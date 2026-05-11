const express = require('express');
const router = express.Router();
const { AuditLog } = require('../models');

/**
 * @route GET /api/audit
 * @desc Get all audit logs with pagination
 * @access Public
 */
router.get('/', async (req, res) => {
  try {
    const { skip = 0, limit = 100 } = req.query;
    const offset = parseInt(skip);
    const parsedLimit = parseInt(limit);
    
    const auditLogs = await AuditLog.findAll({
      offset: offset,
      limit: parsedLimit,
      order: [['created_at', 'DESC']]
    });
    
    // Get total count for pagination
    const totalCount = await AuditLog.count();
    
    res.json({
      audit_logs: auditLogs,
      items: auditLogs, // For backward compatibility
      logs: auditLogs,  // For backward compatibility
      total: totalCount,
      total_count: totalCount,
      skip: offset,
      limit: parsedLimit,
      has_more: offset + auditLogs.length < totalCount
    });
  } catch (error) {
    console.error('Error fetching audit logs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/audit/entity/:entityType/:entityId
 * @desc Get audit logs for a specific entity
 * @access Public
 */
router.get('/entity/:entityType/:entityId', async (req, res) => {
  try {
    const { entityType, entityId } = req.params;
    const id = typeof entityId === 'string' && entityId.includes(':')
      ? entityId.split(':').pop()
      : entityId;
    if (!id) return res.json([]);
    
    const auditLogs = await AuditLog.findAll({
      where: {
        entity_type: entityType,
        entity_id: id.toString()
      },
      order: [['created_at', 'DESC']]
    });
    
    res.json(auditLogs);
  } catch (error) {
    console.error('Error fetching entity audit logs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/audit
 * @desc Create a new audit log entry
 * @access Private
 */
router.post('/', async (req, res) => {
  try {
    const auditLogData = req.body;
    
    const auditLog = await AuditLog.create(auditLogData);
    
    res.status(201).json(auditLog);
  } catch (error) {
    console.error('Error creating audit log:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/audit/deliverable/:deliverableId
 * @desc Get audit logs for a specific deliverable
 * @access Public
 */
router.get('/deliverable/:deliverableId', async (req, res) => {
  try {
    const { deliverableId } = req.params;
    
    const auditLogs = await AuditLog.findAll({
      where: {
        entity_type: 'deliverable',
        entity_id: deliverableId.toString()
      },
      order: [['created_at', 'DESC']]
    });
    
    res.json(auditLogs);
  } catch (error) {
    console.error('Error fetching deliverable audit logs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/audit/sprint/:sprintId
 * @desc Get audit logs for a specific sprint
 * @access Public
 */
router.get('/sprint/:sprintId', async (req, res) => {
  try {
    const { sprintId } = req.params;
    
    const auditLogs = await AuditLog.findAll({
      where: {
        entity_type: 'sprint',
        entity_id: sprintId.toString()
      },
      order: [['created_at', 'DESC']]
    });
    
    res.json(auditLogs);
  } catch (error) {
    console.error('Error fetching sprint audit logs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/audit/signoff/:signoffId
 * @desc Get audit logs for a specific signoff
 * @access Public
 */
router.get('/signoff/:signoffId', async (req, res) => {
  try {
    const { signoffId } = req.params;
    const id = typeof signoffId === 'string' && signoffId.includes(':')
      ? signoffId.split(':').pop()
      : signoffId;
    if (!id) return res.json([]);
    
    const auditLogs = await AuditLog.findAll({
      where: {
        entity_type: 'signoff',
        entity_id: id.toString()
      },
      order: [['created_at', 'DESC']]
    });
    
    res.json(auditLogs);
  } catch (error) {
    console.error('Error fetching signoff audit logs:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
