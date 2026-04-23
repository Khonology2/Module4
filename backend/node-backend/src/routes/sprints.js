const express = require('express');
const router = express.Router();
const { Sprint, Project, Deliverable, User } = require('../models');
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
