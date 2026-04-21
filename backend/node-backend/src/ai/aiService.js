const { chatCompletions } = require('../config/openai');
const systemPrompt = require('./systemPrompt');

function clampInt(v, min, max) {
  const n = Number(v);
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, Math.trunc(n)));
}

function sanitizeText(v, maxLen) {
  const s = String(v == null ? '' : v)
    .replace(/\u0000/g, '')
    .replace(/[^\S\r\n]+/g, ' ')
    .trim();
  if (!maxLen) return s;
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

function sanitizeIsoDate(v) {
  const s = sanitizeText(v, 64);
  if (!s) return null;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function sanitizeSprintReportInput(report) {
  const r = report && typeof report === 'object' ? report : {};
  const sprint = r.sprint && typeof r.sprint === 'object' ? r.sprint : {};
  const summary = r.summary && typeof r.summary === 'object' ? r.summary : {};

  const deliverablesRaw = Array.isArray(r.deliverables) ? r.deliverables : [];
  const deliverables = deliverablesRaw.slice(0, 250).map((d) => {
    const m = d && typeof d === 'object' ? d : {};
    return {
      id: sanitizeText(m.id, 64),
      title: sanitizeText(m.name || m.title, 160),
      status: sanitizeText(m.status, 40),
      category: sanitizeText(m.category, 40),
      progressPercent: clampInt(m.progressPercent, 0, 100),
      dueDate: sanitizeIsoDate(m.dueDate),
      isOverdue: Boolean(m.isOverdue),
      flags: Array.isArray(m.flags) ? m.flags.slice(0, 10).map((x) => sanitizeText(x, 24)).filter(Boolean) : [],
    };
  });

  const delayed = r.insights && r.insights.delayedDeliverables;
  const risk = r.insights && r.insights.riskDeliverables;

  return {
    generatedAt: sanitizeIsoDate(r.generatedAt) || new Date().toISOString(),
    sprint: {
      id: sanitizeText(sprint.id, 64),
      name: sanitizeText(sprint.name, 160),
      startDate: sanitizeIsoDate(sprint.startDate),
      endDate: sanitizeIsoDate(sprint.endDate),
      status: sanitizeText(sprint.status, 40),
      project: sprint.project && typeof sprint.project === 'object'
        ? {
            id: sanitizeText(sprint.project.id, 64),
            key: sanitizeText(sprint.project.key, 32),
            name: sanitizeText(sprint.project.name, 160),
          }
        : null,
    },
    summary: {
      totalDeliverables: clampInt(summary.totalDeliverables, 0, 100000),
      completedDeliverables: clampInt(summary.completedDeliverables, 0, 100000),
      incompleteDeliverables: clampInt(summary.incompleteDeliverables, 0, 100000),
      inProgressDeliverables: clampInt(summary.inProgressDeliverables, 0, 100000),
      notStartedDeliverables: clampInt(summary.notStartedDeliverables, 0, 100000),
      overdueDeliverables: clampInt(summary.overdueDeliverables, 0, 100000),
      blockedDeliverables: clampInt(summary.blockedDeliverables, 0, 100000),
      sprintProgressPercent: clampInt(summary.sprintProgressPercent, 0, 100),
      completionRatePercent: clampInt(summary.completionRatePercent, 0, 100),
      health: sanitizeText(summary.health, 24),
    },
    deliverables,
    insights: {
      delayedDeliverables: Array.isArray(delayed)
        ? delayed.slice(0, 50).map((x) => ({
            id: sanitizeText(x.id, 64),
            title: sanitizeText(x.name || x.title, 160),
            dueDate: sanitizeIsoDate(x.dueDate),
          }))
        : [],
      riskDeliverables: Array.isArray(risk)
        ? risk.slice(0, 50).map((x) => ({
            id: sanitizeText(x.id, 64),
            title: sanitizeText(x.name || x.title, 160),
            flags: Array.isArray(x.flags) ? x.flags.slice(0, 10).map((f) => sanitizeText(f, 24)).filter(Boolean) : [],
          }))
        : [],
    },
  };
}

function extractJsonObject(text) {
  const s = String(text || '').trim();
  if (!s) return null;
  try {
    const direct = JSON.parse(s);
    return direct && typeof direct === 'object' ? direct : null;
  } catch (_) {}
  const start = s.indexOf('{');
  const end = s.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return null;
  const candidate = s.slice(start, end + 1);
  try {
    const parsed = JSON.parse(candidate);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch (_) {
    return null;
  }
}

async function generateSprintAiReport({ sprintReport }) {
  const safe = sanitizeSprintReportInput(sprintReport);
  const schema = {
    sprint: {
      id: 'string',
      name: 'string',
      startDate: 'string|null',
      endDate: 'string|null',
      status: 'string',
      project: { id: 'string|null', key: 'string|null', name: 'string|null' },
    },
    progress: {
      overallPercent: 'number',
      completionRatePercent: 'number',
      totalDeliverables: 'number',
      completedDeliverables: 'number',
      incompleteDeliverables: 'number',
      overdueDeliverables: 'number',
      blockedDeliverables: 'number',
      health: 'string',
    },
    highlights: ['string'],
    completedDeliverables: [{ id: 'string', title: 'string' }],
    incompleteDeliverables: [{ id: 'string', title: 'string', status: 'string', dueDate: 'string|null', risk: 'string|null' }],
    risks: [{ type: 'string', severity: 'low|medium|high', deliverableId: 'string|null', summary: 'string', evidence: 'string' }],
    nextActions: [{ priority: 'low|medium|high', action: 'string', evidence: 'string' }],
    dataGaps: ['string'],
  };

  const msgs = [
    { role: 'system', content: systemPrompt },
    { role: 'system', content: `SPRINT_DATA_JSON: ${JSON.stringify(safe)}` },
    {
      role: 'user',
      content: [
        'Generate a sprint report as STRICT JSON only.',
        'Follow this JSON schema shape (types are guidance):',
        JSON.stringify(schema),
        'Rules:',
        '- Use only the provided SPRINT_DATA_JSON.',
        '- Evidence fields must reference concrete fields (status, dueDate, flags, summary counts).',
        '- If a field cannot be derived from data, set it to null or [] and add an entry to dataGaps.',
      ].join('\n'),
    },
  ];

  const out = await chatCompletions({ messages: msgs, temperature: 0.1, maxTokens: 900 });
  const parsed = extractJsonObject(out.content);
  if (parsed) {
    return { report: parsed, usage: out.usage, model: out.model, raw: null };
  }
  return { report: null, usage: out.usage, model: out.model, raw: out.content };
}

async function sprintChat({ sprintReport, messages, question }) {
  const safe = sanitizeSprintReportInput(sprintReport);
  const msgs = [
    { role: 'system', content: systemPrompt },
    { role: 'system', content: `SPRINT_DATA_JSON: ${JSON.stringify(safe)}` },
  ];

  if (Array.isArray(messages) && messages.length > 0) {
    for (const m of messages.slice(0, 20)) {
      const role = sanitizeText(m && m.role ? m.role : 'user', 24).toLowerCase();
      const content = sanitizeText(m && m.content != null ? m.content : '', 2000);
      if (!content) continue;
      if (role !== 'user' && role !== 'assistant') continue;
      msgs.push({ role, content });
    }
  } else {
    const q = sanitizeText(question, 2000);
    msgs.push({ role: 'user', content: q || 'Provide sprint analysis based on the provided data.' });
  }

  return await chatCompletions({ messages: msgs, temperature: 0.2, maxTokens: 700 });
}

module.exports = {
  sanitizeSprintReportInput,
  generateSprintAiReport,
  sprintChat,
};

