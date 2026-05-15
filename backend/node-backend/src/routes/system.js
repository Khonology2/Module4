"use strict";

const express = require('express');
const { Sequelize, Op } = require('sequelize');
const fs = require('fs');
const path = require('path');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { sequelize, User, Project, Sprint, Deliverable, AuditLog, Notification } = require('../models');
const { QueryTypes } = require('sequelize');
const analyticsService = require('../services/analyticsService');
const { loggingService } = require('../services/loggingService');
const schedulerService = require('../services/schedulerService');
const socketService = require('../services/socketService');

const router = express.Router();

// System settings storage (in-memory for now, could be moved to database)
let systemSettings = {
  maintenanceMode: false,
  maintenanceMessage: "System is under maintenance. Please try again later.",
  allowNewRegistrations: true,
  maxFileUploadSize: 50, // MB
  sessionTimeout: 24, // hours
  backupRetentionDays: 30,
  systemNotifications: true,
  performanceMonitoring: true,
  auditLogRetentionDays: 90
};

// Get system settings (admin only)
router.get('/settings', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    res.status(200).json({
      status: 'success',
      settings: systemSettings,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('System settings error:', error);
    res.status(500).json({
      error: 'Failed to get system settings',
      details: error.message
    });
  }
});

// Simulate pending approval reminder for reports (admin, delivery lead, or client reviewer)
router.post('/simulate-report-reminder', authenticateToken, requireRole(['system_admin', 'delivery_lead', 'client_reviewer']), async (req, res) => {
  console.log('📧 simulate-report-reminder endpoint called!');
  console.log('📧 Request body:', req.body);
  console.log('📧 Request user:', req.user);
  try {
    const { reportId, force, recipientRole, recipientId } = req.body || {};

    // Find target reports
    let reports = [];
    if (reportId) {
      reports = await sequelize.query(
        "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE id = $1",
        { bind: [reportId], type: QueryTypes.SELECT }
      );
    } else {
      reports = await sequelize.query(
        "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status IN ('submitted','under_review','change_requested','pending')",
        { type: QueryTypes.SELECT }
      );
      if ((!reports || reports.length === 0) && force) {
        reports = await sequelize.query(
          "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status NOT IN ('approved','rejected')",
          { type: QueryTypes.SELECT }
        );
      }
    }

    if (!reports || reports.length === 0) {
      const signoffs = await sequelize.query(
        "SELECT s.id, d.created_by, s.decision as status, s.comments as content, COALESCE(s.reviewed_at, s.submitted_at, NOW()) as updated_at FROM signoffs s LEFT JOIN deliverables d ON d.id = s.entity_id WHERE s.entity_type IN ('deliverable','sprint') AND (s.decision IS NULL OR s.decision IN ('pending','submitted','under_review','change_requested')) ORDER BY COALESCE(s.reviewed_at, s.submitted_at, NOW()) DESC",
        { type: QueryTypes.SELECT }
      );
      reports = (signoffs || []).map((s) => ({
        id: s.id,
        created_by: s.created_by,
        status: s.status || 'submitted',
        content: typeof s.content === 'string' ? (() => { try { return JSON.parse(s.content); } catch { return {}; } })() : (s.content || {}),
        updated_at: s.updated_at,
      }));
      if (!reports || reports.length === 0) {
        const deliverables = await Deliverable.findAll({
          where: { status: { [Op.notIn]: ['approved', 'rejected'] } },
          order: [['created_at', 'DESC']],
          limit: 50,
        });
        reports = (deliverables || []).map((d) => ({
          id: d.id,
          created_by: d.created_by,
          status: d.status || 'pending',
          content: { reportTitle: d.title || 'Deliverable', reportContent: d.description || '' },
          updated_at: d.updated_at || d.created_at,
        }));
        if (!reports || reports.length === 0) {
          return res.status(404).json({ success: false, error: 'No reports found to remind' });
        }
      }
    }

    let recipients = [];
    
    if (recipientId) {
      // If a specific user ID is provided, target only that user
      // We check if the user exists and is active
      const user = await User.findOne({ where: { id: recipientId, is_active: true } });
      if (user) {
        recipients = [user];
      }
    } else {
      // Fallback to role-based logic if no specific user is targeted
      const roleKey = String(recipientRole || '').toLowerCase();
      if (roleKey === 'client_reviewer') {
        recipients = await User.findAll({ where: { role: { [Op.in]: ['clientReviewer', 'ClientReviewer', 'clientreviewer'] }, is_active: true } });
      } else if (roleKey === 'system_admin') {
        recipients = await User.findAll({ where: { role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'systemadmin'] }, is_active: true } });
      } else if (roleKey === 'delivery_lead') {
        recipients = await User.findAll({ where: { role: { [Op.in]: ['deliveryLead', 'DeliveryLead', 'deliverylead'] }, is_active: true } });
      } else {
        const clientReviewers = await User.findAll({ where: { role: { [Op.in]: ['clientReviewer', 'ClientReviewer', 'clientreviewer'] }, is_active: true } });
        recipients = clientReviewers;
        if (!recipients || recipients.length === 0) {
          const deliveryLeads = await User.findAll({ where: { role: { [Op.in]: ['deliveryLead', 'DeliveryLead', 'deliverylead'] }, is_active: true } });
          const admins = await User.findAll({ where: { role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'systemadmin'] }, is_active: true } });
          recipients = [...deliveryLeads, ...admins];
        }
      }
    }

    if (!recipients || recipients.length === 0) {
      return res.status(400).json({ success: false, error: 'No active recipients found' });
    }

    let createdCount = 0;
    for (const report of reports) {
      const content = typeof report.content === 'string' ? (() => { try { return JSON.parse(report.content); } catch { return {}; } })() : (report.content || {});
      const title = content.reportTitle || content.report_title || 'Sign-Off Report';

      // Skip non-due unless forced
      const ageMs = Date.now() - new Date(report.updated_at || Date.now()).getTime();
      const oneDayMs = 24 * 60 * 60 * 1000;
      if (!force && ageMs < oneDayMs && report.status !== 'submitted') continue;

      const notifications = recipients.map((client) => ({
        recipient_id: client.id,
        sender_id: (report.created_by && typeof report.created_by === 'string' && /^[0-9a-fA-F-]{36}$/.test(report.created_by)) ? report.created_by : null,
        type: 'approval',
        message: `Reminder: Please review and approve or request changes for "${title}"`,
        payload: {
          report_id: report.id,
          report_title: title,
          action_url: `/enhanced-client-review/${report.id}`,
        },
        is_read: false,
        created_at: new Date(),
      }));

      await Notification.bulkCreate(notifications);
      
      // Send real-time notifications
      for (const notification of notifications) {
        if (socketService && typeof socketService.sendToUser === 'function') {
          socketService.sendToUser(notification.recipient_id, 'notification_received', notification);
        }
      }

      createdCount += notifications.length;
    }

    return res.json({ success: true, created_notifications: createdCount });
  } catch (error) {
    console.error('Error simulating report reminder:', error);
    if (error.stack) console.error(error.stack);
    res.status(500).json({ success: false, error: 'Failed to simulate report reminder', details: error && error.message ? error.message : undefined });
  }
});

