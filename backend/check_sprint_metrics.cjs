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

async function checkAndFixSprintMetrics() {
  try {
    console.log('🔍 Checking sprint_metrics table structure...');
    
    // Check current columns
    const columnsResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sprint_metrics' 
      ORDER BY column_name
    `);
    
    console.log('Current columns:');
    columnsResult.rows.forEach(row => {
      console.log(`  - ${row.column_name} (${row.data_type})`);
    });
    
    // Check if planned_points exists
    const plannedPointsExists = columnsResult.rows.some(row => row.column_name === 'planned_points');
    
    if (!plannedPointsExists) {
      console.log('❌ planned_points column missing - adding it...');
      
      // Add the missing column
      await pool.query(`
        ALTER TABLE sprint_metrics 
        ADD COLUMN planned_points INTEGER DEFAULT 0
      `);
      
      console.log('✅ planned_points column added successfully!');
    } else {
      console.log('✅ planned_points column already exists');
    }
    
    // Verify the fix
    const verifyResult = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'sprint_metrics' AND column_name = 'planned_points'
    `);
    
    if (verifyResult.rows.length > 0) {
      console.log('✅ Verification successful - planned_points column exists!');
      console.log(`   Type: ${verifyResult.rows[0].data_type}`);
    } else {
      console.log('❌ Verification failed - column still missing');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkAndFixSprintMetrics();
