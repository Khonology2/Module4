const { Sprint, Deliverable, DeliverableSprint, sequelize } = require('../models');

function normalizeStatus(v) {
  return String(v || '').toLowerCase().replace(/[\s_-]+/g, '');
}

function isDeliverableCompletedStatus(v) {
  const s = normalizeStatus(v);
  return s === 'signedoff' || s === 'approved' || s === 'completed' || s === 'done';
}

function isSprintCompletedStatus(v) {
  const s = normalizeStatus(v);
  return s === 'completed' || s === 'done' || s === 'closed';
}

function dateValue(d) {
  const t = d instanceof Date ? d.getTime() : (d ? new Date(d).getTime() : 0);
  return Number.isFinite(t) ? t : 0;
}

async function carryOverOverdueDeliverablesForProject(projectId) {
  if (!projectId || String(projectId).trim() === '') return { moved: 0 };

  const now = new Date();
  const all = await Sprint.findAll({ where: { project_id: projectId } });
  if (!all || all.length < 2) return { moved: 0 };

  const sorted = [...all].sort((a, b) => {
    const ak = dateValue(a.start_date) || dateValue(a.created_at);
    const bk = dateValue(b.start_date) || dateValue(b.created_at);
    if (ak !== bk) return ak - bk;
    return (a.id || 0) - (b.id || 0);
  });

  let movedTotal = 0;

  for (const sprint of sorted) {
    const endDate = sprint.end_date ? new Date(sprint.end_date) : null;
    if (!endDate || !(endDate.getTime() < now.getTime())) continue;

    const baseTime = endDate.getTime();
    const next = sorted.find((s) => {
      if (!s || s.id === sprint.id) return false;
      const startKey = dateValue(s.start_date) || dateValue(s.created_at);
      return startKey >= baseTime;
    });
    if (!next) continue;

    const deliverables = await Deliverable.findAll({
      attributes: ['id', 'status'],
      include: [
        {
          model: Sprint,
          as: 'contributing_sprints',
          attributes: [],
          through: { attributes: [] },
          where: { id: sprint.id },
          required: true,
        },
      ],
    });

    const toMove = (deliverables || []).filter((d) => !isDeliverableCompletedStatus(d.status));
    if (!toMove || toMove.length === 0) continue;

    await sequelize.transaction(async (t) => {
      for (const d of toMove) {
        const deliverableId = d.id;
        if (deliverableId == null) continue;
        await DeliverableSprint.destroy({
          where: { deliverable_id: deliverableId, sprint_id: sprint.id },
          transaction: t,
        });
        await DeliverableSprint.findOrCreate({
          where: { deliverable_id: deliverableId, sprint_id: next.id },
          defaults: { contribution_percentage: 100, created_at: new Date() },
          transaction: t,
        });
      }
    });

    movedTotal += toMove.length;
  }

  return { moved: movedTotal };
}

module.exports = {
  carryOverOverdueDeliverablesForProject,
  isSprintCompletedStatus,
};
