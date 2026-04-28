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

async function fixRepositoryFilesTable() {
  try {
    console.log('🔧 Checking repository_files table structure...');
    
    // Get current table structure
    const structureResult = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'repository_files' 
      ORDER BY ordinal_position
    `);
    
    console.log('\n📋 Current repository_files columns:');
    structureResult.rows.forEach(row => {
      console.log(`   ${row.column_name}: ${row.data_type} (${row.is_nullable})`);
    });
    
    // Check if filename column exists
    const filenameCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'repository_files' 
      AND column_name = 'filename'
    `);
    
    if (filenameCheck.rows.length === 0) {
      console.log('\n➕ Adding missing filename column...');
      await pool.query(`ALTER TABLE repository_files ADD COLUMN filename TEXT`);
      console.log('✅ Added filename column to repository_files table');
    } else {
      console.log('ℹ️ filename column already exists in repository_files table');
    }
    
    // Check if original_filename column exists
    const originalFilenameCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'repository_files' 
      AND column_name = 'original_filename'
    `);
    
    if (originalFilenameCheck.rows.length === 0) {
      console.log('➕ Adding missing original_filename column...');
      await pool.query(`ALTER TABLE repository_files ADD COLUMN original_filename TEXT`);
      console.log('✅ Added original_filename column to repository_files table');
    } else {
      console.log('ℹ️ original_filename column already exists in repository_files table');
    }
    
    // Update existing records to have default values for the new columns
    await pool.query(`
      UPDATE repository_files 
      SET filename = file_name, original_filename = file_name 
      WHERE filename IS NULL OR original_filename IS NULL
    `);
    
    console.log('🔄 Updated existing records with default values');
    
    // Test insertion again
    console.log('\n➕ Testing document insertion...');
    const testUserId = '00356a1b-6e08-44b8-8499-a4491d14e988';
    const testProjectId = 'c93009f3-0e7a-4272-9327-afcfa68ba503';
    
    const insertResult = await pool.query(`
      INSERT INTO repository_files (
        name, project_id, filename, original_filename, file_name, file_path, file_type, 
        file_size, content_hash, uploaded_by, description, tags, 
        uploaded_at, last_modified, is_active
      )
      VALUES ($1::text, $2::uuid, $3::text, $3::text, $3::text, $4::text, $5::text, 
      $6::bigint, $7::text, $8::uuid, $9::text, $10::text, 
      NOW(), NOW(), true)
      RETURNING id, uploaded_at, filename, name
    `, [
      'Test Document',
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
    console.log(`   📁 name: ${insertResult.rows[0].name}`);
    console.log(`   📁 filename: ${insertResult.rows[0].filename}`);
    console.log(`   📅 uploaded_at: ${insertResult.rows[0].uploaded_at}`);
    
    // Clean up
    await pool.query('DELETE FROM repository_files WHERE id = $1', [insertResult.rows[0].id]);
    console.log('🧹 Cleaned up test document');
    
    console.log('\n🎉 repository_files table is now fully functional!');
    
  } catch (error) {
    console.error('❌ Error fixing repository_files table:', error.message);
  } finally {
    await pool.end();
  }
}

fixRepositoryFilesTable();
