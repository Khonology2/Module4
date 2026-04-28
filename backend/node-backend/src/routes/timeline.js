const express = require('express');
const { sequelize, User, Project, Sprint, Timeline } = require('../models');
const { Op } = require('sequelize');
const router = express.Router();

// Helper function to prevent duplicate timeline entries
async function preventDuplicateTimelineEntry(entityType, entityId, title, description, startDate, endDate, createdBy, status = 'active', priority = 'medium') {
  try {
    // Check if timeline entry already exists
    const existingEntry = await Timeline.findOne({
      where: {
        entity_type: entityType,
        entity_id: entityId
      }
    });

    if (existingEntry) {
      // Update existing entry
      await existingEntry.update({
        title,
        description,
        start_date: startDate,
        end_date: endDate,
        status,
        priority
      });
      
      console.log(`Timeline entry updated for existing ${entityType}: ${title}`);
      return existingEntry.id;
    } else {
      // Create new entry
      const newEntry = await Timeline.create({
        entity_type: entityType,
        entity_id: entityId,
        title,
        description,
        start_date: startDate,
        end_date: endDate,
        created_by: createdBy,
        status,
        priority,
        tags: [entityType],
        metadata: { created_by: createdBy }
      });
      
      console.log(`Timeline entry created for new ${entityType}: ${title}`);
      return newEntry.id;
    }
  } catch (error) {
    console.error('Error in preventDuplicateTimelineEntry:', error);
    throw error;
  }
}

