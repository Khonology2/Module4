require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'flow_space',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
  // Use DATABASE_URL if available (preferred approach)
  connectionString: process.env.DATABASE_URL,
});

async function runActivityLogFix() {
  try {
    console.log('🚀 Creating activity_log table...');
    
    const sqlFilePath = path.join(__dirname, 'fix_activity_log.sql');
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf8');
    
    await pool.query(sqlContent);
    console.log('✅ activity_log table created successfully!');
    
    // Verify
    const result = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name = 'activity_log'
    `);
    
    if (result.rows.length > 0) {
      console.log('✅ activity_log table verified!');
    } else {
      console.log('❌ activity_log table not found');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

runActivityLogFix();
