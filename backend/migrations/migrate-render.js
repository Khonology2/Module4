#!/usr/bin/env node

/**
 * Render Database Migration Script for Flow-Space
 * Usage: node migrate-render.js
 * This script connects to the Render database and runs migrations
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pkg from 'pg';
const { Pool } = pkg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Render database configuration
const renderConfig = {
  connectionString: 'postgresql://dssoh_user:IuTxLxOZ6CQBGXdghxfdPOfZSKAF070h@dpg-d6p6de5m5p6s73dlguqg-a.virginia-postgres.render.com/dssoh',
  ssl: {
    rejectUnauthorized: false,
  },
};

async function migrateRenderDatabase() {
  console.log('🚀 Starting Flow-Space Render Database Migration...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    // Test database connection first
    console.log('🔍 Testing Render database connection...');
    const client = await pool.connect();
    
    const result = await client.query('SELECT current_database(), version()');
    console.log('✅ Connected to Render database:', result.rows[0].current_database);
    console.log('📋 PostgreSQL version:', result.rows[0].version.split(',')[0]);
    console.log('');

    // Check if tables already exist
    const tablesQuery = `
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `;
    
    const existingTables = await client.query(tablesQuery);
    console.log(`📋 Existing tables: ${existingTables.rows.length}`);
    
    if (existingTables.rows.length > 0) {
      console.log('📋 Tables already exist:');
      existingTables.rows.forEach(row => {
        console.log(`  ✓ ${row.table_name}`);
      });
      console.log('');
      console.log('⚠️  Database appears to be already set up.');
      console.log('🔍 Checking for missing tables...');
    }

    // Read and execute migration file
    const migrationFile = path.join(__dirname, '001_initial_schema.sql');
    const migrationSQL = fs.readFileSync(migrationFile, 'utf8');

    console.log('📝 Executing migration script...');
    
    // Execute the migration
    await client.query(migrationSQL);
    
    console.log('✅ Migration completed successfully!');
    console.log('');

    // Verify tables were created
    const tablesResult = await client.query(tablesQuery);
    console.log(`📋 Total tables after migration: ${tablesResult.rows.length}`);
    console.log('📋 Created/Updated tables:');
    tablesResult.rows.forEach(row => {
      console.log(`  ✓ ${row.table_name}`);
    });
    console.log('');

    // Check for admin user
    const adminUserQuery = `
      SELECT email, role, is_active, email_verified 
      FROM users 
      WHERE email = 'admin@flownet.works'
    `;
    
    const adminResult = await client.query(adminUserQuery);
    if (adminResult.rows.length > 0) {
      const admin = adminResult.rows[0];
      console.log('👤 Default admin user found:');
      console.log(`  📧 Email: ${admin.email}`);
      console.log(`  🔐 Role: ${admin.role}`);
      console.log(`  ✅ Active: ${admin.is_active}`);
      console.log(`  📧 Verified: ${admin.email_verified}`);
      console.log('');
      console.log('🔑 Login credentials for Render app:');
      console.log('  Email: admin@flownet.works');
      console.log('  Password: admin123');
      console.log('');
      console.log('⚠️  IMPORTANT: Change the default password after first login!');
    } else {
      console.log('⚠️  Admin user not found - you may need to create one manually');
    }

    // Test basic functionality
    console.log('');
    console.log('🧪 Testing database functionality...');
    
    // Test user insertion
    const testUser = await client.query(`
      INSERT INTO users (email, first_name, last_name, password_hash, role, is_active, email_verified)
      VALUES ('test@flownet.works', 'Test', 'User', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', 'team_member', true, true)
      ON CONFLICT (email) DO NOTHING
      RETURNING id, email
    `);
    
    if (testUser.rows.length > 0) {
      console.log('✅ Test user creation successful');
    } else {
      console.log('ℹ️  Test user already exists');
    }

    // Test project creation
    const testProject = await client.query(`
      INSERT INTO projects (name, key, description, created_by)
      VALUES ('Test Project', 'TEST-001', 'Migration test project', 
        (SELECT id FROM users WHERE email = 'admin@flownet.works' LIMIT 1))
      ON CONFLICT (key) DO NOTHING
      RETURNING id, name, key
    `);
    
    if (testProject.rows.length > 0) {
      console.log('✅ Test project creation successful');
    } else {
      console.log('ℹ️  Test project already exists');
    }

    client.release();
    
    console.log('');
    console.log('🎉 Render database migration completed successfully!');
    console.log('🚀 Your deployed Flow-Space app is now ready to use the new database!');
    console.log('');
    console.log('📋 Next steps:');
    console.log('  1. Deploy your application to Render');
    console.log('  2. Ensure DATABASE_URL environment variable is set in Render');
    console.log('  3. Test the deployed application');
    console.log('  4. Change the default admin password');
    
  } catch (error) {
    console.error('❌ Render migration failed:', error.message);
    console.error('📋 Error details:', error);
    
    // Provide helpful error messages
    if (error.code === 'ECONNREFUSED') {
      console.log('');
      console.log('💡 Troubleshooting tips:');
      console.log('  • Check if the Render database is running');
      console.log('  • Verify the connection string');
      console.log('  • Ensure firewall allows database connections');
    } else if (error.code === '28P01') {
      console.log('');
      console.log('💡 Troubleshooting tips:');
      console.log('  • Verify database username and password');
      console.log('  • Check if user has proper permissions');
    } else if (error.code === '3D000') {
      console.log('');
      console.log('💡 Troubleshooting tips:');
      console.log('  • Verify database name exists');
      console.log('  • Check if database was created properly');
    }
    
    process.exit(1);
  } finally {
    // Close the pool
    await pool.end();
  }
}

// Run the migration
migrateRenderDatabase().catch(console.error);