// Get all timeline events
router.get('/', async (req, res) => {
  try {
    const { 
      start_date, 
      end_date, 
      entity_type, 
      entity_id, 
      limit = 100, 
      offset = 0,
      include_completed = false
    } = req.query;

    // Build WHERE clause
    const whereConditions = {};

    if (start_date) {
      whereConditions.start_date = { [Op.gte]: start_date };
    }

    if (end_date) {
      whereConditions.end_date = { [Op.lte]: end_date };
    }

    if (entity_type) {
      whereConditions.entity_type = entity_type;
    }

    if (entity_id) {
      whereConditions.entity_id = entity_id;
    }

    // Filter out completed projects/sprints unless explicitly requested
    if (include_completed !== 'true') {
      whereConditions.status = { [Op.notIn]: ['completed', 'cancelled'] };
    }

    const events = await Timeline.findAll({
      where: whereConditions,
      order: [['start_date', 'DESC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    // Get total count
    const count = await Timeline.count({
      where: whereConditions
    });

    // Format events for response
    const formattedEvents = events.map(event => ({
      id: event.id,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      title: event.title,
      description: event.description,
      startTime: event.start_date,
      endTime: event.end_date,
      createdBy: event.created_by,
      status: event.status,
      priority: event.priority,
      tags: event.tags,
      metadata: event.metadata,
      createdAt: event.created_at,
      updatedAt: event.updated_at,
      isCompleted: event.status === 'completed'
    }));

    res.json({
      success: true,
      data: formattedEvents,
      count: count,
      filters: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        excludes_completed: include_completed !== 'true'
      }
    });

  } catch (error) {
    console.error('Error fetching timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch timeline events'
    });
  }
});

// Get active timeline events (excluding completed/cancelled)
router.get('/active', async (req, res) => {
  try {
    const { limit = 100, offset = 0 } = req.query;

    const whereConditions = {
      status: { [Op.notIn]: ['completed', 'cancelled'] }
    };

    const events = await Timeline.findAll({
      where: whereConditions,
      order: [['start_date', 'ASC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    // Get total count
    const count = await Timeline.count({
      where: whereConditions
    });

    // Format events for response
    const formattedEvents = events.map(event => ({
      id: event.id,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      title: event.title,
      description: event.description,
      startTime: event.start_date,
      endTime: event.end_date,
      createdBy: event.created_by,
      status: event.status,
      priority: event.priority,
      tags: event.tags,
      metadata: event.metadata,
      createdAt: event.created_at,
      updatedAt: event.updated_at,
      isCompleted: event.status === 'completed'
    }));

    res.json({
      success: true,
      data: formattedEvents,
      count: count,
      filters: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        excludes_completed: true
      },
      last_sync: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error fetching active timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch active timeline events'
    });
  }
});

// Sync all timeline events (for frontend synchronization)
router.get('/sync/all', async (req, res) => {
  try {
    const { include_completed = false, limit = 100, offset = 0 } = req.query;

    const whereConditions = {};
    
    // Filter out completed projects/sprints unless explicitly requested
    if (include_completed !== 'true') {
      whereConditions.status = { [Op.notIn]: ['completed', 'cancelled'] };
    }

    const events = await Timeline.findAll({
      where: whereConditions,
      order: [['start_date', 'ASC']],
      limit: parseInt(limit),
      offset: parseInt(offset)
    });

    // Get total count
    const count = await Timeline.count({
      where: whereConditions
    });

    // Format events for response
    const formattedEvents = events.map(event => ({
      id: event.id,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      title: event.title,
      description: event.description,
      startTime: event.start_date,
      endTime: event.end_date,
      createdBy: event.created_by,
      status: event.status,
      priority: event.priority,
      tags: event.tags,
      metadata: event.metadata,
      createdAt: event.created_at,
      updatedAt: event.updated_at,
      isCompleted: event.status === 'completed'
    }));

    res.json({
      success: true,
      data: formattedEvents,
      count: count,
      filters: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        excludes_completed: include_completed !== 'true'
      },
      last_sync: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error syncing timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to sync timeline events'
    });
  }
});

// Get timeline events for a specific project
router.get('/project/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { include_completed = false } = req.query;

    const whereConditions = { entity_id: projectId };

    if (include_completed !== 'true') {
      whereConditions.status = { [Op.notIn]: ['completed', 'cancelled'] };
    }

    const events = await Timeline.findAll({
      where: whereConditions,
      order: [['start_date', 'ASC']]
    });

    // Format events for response
    const formattedEvents = events.map(event => ({
      id: event.id,
      entity_type: event.entity_type,
      entity_id: event.entity_id,
      title: event.title,
      description: event.description,
      startTime: event.start_date,
      endTime: event.end_date,
      createdBy: event.created_by,
      status: event.status,
      priority: event.priority,
      tags: event.tags,
      metadata: event.metadata,
      createdAt: event.created_at,
      updatedAt: event.updated_at,
      isCompleted: event.status === 'completed'
    }));

    res.json({
      success: true,
      data: formattedEvents,
      count: formattedEvents.length
    });

  } catch (error) {
    console.error('Error fetching project timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch project timeline events'
    });
  }
});

// Create a new timeline event
router.post('/', async (req, res) => {
  try {
    const {
      entity_type,
      entity_id,
      title,
      description,
      start_date,
      end_date,
      created_by,
      status = 'active',
      priority = 'medium',
      tags = [],
      metadata = {}
    } = req.body;

    // Validate required fields
    if (!entity_type || !entity_id || !title || !created_by) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: entity_type, entity_id, title, created_by'
      });
    }

    const newEvent = await Timeline.create({
      entity_type,
      entity_id,
      title,
      description,
      start_date,
      end_date,
      created_by,
      status,
      priority,
      tags,
      metadata
    });

    res.status(201).json({
      success: true,
      data: { id: newEvent.id },
      message: 'Timeline event created successfully'
    });

  } catch (error) {
    console.error('Error creating timeline event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create timeline event'
    });
  }
});

// Update a timeline event
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const event = await Timeline.findByPk(id);

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Timeline event not found'
      });
    }

    const {
      title,
      description,
      start_date,
      end_date,
      status,
      priority,
      tags,
      metadata
    } = req.body;

    const updateData = {};
    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (start_date !== undefined) updateData.start_date = start_date;
    if (end_date !== undefined) updateData.end_date = end_date;
    if (status !== undefined) updateData.status = status;
    if (priority !== undefined) updateData.priority = priority;
    if (tags !== undefined) updateData.tags = tags;
    if (metadata !== undefined) updateData.metadata = metadata;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No valid fields to update'
      });
    }

    await event.update(updateData);

    res.json({
      success: true,
      data: event,
      message: 'Timeline event updated successfully'
    });

  } catch (error) {
    console.error('Error updating timeline event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update timeline event'
    });
  }
});

// Delete a timeline event
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const event = await Timeline.findByPk(id);

    if (!event) {
      return res.status(404).json({
        success: false,
        error: 'Timeline event not found'
      });
    }

    await event.destroy();

    res.json({
      success: true,
      message: 'Timeline event deleted successfully'
    });

  } catch (error) {
    console.error('Error deleting timeline event:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete timeline event'
    });
  }
});

module.exports = router;
