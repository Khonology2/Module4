import pool from './dbPool.js';

async function main() {
  try {
    const users = await pool.query(
      `SELECT id, name, email
       FROM users
       WHERE role = 'teamMember' AND is_active = true
       ORDER BY created_at DESC
       LIMIT 10`
    );

    for (const user of users.rows) {
      const deliverables = await pool.query(
        `SELECT COUNT(*)::int AS c
         FROM deliverables
         WHERE assigned_to = $1::uuid OR created_by = $1::uuid`,
        [user.id]
      );
      const projects = await pool.query(
        `SELECT COUNT(*)::int AS c FROM project_members WHERE user_id = $1::uuid`,
        [user.id]
      );
      const activity = await pool.query(
        `SELECT COUNT(*)::int AS c FROM activity_logs WHERE user_id = $1::uuid`,
        [user.id]
      );

      console.log(
        `${user.name} (${user.email}) => deliverables:${deliverables.rows[0].c}, projects:${projects.rows[0].c}, activity:${activity.rows[0].c}`
      );
    }
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
