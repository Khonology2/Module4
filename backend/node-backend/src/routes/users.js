const express = require('express');
const { Op } = require('sequelize');
const router = express.Router();
const { User, UserProfile } = require('../models');
const { authenticateToken, requireRole } = require('../middleware/auth');

function looksLikeUuid(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    String(value || '').trim()
  );
}

async function findUserByIdentifier(identifier, options = {}) {
  const raw = String(identifier || '').trim();
  if (!raw) return null;

  if (looksLikeUuid(raw)) {
    return User.findByPk(raw, options);
  }

  return User.findOne({
    ...options,
    where: {
      ...(options.where || {}),
      email: raw,
    },
  });
}

/**
 * @route GET /api/users
 * @desc Get all users with pagination and search
 * @access Private (Authenticated users)
 */
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { page = 1, limit = 20, search } = req.query;
    const offset = (page - 1) * limit;
    
    // Build where clause for search
    const whereClause = {};
    if (search) {
      whereClause[Op.or] = [
        { email: { [Op.iLike]: `%${search}%` } },
        { first_name: { [Op.iLike]: `%${search}%` } },
        { last_name: { [Op.iLike]: `%${search}%` } }
      ];
    }
    
    const { count, rows: users } = await User.findAndCountAll({
      where: whereClause,
      attributes: [
        'id',
        'email',
        'first_name',
        'last_name',
        'role',
        'is_active',
        'last_login',
        'created_at'
      ],
      order: [['created_at', 'DESC']],
      limit: parseInt(limit),
      offset: offset
    });
    
    res.json({
      users,
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(count / limit)
      }
    });
    
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch users'
    });
  }
});

/**
 * @route GET /api/users/:id
 * @desc Get user by ID
 * @access Private (Admin only)
 */
router.get('/:id', authenticateToken, requireRole(['systemAdmin', 'admin', 'deliveryLead']), async (req, res) => {
  try {
    const { id } = req.params;
    
    const user = await findUserByIdentifier(id, {
      attributes: [
        'id',
        'email',
        'first_name',
        'last_name',
        'role',
        'is_active',
        'last_login',
        'created_at',
        'updated_at'
      ]
    });
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }
    
    res.json({ user });
    
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to fetch user'
    });
  }
});

router.put('/:id/role', authenticateToken, requireRole(['systemAdmin', 'admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { role } = req.body || {};

    if (!role || typeof role !== 'string' || role.trim() === '') {
      return res.status(400).json({
        error: 'Invalid role',
        message: 'Role is required and must be a non-empty string'
      });
    }

    const user = await findUserByIdentifier(id);
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }

    if (user.role === role) {
      return res.json({
        message: 'User role unchanged',
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          role: user.role,
          is_active: user.is_active,
          last_login: user.last_login,
          created_at: user.created_at
        }
      });
    }

    await user.update({ role }, { updatedBy: req.user?.id });

    return res.json({
      message: 'User role updated successfully',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_active: user.is_active,
        last_login: user.last_login,
        created_at: user.created_at
      }
    });
  } catch (error) {
    console.error('Update user role error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to update user role'
    });
  }
});

/**
 * @route PUT /api/users/:id
 * @desc Update user information
 * @access Private (Admin only)
 */
router.put('/:id', authenticateToken, requireRole(['systemAdmin', 'admin']), async (req, res) => {
  try {
    const { id } = req.params;
    const { 
      first_name, 
      last_name, 
      email, 
      role, 
      is_active 
    } = req.body;
    
    const user = await findUserByIdentifier(id);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }
    
    // Check if email is being changed and if it already exists
    if (email && email !== user.email) {
      const existingUser = await User.findOne({ where: { email } });
      if (existingUser) {
        return res.status(409).json({
          error: 'Email already exists',
          message: 'A user with this email already exists'
        });
      }
    }
    
    // Prepare updates
    const updates = {};
    if (first_name !== undefined) updates.first_name = first_name;
    if (last_name !== undefined) updates.last_name = last_name;
    if (email !== undefined) updates.email = email;
    if (role !== undefined) updates.role = role;
    if (is_active !== undefined) updates.is_active = is_active;
    
    await user.update(updates);
    
    res.json({
      message: 'User updated successfully',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_active: user.is_active,
        last_login: user.last_login,
        created_at: user.created_at
      }
    });
    
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to update user'
    });
  }
});

/**
 * @route DELETE /api/users/:id
 * @desc Delete user
 * @access Private (Admin only)
 */
router.delete('/:id', authenticateToken, requireRole(['systemAdmin', 'admin']), async (req, res) => {
  try {
    const { id } = req.params;
    
    const user = await findUserByIdentifier(id);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }
    
    const allowSelf = String(req.query.allow_self || '').toLowerCase() === 'true';
    if (user.id === req.user.id && !allowSelf) {
      return res.status(400).json({
        error: 'Cannot delete own account',
        message: 'You cannot delete your own account'
      });
    }
    
    await UserProfile.destroy({ where: { user_id: user.id } });
    await user.destroy();
    
    res.json({
      message: 'User deleted successfully'
    });
    
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to delete user'
    });
  }
});

// Purge users except specified keepers and protected roles
router.delete('/purge', authenticateToken, requireRole(['systemAdmin', 'admin']), async (req, res) => {
  try {
    const { keep_email, keep_first_name, keep_last_name, include_protected, disable_keeper } = req.query || {};
    const includeProtected = String(include_protected || '').toLowerCase() === 'true';
    const disableKeeper = String(disable_keeper || '').toLowerCase() === 'true';

    const protectedRoles = includeProtected ? [] : ['system_admin', 'systemAdmin', 'admin'];
    const keepIds = new Set();

    if (keep_email && typeof keep_email === 'string') {
      const u = await User.findOne({ where: { email: keep_email } });
      if (u) keepIds.add(u.id);
    }

    if (!disableKeeper) {
      const firstName = (keep_first_name && String(keep_first_name)) || 'Thabang';
      const lastName = (keep_last_name && String(keep_last_name)) || 'Nkabinde';
      const keeper = await User.findOne({
        where: {
          [Op.and]: [
            { first_name: { [Op.iLike]: firstName } },
            { last_name: { [Op.iLike]: lastName } }
          ]
        }
      });
      if (keeper) keepIds.add(keeper.id);
    }

    // Determine deletable users (exclude protected roles and keepers)
    const whereClause = {
      id: { [Op.notIn]: Array.from(keepIds) }
    };
    if (protectedRoles.length > 0) {
      whereClause.role = { [Op.notIn]: protectedRoles };
    }
    const deletableUsers = await User.findAll({
      where: whereClause,
      attributes: ['id']
    });

    const idsToDelete = deletableUsers.map(u => u.id);
    if (idsToDelete.length === 0) {
      return res.json({ message: 'No users eligible for deletion', deletedCount: 0 });
    }

    await UserProfile.destroy({ where: { user_id: { [Op.in]: idsToDelete } } });
    const deletedCount = await User.destroy({ where: { id: { [Op.in]: idsToDelete } } });
    return res.json({ message: 'Users purged successfully', deletedCount });
  } catch (error) {
    console.error('Purge users error:', error);
    res.status(500).json({ error: 'Internal server error', message: 'Failed to purge users' });
  }
});

module.exports = router;
