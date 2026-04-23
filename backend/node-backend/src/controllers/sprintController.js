const { Sprint, Project, Deliverable, User } = require('../models');
const { carryOverOverdueDeliverablesForProject } = require('../services/sprintCarryOverService');
const aiService = require('../ai/aiService');

function normalizeStatus(v) {
  return String(v || '').toLowerCase().replace(/[\s_-]+/g, '');
}

function buildUserDisplayName(u) {
  if (!u) return null;
  const name = (u.name || '').toString().trim();
  if (name) return name;
  const first = (u.first_name || u.firstName || '').toString().trim();
  const last = (u.last_name || u.lastName || '').toString().trim();
  const full = `${first} ${last}`.trim();
  if (full) return full;
  const email = (u.email || '').toString().trim();
  return email || null;
}

function deliverableProgressPercent(statusRaw) {
  const s = normalizeStatus(statusRaw);
  if (s === 'signedoff' || s === 'approved' || s === 'completed' || s === 'done') return 100;
  if (s === 'inreview' || s === 'submitted') return 80;
  if (s === 'changerequested') return 70;
  if (s === 'rejected') return 50;
  if (s === 'inprogress' || s === 'active') return 50;
  return 0;
}

function deliverableStatusCategory(deliverable, now) {
  const s = normalizeStatus(deliverable.status);
  const progress = deliverableProgressPercent(deliverable.status);
  const due = deliverable.due_date ? new Date(deliverable.due_date) : null;
  const overdue = due != null && due.getTime() < now.getTime() && progress < 100;
  const blocked = s === 'changerequested' || s === 'rejected';
  if (overdue) return 'overdue';
  if (progress >= 100) return 'completed';
  if (blocked) return 'blocked';
  if (progress <= 0) return 'not_started';
  return 'in_progress';
}

