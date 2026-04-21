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

async function testTransactionHandling() {
  try {
    console.log('🧪 Testing transaction handling for sprint creation...');
    
    // Get test data
    const projectResult = await pool.query('SELECT id, name FROM projects LIMIT 1');
    const userResult = await pool.query('SELECT id, email FROM users LIMIT 1');
    
    if (projectResult.rows.length === 0 || userResult.rows.length === 0) {
      console.log('❌ No test data available');
      return;
    }
    
    const projectId = projectResult.rows[0].id;
    const userId = userResult.rows[0].id;
    
    console.log(`✅ Using project: ${projectResult.rows[0].name}`);
    console.log(`✅ Using user: ${userResult.rows[0].email}`);
    
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Count sprints before
      const beforeCount = await client.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
      console.log(`📊 Sprints before: ${beforeCount.rows[0].count}`);
      
      // Create sprint
      const sprintResult = await client.query(`
        INSERT INTO sprints (name, description, start_date, end_date, project_id, created_by, status, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, 'planning', NOW(), NOW())
        RETURNING *
      `, [
        'Test Sprint Transaction',
        'Testing transaction rollback',
        new Date().toISOString().split('T')[0],
        new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        projectId,
        userId
      ]);
      
      const sprint = sprintResult.rows[0];
      console.log(`✅ Sprint created: ${sprint.id}`);
      
      // Count sprints after creation but before metrics
      const afterCreationCount = await client.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
      console.log(`📊 Sprints after creation: ${afterCreationCount.rows[0].count}`);
      
      // Try to insert metrics with a non-existent column to trigger error
      try {
        await client.query(`
          INSERT INTO sprint_metrics (sprint_id, non_existent_column) VALUES ($1, $2)
        `, [sprint.id, 'test_value']);
        
        await client.query('COMMIT');
        console.log('✅ Transaction committed');
        
      } catch (metricsError) {
        console.log(`❌ Metrics insertion failed: ${metricsError.message}`);
        await client.query('ROLLBACK');
        console.log('🔄 Transaction rolled back');
      }
      
      // Count sprints after rollback
      const afterRollbackCount = await client.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
      console.log(`📊 Sprints after rollback: ${afterRollbackCount.rows[0].count}`);
      
      // Verify transaction worked correctly
      if (beforeCount.rows[0].count === afterRollbackCount.rows[0].count) {
        console.log('🎉 Transaction handling works correctly - sprint was rolled back!');
      } else {
        console.log('❌ Transaction handling failed - sprint still exists after rollback');
      }
      
    } finally {
      client.release();
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await pool.end();
  }
}

testTransactionHandling();
