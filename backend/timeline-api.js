import express from 'express';
import pool from './dbPool.js';

const router = express.Router();

// Get all timeline events
router.get('/', async (req, res) => {
  try {
    const { 
      start_date, 
      end_date, 
      entity_type, 
      entity_id, 
      limit = 100, 
      offset = 0 
    } = req.query;

    let query = `
      SELECT 
        id,
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
        metadata,
        created_at,
        updated_at
      FROM timeline
      WHERE 1=1
    `;

    const params = [];
    let paramIndex = 1;

    if (start_date) {
      query += ` AND start_date >= $${paramIndex++}`;
      params.push(start_date);
    }

    if (end_date) {
      query += ` AND end_date <= $${paramIndex++}`;
      params.push(end_date);
    }

    if (entity_type) {
      query += ` AND entity_type = $${paramIndex++}`;
      params.push(entity_type);
    }

    if (entity_id) {
      query += ` AND entity_id = $${paramIndex++}`;
      params.push(entity_id);
    }

    query += ` ORDER BY start_date ASC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('Error fetching timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch timeline events'
    });
  }
});

// Get timeline events by project
router.get('/project/:projectId', async (req, res) => {
  try {
    const { projectId } = req.params;
    const { start_date, end_date } = req.query;

    let query = `
      SELECT 
        id,
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
        metadata,
        created_at,
        updated_at
      FROM timeline
      WHERE (entity_id = $1 AND entity_type = 'project')
         OR (entity_id IN (
           SELECT id FROM sprints WHERE project_id = $1
         ) AND entity_type = 'sprint')
    `;

    const params = [projectId];
    let paramIndex = 2;

    if (start_date) {
      query += ` AND start_date >= $${paramIndex++}`;
      params.push(start_date);
    }

    if (end_date) {
      query += ` AND end_date <= $${paramIndex++}`;
      params.push(end_date);
    }

    query += ` ORDER BY start_date ASC`;

    const result = await pool.query(query, params);

    res.json({
      success: true,
      data: result.rows,
      count: result.rows.length
    });

  } catch (error) {
    console.error('Error fetching project timeline:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch project timeline'
    });
  }
});

// Create timeline event
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

    if (!entity_type || !entity_id || !title || !created_by) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: entity_type, entity_id, title, created_by'
      });
    }

    const query = `
      INSERT INTO timeline (
        entity_type, entity_id, title, description, 
        start_date, end_date, created_by, status, 
        priority, tags, metadata
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *
    `;

    const values = [
      entity_type,
      entity_id,
      title,
      description,
      start_date,
      end_date,
      created_by,
      status,
      priority,
      JSON.stringify(tags),
      JSON.stringify(metadata)
    ];

    const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      data: result.rows[0],
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

// Update timeline event
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
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

    const query = `
      UPDATE timeline 
      SET 
        title = COALESCE($1, title),
        description = COALESCE($2, description),
        start_date = COALESCE($3, start_date),
        end_date = COALESCE($4, end_date),
        status = COALESCE($5, status),
        priority = COALESCE($6, priority),
        tags = COALESCE($7, tags),
        metadata = COALESCE($8, metadata),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $9
      RETURNING *
    `;

    const values = [
      title,
      description,
      start_date,
      end_date,
      status,
      priority,
      tags ? JSON.stringify(tags) : undefined,
      metadata ? JSON.stringify(metadata) : undefined,
      id
    ];

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Timeline event not found'
      });
    }

    res.json({
      success: true,
      data: result.rows[0],
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

// Delete timeline event
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const query = 'DELETE FROM timeline WHERE id = $1 RETURNING *';
    const result = await pool.query(query, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Timeline event not found'
      });
    }

    res.json({
      success: true,
      data: result.rows[0],
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

// Sync timeline events for frontend
router.get('/sync/all', async (req, res) => {
  try {
    const { last_sync, include_completed = false } = req.query;
    
    let query = `
      SELECT 
        t.id,
        t.entity_type,
        t.entity_id,
        t.title,
        t.description,
        t.start_date,
        t.end_date,
        t.created_by,
        t.status,
        t.priority,
        t.tags,
        t.metadata,
        t.created_at,
        t.updated_at,
        -- Get project/sprint status for filtering
        CASE 
          WHEN t.entity_type = 'project' THEN p.status
          WHEN t.entity_type = 'sprint' THEN s.status
          ELSE null
        END as entity_status
      FROM timeline t
      LEFT JOIN projects p ON t.entity_type = 'project' AND t.entity_id = p.id
      LEFT JOIN sprints s ON t.entity_type = 'sprint' AND t.entity_id = s.id
      WHERE 1=1
    `;

    const params = [];
    let paramIndex = 1;

    if (last_sync) {
      query += ` AND t.updated_at > $${paramIndex++}`;
      params.push(last_sync);
    }

    // Filter out completed projects/sprints unless explicitly requested
    if (include_completed !== 'true') {
      query += ` AND (
        (t.entity_type = 'project' AND (p.status IS NULL OR p.status NOT IN ('completed', 'cancelled'))) OR
        (t.entity_type = 'sprint' AND (s.status IS NULL OR s.status NOT IN ('completed', 'cancelled'))) OR
        (t.entity_type NOT IN ('project', 'sprint'))
      )`;
    }

    query += ` ORDER BY t.updated_at DESC`;

    const result = await pool.query(query, params);

    // Transform to match frontend TimelineEvent model
    const transformedEvents = result.rows.map(row => ({
      id: row.id,
      title: row.title,
      description: row.description,
      type: row.entity_type, // Map entity_type to TimelineEventType
      date: row.start_date,
      startTime: row.start_date,
      endTime: row.end_date,
      projectId: row.entity_type === 'project' ? row.entity_id : null,
      sprintId: row.entity_type === 'sprint' ? row.entity_id : null,
      assignedTo: row.created_by,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      metadata: row.metadata || {},
      isCompleted: row.status === 'completed' || row.entity_status === 'completed',
      // Legacy fields for backwards compatibility
      time: row.start_date ? new Date(row.start_date).toTimeString().slice(0, 5) : null,
      priority: row.priority,
      project: row.entity_type === 'project' ? row.title : null,
      colorTag: _mapPriorityToColorTag(row.priority)
    }));

    res.json({
      success: true,
      data: transformedEvents,
      count: transformedEvents.length,
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

// Get active timeline events only
router.get('/active', async (req, res) => {
  try {
    const { start_date, end_date, limit = 100, offset = 0 } = req.query;

    let query = `
      SELECT 
        t.id,
        t.entity_type,
        t.entity_id,
        t.title,
        t.description,
        t.start_date,
        t.end_date,
        t.created_by,
        t.status,
        t.priority,
        t.tags,
        t.metadata,
        t.created_at,
        t.updated_at,
        -- Get project/sprint status for filtering
        CASE 
          WHEN t.entity_type = 'project' THEN p.status
          WHEN t.entity_type = 'sprint' THEN s.status
          ELSE null
        END as entity_status
      FROM timeline t
      LEFT JOIN projects p ON t.entity_type = 'project' AND t.entity_id = p.id
      LEFT JOIN sprints s ON t.entity_type = 'sprint' AND t.entity_id = s.id
      WHERE 1=1
        AND (
          (t.entity_type = 'project' AND p.status NOT IN ('completed', 'cancelled')) OR
          (t.entity_type = 'sprint' AND s.status NOT IN ('completed', 'cancelled')) OR
          (t.entity_type NOT IN ('project', 'sprint'))
        )
    `;

    const params = [];
    let paramIndex = 1;

    if (start_date) {
      query += ` AND t.start_date >= $${paramIndex++}`;
      params.push(start_date);
    }

    if (end_date) {
      query += ` AND t.end_date <= $${paramIndex++}`;
      params.push(end_date);
    }

    query += ` ORDER BY t.start_date ASC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    // Transform to match frontend TimelineEvent model
    const transformedEvents = result.rows.map(row => ({
      id: row.id,
      title: row.title,
      description: row.description,
      type: row.entity_type,
      date: row.start_date,
      startTime: row.start_date,
      endTime: row.end_date,
      projectId: row.entity_type === 'project' ? row.entity_id : null,
      sprintId: row.entity_type === 'sprint' ? row.entity_id : null,
      assignedTo: row.created_by,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      metadata: row.metadata || {},
      isCompleted: row.status === 'completed' || row.entity_status === 'completed',
      time: row.start_date ? new Date(row.start_date).toTimeString().slice(0, 5) : null,
      priority: row.priority,
      project: row.entity_type === 'project' ? row.title : null,
      colorTag: _mapPriorityToColorTag(row.priority)
    }));

    res.json({
      success: true,
      data: transformedEvents,
      count: transformedEvents.length,
      filters: {
        start_date,
        end_date,
        limit,
        offset,
        excludes_completed: true
      }
    });

  } catch (error) {
    console.error('Error fetching active timeline events:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch active timeline events'
    });
  }
});

