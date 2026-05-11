const express = require('express');
const router = express.Router();
const { Sprint, Project, Deliverable, User, sequelize } = require('../models');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { carryOverOverdueDeliverablesForProject } = require('../services/sprintCarryOverService');
const sprintController = require('../controllers/sprintController');

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

function normalizeSprintData(body) {
  const d = {};
  if (body.name != null) d.name = body.name;
  if (body.description != null) d.description = body.description;
  const sd = body.start_date ?? body.startDate;
  if (sd != null) d.start_date = sd;
  const ed = body.end_date ?? body.endDate;
  if (ed != null) d.end_date = ed;
  const pid = body.project_id ?? body.projectId;
  if (pid != null) d.project_id = pid;
  const planned = body.planned_points ?? body.plannedPoints;
  if (planned != null) d.planned_points = planned;
  const committed = body.committed_points ?? body.committedPoints;
  if (committed != null) d.committed_points = committed;
  const completed = body.completed_points ?? body.completedPoints;
  if (completed != null) d.completed_points = completed;
  const carried = body.carried_over_points ?? body.carriedOverPoints;
  if (carried != null) d.carried_over_points = carried;
  const added = body.added_during_sprint ?? body.addedDuringSprint;
  if (added != null) d.added_during_sprint = added;
  const removed = body.removed_during_sprint ?? body.removedDuringSprint;
  if (removed != null) d.removed_during_sprint = removed;
  const tpr = body.test_pass_rate ?? body.testPassRate;
  if (tpr != null) d.test_pass_rate = tpr;
  const cov = body.code_coverage ?? body.codeCoverage;
  if (cov != null) d.code_coverage = cov;
  const esc = body.escaped_defects ?? body.escapedDefects;
  if (esc != null) d.escaped_defects = esc;
  const opened = body.defects_opened ?? body.defectsOpened;
  if (opened != null) d.defects_opened = opened;
  const closed = body.defects_closed ?? body.defectsClosed;
  if (closed != null) d.defects_closed = closed;
  const mix = body.defect_severity_mix ?? body.defectSeverityMix;
  if (mix != null) d.defect_severity_mix = mix;
  const cr = body.code_review_completion ?? body.codeReviewCompletion;
  if (cr != null) d.code_review_completion = cr;
  const doc = body.documentation_status ?? body.documentationStatus;
  if (doc != null) d.documentation_status = doc;
  const uatNotes = body.uat_notes ?? body.uatNotes;
  if (uatNotes != null) d.uat_notes = uatNotes;
  const uatRate = body.uat_pass_rate ?? body.uatPassRate;
  if (uatRate != null) d.uat_pass_rate = uatRate;
  const risksIdentified = body.risks_identified ?? body.risksIdentified;
  if (risksIdentified != null) d.risks_identified = risksIdentified;
  const risks = body.risks;
  if (risks != null) d.risks = risks;
  const risksMitigated = body.risks_mitigated ?? body.risksMitigated;
  if (risksMitigated != null) d.risks_mitigated = risksMitigated;
  const blockers = body.blockers;
  if (blockers != null) d.blockers = blockers;
  const decisions = body.decisions;
  if (decisions != null) d.decisions = decisions;
  const status = body.status ?? body.state;
  if (status != null) d.status = status;
  if (body.progress !== undefined) d.progress = body.progress;
  if (body.goal != null) d.goal = body.goal;
  if (body.board_id != null || body.boardId != null) d.board_id = body.board_id ?? body.boardId;
  const createdBy = body.created_by ?? body.createdBy;
  if (createdBy != null) d.created_by = createdBy;
  return d;
}

/**
 * @route GET /api/sprints
 * @desc Get all sprints with pagination
 * @access Public
 */
router.get('/', async (req, res) => {
  try {
    const { skip = 0, limit = 100 } = req.query;
    const projectId = req.query.project_id || req.query.projectId;
    const projectKey = req.query.project_key || req.query.projectKey;

    const where = {};
    if (projectId) where.project_id = projectId;

    const include = [{ model: Project, as: 'project', attributes: ['id', 'name', 'key'] }];
    if (!projectId && projectKey) include[0].where = { key: projectKey };

    if (projectId) {
      try {
        await carryOverOverdueDeliverablesForProject(projectId);
      } catch (e) {
        console.error('Error carrying over overdue deliverables:', e);
      }
    }

    const sprints = await Sprint.findAll({
      offset: parseInt(skip),
      limit: parseInt(limit),
      order: [['created_at', 'DESC']],
      where,
      include
    });
    
    res.json({
      success: true,
      data: sprints
    });
  } catch (error) {
    console.error('Error fetching sprints:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error',
      details: error.message,
      stack: error.stack
    });
  }
});

