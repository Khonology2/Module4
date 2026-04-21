require('dotenv').config();
const { sequelize } = require('../src/models');

async function col(table, column) {
  const [rows] = await sequelize.query(
    "SELECT table_name, column_name, data_type, udt_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2",
    { bind: [table, column] },
  );
  return rows && rows[0] ? rows[0] : null;
}

async function main() {
  const checks = [
    ['projects', 'id'],
    ['sprints', 'project_id'],
    ['deliverables', 'project_id'],
    ['tickets', 'project_id'],
    ['project_members', 'project_id'],
    ['project_members', 'user_id'],
  ];
  for (const [t, c] of checks) {
    const r = await col(t, c);
    console.log(`${t}.${c}:`, r);
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});

