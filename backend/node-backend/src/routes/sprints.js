const express = require('express');
const router = express.Router();
const { Sprint, Project, Deliverable, User } = require('../models');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { carryOverOverdueDeliverablesForProject } = require('../services/sprintCarryOverService');

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
  try {
    const { id } = req.params;
    const statusCategory = (req.query.statusCategory || req.query.status || '').toString().trim();
    const ownerId = (req.query.ownerId || req.query.owner_id || '').toString().trim();
    const dueFrom = (req.query.dueFrom || req.query.due_from || '').toString().trim();
    const dueTo = (req.query.dueTo || req.query.due_to || '').toString().trim();

    const sprint = await Sprint.findByPk(id, {
      include: [{ model: Project, as: 'project', attributes: ['id', 'name', 'key'] }],
    });
    if (!sprint) {
      return res.status(404).json({ success: false, error: 'Sprint not found' });
    }

    if (sprint.project_id) {
      try {
        await carryOverOverdueDeliverablesForProject(sprint.project_id);
      } catch (e) {
        console.error('Error carrying over overdue deliverables:', e);
      }
    }

    const sprintWithDeliverables = await Sprint.findByPk(id, {
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

    const now = new Date();
    const rawDeliverables = (sprintWithDeliverables && sprintWithDeliverables.deliverables) ? sprintWithDeliverables.deliverables : [];

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
    const health = (counts.overdue > 0)
      ? 'critical'
      : (endDate && endDate.getTime() < now.getTime() && completionRate < 100 ? 'warning' : 'good');

    const report = {
      generatedAt: now.toISOString(),
      sprint: {
        id: String(sprintWithDeliverables.id),
        name: sprintWithDeliverables.name,
        startDate: sprintWithDeliverables.start_date ? new Date(sprintWithDeliverables.start_date).toISOString() : null,
        endDate: sprintWithDeliverables.end_date ? new Date(sprintWithDeliverables.end_date).toISOString() : null,
        status: sprintStatus,
        projectId: sprintWithDeliverables.project_id ? String(sprintWithDeliverables.project_id) : null,
        project: sprintWithDeliverables.project ? {
          id: sprintWithDeliverables.project.id,
          name: sprintWithDeliverables.project.name,
          key: sprintWithDeliverables.project.key,
        } : null,
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

    return res.json({ success: true, data: report });
  } catch (error) {
    console.error('Error generating sprint report:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
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