async function buildSprintReportFromDb({ id, query }) {
  const statusCategory = (query.statusCategory || query.status || '').toString().trim();
  const ownerId = (query.ownerId || query.owner_id || '').toString().trim();
  const dueFrom = (query.dueFrom || query.due_from || '').toString().trim();
  const dueTo = (query.dueTo || query.due_to || '').toString().trim();

  const sprint = await Sprint.findByPk(id, {
    include: [{ model: Project, as: 'project', attributes: ['id', 'name', 'key'] }],
  });
  if (!sprint) {
    const err = new Error('Sprint not found');
    err.statusCode = 404;
    throw err;
  }

  if (sprint.project_id) {
    try {
      await carryOverOverdueDeliverablesForProject(sprint.project_id);
    } catch (_) {}
  }

  const sprintWithDeliverables = await Sprint.findByPk(id, {
    include: [
      { model: Project, as: 'project', attributes: ['id', 'name', 'key'] },
      {
        model: Deliverable,
        as: 'deliverables',
        through: { attributes: [] },
        required: false,
        include: [{ model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
      },
    ],
  });

  const now = new Date();
  const rawDeliverables = sprintWithDeliverables && sprintWithDeliverables.deliverables ? sprintWithDeliverables.deliverables : [];

  let deliverables = rawDeliverables.map((d) => {
    const progressPercent = deliverableProgressPercent(d.status);
    const dueDate = d.due_date ? new Date(d.due_date) : null;
    const createdAt = d.created_at ? new Date(d.created_at) : null;
    const updatedAt = d.updated_at ? new Date(d.updated_at) : null;
    const completionDate = d.approved_at ? new Date(d.approved_at) : (d.submitted_at ? new Date(d.submitted_at) : null);
    const category = deliverableStatusCategory(d, now);
    const isOverdue = category === 'overdue';

    const owner = d.owner || null;
    const ownerName = buildUserDisplayName(owner);

    const flags = [];
    if (isOverdue) flags.push('overdue');
    if (category === 'blocked') flags.push('blocked');
    if (category === 'not_started') flags.push('not_started');
    if (category === 'in_progress') flags.push('in_progress');
    if (category === 'completed') flags.push('completed');

    return {
      id: d.id != null ? String(d.id) : '',
      name: d.title || d.name || `Deliverable ${d.id}`,
      description: d.description || '',
      ownerId: owner && owner.id != null ? String(owner.id) : (d.owner_id != null ? String(d.owner_id) : null),
      ownerName,
      ownerRole: owner && owner.role != null ? String(owner.role) : null,
      createdAt: createdAt ? createdAt.toISOString() : null,
      dueDate: dueDate ? dueDate.toISOString() : null,
      status: d.status || 'draft',
      progressPercent,
      lastUpdated: updatedAt ? updatedAt.toISOString() : null,
      completionDate: completionDate ? completionDate.toISOString() : null,
      isOverdue,
      category,
      flags,
    };
  });

  const fromDate = dueFrom ? new Date(dueFrom) : null;
  const toDate = dueTo ? new Date(dueTo) : null;
  if (fromDate && !Number.isNaN(fromDate.getTime())) {
    deliverables = deliverables.filter((d) => d.dueDate && new Date(d.dueDate).getTime() >= fromDate.getTime());
  }
  if (toDate && !Number.isNaN(toDate.getTime())) {
    deliverables = deliverables.filter((d) => d.dueDate && new Date(d.dueDate).getTime() <= toDate.getTime());
  }
  if (ownerId) {
    deliverables = deliverables.filter((d) => String(d.ownerId || '') === ownerId);
  }
  if (statusCategory) {
    const cat = normalizeStatus(statusCategory);
    deliverables = deliverables.filter((d) => normalizeStatus(d.category) === cat);
  }

  const total = deliverables.length;
  const counts = { completed: 0, in_progress: 0, not_started: 0, overdue: 0, blocked: 0 };
  let sumProgress = 0;
  for (const d of deliverables) {
    sumProgress += Number(d.progressPercent || 0);
    if (counts[d.category] !== undefined) counts[d.category] += 1;
  }
  const progressPercent = total > 0 ? Math.round(sumProgress / total) : 0;
  const completionRate = total > 0 ? Math.round((counts.completed / total) * 100) : 0;

  const teamMap = new Map();
  for (const d of rawDeliverables) {
    const o = d.owner || null;
    if (o && o.id != null) {
      const uid = String(o.id);
      if (!teamMap.has(uid)) {
        teamMap.set(uid, { id: uid, name: buildUserDisplayName(o), email: o.email || null, role: o.role || null });
      }
    }
  }
  const team = Array.from(teamMap.values()).filter((m) => m.name || m.email);

  const sprintStatus = sprintWithDeliverables.status || sprint.status || 'planning';
  const sprintEnd = sprintWithDeliverables.end_date || sprint.end_date;
  const endDate = sprintEnd ? new Date(sprintEnd) : null;
  const health = counts.overdue > 0 ? 'critical' : (endDate && endDate.getTime() < now.getTime() && completionRate < 100 ? 'warning' : 'good');

  return {
    generatedAt: now.toISOString(),
    sprint: {
      id: String(sprintWithDeliverables.id),
      name: sprintWithDeliverables.name,
      startDate: sprintWithDeliverables.start_date ? new Date(sprintWithDeliverables.start_date).toISOString() : null,
      endDate: sprintWithDeliverables.end_date ? new Date(sprintWithDeliverables.end_date).toISOString() : null,
      status: sprintStatus,
      projectId: sprintWithDeliverables.project_id ? String(sprintWithDeliverables.project_id) : null,
      project: sprintWithDeliverables.project
        ? { id: sprintWithDeliverables.project.id, name: sprintWithDeliverables.project.name, key: sprintWithDeliverables.project.key }
        : null,
    },
    filters: { statusCategory: statusCategory || null, ownerId: ownerId || null, dueFrom: dueFrom || null, dueTo: dueTo || null },
    summary: {
      totalDeliverables: total,
      completedDeliverables: counts.completed,
      incompleteDeliverables: total - counts.completed,
      inProgressDeliverables: counts.in_progress,
      notStartedDeliverables: counts.not_started,
      overdueDeliverables: counts.overdue,
      blockedDeliverables: counts.blocked,
      sprintProgressPercent: progressPercent,
      completionRatePercent: completionRate,
      health,
    },
    team: { members: team },
    deliverables,
    insights: {
      delayedDeliverables: deliverables.filter((d) => d.isOverdue).map((d) => ({ id: d.id, name: d.name, dueDate: d.dueDate, ownerName: d.ownerName })),
      riskDeliverables: deliverables.filter((d) => d.category === 'blocked' || d.isOverdue).map((d) => ({ id: d.id, name: d.name, flags: d.flags })),
    },
  };
}

async function getSprintReport(req, res) {
  try {
    const report = await buildSprintReportFromDb({ id: req.params.id, query: req.query || {} });
    return res.json({ success: true, data: report });
  } catch (e) {
    const status = e.statusCode || 500;
    return res.status(status).json({ success: false, error: e.message || 'Internal server error' });
  }
}

async function getAiSprintReport(req, res) {
  try {
    const sprintReport = await buildSprintReportFromDb({ id: req.params.id, query: req.query || {} });
    const ai = await aiService.generateSprintAiReport({ sprintReport });
    return res.json({
      success: true,
      data: {
        sprint: sprintReport.sprint,
        summary: sprintReport.summary,
        ai: ai.report || null,
        aiRaw: ai.report ? null : (ai.raw || null),
        model: ai.model,
        usage: ai.usage,
      },
    });
  } catch (e) {
    const status = e.statusCode || (e && e.response && e.response.status) || 500;
    const msg = (e && e.response && e.response.data && (e.response.data.error?.message || e.response.data.error || e.response.data.message)) || e.message || 'Internal server error';
    return res.status(status).json({ success: false, error: msg });
  }
}

async function postAiSprintChat(req, res) {
  try {
    const sprintReport = await buildSprintReportFromDb({ id: req.params.id, query: req.query || {} });
    const body = req.body || {};
    const out = await aiService.sprintChat({ sprintReport, messages: body.messages, question: body.question || body.prompt });
    return res.json({ success: true, data: out });
  } catch (e) {
    const status = e.statusCode || (e && e.response && e.response.status) || 500;
    const msg = (e && e.response && e.response.data && (e.response.data.error?.message || e.response.data.error || e.response.data.message)) || e.message || 'Internal server error';
    return res.status(status).json({ success: false, error: msg });
  }
}

module.exports = {
  buildSprintReportFromDb,
  getSprintReport,
  getAiSprintReport,
  postAiSprintChat,
};
