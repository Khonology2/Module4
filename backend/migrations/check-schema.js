#!/usr/bin/env node

/**
 * Check Database Schema for Release Readiness
 * Check the actual database schema to fix column issues
 * Usage: node migrations/check-schema.js
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

async function checkSchema() {
  console.log('🔍 Checking Database Schema...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    const client = await pool.connect();
    
    console.log('🔍 Checking deliverables table structure...');
    
    const deliverableSchema = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'deliverables' 
      ORDER BY ordinal_position
    `);
    
    console.log('📋 Deliverables table columns:');
    deliverableSchema.rows.forEach((col, index) => {
      console.log(`${index + 1}. ${col.column_name} (${col.data_type}) - Nullable: ${col.is_nullable}`);
    });
    
    console.log('');
    console.log('🔍 Checking release_readiness_checks table structure...');
    
    try {
      const readinessSchema = await client.query(`
        SELECT column_name, data_type, is_nullable 
        FROM information_schema.columns 
        WHERE table_name = 'release_readiness_checks' 
        ORDER BY ordinal_position
      `);
      
      console.log('📋 Release readiness checks table columns:');
      readinessSchema.rows.forEach((col, index) => {
        console.log(`${index + 1}. ${col.column_name} (${col.data_type}) - Nullable: ${col.is_nullable}`);
      });
    } catch (error) {
      console.log('ℹ️  release_readiness_checks table does not exist');
    }
    
    console.log('');
    console.log('🔍 Testing deliverables query with correct columns...');
    
    const testQuery = await client.query(`
      SELECT COUNT(*) as count 
      FROM deliverables 
      LIMIT 1
    `);
    
    const deliverableCount = parseInt(testQuery.rows[0].count);
    console.log(`📋 Deliverables found: ${deliverableCount}`);
    
    console.log('');
    console.log('🔍 Checking sample deliverable data...');
    
    const sampleQuery = await client.query(`
      SELECT id, title, description, status, priority 
      FROM deliverables 
      LIMIT 3
    `);
    
    console.log('📋 Sample deliverables:');
    sampleQuery.rows.forEach((deliverable, index) => {
      console.log(`${index + 1}. ${deliverable.title} - Status: ${deliverable.status} - Priority: ${deliverable.priority}`);
    });
    
    client.release();
    
  } catch (error) {
    console.error('❌ Error checking schema:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the check
checkSchema().catch(console.error);
