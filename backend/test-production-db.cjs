// Test production backend database connection
const { Pool } = require('pg');

// Production backend configuration
const productionConfig = {
  host: 'backend-532p.onrender.com',
  port: 5432,
  database: 'flow_space',
  user: 'postgres',
  password: 'postgres', // This might need to be changed
  ssl: {
    rejectUnauthorized: false
  }
};

async function testProductionDB() {
  console.log('🔍 Testing production database connection...');
  console.log(`Host: ${productionConfig.host}`);
  console.log(`Database: ${productionConfig.database}`);
  console.log(`User: ${productionConfig.user}`);
  
  const pool = new Pool(productionConfig);
  
  try {
    await pool.connect();
    console.log('✅ Connected to production database!');
    
    // Check users table
    const result = await pool.query('SELECT COUNT(*) FROM users');
    console.log(`📊 Users in production database: ${result.rows[0].count}`);
    
    // Check specific user
    const userResult = await pool.query('SELECT email, is_active FROM users WHERE email = $1 LIMIT 1', ['gatesofgift@gmail.com']);
    
    if (userResult.rows.length > 0) {
      const user = userResult.rows[0];
      console.log(`👤 Found user: ${user.email}`);
      console.log(`   Active: ${user.is_active}`);
    } else {
      console.log('❌ User not found in production database');
    }
    
    await pool.end();
    return true;
  } catch (error) {
    console.error('❌ Production database connection failed:', error.message);
    await pool.end();
    return false;
  }
}

testProductionDB();
