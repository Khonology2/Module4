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

async function testDeliverableStatusUpdate() {
  try {
    console.log('🧪 Testing deliverable status update endpoint...');
    
    // Get a deliverable to test with
    const deliverableResult = await pool.query(`
      SELECT id, title, status 
      FROM deliverables 
      LIMIT 1
    `);
    
    if (deliverableResult.rows.length === 0) {
      console.log('❌ No deliverables found to test with');
      return;
    }
    
    const deliverable = deliverableResult.rows[0];
    console.log(`\n📦 Testing with deliverable: ${deliverable.title} (${deliverable.id})`);
    console.log(`   📊 Current status: ${deliverable.status}`);
    
    // Test the update (simulate what the frontend does)
    const newStatus = 'completed';
    console.log(`   🔄 Updating status to: ${newStatus}`);
    
    const updateResult = await pool.query(`
      UPDATE deliverables 
      SET status = $1, updated_at = NOW() 
      WHERE id = $2::uuid 
      RETURNING id, title, status, updated_at
    `, [newStatus, deliverable.id]);
    
    if (updateResult.rows.length === 0) {
      console.log('❌ Failed to update deliverable');
      return;
    }
    
    const updated = updateResult.rows[0];
    console.log(`   ✅ Updated successfully!`);
    console.log(`   📊 New status: ${updated.status}`);
    console.log(`   ⏰ Updated at: ${updated.updated_at}`);
    
    // Verify the change persisted
    const verifyResult = await pool.query(`
      SELECT id, title, status, updated_at 
      FROM deliverables 
      WHERE id = $1::uuid
    `, [deliverable.id]);
    
    if (verifyResult.rows.length > 0) {
      const verified = verifyResult.rows[0];
      console.log(`   🔍 Verification - Status: ${verified.status}`);
      console.log(`   🔍 Verification - Updated: ${verified.updated_at}`);
      
      if (verified.status === newStatus) {
        console.log(`\n✅ SUCCESS: Deliverable status update is working correctly!`);
        console.log(`🎯 The issue might be in the frontend or API layer.`);
      } else {
        console.log(`\n❌ FAILURE: Status didn't persist correctly`);
      }
    }
    
  } catch (error) {
    console.error('❌ Error testing deliverable status update:', error.message);
  } finally {
    await pool.end();
  }
}

testDeliverableStatusUpdate();
