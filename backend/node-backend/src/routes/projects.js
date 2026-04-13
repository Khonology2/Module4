const express = require('express');
const router = express.Router();
const { Project, Sprint, AuditLog, User, ProjectMember, Notification, sequelize } = require('../models');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { Op, QueryTypes } = require('sequelize');
const { carryOverOverdueDeliverablesForProject } = require('../services/sprintCarryOverService');

/** Inserts into legacy `notifications` (user_id + title + message + type); DB has no recipient_id/payload. */
async function insertLegacyNotification({ userId, title, message, type }) {
  await sequelize.query(
    `INSERT INTO notifications (id, user_id, title, message, type, is_read, created_at)
     VALUES (gen_random_uuid(), :userId, :title, :message, :type, false, NOW())`,
    { replacements: { userId, title, message, type } },
  );
}

/**
 * @route GET /api/projects
 * @desc Get all projects visible to the user (owner or member) with pagination
 * @access Private
 */
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { skip = 0, limit = 100 } = req.query;
    const userId = req.user.id;

    // 1. Find all projects where user is a member
    const memberProjects = await ProjectMember.findAll({
      where: { user_id: userId },
      attributes: ['project_id']
    });
    
    const memberProjectIds = memberProjects.map(mp => mp.project_id);

    // Check if user is admin
    console.log(`[DEBUG] GET /api/projects - User: ${req.user.email}, Role: '${req.user.role}'`);
    
    // Normalize role for comparison: remove spaces, lowercase
    const normalizedRole = String(req.user.role || '').toLowerCase().replace(/[\s_-]+/g, '');
    const isAdmin = ['admin', 'systemadmin'].includes(normalizedRole);
    
    console.log(`[DEBUG] Is Admin: ${isAdmin} (normalized: '${normalizedRole}')`);

    // 2. Find projects where user is owner OR member OR creator (safety net)
    // If admin, show all projects
    const whereClause = isAdmin ? {} : {
      [Op.or]: [
        { owner_id: userId },
        { created_by: userId },
        { id: { [Op.in]: memberProjectIds } }
      ]
    };

    console.log(`[DEBUG] Where Clause: ${JSON.stringify(whereClause)}`);

    const projects = await Project.findAll({
      where: whereClause,
      offset: parseInt(skip),
      limit: parseInt(limit),
      order: [['created_at', 'DESC']],
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'first_name', 'last_name', 'email'],
          required: false,
        },
      ],
    });
    
    res.json({
      success: true,
      data: projects
    });
  } catch (error) {
    console.error('Error fetching projects:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route GET /api/projects/:id
 * @desc Get a specific project by ID
 * @access Public
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    console.log(`🔍 Fetching project details for ID: ${id}`);
    
    const project = await Project.findByPk(id, {
      include: [
        {
          model: User,
          as: 'owner',
          attributes: ['id', 'first_name', 'last_name', 'email']
        },
        {
          model: ProjectMember,
          as: 'members',
          include: [
            {
              model: User,
              as: 'user',
              attributes: ['id', 'first_name', 'last_name', 'email']
            }
          ]
        }
      ]
    });
    
    console.log(`📊 Raw project data:`, JSON.stringify(project?.toJSON(), null, 2));
    
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    // Transform for frontend compatibility
    const projectJSON = project.toJSON();
    
    console.log(`👥 Members found: ${projectJSON.members?.length || 0}`);
    
    // Fallback: If no members from associations, manually query them
    if (!projectJSON.members || projectJSON.members.length === 0) {
      console.log(`🔄 No members from associations, manually querying...`);
      try {
        const manualMembers = await sequelize.query(`
          SELECT 
            pm.id,
            pm.project_id,
            pm.user_id,
            pm.role,
            pm.added_at,
            u.first_name,
            u.last_name,
            u.email
          FROM project_members pm
          LEFT JOIN users u ON pm.user_id = u.id
          WHERE pm.project_id = :projectId
          ORDER BY pm.role, u.first_name
        `, {
          replacements: { projectId: id },
          type: QueryTypes.SELECT
        });
        
        console.log(`🔍 Manual query found ${manualMembers.length} members`);
        
        projectJSON.members = manualMembers.map(m => ({
          userId: m.user_id,
          userName: `${m.first_name || ''} ${m.last_name || ''}`.trim() || 'Unknown',
          userEmail: m.email || '',
          role: m.role,
          assignedAt: m.added_at
        }));
        
        console.log(`✅ Added ${projectJSON.members.length} members manually`);
      } catch (error) {
        console.error('❌ Error manually querying members:', error);
        projectJSON.members = [];
      }
    } else {
      // Use association data if available
      projectJSON.members = projectJSON.members.map(m => ({
        userId: m.user_id,
        userName: m.user ? `${m.user.first_name} ${m.user.last_name}`.trim() : 'Unknown',
        userEmail: m.user ? m.user.email : '',
        role: m.role,
        assignedAt: m.added_at
      }));
    }

    // Map snake_case to camelCase for critical fields
    projectJSON.ownerId = projectJSON.owner_id;
    projectJSON.clientOwnerName = projectJSON.client_owner_name;
    
    console.log(`📤 Final API response:`, JSON.stringify({
      success: true,
      data: projectJSON
    }, null, 2));
    
    res.json({
      success: true,
      data: projectJSON
    });
  } catch (error) {
    console.error('Error fetching project:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route POST /api/projects
 * @desc Create a new project
 * @access Private
 */
router.post('/', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    // Generate a project key from the name if not provided
    let projectKey = req.body.key;
    if (!projectKey) {
      projectKey = req.body.name
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, '_')
        .substring(0, 20);
    }
    
    // Default owner to creator if not provided
    const ownerId = req.body.ownerId || req.body.owner_id || req.user.id;

    const projectData = {
      ...req.body,
      client_name: req.body.clientName || req.body.client_name,
      client_owner_name: req.body.clientOwnerName || req.body.client_owner_name,
      start_date: req.body.startDate || req.body.start_date,
      end_date: req.body.endDate || req.body.end_date,
      project_type: req.body.projectType || req.body.project_type,
      owner_id: ownerId,
      key: projectKey,
      created_by: req.user.id
    };
    
    // Validate required fields
    const requiredFields = ['name', 'key', 'description', 'client_name', 'start_date', 'end_date', 'owner_id'];
    const missingFields = requiredFields.filter(field => !projectData[field]);
    
    if (missingFields.length > 0) {
      return res.status(400).json({
        success: false,
        error: `Missing required fields: ${missingFields.join(', ')}`
      });
    }
    
    console.log('Creating project with data:', projectData);
    
    const project = await Project.create(projectData);

    // Handle members assignment
    if (req.body.members && Array.isArray(req.body.members)) {
      const membersToCreate = req.body.members.map(member => {
        const userId = typeof member === 'object' ? (member.userId || member.user_id) : member;
        return {
          project_id: project.id,
          user_id: userId,
          role: (typeof member === 'object' && member.role) ? member.role : 'contributor'
        };
      });
      
      // Also add owner as a member with 'owner' role if not already included
      if (projectData.owner_id) {
         const ownerIndex = membersToCreate.findIndex(m => m.user_id === projectData.owner_id);
         if (ownerIndex >= 0) {
           membersToCreate[ownerIndex].role = 'owner';
         } else {
           membersToCreate.push({
             project_id: project.id,
             user_id: projectData.owner_id,
             role: 'owner'
           });
         }
      }

      if (membersToCreate.length > 0) {
        await ProjectMember.bulkCreate(membersToCreate);

        try {
          // Notify all assigned members (including owner) about project assignment
          const uniqueUserIds = [...new Set(membersToCreate.map(m => String(m.user_id)))];
          const users = await User.findAll({
            where: { id: uniqueUserIds },
            attributes: ['id', 'first_name', 'last_name', 'email']
          });

          for (const user of users) {
            await insertLegacyNotification({
              userId: user.id,
              title: 'Project assignment',
              message: `You have been assigned to project "${project.name}".`,
              type: 'project_assignment',
            });
          }
        } catch (notifyErr) {
          console.error('Error sending project assignment notifications:', notifyErr);
        }
      }
    } else if (projectData.owner_id) {
       // If no members list but owner is specified, add owner as member
       await ProjectMember.create({
         project_id: project.id,
         user_id: projectData.owner_id,
         role: 'owner'
       });

       try {
         // Notify owner about project assignment when they are the only member
         const owner = await User.findByPk(projectData.owner_id, {
           attributes: ['id', 'first_name', 'last_name', 'email']
         });
         if (owner) {
           await insertLegacyNotification({
             userId: owner.id,
             title: 'Project assignment',
             message: `You have been assigned as owner of project "${project.name}".`,
             type: 'project_assignment',
           });
         }
       } catch (notifyErr) {
         console.error('Error sending project owner assignment notification:', notifyErr);
       }
    }

    // Notify system admins about project creation (even if they are not assigned)
    try {
      const assigned = await ProjectMember.findAll({
        where: { project_id: project.id },
        attributes: ['user_id']
      });
      const assignedIds = new Set((assigned || []).map((m) => String(m.user_id)));

      const systemAdmins = await User.findAll({
        where: { role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'systemadmin'] } },
        attributes: ['id']
      });

      const adminNotifications = (systemAdmins || [])
        .filter((u) => u && u.id && !assignedIds.has(String(u.id)))
        .map((u) => ({
          recipient_id: u.id,
          sender_id: req.user.id,
          type: 'project_created',
          message: `New project created: "${project.name}".`,
          payload: {
            project_id: project.id,
            project_name: project.name,
            project_key: project.key,
            client_name: project.client_name,
            status: project.status,
            priority: project.priority,
            created_at: new Date(),
            reason: 'project_created'
          },
          is_read: false,
          created_at: new Date()
        }));

      if (adminNotifications.length > 0) {
        await Notification.bulkCreate(adminNotifications);
      }
    } catch (notifyErr) {
      console.error('Error sending system admin project creation notifications:', notifyErr);
    }

    // Log the project creation
    await AuditLog.create({
      user_id: req.user.id,
      user_email: req.user.email,
      user_role: req.user.role || 'unknown',
      action: 'create_project',
      action_category: 'project',
      entity_type: 'project',
      entity_id: project.id,
      entity_name: project.name,
      new_values: projectData,
      endpoint: req.originalUrl,
      http_method: req.method,
      status_code: 201,
      ip_address: req.ip,
      user_agent: req.get('User-Agent'),
      created_at: new Date()
    });
    
    res.status(201).json({
      success: true,
      data: project
    });
  } catch (error) {
    console.error('Error creating project:', error);
    console.error('Error details:', error.message);
    console.error('Error stack:', error.stack);
    
    // Log the failed attempt
    try {
      await AuditLog.create({
        user_id: req.user?.id || null,
        user_email: req.user?.email || null,
        user_role: req.user?.role || 'unknown',
        action: 'create_project_failed',
        action_category: 'project',
        entity_type: 'project',
        new_values: req.body,
        endpoint: req.originalUrl,
        http_method: req.method,
        status_code: 500,
        ip_address: req.ip,
        user_agent: req.get('User-Agent'),
        created_at: new Date()
      });
    } catch (logError) {
      console.error('Failed to log audit entry:', logError);
    }
    
    // Provide more detailed error information
    res.status(500).json({ 
      success: false,
      error: 'Internal server error',
      message: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

/**
 * @route PUT /api/projects/:id
 * @desc Update an existing project
 * @access Private
 */
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    // Explicitly map incoming fields to model attributes
    const updateData = {
      name: req.body.name,
      description: req.body.description,
      client_name: req.body.clientName || req.body.client_name,
      client_owner_name: req.body.clientOwnerName || req.body.client_owner_name,
      start_date: req.body.startDate || req.body.start_date,
      end_date: req.body.endDate || req.body.end_date,
      project_type: req.body.projectType || req.body.project_type,
      status: req.body.status,
      priority: req.body.priority,
      owner_id: req.body.ownerId || req.body.owner_id,
      tags: req.body.tags,
      metadata: req.body.metadata
    };

    // Remove undefined fields to avoid overwriting with null
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });
    
    const project = await Project.findByPk(id);
    
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    // Store old values for audit logging
    const oldValues = project.toJSON();

    // Check for member assignment restriction
    if (req.body.members) {
      // Allow if user is owner OR if user is creator (fallback) OR if user is admin
      const isOwner = project.owner_id && req.user.id === project.owner_id;
      
      // Normalize role for comparison: remove spaces, lowercase
      const normalizedRole = String(req.user.role || '').toLowerCase().replace(/[\s_-]+/g, '');
      const isAdmin = ['admin', 'systemadmin'].includes(normalizedRole);
      
      if (!isOwner && !isAdmin && project.owner_id) { // Only restrict if there IS an owner
         return res.status(403).json({
           success: false,
           error: 'Only the project owner can assign members'
         });
      }
      
      if (Array.isArray(req.body.members)) {
        // Replace members
        // First delete existing (except maybe owner?)
        // For simplicity, we can remove all and re-add.
        await ProjectMember.destroy({
          where: { project_id: id }
        });
        
        const membersToCreate = req.body.members.map(member => {
          const userId = typeof member === 'object' ? (member.userId || member.user_id) : member;
          return {
            project_id: id,
            user_id: userId,
            role: (typeof member === 'object' && member.role) ? member.role : 'contributor'
          };
        });
        
        // Ensure owner is kept as owner
        const currentOwnerId = updateData.owner_id || project.owner_id;
        if (currentOwnerId) {
           const ownerIndex = membersToCreate.findIndex(m => m.user_id === currentOwnerId);
           if (ownerIndex >= 0) {
             membersToCreate[ownerIndex].role = 'owner';
           } else {
             membersToCreate.push({
               project_id: id,
               user_id: currentOwnerId,
               role: 'owner'
             });
           }
        }
        
        if (membersToCreate.length > 0) {
          await ProjectMember.bulkCreate(membersToCreate);

          try {
            // Notify all assigned members (including owner) about project assignment/update
            const uniqueUserIds = [...new Set(membersToCreate.map(m => String(m.user_id)))];
            const users = await User.findAll({
              where: { id: uniqueUserIds },
              attributes: ['id', 'first_name', 'last_name', 'email']
            });

            for (const user of users) {
              await insertLegacyNotification({
                userId: user.id,
                title: 'Project assignment',
                message: `You have been assigned to project "${project.name}".`,
                type: 'project_assignment',
              });
            }
          } catch (notifyErr) {
            console.error('Error sending project assignment notifications on update:', notifyErr);
          }
        }
      }
    }
    
    // Explicitly update the project with mapped data
    await project.update(updateData);

    // Calculate changed fields for audit log
    const changedFields = {};
    Object.keys(updateData).forEach(key => {
      // Handle Date comparison by converting to ISO string
      let oldVal = oldValues[key];
      let newVal = updateData[key];
      
      if (oldVal instanceof Date) oldVal = oldVal.toISOString();
      if (newVal instanceof Date) newVal = newVal.toISOString();
      
      if (oldVal != newVal) {
        changedFields[key] = {
          old: oldValues[key],
          new: updateData[key]
        };
      }
    });

    // Log the project update
    await AuditLog.create({
      user_id: req.user.id,
      user_email: req.user.email,
      user_role: req.user.role || 'unknown',
      action: 'update_project',
      action_category: 'project',
      entity_type: 'project',
      entity_id: project.id,
      entity_name: project.name,
      old_values: oldValues,
      new_values: updateData,
      changed_fields: changedFields,
      endpoint: req.originalUrl,
      http_method: req.method,
      status_code: 200,
      ip_address: req.ip,
      user_agent: req.get('User-Agent'),
      created_at: new Date()
    });
    
    res.json({
      success: true,
      data: project
    });
  } catch (error) {
    console.error('Error updating project:', error);
    
    // Log the failed attempt
    try {
      await AuditLog.create({
        user_id: req.user?.id || null,
        user_email: req.user?.email || null,
        user_role: req.user?.role || 'unknown',
        action: 'update_project_failed',
        action_category: 'project',
        entity_type: 'project',
        entity_id: req.params.id,
        new_values: req.body,
        endpoint: req.originalUrl,
        http_method: req.method,
        status_code: 500,
        ip_address: req.ip,
        user_agent: req.get('User-Agent'),
        created_at: new Date()
      });
    } catch (logError) {
      console.error('Failed to log audit entry:', logError);
    }
    
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route DELETE /api/projects/:id
 * @desc Delete a project
 * @access Private
 */
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const project = await Project.findByPk(id);
    
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }
    
    await project.destroy();
    
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting project:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route GET /api/projects/:projectId/sprints
 * @desc Get all sprints linked to a project
 * @access Public
 */
