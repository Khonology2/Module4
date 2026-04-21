#!/usr/bin/env node

/**
 * Check Database Information and Confirm Identity
 * Usage: node migrations/check-database-info.js
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

async function checkDatabaseInfo() {
  console.log('🔍 Checking Database Information...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    const client = await pool.connect();
    
    // Get basic database info
    const dbInfo = await client.query(`
      SELECT 
        current_database() as database_name,
        current_user as current_user,
        version() as version,
        inet_server_addr() as server_ip,
        inet_server_port() as server_port,
        current_timestamp as server_time
    `);
    
    const info = dbInfo.rows[0];
    console.log('📋 Database Information:');
    console.log(`  🗄️  Database: ${info.database_name}`);
    console.log(`  👤 User: ${info.current_user}`);
    console.log(`  🌐 Server: ${info.server_ip}:${info.server_port}`);
    console.log(`  📦 Version: ${info.version.split(',')[0]}`);
    console.log(`  🕐 Server Time: ${info.server_time}`);
    console.log('');
    
    // Check all tables and their creation times
    console.log('🔍 Checking all tables and their sizes...');
    const tablesQuery = await client.query(`
      SELECT 
        table_name,
        table_type,
        (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count,
        pg_size_pretty(pg_total_relation_size(table_name::regclass)) as size
      FROM information_schema.tables t
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);
    
    console.log(`📋 Found ${tablesQuery.rows.length} tables:`);
    tablesQuery.rows.forEach((table, index) => {
      console.log(`${index + 1}. 📋 ${table.table_name} (${table.table_type})`);
      console.log(`   📏 Columns: ${table.column_count}`);
      console.log(`   💾 Size: ${table.size}`);
      console.log('');
    });
    
    // Check when the database was created (if we can find out)
    console.log('🔍 Checking for any data creation timestamps...');
    
    // Check the earliest created_at timestamp across all tables that have it
    const earliestDataQuery = await client.query(`
      SELECT 
        MIN(created_at) as earliest_record,
        MAX(created_at) as latest_record,
        (SELECT COUNT(*) FROM users) as user_count,
        (SELECT COUNT(*) FROM projects) as project_count,
        (SELECT COUNT(*) FROM deliverables) as deliverable_count,
        (SELECT COUNT(*) FROM audit_logs) as audit_count
      FROM (
        SELECT created_at FROM users WHERE created_at IS NOT NULL
        UNION ALL
        SELECT created_at FROM projects WHERE created_at IS NOT NULL
        UNION ALL
        SELECT created_at FROM deliverables WHERE created_at IS NOT NULL
        UNION ALL
        SELECT created_at FROM audit_logs WHERE created_at IS NOT NULL
      ) all_dates
    `);
    
    const dataInfo = earliestDataQuery.rows[0];
    console.log('📊 Data Summary:');
    console.log(`  👥 Users: ${dataInfo.user_count}`);
    console.log(`  📁 Projects: ${dataInfo.project_count}`);
    console.log(`  📋 Deliverables: ${dataInfo.deliverable_count}`);
    console.log(`  📝 Audit Logs: ${dataInfo.audit_count}`);
    
    if (dataInfo.earliest_record) {
      console.log(`  🕐 Earliest Record: ${dataInfo.earliest_record}`);
      console.log(`  🕐 Latest Record: ${dataInfo.latest_record}`);
      
      // Calculate how old the data is
      const now = new Date();
      const earliest = new Date(dataInfo.earliest_record);
      const hoursOld = (now - earliest) / (1000 * 60 * 60);
      
      console.log(`  ⏰ Data Age: ${hoursOld.toFixed(1)} hours old`);
      
      if (hoursOld < 1) {
        console.log('  🚨 WARNING: Database appears to be very recently created/reset!');
      }
    } else {
      console.log('  🚨 WARNING: No data found in any tables!');
    }
    
    console.log('');
    console.log('🔍 Checking for any database creation patterns...');
    
    // Check if there are any sequences (auto-incrementing IDs)
    const sequencesQuery = await client.query(`
      SELECT sequence_name, start_value, last_value
      FROM information_schema.sequences
      WHERE sequence_schema = 'public'
    `);
    
    console.log(`📋 Found ${sequencesQuery.rows.length} sequences:`);
    sequencesQuery.rows.forEach((seq, index) => {
      console.log(`${index + 1}. 🔢 ${seq.sequence_name}`);
      console.log(`   📍 Start: ${seq.start_value}`);
      console.log(`   📍 Last: ${seq.last_value}`);
      console.log('');
    });
    
    // Check database size
    const sizeQuery = await client.query(`
      SELECT pg_size_pretty(pg_database_size(current_database())) as database_size
    `);
    
    console.log(`💾 Database Size: ${sizeQuery.rows[0].database_size}`);
    
    console.log('');
    console.log('🎯 Analysis:');
    console.log('');
    
    if (dataInfo.user_count === 0 && dataInfo.project_count === 0) {
      console.log('❌ CRITICAL FINDING:');
      console.log('   🗄️  This database appears to be completely empty!');
      console.log('   🔄 This suggests either:');
      console.log('     1. This is a brand new database');
      console.log('     2. The original database was wiped/reset');
      console.log('     3. You might be connected to the wrong database');
      console.log('');
      console.log('💡 RECOMMENDATIONS:');
      console.log('   1. Double-check the DATABASE_URL in your Render environment');
      console.log('   2. Check if Render has database backups available');
      console.log('   3. Verify this is the correct database instance');
      console.log('   4. Contact Render support about database restoration');
    } else {
      console.log('✅ Database contains data, but users may have been lost during migration');
    }
    
    client.release();
    
  } catch (error) {
    console.error('❌ Error checking database info:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the check
checkDatabaseInfo().catch(console.error);