// Helper function to prevent duplicate timeline entries
async function _ensureUniqueTimelineEntry(entityType, entityId, title, description, startDate, endDate, createdBy, status = 'active', priority = 'medium', metadata = {}) {
  try {
    // Check if timeline entry already exists
    const existingEntry = await pool.query(`
      SELECT id FROM timeline 
      WHERE entity_type = $1 AND entity_id = $2
      LIMIT 1
    `, [entityType, entityId]);

    if (existingEntry.rows.length > 0) {
      // Update existing entry
      await pool.query(`
        UPDATE timeline 
        SET 
          title = $1,
          description = $2,
          start_date = $3,
          end_date = $4,
          status = $5,
          priority = $6,
          metadata = $7,
          updated_at = NOW()
        WHERE entity_type = $8 AND entity_id = $9
      `, [title, description, startDate, endDate, status, priority, JSON.stringify(metadata), entityType, entityId]);
      
      console.log(`Timeline entry updated for ${entityType} ${entityId}`);
      return existingEntry.rows[0].id;
    } else {
      // Create new entry
      const result = await pool.query(`
        INSERT INTO timeline (
          entity_type, entity_id, title, description, 
          start_date, end_date, created_by, status, 
          priority, tags, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id
      `, [
        entityType,
        entityId,
        title,
        description,
        startDate,
        endDate,
        createdBy,
        status,
        priority,
        JSON.stringify([]),
        JSON.stringify(metadata)
      ]);
      
      console.log(`Timeline entry created for ${entityType} ${entityId}`);
      return result.rows[0].id;
    }
  } catch (error) {
    console.error('Error ensuring unique timeline entry:', error);
    throw error;
  }
}

// Helper function to map priority to color tag
function _mapPriorityToColorTag(priority) {
  switch (priority?.toLowerCase()) {
    case 'high':
      return 'red';
    case 'medium':
      return 'blue';
    case 'low':
      return 'green';
    default:
      return 'blue';
  }
}

export default router;
