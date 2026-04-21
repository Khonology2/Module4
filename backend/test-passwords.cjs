const { Pool } = require('pg');

// Common PostgreSQL passwords to test
const passwords = ['postgres', 'password', '123456', 'admin', 'root', '', 'flow123'];

async function testPassword(password) {
  console.log(`\n🔍 Testing password: "${password}"`);
  const pool = new Pool({
    user: 'postgres',
    password: password,
    host: 'localhost',
    database: 'flow_space',
    port: 5432,
  });

  try {
    await pool.connect();
    const result = await pool.query('SELECT COUNT(*) FROM users');
    console.log(`✅ Success! Found ${result.rows[0].count} users`);
    await pool.end();
    return true;
  } catch (error) {
    console.log(`❌ Failed: ${error.message}`);
    await pool.end();
    return false;
  }
}

async function testAllPasswords() {
  console.log('🔍 Testing common PostgreSQL passwords...\n');
  
  for (const password of passwords) {
    const success = await testPassword(password);
    if (success) {
      console.log(`\n🎯 CORRECT PASSWORD: "${password}"`);
      return password;
    }
  }
  
  console.log('\n❌ No working password found');
  return null;
}

testAllPasswords();
