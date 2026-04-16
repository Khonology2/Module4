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

async function updateSprintMetricsForDemo() {
  try {
    console.log('🎯 Updating sprint metrics for velocity chart demonstration...');
    
    // Get all sprints with their metrics
    const result = await pool.query(`
      SELECT s.id, s.name, s.project_id,
             sm.planned_points,
             sm.committed_points,
             sm.completed_points
      FROM sprints s 
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      WHERE sm.completed_points = 0 OR sm.completed_points IS NULL
      ORDER BY s.created_at DESC
      LIMIT 5
    `);
    
    console.log(`\n📋 Found ${result.rows.length} sprints to update:`);
    
    for (const sprint of result.rows) {
      // Set realistic completed points (80% of committed points on average)
      const committedPoints = sprint.committed_points || 18;
      const completedPoints = Math.floor(committedPoints * 0.8); // 80% completion rate
      
      console.log(`\n🏃 Updating sprint: ${sprint.name}`);
      console.log(`   📊 Committed: ${committedPoints} → Completed: ${completedPoints}`);
      
      // Update the sprint metrics
      await pool.query(`
        UPDATE sprint_metrics 
        SET completed_points = $1
        WHERE sprint_id = $2
      `, [completedPoints, sprint.id]);
      
      console.log(`   ✅ Updated successfully`);
    }
    
    // Verify the updates
    console.log('\n🔍 Verification - Updated sprint metrics:');
    const verifyResult = await pool.query(`
      SELECT s.name, 
             sm.planned_points,
             sm.committed_points,
             sm.completed_points,
             (sm.completed_points::float / NULLIF(sm.committed_points, 0) * 100) as completion_percentage
      FROM sprints s 
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      WHERE s.id IN (
        SELECT id FROM sprints 
        ORDER BY created_at DESC 
        LIMIT 5
      )
      ORDER BY s.created_at DESC
    `);
    
    verifyResult.rows.forEach((sprint, index) => {
      console.log(`\n📊 Sprint ${index + 1}: ${sprint.name}`);
      console.log(`   📈 Planned: ${sprint.planned_points}`);
      console.log(`   📈 Committed: ${sprint.committed_points}`);
      console.log(`   📈 Completed: ${sprint.completed_points}`);
      console.log(`   📈 Completion: ${sprint.completion_percentage?.toFixed(1)}%`);
      console.log(`   🚀 Velocity: ${sprint.completed_points}`);
    });
    
    console.log('\n✅ Sprint metrics updated successfully!');
    console.log('🎯 Refresh your Flutter app to see the velocity charts working!');
    
  } catch (error) {
    console.error('❌ Error updating sprint metrics:', error.message);
  } finally {
    await pool.end();
  }
}

updateSprintMetricsForDemo();
