const express = require('express');
const router = express.Router();
const { Deliverable, DeliverableSprint, AuditLog, User, DeliverableArtifact, Project } = require('../models');
const { authenticateToken, requireRole } = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
const fileUploadService = require('../services/fileUploadService');

// Configure multer for file uploads
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB limit
    },
});

const handleMulterSingle = (req, res, next) => {
    upload.single('file')(req, res, (err) => {
        if (err) {
            return res.status(400).json({ error: err.message });
        }
        next();
    });
};

/**
 * @route GET /api/deliverables
 * @desc Get all deliverables with pagination
 * @access Public
 */
router.get('/', async (req, res) => {
  try {
    const { skip = 0, limit = 100, project_id } = req.query;
    const where = {};
    if (project_id) {
      where.project_id = project_id;
    }

    const deliverables = await Deliverable.findAll({
      where,
      offset: parseInt(skip),
      limit: parseInt(limit),
      order: [['created_at', 'DESC']],
      include: [{
        model: User,
        as: 'owner',
        attributes: ['id', 'first_name', 'last_name', 'email', 'role']
      }, {
        association: 'artifacts'
      }]
    });
    
    res.json({ success: true, data: deliverables });
  } catch (error) {
    console.error('Error fetching deliverables:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/deliverables/sprint/:sprintId
 * @desc Get all deliverables for a specific sprint
 * @access Public
 */
router.get('/sprint/:sprintId', async (req, res) => {
  try {
    const { sprintId } = req.params;
    
    const deliverables = await Deliverable.findAll({
      include: [{
        association: 'contributing_sprints',
        where: { id: sprintId },
        through: { attributes: [] } // Exclude junction table attributes
      }],
      order: [['created_at', 'DESC']]
    });
    
    res.json({ success: true, data: deliverables });
  } catch (error) {
    console.error('Error fetching sprint deliverables:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/deliverables/:id
 * @desc Get a specific deliverable by ID
 * @access Public
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const deliverable = await Deliverable.findByPk(id, {
      include: [
        { association: 'contributing_sprints' },
        { association: 'signoffs' },
        { association: 'artifacts' },
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'first_name', 'last_name', 'email']
        }
      ]
    });
    
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }

    // Fetch audit logs separately to avoid integer-uuid join issues
    const auditLogs = await AuditLog.findAll({
      where: {
        entity_type: 'deliverable',
        entity_id: id.toString()
      },
      order: [['created_at', 'DESC']],
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'first_name', 'last_name', 'email', 'role']
      }]
    });

    const deliverableData = deliverable.toJSON();
    deliverableData.audit_logs = auditLogs;
    
    res.json({ success: true, data: deliverableData });
  } catch (error) {
    console.error('Error fetching deliverable:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/:id/overview', async (req, res) => {
  try {
    const { id } = req.params;
    const deliverable = await Deliverable.findByPk(id, {
      include: [
        { association: 'contributing_sprints' },
        { association: 'signoffs' }
      ]
    });
    if (!deliverable) {
      return res.status(404).json({ success: false, error: 'Deliverable not found' });
    }
    const sprints = (deliverable.contributing_sprints || []).map(s => ({ id: s.id, name: s.name, start_date: s.start_date, end_date: s.end_date }));
    const signoffs = (deliverable.signoffs || []).map(s => ({ id: s.id, decision: s.decision, comments: s.comments, reviewed_at: s.reviewed_at }));
    const summary = {
      id: deliverable.id,
      title: deliverable.title || deliverable.name || `Deliverable ${deliverable.id}`,
      description: deliverable.description || '',
      status: deliverable.status || 'pending',
      created_at: deliverable.created_at,
      updated_at: deliverable.updated_at,
      sprints,
      signoffs,
    };
    return res.json({ success: true, data: summary });
  } catch (error) {
    console.error('Error fetching deliverable overview:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @route POST /api/deliverables
 * @desc Create a new deliverable
 * @access Private
 */
router.post(
  '/',
  authenticateToken,
  requireRole(['teamMember', 'deliveryLead', 'systemAdmin', 'admin', 'developer', 'projectManager', 'scrumMaster', 'qaEngineer']),
  async (req, res) => {
  try {
    const { sprintIds, ...deliverableData } = req.body || {};
    
    // Ensure created_by is set to current user if not provided
    if (!deliverableData.created_by && req.user) {
      deliverableData.created_by = req.user.id;
    }

    // Validation: Project must be assigned
    if (!deliverableData.project_id) {
      return res.status(400).json({ error: 'Deliverable must be assigned to a project' });
    }

    // Validation: Owner must be selected before marking as Active (or any non-draft status)
    const activeStatuses = ['active', 'in_progress', 'review', 'in_review', 'completed', 'submitted', 'signed_off', 'approved'];
    if (deliverableData.status && activeStatuses.includes(deliverableData.status.toLowerCase())) {
      if (!deliverableData.owner_id) {
        return res.status(400).json({ error: 'Cannot set status to Active/In Progress without an assigned owner' });
      }
    }

    const deliverable = await Deliverable.create(deliverableData);
    
    // Log creation
    await AuditLog.logChange(req.user, deliverable, 'create', null, deliverableData);

    if (Array.isArray(sprintIds) && sprintIds.length > 0) {
      const ids = sprintIds
        .map((id) => parseInt(id))
        .filter((n) => Number.isFinite(n));
      await Promise.all(
        ids.map((sprintId) =>
          DeliverableSprint.create({ deliverable_id: deliverable.id, sprint_id: sprintId })
        )
      );
    }

    res.status(201).json(deliverable);
  } catch (error) {
    console.error('Error creating deliverable:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PUT /api/deliverables/:id
 * @desc Update an existing deliverable
 * @access Private
 */
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    const deliverable = await Deliverable.findByPk(id);
    
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }

    // Role-based access control for owner assignment
    if (updateData.owner_id && updateData.owner_id !== deliverable.owner_id) {
       const nextOwnerId = String(updateData.owner_id);
       const currentUserId = String(req.user && req.user.id);
       const normalizeRole = (r) => String(r || '').toLowerCase().replace(/[\s_-]+/g, '');
       const role = normalizeRole(req.user && req.user.role);
       const isPrivileged = ['owner', 'admin', 'systemadmin', 'deliverylead', 'projectmanager'].includes(role);
       const isSelfAssign = nextOwnerId && currentUserId && nextOwnerId === currentUserId;
       if (!isPrivileged && !isSelfAssign) {
         return res.status(403).json({ error: 'Only Project Owners/Admins/Delivery Leads can assign deliverable owners (or self-assign)' });
       }
    }

    // Validation: Owner must be selected before marking as Active (or any non-draft status)
    const activeStatuses = ['active', 'in_progress', 'review', 'in_review', 'completed', 'submitted', 'signed_off', 'approved'];
    if (updateData.status && activeStatuses.includes(updateData.status.toLowerCase())) {
      const newOwnerId = updateData.owner_id !== undefined ? updateData.owner_id : deliverable.owner_id;
      if (!newOwnerId) {
        return res.status(400).json({ error: 'Cannot set status to Active/In Progress without an assigned owner' });
      }
    }
    
    const oldValues = deliverable.toJSON();
    await deliverable.update(updateData);
    const newValues = deliverable.toJSON();
    
    // Log update
    await AuditLog.logChange(req.user, deliverable, 'update', oldValues, newValues);
    
    res.json(deliverable);
  } catch (error) {
    console.error('Error updating deliverable:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PUT /api/deliverables/:id/updateStatus
 * @desc Update deliverable status
 * @access Private
 */
router.put('/:id/updateStatus', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const deliverable = await Deliverable.findByPk(id);
    
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }

    // Validation: Owner must be selected before marking as Active (or any non-draft status)
    const activeStatuses = ['active', 'in_progress', 'review', 'in_review', 'completed', 'submitted', 'signed_off', 'approved'];
    if (activeStatuses.includes(status.toLowerCase())) {
      if (!deliverable.owner_id) {
        return res.status(400).json({ error: 'Cannot set status to Active/In Progress/Signed Off without an assigned owner' });
      }
    }
    
    const oldValues = deliverable.toJSON();
    deliverable.status = status;
    await deliverable.save();
    const newValues = deliverable.toJSON();
    
    // Log update
    await AuditLog.logChange(req.user, deliverable, 'status_change', oldValues, newValues);
    
    res.json(deliverable);
  } catch (error) {
    console.error('Error updating deliverable status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/deliverables/:id
 * @desc Delete a deliverable
 * @access Private
 */
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const deliverable = await Deliverable.findByPk(id);
    
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }
    
    const oldValues = deliverable.toJSON();
    await deliverable.destroy();
    
    // Log deletion
    await AuditLog.logChange(req.user, deliverable, 'delete', oldValues, null);
    
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting deliverable:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/deliverables/:id/artifacts
 * @desc Upload an artifact for a deliverable
 * @access Private
 */
router.post('/:id/artifacts', authenticateToken, handleMulterSingle, async (req, res) => {
  try {
    const { id } = req.params;
    
    const deliverable = await Deliverable.findByPk(id);
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }

    if (!req.file) {
      return res.status(400).json({ error: 'No file provided' });
    }

    // RBAC: Team Members can only upload to their own deliverables
    const userRole = req.user.role ? req.user.role.toLowerCase() : '';
    const restrictedRoles = ['team_member', 'teammember', 'developer', 'qa_engineer', 'qaengineer'];
    
    if (restrictedRoles.includes(userRole)) {
      if (!deliverable.owner_id || String(deliverable.owner_id) !== String(req.user.id)) {
        return res.status(403).json({ error: 'You can only upload artifacts to deliverables assigned to you' });
      }
    }

    // Fetch user details for metadata
    const user = await User.findByPk(req.user.id);
    const uploaderName = user ? `${user.first_name} ${user.last_name}` : req.user.email;

    // Upload to storage
    const uploadResult = await fileUploadService.uploadFile(
      req.file,
      `deliverables/${id}`,
      {
        title: req.body.title || req.file.originalname,
        description: req.body.description,
        uploadedBy: req.user.id,
        uploaderName: uploaderName
      }
    );

    // Create DB record
    const artifact = await DeliverableArtifact.create({
      deliverable_id: id,
      filename: uploadResult.filename,
      original_name: uploadResult.originalName,
      file_type: req.file.mimetype,
      file_size: req.file.size,
      url: uploadResult.url,
      uploaded_by: req.user.id,
      uploader_name: uploaderName
    });

    res.status(201).json({ success: true, data: artifact });
  } catch (error) {
    console.error('Error uploading artifact:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/deliverables/:id/artifacts/:artifactId
 * @desc Delete an artifact
 * @access Private
 */
router.delete('/:id/artifacts/:artifactId', authenticateToken, async (req, res) => {
  try {
    const { id, artifactId } = req.params;

    const deliverable = await Deliverable.findByPk(id);
    if (!deliverable) {
      return res.status(404).json({ error: 'Deliverable not found' });
    }

    const artifact = await DeliverableArtifact.findOne({
      where: {
        id: artifactId,
        deliverable_id: id
      }
    });

    if (!artifact) {
      return res.status(404).json({ error: 'Artifact not found' });
    }

    // RBAC: Admin, Deliverable Owner, or Artifact Uploader can delete
    const isOwner = deliverable.owner_id && String(deliverable.owner_id) === String(req.user.id);
    const isUploader = String(artifact.uploaded_by) === String(req.user.id);
    const isAdmin = ['admin', 'systemadmin', 'deliverylead'].includes(req.user.role?.toLowerCase());

    if (!isOwner && !isUploader && !isAdmin) {
      return res.status(403).json({ error: 'Not authorized to delete this artifact' });
    }

    // Delete from storage
    await fileUploadService.deleteFile(artifact.filename, `deliverables/${id}`);

    // Delete from DB
    await artifact.destroy();

    // Log deletion
    await AuditLog.logChange(req.user, deliverable, 'delete_artifact', artifact.toJSON(), null);

    res.status(200).json({ success: true, message: 'Artifact deleted successfully' });
  } catch (error) {
    console.error('Error deleting artifact:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
