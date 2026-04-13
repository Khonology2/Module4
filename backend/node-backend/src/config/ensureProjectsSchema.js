/**
 * Align legacy PostgreSQL `projects` tables with the Sequelize Project model.
 * Older DBs were created with only a subset of columns; missing `key` breaks every query.
 */
async function ensureProjectsSchema(sequelize) {
  if (sequelize.getDialect() !== 'postgres') {
    return;
  }

  const statements = [
    `ALTER TABLE projects ADD COLUMN IF NOT EXISTS key VARCHAR(100)`,
    `ALTER TABLE projects ADD COLUMN IF NOT EXISTS client_name VARCHAR(255)`,
    `ALTER TABLE projects ADD COLUMN IF NOT EXISTS client_owner_name VARCHAR(255)`,
    `ALTER TABLE projects ADD COLUMN IF NOT EXISTS project_type VARCHAR(50) DEFAULT 'software'`,
    `ALTER TABLE projects ADD COLUMN IF NOT EXISTS metadata JSONB`,
  ];

  for (const sql of statements) {
    await sequelize.query(sql);
  }

  // Stable unique key for any row that predates the column
  await sequelize.query(`
    UPDATE projects
    SET key = 'PRJ_' || REPLACE(id::text, '-', '')
    WHERE key IS NULL OR TRIM(COALESCE(key::text, '')) = '';
  `);

  try {
    await sequelize.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS projects_key_unique ON projects (key);
    `);
  } catch (e) {
    console.warn('⚠️ projects key unique index:', e.message);
  }
}

module.exports = { ensureProjectsSchema };
