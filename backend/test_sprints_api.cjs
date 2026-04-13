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

async function testSprintsWithMetrics() {
  try {
    console.log('🧪 Testing updated sprints API with metrics...');
    
    // Test the updated query (same as API)
    const result = await pool.query(`
      SELECT s.*, 
             sm.planned_points,
             sm.committed_points,
             sm.completed_points,
             sm.carried_over_points,
             sm.test_pass_rate,
             sm.code_coverage,
             sm.escaped_defects,
             sm.defects_opened,
             sm.defects_closed,
             sm.code_review_completion,
             sm.documentation_status,
             sm.uat_notes,
             sm.uat_pass_rate,
             sm.risks,
             sm.blockers,
             sm.decisions
      FROM sprints s 
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      ORDER BY s.created_at DESC
      LIMIT 5
    `);
    
    console.log(`\n📋 Found ${result.rows.length} sprints with metrics:`);
    
    result.rows.forEach((sprint, index) => {
      console.log(`\n🏃 Sprint ${index + 1}: ${sprint.name}`);
      console.log(`   📁 Project: ${sprint.project_id || 'Unknown'}`);
      console.log(`   🆔 ID: ${sprint.id}`);
      console.log(`   📊 Has Metrics: ${sprint.planned_points !== null ? 'YES' : 'NO'}`);
      
      if (sprint.planned_points !== null) {
        console.log(`   📈 Planned Points: ${sprint.planned_points}`);
        console.log(`   📈 Committed Points: ${sprint.committed_points}`);
        console.log(`   📈 Completed Points: ${sprint.completed_points}`);
        console.log(`   📈 Velocity (completed): ${sprint.completed_points}`);
        
        // This is what the frontend velocity calculation uses
        const velocity = sprint.completed_points || 0;
        console.log(`   🚀 Velocity for chart: ${velocity}`);
      }
    });
    
    // Test specifically for velocity calculation
    console.log('\n🎯 Testing velocity calculation (as used by frontend):');
    const sprintStats = result.rows.filter(s => s.completed_points !== null);
    
    if (sprintStats.length > 0) {
      const avgVelocity = sprintStats
        .map((m) => (m.completed_points || 0))
        .reduce((a, b) => a + b, 0) / sprintStats.length;
      
      console.log(`📊 Average Velocity: ${avgVelocity.toFixed(1)}`);
      console.log(`📊 Total Completed Points: ${sprintStats.reduce((sum, s) => sum + (s.completed_points || 0), 0)}`);
      
      // Show what frontend expects
      console.log('\n📱 Frontend expects this format:');
      sprintStats.forEach(sprint => {
        console.log(`   ${sprint.name}: velocity = ${(sprint.completed_points || 0)}`);
      });
    } else {
      console.log('❌ No sprints with completed_points found');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

testSprintsWithMetrics();
