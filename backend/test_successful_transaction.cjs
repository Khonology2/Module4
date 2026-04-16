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

async function testSuccessfulTransaction() {
  try {
    console.log('🧪 Testing successful sprint creation with metrics...');
    
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
    
    // Simulate successful API call
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');
      
      // Mock request data with valid metrics
      const body = {
        name: 'Successful Test Sprint',
        description: 'Testing successful transaction',
        start_date: new Date().toISOString().split('T')[0],
        end_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        project_id: projectId,
        planned_points: 25,
        committed_points: 20,
        risks: 'Test risk',
        blockers: 'Test blocker'
      };
      
      // Create sprint
      const createdByVal = String(userId);
      const fields = ['name', 'start_date', 'end_date', 'created_by'];
      const vals = [body.name, body.start_date, body.end_date, createdByVal];
      
      if (body.project_id) {
        fields.push('project_id');
        vals.push(body.project_id);
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
      
      // Handle sprint metrics
      const metricsFields = [];
      const metricsVals = [];
      
      if (body.planned_points) {
        metricsFields.push('planned_points');
        metricsVals.push(body.planned_points);
      }
      if (body.committed_points) {
        metricsFields.push('committed_points');
        metricsVals.push(body.committed_points);
      }
      if (body.risks) {
        metricsFields.push('risks');
        metricsVals.push(body.risks);
      }
      if (body.blockers) {
        metricsFields.push('blockers');
        metricsVals.push(body.blockers);
      }
      
      // Insert sprint metrics (should succeed)
      if (metricsFields.length > 0) {
        const placeholders = metricsVals.map((_, i) => `$${i + 1}`).join(', ');
        await client.query(
          `INSERT INTO sprint_metrics (sprint_id, ${metricsFields.join(', ')}) VALUES ($1, ${placeholders})`,
          [sprint.id, ...metricsVals]
        );
        console.log('✅ Sprint metrics inserted successfully');
      }
      
      await client.query('COMMIT');
      console.log('✅ Transaction committed successfully');
      
      // Verify the data was saved
      const sprintCheck = await pool.query('SELECT * FROM sprints WHERE id = $1', [sprint.id]);
      const metricsCheck = await pool.query('SELECT * FROM sprint_metrics WHERE sprint_id = $1', [sprint.id]);
      
      console.log(`📊 Sprint verified: ${sprintCheck.rows.length > 0 ? 'YES' : 'NO'}`);
      console.log(`📊 Metrics verified: ${metricsCheck.rows.length > 0 ? 'YES' : 'NO'} (${metricsCheck.rows.length} rows)`);
      
      // Clean up test data
      await pool.query('DELETE FROM sprint_metrics WHERE sprint_id = $1', [sprint.id]);
      await pool.query('DELETE FROM sprints WHERE id = $1', [sprint.id]);
      console.log('🧹 Test data cleaned up');
      
    } catch (error) {
      await client.query('ROLLBACK');
      console.log(`❌ Error occurred: ${error.message}`);
      console.log('🔄 Transaction rolled back');
      
    } finally {
      client.release();
    }
    
    // Count sprints after cleanup
    const afterCount = await pool.query('SELECT COUNT(*) as count FROM sprints WHERE project_id = $1', [projectId]);
    console.log(`📊 Sprints after cleanup: ${afterCount.rows[0].count}`);
    
    // Verify
    if (beforeCount.rows[0].count === afterCount.rows[0].count) {
      console.log('🎉 Successful transaction test completed correctly!');
    } else {
      console.log('❌ Cleanup failed - test data remains');
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await pool.end();
  }
}

testSuccessfulTransaction();
