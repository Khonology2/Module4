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

async function fixDatabaseSchema() {
  try {
    console.log('🔧 Fixing database schema issues...');
    
    // Fix 1: Add missing columns to digital_signatures table
    console.log('\n📝 Fixing digital_signatures table...');
    
    const signatureColumns = [
      { name: 'signer_role', type: 'TEXT', default: 'deliveryLead' },
      { name: 'is_valid', type: 'BOOLEAN', default: true },
      { name: 'signature_type', type: 'TEXT', default: 'manual' },
      { name: 'signature_hash', type: 'TEXT', default: null }
    ];
    
    for (const column of signatureColumns) {
      try {
        const checkResult = await pool.query(`
          SELECT 1 FROM information_schema.columns 
          WHERE table_name = 'digital_signatures' 
          AND column_name = $1
        `, [column.name]);
        
        if (checkResult.rows.length === 0) {
          console.log(`   ➕ Adding column: ${column.name} (${column.type})`);
          await pool.query(`
            ALTER TABLE digital_signatures 
            ADD COLUMN ${column.name} ${column.type} ${column.default !== null ? `DEFAULT ${column.default}` : ''}
          `);
        } else {
          console.log(`   ✅ Column already exists: ${column.name}`);
        }
      } catch (error) {
        console.error(`   ❌ Error adding column ${column.name}:`, error.message);
      }
    }
    
    // Fix 2: Add missing column to report_exports table
    console.log('\n📊 Fixing report_exports table...');
    
    try {
      const checkResult = await pool.query(`
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'report_exports' 
        AND column_name = 'export_format'
      `);
      
      if (checkResult.rows.length === 0) {
        console.log('   ➕ Adding column: export_format (VARCHAR(50) DEFAULT pdf)');
        await pool.query(`
          ALTER TABLE report_exports 
          ADD COLUMN export_format VARCHAR(50) DEFAULT 'pdf'
        `);
        console.log('   ✅ Successfully added export_format column');
      } else {
        console.log('   ✅ export_format column already exists');
      }
    } catch (error) {
      console.error('   ❌ Error adding export_format column:', error.message);
    }
    
    // Show final table structures
    console.log('\n📋 Final table structures:');
    
    const tables = ['digital_signatures', 'report_exports'];
    for (const table of tables) {
      const result = await pool.query(`
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns 
        WHERE table_name = $1
        ORDER BY ordinal_position
      `, [table]);
      
      console.log(`\n${table.toUpperCase()} columns:`);
      result.rows.forEach(col => {
        console.log(`   ${col.column_name}: ${col.data_type} (${col.is_nullable})`);
      });
    }
    
    console.log('\n✅ Database schema fixes completed!');
    
  } catch (error) {
    console.error('❌ Error fixing database schema:', error.message);
  } finally {
    await pool.end();
  }
}

fixDatabaseSchema();