// Dev-only: simulate report reminder without authentication
router.post('/dev/simulate-report-reminder', async (req, res) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ success: false, error: 'Disabled in production' });
    }
    const { reportId, force } = req.body || {};

    let reports = [];
    if (reportId) {
      reports = await sequelize.query(
        "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE id = $1",
        { bind: [reportId], type: QueryTypes.SELECT }
      );
    } else {
      reports = await sequelize.query(
        "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status IN ('submitted','under_review','change_requested','pending')",
        { type: QueryTypes.SELECT }
      );
      if ((!reports || reports.length === 0) && force) {
        reports = await sequelize.query(
          "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status NOT IN ('approved','rejected')",
          { type: QueryTypes.SELECT }
        );
      }
    }
    if (!reports || reports.length === 0) {
      const signoffs = await sequelize.query(
        "SELECT s.id, d.created_by, s.decision as status, s.comments as content, COALESCE(s.reviewed_at, s.submitted_at, NOW()) as updated_at FROM signoffs s LEFT JOIN deliverables d ON d.id = s.entity_id WHERE s.entity_type IN ('deliverable','sprint') AND (s.decision IS NULL OR s.decision IN ('pending','submitted','under_review','change_requested')) ORDER BY COALESCE(s.reviewed_at, s.submitted_at, NOW()) DESC",
        { type: QueryTypes.SELECT }
      );
      reports = (signoffs || []).map((s) => ({
        id: s.id,
        created_by: s.created_by,
        status: s.status || 'submitted',
        content: typeof s.content === 'string' ? (() => { try { return JSON.parse(s.content); } catch { return {}; } })() : (s.content || {}),
        updated_at: s.updated_at,
      }));
      if (!reports || reports.length === 0) {
        const deliverables = await Deliverable.findAll({
          where: { status: { [Op.notIn]: ['approved', 'rejected'] } },
          order: [['created_at', 'DESC']],
          limit: 50,
        });
        reports = (deliverables || []).map((d) => ({
          id: d.id,
          created_by: d.created_by,
          status: d.status || 'pending',
          content: { reportTitle: d.title || 'Deliverable', reportContent: d.description || '' },
          updated_at: d.updated_at || d.created_at,
        }));
      }
    }

    const clientReviewers = await User.findAll({ where: { role: { [Op.in]: ['clientReviewer', 'ClientReviewer', 'clientreviewer'] }, is_active: true } });
    let recipients = clientReviewers;
    if (!recipients || recipients.length === 0) {
      const deliveryLeads = await User.findAll({ where: { role: { [Op.in]: ['deliveryLead', 'DeliveryLead', 'deliverylead'] }, is_active: true } });
      const admins = await User.findAll({ where: { role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'systemadmin'] }, is_active: true } });
      recipients = [...deliveryLeads, ...admins];
    }
    let createdCount = 0;
    for (const report of reports) {
      const content = typeof report.content === 'string' ? (() => { try { return JSON.parse(report.content); } catch { return {}; } })() : (report.content || {});
      const title = content.reportTitle || content.report_title || 'Sign-Off Report';
      const notifications = recipients.map((client) => ({
        recipient_id: client.id,
        sender_id: (report.created_by && typeof report.created_by === 'string' && /^[0-9a-fA-F-]{36}$/.test(report.created_by)) ? report.created_by : null,
        type: 'approval',
        message: `Reminder: Please review and approve or request changes for "${title}"`,
        payload: {
          report_id: report.id,
          report_title: title,
          action_url: `/enhanced-client-review/${report.id}`,
        },
        is_read: false,
        created_at: new Date(),
      }));
      await Notification.bulkCreate(notifications);
      createdCount += notifications.length;
    }
    return res.json({ success: true, created_notifications: createdCount });
  } catch (error) {
    console.error('Error simulating report reminder (dev):', error);
    res.status(500).json({ success: false, error: 'Failed to simulate report reminder', details: error && error.message ? error.message : undefined });
  }
});

