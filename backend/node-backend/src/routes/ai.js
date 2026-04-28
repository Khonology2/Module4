const express = require('express');
const router = express.Router();
const axios = require('axios');
const analyticsService = require('../services/analyticsService');
const { sequelize, Project, Sprint, Deliverable, Ticket, User, ProjectMember, DeliverableSprint, Notification } = require('../models');
const { Op } = require('sequelize');
const cache = new Map();
const inflight = new Map();
const CACHE_TTL_MS = 12 * 60 * 60 * 1000;
let resolvedOpenRouterModel = '';
let resolvedOpenRouterModelAt = 0;
let consecutiveFailures = 0;
let circuitOpenUntil = 0;
const pendingActions = new Map();
const lastTopicByUser = new Map();
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

function cleanAiText(text) {
  let s = String(text || '');
  s = s.replace(/```[\s\S]*?```/g, (m) => m.replace(/```/g, ''));
  s = s.replace(/^\s*#{1,6}\s+/gm, '');
  s = s.replace(/^\s*terminal\s*#?\s*\d+(?:\s*-\s*\d+)?\s*$/gmi, '');
  s = s.replace(/^\s*[-*+]\s+/gm, '- ');
  s = s.replace(/^\s*•\s+/gm, '- ');
  s = s.replace(/[`*#]/g, '');
  s = s.replace(/^\s*>\s?/gm, '');
  s = s.replace(/[^\S\r\n]+/g, ' ');
  s = s.replace(/^\s*•\s+/gm, '- ');
  return s.trim();
}

function parseKeyValueLines(text) {
  const obj = {};
  const raw = String(text || '');
  for (const line of raw.split('\n')) {
    const m = line.match(/^\s*([A-Za-z][A-Za-z0-9 _-]{0,40})\s*:\s*(.+?)\s*$/);
    if (!m) continue;
    const k = String(m[1]).trim().toLowerCase().replace(/[\s_-]+/g, '_');
    const v = String(m[2]).trim();
    if (!k || !v) continue;
    obj[k] = v;
  }
  return obj;
}

function mergeDefined(target, patch) {
  const t = target || {};
  const p = patch || {};
  for (const k of Object.keys(p)) {
    const v = p[k];
    if (v === undefined || v === null) continue;
    if (typeof v === 'string' && !v.trim()) continue;
    t[k] = v;
  }
  return t;
}

function isConfirmText(text) {
  const t = String(text || '').trim().toLowerCase();
  if (t === 'confirm' || t === 'yes' || t === 'y' || t === 'ok' || t === 'okay' || t === 'go ahead' || t === 'proceed') return true;
  if (/^confirm\b/.test(t)) return true;
  if (/^yes\b/.test(t)) return true;
  if (/^ok\b/.test(t)) return true;
  return false;
}

function isCancelText(text) {
  const t = String(text || '').trim().toLowerCase();
  return t === 'cancel' || t === 'stop' || t === 'never mind' || t === 'nevermind';
}

function isSkipText(text) {
  const t = String(text || '').trim().toLowerCase();
  return t === 'skip' || t === 'none' || t === 'n/a' || t === 'no feedback';
}

function normalizePossibleTitle(value) {
  const s = String(value || '').trim().replace(/^["'`“”]+|["'`“”]+$/g, '');
  if (!s) return '';
  if (s.length > 160) return '';
  if (!/[A-Za-z0-9]/.test(s)) return '';
  if (/^(confirm|yes|y|ok|okay|go ahead|proceed|cancel|stop)$/i.test(s)) return '';
  return s;
}

function extractReportTitleFromText(text) {
  const raw = String(text || '').trim();
  if (!raw) return '';
  const kv = parseKeyValueLines(raw);
  if (kv.report_title) return normalizePossibleTitle(kv.report_title);

  const patterns = [
    /(?:report\s*title|title)\s*(?:is|:|-)\s*(.+)$/i,
    /(?:name\s+this\s+report|call\s+(?:this\s+)?report)\s*(.+)$/i,
    /(?:set\s+)?report\s+title\s+to\s+(.+)$/i,
    /^(?:it'?s|its)\s+(.+)$/i,
  ];
  for (const p of patterns) {
    const m = raw.match(p);
    if (m && m[1]) {
      const title = normalizePossibleTitle(m[1].replace(/[.?!]\s*$/g, ''));
      if (title) return title;
    }
  }

  if (raw.length <= 80 && !raw.includes('\n') && !/\?$/.test(raw)) {
    const direct = normalizePossibleTitle(raw.replace(/[.?!]\s*$/g, ''));
    if (direct) return direct;
  }
  return '';
}

function suggestSprintReportTitle(sprintData) {
  try {
    const sprint = sprintData && sprintData.sprint ? sprintData.sprint : {};
    const sprintName = String(sprint.name || 'Sprint').trim() || 'Sprint';
    const project = sprint.project || null;
    const projectKey = project && project.key ? String(project.key).trim() : '';
    const end = fmtIsoDate(sprint.endDate);
    const parts = [];
    parts.push('Sprint Report');
    if (projectKey) parts.push(projectKey);
    parts.push(sprintName);
    if (end) parts.push(end);
    return parts.join(' - ');
  } catch (_) {
    return 'Sprint Report';
  }
}

function shouldAutoCancelPending(pending, userText, pendingPatch) {
  if (!pending) return false;
  if (isCancelText(userText) || isConfirmText(userText)) return false;
  const t = String(userText || '').toLowerCase();
  const nextCreate = detectCreateIntent(userText);
  if (nextCreate && nextCreate !== pending.type) return true;
  const isSprintReport = /\bsprint\b/.test(t) && /\breport\b/.test(t);
  if (isSprintReport && pending.type !== 'sprint_report' && pending.type !== 'sprint_report_select') return true;
  if (pendingPatch && Object.keys(pendingPatch).length > 0) return false;
  if (isNavigationQuery(userText)) return true;
  if (isNotificationsDataQuery(userText)) return true;
  if (/\bsprint\b/.test(t) && /\breport\b/.test(t) && pending.type !== 'sprint_report') return true;
  if (isListOrCountQuery(userText)) return true;
  return false;
}

function normalizeProjectKeyOrName(value) {
  const v = String(value || '').trim();
  if (!v) return '';
  if (/^[A-Za-z]{2,10}$/.test(v)) return v.toUpperCase();
  return v;
}

async function resolveProjectIdFromInput(value, snapshotData) {
  const v = normalizeProjectKeyOrName(value);
  if (!v) return null;
  const projects = snapshotData && Array.isArray(snapshotData.projects) ? snapshotData.projects : [];
  const byKey = projects.find((p) => String(p.key || '').toUpperCase() === v.toUpperCase());
  if (byKey) return String(byKey.id);
  const byName = projects.find((p) => String(p.name || '').toLowerCase() === v.toLowerCase());
  if (byName) return String(byName.id);
  const where = {
    [Op.or]: [
      { key: v.toUpperCase() },
      { name: v },
    ],
  };
  const found = await Project.findOne({ where, attributes: ['id'] });
  return found ? String(found.id) : null;
}

async function ensureReportsTable() {
  await sequelize.query(
    "CREATE TABLE IF NOT EXISTS sign_off_reports (" +
      "id SERIAL PRIMARY KEY," +
      "deliverable_id VARCHAR(255)," +
      "created_by VARCHAR(255)," +
      "status VARCHAR(50) DEFAULT 'draft'," +
      "content JSONB," +
      "created_at TIMESTAMP DEFAULT NOW()," +
      "updated_at TIMESTAMP DEFAULT NOW()" +
    ")"
  );
}

function detectCreateIntent(text) {
  const t = String(text || '').toLowerCase();
  const isSprintReportRequest =
    /\bsprint\b/.test(t) && (/\breport\b/.test(t) || /\b(sign[- ]?off|signoff)\b/.test(t));
  if (isSprintReportRequest) return null;
  const isSignoffReport =
    /\b(sign[- ]?off|signoff)\b.*\breport\b|\breport\b.*\b(sign[- ]?off|signoff)\b/.test(t);
  if (isSignoffReport) return 'report';

  const isAnyNonSignoffReport =
    /\breport\b/.test(t) ||
    (/\bsummary\b/.test(t) && (/\bsprint\b/.test(t) || /\bproject\b/.test(t)));
  if (isAnyNonSignoffReport) return null;

  if (!/\b(create|add|new|make|generate)\b/.test(t)) return null;
  if (/\bdeliverable\b/.test(t)) return 'deliverable';
  if (/\bsprint\b/.test(t)) return 'sprint';
  if (/\bproject\b/.test(t)) return 'project';
  return null;
}

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

function normalizeRole(v) {
  return String(v || '').toLowerCase().replace(/[\s_-]+/g, '');
}

function isAdminUser(user) {
  const r = normalizeRole(user && user.role);
  return r === 'admin' || r === 'systemadmin';
}

function displayName(user) {
  const first = user && user.first_name ? String(user.first_name).trim() : '';
  const last = user && user.last_name ? String(user.last_name).trim() : '';
  const full = `${first} ${last}`.trim();
  if (full) return full;
  if (user && user.email) return String(user.email);
  return user && user.id ? String(user.id) : 'Unknown';
}

function normalizeStatus(v) {
  return String(v || '').toLowerCase().replace(/[\s_-]+/g, '');
}

function isDeliverableCompletedStatus(v) {
  const s = normalizeStatus(v);
  return s === 'signedoff' || s === 'approved' || s === 'completed' || s === 'done';
}

function isSprintCompletedStatus(v) {
  const s = normalizeStatus(v);
  return s === 'completed' || s === 'done' || s === 'closed' || s === 'finished' || s === 'signedoff' || s === 'approved';
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

async function buildAppDataSnapshotData(user) {
  const maxProjects = Number(process.env.AI_CONTEXT_MAX_PROJECTS || 50);
  const maxSprints = Number(process.env.AI_CONTEXT_MAX_SPRINTS || 200);
  const maxDeliverables = Number(process.env.AI_CONTEXT_MAX_DELIVERABLES || 250);
  const maxTickets = Number(process.env.AI_CONTEXT_MAX_TICKETS || 250);
  const maxAssignees = Number(process.env.AI_CONTEXT_MAX_ASSIGNEES || 50);
  const maxNotifications = Number(process.env.AI_CONTEXT_MAX_NOTIFICATIONS || 25);
  const includeAllUsers = String(process.env.AI_CONTEXT_INCLUDE_ALL_USERS || 'true').toLowerCase() === 'true';
  const fullAccess =
    String(process.env.AI_CONTEXT_FULL_ACCESS || '').toLowerCase() === 'true' ||
    String(process.env.NODE_ENV || '').toLowerCase() === 'development';

  const isAdmin = isAdminUser(user);
  const userId = user && user.id ? String(user.id) : '';

  let memberProjectIds = [];
  if (!fullAccess && !isAdmin && userId) {
    const memberProjects = await ProjectMember.findAll({
      where: { user_id: userId },
      attributes: ['project_id'],
    });
    memberProjectIds = (memberProjects || []).map((m) => String(m.project_id));
  }

  const projectWhere = (fullAccess || isAdmin) ? {} : {
    [Op.or]: [
      { owner_id: userId },
      { created_by: userId },
      ...(memberProjectIds.length > 0 ? [{ id: { [Op.in]: memberProjectIds } }] : []),
    ],
  };

  const projectsRaw = await Project.findAll({
    where: projectWhere,
    include: [{ model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
    order: [['updated_at', 'DESC']],
    limit: maxProjects,
  });

  const projectIds = (projectsRaw || []).map((p) => String(p.id));
  const projectKeyById = new Map((projectsRaw || []).map((p) => [String(p.id), String(p.key || '')]));

  const sprintsRaw = projectIds.length === 0 ? [] : await Sprint.findAll({
    where: { project_id: { [Op.in]: projectIds } },
    attributes: [
      'id',
      'project_id',
      'name',
      'status',
      'start_date',
      'end_date',
      'progress',
      'committed_points',
      'completed_points',
      'carried_over_points',
      'updated_at',
    ],
    order: [['updated_at', 'DESC']],
    limit: maxSprints,
  });

  const deliverablesRaw = projectIds.length === 0 ? [] : await Deliverable.findAll({
    where: { project_id: { [Op.in]: projectIds } },
    attributes: ['id', 'project_id', 'title', 'status', 'priority', 'due_date', 'assigned_to', 'owner_id', 'updated_at'],
    include: [{ model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
    order: [['updated_at', 'DESC']],
    limit: maxDeliverables,
  });

  const sprintIds = (sprintsRaw || []).map((s) => Number(s.id)).filter((n) => Number.isFinite(n));
  const ticketsRaw = sprintIds.length === 0 ? [] : await Ticket.findAll({
    where: { sprint_id: { [Op.in]: sprintIds } },
    attributes: ['id', 'ticket_id', 'ticket_key', 'summary', 'status', 'priority', 'issue_type', 'assignee', 'sprint_id', 'updated_at'],
    order: [['updated_at', 'DESC']],
    limit: maxTickets,
  });

  const deliverablesByProject = new Map();
  for (const d of deliverablesRaw || []) {
    const pid = String(d.project_id || '');
    if (!deliverablesByProject.has(pid)) deliverablesByProject.set(pid, []);
    deliverablesByProject.get(pid).push(d);
  }

  const sprintsByProject = new Map();
  for (const s of sprintsRaw || []) {
    const pid = String(s.project_id || '');
    if (!sprintsByProject.has(pid)) sprintsByProject.set(pid, []);
    sprintsByProject.get(pid).push(s);
  }

  const projects = (projectsRaw || []).map((p) => {
    const pid = String(p.id);
    const ds = deliverablesByProject.get(pid) || [];
    const ss = sprintsByProject.get(pid) || [];
    const deliverablesTotal = ds.length;
    const deliverablesCompleted = ds.filter((d) => isDeliverableCompletedStatus(d.status)).length;
    const sprintsTotal = ss.length;
    const sprintsCompleted = ss.filter((s) => isSprintCompletedStatus(s.status)).length;
    const sprintsActive = ss.filter((s) => !isSprintCompletedStatus(s.status)).length;
    return {
      id: pid,
      key: String(p.key || ''),
      name: String(p.name || ''),
      status: String(p.status || ''),
      owner: p.owner ? { id: String(p.owner.id), name: displayName(p.owner) } : null,
      startDate: p.start_date ? new Date(p.start_date).toISOString().slice(0, 10) : null,
      endDate: p.end_date ? new Date(p.end_date).toISOString().slice(0, 10) : null,
      sprints: { total: sprintsTotal, active: sprintsActive, completed: sprintsCompleted },
      deliverables: { total: deliverablesTotal, completed: deliverablesCompleted, open: deliverablesTotal - deliverablesCompleted },
    };
  });

  const sprints = (sprintsRaw || []).map((s) => ({
    id: s.id,
    projectKey: projectKeyById.get(String(s.project_id || '')) || '',
    name: String(s.name || ''),
    status: String(s.status || ''),
    startDate: s.start_date ? new Date(s.start_date).toISOString().slice(0, 10) : null,
    endDate: s.end_date ? new Date(s.end_date).toISOString().slice(0, 10) : null,
    progress: typeof s.progress === 'number' ? s.progress : Number(s.progress || 0),
    committedPoints: Number(s.committed_points || 0),
    completedPoints: Number(s.completed_points || 0),
    carriedOverPoints: Number(s.carried_over_points || 0),
  }));

  const deliverables = (deliverablesRaw || []).map((d) => ({
    id: d.id,
    projectKey: projectKeyById.get(String(d.project_id || '')) || '',
    title: String(d.title || ''),
    status: String(d.status || ''),
    priority: String(d.priority || ''),
    dueDate: d.due_date ? new Date(d.due_date).toISOString().slice(0, 10) : null,
    owner: d.owner ? { id: String(d.owner.id), name: displayName(d.owner) } : (d.owner_id ? { id: String(d.owner_id), name: String(d.owner_id) } : null),
    assignedTo: d.assigned_to ? String(d.assigned_to) : null,
  }));

  const projectKeyBySprintId = new Map((sprintsRaw || []).map((s) => [Number(s.id), projectKeyById.get(String(s.project_id || '')) || '']));
  const tickets = (ticketsRaw || []).map((t) => ({
    id: t.id,
    projectKey: projectKeyBySprintId.get(Number(t.sprint_id)) || '',
    sprintId: t.sprint_id != null ? Number(t.sprint_id) : null,
    ticketId: String(t.ticket_id || ''),
    summary: String(t.summary || ''),
    status: String(t.status || ''),
    priority: String(t.priority || ''),
    issueType: String(t.issue_type || ''),
    assignee: t.assignee ? String(t.assignee) : null,
  }));

  const deliverablesByOwner = new Map();
  for (const d of deliverablesRaw || []) {
    const owner = d.owner ? displayName(d.owner) : null;
    if (!owner) continue;
    if (!deliverablesByOwner.has(owner)) deliverablesByOwner.set(owner, []);
    deliverablesByOwner.get(owner).push(d);
  }

  const ticketsByAssignee = new Map();
  for (const t of ticketsRaw || []) {
    const a = t.assignee ? String(t.assignee).trim() : '';
    if (!a) continue;
    if (!ticketsByAssignee.has(a)) ticketsByAssignee.set(a, []);
    ticketsByAssignee.get(a).push(t);
  }

  const assignmentNames = Array.from(new Set([...deliverablesByOwner.keys(), ...ticketsByAssignee.keys()])).slice(0, maxAssignees);
  const assignments = assignmentNames.map((name) => ({
    name,
    deliverables: (deliverablesByOwner.get(name) || []).slice(0, 20).map((d) => ({
      id: d.id,
      projectKey: projectKeyById.get(String(d.project_id || '')) || '',
      title: String(d.title || ''),
      status: String(d.status || ''),
    })),
    tickets: (ticketsByAssignee.get(name) || []).slice(0, 20).map((t) => ({
      id: t.id,
      projectKey: projectKeyById.get(String(t.project_id || '')) || '',
      ticketId: String(t.ticket_id || ''),
      summary: String(t.summary || ''),
      status: String(t.status || ''),
    })),
  }));

  let users = [];
  let memberships = [];
  try {
    const maxMembers = Number(process.env.AI_CONTEXT_MAX_PROJECT_MEMBERS || 500);
    const membersRaw = projectIds.length === 0 ? [] : await ProjectMember.findAll({
      where: { project_id: { [Op.in]: projectIds } },
      include: [
        { model: User, as: 'user', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] },
        { model: Project, as: 'project', attributes: ['id', 'key', 'name'] },
      ],
      limit: maxMembers,
    });

    const userMap = new Map();
    const mships = [];
    for (const m of membersRaw || []) {
      const u = m.user;
      const p = m.project;
      if (!u || !p) continue;
      const uid = String(u.id);
      const pk = String(p.key || '');
      if (!userMap.has(uid)) {
        userMap.set(uid, {
          id: uid,
          name: displayName(u),
          email: u.email ? String(u.email) : null,
          role: u.role ? String(u.role) : null,
          projectKeys: [],
        });
      }
      const entry = userMap.get(uid);
      if (pk && !entry.projectKeys.includes(pk)) entry.projectKeys.push(pk);
      mships.push({
        projectKey: pk,
        projectName: String(p.name || ''),
        userId: uid,
        userName: displayName(u),
        role: m.role ? String(m.role) : null,
      });
    }

    users = Array.from(userMap.values());
    memberships = mships;
  } catch (_) {
    users = [];
    memberships = [];
  }

  let notifications = { unreadCount: 0, unread: [] };
  try {
    if (userId) {
      const unreadCount = await Notification.count({ where: { recipient_id: userId, is_read: false } });
      const unreadRows = unreadCount === 0 ? [] : await Notification.findAll({
        where: { recipient_id: userId, is_read: false },
        attributes: ['id', 'type', 'message', 'payload', 'created_at'],
        include: [{ model: User, as: 'sender', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
        order: [['created_at', 'DESC']],
        limit: maxNotifications,
      });
      notifications = {
        unreadCount: Number(unreadCount || 0),
        unread: (unreadRows || []).map((n) => ({
          id: Number(n.id),
          type: String(n.type || ''),
          message: String(n.message || ''),
          createdAt: n.created_at ? new Date(n.created_at).toISOString() : null,
          sender: n.sender ? { id: String(n.sender.id), name: displayName(n.sender) } : null,
        })),
      };
    }
  } catch (_) {
    notifications = { unreadCount: 0, unread: [] };
  }

  const snapshot = {
    generatedAt: new Date().toISOString(),
    viewer: user ? { id: String(user.id || ''), name: displayName(user), role: String(user.role || '') } : null,
    projects,
    sprints,
    deliverables,
    tickets,
    users,
    memberships,
    assignments,
    notifications,
  };

  if ((fullAccess || isAdmin) && includeAllUsers) {
    const allUsers = await User.findAll({
      attributes: ['id', 'email', 'first_name', 'last_name', 'role', 'is_active'],
      order: [['created_at', 'DESC']],
      limit: Number(process.env.AI_CONTEXT_MAX_USERS || 500),
    });
    snapshot.allUsers = (allUsers || []).map((u) => ({
      id: String(u.id),
      name: displayName(u),
      email: u.email ? String(u.email) : null,
      role: u.role ? String(u.role) : null,
      isActive: u.is_active === undefined ? null : !!u.is_active,
    }));
  }

  return snapshot;
}

async function buildAppDataSnapshot(user) {
  const data = await buildAppDataSnapshotData(user);
  return JSON.stringify(data);
}

function lastUserTextFromMessages(msgs) {
  const arr = Array.isArray(msgs) ? msgs : [];
  for (let i = arr.length - 1; i >= 0; i -= 1) {
    const m = arr[i];
    if (m && String(m.role || '').toLowerCase() === 'user') {
      return String(m.content || '').trim();
    }
  }
  return '';
}

function isListOrCountQuery(text) {
  const t = String(text || '').toLowerCase();
  return /how many|number of|count|list|names?\b|show\b/.test(t);
}

function isNotificationsDataQuery(text) {
  const t = String(text || '').toLowerCase().trim();
  if (!/\bnotifications?\b|\balerts?\b/.test(t)) return false;
  if (/\bgo to\b|\bopen\b|\bnavigate\b|\bswitch to\b|\broute me\b/.test(t)) return false;
  return /\bhow many\b|\bnumber of\b|\bcount\b|\blist\b|\bshow\b|\bunread\b|\bnew\b/.test(t) || t === 'notifications' || t === 'alerts';
}

function answerFromSnapshot(snapshot, userText) {
  const t = String(userText || '').toLowerCase();
  if (!snapshot || typeof snapshot !== 'object') return null;

  let wantsProjects = /\bprojects?\b/.test(t);
  let wantsSprints = /\bsprints?\b/.test(t);
  let wantsUsers = /\busers?\b|\bteam\b|\bmembers?\b/.test(t);
  let wantsDeliverables = /\bdeliverables?\b/.test(t);
  let wantsNotifications = /\bnotifications?\b|\balerts?\b/.test(t);

  const wantsNames = /\bnames?\b|\blist\b|\bshow\b/.test(t);
  const wantsCount = /\bhow many\b|\bnumber of\b|\bcount\b/.test(t);
  if ((wantsNames || wantsCount) && !wantsProjects && !wantsSprints && !wantsUsers && !wantsDeliverables) {
    const topic = snapshot && snapshot.__topic ? String(snapshot.__topic) : '';
    if (topic === 'projects') wantsProjects = true;
    if (topic === 'sprints') wantsSprints = true;
    if (topic === 'users') wantsUsers = true;
    if (topic === 'deliverables') wantsDeliverables = true;
  }

  if (wantsSprints && (wantsNames || wantsCount)) {
    const sprints = Array.isArray(snapshot.sprints) ? snapshot.sprints : [];
    if (wantsCount && !wantsNames) {
      const completed = sprints.filter((s) => isSprintCompletedStatus(s.status)).length;
      const active = sprints.length - completed;
      return `Sprints: total=${sprints.length}, active=${active}, completed=${completed}.`;
    }
    if (sprints.length === 0) return 'No sprints found in the snapshot.';
    const lines = sprints.map((s) => `- ${s.name} (${s.projectKey || 'no project'}, ${s.status || 'unknown'})`);
    return `Sprint names (${sprints.length}):\n` + lines.join('\n');
  }

  if (wantsProjects && (wantsNames || wantsCount)) {
    const projects = Array.isArray(snapshot.projects) ? snapshot.projects : [];
    if (wantsCount && !wantsNames) {
      const statuses = {};
      for (const p of projects) {
        const s = String(p.status || 'unknown').toLowerCase();
        statuses[s] = (statuses[s] || 0) + 1;
      }
      const breakdown = Object.entries(statuses).map(([s, c]) => `${s}=${c}`).join(', ');
      return `Projects: total=${projects.length}${breakdown ? ` (${breakdown})` : ''}.`;
    }
    if (projects.length === 0) return 'No projects found in the snapshot.';
    const lines = projects.map((p) => `- ${p.name} (${p.key || 'no key'}, ${p.status || 'unknown'})`);
    return `Project names (${projects.length}):\n` + lines.join('\n');
  }

  if (wantsDeliverables && (wantsNames || wantsCount)) {
    const deliverables = Array.isArray(snapshot.deliverables) ? snapshot.deliverables : [];
    if (wantsCount && !wantsNames) return `Deliverables: total=${deliverables.length}.`;
    if (deliverables.length === 0) return 'No deliverables found in the snapshot.';
    const lines = deliverables.map((d) => `- ${d.title} (${d.projectKey || 'no project'}, ${d.status || 'unknown'})`);
    return `Deliverables (${deliverables.length}):\n` + lines.join('\n');
  }

  if (wantsUsers && (wantsNames || wantsCount)) {
    const users = Array.isArray(snapshot.allUsers) ? snapshot.allUsers : (Array.isArray(snapshot.users) ? snapshot.users : []);
    if (wantsCount && !wantsNames) return `Users: total=${users.length}.`;
    if (users.length === 0) return 'No users found in the snapshot.';
    const lines = users.map((u) => `- ${u.name}${u.role ? ` (${u.role})` : ''}`);
    return `Users (${users.length}):\n` + lines.join('\n');
  }

  if (wantsNotifications && (wantsNames || wantsCount || /\bunread\b|\bnew\b|\bnotifications?\b|\balerts?\b/.test(t))) {
    const notif = snapshot.notifications && typeof snapshot.notifications === 'object' ? snapshot.notifications : { unreadCount: 0, unread: [] };
    const unreadCount = Number(notif.unreadCount || 0);
    const unread = Array.isArray(notif.unread) ? notif.unread : [];
    if (wantsCount && !wantsNames) {
      return `Unread notifications: ${unreadCount}.`;
    }
    if (unreadCount === 0 || unread.length === 0) {
      return 'You have no unread notifications.';
    }
    const lines = unread.slice(0, 10).map((n) => {
      const created = n.createdAt ? String(n.createdAt).slice(0, 16).replace('T', ' ') : '';
      const sender = n.sender && n.sender.name ? ` • from ${n.sender.name}` : '';
      const type = n.type ? `[${n.type}] ` : '';
      return `- ${type}${n.message}${created ? ` • ${created}` : ''}${sender}`;
    });
    return `Unread notifications (${unreadCount}):\n` + lines.join('\n');
  }

  return null;
}

async function answerFromDb(userText, topicHint) {
  const t = String(userText || '').toLowerCase();
  const wantsNames = /\bnames?\b|\blist\b|\bshow\b/.test(t);
  const wantsCount = /\bhow many\b|\bnumber of\b|\bcount\b/.test(t);
  if (!wantsNames && !wantsCount) return null;

  let wantsProjects = /\bprojects?\b/.test(t);
  let wantsSprints = /\bsprints?\b/.test(t);
  let wantsUsers = /\busers?\b|\bteam\b|\bmembers?\b/.test(t);
  let wantsDeliverables = /\bdeliverables?\b/.test(t);
  if (!wantsProjects && !wantsSprints && !wantsUsers && !wantsDeliverables) {
    const hint = String(topicHint || '');
    if (hint === 'projects') wantsProjects = true;
    if (hint === 'sprints') wantsSprints = true;
    if (hint === 'users') wantsUsers = true;
    if (hint === 'deliverables') wantsDeliverables = true;
  }

  const limitProjects = Number(process.env.AI_LIST_MAX_PROJECTS || 200);
  const limitSprints = Number(process.env.AI_LIST_MAX_SPRINTS || 500);
  const limitDeliverables = Number(process.env.AI_LIST_MAX_DELIVERABLES || 500);
  const limitUsers = Number(process.env.AI_LIST_MAX_USERS || 500);

  if (wantsProjects) {
    const projects = await Project.findAll({
      attributes: ['id', 'key', 'name', 'status'],
      order: [['updated_at', 'DESC']],
      limit: limitProjects,
    });
    if (wantsCount && !wantsNames) {
      const statuses = {};
      for (const p of projects) {
        const s = String(p.status || 'unknown').toLowerCase();
        statuses[s] = (statuses[s] || 0) + 1;
      }
      const breakdown = Object.entries(statuses).map(([s, c]) => `${s}=${c}`).join(', ');
      return `Projects: total=${projects.length}${breakdown ? ` (${breakdown})` : ''}.`;
    }
    if (projects.length === 0) return 'No projects found.';
    const lines = projects.map((p) => `- ${p.name} (${p.key || 'no key'}, ${p.status || 'unknown'})`);
    return `Project names (${projects.length}):\n` + lines.join('\n');
  }

  if (wantsSprints) {
    const sprints = await Sprint.findAll({
      attributes: ['id', 'project_id', 'name', 'status'],
      order: [['updated_at', 'DESC']],
      limit: limitSprints,
    });
    if (wantsCount && !wantsNames) {
      const completed = sprints.filter((s) => isSprintCompletedStatus(s.status)).length;
      const active = sprints.length - completed;
      return `Sprints: total=${sprints.length}, active=${active}, completed=${completed}.`;
    }
    if (sprints.length === 0) return 'No sprints found.';
    const projectIds = Array.from(new Set(sprints.map((s) => String(s.project_id || '')).filter(Boolean)));
    const projects = projectIds.length === 0 ? [] : await Project.findAll({
      where: { id: { [Op.in]: projectIds } },
      attributes: ['id', 'key'],
    });
    const keyById = new Map((projects || []).map((p) => [String(p.id), String(p.key || '')]));
    const lines = sprints.map((s) => `- ${s.name} (${keyById.get(String(s.project_id || '')) || 'no project'}, ${s.status || 'unknown'})`);
    return `Sprint names (${sprints.length}):\n` + lines.join('\n');
  }

  if (wantsDeliverables) {
    const deliverables = await Deliverable.findAll({
      attributes: ['id', 'project_id', 'title', 'status'],
      order: [['updated_at', 'DESC']],
      limit: limitDeliverables,
    });
    if (wantsCount && !wantsNames) return `Deliverables: total=${deliverables.length}.`;
    if (deliverables.length === 0) return 'No deliverables found.';
    const projectIds = Array.from(new Set(deliverables.map((d) => String(d.project_id || '')).filter(Boolean)));
    const projects = projectIds.length === 0 ? [] : await Project.findAll({
      where: { id: { [Op.in]: projectIds } },
      attributes: ['id', 'key'],
    });
    const keyById = new Map((projects || []).map((p) => [String(p.id), String(p.key || '')]));
    const lines = deliverables.map((d) => `- ${d.title} (${keyById.get(String(d.project_id || '')) || 'no project'}, ${d.status || 'unknown'})`);
    return `Deliverables (${deliverables.length}):\n` + lines.join('\n');
  }

  if (wantsUsers) {
    const users = await User.findAll({
      attributes: ['id', 'email', 'first_name', 'last_name', 'role', 'is_active'],
      order: [['created_at', 'DESC']],
      limit: limitUsers,
    });
    if (wantsCount && !wantsNames) return `Users: total=${users.length}.`;
    if (users.length === 0) return 'No users found.';
    const lines = users.map((u) => `- ${displayName(u)}${u.role ? ` (${u.role})` : ''}`);
    return `Users (${users.length}):\n` + lines.join('\n');
  }

  return null;
}

function isAllProjectsSummaryQuery(text) {
  const t = String(text || '').toLowerCase();
  if (!/\bprojects?\b/.test(t)) return false;
  return /\ball\b/.test(t) && /\b(status|progress|overview|summary|details|report)\b/.test(t);
}

function isDeliverableScopedQuery(text) {
  const t = String(text || '').toLowerCase();
  if (!/\bdeliverables?\b/.test(t)) return false;
  return /\b(details|info|overview|status|priority|due date|owner|sprints|signoffs|artifacts|progress|quality)\b/.test(t);
}

function isSprintScopedQuery(text) {
  const t = String(text || '').toLowerCase();
  if (!/\bsprints?\b/.test(t)) return false;
  return /\b(details|info|overview|status|progress|report|analysis|summary|risk|health|team|deliverables)\b/.test(t);
}

function isProjectScopedQuery(text) {
  const t = String(text || '').toLowerCase();
  if (!/\bproject\b/.test(t)) return false;
  return /\b(details|info|overview|status|progress|owner|sprints?|deliverables?|reports?)\b/.test(t) || /\bassociated\b/.test(t);
}

function isNavigationQuery(text) {
  const t = String(text || '').toLowerCase();
  return /\b(navigate|go to|open|take me|bring me|show me|view|switch to|route me|send me)\b/.test(t);
}

function wantsNavigationChatConfirmation(text) {
  const t = String(text || '').toLowerCase();
  return /\b(explain|why|summary|details|tell me|describe|what should i know)\b/.test(t);
}

function inferRouteFromText(text) {
  const t = String(text || '').toLowerCase();
  if (/\bdashboard\b/.test(t) || /\bhome\b/.test(t)) return '/dashboard';
  if (/\bprojects\b/.test(t) && !/\bproject\b/.test(t)) return '/projects';
  if (/\bdeliverables?\b/.test(t)) return '/deliverables-overview';
  if (/\bapprovals?\b/.test(t) || /\bapproval requests?\b/.test(t)) return '/approvals';
  if (/\brepository\b/.test(t) || /\bdocuments?\b/.test(t) || /\bfiles?\b/.test(t)) return '/repository';
  if (/\bnotifications?\b/.test(t) || /\balerts?\b/.test(t)) return '/notifications';
  if (/\bsettings?\b/.test(t)) return '/settings';
  if (/\bprofile\b/.test(t) || /\baccount\b/.test(t)) return '/profile';
  if (/\bai assistant\b/.test(t) || /\bassistant\b/.test(t)) return '/ai-assistant';
  return null;
}

async function buildNavigationActionFromText(userText, snapshotData) {
  const t = String(userText || '').toLowerCase();

  if (/\bproject\b/.test(t)) {
    const project = await findProjectFromText(userText, snapshotData);
    if (!project) return null;
    const projectId = String(project.id);
    const wantsDetails = /\b(details|detail|overview|info|status)\b/.test(t);
    const wantsWorkspace = /\b(workspace|board|kanban|sprint board)\b/.test(t);
    const route = wantsDetails ? `/project-details/${projectId}` : (wantsWorkspace ? `/project-workspace/${projectId}` : `/project-details/${projectId}`);
    const name = project.name ? String(project.name) : 'project';
    const key = project.key ? String(project.key) : '';
    const label = key ? `${name} (${key})` : name;
    return { route, label };
  }

  if (/\bdeliverable\b/.test(t)) {
    const deliverable = await findDeliverableFromText(userText, snapshotData);
    if (!deliverable) return null;
    const deliverableId = String(deliverable.id);
    const title = deliverable.title ? String(deliverable.title) : 'deliverable';
    return { route: `/deliverables/${deliverableId}`, label: title };
  }

  const directRoute = inferRouteFromText(userText);
  if (directRoute) {
    return { route: directRoute, label: directRoute };
  }

  return null;
}

async function findDeliverableFromText(text, snapshotData) {
  const raw = String(text || '');
  const t = raw.toLowerCase();
  const deliverables = snapshotData && Array.isArray(snapshotData.deliverables) ? snapshotData.deliverables : null;

  const uuidMatch = raw.match(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i);
  if (uuidMatch) {
    const id = uuidMatch[0];
    if (deliverables) {
      const d = deliverables.find((x) => String(x.id || '').toLowerCase() === id.toLowerCase());
      if (d) return d;
    }
    try {
      const d = await Deliverable.findByPk(id, { attributes: ['id', 'title', 'status', 'project_id'] });
      if (d) return d;
    } catch (_) {}
  }

  const explicit = parseKeyValueLines(raw);
  const explicitDeliverable = explicit.deliverable || explicit.deliverable_id || explicit.deliverable_title || '';
  if (explicitDeliverable) {
    const maybeId = String(explicitDeliverable).trim();
    if (/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i.test(maybeId)) {
      try {
        const d = await Deliverable.findByPk(maybeId, { attributes: ['id', 'title', 'status', 'project_id'] });
        if (d) return d;
      } catch (_) {}
    }
  }

  let titleQuery = '';
  try {
    const m = raw.match(/\bdeliverable\b\s*(?:named\s*)?(?:"([^"]+)"|'([^']+)'|([^\n\r]+))/i);
    titleQuery = String((m && (m[1] || m[2] || m[3])) || '').trim();
  } catch (_) {}
  if (!titleQuery && explicitDeliverable) titleQuery = String(explicitDeliverable).trim();
  if (titleQuery) {
    titleQuery = titleQuery
      .replace(/\b(details?|overview|info|status|page|screen)\b/ig, '')
      .replace(/\s+/g, ' ')
      .trim();
  }
  if (!titleQuery) return null;

  let best = null;
  let bestScore = 0;
  const candidates = deliverables || (await Deliverable.findAll({ attributes: ['id', 'title', 'status', 'project_id'], order: [['updated_at', 'DESC']], limit: 200 }));
  for (const d of candidates || []) {
    const title = String(d.title || '').toLowerCase();
    if (!title) continue;
    let score = 0;
    if (title === titleQuery.toLowerCase()) score = 1000;
    else if (t.includes(title)) score = 500 + title.length;
    else if (title.includes(titleQuery.toLowerCase())) score = 300 + titleQuery.length;
    if (score > bestScore) {
      bestScore = score;
      best = d;
    }
  }
  if (best && bestScore >= 320) {
    if (best instanceof Deliverable) return best;
    const id = String(best.id || '');
    try {
      const d = await Deliverable.findByPk(id, { attributes: ['id', 'title', 'status', 'project_id'] });
      if (d) return d;
    } catch (_) {}
    return best;
  }

  const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
  const likeOp = dialect === 'postgres' ? Op.iLike : Op.like;
  try {
    const rows = await Deliverable.findAll({
      attributes: ['id', 'title', 'status', 'project_id'],
      where: { title: { [likeOp]: `%${titleQuery}%` } },
      order: [['updated_at', 'DESC']],
      limit: 25,
    });
    if (rows && rows[0]) return rows[0];
  } catch (_) {}

  return null;
}

async function findProjectFromText(text, snapshotData) {
  const raw = String(text || '');
  const t = raw.toLowerCase();
  const projects = snapshotData && Array.isArray(snapshotData.projects) ? snapshotData.projects : null;

  const explicit = parseKeyValueLines(raw);
  const explicitProject = explicit.project || explicit.project_key || explicit.project_name || '';
  if (explicitProject) {
    const id = await resolveProjectIdFromInput(explicitProject, snapshotData || {});
    if (id) {
      const p = await Project.findByPk(id, { attributes: ['id', 'key', 'name', 'status', 'start_date', 'end_date', 'owner_id'] });
      if (p) return p;
    }
  }

  let best = null;
  let bestScore = 0;

  const candidates = projects || (await Project.findAll({ attributes: ['id', 'key', 'name', 'status', 'start_date', 'end_date', 'owner_id'], order: [['updated_at', 'DESC']], limit: 200 }));
  for (const p of candidates || []) {
    const key = String(p.key || '').toLowerCase();
    const name = String(p.name || '').toLowerCase();
    let score = 0;
    if (key && t.includes(key)) score = 100 + key.length;
    else if (name && t.includes(name)) score = 80 + name.length;
    if (score > bestScore) {
      bestScore = score;
      best = p;
    }
  }

  if (best && bestScore >= 85) {
    if (best instanceof Project) return best;
    const id = String(best.id || '');
    const p = await Project.findByPk(id, { attributes: ['id', 'key', 'name', 'status', 'start_date', 'end_date', 'owner_id'] });
    return p || null;
  }

  const m = raw.match(/project\s*[:\-]?\s*["']?([A-Za-z0-9 _-]{2,60})["']?/i);
  if (m && m[1]) {
    const id = await resolveProjectIdFromInput(m[1], snapshotData || {});
    if (id) {
      const p = await Project.findByPk(id, { attributes: ['id', 'key', 'name', 'status', 'start_date', 'end_date', 'owner_id'] });
      return p || null;
    }
  }

  return null;
}

function fmtDate(v) {
  if (!v) return null;
  try { return new Date(v).toISOString().slice(0, 10); } catch (_) { return null; }
}

async function listProjectReportsByDeliverableIds(deliverableIds) {
  const ids = (deliverableIds || []).map((id) => String(id)).filter(Boolean);
  if (ids.length === 0) return [];
  try {
    await ensureReportsTable();
    const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
    if (dialect === 'postgres') {
      const [rows] = await sequelize.query(
        "SELECT id, deliverable_id, status, created_at, content FROM sign_off_reports WHERE deliverable_id = ANY($1::text[]) ORDER BY created_at DESC LIMIT 50",
        { bind: [ids] }
      );
      return Array.isArray(rows) ? rows : [];
    }
    const placeholders = ids.map((_, i) => `$${i + 1}`).join(', ');
    const [rows] = await sequelize.query(
      `SELECT id, deliverable_id, status, created_at, content FROM sign_off_reports WHERE deliverable_id IN (${placeholders}) ORDER BY created_at DESC LIMIT 50`,
      { bind: ids }
    );
    return Array.isArray(rows) ? rows : [];
  } catch (_) {
    return [];
  }
}

async function buildSprintDetailsData(userText, snapshotData) {
  const raw = String(userText || '');
  const t = raw.toLowerCase();
  const sprints = snapshotData && Array.isArray(snapshotData.sprints) ? snapshotData.sprints : null;

  let sprintId = null;
  const uuidMatch = raw.match(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i);
  if (uuidMatch) {
    sprintId = uuidMatch[0];
  } else {
    const m = raw.match(/sprint\s*[:\-]?\s*["'`“”]?([^\n"'`“”]{1,120})/i);
    const sprintName = m ? m[1].trim().replace(/[.?!]\s*$/g, '') : '';
    if (sprintName) {
      if (/^\d+$/.test(sprintName)) {
        const n = parseInt(sprintName, 10);
        sprintId = Number.isFinite(n) ? n : sprintName;
      } else {
      const candidates = sprints || (await Sprint.findAll({ attributes: ['id', 'name'], order: [['updated_at', 'DESC']], limit: 200 }));
      const needle = sprintName.toLowerCase();
      const normalize = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
      const found = candidates.find((s) => String(s.name || '').toLowerCase() === needle)
        || candidates.find((s) => String(s.name || '').toLowerCase().includes(needle))
        || candidates.find((s) => needle.includes(String(s.name || '').toLowerCase()))
        || candidates.find((s) => normalize(String(s.name || '')) === normalize(needle))
        || candidates.find((s) => normalize(String(s.name || '')).includes(normalize(needle)));
      if (found) sprintId = found.id;
      }
    }
  }

  if (!sprintId) return null;
  if (typeof sprintId === 'string' && /^\d+$/.test(sprintId)) {
    const n = parseInt(sprintId, 10);
    if (Number.isFinite(n)) sprintId = n;
  }

  try {
    const sprintController = require('../controllers/sprintController');
    const report = await sprintController.buildSprintReportFromDb({ id: sprintId, query: {} });
    return report;
  } catch (_) {
    return null;
  }
}

async function buildSprintReportById(sprintIdRaw) {
  const raw = String(sprintIdRaw || '').trim();
  if (!raw) return { report: null, notFound: true, error: 'missing_sprint_id' };
  let id = raw;
  if (/^\d+$/.test(raw)) {
    const n = parseInt(raw, 10);
    if (Number.isFinite(n)) id = n;
  }
  try {
    const sprintController = require('../controllers/sprintController');
    const report = await sprintController.buildSprintReportFromDb({ id, query: {} });
    return { report, notFound: false, error: null };
  } catch (e) {
    const msg = (e && e.message) ? String(e.message) : 'sprint_report_failed';
    const notFound =
      (e && (e.statusCode === 404 || e.status === 404)) ||
      /sprint not found/i.test(msg);
    return { report: null, notFound, error: msg };
  }
}

async function getSprintSelectionOptions(snapshotData, limit = 12) {
  const fromSnapshot = snapshotData && Array.isArray(snapshotData.sprints)
    ? snapshotData.sprints
        .map((s) => ({ id: s && s.id != null ? String(s.id) : '', name: s && s.name ? String(s.name) : '' }))
        .filter((s) => s.id && s.name)
    : [];

  if (fromSnapshot.length > 0) {
    const seen = new Set();
    const unique = [];
    for (const s of fromSnapshot) {
      if (seen.has(s.id)) continue;
      seen.add(s.id);
      unique.push(s);
      if (unique.length >= limit) break;
    }
    return unique;
  }

  try {
    const rows = await Sprint.findAll({ attributes: ['id', 'name'], order: [['updated_at', 'DESC']], limit: Math.max(20, limit) });
    const list = (rows || []).map((s) => ({ id: String(s.id), name: String(s.name || '').trim() })).filter((s) => s.id && s.name);
    return list.slice(0, limit);
  } catch (_) {
    return [];
  }
}

function formatSprintOptionsForPrompt(options) {
  if (!options || options.length === 0) return '';
  const lines = [];
  for (let i = 0; i < options.length; i += 1) {
    const s = options[i];
    lines.push(`${i + 1}) ${String(s.name)}`);
  }
  return lines.join('\n');
}

function resolveSprintIdFromSelectionText(userText, options) {
  const raw = String(userText || '').trim();
  const kv = parseKeyValueLines(raw);
  const value = (kv.sprint ? String(kv.sprint) : raw).trim();
  if (!value) return null;

  if (/^\d+$/.test(value)) {
    const idx = parseInt(value, 10);
    if (Number.isFinite(idx) && idx >= 1 && idx <= (options || []).length) {
      const chosen = options[idx - 1];
      return chosen && chosen.id ? String(chosen.id) : null;
    }
    return null;
  }

  const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const needle = value.toLowerCase();
  const needleNorm = norm(value);

  const byId = (options || []).find((o) => String(o.id) === value);
  if (byId) return String(byId.id);
  const byExact = (options || []).find((o) => String(o.name || '').toLowerCase() === needle);
  if (byExact) return String(byExact.id);
  const byIncludes = (options || []).find((o) => String(o.name || '').toLowerCase().includes(needle));
  if (byIncludes) return String(byIncludes.id);
  const byNorm = (options || []).find((o) => norm(o.name) === needleNorm || norm(o.name).includes(needleNorm));
  if (byNorm) return String(byNorm.id);

  return null;
}

function fmtIsoDate(iso) {
  try {
    if (!iso) return '';
    return String(iso).slice(0, 10);
  } catch (_) {
    return '';
  }
}

function buildManualSprintReportText(report, reportTitle, feedback) {
  if (!report || typeof report !== 'object') return '';
  const sprint = report.sprint && typeof report.sprint === 'object' ? report.sprint : {};
  const summary = report.summary && typeof report.summary === 'object' ? report.summary : {};
  const team = report.team && report.team.members && Array.isArray(report.team.members) ? report.team.members : [];
  const deliverables = Array.isArray(report.deliverables) ? report.deliverables : [];

  const sprintName = String(sprint.name || 'Sprint');
  const title = reportTitle ? String(reportTitle) : sprintName;
  const project = sprint.project && typeof sprint.project === 'object' ? sprint.project : null;
  const projectLabel = project ? `${String(project.name || '').trim()}${project.key ? ` (${String(project.key)})` : ''}`.trim() : '';
  const start = fmtIsoDate(sprint.startDate);
  const end = fmtIsoDate(sprint.endDate);
  const status = String(sprint.status || '').trim() || 'planning';
  const health = String(summary.health || '').trim() || 'good';
  const progress = Number(summary.sprintProgressPercent || 0);
  const completionRate = Number(summary.completionRatePercent || 0);
  const overdue = Number(summary.overdueDeliverables || 0);
  const blocked = Number(summary.blockedDeliverables || 0);
  const dash = (v) => (v ? String(v) : '-');

  const lines = [];
  lines.push(title);
  if (reportTitle && title !== sprintName) lines.push(`Sprint: ${sprintName}`);
  if (projectLabel) lines.push(`Project: ${projectLabel}`);
  if (start || end) lines.push(`Duration: ${start || '-'} → ${end || '-'}`);
  lines.push(`Status: ${status}`);
  if (team.length > 0) {
    lines.push(`Team: ${team.map((m) => String(m.name || m.email || '').trim()).filter(Boolean).slice(0, 6).join(', ')}`);
  }
  lines.push(`Sprint Progress: ${progress}%`);
  if (team.length > 0) {
    // already added above
  }
  lines.push('');
  lines.push('Summary');
  lines.push(`- Total: ${Number(summary.totalDeliverables || 0)}`);
  lines.push(`- Completed: ${Number(summary.completedDeliverables || 0)}`);
  lines.push(`- In Progress: ${Number(summary.inProgressDeliverables || 0)}`);
  lines.push(`- Not Started: ${Number(summary.notStartedDeliverables || 0)}`);
  lines.push(`- Overdue: ${Number(summary.overdueDeliverables || 0)}`);
  lines.push(`- Blocked: ${Number(summary.blockedDeliverables || 0)}`);
  lines.push('');
  lines.push('Deliverables');
  if (deliverables.length === 0) {
    lines.push('- No deliverables found for this sprint.');
  } else {
    for (const d of deliverables) {
      const name = String(d.name || d.title || '').trim() || `Deliverable ${String(d.id || '').trim()}`;
      const owner = String(d.ownerName || '').trim() || '-';
      const st = String(d.status || '').trim() || '-';
      const pct = Number(d.progressPercent || 0);
      const due = dash(fmtIsoDate(d.dueDate));
      const completion = dash(fmtIsoDate(d.completionDate));
      lines.push(`- ${name} | ${owner} | ${st} | ${pct}% | ${due} | ${completion}`);
    }
  }
  lines.push('');
  lines.push('Sprint Insights');
  lines.push(`- Completion Rate: ${completionRate}%`);
  lines.push(`- Delayed Deliverables: ${overdue}`);
  lines.push(`- Blocked Deliverables: ${blocked}`);
  lines.push(`- Overall Sprint Health: ${String(health).toUpperCase()}`);
  lines.push('');
  lines.push('Feedback');
  lines.push((feedback && String(feedback).trim()) ? String(feedback).trim() : '-');

  return lines.join('\n').trim();
}

function normalizePossibleNote(value) {
  const s = String(value || '').trim();
  if (!s) return '';
  if (s.length > 2000) return s.slice(0, 2000);
  return s;
}

function extractSignoffNoteFromText(text) {
  const raw = String(text || '').trim();
  if (!raw) return '';
  const kv = parseKeyValueLines(raw);
  const note =
    kv.signoff_note ||
    kv.sign_off_note ||
    kv.note ||
    kv.notes ||
    kv.comment ||
    kv.comments ||
    '';
  if (note) return normalizePossibleNote(note);
  const m = raw.match(/(?:sign[- ]?off\s*note|note|notes)\s*(?:is|:|-)\s*(.+)$/i);
  if (m && m[1]) return normalizePossibleNote(m[1]);
  return '';
}

function normalizePossibleFeedback(value) {
  const s = String(value || '').trim();
  if (!s) return '';
  if (s.length > 2000) return s.slice(0, 2000);
  return s;
}

function extractFeedbackFromText(text) {
  const raw = String(text || '').trim();
  if (!raw) return '';
  const kv = parseKeyValueLines(raw);
  const fb =
    kv.feedback ||
    kv.user_feedback ||
    kv.comment ||
    kv.comments ||
    kv.feedback_comment ||
    '';
  if (fb) return normalizePossibleFeedback(fb);
  const m = raw.match(/(?:feedback|comment|comments)\s*(?:is|:|-)\s*(.+)$/i);
  if (m && m[1]) return normalizePossibleFeedback(m[1]);
  return '';
}

function buildSprintSignoffReportText(sprintReport, reportTitle, note, feedback) {
  if (!sprintReport || typeof sprintReport !== 'object') return '';
  const sprint = sprintReport.sprint && typeof sprintReport.sprint === 'object' ? sprintReport.sprint : {};
  const project = sprint.project && typeof sprint.project === 'object' ? sprint.project : null;
  const summary = sprintReport.summary && typeof sprintReport.summary === 'object' ? sprintReport.summary : {};
  const team = sprintReport.team && sprintReport.team.members && Array.isArray(sprintReport.team.members)
    ? sprintReport.team.members
    : [];
  const deliverables = Array.isArray(sprintReport.deliverables) ? sprintReport.deliverables : [];

  const fmt = (v) => (v == null || String(v).trim() === '' ? '-' : String(v));
  const fmtIso = (iso) => {
    if (!iso) return '-';
    try {
      const d = new Date(iso);
      if (Number.isNaN(d.getTime())) return String(iso);
      return d.toISOString().slice(0, 10);
    } catch (_) {
      return String(iso);
    }
  };
  const fmtPct = (n) => `${Number(n || 0)}%`;

  const sprintName = fmt(sprint.name || 'Sprint');
  const title = reportTitle && String(reportTitle).trim() ? String(reportTitle).trim() : `Sprint Report: ${sprintName}`;
  const lines = [];
  lines.push(title);
  lines.push('');
  lines.push('PROJECT');
  lines.push(`Name: ${fmt(project && project.name)}`);
  lines.push(`Key: ${fmt(project && project.key)}`);
  lines.push(`ID: ${fmt(project && project.id)}`);
  lines.push('');
  lines.push('SPRINT');
  lines.push(`Name: ${sprintName}`);
  lines.push(`ID: ${fmt(sprint.id)}`);
  lines.push(`Status: ${fmt(sprint.status)}`);
  lines.push(`Start: ${fmtIso(sprint.startDate)}`);
  lines.push(`End: ${fmtIso(sprint.endDate)}`);
  lines.push('');
  lines.push('SPRINT SUMMARY');
  lines.push(`Total Deliverables: ${Number(summary.totalDeliverables || 0)}`);
  lines.push(`Completed: ${Number(summary.completedDeliverables || 0)}`);
  lines.push(`In Progress: ${Number(summary.inProgressDeliverables || 0)}`);
  lines.push(`Not Started: ${Number(summary.notStartedDeliverables || 0)}`);
  lines.push(`Overdue: ${Number(summary.overdueDeliverables || 0)}`);
  lines.push(`Blocked: ${Number(summary.blockedDeliverables || 0)}`);
  lines.push(`Sprint Progress: ${fmtPct(summary.sprintProgressPercent)}`);
  lines.push(`Completion Rate: ${fmtPct(summary.completionRatePercent)}`);
  lines.push(`Health: ${fmt(summary.health).toUpperCase()}`);
  lines.push('');
  lines.push('TEAM MEMBERS');
  if (team.length === 0) {
    lines.push('None');
  } else {
    for (const m of team) {
      lines.push(`- ${fmt(m.name)} | ${fmt(m.email)} | ${fmt(m.role)}`);
    }
  }
  lines.push('');
  lines.push('DELIVERABLES');
  if (deliverables.length === 0) {
    lines.push('None');
  } else {
    for (const d of deliverables) {
      lines.push(
        `- ${fmt(d.name || d.title)} | Owner: ${fmt(d.ownerName)} | Status: ${fmt(d.status)} | Progress: ${fmtPct(d.progressPercent)} | Due: ${fmtIso(d.dueDate)} | Completed: ${fmtIso(d.completionDate)} | Category: ${fmt(d.category)} | Overdue: ${d.isOverdue ? 'yes' : 'no'}`
      );
    }
  }
  lines.push('');
  lines.push('SIGN-OFF NOTES');
  lines.push(note && String(note).trim() ? String(note).trim() : '-');
  lines.push('');
  lines.push('FEEDBACK');
  lines.push((feedback && String(feedback).trim()) ? String(feedback).trim() : '-');
  return lines.join('\n').trim();
}

async function buildAllProjectsSummaryData(snapshotData) {
  const projects = snapshotData && Array.isArray(snapshotData.projects) ? snapshotData.projects : [];
  if (projects.length === 0) return null;
  return {
    count: projects.length,
    projects: projects.map((p) => ({
      name: p.name,
      key: p.key,
      status: p.status,
      sprints: p.sprints,
      deliverables: p.deliverables,
      startDate: p.startDate,
      endDate: p.endDate,
    })),
  };
}

async function buildDeliverableDetailsData(userText, snapshotData) {
  const deliverable = await findDeliverableFromText(userText, snapshotData);
  if (!deliverable) return null;

  const deliverableId = String(deliverable.id);
  const deliverableRow = deliverable instanceof Deliverable
    ? deliverable
    : await Deliverable.findByPk(deliverableId, {
        include: [
          { association: 'contributing_sprints' },
          { association: 'signoffs' },
          { association: 'artifacts' },
          { model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }
        ]
      });

  if (!deliverableRow) return null;

  const data = deliverableRow.toJSON ? deliverableRow.toJSON() : deliverableRow;
  
  // Format for AI
  return {
    id: data.id,
    title: data.title,
    description: data.description,
    status: data.status,
    priority: data.priority,
    dueDate: data.due_date,
    owner: data.owner ? { name: displayName(data.owner), role: data.owner.role } : null,
    sprints: (data.contributing_sprints || []).map(s => ({ name: s.name, status: s.status })),
    signoffs: (data.signoffs || []).map(s => ({ decision: s.decision, comments: s.comments })),
    artifacts: (data.artifacts || []).map(a => ({ name: a.name, type: a.type })),
    progress: deliverableProgressPercent ? deliverableProgressPercent(data.status) : null,
    quality: {
      testPassRate: data.test_pass_rate,
      codeCoverage: data.code_coverage,
      escapedDefects: data.escaped_defects
    }
  };
}

async function buildProjectDetailsData(userText, snapshotData) {
  const project = await findProjectFromText(userText, snapshotData);
  if (!project) return null;

  const projectId = String(project.id);
  const projectRow = project instanceof Project
    ? project
    : await Project.findByPk(projectId, { attributes: ['id', 'key', 'name', 'status', 'description', 'client_name', 'client_owner_name', 'project_type', 'start_date', 'end_date', 'owner_id', 'metadata'] });

  if (!projectRow) return null;

  const owner = projectRow.owner_id
    ? await User.findByPk(projectRow.owner_id, { attributes: ['id', 'email', 'first_name', 'last_name', 'role'] })
    : null;

  const sprintsRaw = await Sprint.findAll({
    where: { project_id: projectId },
    attributes: [
      'id',
      'name',
      'status',
      'progress',
      'start_date',
      'end_date',
      'planned_points',
      'committed_points',
      'completed_points',
      'carried_over_points',
      'test_pass_rate',
      'code_coverage',
      'escaped_defects',
      'defects_opened',
      'defects_closed',
      'code_review_completion',
      'documentation_status',
      'uat_pass_rate',
      'uat_notes',
      'risks_identified',
      'risks',
      'blockers',
      'updated_at',
    ],
    order: [['updated_at', 'DESC']],
    limit: Number(process.env.AI_PROJECT_MAX_SPRINTS || 50),
  });

  const deliverablesRaw = await Deliverable.findAll({
    where: { project_id: projectId },
    attributes: [
      'id',
      'title',
      'description',
      'definition_of_done',
      'status',
      'priority',
      'due_date',
      'owner_id',
      'assigned_to',
      'evidence_links',
      'demo_link',
      'repo_link',
      'test_summary_link',
      'user_guide_link',
      'test_pass_rate',
      'code_coverage',
      'escaped_defects',
      'defect_severity_mix',
      'submitted_at',
      'approved_at',
      'updated_at',
    ],
    include: [{ model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
    order: [['updated_at', 'DESC']],
    limit: Number(process.env.AI_PROJECT_MAX_DELIVERABLES || 100),
  });

  const deliverableIds = (deliverablesRaw || []).map((d) => d.id);
  const reportsRaw = await listProjectReportsByDeliverableIds(deliverableIds);

  const sprints = (sprintsRaw || []).map((s) => ({
    id: Number(s.id),
    name: String(s.name || ''),
    status: String(s.status || ''),
    progress: s.progress != null ? Number(s.progress) : 0,
    startDate: fmtDate(s.start_date),
    endDate: fmtDate(s.end_date),
    points: {
      planned: Number(s.planned_points || 0),
      committed: Number(s.committed_points || 0),
      completed: Number(s.completed_points || 0),
      carriedOver: Number(s.carried_over_points || 0),
    },
    quality: {
      testPassRate: s.test_pass_rate != null ? Number(s.test_pass_rate) : null,
      codeCoverage: s.code_coverage != null ? Number(s.code_coverage) : null,
      escapedDefects: s.escaped_defects != null ? Number(s.escaped_defects) : null,
      defectsOpened: s.defects_opened != null ? Number(s.defects_opened) : null,
      defectsClosed: s.defects_closed != null ? Number(s.defects_closed) : null,
    },
    execution: {
      codeReviewCompletion: s.code_review_completion != null ? Number(s.code_review_completion) : null,
      documentationStatus: s.documentation_status != null ? String(s.documentation_status) : null,
      uatPassRate: s.uat_pass_rate != null ? Number(s.uat_pass_rate) : null,
      uatNotes: s.uat_notes != null ? String(s.uat_notes) : null,
    },
    risks: {
      identified: s.risks_identified != null ? Number(s.risks_identified) : null,
      risks: s.risks != null ? String(s.risks) : null,
      blockers: s.blockers != null ? String(s.blockers) : null,
    },
    updatedAt: s.updated_at ? new Date(s.updated_at).toISOString() : null,
  }));

  const deliverables = (deliverablesRaw || []).map((d) => ({
    id: Number(d.id),
    title: String(d.title || ''),
    description: d.description != null ? String(d.description) : null,
    definitionOfDone: d.definition_of_done != null ? String(d.definition_of_done) : null,
    status: String(d.status || ''),
    priority: String(d.priority || ''),
    dueDate: fmtDate(d.due_date),
    owner: d.owner ? { id: String(d.owner.id), name: displayName(d.owner), role: d.owner.role ? String(d.owner.role) : null } : null,
    assignedTo: d.assigned_to != null ? String(d.assigned_to) : null,
    links: {
      demo: d.demo_link != null ? String(d.demo_link) : null,
      repo: d.repo_link != null ? String(d.repo_link) : null,
      testSummary: d.test_summary_link != null ? String(d.test_summary_link) : null,
      userGuide: d.user_guide_link != null ? String(d.user_guide_link) : null,
      evidence: d.evidence_links || null,
    },
    quality: {
      testPassRate: d.test_pass_rate != null ? Number(d.test_pass_rate) : null,
      codeCoverage: d.code_coverage != null ? Number(d.code_coverage) : null,
      escapedDefects: d.escaped_defects != null ? Number(d.escaped_defects) : null,
      defectSeverityMix: d.defect_severity_mix || null,
    },
    dates: {
      submittedAt: d.submitted_at ? new Date(d.submitted_at).toISOString() : null,
      approvedAt: d.approved_at ? new Date(d.approved_at).toISOString() : null,
      updatedAt: d.updated_at ? new Date(d.updated_at).toISOString() : null,
    },
  }));

  const reports = (reportsRaw || []).map((r) => {
    let reportTitle = '';
    try {
      if (r.content && typeof r.content === 'object') reportTitle = r.content.reportTitle || r.content.title || '';
      if (!reportTitle && typeof r.content === 'string') {
        const parsed = JSON.parse(r.content);
        reportTitle = parsed.reportTitle || parsed.title || '';
      }
    } catch (_) {}
    return {
      id: r.id != null ? String(r.id) : null,
      deliverableId: r.deliverable_id != null ? String(r.deliverable_id) : null,
      status: r.status != null ? String(r.status) : null,
      createdAt: r.created_at ? new Date(r.created_at).toISOString() : null,
      title: reportTitle || null,
    };
  });

  const sprintsCompleted = sprints.filter((s) => isSprintCompletedStatus(s.status)).length;
  const sprintsActive = sprints.length - sprintsCompleted;
  const deliverablesCompleted = deliverables.filter((d) => isDeliverableCompletedStatus(d.status)).length;
  const deliverablesOpen = deliverables.length - deliverablesCompleted;

  return {
    project: {
      id: String(projectRow.id),
      key: String(projectRow.key || ''),
      name: String(projectRow.name || ''),
      status: String(projectRow.status || ''),
      type: projectRow.project_type != null ? String(projectRow.project_type) : null,
      description: projectRow.description != null ? String(projectRow.description) : null,
      clientName: projectRow.client_name != null ? String(projectRow.client_name) : null,
      clientOwnerName: projectRow.client_owner_name != null ? String(projectRow.client_owner_name) : null,
      startDate: fmtDate(projectRow.start_date),
      endDate: fmtDate(projectRow.end_date),
      metadata: projectRow.metadata || null,
    },
    owner: owner ? { id: String(owner.id), name: displayName(owner), email: owner.email ? String(owner.email) : null, role: owner.role ? String(owner.role) : null } : null,
    totals: {
      sprints: { total: sprints.length, active: sprintsActive, completed: sprintsCompleted },
      deliverables: { total: deliverables.length, open: deliverablesOpen, completed: deliverablesCompleted },
      reports: { total: reports.length },
    },
    sprints,
    deliverables,
    reports,
  };
}

async function formatWithOpenRouter({ userText, data, kind }) {
  const guidance = [
    'You are FlowPilot, the friendly and supportive AI assistant for the Flow app.',
    'Your goal is to provide a conversational, guided, and professional experience.',
    'Use only the provided JSON data to answer, but phrase your responses naturally like a helpful team member.',
    'If the user changes topics, switch immediately and answer the latest request without repeating your previous response unless asked.',
    'Do not say you lack access; if something is missing, explain it gently based on the available data.',
    'Do not use markdown. Do not output *, #, or ` characters. Do not use code fences.',
    'Use plain text with "-" for lists.',
    'Be warm, conversational, and focus on guiding the user through their tasks.',
  ].join(' ');
  const msgs = [
    { role: 'system', content: guidance },
    { role: 'system', content: `${String(kind || 'DATA')}_JSON: ${JSON.stringify(data)}` },
    { role: 'user', content: userText },
  ];
  const payload = await callOpenRouter({ msgs, temperature: 0.2, max_tokens: 700 });
  return payload;
}

async function rephraseWithOpenRouter({ question, rawAnswer }) {
  const guidance = [
    'Rewrite the provided answer in a warm, friendly, and professional assistant tone.',
    'Your goal is to be conversational and helpful, making the information easy to understand.',
    'Do not add new facts, do not remove any listed items, and do not change names.',
    'Do not use markdown. Do not output *, #, or ` characters. Do not use code fences.',
    'Use plain text with "-" for lists.',
  ].join(' ');
  const msgs = [
    { role: 'system', content: guidance },
    { role: 'system', content: `RAW_ANSWER_TEXT: ${String(rawAnswer || '')}` },
    { role: 'user', content: String(question || '').trim() },
  ];
  const payload = await callOpenRouter({ msgs, temperature: 0.2, max_tokens: 700 });
  return payload;
}

function toOpenRouterRequest(msgs, temperature, max_tokens) {
  const systemTexts = [];
  const messages = [];
  for (const m of msgs || []) {
    const role = String(m && m.role ? m.role : 'user').toLowerCase();
    const content = (m && m.content != null) ? String(m.content) : '';
    if (!content.trim()) continue;
    if (role === 'system') {
      systemTexts.push(content.trim());
      continue;
    }
    if (role === 'assistant') {
      messages.push({ role: 'assistant', content });
      continue;
    }
    messages.push({ role: 'user', content });
  }
  if (systemTexts.length > 0) {
    messages.unshift({ role: 'system', content: systemTexts.join('\n\n') });
  }
  return {
    messages,
    temperature: typeof temperature === 'number' ? temperature : 0.7,
    max_tokens: typeof max_tokens === 'number' ? max_tokens : 512,
  };
}

async function listOpenRouterModels(baseUrl) {
  const r = await axios.get(`${baseUrl}/api/v1/models`, { timeout: 30000 });
  const data = r.data || {};
  const models = Array.isArray(data.data) ? data.data : [];
  return models.map((m) => String(m && m.id || '').trim()).filter(Boolean);
}

async function resolveOpenRouterModel(baseUrl) {
  const now = Date.now();
  if (resolvedOpenRouterModel && (now - resolvedOpenRouterModelAt) < 60 * 60 * 1000) {
    return resolvedOpenRouterModel;
  }
  const prefer = [];
  if (process.env.OPENROUTER_MODEL) prefer.push(String(process.env.OPENROUTER_MODEL).trim());
  if (process.env.GEMINI_MODEL) prefer.push(String(process.env.GEMINI_MODEL).trim());
  let all = [];
  try {
    all = await listOpenRouterModels(baseUrl);
  } catch (_) {}
  let selected = prefer.find(id => all.includes(id)) || '';
  if (!selected) {
    const candidates = all.filter(id => id.toLowerCase().includes('gemini'));
    selected = candidates.find(id => id.toLowerCase().includes('flash')) || candidates[0] || all[0] || 'google/gemini-3.1-flash-lite-preview';
  }
  resolvedOpenRouterModel = selected;
  resolvedOpenRouterModelAt = now;
  return selected;
}

async function callOpenRouter({ msgs, temperature, max_tokens }) {
  const apiKey = process.env.OPENROUTER_API_KEY || process.env.OpenRouter_API_KEY || '';
  if (!apiKey) {
    const err = new Error('OpenRouter API key not configured. Set OPENROUTER_API_KEY in backend/node-backend/.env');
    err.response = { status: 500 };
    throw err;
  }
  const baseUrl = (process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai').replace(/\/+$/, '');
  const body = toOpenRouterRequest(msgs, temperature, max_tokens);
  let model = (process.env.OPENROUTER_MODEL || process.env.GEMINI_MODEL || '').trim();
  if (!model) {
    model = await resolveOpenRouterModel(baseUrl);
  }
  async function post(modelId) {
    return await axios.post(`${baseUrl}/api/v1/chat/completions`, {
      model: modelId,
      messages: body.messages,
      temperature: body.temperature,
      max_tokens: body.max_tokens,
    }, {
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      timeout: 60000,
    });
  }
  let r;
  try {
    r = await post(model);
  } catch (e) {
    const status = (e && e.response && e.response.status) || 0;
    if (status === 400 || status === 404) {
      const fallback = await resolveOpenRouterModel(baseUrl);
      r = await post(fallback);
      model = fallback;
    } else {
      throw e;
    }
  }
  const data = r.data || {};
  const choice = (data.choices && data.choices[0]) || {};
  const message = choice.message || {};
  const content = (message.content != null) ? String(message.content) : '';
  const payload = { content: cleanAiText(content), usage: data.usage || {}, model };
  return payload;
}

function generateSuggestions(userText, intent, snapshotData) {
  const t = String(userText || '').toLowerCase();
  const suggestions = [];

  // 1. Context-based suggestions
  if (/\bprojects?\b/.test(t)) {
    suggestions.push('Could you show me all projects?');
    suggestions.push("I'd like help starting a new project.");
    suggestions.push('Can you tell me who the project owners are?');
  } else if (/\bsprints?\b/.test(t)) {
    suggestions.push('I want to see all the sprints.');
    suggestions.push("Could we set up a new sprint together?");
    suggestions.push('What sprints are currently active?');
  } else if (/\bdeliverables?\b/.test(t)) {
    suggestions.push('Show me what deliverables we have.');
    suggestions.push('I need help creating a deliverable.');
    suggestions.push('Are there any deliverables past their due date?');
  } else if (/\busers?\b|\bteam\b|\bmembers?\b/.test(t)) {
    suggestions.push('Who are the members of the team?');
    suggestions.push('Can you show me the team assignments?');
  }

  // 2. Intent-based additions
  if (intent === 'project') {
    suggestions.push('Please open the project workspace.');
    suggestions.push('Which sprints belong to this project?');
  } else if (intent === 'sprint') {
    suggestions.push('Could you prepare a report for this sprint?');
    suggestions.push('Show me the deliverables for this sprint.');
  } else if (intent === 'deliverable') {
    suggestions.push('Help me draft a sign-off report.');
    suggestions.push('I want to change the status of this.');
  }

  // 3. General helpful suggestions if list is short
  if (suggestions.length < 3) {
    suggestions.push('Take me back to the dashboard.');
    suggestions.push('Are there any new notifications for me?');
    suggestions.push('What kind of things can you help me with?');
  }

  // Deduplicate and limit
  const unique = Array.from(new Set(suggestions));
  for (let i = unique.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = unique[i];
    unique[i] = unique[j];
    unique[j] = tmp;
  }
  return unique.slice(0, 4);
}

function hashStringToUInt(str) {
  let h = 2166136261;
  const s = String(str || '');
  for (let i = 0; i < s.length; i += 1) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return function rand() {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffleInPlace(arr, rand) {
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rand() * (i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

function buildEntrySuggestions(snapshotData, userId) {
  const rand = mulberry32((Date.now() ^ hashStringToUInt(userId)) >>> 0);
  const projects = snapshotData && Array.isArray(snapshotData.projects) ? snapshotData.projects : [];
  const sprints = snapshotData && Array.isArray(snapshotData.sprints) ? snapshotData.sprints : [];
  const deliverables = snapshotData && Array.isArray(snapshotData.deliverables) ? snapshotData.deliverables : [];

  const pool = [];

  if (projects.length > 0) {
    const picks = shuffleInPlace(projects.slice(0, Math.min(projects.length, 12)), rand).slice(0, 2);
    for (const p of picks) {
      const name = String(p.name || '').trim();
      const key = String(p.key || '').trim();
      const label = key ? `${name} (${key})` : name;
      if (label.trim()) {
        pool.push(`Open ${label} workspace.`);
        pool.push(`What's the current status of ${label}?`);
      }
    }
  }

  const activeSprints = sprints.filter((s) => !isSprintCompletedStatus(s.status));
  if (activeSprints.length > 0) {
    const s = shuffleInPlace(activeSprints.slice(0, Math.min(activeSprints.length, 12)), rand)[0];
    const sprintName = String(s.name || '').trim();
    if (sprintName) {
      pool.push(`Give me a quick update on sprint "${sprintName}".`);
      pool.push(`Generate a sprint report for "${sprintName}".`);
    }
  }

  const nowYmd = new Date().toISOString().slice(0, 10);
  const overdueCount = deliverables.filter((d) => {
    const due = d && d.dueDate ? String(d.dueDate) : '';
    if (!due) return false;
    if (due > nowYmd) return false;
    return !isDeliverableCompletedStatus(d.status);
  }).length;
  if (overdueCount > 0) {
    pool.push(`Show me what's overdue right now (${overdueCount} item${overdueCount === 1 ? '' : 's'}).`);
  } else {
    pool.push('What should I focus on next?');
  }

  pool.push('Show me all projects.');
  pool.push('What sprints are currently active?');
  pool.push('Help me create a deliverable.');
  pool.push('Help me set up a new sprint.');
  pool.push('Take me back to the dashboard.');

  const unique = Array.from(new Set(pool.map((s) => String(s || '').trim()).filter(Boolean)));
  shuffleInPlace(unique, rand);
  return unique.slice(0, 4);
}

router.get('/status', (req, res) => {
  const loadedFrom = process.env.ENV_LOADED_FROM || '';
  const basename = loadedFrom ? String(loadedFrom).split(/[\\/]/).pop() : '';
  return res.json({
    success: true,
    data: {
      aiRoutesVersion: 'ai-active-2026-04-13',
      provider: 'openrouter',
      openrouterConfigured: !!(process.env.OPENROUTER_API_KEY || process.env.OpenRouter_API_KEY),
      openrouterModel: resolvedOpenRouterModel || process.env.OPENROUTER_MODEL || process.env.GEMINI_MODEL || 'google/gemini-3.1-flash-lite-preview',
      directListEnabled: true,
      snapshotEndpointEnabled: true,
      fullAccessEnabled: String(process.env.AI_CONTEXT_FULL_ACCESS || '').toLowerCase() === 'true' || String(process.env.NODE_ENV || '').toLowerCase() === 'development',
      nodeEnv: process.env.NODE_ENV || 'development',
      envFile: basename || null,
    },
  });
});

router.get('/snapshot', async (req, res) => {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ success: false, error: 'Authentication required' });
    }
    const data = await buildAppDataSnapshotData(req.user);
    const asJson = JSON.stringify(data);
    return res.json({
      success: true,
      meta: {
        bytes: asJson.length,
        projects: Array.isArray(data.projects) ? data.projects.length : 0,
        sprints: Array.isArray(data.sprints) ? data.sprints.length : 0,
        deliverables: Array.isArray(data.deliverables) ? data.deliverables.length : 0,
        tickets: Array.isArray(data.tickets) ? data.tickets.length : 0,
        users: Array.isArray(data.allUsers) ? data.allUsers.length : (Array.isArray(data.users) ? data.users.length : 0),
      },
      data,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'snapshot_failed' });
  }
});

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
    msgs.unshift({
      role: 'system',
      content: 'You are FlowPilot. You have access to project/sprint/deliverable/user/notification data in APP_DATA_SNAPSHOT_JSON. Use it to answer questions about counts, names, status, assignments, progress, and unread notifications. If the user changes topics, answer the latest request directly without repeating your previous response unless asked. If something is not present in the snapshot, say it is not present in the snapshot.',
    });
    let snapshotData = null;
    try {
      if (req.user && req.user.id) {
        snapshotData = await buildAppDataSnapshotData(req.user);
        msgs.unshift({ role: 'system', content: `APP_DATA_SNAPSHOT_JSON: ${JSON.stringify(snapshotData)}` });
      }
    } catch (_) {
      snapshotData = null;
      msgs.unshift({ role: 'system', content: 'APP_DATA_SNAPSHOT_JSON: {"error":"snapshot_unavailable"}' });
    }

    const userText = lastUserTextFromMessages(msgs);
    const userId = req.user && req.user.id ? String(req.user.id) : '';
    const intent = detectCreateIntent(userText);
    
    const sendResponse = (res, success, data) => {
      if (success && data && !data.suggestions) {
        data.suggestions = generateSuggestions(userText, intent, snapshotData);
      }
      console.log('AI Response:', JSON.stringify({ success, suggestions: data?.suggestions?.length || 0 }));
      return res.json({ success, data });
    };

    if (userId && userText) {
      const t = String(userText).toLowerCase();
      let topic = '';
      if (/\bprojects?\b/.test(t)) topic = 'projects';
      else if (/\bsprints?\b/.test(t)) topic = 'sprints';
      else if (/\bdeliverables?\b/.test(t)) topic = 'deliverables';
      else if (/\busers?\b|\bteam\b|\bmembers?\b/.test(t)) topic = 'users';
      if (!topic && isListOrCountQuery(userText)) {
        topic = lastTopicByUser.get(userId) || '';
      }
      if (topic) lastTopicByUser.set(userId, topic);
      if (snapshotData && topic) snapshotData.__topic = topic;

      let pending = pendingActions.get(userId);
      const pendingPatch = parseKeyValueLines(userText);
      if (pending && shouldAutoCancelPending(pending, userText, pendingPatch)) {
        pendingActions.delete(userId);
        pending = null;
      }
      if (pending && isCancelText(userText)) {
        pendingActions.delete(userId);
        return sendResponse(res, true, { content: 'Cancelled.', usage: {}, model: 'server' });
      }
      if (pending) {
        pending.data = mergeDefined(pending.data, pendingPatch);
        if (pending.type === 'report') {
          const tt = String(userText || '').toLowerCase();
          if ((pendingPatch && pendingPatch.sprint) || /\bsprint\b/.test(tt)) {
            pending.type = 'signoff_sprint_select';
            pending.data = {
              sprint: pendingPatch.sprint ? String(pendingPatch.sprint).trim() : '',
              note: extractSignoffNoteFromText(userText),
            };
            pending.confirmAsked = true;
          }
        }
        if (pending.type === 'sprint_report_select') {
          if (!Array.isArray(pending.data.sprint_options) || pending.data.sprint_options.length === 0) {
            pending.data.sprint_options = await getSprintSelectionOptions(snapshotData || {}, 12);
          }
          const options = pending.data.sprint_options || [];
          const selectedId = resolveSprintIdFromSelectionText(userText, options);

          if (!selectedId) {
            const list = formatSprintOptionsForPrompt(options);
            return sendResponse(res, true, {
              content: cleanAiText(`Choose a sprint for the report by replying with the number.\n\n${list}`),
              usage: {},
              model: 'server',
            });
          }

          const sprintLoad = await buildSprintReportById(selectedId);
          const sprintData = sprintLoad ? sprintLoad.report : null;
          if (!sprintData) {
            if (sprintLoad && !sprintLoad.notFound) {
              pendingActions.delete(userId);
              return sendResponse(res, true, {
                content: cleanAiText(`I couldn't generate the sprint report due to an internal error: ${String(sprintLoad.error || 'unknown_error')}`),
                usage: {},
                model: 'server',
              });
            }
            pending.data.sprint_options = await getSprintSelectionOptions(snapshotData || {}, 12);
            const list = formatSprintOptionsForPrompt(pending.data.sprint_options);
            return sendResponse(res, true, {
              content: cleanAiText(`I couldn't find that sprint. Please choose again by replying with the number.\n\n${list}`),
              usage: {},
              model: 'server',
            });
          }

          const verificationText = buildManualSprintReportText(sprintData, undefined, pending.data.feedback);
          const suggested = suggestSprintReportTitle(sprintData);
          pending.type = 'sprint_report';
          pending.data = {
            sprint_ref: sprintData.sprint && sprintData.sprint.id ? String(sprintData.sprint.id) : String(selectedId),
            suggested_title: suggested,
            stage: 'verify',
            feedback: pending.data.feedback || '',
          };
          return sendResponse(res, true, {
            content: cleanAiText(`Here is the sprint data (deliverables and team included) for verification:\n\n${verificationText}\n\nSuggested report title: ${suggested}\nReply "confirm" to confirm the title, then you will be prompted to add feedback before the report is generated.`),
            usage: {},
            model: 'server',
          });
        }
        if (pending.type === 'sprint_report') {
          const stage = String(pending.data.stage || 'verify');
          const extractedTitle = extractReportTitleFromText(userText);
          if (extractedTitle) pending.data.report_title = extractedTitle;
          const extractedFeedback = extractFeedbackFromText(userText);
          if (extractedFeedback) pending.data.feedback = extractedFeedback;

          if (stage === 'verify') {
            if (!pending.data.report_title && isConfirmText(userText) && pending.data.suggested_title) {
              pending.data.report_title = String(pending.data.suggested_title).trim();
            }

            if (pending.data.report_title && !isConfirmText(userText)) {
              return sendResponse(res, true, {
                content: cleanAiText(`Report title set to: ${String(pending.data.report_title)}\nReply "confirm" to confirm the title and continue to feedback, or type a new title.`),
                usage: {},
                model: 'server',
              });
            }

            if (!isConfirmText(userText)) {
              const prompt = pending.data.suggested_title
                ? `Suggested report title: ${String(pending.data.suggested_title)}\nReply "confirm" to use it, or type your own title.`
                : 'Please provide a report title.';
              return sendResponse(res, true, { content: cleanAiText(prompt), usage: {}, model: 'server' });
            }

            if (!pending.data.report_title) {
              return sendResponse(res, true, { content: cleanAiText('Please provide a report title, then reply "confirm".'), usage: {}, model: 'server' });
            }

            pending.data.stage = 'feedback';
            pending.data.feedback_confirm_ready = false;
            return sendResponse(res, true, {
              content: cleanAiText(`Add feedback that will appear in the PDF report (optional).\nReply with:\n- Feedback: <your comments>\nOr just type your feedback as a message.\nOr reply "skip" to continue without feedback.\n\nAfter you add feedback (or skip), reply "confirm" to generate and export the report PDF.`),
              usage: {},
              model: 'server',
            });
          }

          if (stage === 'feedback') {
            if (isSkipText(userText)) {
              pending.data.feedback = '';
              pending.data.feedback_confirm_ready = true;
            } else if (extractedFeedback) {
              pending.data.feedback_confirm_ready = true;
            } else if (userText && !isConfirmText(userText) && !isCancelText(userText)) {
              const direct = String(userText).trim();
              if (direct) {
                pending.data.feedback = normalizePossibleFeedback(direct);
                pending.data.feedback_confirm_ready = true;
              }
            }

            if (isConfirmText(userText)) {
              if (!pending.data.feedback_confirm_ready) {
                return sendResponse(res, true, {
                  content: cleanAiText('Please add feedback (or reply "skip") before confirming.'),
                  usage: {},
                  model: 'server',
                });
              }
            } else {
              return sendResponse(res, true, {
                content: cleanAiText(pending.data.feedback
                  ? 'Feedback saved. Reply "confirm" to generate and export the report PDF, or update your feedback.'
                  : 'Reply with your feedback (optional), or reply "skip". Then reply "confirm" to generate and export the report PDF.'),
                usage: {},
                model: 'server',
              });
            }

            const reportTitle = String(pending.data.report_title || '').trim() || 'Sprint Report';
            const sprintRef = pending.data.sprint_ref ? String(pending.data.sprint_ref).trim() : '';
            const latestLoad = sprintRef ? await buildSprintReportById(sprintRef) : null;
            const latestData = latestLoad ? latestLoad.report : null;
            if (!latestData) {
              return sendResponse(res, true, {
                content: cleanAiText(latestLoad && !latestLoad.notFound
                  ? `I couldn't generate the report due to an internal error: ${String(latestLoad.error || 'unknown_error')}`
                  : 'I could not reload the sprint data for the report. Please try again.'),
                usage: {},
                model: 'server',
              });
            }
            const finalText = buildManualSprintReportText(latestData, reportTitle, pending.data.feedback);
            const role = normalizeRole(req.user && req.user.role);
            const allowSignoff = ['admin', 'systemadmin', 'deliverylead'].includes(role);
            pendingActions.delete(userId);
            return sendResponse(res, true, {
              content: cleanAiText(finalText),
              actions: allowSignoff ? [{ type: 'export_pdf', title: reportTitle, content: cleanAiText(finalText) }] : [],
              usage: {},
              model: 'server',
            });
          }

          pending.data.stage = 'verify';
          return sendResponse(res, true, { content: cleanAiText('Please reply "confirm" to continue.'), usage: {}, model: 'server' });
        }
        if (pending.type === 'signoff_sprint_select') {
          const role = normalizeRole(req.user && req.user.role);
          const allowSignoff = ['admin', 'systemadmin', 'deliverylead'].includes(role);
          if (!allowSignoff) {
            pendingActions.delete(userId);
            return sendResponse(res, true, {
              content: cleanAiText('Only Delivery Leads and System Admins can generate sign-off reports with FlowPilot.'),
              usage: {},
              model: 'server',
            });
          }
          if (!pending.data.note) {
            const n = extractSignoffNoteFromText(userText);
            if (n) pending.data.note = n;
          }
          if (!Array.isArray(pending.data.sprint_options) || pending.data.sprint_options.length === 0) {
            pending.data.sprint_options = await getSprintSelectionOptions(snapshotData || {}, 12);
          }
          const options = pending.data.sprint_options || [];
          const selectedId = resolveSprintIdFromSelectionText(userText, options);

          if (!selectedId) {
            const list = formatSprintOptionsForPrompt(options);
            return sendResponse(res, true, {
              content: cleanAiText(`Choose a sprint for the sign-off report by replying with the number.\n\n${list}`),
              usage: {},
              model: 'server',
            });
          }

          const sprintLoad = await buildSprintReportById(selectedId);
          const sprintData = sprintLoad ? sprintLoad.report : null;
          if (!sprintData) {
            if (sprintLoad && !sprintLoad.notFound) {
              pendingActions.delete(userId);
              return sendResponse(res, true, {
                content: cleanAiText(`I couldn't generate the sign-off report due to an internal error: ${String(sprintLoad.error || 'unknown_error')}`),
                usage: {},
                model: 'server',
              });
            }
            pending.data.sprint_options = await getSprintSelectionOptions(snapshotData || {}, 12);
            const list = formatSprintOptionsForPrompt(pending.data.sprint_options);
            return sendResponse(res, true, {
              content: cleanAiText(`I couldn't find that sprint. Please choose again by replying with the number.\n\n${list}`),
              usage: {},
              model: 'server',
            });
          }

          const suggestedTitle = `Sprint Report: ${String(sprintData.sprint && sprintData.sprint.name ? sprintData.sprint.name : '').trim() || 'Sprint'}`;
          const providedTitle = extractReportTitleFromText(userText);
          const title = providedTitle || suggestedTitle;
          const preview = buildSprintSignoffReportText(sprintData, title, pending.data.note, pending.data.feedback);
          pending.type = 'signoff_sprint_report';
          pending.data = {
            sprint_ref: String(sprintData.sprint && sprintData.sprint.id ? sprintData.sprint.id : selectedId),
            suggested_title: suggestedTitle,
            report_title: providedTitle || '',
            note: pending.data.note || '',
            feedback: pending.data.feedback || '',
            stage: 'verify',
          };
          return sendResponse(res, true, {
            content: cleanAiText(`Here is the sprint sign-off report content for verification:\n\n${preview}\n\nSuggested report title: ${suggestedTitle}\nReply "confirm" to confirm the title, then you will be prompted to add feedback before the report is created and exported.`),
            usage: {},
            model: 'server',
          });
        }
        if (pending.type === 'signoff_sprint_report') {
          const role = normalizeRole(req.user && req.user.role);
          const allowSignoff = ['admin', 'systemadmin', 'deliverylead'].includes(role);
          if (!allowSignoff) {
            pendingActions.delete(userId);
            return sendResponse(res, true, {
              content: cleanAiText('Only Delivery Leads and System Admins can generate sign-off reports with FlowPilot.'),
              usage: {},
              model: 'server',
            });
          }
          const stage = String(pending.data.stage || 'verify');
          const extractedTitle = extractReportTitleFromText(userText);
          if (extractedTitle) pending.data.report_title = extractedTitle;
          const extractedNote = extractSignoffNoteFromText(userText);
          if (extractedNote) pending.data.note = extractedNote;
          const extractedFeedback = extractFeedbackFromText(userText);
          if (extractedFeedback) pending.data.feedback = extractedFeedback;

          if (stage === 'verify') {
            if (!pending.data.report_title && isConfirmText(userText) && pending.data.suggested_title) {
              pending.data.report_title = String(pending.data.suggested_title).trim();
            }

            if (pending.data.report_title && !isConfirmText(userText)) {
              return sendResponse(res, true, {
                content: cleanAiText(`Report title set to: ${String(pending.data.report_title)}\nReply "confirm" to confirm the title and continue to feedback, or type a new title.`),
                usage: {},
                model: 'server',
              });
            }

            if (!isConfirmText(userText)) {
              return sendResponse(res, true, {
                content: cleanAiText(`Suggested report title: ${String(pending.data.suggested_title || 'Sprint Report')}\nReply "confirm" to use it, or type your own title.`),
                usage: {},
                model: 'server',
              });
            }

            if (!pending.data.report_title) {
              return sendResponse(res, true, { content: cleanAiText('Please provide a report title, then reply "confirm".'), usage: {}, model: 'server' });
            }

            pending.data.stage = 'feedback';
            pending.data.feedback_confirm_ready = false;
            return sendResponse(res, true, {
              content: cleanAiText(`Add feedback that will appear in the PDF report (optional).\nReply with:\n- Feedback: <your comments>\nOr just type your feedback as a message.\nOr reply "skip" to continue without feedback.\n\nAfter you add feedback (or skip), reply "confirm" to create and export the sign-off report PDF.`),
              usage: {},
              model: 'server',
            });
          }

          if (stage === 'feedback') {
            if (isSkipText(userText)) {
              pending.data.feedback = '';
              pending.data.feedback_confirm_ready = true;
            } else if (extractedFeedback) {
              pending.data.feedback_confirm_ready = true;
            } else if (userText && !isConfirmText(userText) && !isCancelText(userText)) {
              const direct = String(userText).trim();
              if (direct) {
                pending.data.feedback = normalizePossibleFeedback(direct);
                pending.data.feedback_confirm_ready = true;
              }
            }

            if (isConfirmText(userText)) {
              if (!pending.data.feedback_confirm_ready) {
                return sendResponse(res, true, { content: cleanAiText('Please add feedback (or reply "skip") before confirming.'), usage: {}, model: 'server' });
              }
            } else {
              return sendResponse(res, true, {
                content: cleanAiText(pending.data.feedback
                  ? 'Feedback saved. Reply "confirm" to create and export the sign-off report PDF, or update your feedback.'
                  : 'Reply with your feedback (optional), or reply "skip". Then reply "confirm" to create and export the sign-off report PDF.'),
                usage: {},
                model: 'server',
              });
            }
          } else {
            pending.data.stage = 'verify';
            return sendResponse(res, true, { content: cleanAiText('Please reply "confirm" to continue.'), usage: {}, model: 'server' });
          }

          const reportTitle = String(pending.data.report_title || pending.data.suggested_title || 'Sprint Report').trim();
          const sprintRef = String(pending.data.sprint_ref || '').trim();
          const latestLoad = sprintRef ? await buildSprintReportById(sprintRef) : null;
          const latestData = latestLoad ? latestLoad.report : null;
          if (!latestData) {
            return sendResponse(res, true, { content: cleanAiText(latestLoad && !latestLoad.notFound
              ? `I couldn't create the sign-off report due to an internal error: ${String(latestLoad.error || 'unknown_error')}`
              : 'I could not reload the sprint data for the sign-off report. Please try again.'), usage: {}, model: 'server' });
          }

          const reportContent = buildSprintSignoffReportText(latestData, reportTitle, pending.data.note, pending.data.feedback);
          await ensureReportsTable();
          const preparedByName = req.user ? displayName(req.user) : null;
          const content = {
            reportTitle,
            reportContent,
            sprintIds: [String(latestData.sprint && latestData.sprint.id ? latestData.sprint.id : sprintRef)],
            sprintPerformanceData: '',
            sprintReportData: latestData,
            preparedBy: userId,
            preparedByName,
            preparedByRole: role || null,
            status: 'draft',
          };
          const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
          const contentExpr = dialect === 'postgres' ? '$4::jsonb' : '$4';
          const [results] = await sequelize.query(
            `INSERT INTO sign_off_reports (deliverable_id, created_by, status, content) VALUES ($1, $2, $3, ${contentExpr}) RETURNING id`,
            { bind: [null, userId, 'draft', JSON.stringify(content)] }
          );
          const row = results && results[0] ? results[0] : null;
          pendingActions.delete(userId);
          return sendResponse(res, true, {
            content: cleanAiText(`${reportContent}\n\nSaved as a draft sign-off report (id=${row ? row.id : 'unknown'}).`),
            actions: [{ type: 'export_pdf', title: reportTitle, content: cleanAiText(reportContent) }],
            usage: {},
            model: 'server',
          });
        }
        const ready = pending.type === 'project'
          ? !!pending.data.name
          : pending.type === 'sprint'
            ? !!pending.data.project && !!pending.data.name && !!pending.data.start_date && !!pending.data.end_date
            : pending.type === 'deliverable'
              ? !!pending.data.project && !!pending.data.title
              : pending.type === 'report'
                ? !!pending.data.deliverable_id && !!pending.data.report_title && !!pending.data.report_content
                : false;

        if (!ready) {
          const ask = pending.type === 'deliverable'
            ? "I'm ready to help you create a deliverable. Could you share:\n- Project (key or name)\n- Title\n- Due Date (optional)\n- Owner Email (optional)\n- Assigned To (optional)\n- Sprint (optional)\n- Priority (low, medium, or high)"
            : pending.type === 'sprint'
              ? "Let's set up a new sprint. I'll need a few things:\n- Project (key or name)\n- Sprint Name\n- Start Date (YYYY-MM-DD)\n- End Date (YYYY-MM-DD)\n- Planned Points (optional)"
              : pending.type === 'project'
                ? "I'd be happy to help you start a new project! Please provide:\n- Project Name\n- Short Key (optional)\n- Owner Email (optional)"
                : "I'll help you draft a sign-off report. Please provide:\n- Deliverable ID\n- Report Title\n- Report Content\n- Status (draft or submitted)";
          return sendResponse(res, true, { content: ask, usage: {}, model: 'server' });
        }

        if (!isConfirmText(userText) && !pending.confirmAsked) {
          pending.confirmAsked = true;
          const summary = pending.type === 'deliverable'
            ? `Great — here's what I'll set up:\n- Project: ${pending.data.project}\n- Title: ${pending.data.title}\n- Due date: ${pending.data.due_date || 'Not set'}\n- Owner email: ${pending.data.owner_email || 'Not set'}\n- Assigned to: ${pending.data.assigned_to || 'Not set'}\n- Sprint: ${pending.data.sprint || 'Not set'}\n\nShall I go ahead and create this deliverable? (Reply "confirm" or "cancel")`
            : pending.type === 'sprint'
              ? `Perfect — here are the sprint details:\n- Project: ${pending.data.project}\n- Name: ${pending.data.name}\n- Dates: ${pending.data.start_date} to ${pending.data.end_date}\n- Planned points: ${pending.data.planned_points || '0'}\n\nReady for me to create this sprint? (Reply "confirm" or "cancel")`
              : pending.type === 'project'
                ? `I'm ready to set up your new project:\n- Name: ${pending.data.name}\n- Key: ${pending.data.key || 'Will be auto-generated'}\n\nShould I go ahead and create it? (Reply "confirm" or "cancel")`
                : `I've drafted the sign-off report:\n- Deliverable ID: ${pending.data.deliverable_id}\n- Title: ${pending.data.report_title}\n- Status: ${pending.data.status || 'draft'}\n\nShall I save this report? (Reply "confirm" or "cancel")`;
          return sendResponse(res, true, { content: summary, usage: {}, model: 'server' });
        }

        if (isConfirmText(userText)) {
          const role = normalizeRole(req.user && req.user.role);
          const allowProject = ['admin', 'systemadmin', 'deliverylead', 'projectmanager'].includes(role);
          const allowSprint = ['admin', 'systemadmin', 'deliverylead', 'scrummaster', 'projectmanager'].includes(role);
          const allowDeliverable = ['admin', 'systemadmin', 'deliverylead', 'teammember', 'developer', 'projectmanager', 'scrummaster', 'qaengineer'].includes(role);
          const allowReport = ['admin', 'systemadmin', 'deliverylead'].includes(role);

          try {
            if (pending.type === 'project') {
              if (!allowProject) return res.status(403).json({ error: 'Insufficient permissions' });
              const name = String(pending.data.name || '').trim();
              let key = String(pending.data.key || '').trim();
              if (!key) key = deriveKey(name);
              key = key.toUpperCase();
              let uniqueKey = key;
              for (let i = 1; i <= 99; i += 1) {
                const exists = await Project.findOne({ where: { key: uniqueKey }, attributes: ['id'] });
                if (!exists) break;
                uniqueKey = (key + String(i)).slice(0, 10);
              }
              const project = await Project.create({
                name,
                key: uniqueKey,
                status: 'active',
                owner_id: userId,
                created_by: userId,
              });
              pendingActions.delete(userId);
              return sendResponse(res, true, { content: `Project created: ${project.name} (${project.key})`, usage: {}, model: 'server' });
            }

            if (pending.type === 'sprint') {
              if (!allowSprint) return res.status(403).json({ error: 'Insufficient permissions' });
              const projectId = await resolveProjectIdFromInput(pending.data.project, snapshotData || {});
              if (!projectId) return sendResponse(res, true, { content: 'Project not found. Provide Project as a valid project key or name.', usage: {}, model: 'server' });
              
              // Validate dates
              const start = new Date(String(pending.data.start_date).trim());
              const end = new Date(String(pending.data.end_date).trim());
              if (isNaN(start.getTime()) || isNaN(end.getTime())) {
                return sendResponse(res, true, { content: 'Invalid date format. Please use YYYY-MM-DD.', usage: {}, model: 'server' });
              }
              if (end <= start) {
                return sendResponse(res, true, { content: 'End date must be after start date.', usage: {}, model: 'server' });
              }

              let plannedPoints = 0;
              if (pending.data.planned_points !== undefined && pending.data.planned_points !== null) {
                const n = parseInt(String(pending.data.planned_points).trim(), 10);
                if (Number.isNaN(n) || n < 0) {
                  return sendResponse(res, true, { content: 'Planned Points must be a non-negative number.', usage: {}, model: 'server' });
                }
                plannedPoints = n;
              }

              const sprint = await Sprint.create({
                project_id: projectId,
                name: String(pending.data.name).trim(),
                start_date: start,
                end_date: end,
                planned_points: plannedPoints,
                status: 'planning',
                created_by: userId,
                created_at: new Date(),
                updated_at: new Date(),
              });
              pendingActions.delete(userId);
              return sendResponse(res, true, {
                  content: `Sprint created: ${sprint.name} (id=${sprint.id})`,
                  actions: [{ type: 'navigate', route: '/sprint-console', silent: false }],
                  usage: {},
                  model: 'server'
              });
            }

            if (pending.type === 'deliverable') {
              if (!allowDeliverable) return res.status(403).json({ error: 'Insufficient permissions' });
              const projectId = await resolveProjectIdFromInput(pending.data.project, snapshotData || {});
              if (!projectId) return sendResponse(res, true, { content: 'Project not found. Provide Project as a valid project key or name.', usage: {}, model: 'server' });
              let ownerId = null;
              if (pending.data.owner_email) {
                const u = await User.findOne({ where: { email: String(pending.data.owner_email).trim() }, attributes: ['id'] });
                if (u) ownerId = String(u.id);
              }
              const deliverable = await Deliverable.create({
                project_id: projectId,
                title: String(pending.data.title).trim(),
                status: 'draft',
                priority: pending.data.priority ? String(pending.data.priority).trim() : 'medium',
                due_date: pending.data.due_date ? new Date(String(pending.data.due_date).trim()) : null,
                owner_id: ownerId,
                created_by: userId,
                assigned_to: pending.data.assigned_to ? String(pending.data.assigned_to).trim() : null,
                created_at: new Date(),
                updated_at: new Date(),
              });
              if (pending.data.sprint) {
                const sprint = await Sprint.findOne({
                  where: { project_id: projectId, name: String(pending.data.sprint).trim() },
                  attributes: ['id'],
                });
                if (sprint) {
                  await DeliverableSprint.findOrCreate({
                    where: { deliverable_id: deliverable.id, sprint_id: sprint.id },
                    defaults: { contribution_percentage: 100, created_at: new Date() },
                  });
                }
              }
              pendingActions.delete(userId);
              return sendResponse(res, true, {
                  content: `Deliverable created: ${deliverable.title} (id=${deliverable.id})`,
                  actions: [{ type: 'navigate', route: `/deliverables/${deliverable.id}`, silent: false }],
                  usage: {},
                  model: 'server'
              });
            }

            if (pending.type === 'report') {
              if (!allowReport) {
                pendingActions.delete(userId);
                return sendResponse(res, true, {
                  content: cleanAiText('Only Delivery Leads and System Admins can generate sign-off reports with FlowPilot.'),
                  usage: {},
                  model: 'server',
                });
              }
              await ensureReportsTable();
              const deliverableId = String(pending.data.deliverable_id).trim();
              const reportTitle = String(pending.data.report_title).trim();
              const reportContent = String(pending.data.report_content).trim();
              const status = pending.data.status ? String(pending.data.status).trim() : 'draft';
              const content = { reportTitle, reportContent, status, preparedBy: userId };
              const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
              const contentExpr = dialect === 'postgres' ? '$4::jsonb' : '$4';
              const [results] = await sequelize.query(
                `INSERT INTO sign_off_reports (deliverable_id, created_by, status, content) VALUES ($1, $2, $3, ${contentExpr}) RETURNING id`,
                { bind: [deliverableId, userId, status, JSON.stringify(content)] }
              );
              const row = results && results[0] ? results[0] : null;
              pendingActions.delete(userId);
              return sendResponse(res, true, { content: `Sign-off report created: id=${row ? row.id : 'unknown'}`, usage: {}, model: 'server' });
            }
          } catch (e) {
            pendingActions.delete(userId);
            return res.status(500).json({ error: e.message || 'create_failed' });
          }
        }
      }

      if (userId && userText) {
        const tt = String(userText).toLowerCase();
        const wantsSignoffReport = /\b(sign[- ]?off|signoff)\b/.test(tt) && /\breport\b/.test(tt);
        const mentionsDeliverable = /\bdeliverable\b/.test(tt);
        if (wantsSignoffReport && !mentionsDeliverable) {
          const role = normalizeRole(req.user && req.user.role);
          const allowSignoff = ['admin', 'systemadmin', 'deliverylead'].includes(role);
          if (!allowSignoff) {
            return sendResponse(res, true, {
              content: cleanAiText('Only Delivery Leads and System Admins can generate sign-off reports with FlowPilot.'),
              usage: {},
              model: 'server',
            });
          }
          const sprintData = await buildSprintDetailsData(userText, snapshotData || {});
          if (!sprintData) {
            const options = await getSprintSelectionOptions(snapshotData || {}, 12);
            pendingActions.set(userId, { type: 'signoff_sprint_select', data: { sprint_options: options }, confirmAsked: true, createdAt: Date.now() });
            const list = formatSprintOptionsForPrompt(options);
            return sendResponse(res, true, {
              content: cleanAiText(`Choose a sprint for the sign-off report by replying with the number.\n\n${list}`),
              usage: {},
              model: 'server',
            });
          }

          const note = extractSignoffNoteFromText(userText);
        const feedback = extractFeedbackFromText(userText);
          const suggestedTitle = `Sprint Report: ${String(sprintData.sprint && sprintData.sprint.name ? sprintData.sprint.name : '').trim() || 'Sprint'}`;
          const providedTitle = extractReportTitleFromText(userText);
          const title = providedTitle || suggestedTitle;
        const preview = buildSprintSignoffReportText(sprintData, title, note, feedback);
          pendingActions.set(userId, {
            type: 'signoff_sprint_report',
            data: {
              sprint_ref: String(sprintData.sprint && sprintData.sprint.id ? sprintData.sprint.id : ''),
              suggested_title: suggestedTitle,
              report_title: providedTitle || '',
              note: note || '',
            feedback: feedback || '',
            },
            confirmAsked: true,
            createdAt: Date.now(),
          });
          return sendResponse(res, true, {
          content: cleanAiText(`Here is the sprint sign-off report content for verification:\n\n${preview}\n\nSuggested report title: ${suggestedTitle}\nOptional: add feedback that will appear in the PDF:\n- Feedback: <your comments>\n\nReply "confirm" to create this sign-off report (draft) and export PDF, or type a new title/note/feedback and then reply "confirm".`),
            usage: {},
            model: 'server',
          });
        }
      }

      const intent = detectCreateIntent(userText);
      if (intent) {
        pendingActions.set(userId, { type: intent, data: {}, confirmAsked: false, createdAt: Date.now() });
        const ask = intent === 'deliverable'
          ? "I'm ready to help you create a deliverable. Could you share:\n- Project (key or name)\n- Title\n- Due Date (optional)\n- Owner Email (optional)\n- Assigned To (optional)\n- Sprint (optional)\n- Priority (low, medium, or high)"
          : intent === 'sprint'
            ? "Let's set up a new sprint. I'll need a few things:\n- Project (key or name)\n- Sprint Name\n- Start Date (YYYY-MM-DD)\n- End Date (YYYY-MM-DD)\n- Planned Points (optional)"
            : intent === 'project'
              ? "I'd be happy to help you start a new project! Please provide:\n- Project Name\n- Short Key (optional)\n- Owner Email (optional)"
              : "I'll help you draft a sign-off report. Please provide:\n- Deliverable ID\n- Report Title\n- Report Content\n- Status (draft or submitted)";
        return sendResponse(res, true, { content: ask, usage: {}, model: 'server' });
      }
    }

    if (userId && userText && isNotificationsDataQuery(userText)) {
      const direct = snapshotData ? answerFromSnapshot(snapshotData, userText) : null;
      if (direct) {
        try {
          const ai = await rephraseWithOpenRouter({ question: userText, rawAnswer: direct });
          return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
        } catch (_) {
          return sendResponse(res, true, { content: cleanAiText(direct), usage: {}, model: 'server' });
        }
      }
    }

    if (userText && isNavigationQuery(userText)) {
      const nav = await buildNavigationActionFromText(userText, snapshotData || {});
      if (nav && nav.route) {
        const includeChat = wantsNavigationChatConfirmation(userText);
        return sendResponse(res, true, {
            content: includeChat ? cleanAiText(`Taking you to ${nav.label || 'that page'} now.`) : '',
            actions: [{ type: 'navigate', route: String(nav.route), silent: !includeChat }],
            usage: {},
            model: 'server',
        });
      }
      if (/\bproject\b/i.test(userText)) {
        const projectsPreview = await answerFromDb('list the project names', 'projects');
        return sendResponse(res, true, {
            content: cleanAiText(`Which project should I open?\nReply with: Project: <project key or name>\n\n${projectsPreview || ''}`),
            usage: {},
            model: 'server',
        });
      }
      if (/\bdeliverable\b/i.test(userText)) {
        const preview = await answerFromDb('list the deliverable titles', 'deliverables');
        return sendResponse(res, true, {
            content: cleanAiText(`Which deliverable should I open?\nReply with: Deliverable: <deliverable id or title>\n\n${preview || ''}`),
            usage: {},
            model: 'server',
        });
      }
    }
    if (userText && isAllProjectsSummaryQuery(userText)) {
      const allData = await buildAllProjectsSummaryData(snapshotData || {});
      if (allData) {
        const ai = await formatWithOpenRouter({ userText, data: allData, kind: 'ALL_PROJECTS_SUMMARY' });
        return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
      }
    }
    if (userText && isDeliverableScopedQuery(userText)) {
      const delData = await buildDeliverableDetailsData(userText, snapshotData || {});
      if (delData) {
        const ai = await formatWithOpenRouter({ userText, data: delData, kind: 'DELIVERABLE_DETAILS' });
        return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
      }
      const delPreview = await answerFromDb('list the deliverable titles', 'deliverables');
      return sendResponse(res, true, { content: cleanAiText(`Which deliverable do you mean?\nReply with: Deliverable: <deliverable title or id>\n\n${delPreview || ''}`), usage: {}, model: 'server' });
    }
    if (userText && isSprintScopedQuery(userText)) {
      const sprintData = await buildSprintDetailsData(userText, snapshotData || {});
      const wantsReport = /\breport\b|\bsummary\b|\binsights?\b|\bhealth\b/.test(String(userText || '').toLowerCase());
      if (!sprintData) {
        if (wantsReport) {
          const options = await getSprintSelectionOptions(snapshotData || {}, 12);
          pendingActions.set(userId, { type: 'sprint_report_select', data: { sprint_options: options }, confirmAsked: true, createdAt: Date.now() });
        }
        const options = await getSprintSelectionOptions(snapshotData || {}, 12);
        const list = formatSprintOptionsForPrompt(options);
        return sendResponse(res, true, {
          content: cleanAiText(`Choose a sprint for the report by replying with the number.\n\n${list}`),
          usage: {},
          model: 'server',
        });
      }

      if (wantsReport) {
        const verificationText = buildManualSprintReportText(sprintData, undefined, '');
        const providedTitle = extractReportTitleFromText(userText);
        const suggested = providedTitle || suggestSprintReportTitle(sprintData);
        pendingActions.set(userId, {
          type: 'sprint_report',
          data: {
            sprint_ref: sprintData.sprint && sprintData.sprint.id ? String(sprintData.sprint.id) : String(sprintData.sprint && sprintData.sprint.name ? sprintData.sprint.name : ''),
            suggested_title: suggested,
            stage: 'verify',
            ...(providedTitle ? { report_title: providedTitle } : {}),
            feedback: '',
          },
          confirmAsked: true,
          createdAt: Date.now(),
        });
        return sendResponse(res, true, {
          content: cleanAiText(`Here is the sprint data (deliverables and team included) for verification:\n\n${verificationText}\n\nSuggested report title: ${suggested}\nReply "confirm" to confirm the title, then you will be prompted to add feedback before the report is generated.`),
          usage: {},
          model: 'server',
        });
      }

      const ai = await formatWithOpenRouter({ userText, data: sprintData, kind: 'SPRINT_REPORT' });
      return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
    }
    if (userText && isProjectScopedQuery(userText)) {
      const detailsData = await buildProjectDetailsData(userText, snapshotData || {});
      if (detailsData) {
        const ai = await formatWithOpenRouter({ userText, data: detailsData, kind: 'PROJECT_DETAILS' });
        return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
      }
      const projectsPreview = await answerFromDb('list the project names', 'projects');
      return sendResponse(res, true, { content: cleanAiText(`Which project do you mean?\nReply with: Project: <project key or name>\n\n${projectsPreview || ''}`), usage: {}, model: 'server' });
    }
    if (userText && isListOrCountQuery(userText)) {
      if (snapshotData) {
        const direct = answerFromSnapshot(snapshotData, userText);
        if (direct) {
          try {
            const ai = await rephraseWithOpenRouter({ question: userText, rawAnswer: direct });
            return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
          } catch (_) {
            return sendResponse(res, true, { content: cleanAiText(direct), usage: {}, model: 'server' });
          }
        }
      }
      const topicHint = userId ? (lastTopicByUser.get(userId) || '') : '';
      const directDb = await answerFromDb(userText, topicHint);
      if (directDb) {
        try {
          const ai = await rephraseWithOpenRouter({ question: userText, rawAnswer: directDb });
          return sendResponse(res, true, { content: cleanAiText(ai.content), usage: ai.usage || {}, model: ai.model || 'openrouter' });
        } catch (_) {
          return sendResponse(res, true, { content: cleanAiText(directDb), usage: {}, model: 'server' });
        }
      }
    }
    const key = makeKey(msgs, temperature, max_tokens);
    const cached = getCached(key);
    if (cached) {
      return sendResponse(res, true, cached);
    }
    const existing = inflight.get(key);
    if (existing) {
      try {
        const v = await existing;
        return sendResponse(res, true, v);
      } catch (e) {
        const status = (e && e.response && e.response.status) || 500;
        const upstream = (e && e.response && e.response.data && (e.response.data.error?.message || e.response.data.error || e.response.data.message)) || null;
        return res.status(status).json({ error: upstream || e.message || 'AI request failed' });
      }
    }
    if (!msgs || msgs.length === 0) {
      return res.status(400).json({ error: 'messages or prompt required' });
    }
    const p = (async () => {
      const payload = await callOpenRouter({ msgs, temperature, max_tokens });
      setCached(key, payload);
      consecutiveFailures = 0;
      circuitOpenUntil = 0;
      return payload;
    })();
    inflight.set(key, p);
    try {
      const payload = await p;
      return sendResponse(res, true, payload);
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
    const upstream = (error && error.response && error.response.data && (error.response.data.error?.message || error.response.data.error || error.response.data.message)) || null;
    return res.status(status).json({ error: upstream || error.message || 'AI request failed' });
  }
});

router.get('/chat', async (req, res) => {
  try {
    return res.status(405).json({ error: 'Method Not Allowed', message: 'Use POST /chat with a JSON body: { messages: [...] }' });
  } catch (error) {
    return res.status(500).json({ error: error.message || 'Internal error' });
  }
});

router.get('/suggestions', async (req, res) => {
  try {
    const userId = req.user && req.user.id ? String(req.user.id) : '';
    let snapshotData = null;
    try {
      if (req.user && req.user.id) {
        snapshotData = await buildAppDataSnapshotData(req.user);
      }
    } catch (_) {
      snapshotData = null;
    }
    const suggestions = buildEntrySuggestions(snapshotData || {}, userId);
    return res.json({ success: true, data: { suggestions } });
  } catch (error) {
    return res.json({
      success: true,
      data: {
        suggestions: [
          'Show me all projects.',
          'What sprints are currently active?',
          'Help me create a deliverable.',
          'What should I focus on next?',
        ],
      },
    });
  }
});

module.exports = router;
