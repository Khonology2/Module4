#!/usr/bin/env node

/**
 * Database Migration Runner for Flow-Space
 * Usage: node run-migration.js
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pool from '../dbPool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function runMigration() {
  console.log('🚀 Starting Flow-Space Database Migration...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  try {
    // Test database connection first
    console.log('🔍 Testing database connection...');
    const client = await pool.connect();
    
    const result = await client.query('SELECT current_database(), version()');
    console.log('✅ Connected to database:', result.rows[0].current_database);
    console.log('📋 PostgreSQL version:', result.rows[0].version.split(',')[0]);
    console.log('');

    // Read and execute migration file
    const migrationFile = path.join(__dirname, '001_initial_schema.sql');
    const migrationSQL = fs.readFileSync(migrationFile, 'utf8');

    console.log('📝 Executing migration script...');
    
    // Execute the migration
    await client.query(migrationSQL);
    
    console.log('✅ Migration completed successfully!');
    console.log('');

    // Verify tables were created
    const tablesQuery = `
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `;
    
    const tablesResult = await client.query(tablesQuery);
    console.log('📋 Created tables:');
    tablesResult.rows.forEach(row => {
      console.log(`  ✓ ${row.table_name}`);
    });
    console.log('');

    // Verify indexes
    const indexesQuery = `
      SELECT indexname 
      FROM pg_indexes 
      WHERE schemaname = 'public' 
      ORDER BY indexname
    `;
    
    const indexesResult = await client.query(indexesQuery);
    console.log('🔑 Created indexes:', indexesResult.rows.length);
    
    // Check for admin user
    const adminUserQuery = `
      SELECT email, role, is_active, email_verified 
      FROM users 
      WHERE email = 'admin@flownet.works'
    `;
    
    const adminResult = await client.query(adminUserQuery);
    if (adminResult.rows.length > 0) {
      const admin = adminResult.rows[0];
      console.log('👤 Default admin user created:');
      console.log(`  📧 Email: ${admin.email}`);
      console.log(`  🔐 Role: ${admin.role}`);
      console.log(`  ✅ Active: ${admin.is_active}`);
      console.log(`  📧 Verified: ${admin.email_verified}`);
      console.log('');
      console.log('🔑 Login credentials:');
      console.log('  Email: admin@flownet.works');
      console.log('  Password: admin123');
      console.log('');
      console.log('⚠️  IMPORTANT: Change the default password after first login!');
    }

    client.release();
    
    console.log('🎉 Database migration completed successfully!');
    console.log('🚀 Your Flow-Space application is now ready to use the new database.');
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    console.error('📋 Error details:', error);
    process.exit(1);
  } finally {
    // Close the pool
    await pool.end();
  }
}

// Run the migration
runMigration().catch(console.error);
