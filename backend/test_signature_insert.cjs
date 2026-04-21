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

async function testSignatureInsert() {
  try {
    console.log('🧪 Testing signature insertion directly...');
    
    const reportId = '6b092421-a0d4-47df-aeb6-d672cc82875f';
    const userId = '00356a1b-6e08-44b8-8499-a4491d14e988';
    const userRole = 'deliveryLead';
    const signatureData = 'test_signature_data';
    const signatureHash = 'test_hash_123';
    const ipAddress = '127.0.0.1';
    const userAgent = 'test_user_agent';
    
    // Test the exact query from the backend
    const result = await pool.query(`
      INSERT INTO digital_signatures (
        report_id, signer_id, signer_role, signature_type, 
        signature_data, signature_hash, ip_address, user_agent, 
        signed_at, created_at
      )
      VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, $8, NOW(), NOW())
      RETURNING *
    `, [
      reportId,
      userId,
      userRole,
      'manual',
      signatureData,
      signatureHash,
      ipAddress,
      userAgent
    ]);
    
    console.log('✅ Signature inserted successfully!');
    console.log('📊 Inserted signature:', result.rows[0]);
    
    // Clean up
    await pool.query('DELETE FROM digital_signatures WHERE id = $1', [result.rows[0].id]);
    console.log('🧹 Cleaned up test signature');
    
  } catch (error) {
    console.error('❌ Error inserting signature:', error.message);
    console.error('Stack:', error.stack);
  } finally {
    await pool.end();
  }
}

testSignatureInsert();
