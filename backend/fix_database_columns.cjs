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

async function fixDatabaseColumns() {
  try {
    console.log('🔧 Fixing database schema issues...');
    
    // Fix 1: Check if uploaded_at column exists in repository_files
    const uploadedAtCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'repository_files' 
      AND column_name = 'uploaded_at'
    `);
    
    if (uploadedAtCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE repository_files ADD COLUMN uploaded_at TIMESTAMP DEFAULT NOW()`);
      console.log('✅ Added uploaded_at column to repository_files table');
    } else {
      console.log('ℹ️ uploaded_at column already exists in repository_files table');
    }
    
    // Fix 2: Check if signer_id column exists in digital_signatures
    const signerIdCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'digital_signatures' 
      AND column_name = 'signer_id'
    `);
    
    if (signerIdCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE digital_signatures ADD COLUMN signer_id UUID REFERENCES users(id)`);
      console.log('✅ Added signer_id column to digital_signatures table');
    } else {
      console.log('ℹ️ signer_id column already exists in digital_signatures table');
    }
    
    // Fix 3: Check if export_format column exists in report_exports
    const exportFormatCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'report_exports' 
      AND column_name = 'export_format'
    `);
    
    if (exportFormatCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE report_exports ADD COLUMN export_format VARCHAR(50) DEFAULT 'pdf'`);
      console.log('✅ Added export_format column to report_exports table');
    } else {
      console.log('ℹ️ export_format column already exists in report_exports table');
    }
    
    // Fix 4: Update any existing records to have default values
    await pool.query(`UPDATE repository_files SET uploaded_at = NOW() WHERE uploaded_at IS NULL`);
    await pool.query(`UPDATE report_exports SET export_format = 'pdf' WHERE export_format IS NULL`);
    
    // Show current table structures
    console.log('\n📋 Current table structures:');
    const tables = await pool.query(`
      SELECT 
        table_name,
        column_name,
        data_type,
        is_nullable
      FROM information_schema.columns 
      WHERE table_name IN ('repository_files', 'digital_signatures', 'report_exports')
      ORDER BY table_name, ordinal_position
    `);
    
    tables.rows.forEach(row => {
      console.log(`   ${row.table_name}.${row.column_name}: ${row.data_type} (${row.is_nullable})`);
    });
    
    console.log('\n🎉 Database schema fixes completed successfully!');
    
  } catch (error) {
    console.error('❌ Error fixing database columns:', error.message);
  } finally {
    await pool.end();
  }
}

fixDatabaseColumns();
