const { Pool } = require('pg');

// Use same configuration as server.js
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/flow_space',
  ssl: false,
});

async function checkLocalUsers() {
  console.log('🔍 Checking local database users...');
  
  try {
    await pool.connect();
    
    // Check all users
    const result = await pool.query('SELECT id, email, first_name, last_name, role, is_active, created_at FROM users ORDER BY created_at DESC');
    
    console.log(`📊 Found ${result.rows.length} users:`);
    result.rows.forEach((user, index) => {
      console.log(`${index + 1}. ${user.email} (${user.role}) - Active: ${user.is_active} - Created: ${user.created_at}`);
    });
    
    await pool.end();
    return true;
  } catch (error) {
    console.error('❌ Error checking users:', error.message);
    await pool.end();
    return false;
  }
}

checkLocalUsers();
