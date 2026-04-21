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

async function verifySprintsTable() {
  try {
    console.log('🔍 Verifying sprints table...');
    
    // Check if created_by exists
    const columnsResult = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'sprints' AND column_name = 'created_by'
    `);
    
    if (columnsResult.rows.length > 0) {
      console.log('✅ sprints.created_by column exists:');
      console.log(`   - Type: ${columnsResult.rows[0].data_type}`);
      console.log(`   - Nullable: ${columnsResult.rows[0].is_nullable}`);
    } else {
      console.log('❌ sprints.created_by column missing - adding it...');
      
      // Add the missing column
      await pool.query(`
        ALTER TABLE sprints 
        ADD COLUMN created_by TEXT
      `);
      
      console.log('✅ sprints.created_by column added successfully!');
    }
    
    // Check all critical sprint columns
    const requiredColumns = ['id', 'name', 'start_date', 'end_date', 'project_id', 'created_by'];
    const allColumnsResult = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'sprints' 
      AND column_name = ANY($1)
      ORDER BY column_name
    `, [requiredColumns]);
    
    console.log('\n📋 Critical sprints table columns:');
    requiredColumns.forEach(column => {
      const exists = allColumnsResult.rows.some(row => row.column_name === column);
      const status = exists ? '✅' : '❌';
      console.log(`  ${status} ${column}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

verifySprintsTable();
