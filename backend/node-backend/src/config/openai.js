const axios = require('axios');

function cleanText(v) {
  let s = String(v == null ? '' : v)
    .replace(/\u0000/g, '')
    .replace(/[^\S\r\n]+/g, ' ')
    .trim();
  s = s.replace(/```/g, '');
  s = s.replace(/[`*#]/g, '');
  s = s.replace(/^\s*#{1,6}\s+/gm, '');
  s = s.replace(/^\s*terminal\s*#?\s*\d+(?:\s*-\s*\d+)?\s*$/gmi, '');
  s = s.replace(/^\s*•\s+/gm, '- ');
  s = s.replace(/^\s*\*\s+/gm, '- ');
  return s.trim();
}

function toRequest(messages, temperature, maxTokens) {
  const msgs = Array.isArray(messages) ? messages : [];
  return {
    messages: msgs.map((m) => ({
      role: cleanText(m && m.role ? m.role : 'user') || 'user',
      content: cleanText(m && m.content != null ? m.content : ''),
    })),
    temperature: typeof temperature === 'number' ? temperature : 0.2,
    max_tokens: Number.isFinite(Number(maxTokens)) ? Number(maxTokens) : 700,
  };
}

let resolvedModel = '';
let resolvedAt = 0;

async function listModels(baseUrl) {
  const r = await axios.get(`${baseUrl}/api/v1/models`, { timeout: 30000 });
  const data = r.data || {};
  const ids = Array.isArray(data.data) ? data.data.map((m) => m && m.id).filter(Boolean) : [];
  return ids.map((id) => String(id));
}

async function resolveModel(baseUrl) {
  const now = Date.now();
  if (resolvedModel && now - resolvedAt < 15 * 60 * 1000) return resolvedModel;

  const prefer = [];
  if (process.env.OPENROUTER_MODEL) prefer.push(String(process.env.OPENROUTER_MODEL).trim());
  if (process.env.GEMINI_MODEL) prefer.push(String(process.env.GEMINI_MODEL).trim());

  let all = [];
  try {
    all = await listModels(baseUrl);
  } catch (_) {}

  let selected = prefer.find((id) => all.includes(id)) || '';
  if (!selected) {
    const candidates = all.filter((id) => id.toLowerCase().includes('gemini'));
    selected = candidates.find((id) => id.toLowerCase().includes('flash')) || candidates[0] || all[0] || 'google/gemini-3.1-flash-lite-preview';
  }

  resolvedModel = selected;
  resolvedAt = now;
  return selected;
}

async function chatCompletions({ messages, temperature, maxTokens }) {
  const apiKey = process.env.OPENROUTER_API_KEY || process.env.OpenRouter_API_KEY || '';
  if (!apiKey) {
    const err = new Error('AI provider not configured. Set OPENROUTER_API_KEY.');
    err.statusCode = 500;
    throw err;
  }

  const baseUrl = (process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai').replace(/\/+$/, '');
  const reqBody = toRequest(messages, temperature, maxTokens);

  let model = (process.env.OPENROUTER_MODEL || process.env.GEMINI_MODEL || '').trim();
  if (!model) model = await resolveModel(baseUrl);

  async function post(modelId) {
    return await axios.post(
      `${baseUrl}/api/v1/chat/completions`,
      {
        model: modelId,
        messages: reqBody.messages,
        temperature: reqBody.temperature,
        max_tokens: reqBody.max_tokens,
      },
      {
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        timeout: 60000,
      },
    );
  }

  let r;
  try {
    r = await post(model);
  } catch (e) {
    const status = (e && e.response && e.response.status) || 0;
    if (status === 400 || status === 404) {
      const fallback = await resolveModel(baseUrl);
      r = await post(fallback);
      model = fallback;
    } else {
      throw e;
    }
  }

  const data = r.data || {};
  const choice = (data.choices && data.choices[0]) || {};
  const message = choice.message || {};
  const content = message.content != null ? String(message.content) : '';
  return { content: cleanText(content), usage: data.usage || {}, model };
}

module.exports = { chatCompletions };