router.get('/dev/recent-notifications', authenticateToken, async (req, res) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ success: false, error: 'Disabled in production' });
    }
    const { limit = 20 } = req.query;
    const rows = await Notification.findAll({ where: { recipient_id: req.user.id }, order: [['created_at', 'DESC']], limit: parseInt(limit) });
    res.json({ success: true, data: rows });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to load notifications', details: error && error.message ? error.message : undefined });
  }
});

// Admin: Backfill user null fields (dev utility)
router.post('/dev/backfill-users', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const users = await User.findAll();
    let updated = 0;
    for (const u of users) {
      const email = u.email || '';
      const namePart = typeof email === 'string' ? email.split('@')[0] : '';
      const splitName = namePart.includes('.') ? namePart.split('.') : [];
      const first = u.first_name || (splitName[0] ? splitName[0] : namePart) || null;
      const last = u.last_name || (splitName[1] ? splitName[1] : '') || null;
      const isActive = (u.is_active === true) ? true : true;
      const status = u.status || (isActive ? 'active' : null);
      const lastLogin = u.last_login || u.updated_at || null;
      const createdAt = u.created_at || (u.updated_at ? u.updated_at : new Date());
      const updates = {};
      if (!u.first_name && first) updates.first_name = first;
      if (!u.last_name && last) updates.last_name = last;
      if (u.is_active !== true) updates.is_active = true;
      if (!u.status && status) updates.status = status;
      if (!u.last_login && lastLogin) updates.last_login = lastLogin;
      if (!u.created_at && createdAt) updates.created_at = createdAt;
      if (Object.keys(updates).length > 0) {
        await u.update(updates);
        updated++;
      }
    }
    return res.json({ success: true, updated_count: updated });
  } catch (error) {
    console.error('Backfill users error:', error);
    return res.status(500).json({ success: false, error: 'Failed to backfill users' });
  }
});

