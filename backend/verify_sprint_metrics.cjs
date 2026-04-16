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

async function verifyAllSprintMetricsColumns() {
  try {
    console.log('🔍 Verifying all sprint_metrics columns...');
    
    // All columns that should exist based on server.js code
    const requiredColumns = [
      'planned_points',
      'committed_points', 
      'completed_points',
      'carried_over_points',
      'test_pass_rate',
      'code_coverage',
      'escaped_defects',
      'defects_opened',
      'defects_closed',
      'code_review_completion',
      'documentation_status',
      'uat_notes',
      'uat_pass_rate',
      'risks',
      'blockers',
      'decisions'
    ];
    
    // Check current columns
    const columnsResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sprint_metrics' 
      ORDER BY column_name
    `);
    
    const existingColumns = columnsResult.rows.map(row => row.column_name);
    
    console.log('\n📋 Column verification:');
    let allExist = true;
    
    requiredColumns.forEach(column => {
      const exists = existingColumns.includes(column);
      const status = exists ? '✅' : '❌';
      console.log(`  ${status} ${column}`);
      if (!exists) allExist = false;
    });
    
    if (allExist) {
      console.log('\n🎉 All required sprint_metrics columns exist!');
    } else {
      console.log('\n⚠️  Some columns are missing. Adding them...');
      
      // Add missing columns
      for (const column of requiredColumns) {
        if (!existingColumns.includes(column)) {
          let dataType = 'INTEGER DEFAULT 0';
          
          // Determine appropriate data type
          if (column.includes('rate') || column === 'code_coverage' || column === 'code_review_completion') {
            dataType = 'DECIMAL(5,2) DEFAULT 0.00';
          } else if (column.includes('status') || column === 'uat_notes' || column === 'risks' || column === 'blockers' || column === 'decisions') {
            dataType = 'TEXT DEFAULT \'pending\'';
          }
          
          try {
            await pool.query(`ALTER TABLE sprint_metrics ADD COLUMN ${column} ${dataType}`);
            console.log(`✅ Added ${column}`);
          } catch (error) {
            console.log(`⚠️  Failed to add ${column}: ${error.message}`);
          }
        }
      }
    }
    
    // Final verification
    console.log('\n🔍 Final verification:');
    const finalResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sprint_metrics' 
      AND column_name = ANY($1)
      ORDER BY column_name
    `, [requiredColumns]);
    
    finalResult.rows.forEach(row => {
      console.log(`  ✅ ${row.column_name} (${row.data_type})`);
    });
    
    console.log(`\n✅ sprint_metrics table has ${finalResult.rows.length}/${requiredColumns.length} required columns`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

verifyAllSprintMetricsColumns();
