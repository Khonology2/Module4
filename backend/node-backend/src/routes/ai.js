const express = require('express');
const router = express.Router();
const axios = require('axios');
const analyticsService = require('../services/analyticsService');
const cache = new Map();
const inflight = new Map();
const CACHE_TTL_MS = 12 * 60 * 60 * 1000;
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-4o-mini';
let consecutiveFailures = 0;
let circuitOpenUntil = 0;
function makeKey(msgs, temperature, max_tokens) {
  try { return JSON.stringify({ msgs, temperature, max_tokens }); } catch (_) { return String(temperature) + '|' + String(max_tokens); }
}
function getCached(key) {
  const e = cache.get(key);
  if (!e) return null;
  if (Date.now() - e.t > CACHE_TTL_MS) { cache.delete(key); return null; }
  return e.v;
}
function setCached(key, v) { cache.set(key, { t: Date.now(), v }); }

function capitalize(s) { return typeof s === 'string' && s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : ''; }
function words(text) { return (text || '').match(/[A-Za-z][A-Za-z\-']*/g) || []; }
function firstMeaningful(text, count = 2) { return words(text).filter(w => w.length > 2).slice(0, count).map(capitalize).join(' '); }
function deriveKey(name) {
  const parts = words(name);
  let key = parts.map(p => p[0]).join('');
  if (key.length < 2) key = (name || '').replace(/[^A-Za-z]/g, '').slice(0, 4);
  key = (key || 'PRJ').toUpperCase().replace(/[^A-Z]/g, '');
  if (key.length > 6) key = key.slice(0, 6);
  if (key.length < 2) key = (key + 'PRJ').slice(0, Math.max(2, key.length));
  return key;
}
function parseField(source, label) {
  const m = (source || '').match(new RegExp(label + "\s*:\\s*([^\n]+)", 'i'));
  return m ? m[1].trim() : '';
}
function generateReportContent(userText) {
  const committed = Number((userText.match(/Committed\s*:\s*(\d+)/i) || [])[1] || 0);
  const completed = Number((userText.match(/Completed\s*:\s*(\d+)/i) || [])[1] || 0);
  const passRate = (userText.match(/AvgTestPassRate\s*:\s*([0-9.]+)%/i) || [])[1] || '';
  const title = parseField(userText, 'Title') || firstMeaningful(userText, 2) || 'Deliverable Report';
  const dod = parseField(userText, 'DefinitionOfDone');
  const lines = [];
  lines.push(`# ${title}`);
  lines.push('');
  lines.push('## Executive Summary');
  lines.push(`This report summarizes progress and quality signals for ${title}.`);
  lines.push('');
  lines.push('## Sprint Performance');
  lines.push(`Committed: ${committed}`);
  lines.push(`Completed: ${completed}`);
  if (committed > 0) {
    const velocity = completed;
    const completionRate = committed ? Math.round((completed / committed) * 100) : 0;
    lines.push(`Velocity: ${velocity}`);
    lines.push(`Completion Rate: ${completionRate}%`);
  }
  lines.push('');
  lines.push('## Quality');
  if (passRate) lines.push(`Average Test Pass Rate: ${passRate}%`);
  lines.push('Defect trends and coverage appear within expected ranges based on current scope.');
  lines.push('');
  lines.push('## Readiness');
  lines.push(dod ? `Definition of Done: ${dod}` : 'Definition of Done: See checklist in deliverable details.');
  lines.push('The deliverable is progressing toward readiness subject to final validations and sign-offs.');
  lines.push('');
  lines.push('## Recommendations');
  lines.push('- Address any remaining blocking tasks early in the next sprint');
  lines.push('- Maintain test coverage and close critical defects before release');
  lines.push('- Communicate risks and dependencies to stakeholders');
  lines.push('');
  lines.push('## Detailed Metrics');
  lines.push('- Story Points Committed vs Completed');
  lines.push('- Carryover from previous sprint');
  lines.push('- Test execution and pass rate by suite');
  lines.push('- Code review completion and documentation status');
  lines.push('');
  lines.push('## Defect Severity Breakdown');
  lines.push('- Critical: impact on release readiness');
  lines.push('- High: prioritized for next iteration');
  lines.push('- Medium: tracked and monitored');
  lines.push('- Low: non-blocking improvements');
  lines.push('');
  lines.push('## Risks & Dependencies');
  lines.push('- Key risks impacting delivery timelines');
  lines.push('- Dependencies with teams and systems');
  lines.push('- Mitigation actions and owners');
  lines.push('');
  lines.push('## Next Steps');
  lines.push('1. Prioritize remaining scope and defects');
  lines.push('2. Increase coverage on critical paths');
  lines.push('3. Align deployment plan and sign-offs');
  return lines.join('\n');
}

router.post('/chat', async (req, res) => {
  const { messages, prompt, temperature, max_tokens } = req.body || {};
  const msgs = Array.isArray(messages) ? messages : (prompt ? [{ role: 'user', content: prompt }] : []);
  try {
    try {
      const metrics = await analyticsService.getMetrics();
      const m = metrics || {};
      const parts = [];
      if (m.total_users !== undefined) parts.push(`users=${m.total_users}`);
      if (m.active_sprints !== undefined) parts.push(`active_sprints=${m.active_sprints}`);
      if (m.completed_sprints !== undefined) parts.push(`completed_sprints=${m.completed_sprints}`);
      if (m.total_deliverables !== undefined) parts.push(`deliverables=${m.total_deliverables}`);
      const summary = parts.join(', ');
      msgs.unshift({ role: 'system', content: `Context: ${summary}` });
    } catch (_) {}
    const key = makeKey(msgs, temperature, max_tokens);
    const cached = getCached(key);
    if (cached) {
      return res.json({ success: true, data: cached });
    }
    const existing = inflight.get(key);
    if (existing) {
      try {
        const v = await existing;
        return res.json({ success: true, data: v });
      } catch (e) {
        const status = (e && e.response && e.response.status) || 500;
        return res.status(status).json({ error: e.message || 'AI request failed' });
      }
    }
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'OpenAI API key not configured' });
    }
    if (!msgs || msgs.length === 0) {
      return res.status(400).json({ error: 'messages or prompt required' });
    }
    const p = (async () => {
      const r = await axios.post('https://api.openai.com/v1/chat/completions', {
        model: OPENAI_MODEL,
        messages: msgs,
        temperature: typeof temperature === 'number' ? temperature : 0.7,
        max_tokens: typeof max_tokens === 'number' ? max_tokens : 512
      }, {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        }
      });
      const data = r.data || {};
      const choice = (data.choices && data.choices[0]) || {};
      const message = choice.message || {};
      const payload = { content: message.content || '', usage: data.usage || {}, model: data.model || OPENAI_MODEL };
      setCached(key, payload);
      consecutiveFailures = 0;
      circuitOpenUntil = 0;
      return payload;
    })();
    inflight.set(key, p);
    try {
      const payload = await p;
      return res.json({ success: true, data: payload });
    } finally {
      inflight.delete(key);
    }
  } catch (error) {
    inflight.delete(makeKey(msgs, temperature, max_tokens));
    const status = (error && error.response && error.response.status) || 500;
    if (status === 429) {
      consecutiveFailures += 1;
      const retryAfter = (error && error.response && error.response.headers && (error.response.headers['retry-after'] || error.response.headers['Retry-After'])) || '2';
      return res.status(429).json({
        error: 'AI provider rate limit exceeded. Please retry shortly.',
        retry_after: retryAfter
      });
    }
    consecutiveFailures += 1;
    return res.status(status).json({ error: error.message || 'AI request failed' });
  }
});

router.get('/chat', async (req, res) => {
  try {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: 'OpenAI API key not configured' });
    }
    return res.status(405).json({ error: 'Method Not Allowed', message: 'Use POST /chat with a JSON body: { messages: [...] }' });
  } catch (error) {
    return res.status(500).json({ error: error.message || 'Internal error' });
  }
});

module.exports = router;