// Update system settings (admin only)
router.put('/settings', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const updates = req.body;
    
    // Validate updates
    const validSettings = Object.keys(systemSettings);
    const invalidKeys = Object.keys(updates).filter(key => !validSettings.includes(key));
    
    if (invalidKeys.length > 0) {
      return res.status(400).json({
        error: 'Invalid settings',
        details: `Invalid setting keys: ${invalidKeys.join(', ')}`
      });
    }
    
    // Update settings
    systemSettings = { ...systemSettings, ...updates };
    
    // Log the change
    await AuditLog.logChange({
      userId: req.user.id,
      action: 'system_settings_update',
      entityType: 'system',
      entityId: 'global',
      oldValues: {},
      newValues: updates,
      description: `System settings updated by ${req.user.email}`
    });
    
    res.status(200).json({
      status: 'success',
      message: 'System settings updated successfully',
      settings: systemSettings,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('System settings update error:', error);
    res.status(500).json({
      error: 'Failed to update system settings',
      details: error.message
    });
  }
});

// Create system backup (admin only)
router.post('/backup', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(__dirname, '..', '..', 'backups');
    const backupFile = path.join(backupDir, `backup-${timestamp}.sql`);
    const metadataFile = path.join(backupDir, `backup-${timestamp}.json`);
    
    // Create backups directory if it doesn't exist
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir, { recursive: true });
    }
    
    // Get database configuration from environment
    const dbConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_NAME || 'flow_space',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres'
    };
    
    // Create backup metadata
    const backupData = {
      timestamp: new Date().toISOString(),
      createdBy: req.user.email,
      userId: req.user.id,
      database: dbConfig.database,
      tables: {
        users: await User.count(),
        projects: await Project.count(),
        sprints: await Sprint.count(),
        deliverables: await Deliverable.count(),
        auditLogs: await AuditLog.count()
      },
      settings: systemSettings,
      dbConfig: {
        host: dbConfig.host,
        port: dbConfig.port,
        database: dbConfig.database,
        user: dbConfig.user
      }
    };
    
    // Use pg_dump for PostgreSQL backup
    const { exec } = require('child_process');
    const pgDumpCommand = `pg_dump -h ${dbConfig.host} -p ${dbConfig.port} -U ${dbConfig.user} -d ${dbConfig.database} -F c -f "${backupFile}"`;
    
    // Set PGPASSWORD environment variable for authentication
    const env = { ...process.env, PGPASSWORD: dbConfig.password };
    
    exec(pgDumpCommand, { env }, async (error, stdout, stderr) => {
      if (error) {
        console.error('pg_dump error:', error);
        console.error('stderr:', stderr);
        
        // Fallback to metadata-only backup if pg_dump fails
        console.log('Falling back to metadata-only backup');
        fs.writeFileSync(metadataFile, JSON.stringify(backupData, null, 2));
        
        // Log the backup creation (metadata only)
        await AuditLog.logChange({
          userId: req.user.id,
          action: 'system_backup_created_metadata',
          entityType: 'system',
          entityId: 'backup',
          oldValues: {},
          newValues: { backupFile: metadataFile, ...backupData },
          description: `System metadata backup created (pg_dump failed) by ${req.user.email}: ${error.message}`
        });
        
        return res.status(201).json({
          status: 'partial_success',
          message: 'Metadata backup created (database backup failed)',
          backup: {
            filename: `backup-${timestamp}.json`,
            path: metadataFile,
            createdAt: new Date().toISOString(),
            createdBy: req.user.email,
            stats: backupData.tables,
            type: 'metadata_only',
            warning: 'Database backup failed, only metadata saved'
          },
          timestamp: Date.now()
        });
      }
      
      // Write metadata file for successful backup
      fs.writeFileSync(metadataFile, JSON.stringify(backupData, null, 2));
      
      // Get backup file stats
      const stats = fs.statSync(backupFile);
      
      // Log the successful backup creation
      await AuditLog.logChange({
        userId: req.user.id,
        action: 'system_backup_created',
        entityType: 'system',
        entityId: 'backup',
        oldValues: {},
        newValues: { 
          backupFile, 
          metadataFile,
          size: stats.size,
          ...backupData 
        },
        description: `System backup created successfully by ${req.user.email}`
      });
      
      res.status(201).json({
        status: 'success',
        message: 'System backup created successfully',
        backup: {
          filename: `backup-${timestamp}.sql`,
          metadataFilename: `backup-${timestamp}.json`,
          path: backupFile,
          size: stats.size,
          createdAt: new Date().toISOString(),
          createdBy: req.user.email,
          stats: backupData.tables,
          type: 'full_database'
        },
        timestamp: Date.now()
      });
    });
  } catch (error) {
    console.error('Backup creation error:', error);
    res.status(500).json({
      error: 'Failed to create system backup',
      details: error.message
    });
  }
});

