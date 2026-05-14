const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { Signoff, AuditLog, Deliverable, Sprint, User, sequelize } = require('../models');
const { QueryTypes, Op } = require('sequelize');
const { verifyToken } = require('../utils/authUtils');
const { optionalAuthenticateToken } = require('../middleware/auth');
const { isSprintCompletedStatus } = require('../services/sprintCarryOverService');
const PDFDocument = require('pdfkit');

function safeParseJson(text) {
  try { return JSON.parse(text); } catch (_) { return {}; }
}

async function validateCompletedSprintIds(sprintIds) {
  const raw = Array.isArray(sprintIds) ? sprintIds : (sprintIds == null ? [] : [sprintIds]);
  const ids = raw
    .map((v) => String(v || '').trim())
    .filter((v) => v.length > 0);
  if (ids.length === 0) return null;

  const numericIds = Array.from(new Set(ids))
    .map((v) => parseInt(v, 10))
    .filter((n) => Number.isFinite(n));
  if (numericIds.length === 0) {
    return { error: 'Invalid sprintIds', invalidSprintIds: ids };
  }

  const sprints = await Sprint.findAll({
    where: { id: { [Op.in]: numericIds } },
    attributes: ['id', 'name', 'status'],
  });
  const byId = new Map((sprints || []).map((s) => [String(s.id), s]));

  const missingSprintIds = [];
  const invalidSprints = [];
  for (const id of numericIds) {
    const s = byId.get(String(id));
    if (!s) {
      missingSprintIds.push(String(id));
      continue;
    }
    if (!isSprintCompletedStatus(s.status)) {
      invalidSprints.push({
        id: String(s.id),
        name: s.name || null,
        status: s.status || null,
      });
    }
  }

  if (missingSprintIds.length > 0 || invalidSprints.length > 0) {
    return {
      error: 'Reports can only be linked to completed sprints',
      missingSprintIds,
      invalidSprints,
    };
  }

  return null;
}

async function buildSprintReportDataBySprintIds(sprintIds) {
  const raw = Array.isArray(sprintIds) ? sprintIds : (sprintIds == null ? [] : [sprintIds]);
  const ids = raw
    .map((v) => String(v || '').trim())
    .filter((v) => v.length > 0);
  if (ids.length === 0) return null;
  try {
    const numericIds = Array.from(new Set(ids))
      .map((v) => parseInt(v, 10))
      .filter((n) => Number.isFinite(n));
    if (numericIds.length === 0) return null;
    const sprints = await Sprint.findAll({
      where: { id: { [Op.in]: numericIds } },
      order: [['start_date', 'ASC'], ['created_at', 'ASC']],
    });
    if (!sprints || sprints.length === 0) {
      // Return basic structure even if no sprints found to avoid errors
      return {
        project: null,
        sprint: {
          id: ids.join(','),
          name: 'Sprint Details Not Found',
          startDate: null,
          endDate: null,
          status: 'unknown',
          sprintCount: 0,
        },
        summary: {
          sprintCount: 0,
          totalCommittedPoints: 0,
          totalCompletedPoints: 0,
          totalCarriedOverPoints: 0,
          totalDefectsOpened: 0,
          totalDefectsClosed: 0,
          averageTestPassRate: 0,
          scopeChanges: [],
        },
        team: null,
        deliverables: [],
        performanceMetrics: [],
      };
    }
    const performanceMetrics = await generatePerformanceMetrics(numericIds);
    const totalCommitted = performanceMetrics.reduce((sum, item) => sum + Number(item.committed_points || 0), 0);
    const totalCompleted = performanceMetrics.reduce((sum, item) => sum + Number(item.completed_points || 0), 0);
    const totalCarried = performanceMetrics.reduce((sum, item) => sum + Number(item.carried_over_points || 0), 0);
    const totalOpened = performanceMetrics.reduce((sum, item) => sum + Number(item.defects_opened || 0), 0);
    const totalClosed = performanceMetrics.reduce((sum, item) => sum + Number(item.defects_closed || 0), 0);
    const avgPassRate = performanceMetrics.length > 0
      ? Math.round(
          performanceMetrics.reduce((sum, item) => sum + Number(item.test_pass_rate || 0), 0) / performanceMetrics.length
        )
      : 0;
    const firstSprint = sprints[0];
    const lastSprint = sprints[sprints.length - 1];
    const scopeChanges = performanceMetrics.map((item) => ({
      sprintId: item.sprintId,
      sprintName: item.name,
      pointsAdded: Number(item.points_added || 0),
      pointsRemoved: Number(item.points_removed || 0),
      indicator: item.scope_change_indicator || 'No change',
    }));
    return {
      project: firstSprint && firstSprint.project_id ? { id: firstSprint.project_id } : null,
      sprint: {
        id: sprints.length === 1 ? String(firstSprint.id) : ids.join(','),
        name: sprints.length === 1
          ? (firstSprint.name || `Sprint ${firstSprint.id}`)
          : `${sprints.length} Linked Sprints`,
        startDate: firstSprint && firstSprint.start_date ? new Date(firstSprint.start_date).toISOString() : null,
        endDate: lastSprint && lastSprint.end_date ? new Date(lastSprint.end_date).toISOString() : null,
        status: sprints.every((s) => isSprintCompletedStatus(s.status)) ? 'completed' : 'mixed',
        sprintCount: sprints.length,
      },
      summary: {
        sprintCount: sprints.length,
        totalCommittedPoints: totalCommitted,
        totalCompletedPoints: totalCompleted,
        totalCarriedOverPoints: totalCarried,
        totalDefectsOpened: totalOpened,
        totalDefectsClosed: totalClosed,
        averageTestPassRate: avgPassRate,
        scopeChanges,
      },
      team: null,
      deliverables: [],
      performanceMetrics,
    };
  } catch (_) {
    // Return basic structure on error to avoid errors
    return {
      project: null,
      sprint: {
        id: ids.join(','),
        name: 'Sprint Details Not Found',
        startDate: null,
        endDate: null,
        status: 'unknown',
        sprintCount: 0,
      },
      summary: {
        sprintCount: 0,
        totalCommittedPoints: 0,
        totalCompletedPoints: 0,
        totalCarriedOverPoints: 0,
        totalDefectsOpened: 0,
        totalDefectsClosed: 0,
        averageTestPassRate: 0,
        scopeChanges: [],
      },
      team: null,
      deliverables: [],
      performanceMetrics: [],
    };
  }
}

function normalizeReportStatusValue(value) {
  const raw = String(value || '').trim().toLowerCase().replace(/[\s_-]+/g, '');
  if (!raw) return 'draft';
  if (raw === 'underreview') return 'under_review';
  if (raw === 'changerequested') return 'change_requested';
  return raw;
}

function effectiveReportTimestamp(content, row) {
  const c = content || {};
  return (
    c.approvedAt ||
    c.approved_at ||
    c.reviewedAt ||
    c.reviewed_at ||
    c.submittedAt ||
    c.submitted_at ||
    row.updated_at ||
    row.created_at ||
    null
  );
}

function buildReportVersionEntry(content, row, reason, actor) {
  const c = content || {};
  return {
    version: Number(c.currentVersion || 1),
    status: row && row.status ? String(row.status) : normalizeReportStatusValue(c.status),
    reportTitle: c.reportTitle || c.report_title || 'Untitled Report',
    savedAt: new Date().toISOString(),
    savedBy: actor && actor.id ? String(actor.id) : null,
    savedByName: actor && actor.name ? actor.name : null,
    savedByRole: actor && actor.role ? (roleDisplayValue(actor.role) || actor.role) : null,
    reason: reason || 'updated',
    snapshot: {
      reportContent: c.reportContent || c.report_content || '',
      sprintIds: c.sprintIds || c.sprint_ids || [],
      sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data || null,
      sprintReportData: c.sprintReportData || c.sprint_report_data || null,
      knownLimitations: c.knownLimitations || c.known_limitations || null,
      nextSteps: c.nextSteps || c.next_steps || null,
      clientComment: c.clientComment || c.client_comment || null,
      changeRequestDetails: c.changeRequestDetails || c.change_request_details || null,
    },
  };
}

function appendReportVersion(content, row, reason, actor) {
  const current = content || {};
  const history = Array.isArray(current.versionHistory) ? [...current.versionHistory] : [];
  history.unshift(buildReportVersionEntry(current, row || {}, reason, actor));
  return {
    ...current,
    currentVersion: Number(current.currentVersion || 0) + 1,
    versionHistory: history.slice(0, 25),
  };
}

async function recordReportAudit({ action, reportId, reportTitle, actor, details }) {
  try {
    const payload = {
      action,
      user_id: actor && actor.id ? actor.id : null,
      user_email: actor && actor.email ? actor.email : null,
      user_role: actor && actor.role ? (roleDisplayValue(actor.role) || actor.role) : null,
      entity_type: 'signoff',
      entity_id: String(reportId),
      entity_name: reportTitle || 'Sign-Off Report',
      created_at: new Date(),
    };
    if (details && typeof details === 'object') {
      payload.details = details;
    }
    await AuditLog.create(payload);
  } catch (auditErr) {
    console.error(`Error creating audit log for ${action}:`, auditErr);
  }
}

function normalizeRoleValue(r) {
  return String(r || '').toLowerCase().replace(/[\s_-]+/g, '');
}

