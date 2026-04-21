require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'flow_space',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
  connectionString: process.env.DATABASE_URL,
});

async function checkSprintsAndMetrics() {
  try {
    console.log('🔍 Checking existing sprints and their metrics...');
    
    // Get all sprints
    const sprintsResult = await pool.query(`
      SELECT s.id, s.name, s.project_id, p.name as project_name, s.created_at
      FROM sprints s
      LEFT JOIN projects p ON s.project_id = p.id
      ORDER BY s.created_at DESC
    `);
    
    console.log(`\n📋 Found ${sprintsResult.rows.length} sprints:`);
    
    for (const sprint of sprintsResult.rows) {
      // Check if sprint has metrics
      const metricsResult = await pool.query(`
        SELECT COUNT(*) as count, 
               planned_points, committed_points, completed_points,
               test_pass_rate, code_coverage
        FROM sprint_metrics 
        WHERE sprint_id = $1
        GROUP BY sprint_id, planned_points, committed_points, completed_points, test_pass_rate, code_coverage
      `, [sprint.id]);
      
      const hasMetrics = metricsResult.rows.length > 0;
      const metrics = metricsResult.rows[0] || {};
      
      console.log(`\n🏃 Sprint: ${sprint.name}`);
      console.log(`   📁 Project: ${sprint.project_name || 'Unknown'}`);
      console.log(`   🆔 ID: ${sprint.id}`);
      console.log(`   📊 Metrics: ${hasMetrics ? '✅ YES' : '❌ NO'}`);
      
      if (hasMetrics) {
        console.log(`   📈 Planned Points: ${metrics.planned_points || 0}`);
        console.log(`   📈 Committed Points: ${metrics.committed_points || 0}`);
        console.log(`   📈 Completed Points: ${metrics.completed_points || 0}`);
      }
    }
    
    // Summary
    const sprintsWithMetrics = await pool.query(`
      SELECT COUNT(DISTINCT s.id) as count
      FROM sprints s
      INNER JOIN sprint_metrics sm ON s.id = sm.sprint_id
    `);
    
    const totalSprints = sprintsResult.rows.length;
    const withMetrics = parseInt(sprintsWithMetrics.rows[0].count);
    const withoutMetrics = totalSprints - withMetrics;
    
    console.log(`\n📊 Summary:`);
    console.log(`   Total Sprints: ${totalSprints}`);
    console.log(`   With Metrics: ${withMetrics}`);
    console.log(`   Without Metrics: ${withoutMetrics}`);
    
    if (withoutMetrics > 0) {
      console.log(`\n⚠️  ${withoutMetrics} sprint(s) are missing metrics!`);
      console.log(`💡 Would you like me to add default metrics to these sprints?`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkSprintsAndMetrics();