// List system backups (admin only)
router.get('/backups', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const backupDir = path.join(__dirname, '..', '..', 'backups');
    
    if (!fs.existsSync(backupDir)) {
      return res.status(200).json({
        status: 'success',
        backups: [],
        count: 0,
        timestamp: Date.now()
      });
    }
    
    const files = fs.readdirSync(backupDir);
    const backups = files
      .filter(file => file.startsWith('backup-') && file.endsWith('.sql'))
      .map(file => {
        const filePath = path.join(backupDir, file);
        const stats = fs.statSync(filePath);
        
        try {
          const content = fs.readFileSync(filePath, 'utf8');
          const data = JSON.parse(content);
          return {
            filename: file,
            size: stats.size,
            createdAt: data.timestamp,
            createdBy: data.createdBy,
            tables: data.tables
          };
        } catch (error) {
          return {
            filename: file,
            size: stats.size,
            createdAt: stats.mtime.toISOString(),
            createdBy: 'unknown',
            tables: {}
          };
        }
      })
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.status(200).json({
      status: 'success',
      backups: backups,
      count: backups.length,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Backup list error:', error);
    res.status(500).json({
      error: 'Failed to list system backups',
      details: error.message
    });
  }
});

// Database table schema introspection (development helper)
router.get('/schema/:table', async (req, res) => {
  try {
    const { table } = req.params;
    const columns = await sequelize.query(
      `SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = :table ORDER BY ordinal_position`,
      { type: QueryTypes.SELECT, replacements: { table } }
    );
    res.status(200).json({ success: true, table, columns });
  } catch (error) {
    console.error('Schema introspection error:', error);
    res.status(500).json({ success: false, error: 'Failed to introspect schema' });
  }
});

// Fix column type mismatch: sprints.project_id -> UUID
router.post('/schema/sprints/project-id-to-uuid', async (req, res) => {
  try {
    const check = await sequelize.query(
      `SELECT data_type FROM information_schema.columns WHERE table_name = 'sprints' AND column_name = 'project_id'`,
      { type: QueryTypes.SELECT }
    );
    const currentType = (check[0] && check[0].data_type) || null;
    if (currentType === 'uuid') {
      return res.status(200).json({ success: true, message: 'Column already UUID' });
    }
    await sequelize.query(`ALTER TABLE sprints DROP COLUMN IF EXISTS project_id`);
    await sequelize.query(`ALTER TABLE sprints ADD COLUMN project_id uuid`);
    res.status(200).json({ success: true, message: 'sprints.project_id recreated as uuid' });
  } catch (error) {
    console.error('Column type fix error:', error);
    res.status(500).json({ success: false, error: 'Failed to alter column type', details: error.message });
  }
});