function roleDisplayValue(role) {
  const raw = String(role || '').trim();
  if (!raw) return null;
  const spaced = raw
    .replace(/[_-]+/g, ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .trim();
  if (!spaced) return null;
  return spaced
    .split(/\s+/g)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

function buildUserDisplayName(u) {
  if (!u) return '';
  const name = (u.name || '').toString().trim();
  if (name) return name;
  const first = (u.first_name || u.firstName || '').toString().trim();
  const last = (u.last_name || u.lastName || '').toString().trim();
  const full = `${first} ${last}`.trim();
  if (full) return full;
  const username = (u.username || '').toString().trim();
  if (username) return username;
  const email = (u.email || '').toString().trim();
  if (email) return email;
  return '';
}

function sanitizeReportTitle(value) {
  const title = String(value || '').trim();
  if (!title) return title;
  const hasDigit = (s) => /\d/.test(String(s || ''));

  const bracketed = /^(.*)\s*[\[\(]\s*([A-Za-z0-9-]{6,})\s*[\]\)]\s*$/.exec(title);
  if (bracketed && hasDigit(bracketed[2])) {
    const base = String(bracketed[1] || '').trim();
    return base || title;
  }

  const dashed = /^(.*)\s*[-–—]\s*([A-Za-z0-9-]{6,})\s*$/.exec(title);
  if (dashed && hasDigit(dashed[2])) {
    const base = String(dashed[1] || '').trim();
    return base || title;
  }

  return title;
}

async function resolveActorIdentity({ userId, email }) {
  const uuidLike = (v) => typeof v === 'string' && /^[0-9a-fA-F-]{36}$/.test(v);
  const emailLike = (v) => typeof v === 'string' && v.includes('@') && v.trim() !== '';

  const id = typeof userId === 'string' && userId.trim() !== '' ? userId.trim() : null;
  const em = typeof email === 'string' && email.trim() !== '' ? email.trim() : null;

  try {
    if (id) {
      const u = await User.findByPk(id);
      if (u) {
        const name = buildUserDisplayName(u);
        return { id: String(u.id || id), email: u.email || em, role: u.role, name: name || (u.email || em || 'Unknown User') };
      }
    }
  } catch (_) {}

  try {
    const lookupEmail = (em && emailLike(em)) ? em : (id && emailLike(id) ? id : null);
    if (lookupEmail) {
      const u = await User.findOne({ where: { email: lookupEmail } });
      if (u) {
        const name = buildUserDisplayName(u);
        return { id: id || u.id || lookupEmail, email: u.email || lookupEmail, role: u.role, name: name || (u.email || lookupEmail) };
      }
      return { id: id || lookupEmail, email: lookupEmail, role: null, name: lookupEmail };
    }
  } catch (_) {}

  const fallback = em || id;
  return { id: fallback, email: em, role: null, name: fallback || 'Unknown User' };
}

/**
 * Extract and validate client review token from request
 * @param {object} req - Express request object
 * @returns {object|null} - Token payload with reportId and clientEmail, or null if invalid
 */
function extractReviewToken(req) {
  try {
    // Check for token in query, body, or header
    let token = req.query.token || req.body.token || req.headers['x-review-token'];
    if (!token && req.headers.authorization) {
      const authHeader = req.headers.authorization;
      if (authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      }
    }
    
    if (!token) return null;
    
    const payload = verifyToken(token);
    if (!payload || payload.type !== 'client_review') {
      return null;
    }
    
    return {
      reportId: payload.reportId,
      clientEmail: payload.clientEmail,
      token: token
    };
  } catch (error) {
    return null;
  }
}

router.use(optionalAuthenticateToken);

let reportsTableReady = false;
function getSequelizeDialect() {
  try {
    return sequelize && typeof sequelize.getDialect === 'function' ? sequelize.getDialect() : '';
  } catch (_) {
    return '';
  }
}

function reportsIdWhere(paramIndex = 1) {
  const dialect = getSequelizeDialect();
  const p = `$${paramIndex}`;
  if (dialect === 'postgres') return `id::text = ${p}`;
  return `id = ${p}`;
}

async function ensureReportsTable() {
  if (reportsTableReady) return;
  try {
    console.log('[sign-off-reports] Ensuring table exists');
    await sequelize.query(
      "CREATE TABLE IF NOT EXISTS sign_off_reports (\n        id SERIAL PRIMARY KEY,\n        deliverable_id VARCHAR(255),\n        created_by VARCHAR(255),\n        status VARCHAR(50) DEFAULT 'draft',\n        content JSONB,\n        created_at TIMESTAMP DEFAULT NOW(),\n        updated_at TIMESTAMP DEFAULT NOW()\n      )"
    );
    console.log('[sign-off-reports] Table ensured');
    reportsTableReady = true;
  } catch (e) {
    console.error('Error ensuring sign_off_reports table:', e);
  }
}

/**
 * @route POST /api/sign-off-reports/from-sprint/:sprintId
 * @desc Create a sprint-based sign-off report (draft) populated with sprint, project, deliverables, and team data
 * @access Private
 */
router.post('/from-sprint/:sprintId', async (req, res) => {
  try {
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const roleNorm = normalizeRoleValue(req.user && req.user.role);
    if (roleNorm !== 'deliverylead') {
      return res.status(403).json({ error: 'Only delivery leads can prepare sprint sign-off reports' });
    }
    const { sprintId } = req.params;
    const note = (req.body && req.body.note) ? String(req.body.note) : null;
    const { Sprint, Project, Deliverable, User } = require('../models');
    const now = new Date();
    const sprint = await Sprint.findByPk(sprintId, {
      include: [
        { model: Project, as: 'project', attributes: ['id', 'name', 'key'] },
        {
          model: Deliverable,
          as: 'deliverables',
          through: { attributes: [] },
          required: false,
          include: [
            { model: User, as: 'owner', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] },
          ],
        },
      ],
    });
    if (!sprint) {
      return res.status(404).json({ error: 'Sprint not found' });
    }
    if (!isSprintCompletedStatus(sprint.status)) {
      return res.status(400).json({ error: 'Sprint must be completed before creating a sprint sign-off report' });
    }
    const sprintJson = (sprint && typeof sprint.toJSON === 'function') ? sprint.toJSON() : sprint;
    const isPresent = (v) => v !== null && v !== undefined && String(v).trim() !== '';
    const pick = (...keys) => {
      for (const k of keys) {
        if (sprintJson && Object.prototype.hasOwnProperty.call(sprintJson, k) && isPresent(sprintJson[k])) {
          return sprintJson[k];
        }
      }
      return null;
    };
    const hasRequiredOnSprint =
      isPresent(pick('test_pass_rate', 'testPassRate')) &&
      isPresent(pick('defects_opened', 'defectsOpened')) &&
      isPresent(pick('defects_closed', 'defectsClosed')) &&
      isPresent(pick('code_review_completion', 'codeReviewCompletion')) &&
      isPresent(pick('documentation_status', 'documentationStatus'));

    if (!hasRequiredOnSprint) {
      try {
        const [metricsRows] = await sequelize.query(
          `SELECT 1 FROM sprint_metrics WHERE sprint_id = $1 ORDER BY recorded_at DESC LIMIT 1`,
          { bind: [sprintId] }
        );
        if (!metricsRows || metricsRows.length === 0) {
          return res.status(400).json({ error: 'Sprint metrics must be completed before creating a sprint sign-off report' });
        }
      } catch (_) {
        return res.status(400).json({ error: 'Sprint metrics must be completed before creating a sprint sign-off report' });
      }
    }
    const allProjectSprints = sprint.project_id
      ? await Sprint.findAll({ where: { project_id: sprint.project_id }, attributes: ['id', 'status'] })
      : [];
    const totalSprints = allProjectSprints.length;
    const completedSprints = allProjectSprints.filter((s) => isSprintCompletedStatus(s.status)).length;
    const sprintSuccessRate = totalSprints > 0 ? Math.round((completedSprints / totalSprints) * 100) : 0;

    function normalizeStatus(v) {
      return String(v || '').toLowerCase().replace(/[\s_-]+/g, '');
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
    function ownerDisplay(u) {
      const first = (u && (u.first_name || '')).toString().trim();
      const last = (u && (u.last_name || '')).toString().trim();
      const full = `${first} ${last}`.trim();
      return full || (u && u.email) || null;
    }

    const rawDeliverables = Array.isArray(sprint.deliverables) ? sprint.deliverables : [];
    const deliverables = rawDeliverables.map((d) => {
      const progressPercent = deliverableProgressPercent(d.status);
      const dueDate = d.due_date ? new Date(d.due_date) : null;
      const createdAt = d.created_at ? new Date(d.created_at) : null;
      const updatedAt = d.updated_at ? new Date(d.updated_at) : null;
      const completionDate = d.approved_at ? new Date(d.approved_at) : (d.submitted_at ? new Date(d.submitted_at) : null);
      const category = deliverableStatusCategory(d, now);
      const isOverdue = category === 'overdue';
      const owner = d.owner || null;
      const ownerId = owner && owner.id ? String(owner.id) : (d.owner_id ? String(d.owner_id) : null);
      const ownerName = owner ? ownerDisplay(owner) : null;
      return {
        id: d.id != null ? String(d.id) : '',
        name: d.title || d.name || `Deliverable ${d.id}`,
        description: d.description || '',
        ownerId,
        ownerName,
        ownerRole: owner && owner.role ? String(owner.role) : null,
        createdAt: createdAt ? createdAt.toISOString() : null,
        dueDate: dueDate ? dueDate.toISOString() : null,
        status: d.status || 'draft',
        progressPercent,
        lastUpdated: updatedAt ? updatedAt.toISOString() : null,
        completionDate: completionDate ? completionDate.toISOString() : null,
        isOverdue,
        category,
      };
    });

    const total = deliverables.length;
    const counts = { completed: 0, in_progress: 0, not_started: 0, overdue: 0, blocked: 0 };
    let sumProgress = 0;
    for (const d of deliverables) {
      sumProgress += Number(d.progressPercent || 0);
      if (counts[d.category] !== undefined) counts[d.category] += 1;
    }
    const progressPercent = total > 0 ? Math.round(sumProgress / total) : 0;
    const completionRate = total > 0 ? Math.round((counts.completed / total) * 100) : 0;

    const { ProjectMember } = require('../models');
    const deliverablesByOwner = new Map();
    for (const d of deliverables) {
      const ownerId = d.ownerId ? String(d.ownerId) : null;
      if (!ownerId) continue;
      const list = deliverablesByOwner.get(ownerId) || [];
      list.push(d);
      deliverablesByOwner.set(ownerId, list);
    }

    let team = [];
    try {
      if (sprint.project_id) {
        const members = await ProjectMember.findAll({
          where: { project_id: sprint.project_id },
          include: [{ model: User, as: 'user', attributes: ['id', 'email', 'first_name', 'last_name', 'role'] }],
        });
        team = members.map((pm) => {
          const u = pm.user || null;
          const uid = u && u.id != null ? String(u.id) : null;
          const workList = uid ? (deliverablesByOwner.get(uid) || []) : [];
          const work = workList.length === 0
            ? 'No sprint deliverables assigned'
            : workList.map((d) => `${d.name} (${d.status || 'unknown'})`).join(', ');
          return {
            id: uid || '',
            name: u ? ownerDisplay(u) : null,
            email: u && u.email ? String(u.email) : null,
            role: pm.role || (u && u.role ? String(u.role) : null),
            work,
          };
        }).filter((m) => m.name || m.email);
      }
    } catch (_) {
      team = [];
    }

    const health = (counts.overdue > 0)
      ? 'critical'
      : (sprint.end_date && new Date(sprint.end_date).getTime() < now.getTime() && completionRate < 100 ? 'warning' : 'good');

    const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
    const actorRole = roleDisplayValue(actor.role) || actor.role || null;

    const sprintDetails = {
      id: String(sprint.id),
      name: sprint.name || `Sprint ${sprintId}`,
      startDate: sprint.start_date ? new Date(sprint.start_date).toISOString() : null,
      endDate: sprint.end_date ? new Date(sprint.end_date).toISOString() : null,
      status: sprint.status || null,
    };
    const projectDetails = sprint.project
      ? { id: sprint.project.id, name: sprint.project.name, key: sprint.project.key }
      : null;
    const summary = {
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
    };

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
    const fmt = (v) => (v == null || String(v).trim() === '' ? '-' : String(v));
    const fmtPct = (n) => `${Number(n || 0)}%`;

    const reportLines = [];
    reportLines.push('PROJECT');
    reportLines.push(`Name: ${fmt(projectDetails && projectDetails.name)}`);
    reportLines.push(`Key: ${fmt(projectDetails && projectDetails.key)}`);
    reportLines.push(`ID: ${fmt(projectDetails && projectDetails.id)}`);
    reportLines.push('');
    reportLines.push('SPRINT');
    reportLines.push(`Name: ${fmt(sprintDetails.name)}`);
    reportLines.push(`ID: ${fmt(sprintDetails.id)}`);
    reportLines.push(`Status: ${fmt(sprintDetails.status)}`);
    reportLines.push(`Start: ${fmtIso(sprintDetails.startDate)}`);
    reportLines.push(`End: ${fmtIso(sprintDetails.endDate)}`);
    reportLines.push('');
    reportLines.push('SPRINT SUMMARY');
    reportLines.push(`Total Deliverables: ${summary.totalDeliverables}`);
    reportLines.push(`Completed: ${summary.completedDeliverables}`);
    reportLines.push(`In Progress: ${summary.inProgressDeliverables}`);
    reportLines.push(`Not Started: ${summary.notStartedDeliverables}`);
    reportLines.push(`Overdue: ${summary.overdueDeliverables}`);
    reportLines.push(`Blocked: ${summary.blockedDeliverables}`);
    reportLines.push(`Sprint Progress: ${fmtPct(summary.sprintProgressPercent)}`);
    reportLines.push(`Completion Rate: ${fmtPct(summary.completionRatePercent)}`);
    reportLines.push(`Health: ${fmt(summary.health).toUpperCase()}`);
    reportLines.push('');
    reportLines.push('TEAM MEMBERS');
    if (team.length === 0) {
      reportLines.push('None');
    } else {
      for (const m of team) {
        const work = m.work ? String(m.work) : '';
        reportLines.push(`- ${fmt(m.name)} | ${fmt(m.email)} | ${fmt(m.role)}${work ? ' | Work: ' + work : ''}`);
      }
    }
    reportLines.push('');
    reportLines.push('DELIVERABLES');
    if (deliverables.length === 0) {
      reportLines.push('None');
    } else {
      for (const d of deliverables) {
        reportLines.push(
          `- ${fmt(d.name)} | Owner: ${fmt(d.ownerName)} | Status: ${fmt(d.status)} | Progress: ${fmtPct(d.progressPercent)} | Due: ${fmtIso(d.dueDate)} | Completed: ${fmtIso(d.completionDate)} | Category: ${fmt(d.category)} | Overdue: ${d.isOverdue ? 'yes' : 'no'}`
        );
      }
    }
    reportLines.push('');
    reportLines.push('SIGN-OFF NOTES');
    reportLines.push(note && note.trim() ? note.trim() : '-');

    const sprintPerformanceData = JSON.stringify([{
      id: String(sprint.id),
      name: sprintDetails.name,
      status: sprint.status || null,
      start_date: sprintDetails.startDate,
      end_date: sprintDetails.endDate,
      planned_points: sprint.planned_points ?? 0,
      committed_points: sprint.committed_points ?? 0,
      completed_points: sprint.completed_points ?? 0,
      carried_over_points: sprint.carried_over_points ?? 0,
      points_added: sprint.added_during_sprint ?? 0,
      points_removed: sprint.removed_during_sprint ?? 0,
      test_pass_rate: sprint.test_pass_rate ?? 0,
      defects_opened: sprint.defects_opened ?? 0,
      defects_closed: sprint.defects_closed ?? 0,
      code_review_completion: sprint.code_review_completion ?? 0,
      documentation_status: sprint.documentation_status ?? null,
    }]);

    let content = {
      reportTitle: `Sprint Report: ${sprint.name || 'Sprint ' + sprintId}`,
      reportContent: reportLines.join('\n'),
      sprintIds: [String(sprintId)],
      sprintPerformanceData,
      sprintReportData: {
        project: projectDetails,
        sprint: sprintDetails,
        summary,
        team: { members: team },
        deliverables,
      },
      preparedBy: actor.id,
      preparedByName: actor.name,
      preparedByRole: actorRole,
      status: 'draft',
    };
    content = appendReportVersion(content, { status: 'draft' }, 'created_from_sprint', actor);

    const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
    const contentExpr = dialect === 'postgres' ? '$3::jsonb' : '$3';
    const [results] = await sequelize.query(
      `INSERT INTO sign_off_reports (deliverable_id, created_by, status, content) VALUES ($1, $2, $4, ${contentExpr}) RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
      { bind: [null, String(req.user.id), JSON.stringify(content), 'draft'] }
    );
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const report = {
      id: row.id,
      deliverableId: (row.deliverable_id || '').toString(),
      reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
      reportContent: (c.reportContent || c.report_content || ''),
      sprintIds: c.sprintIds || c.sprint_ids || [],
      sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
      sprintReportData: c.sprintReportData || c.sprint_report_data || null,
      status: row.status || 'draft',
      preparedBy: c.preparedBy || c.prepared_by,
      preparedByName: c.preparedByName || c.prepared_by_name,
      preparedByRole: c.preparedByRole || c.prepared_by_role,
      createdAt: row.created_at,
      createdBy: (row.created_by || '').toString(),
    };
    if (global.realtimeEvents) {
      global.realtimeEvents.emit('report_created', {
        id: report.id,
        reportTitle: report.reportTitle,
        created_by: report.createdBy
      });
    }
    await recordReportAudit({
      action: 'created',
      reportId: report.id,
      reportTitle: report.reportTitle,
      actor,
      details: { sprint_ids: [String(sprintId)], version: content.currentVersion || 1 },
    });
    return res.status(201).json(report);
  } catch (error) {
    console.error('Error creating sprint sign-off report:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/signoff/sprint/:sprintId
 * @desc Get all signoffs for a specific sprint
 * @access Public
 */
router.get('/sprint/:sprintId', async (req, res) => {
  try {
    const { sprintId } = req.params;
    
    const signoffs = await Signoff.findAll({
      where: { 
        entity_type: 'sprint',
        entity_id: sprintId 
      },
      order: [['created_at', 'DESC']]
    });
    
    res.json(signoffs);
  } catch (error) {
    console.error('Error fetching sprint signoffs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/', async (req, res) => {
  try {
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    
    await ensureReportsTable();
    
    const { deliverableId, status, search, projectId, sprintId, from, to } = req.query;
    let results;
    try {
      const normalizeStatus = (s) => {
        const x = String(s || '').toLowerCase().replace(/[\s_-]+/g, '');
        if (!x) return '';
        if (x === 'underreview') return 'under_review';
        if (x === 'changerequested') return 'change_requested';
        return x;
      };
      const s = normalizeStatus(status);
      if (deliverableId && s) {
        results = await sequelize.query(
          "SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE deliverable_id = $1 AND LOWER(REPLACE(status, '-', '')) = LOWER(REPLACE($2, '-', '')) ORDER BY created_at DESC",
          { bind: [deliverableId, s], type: QueryTypes.SELECT }
        );
      } else if (deliverableId) {
        results = await sequelize.query(
          "SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE deliverable_id = $1 ORDER BY created_at DESC",
          { bind: [deliverableId], type: QueryTypes.SELECT }
        );
      } else if (s) {
        results = await sequelize.query(
          "SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE LOWER(REPLACE(status, '-', '')) = LOWER(REPLACE($1, '-', '')) ORDER BY created_at DESC",
          { bind: [s], type: QueryTypes.SELECT }
        );
      } else {
        results = await sequelize.query(
          "SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports ORDER BY created_at DESC",
          { type: QueryTypes.SELECT }
        );
      }
    } catch (dbErr) {
      results = [];
    }
    const rawRows = Array.isArray(results) ? results : [];
    const looksLikeUserId = (v) => {
      if (!v) return false;
      const s = String(v).trim();
      if (!s) return false;
      if (s.includes('@')) return false;
      if (/\s/.test(s)) return false;
      return /^[a-f0-9-]{8,}$/i.test(s) || /^\d+$/.test(s);
    };
    const userIds = new Set(rawRows.map((r) => r.created_by).filter(Boolean));
    const emails = new Set();
    for (const row of rawRows) {
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const submittedBy = c.submittedBy || c.submitted_by;
      const reviewedBy = c.reviewedBy || c.reviewed_by;
      const approvedBy = c.approvedBy || c.approved_by;
      const preparedBy = c.preparedBy || c.prepared_by;
      if (looksLikeUserId(submittedBy)) userIds.add(String(submittedBy));
      if (looksLikeUserId(reviewedBy)) userIds.add(String(reviewedBy));
      if (looksLikeUserId(approvedBy)) userIds.add(String(approvedBy));
      if (looksLikeUserId(preparedBy)) userIds.add(String(preparedBy));
      if (typeof submittedBy === 'string' && submittedBy.includes('@')) emails.add(submittedBy);
      if (typeof reviewedBy === 'string' && reviewedBy.includes('@')) emails.add(reviewedBy);
      if (typeof approvedBy === 'string' && approvedBy.includes('@')) emails.add(approvedBy);
      if (typeof preparedBy === 'string' && preparedBy.includes('@')) emails.add(preparedBy);
    }
    const usersById = userIds.size > 0 ? await User.findAll({ where: { id: [...userIds] } }) : [];
    const usersByEmail = emails.size > 0 ? await User.findAll({ where: { email: [...emails] } }) : [];
    const numericDeliverableIds = [...new Set(rawRows
      .map((r) => parseInt(r.deliverable_id, 10))
      .filter((n) => Number.isFinite(n)))];
    const deliverablesById = new Map();
    const projectsById = new Map();
    if (numericDeliverableIds.length > 0) {
      const linkedDeliverables = await Deliverable.findAll({
        where: { id: { [Op.in]: numericDeliverableIds } },
        attributes: ['id', 'title', 'status', 'project_id'],
      });
      for (const deliverable of linkedDeliverables) {
        deliverablesById.set(String(deliverable.id), deliverable);
      }
      const projectIds = [...new Set(linkedDeliverables
        .map((d) => d.project_id)
        .filter(Boolean)
        .map((v) => String(v)))];
      if (projectIds.length > 0) {
        const { Project } = require('../models');
        const projects = await Project.findAll({
          where: { id: { [Op.in]: projectIds } },
          attributes: ['id', 'name', 'key'],
        });
        for (const project of projects) {
          projectsById.set(String(project.id), project);
        }
      }
    }
    const userNameMap = new Map();
    const userRoleMap = new Map();
    for (const u of usersById) {
      const display = buildUserDisplayName(u);
      const roleVal = u && u.role ? String(u.role) : null;
      if (u.id) userNameMap.set(u.id, display);
      if (u.email) userNameMap.set(u.email, display);
      if (u.id && roleVal) userRoleMap.set(u.id, roleVal);
      if (u.email && roleVal) userRoleMap.set(u.email, roleVal);
    }
    for (const u of usersByEmail) {
      const display = buildUserDisplayName(u);
      const roleVal = u && u.role ? String(u.role) : null;
      if (u.id) userNameMap.set(u.id, display);
      if (u.email) userNameMap.set(u.email, display);
      if (u.id && roleVal) userRoleMap.set(u.id, roleVal);
      if (u.email && roleVal) userRoleMap.set(u.email, roleVal);
    }
    let reports = rawRows.map((row) => {
      try {
        const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
        const submittedBy = c.submittedBy || c.submitted_by;
        const reviewedBy = c.reviewedBy || c.reviewed_by;
        const approvedBy = c.approvedBy || c.approved_by;
        const preparedBy = c.preparedBy || c.prepared_by || (row.created_by || '').toString();
        const linkedDeliverable = deliverablesById.get((row.deliverable_id || '').toString()) || null;
        const linkedProject = linkedDeliverable && linkedDeliverable.project_id
          ? projectsById.get(String(linkedDeliverable.project_id)) || null
          : null;
        return {
          id: row.id,
          deliverableId: (row.deliverable_id || '').toString(),
          deliverableTitle: linkedDeliverable ? linkedDeliverable.title : null,
          projectId: linkedDeliverable && linkedDeliverable.project_id ? String(linkedDeliverable.project_id) : null,
          projectName: linkedProject ? linkedProject.name : null,
          reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
          reportContent: (c.reportContent || c.report_content || ''),
          sprintIds: c.sprintIds || c.sprint_ids || [],
          sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
          knownLimitations: c.knownLimitations || c.known_limitations,
          nextSteps: c.nextSteps || c.next_steps,
          status: row.status || 'draft',
          updatedAt: row.updated_at,
          effectiveAt: effectiveReportTimestamp(c, row),
          isArchived: Boolean(c.isArchived),
          archivedAt: c.archivedAt || null,
          currentVersion: Number(c.currentVersion || 0),
          versionHistory: Array.isArray(c.versionHistory) ? c.versionHistory : [],
          preparedBy: preparedBy,
          preparedByName:
            c.preparedByName ||
            c.prepared_by_name ||
            userNameMap.get(preparedBy) ||
            userNameMap.get((row.created_by || '').toString()) ||
            null,
          preparedByRole:
            c.preparedByRole ||
            c.prepared_by_role ||
            userRoleMap.get(preparedBy) ||
            userRoleMap.get((row.created_by || '').toString()) ||
            null,
          createdAt: row.created_at,
          createdBy: (row.created_by || '').toString(),
          createdByName: userNameMap.get(row.created_by) || null,
          submittedAt: c.submittedAt || c.submitted_at,
          submittedBy: submittedBy,
          submittedByName:
            c.submittedByName ||
            c.submitted_by_name ||
            userNameMap.get(String(submittedBy)) ||
            null,
          submittedByRole:
            c.submittedByRole ||
            c.submitted_by_role ||
            userRoleMap.get(String(submittedBy)) ||
            null,
          reviewedAt: c.reviewedAt || c.reviewed_at,
          reviewedBy: reviewedBy,
          reviewedByName:
            c.reviewedByName ||
            c.reviewed_by_name ||
            userNameMap.get(String(reviewedBy)) ||
            null,
          reviewedByRole:
            c.reviewedByRole ||
            c.reviewed_by_role ||
            userRoleMap.get(String(reviewedBy)) ||
            null,
          clientComment: c.clientComment || c.client_comment,
          changeRequestDetails: c.changeRequestDetails || c.change_request_details,
          approvedAt: c.approvedAt || c.approved_at,
          approvedBy: approvedBy,
          approvedByName:
            c.approvedByName ||
            c.approved_by_name ||
            userNameMap.get(String(approvedBy)) ||
            null,
          approvedByRole:
            c.approvedByRole ||
            c.approved_by_role ||
            userRoleMap.get(String(approvedBy)) ||
            null,
          digitalSignature: c.digitalSignature || c.digital_signature,
        };
      } catch (e) {
        return {
          id: row.id,
          deliverableId: (row.deliverable_id || '').toString(),
          reportTitle: 'Untitled Report',
          reportContent: '',
          sprintIds: [],
          status: row.status || 'draft',
          createdAt: row.created_at,
          createdBy: (row.created_by || '').toString(),
          createdByName: userNameMap.get(row.created_by) || null,
        };
      }
    });
    const role = normalizeRoleValue(req.user && req.user.role);
    const qStatus = String(req.query.status || '').toLowerCase().replace(/[\s_-]+/g, '');
    if (role === 'clientreviewer') {
      const allowedStatuses = new Set(['submitted', 'approved', 'underreview', 'under_review']);
      reports = reports.filter((r) => allowedStatuses.has(String(r.status || '').toLowerCase()));
      if (qStatus && !allowedStatuses.has(qStatus)) {
        return res.status(403).json({ error: 'Insufficient permissions' });
      }
    }
    const normalizedStatusFilter = String(status || '').trim()
      ? normalizeReportStatusValue(status)
      : '';
    const searchTerm = String(search || '').trim().toLowerCase();
    const fromDate = from ? new Date(String(from)) : null;
    const toDate = to ? new Date(String(to)) : null;
    if (normalizedStatusFilter) {
      reports = reports.filter((report) => normalizeReportStatusValue(report.status) === normalizedStatusFilter);
    }
    if (projectId) {
      reports = reports.filter((report) => String(report.projectId || '') === String(projectId));
    }
    if (sprintId) {
      reports = reports.filter((report) => Array.isArray(report.sprintIds) && report.sprintIds.map(String).includes(String(sprintId)));
    }
    if (searchTerm) {
      reports = reports.filter((report) => {
        const haystack = [
          report.reportTitle,
          report.reportContent,
          report.deliverableTitle,
          report.projectName,
          report.changeRequestDetails,
          report.clientComment,
          report.createdByName,
          report.preparedByName,
        ]
          .map((value) => String(value || '').toLowerCase())
          .join(' ');
        return haystack.includes(searchTerm);
      });
    }
    if (fromDate instanceof Date && !Number.isNaN(fromDate.getTime())) {
      reports = reports.filter((report) => {
        const ts = new Date(report.effectiveAt || report.createdAt || report.updatedAt || 0);
        return !Number.isNaN(ts.getTime()) && ts >= fromDate;
      });
    }
    if (toDate instanceof Date && !Number.isNaN(toDate.getTime())) {
      reports = reports.filter((report) => {
        const ts = new Date(report.effectiveAt || report.createdAt || report.updatedAt || 0);
        return !Number.isNaN(ts.getTime()) && ts <= toDate;
      });
    }
    if (rawRows.length === 0) {
      try {
        const signoffs = await Signoff.findAll({
          where: { entity_type: 'deliverable' },
          include: [{ model: Deliverable, as: 'deliverable', attributes: ['id', 'title', 'created_by'] }],
          order: [['submitted_at', 'DESC']],
          limit: 50
        });
        const fallbackReports = signoffs.map((s) => ({
          id: s.id,
          deliverableId: (s.deliverable?.id || s.entity_id || '').toString(),
          reportTitle: s.deliverable?.title || 'Deliverable Sign-off',
          reportContent: s.comments || '',
          sprintIds: [],
          status: s.decision || 'pending',
          createdAt: s.submitted_at,
          createdBy: s.deliverable?.created_by || '',
          reviewedAt: s.reviewed_at,
          reviewedBy: null,
          clientComment: s.comments || null,
        }));
        return res.json(fallbackReports);
      } catch (e) {
        console.error('Error building fallback sign-off reports:', e);
      }
    }
    res.json(reports);
  } catch (error) {
    console.error('Error fetching sign-off-reports list:', error);
    return res.json([]);
  }
});

/**
 * @route GET /api/signoff/:id
 * @desc Get a specific signoff by ID
 * @access Public
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      const [results] = await sequelize.query(
        `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!results || results.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const looksLikeUserId = (v) => {
        if (!v) return false;
        const s = String(v).trim();
        if (!s) return false;
        if (s.includes('@')) return false;
        if (/\s/.test(s)) return false;
        return /^[a-f0-9-]{8,}$/i.test(s) || /^\d+$/.test(s);
      };
      const creator = row.created_by ? await User.findByPk(row.created_by) : null;
      const createdByName = creator
        ? (creator.name ||
            `${creator.first_name || ''} ${creator.last_name || ''}`.trim() ||
            creator.username ||
            creator.email ||
            null)
        : null;
      const submittedBy = c.submittedBy || c.submitted_by;
      const reviewedBy = c.reviewedBy || c.reviewed_by;
      const approvedBy = c.approvedBy || c.approved_by;
      const preparedBy = c.preparedBy || c.prepared_by || (row.created_by || '').toString();
      const sprintIds = c.sprintIds || c.sprint_ids || [];
      const sprintReportDataFromContent = c.sprintReportData || c.sprint_report_data || null;
      const sprintReportData =
        sprintReportDataFromContent != null ? sprintReportDataFromContent : await buildSprintReportDataBySprintIds(sprintIds);
      const extraIds = [];
      if (looksLikeUserId(submittedBy)) extraIds.push(String(submittedBy));
      if (looksLikeUserId(reviewedBy)) extraIds.push(String(reviewedBy));
      if (looksLikeUserId(approvedBy)) extraIds.push(String(approvedBy));
      if (looksLikeUserId(preparedBy)) extraIds.push(String(preparedBy));
      const emails = [];
      if (typeof submittedBy === 'string' && submittedBy.includes('@')) emails.push(submittedBy);
      if (typeof reviewedBy === 'string' && reviewedBy.includes('@')) emails.push(reviewedBy);
      if (typeof approvedBy === 'string' && approvedBy.includes('@')) emails.push(approvedBy);
      if (typeof preparedBy === 'string' && preparedBy.includes('@')) emails.push(preparedBy);
      const extraUsers =
        extraIds.length > 0 ? await User.findAll({ where: { id: [...new Set(extraIds)] } }) : [];
      const extraUsersByEmail =
        emails.length > 0 ? await User.findAll({ where: { email: [...new Set(emails)] } }) : [];
      const userNameMap = new Map();
      const userRoleMap = new Map();
      for (const u of [...extraUsers, ...extraUsersByEmail]) {
        const display = buildUserDisplayName(u);
        const roleVal = u && u.role ? String(u.role) : null;
        if (u.id) userNameMap.set(u.id, display);
        if (u.email) userNameMap.set(u.email, display);
        if (u.id && roleVal) userRoleMap.set(u.id, roleVal);
        if (u.email && roleVal) userRoleMap.set(u.email, roleVal);
      }
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds,
        sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
        sprintReportData,
        knownLimitations: c.knownLimitations || c.known_limitations,
        nextSteps: c.nextSteps || c.next_steps,
        preparedBy: preparedBy,
        preparedByName:
          c.preparedByName ||
          c.prepared_by_name ||
          userNameMap.get(String(preparedBy)) ||
          createdByName ||
          null,
        preparedByRole:
          c.preparedByRole ||
          c.prepared_by_role ||
          userRoleMap.get(String(preparedBy)) ||
          null,
        status: row.status || 'draft',
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString(),
        createdByName: createdByName,
        submittedAt: c.submittedAt || c.submitted_at,
        submittedBy: submittedBy,
        submittedByName:
          c.submittedByName ||
          c.submitted_by_name ||
          userNameMap.get(String(submittedBy)) ||
          null,
        submittedByRole:
          c.submittedByRole ||
          c.submitted_by_role ||
          userRoleMap.get(String(submittedBy)) ||
          null,
        reviewedAt: c.reviewedAt || c.reviewed_at,
        reviewedBy: reviewedBy,
        reviewedByName:
          c.reviewedByName ||
          c.reviewed_by_name ||
          userNameMap.get(String(reviewedBy)) ||
          null,
        reviewedByRole:
          c.reviewedByRole ||
          c.reviewed_by_role ||
          userRoleMap.get(String(reviewedBy)) ||
          null,
        clientComment: c.clientComment || c.client_comment,
        changeRequestDetails: c.changeRequestDetails || c.change_request_details,
        versionHistory: Array.isArray(c.versionHistory) ? c.versionHistory : [],
        currentVersion: Number(c.currentVersion || 0),
        isArchived: Boolean(c.isArchived),
        archivedAt: c.archivedAt || null,
        sealedAt: c.sealedAt || null,
        approvedAt: c.approvedAt || c.approved_at,
        approvedBy: approvedBy,
        approvedByName:
          c.approvedByName ||
          c.approved_by_name ||
          userNameMap.get(String(approvedBy)) ||
          null,
        approvedByRole:
          c.approvedByRole ||
          c.approved_by_role ||
          userRoleMap.get(String(approvedBy)) ||
          null,
        digitalSignature: c.digitalSignature || c.digital_signature,
      };
      return res.json(report);
    }
    const signoff = await Signoff.findByPk(id, {
      include: [
        { association: 'deliverable' },
        { association: 'sprint' },
        { association: 'audit_logs' }
      ]
    });
    if (!signoff) {
      return res.status(404).json({ error: 'Signoff not found' });
    }
    res.json(signoff);
  } catch (error) {
    console.error('Error fetching signoff:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/signoff
 * @desc Create a new signoff
 * @access Private
 */
router.post('/', async (req, res) => {
  try {
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      await ensureReportsTable();
      
      // Validate required fields
      const {
        deliverableId,
        reportTitle,
        reportContent,
        sprintIds,
        sprintPerformanceData,
        knownLimitations,
        nextSteps,
        status
      } = req.body || {};
      
      const hasDeliverableId = deliverableId && typeof deliverableId === 'string' && deliverableId.trim().length > 0;
      const hasSprintIds = Array.isArray(sprintIds) && sprintIds.length > 0;
      
      if (!hasDeliverableId && !hasSprintIds) {
        return res.status(400).json({ error: 'Either deliverableId or sprintIds is required' });
      }
      if (!reportTitle || typeof reportTitle !== 'string' || reportTitle.trim().length === 0) {
        return res.status(400).json({ error: 'reportTitle is required' });
      }
      if (!reportContent || typeof reportContent !== 'string' || reportContent.trim().length === 0) {
        return res.status(400).json({ error: 'reportContent is required' });
      }

      const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
      const actorRole = actor.role ? String(actor.role) : (req.user && req.user.role ? String(req.user.role) : null);
      const normalizedStatus = (typeof status === 'string' && status.trim().length > 0) ? status.trim() : 'draft';

      // Only validate sprint completion status if not a draft
      if (normalizedStatus !== 'draft') {
        const sprintValidation = await validateCompletedSprintIds(sprintIds);
        if (sprintValidation) {
          return res.status(400).json(sprintValidation);
        }
      }
      const sprintReportData = await buildSprintReportDataBySprintIds(sprintIds);
      const hasValidSprintIds = Array.isArray(sprintIds) && sprintIds.length > 0;
      let content = {
        reportTitle: reportTitle.trim(),
        reportContent: reportContent.trim(),
        sprintIds: sprintIds || [],
        sprintPerformanceData: sprintPerformanceData || (hasValidSprintIds
          ? JSON.stringify(await generatePerformanceMetrics(sprintIds))
          : null),
        sprintReportData,
        knownLimitations,
        nextSteps,
        status: normalizedStatus,
        preparedBy: actor.id,
        preparedByName: actor.name,
        preparedByRole: actorRole
      };
      content = appendReportVersion(content, { status: normalizedStatus }, 'created', actor);
      const dialect = (sequelize && typeof sequelize.getDialect === 'function') ? sequelize.getDialect() : '';
      const contentExpr = dialect === 'postgres' ? '$4::jsonb' : '$4';
      const [results] = await sequelize.query(
        `INSERT INTO sign_off_reports (deliverable_id, created_by, status, content) VALUES ($1, $2, $3, ${contentExpr}) RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
        { bind: [hasDeliverableId ? deliverableId.trim() : null, String(req.user.id), normalizedStatus, JSON.stringify(content)] }
      );
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds: c.sprintIds || c.sprint_ids || [],
        sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
        sprintReportData: c.sprintReportData || c.sprint_report_data || null,
        knownLimitations: c.knownLimitations || c.known_limitations,
        nextSteps: c.nextSteps || c.next_steps,
        status: row.status || normalizedStatus,
        preparedBy: c.preparedBy || c.prepared_by,
        preparedByName: c.preparedByName || c.prepared_by_name,
        preparedByRole: c.preparedByRole || c.prepared_by_role,
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString(),
        createdByName: actor.name
      };
      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_created', {
          id: report.id,
          deliverableId: report.deliverableId,
          reportTitle: report.reportTitle,
          created_by: report.createdBy
        });
      }
      await recordReportAudit({
        action: 'created',
        reportId: report.id,
        reportTitle: report.reportTitle,
        actor,
        details: {
          deliverable_id: report.deliverableId,
          sprint_ids: report.sprintIds,
          version: content.currentVersion || 1,
        },
      });
      return res.status(201).json(report);
    }
    const signoffData = req.body;
    const signoff = await Signoff.create(signoffData);
    res.status(201).json(signoff);
  } catch (error) {
    console.error('Error creating signoff:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PUT /api/signoff/:id
 * @desc Update an existing signoff
 * @access Private
 */
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      await ensureReportsTable();
      const updates = { ...(req.body || {}) };
      const [existing] = await sequelize.query(
        `SELECT id, created_by, status, deliverable_id, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const ownerId = existing[0].created_by ? String(existing[0].created_by) : null;
      if (ownerId && req.user && String(req.user.id) !== ownerId) {
        return res.status(403).json({ error: 'Not authorized to update this report' });
      }
      
      // Seal check: Prevent updates if approved
      const currentStatus = String(existing[0].status || 'draft');
      if (currentStatus === 'approved') {
        return res.status(403).json({ error: 'Report is approved and sealed. No further updates allowed.' });
      }

      const nextSprintIds = Object.prototype.hasOwnProperty.call(updates, 'sprintIds')
        ? updates.sprintIds
        : (Object.prototype.hasOwnProperty.call(updates, 'sprint_ids') ? updates.sprint_ids : null);
      // Only validate sprint completion status if not a draft
      if (nextSprintIds != null && currentStatus !== 'draft') {
        const sprintValidation = await validateCompletedSprintIds(nextSprintIds);
        if (sprintValidation) {
          return res.status(400).json(sprintValidation);
        }
      }
      if (nextSprintIds != null) {
        const sprintReportData = await buildSprintReportDataBySprintIds(nextSprintIds);
        updates.sprintReportData = sprintReportData;
        updates.sprintPerformanceData = JSON.stringify(await generatePerformanceMetrics(nextSprintIds));
      }

      const currentRow = existing[0];
      const currentContent = currentRow && currentRow.content
        ? (typeof currentRow.content === 'string' ? safeParseJson(currentRow.content) : currentRow.content)
        : {};
      const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
      let mergedContent = {
        ...currentContent,
        ...updates,
      };
      if (updates.status != null) {
        mergedContent.status = updates.status;
      }
      mergedContent = appendReportVersion(mergedContent, currentRow, 'updated', actor);

      const [results] = await sequelize.query(
        `UPDATE sign_off_reports SET status = COALESCE($2, status), content = $3::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
        { bind: [id, updates.status ?? null, JSON.stringify(mergedContent)] }
      );
      if (!results || results.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds: c.sprintIds || c.sprint_ids || [],
        sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
        sprintReportData: c.sprintReportData || c.sprint_report_data || null,
        knownLimitations: c.knownLimitations || c.known_limitations,
        nextSteps: c.nextSteps || c.next_steps,
        status: row.status || 'draft',
        preparedBy: c.preparedBy || c.prepared_by,
        preparedByName: c.preparedByName || c.prepared_by_name,
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString()
      };
      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_updated', {
          id: report.id,
          deliverableId: report.deliverableId,
          reportTitle: report.reportTitle,
          created_by: report.createdBy,
          status: report.status
        });
      }
      await recordReportAudit({
        action: 'updated',
        reportId: report.id,
        reportTitle: report.reportTitle,
        actor,
        details: {
          updated_fields: Object.keys(updates),
          version: mergedContent.currentVersion || null,
        },
      });
      return res.json(report);
    }
    const updateData = req.body;
    const signoff = await Signoff.findByPk(id);
    if (!signoff) {
      return res.status(404).json({ error: 'Signoff not found' });
    }
    await signoff.update(updateData);
    res.json(signoff);
  } catch (error) {
    console.error('Error updating signoff:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/signoff/:id
 * @desc Delete a signoff
 * @access Private
 */
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      await ensureReportsTable();
      const [rows] = await sequelize.query(`DELETE FROM sign_off_reports WHERE ${reportsIdWhere(1)} RETURNING id`, { bind: [id] });
      if (!rows || rows.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_deleted', { id });
      }
      return res.status(204).send();
    }
    const signoff = await Signoff.findByPk(id);
    if (!signoff) {
      return res.status(404).json({ error: 'Signoff not found' });
    }
    await signoff.destroy();
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting signoff:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/signoff/:id/approve
 * @desc Approve a signoff
 * @access Private
 */
router.post('/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      const { comment, digitalSignature, clientId, clientName, clientRole } = req.body || {};
      
      // Check for review token (token-based access)
      const reviewToken = extractReviewToken(req);
      let approvedBy = null;
      let clientEmail = null;
      
      if (reviewToken) {
        // Validate token matches report ID
        if (reviewToken.reportId !== id.toString()) {
          return res.status(403).json({ error: 'Token is not valid for this report' });
        }
        approvedBy = clientId || reviewToken.clientEmail; // Use clientId from body or email from token
        clientEmail = reviewToken.clientEmail;
      } else if (req.user) {
        // Authenticated user
        approvedBy = req.user.id;
      } else {
        // Try to use clientId from body if provided
        approvedBy = clientId;
      }

      const user = req.user || {};
      const identity = await resolveActorIdentity({
        userId: user.id ? String(user.id) : (approvedBy ? String(approvedBy) : null),
        email: user.email || clientEmail || null
      });
      const actorId = identity.id || null;
      const actorEmail = identity.email || user.email || clientEmail || null;
      const actorName = (reviewToken && clientName && String(clientName).trim())
        ? String(clientName).trim()
        : identity.name;
      const actorRoleRaw =
        (reviewToken && clientRole && String(clientRole).trim())
          ? String(clientRole).trim()
          : (identity.role ? String(identity.role) : (user.role ? String(user.role) : (reviewToken ? 'clientReviewer' : null)));
      const actorRole = roleDisplayValue(actorRoleRaw) || actorRoleRaw || null;
      
      // Seal check: Prevent re-approval
      const [existing] = await sequelize.query(
        `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (existing && existing.length > 0 && existing[0].status === 'approved') {
        return res.status(403).json({ error: 'Report is already approved and sealed.' });
      }
      const currentRow = existing[0];
      const currentContent = currentRow && currentRow.content
        ? (typeof currentRow.content === 'string' ? safeParseJson(currentRow.content) : currentRow.content)
        : {};
      let mergedContent = {
        ...currentContent,
        reviewedAt: new Date().toISOString(),
        reviewedBy: actorId ?? approvedBy,
        reviewedByName: actorName,
        reviewedByRole: actorRole,
        reviewedByEmail: actorEmail,
        approvedAt: new Date().toISOString(),
        approvedBy: actorId ?? approvedBy,
        approvedByName: actorName,
        approvedByRole: actorRole,
        approvedByEmail: actorEmail,
        clientComment: comment ?? null,
        digitalSignature: digitalSignature ?? null,
        clientEmail: clientEmail || actorEmail,
        clientName: clientName ?? actorName,
        clientRole: clientRole ?? actorRole,
        sealedAt: new Date().toISOString(),
        sealedBy: actorId ?? approvedBy,
        status: 'approved',
      };
      mergedContent = appendReportVersion(
        mergedContent,
        { ...currentRow, status: 'approved' },
        'approved',
        { id: actorId ?? approvedBy, email: actorEmail, name: actorName, role: actorRole }
      );

      const [results] = await sequelize.query(
        `UPDATE sign_off_reports SET status = $2, content = $3::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
        { bind: [id, 'approved', JSON.stringify(mergedContent)] }
      );
      if (!results || results.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds: c.sprintIds || c.sprint_ids || [],
        status: row.status || 'approved',
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString(),
        approvedAt: c.approvedAt || c.approved_at,
        approvedBy: c.approvedBy || c.approved_by,
        approvedByName: c.approvedByName || c.approved_by_name || actorName,
        approvedByRole: c.approvedByRole || c.approved_by_role || actorRole,
        reviewedAt: c.reviewedAt || c.reviewed_at,
        reviewedBy: c.reviewedBy || c.reviewed_by,
        reviewedByName: c.reviewedByName || c.reviewed_by_name || actorName,
        reviewedByRole: c.reviewedByRole || c.reviewed_by_role || actorRole,
        clientComment: c.clientComment || c.client_comment,
        digitalSignature: c.digitalSignature || c.digital_signature
      };
      try {
        const did = parseInt(row.deliverable_id);
        if (Number.isFinite(did)) {
          const { Deliverable, Notification } = require('../models');
          const d = await Deliverable.findByPk(did);
          if (d) {
            await d.update({ status: 'approved' });
          }
          if (Notification) {
            await Notification.create({
              recipient_id: (row.created_by || null),
              sender_id: (req.user && req.user.id) || null,
              type: 'approval',
              message: `Report approved: "${report.reportTitle}"`,
              payload: { report_id: report.id, deliverable_id: did },
              is_read: false,
              created_at: new Date()
            });
          }
          try {
            const { ApprovalRequest } = require('../models');
            await ApprovalRequest.update(
              {
                status: 'approved',
                approved_by: (req.user && req.user.id) || null,
                approved_at: new Date(),
                comments: comment ?? null
              },
              { where: { deliverable_id: did, status: 'pending' } }
            );
          } catch (_) {}
        }
      } catch (_) {}
      // Create Audit Log
      await recordReportAudit({
        action: 'approved',
        reportId: report.id,
        reportTitle: report.reportTitle,
        actor: { id: actorId, email: actorEmail, name: actorName, role: actorRole },
        details: {
          comment: comment ?? null,
          digital_signature: digitalSignature ? 'Signed' : null,
          actor_name: actorName,
          version: mergedContent.currentVersion || null,
        },
      });

      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_approved', {
          id: report.id,
          deliverableId: report.deliverableId,
          reportTitle: report.reportTitle,
          created_by: report.createdBy,
          approvedBy: report.approvedBy
        });
      }
      return res.json(report);
    }
    const signoff = await Signoff.findByPk(id);
    if (!signoff) {
      return res.status(404).json({ error: 'Signoff not found' });
    }
    await signoff.update({ decision: 'approved' });
    res.json(signoff);
  } catch (error) {
    console.error('Error approving signoff:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/submit', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      const [existing] = await sequelize.query(
        `SELECT id, created_by, status, content FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const cur = existing[0];
      const ownerId = cur.created_by ? String(cur.created_by) : null;
      if (ownerId && req.user && String(req.user.id) !== ownerId) {
        return res.status(403).json({ error: 'Not authorized to submit this report' });
      }
      const curStatus = String(cur.status || 'draft');
      if (curStatus !== 'draft' && curStatus !== 'change_requested') {
        return res.status(409).json({ error: 'Invalid report state for submission' });
      }
      const user = req.user || {};
      const identity = await resolveActorIdentity({
        userId: user.id ? String(user.id) : ownerId,
        email: user.email || null
      });
      const submitterId = identity.id || ownerId || null;
      const submitterEmail = identity.email || null;
      const submitterName = identity.name;
      const submitterRoleRaw = identity.role ? String(identity.role) : (user.role ? String(user.role) : null);
      const submitterRole = roleDisplayValue(submitterRoleRaw) || submitterRoleRaw || null;
      const curContent = cur && cur.content ? (typeof cur.content === 'string' ? safeParseJson(cur.content) : cur.content) : {};
      const curSprintIds = (curContent && (curContent.sprintIds || curContent.sprint_ids)) ? (curContent.sprintIds || curContent.sprint_ids) : [];
      const sprintValidation = await validateCompletedSprintIds(curSprintIds);
      if (sprintValidation) {
        return res.status(400).json(sprintValidation);
      }
      const originalTitle = (curContent && (curContent.reportTitle || curContent.report_title)) ? (curContent.reportTitle || curContent.report_title) : 'Untitled Report';
      const sanitizedTitle = sanitizeReportTitle(originalTitle);
      let mergedContent = {
        ...curContent,
        submittedAt: new Date().toISOString(),
        submittedBy: submitterId,
        submittedByName: submitterName,
        submittedByRole: submitterRole,
        submittedByEmail: submitterEmail,
        reportTitle: sanitizedTitle,
      };
      mergedContent = appendReportVersion(
        mergedContent,
        { ...cur, status: 'submitted' },
        'submitted',
        { id: submitterId, email: submitterEmail, name: submitterName, role: submitterRole }
      );
      const [results] = await sequelize.query(
        `UPDATE sign_off_reports SET status = $2, content = $3::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
        { bind: [id, 'submitted', JSON.stringify(mergedContent)] }
      );
      if (!results || results.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds: c.sprintIds || c.sprint_ids || [],
        sprintPerformanceData: c.sprintPerformanceData || c.sprint_performance_data,
        knownLimitations: c.knownLimitations || c.known_limitations,
        nextSteps: c.nextSteps || c.next_steps,
        status: row.status || 'submitted',
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString(),
        submittedAt: c.submittedAt || c.submitted_at,
        submittedBy: c.submittedBy || c.submitted_by,
        submittedByName: c.submittedByName || c.submitted_by_name || submitterName,
        submittedByRole: c.submittedByRole || c.submitted_by_role || submitterRole
      };
      await recordReportAudit({
        action: 'submitted',
        reportId: report.id,
        reportTitle: report.reportTitle,
        actor: { id: submitterId, email: submitterEmail, name: submitterName, role: submitterRole },
        details: { status: 'submitted', actor_name: submitterName, version: mergedContent.currentVersion || null },
      });

      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_submitted', {
          id: report.id,
          deliverableId: report.deliverableId,
          reportTitle: sanitizeReportTitle(report.reportTitle),
          created_by: report.createdBy
        });
      }
      return res.json(report);
    }
    return res.status(404).json({ error: 'Endpoint not found' });
  } catch (error) {
    console.error('Error submitting sign-off report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/signatures', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      const [results] = await sequelize.query(
        `SELECT id, content, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!results || results.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const sigs = [];
      const arr = Array.isArray(c.signatures) ? c.signatures : [];
      for (const s of arr) {
        let signerName = s.signer_name || null;
        let signerRole = s.signer_role || null;
        try {
          if ((!signerName || !signerRole) && (s.signer_id || s.signer_email)) {
            const identity = await resolveActorIdentity({
              userId: s.signer_id ? String(s.signer_id) : null,
              email: s.signer_email ? String(s.signer_email) : null,
            });
            signerName = signerName || identity.name || null;
            const rawRole = signerRole || (identity.role ? String(identity.role) : null);
            signerRole = roleDisplayValue(rawRole) || rawRole || null;
          }
        } catch (_) {}
        sigs.push({
          signature_data: s.signature_data || s.digitalSignature || s.digital_signature || null,
          signer_name: signerName,
          signer_role: signerRole,
          signed_at: s.signed_at || row.updated_at,
          is_valid: s.is_valid !== undefined ? s.is_valid : true,
          signature_type: s.signature_type || 'manual'
        });
      }
      if (sigs.length === 0 && (c.digitalSignature || c.digital_signature)) {
        sigs.push({
          signature_data: c.digitalSignature || c.digital_signature,
          signer_name: null,
          signer_role: null,
          signed_at: c.approvedAt || c.approved_at || row.updated_at,
          is_valid: true,
          signature_type: 'manual'
        });
      }
      return res.json({ success: true, data: sigs });
    }
    return res.status(404).json({ error: 'Endpoint not found' });
  } catch (error) {
    console.error('Error fetching report signatures:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/pdf', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const [results] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const pdfActor = req.user
      ? await resolveActorIdentity({
          userId: req.user && req.user.id ? String(req.user.id) : null,
          email: req.user && req.user.email ? String(req.user.email) : null,
        })
      : { id: null, email: null, name: 'Authenticated User', role: null };
    await recordReportAudit({
      action: 'viewed',
      reportId: row.id,
      reportTitle: c.reportTitle || c.report_title || 'Untitled Report',
      actor: pdfActor,
      details: { access: 'pdf_export' },
    });

    const title = sanitizeReportTitle(c.reportTitle || c.report_title || 'Sign-Off Report') || 'Sign-Off Report';
    const safeName = String(title).replace(/[^a-z0-9-_]+/gi, '_').replace(/_+/g, '_');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName || 'report'}_${id}.pdf"`);

    const doc = new PDFDocument({ size: 'A4', margin: 48 });
    doc.pipe(res);

    const pageX = doc.page.margins.left;
    const pageY = doc.page.margins.top;
    const pageW = doc.page.width - doc.page.margins.left - doc.page.margins.right;

    const headerH = 110;
    const barH = 28;

    const bgPath = path.resolve(__dirname, '../../../frontend/assets/images/khono_bg.png');
    const iconPath = path.resolve(__dirname, '../../../frontend/assets/Sprints.png');

    if (fs.existsSync(bgPath)) {
      doc.image(bgPath, pageX, pageY, { width: pageW, height: headerH });
    } else {
      const grad = doc.linearGradient(pageX, pageY, pageX + pageW, pageY);
      grad.stop(0, '#1f0505');
      grad.stop(1, '#0a0a0a');
      doc.save();
      doc.fill(grad).rect(pageX, pageY, pageW, headerH).fill();
      doc.restore();
    }

    doc.fillColor('#c70000').fontSize(28).text('K H O N O L O G Y', pageX + 22, pageY + 26, {
      width: pageW - 120,
      lineBreak: false,
    });
    doc.fillColor('#ffffff').fontSize(18).text('SPRINT SIGN-OFF REPORT', pageX + 22, pageY + 62, {
      width: pageW - 120,
      lineBreak: false,
    });

    const circleR = 32;
    const circleCx = pageX + pageW - 22 - circleR;
    const circleCy = pageY + 55;
    doc.save();
    doc.fillColor('#ffffff').circle(circleCx, circleCy, circleR).fill();
    doc.restore();

    if (fs.existsSync(iconPath)) {
      doc.save();
      doc.circle(circleCx, circleCy, circleR - 1).clip();
      doc.image(iconPath, circleCx - (circleR - 10), circleCy - (circleR - 10), {
        width: (circleR - 10) * 2,
        height: (circleR - 10) * 2,
      });
      doc.restore();
    }

    doc.save();
    doc.fillColor('#c70000').rect(pageX, pageY + headerH, pageW, barH).fill();
    doc.restore();

    const createdAt = row.created_at ? new Date(row.created_at) : null;
    const dateLineValue = createdAt
      ? `${createdAt.getDate()}/${createdAt.getMonth() + 1}/${createdAt.getFullYear()}`
      : '';

    doc.font('Helvetica-Bold');
    doc.fillColor('#ffffff').fontSize(11);
    const barTextY = pageY + headerH + 9;
    const barPadX = 12;
    const leftW = Math.floor(pageW * 0.72);
    const rightW = pageW - (barPadX * 2) - leftW;
    doc.text(`Title: ${title}`, pageX + barPadX, barTextY, { width: leftW, lineBreak: false, ellipsis: true });
    doc.text(`Date: ${dateLineValue}`, pageX + barPadX + leftW, barTextY, { width: rightW, align: 'right', lineBreak: false });
    doc.font('Helvetica');

    const afterHeaderY = pageY + headerH + barH + 14;
    doc.x = pageX;
    doc.y = afterHeaderY;

    doc.fillColor('#333').fontSize(10);
    doc.fontSize(10).fillColor('#333').text(`Status: ${row.status || 'draft'}`);
    doc.text(`Deliverable ID: ${row.deliverable_id || ''}`);
    doc.text(`Created: ${createdAt ? createdAt.toISOString().slice(0, 10) : ''}`);
    doc.moveDown(0.8);

    const writeSection = (heading, body) => {
      const text = String(body || '').trim();
      if (!text) return;
      doc.fillColor('#8B0000').fontSize(12).text(heading);
      doc.moveDown(0.2);
      doc.fillColor('#111').fontSize(10).text(text, { lineGap: 2 });
      doc.moveDown(0.8);
    };

    writeSection('Report Content', c.reportContent || c.report_content || '');
    writeSection('Known Limitations', c.knownLimitations || c.known_limitations || '');
    writeSection('Next Steps', c.nextSteps || c.next_steps || '');

    const signatures = Array.isArray(c.signatures) ? c.signatures : [];
    if (signatures.length > 0) {
      doc.fillColor('#8B0000').fontSize(12).text('Signatures');
      doc.moveDown(0.4);

      for (const s of signatures) {
        const signer = String(s.signer_name || 'Unknown').trim();
        const role = String(s.signer_role || '').trim();
        const when = s.signed_at || row.updated_at || null;
        doc.fillColor('#111').fontSize(10).text(`• ${signer}${role ? ' (' + role + ')' : ''}${when ? ' — ' + when : ''}`);

        const rawSig = String(s.signature_data || '').trim();
        if (rawSig) {
          const base64 = rawSig.includes('base64,') ? rawSig.split('base64,').pop() : rawSig;
          try {
            const buf = Buffer.from(base64, 'base64');
            if (buf.length > 0) {
              const x = doc.x + 12;
              const y = doc.y + 6;
              doc.image(buf, x, y, { width: 180, height: 80, fit: [180, 80] });
              doc.moveDown(4.2);
            } else {
              doc.moveDown(0.3);
            }
          } catch (_) {
            doc.moveDown(0.3);
          }
        } else {
          doc.moveDown(0.3);
        }
      }
    }

    doc.end();
  } catch (error) {
    console.error('Error generating report PDF:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/download', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    const [results] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const title = (c.reportTitle || c.report_title || 'Sign-Off Report');
    const sanitizeReportContent = (value) => {
      const raw = String(value || '');
      if (!raw.trim()) return raw;
      const lines = raw.split('\n');
      const out = [];
      let skipping = false;
      for (const line of lines) {
        const t = String(line || '').trim().toUpperCase();
        if (!skipping && t === 'PROJECT SPRINT TOTALS') {
          skipping = true;
          continue;
        }
        if (skipping) {
          if (t === 'SPRINT SUMMARY') {
            skipping = false;
            out.push(line);
          }
          continue;
        }
        out.push(line);
      }
      return out.join('\n');
    };
    const lines = [];
    lines.push(`# ${title}`);
    lines.push('');
    lines.push(`Status: ${row.status || 'draft'}`);
    lines.push(`Deliverable ID: ${row.deliverable_id || ''}`);
    lines.push('');
    if (c.reportContent || c.report_content) {
      lines.push('## Report Content');
      lines.push(sanitizeReportContent(c.reportContent || c.report_content));
      lines.push('');
    }
    if (Array.isArray(c.sprintIds || c.sprint_ids) && (c.sprintIds || c.sprint_ids).length > 0) {
      lines.push('## Sprints');
      for (const sid of (c.sprintIds || c.sprint_ids)) {
        lines.push(`- Sprint ${sid}`);
      }
      lines.push('');
    }
    if (c.knownLimitations || c.known_limitations) {
      lines.push('## Known Limitations');
      lines.push(String(c.knownLimitations || c.known_limitations));
      lines.push('');
    }
    if (c.nextSteps || c.next_steps) {
      lines.push('## Next Steps');
      lines.push(String(c.nextSteps || c.next_steps));
      lines.push('');
    }
    if (Array.isArray(c.signatures)) {
      lines.push('## Signatures');
      for (const s of c.signatures) {
        const name = s.signer_name || 'Unknown';
        const role = s.signer_role || '';
        const when = s.signed_at || row.updated_at;
        lines.push(`- ${name}${role ? ' ('+role+')' : ''} at ${when}`);
      }
      lines.push('');
    }
    const content = lines.join('\n');
    const safeName = String(title).replace(/[^a-z0-9-_]+/gi, '_').replace(/_+/g, '_');
    res.setHeader('Content-Type', 'text/markdown');
    res.setHeader('Content-Disposition', `attachment; filename="${safeName || 'report'}_${id}.md"`);
    return res.status(200).send(content);
  } catch (error) {
    console.error('Error generating report download:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/signature', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }
      const { signatureData, signatureType } = req.body || {};
      const [existing] = await sequelize.query(
        `SELECT id, content, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = existing[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const signatures = Array.isArray(c.signatures) ? c.signatures : [];
      const identity = await resolveActorIdentity({
        userId: req.user && req.user.id ? String(req.user.id) : null,
        email: req.user && req.user.email ? String(req.user.email) : null,
      });
      const signerName = identity.name || null;
      const signerRoleRaw = identity.role ? String(identity.role) : (req.user && req.user.role ? String(req.user.role) : null);
      const signerRole = roleDisplayValue(signerRoleRaw) || signerRoleRaw || null;
      const signerId = identity.id || (req.user && req.user.id ? String(req.user.id) : null);
      const signerEmail = identity.email || (req.user && req.user.email ? String(req.user.email) : null);
      const newSig = {
        signature_data: signatureData || null,
        signer_name: signerName,
        signer_role: signerRole,
        signer_id: signerId,
        signer_email: signerEmail,
        signed_at: new Date().toISOString(),
        is_valid: true,
        signature_type: signatureType || 'manual'
      };
      const newContent = { ...c, signatures: [...signatures, newSig] };
      const [updated] = await sequelize.query(
        `UPDATE sign_off_reports SET content = $2::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id`,
        { bind: [id, JSON.stringify(newContent)] }
      );
      if (!updated || updated.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      return res.json({ success: true });
    }
    return res.status(404).json({ error: 'Endpoint not found' });
  } catch (error) {
    console.error('Error storing report signature:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/export', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      await ensureReportsTable();
      const { exportFormat, exportType, fileSize, fileHash, metadata } = req.body || {};
      const [existing] = await sequelize.query(
        `SELECT id, content FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const row = existing[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const exportsArr = Array.isArray(c.exports) ? c.exports : [];
      const exportEntry = {
        format: exportFormat || 'pdf',
        type: exportType || 'download',
        fileSize: fileSize || null,
        fileHash: fileHash || null,
        metadata: metadata || {},
        exportedAt: new Date().toISOString(),
        exportedBy: req.user ? String(req.user.id) : null
      };
      const newContent = { ...c, exports: [...exportsArr, exportEntry], lastExport: exportEntry };
      await sequelize.query(
        `UPDATE sign_off_reports SET content = $2::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)}`,
        { bind: [id, JSON.stringify(newContent)] }
      );
      return res.json({ success: true });
    }
    return res.status(404).json({ error: 'Endpoint not found' });
  } catch (error) {
    console.error('Error tracking report export:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/request-changes', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (base.endsWith('/sign-off-reports')) {
      const { changeRequestDetails, clientId, clientName, clientRole } = req.body || {};
      
      // Server-side validation: comment is mandatory
      if (!changeRequestDetails || typeof changeRequestDetails !== 'string' || changeRequestDetails.trim().length === 0) {
        return res.status(400).json({ 
          error: 'Change request details are required',
          message: 'Please provide details for the requested changes'
        });
      }
      
      // Check for review token (token-based access)
      const reviewToken = extractReviewToken(req);
      let reviewedBy = null;
      let clientEmail = null;
      
      if (reviewToken) {
        // Validate token matches report ID
        if (reviewToken.reportId !== id.toString()) {
          return res.status(403).json({ error: 'Token is not valid for this report' });
        }
        reviewedBy = clientId || reviewToken.clientEmail; // Use clientId from body or email from token
        clientEmail = reviewToken.clientEmail;
      } else if (req.user) {
        // Authenticated user
        reviewedBy = req.user.id;
      } else {
        // Try to use clientId from body if provided
        reviewedBy = clientId ? String(clientId) : null;
      }

      const user = req.user || {};
      const identity = await resolveActorIdentity({
        userId: user.id ? String(user.id) : (reviewedBy ? String(reviewedBy) : null),
        email: user.email || clientEmail || null
      });
      const actorId = identity.id || null;
      const actorEmail = identity.email || user.email || clientEmail || null;
      const actorName = (reviewToken && clientName && String(clientName).trim())
        ? String(clientName).trim()
        : identity.name;
      const actorRoleRaw =
        (reviewToken && clientRole && String(clientRole).trim())
          ? String(clientRole).trim()
          : (identity.role ? String(identity.role) : (user.role ? String(user.role) : (reviewToken ? 'clientReviewer' : null)));
      const actorRole = roleDisplayValue(actorRoleRaw) || actorRoleRaw || null;
      
      await ensureReportsTable();
      const [existing] = await sequelize.query(
        `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
        { bind: [id] }
      );
      if (!existing || existing.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      const cur = existing[0];

      // Seal check: Prevent changes if approved
      if (cur.status === 'approved') {
        return res.status(403).json({ error: 'Report is already approved and sealed.' });
      }

      const curC = typeof cur.content === 'string' ? safeParseJson(cur.content) : (cur.content || {});
      
      // History management
      const history = Array.isArray(curC.changeRequestHistory) ? curC.changeRequestHistory : [];
      if (curC.changeRequestDetails) {
        history.unshift({
          details: curC.changeRequestDetails,
          requestedAt: curC.reviewedAt || cur.updated_at,
          requestedBy: curC.reviewedBy || null
        });
      }

      const merged = {
        ...curC,
        changeRequestHistory: history,
        changeRequestDetails: changeRequestDetails ?? null,
        actionItems: String(changeRequestDetails || '')
          .split(/\r?\n+/g)
          .map((line) => String(line || '').replace(/^[-*]\s*/, '').trim())
          .filter(Boolean),
        reviewedAt: new Date().toISOString(),
        reviewedBy: reviewedBy ? String(reviewedBy) : (curC.reviewedBy || null),
        reviewedByName: actorName,
        reviewedByRole: actorRole,
        reviewedByEmail: actorEmail,
        clientEmail: clientEmail || actorEmail || curC.clientEmail || null,
        clientName: clientName || actorName || curC.clientName || null,
        clientRole: clientRole || actorRole || curC.clientRole || null,
        status: 'change_requested',
      };
      const versionedContent = appendReportVersion(
        merged,
        { ...cur, status: 'change_requested' },
        'change_requested',
        { id: actorId, email: actorEmail, name: actorName, role: actorRole }
      );
      const [results] = await sequelize.query(
        `UPDATE sign_off_reports SET status = $2, content = $3::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
        { bind: [id, 'change_requested', JSON.stringify(versionedContent)] }
      );
      const row = results[0];
      const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
      const report = {
        id: row.id,
        deliverableId: (row.deliverable_id || '').toString(),
        reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
        reportContent: (c.reportContent || c.report_content || ''),
        sprintIds: c.sprintIds || c.sprint_ids || [],
        status: row.status || 'change_requested',
        createdAt: row.created_at,
        createdBy: (row.created_by || '').toString(),
        changeRequestDetails: c.changeRequestDetails || c.change_request_details,
        reviewedAt: c.reviewedAt || c.reviewed_at,
        reviewedBy: c.reviewedBy || c.reviewed_by,
        reviewedByName: c.reviewedByName || c.reviewed_by_name || actorName,
        reviewedByRole: c.reviewedByRole || c.reviewed_by_role || actorRole
      };
      try {
        const did = parseInt(row.deliverable_id);
        if (Number.isFinite(did)) {
          const { Deliverable, Notification, User } = require('../models');
          const { Op } = require('sequelize');
          const d = await Deliverable.findByPk(did);
          if (d) {
            await d.update({ status: 'change_requested' });
          }
          if (Notification) {
            // Notify all team members assigned to the deliverable
            const recipientIds = new Set();
            
            // Add report creator
            if (row.created_by) {
              recipientIds.add(row.created_by.toString());
            }
            
            // Add deliverable assignee
            if (d && d.assigned_to) {
              recipientIds.add(d.assigned_to.toString());
            }
            
            // Add deliverable owner
            if (d && d.owner_id) {
              recipientIds.add(d.owner_id.toString());
            }
            
            // Add project team members (if deliverable has project_id)
            if (d && d.project_id) {
              try {
                const projectTeam = await User.findAll({
                  where: {
                    [Op.or]: [
                      { project_id: d.project_id },
                      { role: { [Op.in]: ['deliveryLead', 'scrumMaster', 'developer', 'qaEngineer', 'projectManager'] } }
                    ],
                    is_active: true
                  }
                });
                projectTeam.forEach(user => {
                  if (user.id) recipientIds.add(user.id.toString());
                });
              } catch (teamErr) {
                console.error('Error fetching project team:', teamErr);
              }
            }
            
            // Create notifications for all recipients
            const notifications = Array.from(recipientIds).map(recipientId => ({
              recipient_id: recipientId,
              sender_id: (req.user && req.user.id) || null,
              type: 'change_request',
              message: `Changes requested: "${report.reportTitle}"`,
              payload: { 
                report_id: report.id, 
                deliverable_id: did,
                change_request_details: changeRequestDetails
              },
              is_read: false,
              created_at: new Date()
            }));
            
            if (notifications.length > 0) {
              await Notification.bulkCreate(notifications);
            }
          }
          try {
            const { ApprovalRequest } = require('../models');
            await ApprovalRequest.update(
              {
                status: 'rejected',
                approved_by: (req.user && req.user.id) || null,
                rejected_at: new Date(),
                comments: changeRequestDetails ?? null
              },
              { where: { deliverable_id: did, status: 'pending' } }
            );
          } catch (_) {}
        }
      } catch (_) {}
      if (global.realtimeEvents) {
        global.realtimeEvents.emit('report_change_requested', {
          id: report.id,
          deliverableId: report.deliverableId,
          reportTitle: report.reportTitle,
          created_by: report.createdBy,
          changeRequestDetails: report.changeRequestDetails
        });
      }

      await recordReportAudit({
        action: 'request_changes',
        reportId: report.id,
        reportTitle: report.reportTitle,
        actor: { id: actorId, email: actorEmail, name: actorName, role: actorRole },
        details: {
          change_request_details: changeRequestDetails,
          actor_name: actorName,
          version: versionedContent.currentVersion || null,
        },
      });

      return res.json(report);
    }
    return res.status(404).json({ error: 'Endpoint not found' });
  } catch (error) {
    console.error('Error requesting changes:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    const { comment, digitalSignature, clientId } = req.body || {};
    const reviewToken = extractReviewToken(req);
    let actorSeed = null;
    let actorEmailSeed = null;
    if (reviewToken) {
      if (reviewToken.reportId !== id.toString()) {
        return res.status(403).json({ error: 'Token is not valid for this report' });
      }
      actorSeed = clientId || reviewToken.clientEmail;
      actorEmailSeed = reviewToken.clientEmail;
    } else if (req.user) {
      actorSeed = req.user.id;
      actorEmailSeed = req.user.email || null;
    }
    const actorIdentity = await resolveActorIdentity({
      userId: actorSeed ? String(actorSeed) : null,
      email: actorEmailSeed,
    });
    const actor = {
      id: actorIdentity.id || actorSeed || null,
      email: actorIdentity.email || actorEmailSeed || null,
      name: actorIdentity.name || 'Client Reviewer',
      role: actorIdentity.role || 'clientReviewer',
    };
    const [existing] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const cur = existing[0];
    if (String(cur.status || '') === 'approved') {
      return res.status(403).json({ error: 'Report is already approved and sealed.' });
    }
    const curContent = typeof cur.content === 'string' ? safeParseJson(cur.content) : (cur.content || {});
    let merged = {
      ...curContent,
      reviewedAt: new Date().toISOString(),
      reviewedBy: actor.id ? String(actor.id) : null,
      reviewedByName: actor.name,
      reviewedByRole: roleDisplayValue(actor.role) || actor.role || null,
      reviewedByEmail: actor.email || null,
      digitalSignature: digitalSignature ?? null,
      rejectionComment: comment || 'Rejected by client reviewer',
      status: 'rejected',
    };
    merged = appendReportVersion(merged, { ...cur, status: 'rejected' }, 'rejected', actor);
    const [results] = await sequelize.query(
      `UPDATE sign_off_reports SET status = $2, content = $3::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
      { bind: [id, 'rejected', JSON.stringify(merged)] }
    );
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const report = {
      id: row.id,
      deliverableId: (row.deliverable_id || '').toString(),
      reportTitle: c.reportTitle || c.report_title || 'Untitled Report',
      status: row.status || 'rejected',
      rejectionComment: c.rejectionComment || null,
    };
    try {
      const did = parseInt(row.deliverable_id, 10);
      if (Number.isFinite(did)) {
        const { Deliverable, Notification, User } = require('../models');
        const deliverable = await Deliverable.findByPk(did);
        if (deliverable) {
          await deliverable.update({ status: 'change_requested' });
        }
        const recipients = new Set();
        if (row.created_by) recipients.add(String(row.created_by));
        if (deliverable && deliverable.owner_id) recipients.add(String(deliverable.owner_id));
        if (deliverable && deliverable.assigned_to) recipients.add(String(deliverable.assigned_to));
        if (deliverable && deliverable.project_id) {
          const team = await User.findAll({
            where: {
              is_active: true,
              role: { [Op.in]: ['deliveryLead', 'scrumMaster', 'developer', 'qaEngineer', 'projectManager'] },
            },
          });
          for (const user of team) {
            if (user.id) recipients.add(String(user.id));
          }
        }
        if (Notification && recipients.size > 0) {
          await Notification.bulkCreate(
            [...recipients].map((recipientId) => ({
              recipient_id: recipientId,
              sender_id: actor.id || null,
              type: 'change_request',
              message: `Report rejected: "${report.reportTitle}"`,
              payload: { report_id: report.id, deliverable_id: did, comment: report.rejectionComment },
              is_read: false,
              created_at: new Date(),
            }))
          );
        }
      }
    } catch (_) {}
    await recordReportAudit({
      action: 'rejected',
      reportId: report.id,
      reportTitle: report.reportTitle,
      actor,
      details: { comment: report.rejectionComment, version: merged.currentVersion || null },
    });
    if (global.realtimeEvents) {
      global.realtimeEvents.emit('report_rejected', report);
    }
    return res.json(report);
  } catch (error) {
    console.error('Error rejecting report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/seal', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
    const [existing] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const cur = existing[0];
    if (String(cur.status || '') !== 'approved') {
      return res.status(409).json({ error: 'Only approved reports can be sealed' });
    }
    const curContent = typeof cur.content === 'string' ? safeParseJson(cur.content) : (cur.content || {});
    let merged = {
      ...curContent,
      sealedAt: curContent.sealedAt || new Date().toISOString(),
      sealedBy: curContent.sealedBy || actor.id || null,
      sealedByName: curContent.sealedByName || actor.name || null,
      sealedByRole: curContent.sealedByRole || (roleDisplayValue(actor.role) || actor.role || null),
    };
    merged = appendReportVersion(merged, cur, 'sealed', actor);
    const [results] = await sequelize.query(
      `UPDATE sign_off_reports SET content = $2::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
      { bind: [id, JSON.stringify(merged)] }
    );
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    await recordReportAudit({
      action: 'sealed',
      reportId: row.id,
      reportTitle: c.reportTitle || c.report_title || 'Untitled Report',
      actor,
      details: { version: merged.currentVersion || null },
    });
    return res.json({ success: true, reportId: String(row.id), sealedAt: c.sealedAt, sealedBy: c.sealedBy });
  } catch (error) {
    console.error('Error sealing report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/archive', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
    const [existing] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const cur = existing[0];
    if (!['approved', 'rejected'].includes(String(cur.status || ''))) {
      return res.status(409).json({ error: 'Only completed review reports can be archived' });
    }
    const curContent = typeof cur.content === 'string' ? safeParseJson(cur.content) : (cur.content || {});
    let merged = {
      ...curContent,
      isArchived: true,
      archivedAt: new Date().toISOString(),
      archivedBy: actor.id || null,
      archivedByName: actor.name || null,
      archivedByRole: roleDisplayValue(actor.role) || actor.role || null,
    };
    merged = appendReportVersion(merged, cur, 'archived', actor);
    const [results] = await sequelize.query(
      `UPDATE sign_off_reports SET content = $2::jsonb, updated_at = NOW() WHERE ${reportsIdWhere(1)} RETURNING id, deliverable_id, created_by, status, content, created_at, updated_at`,
      { bind: [id, JSON.stringify(merged)] }
    );
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    await recordReportAudit({
      action: 'archived',
      reportId: row.id,
      reportTitle: c.reportTitle || c.report_title || 'Untitled Report',
      actor,
      details: { archived_at: c.archivedAt, version: merged.currentVersion || null },
    });
    return res.json({ success: true, reportId: String(row.id), archivedAt: c.archivedAt });
  } catch (error) {
    console.error('Error archiving report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/remind', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
    const [existing] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const row = existing[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const { Notification, User } = require('../models');
    const recipients = await User.findAll({
      where: {
        role: { [Op.in]: ['clientReviewer', 'ClientReviewer', 'clientreviewer'] },
        is_active: true,
      },
    });
    if (Notification && recipients.length > 0) {
      await Notification.bulkCreate(
        recipients.map((recipient) => ({
          recipient_id: recipient.id,
          sender_id: actor.id || null,
          type: 'approval',
          message: `Reminder: Review "${c.reportTitle || c.report_title || 'Sign-Off Report'}"`,
          payload: { report_id: id, deliverable_id: row.deliverable_id, reason: 'manual_reminder' },
          is_read: false,
          created_at: new Date(),
        }))
      );
    }
    await recordReportAudit({
      action: 'reminder_sent',
      reportId: id,
      reportTitle: c.reportTitle || c.report_title || 'Sign-Off Report',
      actor,
      details: { recipient_count: recipients.length },
    });
    return res.json({ success: true, recipientCount: recipients.length });
  } catch (error) {
    console.error('Error sending reminder:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/:id/escalate', async (req, res) => {
  try {
    const { id } = req.params;
    const base = req.baseUrl || '';
    if (!base.endsWith('/sign-off-reports')) {
      return res.status(404).json({ error: 'Endpoint not found' });
    }
    await ensureReportsTable();
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    const actor = await resolveActorIdentity({ userId: String(req.user.id), email: req.user.email });
    const [existing] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [id] }
    );
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    const row = existing[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    const { Notification, User } = require('../models');
    const admins = await User.findAll({
      where: {
        role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'deliveryLead', 'DeliveryLead', 'admin'] },
        is_active: true,
      },
    });
    if (Notification && admins.length > 0) {
      await Notification.bulkCreate(
        admins.map((admin) => ({
          recipient_id: admin.id,
          sender_id: actor.id || null,
          type: 'escalation',
          message: `ESCALATION: "${c.reportTitle || c.report_title || 'Sign-Off Report'}" needs attention`,
          payload: { report_id: id, deliverable_id: row.deliverable_id, reason: 'manual_escalation' },
          is_read: false,
          created_at: new Date(),
        }))
      );
    }
    await recordReportAudit({
      action: 'escalated',
      reportId: id,
      reportTitle: c.reportTitle || c.report_title || 'Sign-Off Report',
      actor,
      details: { recipient_count: admins.length },
    });
    return res.json({ success: true, recipientCount: admins.length });
  } catch (error) {
    console.error('Error escalating report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/signoff/:entity_type/:entity_id/report
 * @desc Generate a signoff report for a specific entity
 * @access Public
 */
router.get('/:entity_type/:entity_id/report', async (req, res) => {
  try {
    const { entity_type, entity_id } = req.params;
    const { format = 'json' } = req.query;
    
    // Validate entity type
    if (!['sprint', 'deliverable'].includes(entity_type)) {
      return res.status(400).json({ error: 'Invalid entity type. Must be sprint or deliverable' });
    }
    
    // Validate entity ID
    const entityId = parseInt(entity_id);
    if (isNaN(entityId)) {
      return res.status(400).json({ error: 'Invalid entity ID. Must be a number' });
    }
    
    // Get all signoffs for the entity
    const signoffs = await Signoff.findAll({
      where: { 
        entity_type: entity_type,
        entity_id: entityId 
      },
      order: [['submitted_at', 'DESC']]
    });
    
    if (signoffs.length === 0) {
      const baseInfo = entity_type === 'deliverable'
        ? await Deliverable.findByPk(entityId)
        : await Sprint.findByPk(entityId);
      const reportData = {
        metadata: {
          entity_type,
          entity_id: entityId,
          format,
          generated_at: new Date().toISOString(),
          name: baseInfo?.title || baseInfo?.name || undefined,
          status: baseInfo?.status || undefined
        },
        statistics: {
          total_signoffs: 0,
          approved_count: 0,
          rejected_count: 0,
          pending_count: 0,
          change_requested_count: 0,
          completion_rate: 0
        },
        signoffs: []
      };
      switch (format) {
        case 'json':
          return res.json(reportData);
        case 'text':
          return res.type('text/plain').send(JSON.stringify(reportData, null, 2));
        case 'html':
        case 'pdf':
          return res.type('text/html').send(`<h1>Sign-off Report for ${entity_type} ${entityId}</h1><pre>${JSON.stringify(reportData, null, 2)}</pre>`);
        default:
          return res.status(400).json({ error: 'Invalid format. Must be json, text, html, or pdf' });
      }
    }
    
    // Calculate statistics
    const totalSignoffs = signoffs.length;
    const approvedCount = signoffs.filter(s => s.decision === 'approved').length;
    const rejectedCount = signoffs.filter(s => s.decision === 'rejected').length;
    const pendingCount = signoffs.filter(s => s.decision === 'pending').length;
    const changeRequestedCount = signoffs.filter(s => s.decision === 'change_requested').length;
    const completionRate = totalSignoffs > 0 
      ? Math.round(((approvedCount + rejectedCount + changeRequestedCount) / totalSignoffs) * 100) 
      : 0;
    
    // Prepare report data
    const reportData = {
      metadata: {
        entity_type: entity_type,
        entity_id: entityId,
        format: format,
        generated_at: new Date().toISOString()
      },
      statistics: {
        total_signoffs: totalSignoffs,
        approved_count: approvedCount,
        rejected_count: rejectedCount,
        pending_count: pendingCount,
        change_requested_count: changeRequestedCount,
        completion_rate: completionRate
      },
      signoffs: signoffs.map(s => ({
        id: s.id,
        signer_name: s.signer_name,
        signer_email: s.signer_email,
        signer_role: s.signer_role,
        signer_company: s.signer_company,
        decision: s.decision,
        comments: s.comments,
        change_request_details: s.change_request_details,
        submitted_at: s.submitted_at,
        reviewed_at: s.reviewed_at,
        responded_at: s.responded_at
      }))
    };
    
    // Generate content based on format
    switch (format) {
      case 'json':
        res.json(reportData);
        break;
      case 'text':
        res.type('text/plain').send(JSON.stringify(reportData, null, 2));
        break;
      case 'html':
      case 'pdf':
        res.type('text/html').send(`<h1>Sign-off Report for ${entity_type} ${entityId}</h1><pre>${JSON.stringify(reportData, null, 2)}</pre>`);
        break;
      default:
        res.status(400).json({ error: 'Invalid format. Must be json, text, html, or pdf' });
    }
    
  } catch (error) {
    console.error('Error generating signoff report:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/client-review-links
 * @desc Create a secure review link token for a sign-off report
 * @access Private (requires authentication)
 */
router.post('/client-review-links', async (req, res) => {
  try {
    const { reportId, clientEmail, expiresInSeconds } = req.body;
    
    if (!reportId) {
      return res.status(400).json({ error: 'reportId is required' });
    }
    
    if (!clientEmail || typeof clientEmail !== 'string' || !clientEmail.includes('@')) {
      return res.status(400).json({ error: 'Valid clientEmail is required' });
    }
    
    // Default to 7 days if not specified
    const expiresIn = expiresInSeconds || (7 * 24 * 60 * 60);
    const expiresAt = new Date(Date.now() + expiresIn * 1000);
    
    await ensureReportsTable();
    
    // Verify report exists
    const [reportCheck] = await sequelize.query(
      `SELECT id, status FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [reportId] }
    );
    
    if (!reportCheck || reportCheck.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    // Generate JWT token with report info
    const { createAccessToken } = require('../utils/authUtils');
    const token = createAccessToken({
      reportId: reportId.toString(),
      clientEmail,
      type: 'client_review',
      singleUse: false // Can be made configurable
    }, expiresIn);
    
    // Store token metadata in audit log for tracking
    try {
      const { AuditLog } = require('../models');
      const user = req.user || {};
      const actorEmail = user.email || null;
      const actorName =
        user.name ||
        (user.first_name && user.last_name ? `${user.first_name} ${user.last_name}` : null) ||
        user.username ||
        actorEmail ||
        'Unknown User';
      await AuditLog.create({
        action: 'review_link_created',
        user_id: user.id || null,
        user_email: actorEmail,
        user_role: user.role || null,
        entity_type: 'signoff',
        entity_id: reportId.toString(),
        details: { 
          clientEmail,
          expiresAt: expiresAt.toISOString(),
          tokenType: 'client_review',
          actor_name: actorName
        },
        created_at: new Date()
      });
    } catch (auditErr) {
      console.error('Error creating audit log for review link:', auditErr);
    }
    
    res.status(201).json({
      linkToken: token,
      expiresAt: expiresAt.toISOString(),
      reportId: reportId.toString()
    });
  } catch (error) {
    console.error('Error creating client review link:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/client-review/:token
 * @desc Get sign-off report and performance metrics via secure token
 * @access Public (token-based, no auth required)
 */
router.get('/client-review/:token', async (req, res) => {
  try {
    const { token } = req.params;
    
    // Verify and decode token
    const { verifyToken } = require('../utils/authUtils');
    const payload = verifyToken(token);
    
    if (!payload || payload.type !== 'client_review') {
      return res.status(401).json({ 
        error: 'Invalid or expired token',
        message: 'This review link is invalid or has expired'
      });
    }
    
    const reportId = payload.reportId;
    if (!reportId) {
      return res.status(400).json({ error: 'Invalid token: missing reportId' });
    }
    
    await ensureReportsTable();
    
    // Fetch report
    const [results] = await sequelize.query(
      `SELECT id, deliverable_id, created_by, status, content, created_at, updated_at FROM sign_off_reports WHERE ${reportsIdWhere(1)}`,
      { bind: [reportId] }
    );
    
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }
    
    const row = results[0];
    const c = typeof row.content === 'string' ? safeParseJson(row.content) : (row.content || {});
    
    // Fetch deliverable info
    let deliverable = null;
    if (row.deliverable_id) {
      try {
        const { Deliverable } = require('../models');
        const d = await Deliverable.findByPk(parseInt(row.deliverable_id));
        if (d) {
          deliverable = {
            id: d.id,
            title: d.title,
            description: d.description,
            status: d.status,
            dueDate: d.due_date
          };
        }
      } catch (_) {}
    }
    
    // Generate performance metrics from sprint data if sprintIds exist
    let performanceMetrics = null;
    const sprintIds = c.sprintIds || c.sprint_ids || [];
    if (sprintIds.length > 0) {
      try {
        performanceMetrics = await generatePerformanceMetrics(sprintIds);
      } catch (err) {
        console.error('Error generating performance metrics:', err);
        // Continue without metrics if generation fails
      }
    }
    
    // Build response (read-only view)
    const report = {
      id: row.id,
      deliverableId: (row.deliverable_id || '').toString(),
      reportTitle: (c.reportTitle || c.report_title || 'Untitled Report'),
      reportContent: (c.reportContent || c.report_content || ''),
      sprintIds: sprintIds,
      sprintPerformanceData: performanceMetrics ? JSON.stringify(performanceMetrics) : (c.sprintPerformanceData || c.sprint_performance_data || null),
      knownLimitations: c.knownLimitations || c.known_limitations || null,
      nextSteps: c.nextSteps || c.next_steps || null,
      status: row.status || 'draft',
      createdAt: row.created_at,
      createdBy: (row.created_by || '').toString(),
      approvedAt: c.approvedAt || c.approved_at || null,
      approvedBy: c.approvedBy || c.approved_by || null,
      changeRequestDetails: c.changeRequestDetails || c.change_request_details || null,
      digitalSignature: c.digitalSignature || c.digital_signature || null,
      versionHistory: Array.isArray(c.versionHistory) ? c.versionHistory : [],
      currentVersion: Number(c.currentVersion || 0),
      isArchived: Boolean(c.isArchived),
      archivedAt: c.archivedAt || null,
    };
    
    res.json({
      report,
      deliverable,
      performanceMetrics: performanceMetrics || (c.sprintPerformanceData ? safeParseJson(c.sprintPerformanceData) : null)
    });
  } catch (error) {
    console.error('Error fetching client review:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Generate performance metrics from sprint data
 * @param {Array<string|number>} sprintIds - Array of sprint IDs
 * @returns {Promise<Array>} Array of sprint performance data
 */
async function generatePerformanceMetrics(sprintIds) {
  try {
    const { Sprint, sequelize } = require('../models');
    const metrics = [];
    
    // Handle case where sprintIds is null or not an array
    const safeSprintIds = Array.isArray(sprintIds) ? sprintIds : [];
    if (safeSprintIds.length === 0) return metrics;
    
    for (const sprintId of safeSprintIds) {
      try {
        // Fetch sprint
        const sprint = await Sprint.findByPk(parseInt(sprintId));
        if (!sprint) continue;
        
        // Fetch sprint metrics if available
        const [metricsRows] = await sequelize.query(
          `SELECT 
            committed_points, completed_points, carried_over_points,
            test_pass_rate, defects_opened, defects_closed,
            critical_defects, high_defects, medium_defects, low_defects,
            points_added_during_sprint, points_removed_during_sprint,
            recorded_at
          FROM sprint_metrics 
          WHERE sprint_id = $1 
          ORDER BY recorded_at DESC 
          LIMIT 1`,
          { bind: [sprintId] }
        );
        
        const metric = metricsRows && metricsRows.length > 0 ? metricsRows[0] : null;
        
        // Calculate velocity (completed points)
        const velocity = metric ? (metric.completed_points || 0) : 0;
        const committed = metric ? (metric.committed_points || 0) : 0;
        const completed = metric ? (metric.completed_points || 0) : 0;
        
        // Defect data
        const defectsOpened = metric ? (metric.defects_opened || 0) : 0;
        const defectsClosed = metric ? (metric.defects_closed || 0) : 0;
        const defectSeverityMix = {
          critical: metric ? (metric.critical_defects || 0) : 0,
          high: metric ? (metric.high_defects || 0) : 0,
          medium: metric ? (metric.medium_defects || 0) : 0,
          low: metric ? (metric.low_defects || 0) : 0
        };
        
        // Test pass rate
        const testPassRate = metric ? (metric.test_pass_rate || 0) : 0;
        
        // Scope changes
        const pointsAdded = metric ? (metric.points_added_during_sprint || 0) : 0;
        const pointsRemoved = metric ? (metric.points_removed_during_sprint || 0) : 0;
        
        metrics.push({
          sprintId: sprintId.toString(),
          name: sprint.name || `Sprint ${sprintId}`,
          startDate: sprint.start_date ? sprint.start_date.toISOString() : null,
          endDate: sprint.end_date ? sprint.end_date.toISOString() : null,
          velocity: velocity,
          completed_points: completed,
          planned_points: committed,
          committed_points: committed,
          test_pass_rate: testPassRate,
          defects_opened: defectsOpened,
          defects_closed: defectsClosed,
          defect_count: defectsOpened,
          defect_severity_mix: defectSeverityMix,
          points_added: pointsAdded,
          points_removed: pointsRemoved,
          scope_change_indicator: pointsAdded > 0 || pointsRemoved > 0 ? 
            `${pointsAdded > 0 ? '+' + pointsAdded : ''}${pointsRemoved > 0 ? (pointsAdded > 0 ? ', ' : '') + '-' + pointsRemoved : ''}` : 
            'No change'
        });
      } catch (err) {
        console.error(`Error processing sprint ${sprintId}:`, err);
        // Continue with other sprints
      }
    }
    
    return metrics;
  } catch (error) {
    console.error('Error generating performance metrics:', error);
    return [];
  }
}

module.exports = router;
