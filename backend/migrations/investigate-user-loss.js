#!/usr/bin/env node

/**
 * Investigate User Data Loss
 * Check what happened to the original users
 * Usage: node migrations/investigate-user-loss.js
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

async function investigateUserLoss() {
  console.log('🔍 Investigating User Data Loss...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    const client = await pool.connect();
    
    // Check current users
    const currentUsers = await client.query(`
      SELECT id, email, name, role, is_active, email_verified, created_at
      FROM users 
      ORDER BY created_at DESC
    `);
    
    console.log(`📋 Current Users: ${currentUsers.rows.length}`);
    if (currentUsers.rows.length > 0) {
      currentUsers.rows.forEach((user, index) => {
        console.log(`${index + 1}. 📧 ${user.email}`);
        console.log(`   👤 ${user.name || 'No name'}`);
        console.log(`   🔐 Role: ${user.role}`);
        console.log(`   📅 Created: ${user.created_at}`);
        console.log('');
      });
    }
    
    // Check for any audit logs that might show previous users
    console.log('🔍 Checking audit logs for previous user activity...');
    const auditLogs = await client.query(`
      SELECT DISTINCT user_id, action, created_at
      FROM audit_logs 
      WHERE user_id IS NOT NULL
      ORDER BY created_at DESC
      LIMIT 10
    `);
    
    console.log(`📋 Audit Log Entries: ${auditLogs.rows.length}`);
    auditLogs.rows.forEach((log, index) => {
      console.log(`${index + 1.} 👤 User ID: ${log.user_id}`);
      console.log(`   🔄 Action: ${log.action}`);
      console.log(`   📅 Date: ${log.created_at}`);
      console.log('');
    });
    
    // Check for any project activity that might indicate previous users
    console.log('🔍 Checking project activity...');
    let projectActivity = { rows: [] };
    try {
      projectActivity = await client.query(`
        SELECT DISTINCT created_by, COUNT(*) as project_count
        FROM projects 
        WHERE created_by IS NOT NULL
        GROUP BY created_by
      `);
      
      console.log(`📋 Project Activity Records: ${projectActivity.rows.length}`);
      projectActivity.rows.forEach((activity, index) => {
        console.log(`${index + 1.} 👤 Creator: ${activity.created_by}`);
        console.log(`   📁 Projects: ${activity.project_count}`);
        console.log('');
      });
    } catch (error) {
      console.log('ℹ️  No project activity found or tables not accessible');
    }
    
    // Check for any deliverable activity
    console.log('🔍 Checking deliverable activity...');
    let deliverableActivity = { rows: [] };
    try {
      deliverableActivity = await client.query(`
        SELECT DISTINCT created_by, assigned_to, COUNT(*) as deliverable_count
        FROM deliverables 
        WHERE created_by IS NOT NULL OR assigned_to IS NOT NULL
        GROUP BY created_by, assigned_to
      `);
      
      console.log(`📋 Deliverable Activity Records: ${deliverableActivity.rows.length}`);
      deliverableActivity.rows.forEach((activity, index) => {
        console.log(`${index + 1.} 👤 Creator: ${activity.created_by}`);
        console.log(`   👤 Assigned: ${activity.assigned_to}`);
        console.log(`   📋 Deliverables: ${activity.deliverable_count}`);
        console.log('');
      });
    } catch (error) {
      console.log('ℹ️  No deliverable activity found or tables not accessible');
    }
    
    // Check if there are any user sessions (might show previous users)
    console.log('🔍 Checking user sessions...');
    const userSessions = await client.query(`
      SELECT DISTINCT user_id, created_at, expires_at
      FROM user_sessions 
      WHERE user_id IS NOT NULL
      ORDER BY created_at DESC
      LIMIT 10
    `);
    
    console.log(`📋 User Sessions: ${userSessions.rows.length}`);
    userSessions.rows.forEach((session, index) => {
      console.log(`${index + 1.} 👤 User ID: ${session.user_id}`);
      console.log(`   📅 Created: ${session.created_at}`);
      console.log(`   ⏰ Expires: ${session.expires_at}`);
      console.log('');
    });
    
    // Look for any notifications (might show previous users)
    console.log('🔍 Checking notifications...');
    const notifications = await client.query(`
      SELECT DISTINCT user_id, title, created_at
      FROM notifications 
      WHERE user_id IS NOT NULL
      ORDER BY created_at DESC
      LIMIT 10
    `);
    
    console.log(`📋 Notifications: ${notifications.rows.length}`);
    notifications.rows.forEach((notif, index) => {
      console.log(`${index + 1.} 👤 User ID: ${notif.user_id}`);
      console.log(`   📧 Title: ${notif.title}`);
      console.log(`   📅 Created: ${notif.created_at}`);
      console.log('');
    });
    
    // Try to find user IDs from activity and see if they exist in users table
    console.log('🔍 Cross-referencing activity with user table...');
    
    const allUserIds = new Set();
    
    // Collect user IDs from all activity tables
    auditLogs.rows.forEach(log => log.user_id && allUserIds.add(log.user_id));
    projectActivity.rows.forEach(activity => {
      activity.created_by && allUserIds.add(activity.created_by);
    });
    deliverableActivity.rows.forEach(activity => {
      activity.created_by && allUserIds.add(activity.created_by);
      activity.assigned_to && allUserIds.add(activity.assigned_to);
    });
    userSessions.rows.forEach(session => session.user_id && allUserIds.add(session.user_id));
    notifications.rows.forEach(notif => notif.user_id && allUserIds.add(notif.user_id));
    
    console.log(`🔍 Found ${allUserIds.size} unique user IDs from activity...`);
    
    // Check which of these user IDs actually exist in the users table
    const missingUsers = [];
    const existingUsers = [];
    
    for (const userId of allUserIds) {
      const userCheck = await client.query('SELECT email, name FROM users WHERE id = $1', [userId]);
      if (userCheck.rows.length === 0) {
        missingUsers.push(userId);
      } else {
        existingUsers.push({ id: userId, ...userCheck.rows[0] });
      }
    }
    
    console.log(`❌ Missing Users (found in activity but not in users table): ${missingUsers.length}`);
    console.log(`✅ Existing Users (found in both): ${existingUsers.length}`);
    
    if (missingUsers.length > 0) {
      console.log('');
      console.log('🚨 CRITICAL ISSUE DETECTED!');
      console.log('🔍 Found user IDs in activity tables but corresponding users are missing from users table!');
      console.log('');
      console.log('📋 Missing User IDs:');
      missingUsers.forEach((userId, index) => {
        console.log(`${index + 1}. 👤 ${userId}`);
      });
      
      console.log('');
      console.log('💡 Possible Causes:');
      console.log('  1. Users table was truncated or dropped during migration');
      console.log('  2. Database backup/restore process failed');
      console.log('  3. Migration script accidentally deleted users');
      console.log('  4. Database was reset instead of updated');
      
      console.log('');
      console.log('🔧 Recovery Options:');
      console.log('  1. Check if there\'s a recent database backup');
      console.log('  2. Recreate users from activity data (if possible)');
      console.log('  3. Contact Render support for database backups');
      
    } else {
      console.log('✅ All user IDs from activity exist in users table');
    }
    
    client.release();
    
  } catch (error) {
    console.error('❌ Error investigating user loss:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the investigation
investigateUserLoss().catch(console.error);