// Restore system from backup (admin only)
router.post('/restore', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const { filename } = req.body;
    
    if (!filename) {
      return res.status(400).json({
        error: 'Backup filename required',
        details: 'Please provide a backup filename to restore from'
      });
    }
    
    const backupDir = path.join(__dirname, '..', '..', 'backups');
    const backupFile = path.join(backupDir, filename);
    
    if (!fs.existsSync(backupFile)) {
      return res.status(404).json({
        error: 'Backup not found',
        details: `Backup file ${filename} does not exist`
      });
    }
    
    // Check if this is a metadata-only backup
    const isMetadataOnly = filename.endsWith('.json');
    
    if (isMetadataOnly) {
      return res.status(400).json({
        error: 'Cannot restore from metadata-only backup',
        details: 'This backup contains only metadata. Please use a full database backup file (.sql) for restoration.'
      });
    }
    
    // Read metadata file if it exists
    let backupData = {};
    const metadataFile = path.join(backupDir, filename.replace('.sql', '.json'));
    if (fs.existsSync(metadataFile)) {
      try {
        const metadataContent = fs.readFileSync(metadataFile, 'utf8');
        backupData = JSON.parse(metadataContent);
      } catch (error) {
        console.warn('Failed to read metadata file:', error);
      }
    }
    
    // Get database configuration from environment
    const dbConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_NAME || 'flow_space',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres'
    };
    
    // Use pg_restore for PostgreSQL restore
    const { exec } = require('child_process');
    
    // First, terminate all connections to the database
    const terminateConnectionsCommand = `psql -h ${dbConfig.host} -p ${dbConfig.port} -U ${dbConfig.user} -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${dbConfig.database}' AND pid <> pg_backend_pid();"`;
    
    // Then restore the database using pg_restore
    const restoreCommand = `pg_restore -h ${dbConfig.host} -p ${dbConfig.port} -U ${dbConfig.user} -d ${dbConfig.database} -c "${backupFile}"`;
    
    // Set PGPASSWORD environment variable for authentication
    const env = { ...process.env, PGPASSWORD: dbConfig.password };
    
    // Log the restore operation attempt
    await AuditLog.logChange({
      userId: req.user.id,
      action: 'system_restore_attempted',
      entityType: 'system',
      entityId: 'backup',
      oldValues: {},
      newValues: { filename, backupData },
      description: `System restore initiated from backup ${filename} by ${req.user.email}`
    });
    
    // Step 1: Terminate existing connections
    exec(terminateConnectionsCommand, { env }, async (error, stdout, stderr) => {
      if (error) {
        console.warn('Failed to terminate connections (may be normal if no connections):', error);
      }
      
      // Step 2: Restore the database
      exec(restoreCommand, { env }, async (error, stdout, stderr) => {
        if (error) {
          console.error('pg_restore error:', error);
          console.error('stderr:', stderr);
          
          // Log the restore failure
          await AuditLog.logChange({
            userId: req.user.id,
            action: 'system_restore_failed',
            entityType: 'system',
            entityId: 'backup',
            oldValues: {},
            newValues: { filename, error: error.message },
            description: `System restore failed from backup ${filename} by ${req.user.email}: ${error.message}`
          });
          
          return res.status(500).json({
            error: 'Failed to restore system',
            details: error.message,
            stderr: stderr
          });
        }
        
        // Log the successful restore
        await AuditLog.logChange({
          userId: req.user.id,
          action: 'system_restore_completed',
          entityType: 'system',
          entityId: 'backup',
          oldValues: {},
          newValues: { filename, ...backupData },
          description: `System restored successfully from backup ${filename} by ${req.user.email}`
        });
        
        res.status(200).json({
          status: 'success',
          message: 'System restored successfully',
          backup: {
            filename: filename,
            createdAt: backupData.timestamp || new Date().toISOString(),
            createdBy: backupData.createdBy || 'unknown',
            stats: backupData.tables || {},
            type: 'full_database'
          },
          timestamp: Date.now()
        });
      });
    });
  } catch (error) {
    console.error('Restore error:', error);
    res.status(500).json({
      error: 'Failed to restore system',
      details: error.message
    });
  }
});

