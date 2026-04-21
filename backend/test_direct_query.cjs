require('dotenv').config();

async function testWithDirectQuery() {
  const { Pool } = require('pg');
  const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'flow_space',
    password: process.env.DB_PASSWORD || 'postgres',
    port: process.env.DB_PORT || 5432,
    connectionString: process.env.DATABASE_URL,
  });

  try {
    const deliverableId = '11d458da-6356-47c2-89ed-8b9cc5c5d109';
    const status = 'completed';
    
    console.log('🧪 Testing direct query with UUID...');
    
    // Test the exact query from the endpoint
    const query = `
      UPDATE deliverables 
      SET status = $1, updated_at = NOW() 
      WHERE id = $2::uuid 
      RETURNING *
    `;
    
    const result = await pool.query(query, [status, deliverableId]);
    
    if (result.rows.length === 0) {
      console.log('❌ No deliverable found with that ID');
      
      // Check what deliverables exist
      const allDeliverables = await pool.query('SELECT id, title, status FROM deliverables LIMIT 5');
      console.log('📦 Available deliverables:');
      allDeliverables.rows.forEach((d, i) => {
        console.log(`   ${i+1}. ${d.title} (${d.id}) - ${d.status}`);
      });
    } else {
      console.log('✅ Query executed successfully!');
      console.log('📊 Updated deliverable:', result.rows[0]);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('Stack:', error.stack);
  } finally {
    await pool.end();
  }
}

testWithDirectQuery();
