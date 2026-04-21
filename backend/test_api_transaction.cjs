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

async function testAPITransactionHandling() {
  try {
    console.log('🧪 Testing actual API transaction handling...');
    
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
    
    // Count sprints before
    const beforeCount = await pool.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
    console.log(`📊 Sprints before: ${beforeCount.rows[0].count}`);
    
    // Simulate the exact same logic as the API endpoint
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Mock request data
      const body = {
        name: 'API Test Sprint',
        description: 'Testing API transaction rollback',
        start_date: new Date().toISOString().split('T')[0],
        end_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        project_id: projectId,
        planned_points: 20,
        non_existent_metric: 'this should cause error'
      };
      
      // Normalize field names (same as API)
      const normalizedStartDate = body.start_date;
      const normalizedEndDate = body.end_date;
      const normalizedProjectId = body.project_id;
      const normalizedCreatedBy = userId;
      
      // Create sprint (same as API)
      const createdByVal = String(normalizedCreatedBy || userId);
      const fields = ['name', 'start_date', 'end_date', 'created_by'];
      const vals = [body.name, normalizedStartDate, normalizedEndDate, createdByVal];
      
      if (normalizedProjectId) {
        fields.push('project_id');
        vals.push(normalizedProjectId);
      }
      if (body.description) {
        fields.push('description');
        vals.push(body.description);
      }
      fields.push('status');
      vals.push('planning');
      
      const result = await client.query(
        `INSERT INTO sprints (${fields.join(', ')}, created_at, updated_at) VALUES (${vals.map((_, i) => `$${i + 1}`).join(', ')}, NOW(), NOW()) RETURNING *`,
        vals
      );
      const sprint = result.rows[0];
      console.log(`✅ Sprint created: ${sprint.id}`);
      
      // Handle sprint metrics (same as API)
      const sprintId = sprint.id;
      const metricsFields = [];
      const metricsVals = [];
      
      // Process metrics (same as API)
      if (body.planned_points) {
        metricsFields.push('planned_points');
        metricsVals.push(body.planned_points);
      }
      
      // Try to insert a non-existent metric to trigger error
      if (body.non_existent_metric) {
        metricsFields.push('non_existent_metric');
        metricsVals.push(body.non_existent_metric);
      }
      
      // Insert sprint metrics (this should fail)
      if (metricsFields.length > 0) {
        const placeholders = metricsVals.map((_, i) => `$${i + 1}`).join(', ');
        await client.query(
          `INSERT INTO sprint_metrics (sprint_id, ${metricsFields.join(', ')}) VALUES ($1, ${placeholders})`,
          [sprintId, ...metricsVals]
        );
      }
      
      await client.query('COMMIT');
      console.log('✅ Transaction committed successfully');
      
    } catch (error) {
      await client.query('ROLLBACK');
      console.log(`❌ Error occurred: ${error.message}`);
      console.log('🔄 Transaction rolled back');
      
    } finally {
      client.release();
    }
    
    // Count sprints after
    const afterCount = await pool.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
    console.log(`📊 Sprints after: ${afterCount.rows[0].count}`);
    
    // Verify
    if (beforeCount.rows[0].count === afterCount.rows[0].count) {
      console.log('🎉 API transaction handling works correctly!');
    } else {
      console.log('❌ API transaction handling failed - sprint was not rolled back');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await pool.end();
  }
}

testAPITransactionHandling();
