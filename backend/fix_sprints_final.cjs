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

async function fixSprintsTable() {
  try {
    console.log('🔍 Checking sprints table structure...');
    
    // Get all current columns
    const columnsResult = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'sprints' 
      ORDER BY column_name
    `);
    
    console.log('Current columns:');
    columnsResult.rows.forEach(row => {
      console.log(`  - ${row.column_name} (${row.data_type})`);
    });
    
    const existingColumns = columnsResult.rows.map(row => row.column_name);
    
    // Required columns based on server.js code
    const requiredColumns = {
      'description': 'TEXT',
      'status': 'TEXT DEFAULT \'planning\'',
      'created_at': 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()',
      'updated_at': 'TIMESTAMP WITH TIME ZONE DEFAULT NOW()'
    };
    
    console.log('\n📋 Adding missing columns...');
    
    for (const [column, definition] of Object.entries(requiredColumns)) {
      if (!existingColumns.includes(column)) {
        try {
          await pool.query(`ALTER TABLE sprints ADD COLUMN ${column} ${definition}`);
          console.log(`✅ Added ${column} column`);
        } catch (error) {
          console.log(`⚠️  Failed to add ${column}: ${error.message}`);
        }
      } else {
        console.log(`✅ ${column} already exists`);
      }
    }
    
    // Verify final structure
    console.log('\n🔍 Final verification:');
    const finalResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sprints' 
      ORDER BY column_name
    `);
    
    finalResult.rows.forEach(row => {
      console.log(`  ✅ ${row.column_name} (${row.data_type})`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

fixSprintsTable();
