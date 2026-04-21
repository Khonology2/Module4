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

async function testDatabaseFixes() {
  try {
    console.log('🧪 Testing database fixes...');
    
    // Test 1: Check if we can query repository_files with uploaded_at
    console.log('\n📁 Testing repository_files query...');
    const documentsResult = await pool.query(`
      SELECT id, file_name, uploaded_at, uploaded_by 
      FROM repository_files 
      LIMIT 3
    `);
    console.log(`✅ Found ${documentsResult.rows.length} documents with uploaded_at column`);
    
    // Test 2: Check if we can query digital_signatures with signer_id
    console.log('\n✍️ Testing digital_signatures query...');
    const signaturesResult = await pool.query(`
      SELECT id, report_id, signer_id, signed_at 
      FROM digital_signatures 
      LIMIT 3
    `);
    console.log(`✅ Found ${signaturesResult.rows.length} signatures with signer_id column`);
    
    // Test 3: Check if we can query report_exports with export_format
    console.log('\n📊 Testing report_exports query...');
    const exportsResult = await pool.query(`
      SELECT id, report_id, export_format, exported_at 
      FROM report_exports 
      LIMIT 3
    `);
    console.log(`✅ Found ${exportsResult.rows.length} exports with export_format column`);
    
    // Test 4: Try to insert a test document to make sure all columns work
    console.log('\n➕ Testing document insertion...');
    const testUserId = '00356a1b-6e08-44b8-8499-a4491d14e988'; // Your user ID
    const testProjectId = 'c93009f3-0e7a-4272-9327-afcfa68ba503'; // A project ID from logs
    
    const insertResult = await pool.query(`
      INSERT INTO repository_files (
        project_id, filename, original_filename, file_name, file_path, file_type, 
        file_size, content_hash, uploaded_by, description, tags, 
        uploaded_at, last_modified, is_active
      )
      VALUES ($1, $2, $2, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW(), true)
      RETURNING id, uploaded_at
    `, [
      testProjectId,
      'test_document.pdf',
      '/uploads/test_document.pdf',
      'application/pdf',
      1024,
      'test_hash_123',
      testUserId,
      'Test document for schema validation',
      '["test"]'
    ]);
    
    console.log(`✅ Successfully inserted test document with ID: ${insertResult.rows[0].id}`);
    console.log(`   📅 uploaded_at: ${insertResult.rows[0].uploaded_at}`);
    
    // Clean up test document
    await pool.query('DELETE FROM repository_files WHERE id = $1', [insertResult.rows[0].id]);
    console.log('🧹 Cleaned up test document');
    
    console.log('\n🎉 All database fixes are working correctly!');
    
  } catch (error) {
    console.error('❌ Error testing database fixes:', error.message);
  } finally {
    await pool.end();
  }
}

testDatabaseFixes();
