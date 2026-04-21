const path = require('path');
const axios = require('axios');

require(path.resolve(__dirname, '..', 'src', 'config', 'env-loader'));

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function geminiRole(role) {
  const r = String(role || '').toLowerCase();
  if (r === 'assistant' || r === 'model') return 'model';
  return 'user';
}

function toGeminiRequest(messages, { temperature = 0.4, maxOutputTokens = 500 } = {}) {
  const systemTexts = [];
  const contents = [];

  for (const m of messages || []) {
    const role = String(m && m.role ? m.role : 'user').toLowerCase();
    const content = (m && m.content != null) ? String(m.content) : '';
    if (!content.trim()) continue;

    if (role === 'system') {
      systemTexts.push(content.trim());
      continue;
    }

    contents.push({ role: geminiRole(role), parts: [{ text: content }] });
  }

  if (systemTexts.length > 0) {
    contents.unshift({ role: 'user', parts: [{ text: systemTexts.join('\n\n') }] });
  }

  return {
    contents,
    generationConfig: {
      temperature,
      maxOutputTokens,
    },
  };
}

async function postGenerateContent({ apiKey, model, body }) {
  const url = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(model)}:generateContent`;
  return await axios.post(url, body, {
    params: { key: apiKey },
    headers: { 'Content-Type': 'application/json' },
    timeout: 60_000,
  });
}

async function listModels({ apiKey, apiVersion }) {
  const url = `https://generativelanguage.googleapis.com/${apiVersion}/models`;
  const r = await axios.get(url, { params: { key: apiKey }, timeout: 60_000 });
  const data = r.data || {};
  const models = Array.isArray(data.models) ? data.models : [];
  return models
    .map((m) => ({
      name: String((m && m.name) || '').replace(/^models\//, ''),
      supported: Array.isArray(m && m.supportedGenerationMethods) ? m.supportedGenerationMethods : [],
    }))
    .filter((m) => m.name);
}

async function resolveApiVersion({ apiKey }) {
  try {
    await listModels({ apiKey, apiVersion: 'v1' });
    return 'v1';
  } catch (e) {
    const status = (e && e.response && e.response.status) || 0;
    if (status === 404) return 'v1beta';
    throw e;
  }
}

