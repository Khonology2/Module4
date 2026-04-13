/**
 * Removes QA dummy rows tagged with dummy_12h_seed after metadata/payload expires_at.
 * Safe to run repeatedly (no-op when nothing expired).
 */

const { QueryTypes } = require('sequelize');

function quoteUuidList(ids) {
  return ids
    .filter((id) => /^[0-9a-fA-F-]{36}$/.test(String(id)))
    .map((id) => `'${String(id)}'`)
    .join(', ');
}

async function runExpiredDummy12hCleanup(sequelize) {
  if (!sequelize) return { deletedProjects: 0 };

  const dialect = sequelize.getDialect();
  let projectIds = [];

  try {
    if (dialect === 'postgres') {
      const rows = await sequelize.query(
        `SELECT id::text AS id FROM projects
         WHERE (metadata::jsonb->>'dummy_12h_seed') IN ('true', '1')
           AND (metadata::jsonb->>'expires_at')::timestamptz < NOW()`,
        { type: QueryTypes.SELECT },
      );
      projectIds = rows.map((r) => r.id);
    } else {
      const rows = await sequelize.query(
        `SELECT id FROM projects
         WHERE json_extract(metadata, '$.dummy_12h_seed') IS NOT NULL
           AND json_extract(metadata, '$.dummy_12h_seed') IS NOT 0
           AND datetime(json_extract(metadata, '$.expires_at')) < datetime('now')`,
        { type: QueryTypes.SELECT },
      );
      projectIds = rows.map((r) => String(r.id));
    }
  } catch (e) {
    console.warn('[dummy12h-cleanup] Could not list expired dummy projects:', e.message);
    return { deletedProjects: 0, error: e.message };
  }

  if (projectIds.length === 0) {
    return { deletedProjects: 0 };
  }

  const inProjects = quoteUuidList(projectIds);
  if (!inProjects) {
    return { deletedProjects: 0 };
  }

  try {
    if (dialect === 'postgres') {
      await sequelize.query(
        `DELETE FROM notifications WHERE (payload::jsonb->>'dummy_12h_seed') IN ('true', '1')
         AND (payload::jsonb->>'expires_at')::timestamptz < NOW()`,
      );
      await sequelize.query(
        `DELETE FROM deliverable_sprints WHERE deliverable_id IN (
           SELECT id FROM deliverables WHERE project_id IN (${inProjects})
         )`,
      );
      await sequelize.query(
        `DELETE FROM deliverables WHERE project_id IN (${inProjects})`,
      );
      await sequelize.query(`DELETE FROM sprints WHERE project_id IN (${inProjects})`);
      await sequelize.query(
        `DELETE FROM project_members WHERE project_id IN (${inProjects})`,
      );
      await sequelize.query(`DELETE FROM projects WHERE id IN (${inProjects})`);
    } else {
      await sequelize.query(
        `DELETE FROM notifications WHERE json_extract(payload, '$.dummy_12h_seed') IS NOT NULL
         AND datetime(json_extract(payload, '$.expires_at')) < datetime('now')`,
      );
      await sequelize.query(
        `DELETE FROM deliverable_sprints WHERE deliverable_id IN (
           SELECT id FROM deliverables WHERE project_id IN (${inProjects})
         )`,
      );
      await sequelize.query(
        `DELETE FROM deliverables WHERE project_id IN (${inProjects})`,
      );
      await sequelize.query(`DELETE FROM sprints WHERE project_id IN (${inProjects})`);
      await sequelize.query(
        `DELETE FROM project_members WHERE project_id IN (${inProjects})`,
      );
      await sequelize.query(`DELETE FROM projects WHERE id IN (${inProjects})`);
    }

    console.log(
      `[dummy12h-cleanup] Removed expired dummy pack: ${projectIds.length} project(s)`,
    );
    return { deletedProjects: projectIds.length };
  } catch (e) {
    console.error('[dummy12h-cleanup] Delete failed:', e.message);
    return { deletedProjects: 0, error: e.message };
  }
}

module.exports = { runExpiredDummy12hCleanup };
