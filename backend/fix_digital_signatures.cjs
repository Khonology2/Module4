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

async function fixDigitalSignaturesTable() {
  try {
    console.log('🔧 Fixing digital_signatures table...');
    
    // Check if signer_role column exists
    const signerRoleCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'digital_signatures' 
      AND column_name = 'signer_role'
    `);
    
    if (signerRoleCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE digital_signatures ADD COLUMN signer_role TEXT`);
      console.log('✅ Added signer_role column to digital_signatures table');
    } else {
      console.log('ℹ️ signer_role column already exists in digital_signatures table');
    }
    
    // Check if is_valid column exists
    const isValidCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'digital_signatures' 
      AND column_name = 'is_valid'
    `);
    
    if (isValidCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE digital_signatures ADD COLUMN is_valid BOOLEAN DEFAULT true`);
      console.log('✅ Added is_valid column to digital_signatures table');
    } else {
      console.log('ℹ️ is_valid column already exists in digital_signatures table');
    }
    
    // Check if signature_type column exists
    const signatureTypeCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'digital_signatures' 
      AND column_name = 'signature_type'
    `);
    
    if (signatureTypeCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE digital_signatures ADD COLUMN signature_type TEXT DEFAULT 'manual'`);
      console.log('✅ Added signature_type column to digital_signatures table');
    } else {
      console.log('ℹ️ signature_type column already exists in digital_signatures table');
    }
    
    // Check if signature_hash column exists
    const signatureHashCheck = await pool.query(`
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'digital_signatures' 
      AND column_name = 'signature_hash'
    `);
    
    if (signatureHashCheck.rows.length === 0) {
      await pool.query(`ALTER TABLE digital_signatures ADD COLUMN signature_hash TEXT`);
      console.log('✅ Added signature_hash column to digital_signatures table');
    } else {
      console.log('ℹ️ signature_hash column already exists in digital_signatures table');
    }
    
    // Update existing records to have default values
    await pool.query(`
      UPDATE digital_signatures 
      SET signer_role = 'deliveryLead', 
          is_valid = true, 
          signature_type = 'manual'
      WHERE signer_role IS NULL OR is_valid IS NULL OR signature_type IS NULL
    `);
    
    console.log('🔄 Updated existing records with default values');
    
    // Show final table structure
    console.log('\n📋 Final digital_signatures table structure:');
    const structureResult = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'digital_signatures'
      ORDER BY ordinal_position
    `);
    
    structureResult.rows.forEach(col => {
      console.log(`   ${col.column_name}: ${col.data_type} (${col.is_nullable})`);
    });
    
    console.log('\n🎉 digital_signatures table is now ready for submit functionality!');
    
  } catch (error) {
    console.error('❌ Error fixing digital_signatures table:', error.message);
  } finally {
    await pool.end();
  }
}

fixDigitalSignaturesTable();