/**
 * @route GET /api/sprints/:id/report
 * @desc Get a sprint-based report (deliverables nested under sprint)
 * @access Public
 */
router.get('/:id/report', async (req, res) => {
  return sprintController.getSprintReport(req, res);
});

router.get('/:id/ai-report', async (req, res) => {
  return sprintController.getAiSprintReport(req, res);
});

router.post('/:id/ai-chat', async (req, res) => {
  return sprintController.postAiSprintChat(req, res);
});

function normalizeMetricsInt(v) {
  if (v == null) return null;
  const n = parseInt(String(v), 10);
  if (!Number.isFinite(n)) return null;
  return n;
}

function normalizeMetricsFloat(v) {
  if (v == null) return null;
  const n = parseFloat(String(v));
  if (!Number.isFinite(n)) return null;
  return n;
}

function buildMetricsSnapshot(sprint) {
  const nowIso = new Date().toISOString();
  const updatedAt = sprint.updated_at ? new Date(sprint.updated_at).toISOString() : nowIso;
  return {
    id: String(sprint.id),
    sprintId: String(sprint.id),
    committedPoints: sprint.committed_points ?? 0,
    completedPoints: sprint.completed_points ?? 0,
    carriedOverPoints: sprint.carried_over_points ?? 0,
    testPassRate: Number(sprint.test_pass_rate ?? 0),
    defectsOpened: sprint.defects_opened ?? 0,
    defectsClosed: sprint.defects_closed ?? 0,
    criticalDefects: 0,
    highDefects: 0,
    mediumDefects: 0,
    lowDefects: 0,
    codeReviewCompletion: Number(sprint.code_review_completion ?? 0),
    documentationStatus: Number.parseFloat(String(sprint.documentation_status ?? '0')) || 0,
    risks: sprint.risks ?? null,
    mitigations: null,
    scopeChanges: null,
    pointsAddedDuringSprint: sprint.added_during_sprint ?? 0,
    pointsRemovedDuringSprint: sprint.removed_during_sprint ?? 0,
    blockers: sprint.blockers ?? null,
    decisions: sprint.decisions ?? null,
    uatNotes: sprint.uat_notes ?? null,
    recordedAt: updatedAt,
    recordedBy: sprint.created_by ? String(sprint.created_by) : 'system',
  };
}

async function upsertSprintMetricsFromSprintRow({ sprint, userId }) {
  try {
    const snap = buildMetricsSnapshot(sprint);
    const plannedPoints = sprint.planned_points ?? null;
    await sequelize.query(
      `INSERT INTO sprint_metrics (
         sprint_id,
         planned_points,
         committed_points,
         completed_points,
         carried_over_points,
         test_pass_rate,
         defects_opened,
         defects_closed,
         code_review_completion,
         documentation_status,
         risks,
         blockers,
         decisions,
         uat_notes,
         points_added_during_sprint,
         points_removed_during_sprint,
         recorded_at,
         recorded_by,
         updated_at
       )
       VALUES (
         $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,NOW(),$17,NOW()
       )
       ON CONFLICT (sprint_id) DO UPDATE SET
         planned_points = EXCLUDED.planned_points,
         committed_points = EXCLUDED.committed_points,
         completed_points = EXCLUDED.completed_points,
         carried_over_points = EXCLUDED.carried_over_points,
         test_pass_rate = EXCLUDED.test_pass_rate,
         defects_opened = EXCLUDED.defects_opened,
         defects_closed = EXCLUDED.defects_closed,
         code_review_completion = EXCLUDED.code_review_completion,
         documentation_status = EXCLUDED.documentation_status,
         risks = EXCLUDED.risks,
         blockers = EXCLUDED.blockers,
         decisions = EXCLUDED.decisions,
         uat_notes = EXCLUDED.uat_notes,
         points_added_during_sprint = EXCLUDED.points_added_during_sprint,
         points_removed_during_sprint = EXCLUDED.points_removed_during_sprint,
         recorded_at = NOW(),
         recorded_by = EXCLUDED.recorded_by,
         updated_at = NOW()`,
      {
        bind: [
          String(sprint.id),
          plannedPoints,
          snap.committedPoints,
          snap.completedPoints,
          snap.carriedOverPoints,
          snap.testPassRate,
          snap.defectsOpened,
          snap.defectsClosed,
          snap.codeReviewCompletion,
          snap.documentationStatus,
          snap.risks,
          snap.blockers,
          snap.decisions,
          snap.uatNotes,
          snap.pointsAddedDuringSprint,
          snap.pointsRemovedDuringSprint,
          userId ? String(userId) : null,
        ],
      }
    );
  } catch (e) {
    if (!(e && e.original && e.original.code === '42P01')) {
      console.error('Failed to upsert sprint_metrics snapshot:', e);
    }
  }
}

