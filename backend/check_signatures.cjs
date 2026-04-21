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

async function checkDigitalSignatures() {
  try {
    console.log('🔍 Checking digital signatures table...');
    
    // Get the report ID from the logs
    const reportId = '6b092421-a0d4-47df-aeb6-d672cc82875f';
    const userId = '00356a1b-6e08-44b8-8499-a4491d14e988';
    
    console.log(`\n📋 Checking signatures for report: ${reportId}`);
    console.log(`👤 User ID: ${userId}`);
    
    // Check what signatures exist for this report
    const signaturesResult = await pool.query(`
      SELECT * FROM digital_signatures 
      WHERE report_id = $1::uuid
    `, [reportId]);
    
    console.log(`\n📝 Found ${signaturesResult.rows.length} signatures:`);
    signaturesResult.rows.forEach((sig, index) => {
      console.log(`   ${index + 1}. ID: ${sig.id}`);
      console.log(`      user_id: ${sig.user_id}`);
      console.log(`      signer_id: ${sig.signer_id}`);
      console.log(`      signer_role: ${sig.signer_role}`);
      console.log(`      is_valid: ${sig.is_valid}`);
      console.log(`      signed_at: ${sig.signed_at}`);
      console.log(`      signature_type: ${sig.signature_type}`);
    });
    
    // Check the specific query that the submit endpoint uses
    console.log('\n🔍 Testing submit endpoint query...');
    const submitCheckResult = await pool.query(`
      SELECT * FROM digital_signatures 
      WHERE report_id = $1::uuid 
      AND signer_id = $2::uuid 
      AND signer_role = 'deliveryLead'
      AND is_valid = true
    `, [reportId, userId]);
    
    console.log(`\n📊 Submit check result: ${submitCheckResult.rows.length} rows`);
    if (submitCheckResult.rows.length === 0) {
      console.log('❌ No matching signature found for submit check');
      console.log('   This is why the submit is failing!');
    } else {
      console.log('✅ Signature found for submit check');
    }
    
    // Check what the actual values should be
    console.log('\n🔧 Checking user role...');
    const userResult = await pool.query(`
      SELECT role FROM users WHERE id = $1::uuid
    `, [userId]);
    
    if (userResult.rows.length > 0) {
      console.log(`👤 User role: ${userResult.rows[0].role}`);
    }
    
    // Check if is_valid column exists and what values it has
    console.log('\n📋 Checking digital_signatures table structure...');
    const structureResult = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'digital_signatures'
      ORDER BY ordinal_position
    `);
    
    structureResult.rows.forEach(col => {
      console.log(`   ${col.column_name}: ${col.data_type} (${col.is_nullable})`);
    });
    
  } catch (error) {
    console.error('❌ Error checking digital signatures:', error.message);
  } finally {
    await pool.end();
  }
}

checkDigitalSignatures();
