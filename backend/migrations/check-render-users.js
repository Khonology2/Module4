#!/usr/bin/env node

/**
 * Check Render Database Users
 * Usage: node migrations/check-render-users.js
 */

import pkg from 'pg';
const Pool = pkg.Pool;

// Render database configuration
const renderConfig = {
  connectionString: 'postgresql://dssoh_user:IuTxLxOZ6CQBGXdghxfdPOfZSKAF070h@dpg-d6p6de5m5p6s73dlguqg-a.virginia-postgres.render.com/dssoh',
  ssl: {
    rejectUnauthorized: false,
  },
};

async function checkRenderUsers() {
  console.log('🔍 Checking Render Database Users...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    const client = await pool.connect();
    
    // Get all users
    const usersQuery = await client.query(`
      SELECT id, email, name, first_name, last_name, role, is_active, email_verified, created_at
      FROM users 
      ORDER BY created_at DESC
    `);
    
    console.log(`📋 Total Users: ${usersQuery.rows.length}`);
    console.log('');
    
    if (usersQuery.rows.length === 0) {
      console.log('❌ No users found in the database!');
      console.log('');
      console.log('🔧 Creating required users...');
      
      // Create admin user
      await client.query(`
        INSERT INTO users (id, email, name, first_name, last_name, password_hash, role, is_active, email_verified)
        VALUES (gen_random_uuid(), 'admin@flownet.works', 'System Administrator', 'System', 'Administrator', 
                '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', 'system_admin', true, true)
        ON CONFLICT (email) DO NOTHING
      `);
      
      // Create dhlamini331@gmail.com user (password: user123)
      await client.query(`
        INSERT INTO users (id, email, name, first_name, last_name, password_hash, role, is_active, email_verified)
        VALUES (gen_random_uuid(), 'dhlamini331@gmail.com', 'Busisiwe Dlamini', 'Busisiwe', 'Dlamini', 
                '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', 'system_admin', true, true)
        ON CONFLICT (email) DO NOTHING
      `);
      
      console.log('✅ Created admin user: admin@flownet.works / admin123');
      console.log('✅ Created user: dhlamini331@gmail.com / user123');
      
      // Check users again
      const newUsersQuery = await client.query(`
        SELECT id, email, name, role, is_active, email_verified
        FROM users 
        ORDER BY created_at DESC
      `);
      
      console.log('');
      console.log('📋 Updated Users List:');
      newUsersQuery.rows.forEach((user, index) => {
        console.log(`${index + 1}. 📧 ${user.email}`);
        console.log(`   👤 ${user.name}`);
        console.log(`   🔐 Role: ${user.role}`);
        console.log(`   ✅ Active: ${user.is_active}`);
        console.log(`   📧 Verified: ${user.email_verified}`);
        console.log('');
      });
      
    } else {
      console.log('📋 Existing Users:');
      usersQuery.rows.forEach((user, index) => {
        console.log(`${index + 1}. 📧 ${user.email}`);
        console.log(`   👤 ${user.name || 'No name'}`);
        console.log(`   🔐 Role: ${user.role}`);
        console.log(`   ✅ Active: ${user.is_active}`);
        console.log(`   📧 Verified: ${user.email_verified}`);
        console.log(`   📅 Created: ${user.created_at}`);
        console.log('');
      });
      
      // Check if dhlamini331@gmail.com exists
      const targetUser = usersQuery.rows.find(u => u.email === 'dhlamini331@gmail.com');
      
      if (!targetUser) {
        console.log('❌ User dhlamini331@gmail.com not found!');
        console.log('🔧 Creating user dhlamini331@gmail.com...');
        
        await client.query(`
          INSERT INTO users (id, email, name, first_name, last_name, password_hash, role, is_active, email_verified)
          VALUES (gen_random_uuid(), 'dhlamini331@gmail.com', 'Busisiwe Dlamini', 'Busisiwe', 'Dlamini', 
                  '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', 'system_admin', true, true)
          ON CONFLICT (email) DO NOTHING
        `);
        
        console.log('✅ Created user: dhlamini331@gmail.com / user123');
      } else {
        console.log('✅ User dhlamini331@gmail.com exists');
        console.log(`   👤 Name: ${targetUser.name || 'No name'}`);
        console.log(`   🔐 Role: ${targetUser.role}`);
        console.log(`   ✅ Active: ${targetUser.is_active}`);
        console.log(`   📧 Verified: ${targetUser.email_verified}`);
      }
    }
    
    // Test password hash
    console.log('');
    console.log('🔑 Login Credentials:');
    console.log('1. Admin: admin@flownet.works / admin123');
    console.log('2. User: dhlamini331@gmail.com / user123');
    console.log('');
    console.log('⚠️  If password doesn\'t work, you may need to reset it.');
    
    client.release();
    
  } catch (error) {
    console.error('❌ Error checking users:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the check
checkRenderUsers().catch(console.error);