async function resolveModel({ apiKey, apiVersion }) {
  const configured = String(process.env.GEMINI_MODEL || '').trim().replace(/^models\//, '');
  const preferred = [
    configured,
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-pro',
  ].filter(Boolean);

  const models = await listModels({ apiKey, apiVersion });
  const eligible = models.filter((m) => (m.supported || []).includes('generateContent'));
  for (const p of preferred) {
    if (eligible.some((m) => m.name === p)) return p;
  }
  if (eligible.length > 0) return eligible[0].name;
  if (models.length > 0) return models[0].name;
  return configured || 'gemini-1.5-flash';
}

async function postGenerateContentVersioned({ apiKey, apiVersion, model, body }) {
  const url = `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(model)}:generateContent`;
  return await axios.post(url, body, {
    params: { key: apiKey },
    headers: { 'Content-Type': 'application/json' },
    timeout: 60_000,
  });
}

async function run() {
  const args = process.argv.slice(2);
  const useBackend = args.includes('--backend');
  const providerArgIndex = args.findIndex((a) => a === '--provider');
  const provider =
    (providerArgIndex >= 0 && args[providerArgIndex + 1])
      ? String(args[providerArgIndex + 1]).toLowerCase()
      : 'gemini';
  const promptArgIndex = args.findIndex((a) => a === '--prompt');
  const prompt =
    (promptArgIndex >= 0 && args[promptArgIndex + 1])
      ? String(args[promptArgIndex + 1])
      : 'what is today\'s date?';

  const messages = [
    { role: 'system', content: `Today is ${todayIso()}. Answer using that date if asked.` },
    { role: 'user', content: prompt },
  ];

  const body = toGeminiRequest(messages, { temperature: 0.2, maxOutputTokens: 128 });

  let lastErr = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      if (useBackend) {
        const baseUrl = process.env.API_BASE_URL || 'http://localhost:8000/api/v1';
        const r = await axios.post(`${baseUrl}/ai/chat`, {
          messages,
          temperature: 0.2,
          max_tokens: 128,
        }, {
          headers: { 'Content-Type': 'application/json' },
          timeout: 60_000,
        });
        const data = r.data || {};
        const payload = (data && data.data) ? data.data : data;
        const text = (payload && payload.content) ? String(payload.content).trim() : '';
        process.stdout.write(`mode=backend\n`);
        process.stdout.write(`endpoint=${baseUrl}/ai/chat\n`);
        process.stdout.write(`provider=backend\n`);
        process.stdout.write(`prompt=${prompt}\n`);
        process.stdout.write(`response=${text || '(empty)'}\n`);
        return;
      }

      if (provider === 'deepseek') {
        const apiKey =
          process.env.DEEPSEEK_API_KEY ||
          process.env.Deepseek_API_KEY ||
          process.env.DEEPSEEK_APIKEY ||
          process.env.Deepseek_APIKEY ||
          '';
        if (!apiKey) {
          throw new Error('DEEPSEEK_API_KEY is missing in the backend environment (.env).');
        }
        const baseUrl = (process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com').replace(/\/+$/, '');
        const model = process.env.DEEPSEEK_MODEL || 'deepseek-chat';
        const r = await axios.post(`${baseUrl}/v1/chat/completions`, {
          model,
          messages,
          temperature: 0.2,
          max_tokens: 128,
        }, {
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          timeout: 60_000,
        });
        const data = r.data || {};
        const choice = (data.choices && data.choices[0]) || {};
        const message = choice.message || {};
        const text = (message.content != null) ? String(message.content).trim() : '';
        process.stdout.write(`mode=direct\n`);
        process.stdout.write(`provider=deepseek\n`);
        process.stdout.write(`model=${model}\n`);
        process.stdout.write(`prompt=${prompt}\n`);
        process.stdout.write(`response=${text || '(empty)'}\n`);
        return;
      }

      if (provider === 'openrouter') {
        const apiKey =
          process.env.OPENROUTER_API_KEY ||
          process.env.OpenRouter_API_KEY ||
          '';
        if (!apiKey) {
          throw new Error('OPENROUTER_API_KEY is missing in the backend environment (.env).');
        }
        const baseUrl = (process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai').replace(/\/+$/, '');
        async function listOpenRouterModels() {
          const rr = await axios.get(`${baseUrl}/api/v1/models`, { timeout: 30_000 });
          const data = rr.data || {};
          const models = Array.isArray(data.data) ? data.data : [];
          return models.map((m) => String(m && m.id || '').trim()).filter(Boolean);
        }
        async function tryModel(modelId) {
          return await axios.post(`${baseUrl}/api/v1/chat/completions`, {
            model: modelId,
            messages,
            temperature: 0.2,
            max_tokens: 128,
          }, {
            headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
            timeout: 60_000,
          });
        }
        let model = (process.env.OPENROUTER_MODEL || process.env.GEMINI_MODEL || '').trim();
        if (!model) {
          const all = await listOpenRouterModels();
          const candidates = all.filter((id) => id.toLowerCase().includes('gemini'));
          model = candidates.find((id) => id.toLowerCase().includes('flash')) || candidates[0] || all[0] || 'google/gemini-1.5-flash';
        }
        let r;
        try {
          r = await tryModel(model);
        } catch (e) {
          const status = (e && e.response && e.response.status) || 0;
          if (status === 400 || status === 404) {
            const all = await listOpenRouterModels();
            const candidates = all.filter((id) => id.toLowerCase().includes('gemini'));
            const fallback = candidates.find((id) => id.toLowerCase().includes('flash')) || candidates[0] || all[0];
            if (!fallback) throw e;
            r = await tryModel(fallback);
            model = fallback;
          } else {
            throw e;
          }
        }
        const data = r.data || {};
        const choice = (data.choices && data.choices[0]) || {};
        const message = choice.message || {};
        const text = (message.content != null) ? String(message.content).trim() : '';
        process.stdout.write(`mode=direct\n`);
        process.stdout.write(`provider=openrouter\n`);
        process.stdout.write(`model=${model}\n`);
        process.stdout.write(`prompt=${prompt}\n`);
        process.stdout.write(`response=${text || '(empty)'}\n`);
        return;
      }

      {
        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
          throw new Error('GEMINI_API_KEY is missing in the backend environment (.env).');
        }
        const apiVersion = await resolveApiVersion({ apiKey });
        const model = await resolveModel({ apiKey, apiVersion });
        const r = await postGenerateContentVersioned({ apiKey, apiVersion, model, body });
        const data = r.data || {};
        const cand = (data.candidates && data.candidates[0]) || {};
        const parts = (cand.content && cand.content.parts) || [];
        const text = parts.map((p) => (p && p.text ? String(p.text) : '')).join('').trim();

        process.stdout.write(`mode=direct\n`);
        process.stdout.write(`provider=gemini\n`);
        process.stdout.write(`apiVersion=${apiVersion}\n`);
        process.stdout.write(`model=${model}\n`);
        process.stdout.write(`prompt=${prompt}\n`);
        process.stdout.write(`response=${text || '(empty)'}\n`);
        return;
      }
    } catch (e) {
      const status = (e && e.response && e.response.status) || 0;
      const data = (e && e.response && e.response.data) ? e.response.data : null;
      const msg =
        (data && (data.error?.message || data.error || data.message)) ||
        e.message;
      const effectiveProvider = useBackend ? 'backend' : provider;
      lastErr = new Error(`AI request failed (provider=${effectiveProvider}, status=${status || 'unknown'}): ${msg}`);
      if (status === 429) {
        await new Promise((r) => setTimeout(r, 1000 * attempt));
        continue;
      }
      break;
    }
  }

  throw lastErr || new Error('AI request failed.');
}

run().catch((e) => {
  process.stderr.write(String(e && e.stack ? e.stack : e) + '\n');
  process.exitCode = 1;
});