// Toggle maintenance mode (admin only)
router.post('/maintenance', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const { enabled, message } = req.body;
    
    const oldMaintenanceMode = systemSettings.maintenanceMode;
    systemSettings.maintenanceMode = enabled !== undefined ? enabled : !systemSettings.maintenanceMode;
    
    if (message) {
      systemSettings.maintenanceMessage = message;
    }
    
    // Log the change
    await AuditLog.logChange({
      userId: req.user.id,
      action: 'maintenance_mode_toggle',
      entityType: 'system',
      entityId: 'maintenance',
      oldValues: { maintenanceMode: oldMaintenanceMode },
      newValues: { maintenanceMode: systemSettings.maintenanceMode, message: systemSettings.maintenanceMessage },
      description: `Maintenance mode ${systemSettings.maintenanceMode ? 'enabled' : 'disabled'} by ${req.user.email}`
    });
    
    res.status(200).json({
      status: 'success',
      message: `Maintenance mode ${systemSettings.maintenanceMode ? 'enabled' : 'disabled'}`,
      maintenanceMode: systemSettings.maintenanceMode,
      maintenanceMessage: systemSettings.maintenanceMessage,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Maintenance mode error:', error);
    res.status(500).json({
      error: 'Failed to toggle maintenance mode',
      details: error.message
    });
  }
});

// Get system statistics (admin only)
router.get('/stats', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    const [userCount, projectCount, sprintCount, deliverableCount, auditLogCount] = await Promise.all([
      User.count(),
      Project.count(),
      Sprint.count(),
      Deliverable.count(),
      AuditLog.count()
    ]);
    
    const systemMetrics = await analyticsService.getMetrics('performance');
    
    res.status(200).json({
      status: 'success',
      statistics: {
        users: userCount,
        projects: projectCount,
        sprints: sprintCount,
        deliverables: deliverableCount,
        auditLogs: auditLogCount,
        totalEntities: userCount + projectCount + sprintCount + deliverableCount + auditLogCount
      },
      system: systemMetrics,
      settings: systemSettings,
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('System stats error:', error);
    res.status(500).json({
      error: 'Failed to get system statistics',
      details: error.message
    });
  }
});

// Clear system cache (admin only)
router.post('/cache/clear', authenticateToken, requireRole(['system_admin']), async (req, res) => {
  try {
    // Clear analytics cache
    analyticsService.clearCache();
    
    // Log the cache clearance
    await AuditLog.logChange({
      userId: req.user.id,
      action: 'system_cache_cleared',
      entityType: 'system',
      entityId: 'cache',
      oldValues: {},
      newValues: { clearedAt: new Date().toISOString() },
      description: `System cache cleared by ${req.user.email}`
    });
    
    res.status(200).json({
      status: 'success',
      message: 'System cache cleared successfully',
      timestamp: Date.now()
    });
  } catch (error) {
    console.error('Cache clearance error:', error);
    res.status(500).json({
      error: 'Failed to clear system cache',
      details: error.message
    });
  }
});

// Trigger Escalation and Reminders Manually
router.post('/trigger-escalation', authenticateToken, requireRole(['system_admin', 'delivery_lead']), async (req, res) => {
  try {
    const { force } = req.body; // Pass force=true to bypass duplicate checks
    const results = await schedulerService.runScheduledTasks({ force });
    res.json({
      success: true,
      message: 'Scheduled tasks triggered manually',
      results
    });
  } catch (error) {
    console.error('Error triggering escalation manually:', error);
    res.status(500).json({ error: 'Failed to trigger escalation' });
  }
});

module.exports = router;
