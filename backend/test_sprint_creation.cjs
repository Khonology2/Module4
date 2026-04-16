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

async function testSprintCreation() {
  try {
    console.log('🧪 Testing sprint creation with metrics...');
    
    // First, let's check if we have a project to work with
    const projectResult = await pool.query(`
      SELECT id, name FROM projects LIMIT 1
    `);
    
    if (projectResult.rows.length === 0) {
      console.log('❌ No projects found - cannot test sprint creation');
      return;
    }
    
    const projectId = projectResult.rows[0].id;
    console.log(`✅ Using project: ${projectResult.rows[0].name} (${projectId})`);
    
    // Test user (use first available user)
    const userResult = await pool.query(`
      SELECT id, email FROM users LIMIT 1
    `);
    
    if (userResult.rows.length === 0) {
      console.log('❌ No users found - cannot test sprint creation');
      return;
    }
    
    const userId = userResult.rows[0].id;
    console.log(`✅ Using user: ${userResult.rows[0].email} (${userId})`);
    
    // Test the exact INSERT that server.js would do for sprint creation
    console.log('\n🔄 Testing sprint creation...');
    
    const testSprintData = {
      name: 'Test Sprint for Database Verification',
      description: 'This is a test sprint to verify database schema',
      start_date: new Date().toISOString().split('T')[0],
      end_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      project_id: projectId,
      created_by: userId
    };
    
    // Insert sprint
    const sprintResult = await pool.query(`
      INSERT INTO sprints (name, description, start_date, end_date, project_id, created_by, status, created_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, 'planning', NOW(), NOW())
      RETURNING *
    `, [
      testSprintData.name,
      testSprintData.description,
      testSprintData.start_date,
      testSprintData.end_date,
      testSprintData.project_id,
      testSprintData.created_by
    ]);
    
    const sprint = sprintResult.rows[0];
    console.log(`✅ Sprint created successfully: ${sprint.name} (${sprint.id})`);
    
    // Test sprint metrics insertion
    console.log('\n🔄 Testing sprint metrics insertion...');
    
    const metricsData = {
      planned_points: 20,
      committed_points: 18,
      completed_points: 0,
      carried_over_points: 0,
      test_pass_rate: 85.5,
      code_coverage: 75.0,
      risks: 'Test risk',
      blockers: 'Test blocker',
      decisions: 'Test decision'
    };
    
    const metricsFields = Object.keys(metricsData);
    const metricsValues = Object.values(metricsData);
    
    if (metricsFields.length > 0) {
      const placeholders = metricsValues.map((_, i) => `$${i + 2}`).join(', ');
      await pool.query(`
        INSERT INTO sprint_metrics (sprint_id, ${metricsFields.join(', ')}) 
        VALUES ($1, ${placeholders})
      `, [sprint.id, ...metricsValues]);
      
      console.log('✅ Sprint metrics inserted successfully!');
      
      // Verify the metrics were saved
      const verifyMetrics = await pool.query(`
        SELECT * FROM sprint_metrics WHERE sprint_id = $1
      `, [sprint.id]);
      
      console.log('\n📊 Saved metrics:');
      Object.keys(metricsData).forEach(key => {
        console.log(`  ✅ ${key}: ${verifyMetrics.rows[0][key]}`);
      });
    }
    
    // Clean up test data
    console.log('\n🧹 Cleaning up test data...');
    await pool.query('DELETE FROM sprint_metrics WHERE sprint_id = $1', [sprint.id]);
    await pool.query('DELETE FROM sprints WHERE id = $1', [sprint.id]);
    console.log('✅ Test data cleaned up');
    
    console.log('\n🎉 All tests passed! Database schema is ready for sprint creation.');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.error('Stack:', error.stack);
  } finally {
    await pool.end();
  }
}

testSprintCreation();