router.get('/:projectId/sprints', async (req, res) => {
  try {
    const { projectId } = req.params;
    
    // Verify project exists
    const project = await Project.findByPk(projectId);
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    try {
      await carryOverOverdueDeliverablesForProject(projectId);
    } catch (e) {
      console.error('Error carrying over overdue deliverables:', e);
    }

    const sprints = await Sprint.findAll({
      where: { project_id: projectId },
      order: [['created_at', 'DESC']]
    });

    // Calculate progress for each sprint
    const sprintsWithProgress = sprints.map(sprint => {
      const sprintData = sprint.toJSON();
      
      // Calculate progress based on completed vs planned points
      const plannedPoints = sprintData.planned_points || 0;
      const completedPoints = sprintData.completed_points || 0;
      const progress = plannedPoints > 0 ? Math.round((completedPoints / plannedPoints) * 100) : 0;
      
      return {
        ...sprintData,
        progress,
        ticket_count: 0, // TODO: Implement ticket counting when ticket system is integrated
        completed_tickets: completedPoints, // Using completed points as proxy for now
      };
    });
    
    res.json({
      success: true,
      data: sprintsWithProgress
    });
  } catch (error) {
    console.error('Error fetching project sprints:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route GET /api/projects/:projectId/available-sprints
 * @desc Get sprints that can be linked to a project (not already linked)
 * @access Public
 */
router.get('/:projectId/available-sprints', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { search } = req.query;
    
    // Verify project exists
    const project = await Project.findByPk(projectId);
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    const whereClause = {
      [Op.or]: [
        { project_id: null },
        { project_id: { [Op.ne]: projectId } }
      ]
    };

    // Add search filter if provided
    if (search && search.trim()) {
      whereClause.name = {
        [Op.iLike]: `%${search.trim()}%`
      };
    }

    const sprints = await Sprint.findAll({
      where: whereClause,
      order: [['created_at', 'DESC']],
      limit: 50
    });

    // Add progress calculation
    const sprintsWithProgress = sprints.map(sprint => {
      const sprintData = sprint.toJSON();
      const plannedPoints = sprintData.planned_points || 0;
      const completedPoints = sprintData.completed_points || 0;
      const progress = plannedPoints > 0 ? Math.round((completedPoints / plannedPoints) * 100) : 0;
      
      return {
        ...sprintData,
        progress,
        ticket_count: 0,
        completed_tickets: completedPoints,
      };
    });
    
    res.json({
      success: true,
      data: sprintsWithProgress
    });
  } catch (error) {
    console.error('Error fetching available sprints:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route POST /api/projects/:projectId/sprints
 * @desc Link multiple existing sprints to a project
 * @access Private
 */
router.post('/:projectId/sprints', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    const { projectId } = req.params;
    const { sprintIds } = req.body;

    if (!Array.isArray(sprintIds) || sprintIds.length === 0) {
      return res.status(400).json({ 
        success: false,
        error: 'Sprint IDs array is required' 
      });
    }

    // Verify project exists
    const project = await Project.findByPk(projectId);
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    // Update sprints to link them to the project
    const [updatedCount] = await Sprint.update(
      { project_id: projectId },
      {
        where: {
          id: sprintIds,
          [Op.or]: [
            { project_id: null },
            { project_id: { [Op.ne]: projectId } }
          ]
        }
      }
    );

    // TODO: Add audit logging here
    
    res.status(201).json({
      success: true,
      data: {
        message: `Successfully linked ${updatedCount} sprints to project`,
        linked_count: updatedCount
      }
    });
  } catch (error) {
    console.error('Error linking sprints to project:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route POST /api/projects/:projectId/sprints/new
 * @desc Create a new sprint directly linked to a project
 * @access Private
 */
router.post('/:projectId/sprints/new', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    const { projectId } = req.params;
    const { name, description, start_date, end_date } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({ 
        success: false,
        error: 'Sprint name is required' 
      });
    }

    // Verify project exists
    const project = await Project.findByPk(projectId);
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    const sprintData = {
      name: name.trim(),
      description: description?.trim() || null,
      start_date: start_date || null,
      end_date: end_date || null,
      project_id: projectId,
      status: 'draft',
      created_by: req.user?.id || null,
      planned_points: 0,
      completed_points: 0,
      committed_points: 0
    };

    const sprint = await Sprint.create(sprintData);

    // TODO: Add audit logging here
    
    res.status(201).json({
      success: true,
      data: {
        ...sprint.toJSON(),
        progress: 0,
        ticket_count: 0,
        completed_tickets: 0
      }
    });
  } catch (error) {
    console.error('Error creating sprint for project:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

/**
 * @route DELETE /api/projects/:projectId/sprints/:sprintId
 * @desc Unlink a sprint from a project (sets project_id to null)
 * @access Private
 */
router.delete('/:projectId/sprints/:sprintId', authenticateToken, requireRole(['deliveryLead', 'systemAdmin', 'admin']), async (req, res) => {
  try {
    const { projectId, sprintId } = req.params;

    // Verify project exists
    const project = await Project.findByPk(projectId);
    if (!project) {
      return res.status(404).json({ 
        success: false,
        error: 'Project not found' 
      });
    }

    // Find and update the sprint
    const sprint = await Sprint.findOne({
      where: { 
        id: sprintId,
        project_id: projectId 
      }
    });

    if (!sprint) {
      return res.status(404).json({ 
        success: false,
        error: 'Sprint not found in this project' 
      });
    }

    await sprint.update({ project_id: null });

    // TODO: Add audit logging here
    
    res.json({
      success: true,
      data: {
        message: 'Sprint unlinked from project successfully'
      }
    });
  } catch (error) {
    console.error('Error unlinking sprint from project:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

router.post('/:id/remind-owner', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const project = await Project.findByPk(id);

    if (!project) {
      return res.status(404).json({
        success: false,
        error: 'Project not found'
      });
    }

    if (!project.owner_id) {
      return res.status(400).json({
        success: false,
        error: 'Project has no owner assigned'
      });
    }

    const now = new Date();
    const endDate = project.end_date ? new Date(project.end_date) : null;
    const normalizedStatus = String(project.status || '').toLowerCase();

    if (!endDate || endDate > now) {
      return res.status(400).json({
        success: false,
        error: 'Reminder is only available when the project has reached or passed its due date'
      });
    }

    if (['completed', 'cancelled'].includes(normalizedStatus)) {
      return res.status(400).json({
        success: false,
        error: 'Project is already completed or cancelled'
      });
    }

    const userId = req.user.id;
    const normalizedRole = String(req.user.role || '').toLowerCase().replace(/[\s_-]+/g, '');
    const isAdmin = ['admin', 'systemadmin'].includes(normalizedRole);
    const isOwner = project.owner_id && String(project.owner_id) === String(userId);
    const isCreator = project.created_by && String(project.created_by) === String(userId);

    if (!isAdmin && !isOwner && !isCreator) {
      return res.status(403).json({
        success: false,
        error: 'Not authorized to send reminder for this project'
      });
    }

    const body = req.body || {};
    const force = Boolean(body.force);

    if (!force) {
      const recent = await sequelize.query(
        `SELECT id FROM notifications
         WHERE type = 'system'
           AND message LIKE :needle
           AND created_at >= NOW() - INTERVAL '1 day'`,
        {
          type: QueryTypes.SELECT,
          replacements: { needle: `%${String(project.name).replace(/%/g, '')}%` },
        },
      );
      if (recent && recent.length > 0) {
        return res.json({
          success: true,
          data: { message: 'Recent reminder already sent for this project' },
        });
      }
    }

    const reminderTitle = 'Project due-date reminder';
    const reminderMessage = `Reminder: Please review and update project "${project.name}" which is at or past its due date.`;
    await insertLegacyNotification({
      userId: project.owner_id,
      title: reminderTitle,
      message: reminderMessage,
      type: 'system',
    });

    return res.json({
      success: true,
      data: { message: reminderMessage },
    });
  } catch (error) {
    console.error('Error sending project owner reminder:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

module.exports = router;