router.get('/:id/metrics', async (req, res) => {
  try {
    const { id } = req.params;
    const sprint = await Sprint.findByPk(id);
    if (!sprint) return res.status(404).json({ success: false, error: 'Sprint not found' });
    return res.json({ success: true, data: [buildMetricsSnapshot(sprint)] });
  } catch (error) {
    console.error('Error fetching sprint metrics:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

async function upsertSprintMetrics(req, res) {
  try {
    const { id } = req.params;
    const sprint = await Sprint.findByPk(id);
    if (!sprint) return res.status(404).json({ success: false, error: 'Sprint not found' });

    const body = req.body || {};
    const patch = {};
    const committedPoints = normalizeMetricsInt(body.committedPoints ?? body.committed_points);
    const completedPoints = normalizeMetricsInt(body.completedPoints ?? body.completed_points);
    const carriedOverPoints = normalizeMetricsInt(body.carriedOverPoints ?? body.carried_over_points);
    const testPassRate = normalizeMetricsFloat(body.testPassRate ?? body.test_pass_rate);
    const defectsOpened = normalizeMetricsInt(body.defectsOpened ?? body.defects_opened);
    const defectsClosed = normalizeMetricsInt(body.defectsClosed ?? body.defects_closed);
    const codeReviewCompletion = normalizeMetricsFloat(body.codeReviewCompletion ?? body.code_review_completion);
    const documentationStatus = body.documentationStatus ?? body.documentation_status;
    const pointsAdded = normalizeMetricsInt(body.pointsAddedDuringSprint ?? body.points_added_during_sprint ?? body.added_during_sprint ?? body.points_added);
    const pointsRemoved = normalizeMetricsInt(body.pointsRemovedDuringSprint ?? body.points_removed_during_sprint ?? body.removed_during_sprint ?? body.points_removed);

    if (committedPoints != null) patch.committed_points = committedPoints;
    if (completedPoints != null) patch.completed_points = completedPoints;
    if (carriedOverPoints != null) patch.carried_over_points = carriedOverPoints;
    if (testPassRate != null) patch.test_pass_rate = Math.round(testPassRate);
    if (defectsOpened != null) patch.defects_opened = defectsOpened;
    if (defectsClosed != null) patch.defects_closed = defectsClosed;
    if (codeReviewCompletion != null) patch.code_review_completion = Math.round(codeReviewCompletion);
    if (documentationStatus != null) patch.documentation_status = String(documentationStatus);
    if (pointsAdded != null) patch.added_during_sprint = pointsAdded;
    if (pointsRemoved != null) patch.removed_during_sprint = pointsRemoved;
    if (body.risks != null) patch.risks = String(body.risks);
    if (body.blockers != null) patch.blockers = String(body.blockers);
    if (body.decisions != null) patch.decisions = String(body.decisions);
    if (body.uatNotes != null || body.uat_notes != null) patch.uat_notes = String(body.uatNotes ?? body.uat_notes);

    await sprint.update(patch);
    return res.json({ success: true, data: [buildMetricsSnapshot(sprint)] });
  } catch (error) {
    console.error('Error updating sprint metrics:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
}

router.post('/:id/metrics', authenticateToken, upsertSprintMetrics);
router.put('/:id/metrics', authenticateToken, upsertSprintMetrics);

/**
 * @route GET /api/sprints/:id
 * @desc Get a specific sprint by ID
 * @access Public
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const sprint = await Sprint.findByPk(id, {
      include: [
        { model: Project, as: 'project', attributes: ['id', 'name', 'key'] }
      ]
    });
    
    if (!sprint) {
      return res.status(404).json({ 
        success: false,
        error: 'Sprint not found' 
      });
    }
    
    res.json({
      success: true,
      data: sprint
    });
  } catch (error) {
    console.error('Error fetching sprint:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error',
      details: error.message,
      stack: error.stack
    });
  }
});

/**
 * @route POST /api/sprints
 * @desc Create a new sprint
 * @access Private
 */
router.post('/', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    const sprintData = normalizeSprintData(req.body);
    const sprint = await Sprint.create(sprintData);
    
    res.status(201).json({
      success: true,
      data: sprint
    });
  } catch (error) {
    console.error('Error creating sprint:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route PUT /api/sprints/:id
 * @desc Update an existing sprint
 * @access Private
 */
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = normalizeSprintData(req.body);
    
    const sprint = await Sprint.findByPk(id);
    
    if (!sprint) {
      return res.status(404).json({ error: 'Sprint not found' });
    }

    const normalizeRole = (r) => String(r || '').toLowerCase().replace(/[\s_-]+/g, '');
    const role = normalizeRole(req.user && req.user.role);
    const isPrivileged = ['admin', 'systemadmin', 'deliverylead'].includes(role);
    let isProjectOwner = false;
    try {
      const pid = sprint.project_id;
      if (pid) {
        const project = await Project.findByPk(pid);
        if (project && project.owner_id && req.user && req.user.id) {
          isProjectOwner = String(project.owner_id) === String(req.user.id);
        }
      }
    } catch (_) {}
    if (!isPrivileged && !isProjectOwner) {
      return res.status(403).json({ error: 'Not authorized to update this sprint' });
    }
    
    await sprint.update(updateData);
    await upsertSprintMetricsFromSprintRow({ sprint, userId: req.user && req.user.id });
    
    res.json({ success: true, data: sprint });
  } catch (error) {
    console.error('Error updating sprint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PUT /api/sprints/:id/status
 * @desc Update sprint status (compatibility endpoint)
 * @access Private
 */
router.put('/:id/status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const nextStatus = req.body?.status ?? req.body?.state ?? req.body?.newStatus;
    if (nextStatus == null || String(nextStatus).trim() === '') {
      return res.status(400).json({ error: 'status is required' });
    }

    const sprint = await Sprint.findByPk(id);
    if (!sprint) {
      return res.status(404).json({ error: 'Sprint not found' });
    }

    const normalizeRole = (r) => String(r || '').toLowerCase().replace(/[\s_-]+/g, '');
    const role = normalizeRole(req.user && req.user.role);
    const isPrivileged = ['admin', 'systemadmin', 'deliverylead'].includes(role);
    let isProjectOwner = false;
    try {
      const pid = sprint.project_id;
      if (pid) {
        const project = await Project.findByPk(pid);
        if (project && project.owner_id && req.user && req.user.id) {
          isProjectOwner = String(project.owner_id) === String(req.user.id);
        }
      }
    } catch (_) {}
    if (!isPrivileged && !isProjectOwner) {
      return res.status(403).json({ error: 'Not authorized to update sprint status' });
    }

    const ns = String(nextStatus || '').toLowerCase().replace(/[\s_-]+/g, '');
    const isCompleting = ns === 'completed' || ns === 'done' || ns === 'closed';
    if (isCompleting) {
      const missing = [];
      if (sprint.test_pass_rate == null) missing.push('test_pass_rate');
      if (sprint.defects_opened == null) missing.push('defects_opened');
      if (sprint.defects_closed == null) missing.push('defects_closed');
      if (sprint.code_review_completion == null) missing.push('code_review_completion');
      if (sprint.documentation_status == null) missing.push('documentation_status');
      if (missing.length > 0) {
        return res.status(400).json({
          error: 'Sprint metrics must be completed before marking the sprint as completed',
          missingFields: missing,
        });
      }
    }

    await sprint.update({ status: nextStatus });
    res.json({ success: true, data: sprint });
  } catch (error) {
    console.error('Error updating sprint status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/sprints/:id
 * @desc Delete a sprint
 * @access Private
 */
router.delete('/:id', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    const { id } = req.params;
    
    const sprint = await Sprint.findByPk(id);
    
    if (!sprint) {
      return res.status(404).json({ error: 'Sprint not found' });
    }
    
    await sprint.destroy();
    
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting sprint:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
