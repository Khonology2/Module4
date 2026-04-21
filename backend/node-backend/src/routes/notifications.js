const express = require('express');
const router = express.Router();
const { Notification, User } = require('../models');
const { authenticateToken } = require('../middleware/auth');
const socketService = require('../services/socketService');

/**
 * @route POST /api/notifications
 * @desc Create a new notification
 * @access Private
 */
router.post('/', authenticateToken, async (req, res) => {
  try {
    const notificationData = req.body;
    
    // Ensure the recipient exists
    const recipient = await User.findByPk(notificationData.recipient_id);
    if (!recipient) {
      return res.status(404).json({ error: 'Recipient not found' });
    }
    
    // Set sender_id if not provided (e.g., system notification) or if it's the current user
    if (notificationData.sender_id === undefined || notificationData.sender_id === null) {
      notificationData.sender_id = req.user.id;
    } else if (notificationData.sender_id !== req.user.id) {
      return res.status(403).json({
        error: 'Not authorized',
        message: 'Not authorized to send notifications on behalf of another user'
      });
    }
    
    const notification = await Notification.create(notificationData);
    
    // Enhanced real-time notification with role-based broadcasting
    if (socketService && typeof socketService.sendToUser === 'function') {
      // Send to specific recipient
      socketService.sendToUser(notification.recipient_id, 'notification_received', notification);
      
      // If this is a system-wide notification, also broadcast to relevant roles
      if (notificationData.type === 'system' || notificationData.broadcast_to_roles) {
        const targetRoles = notificationData.broadcast_to_roles || ['system_admin', 'delivery_lead'];
        
        // Get recipient user to determine their role
        try {
          const { User } = require('../models');
          const recipient = await User.findByPk(notification.recipient_id);
          
          if (recipient) {
            // Send to role-based rooms for cross-portal synchronization
            targetRoles.forEach(role => {
              socketService.sendToRole(role, 'notification_received', {
                ...notification,
                sync_type: 'role_broadcast',
                target_role: role,
                original_recipient: notification.recipient_id
              });
            });
          }
        } catch (roleError) {
          console.error('Error broadcasting to roles:', roleError);
        }
      }
      
      // Broadcast notification count update to trigger refresh
      socketService.sendToUser(notification.recipient_id, 'notifications_updated', {
        unreadCount: await Notification.count({
          where: { recipient_id: notification.recipient_id, is_read: false }
        }),
        timestamp: new Date()
      });
    }
    
    res.status(201).json(notification);
  } catch (error) {
    console.error('Error creating notification:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/notifications/me
 * @desc Get notifications for current user
 * @access Private
 */
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const { skip = 0, limit = 100, unread_only } = req.query;

    const uid = req.user && req.user.id;
    if (!uid || !/^[0-9a-fA-F-]{36}$/.test(String(uid))) {
      return res.json([]);
    }

    const where = { recipient_id: uid };
    if (String(unread_only || '').toLowerCase() === 'true') {
      where.is_read = false;
    }

    const notifications = await Notification.findAll({
      where,
      offset: parseInt(skip),
      limit: parseInt(limit),
      order: [['created_at', 'DESC']]
    });
    
    res.json(notifications);
  } catch (error) {
    console.error('Error fetching user notifications:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/notifications/count
 * @desc Get unread notification count
 * @access Private
 */
router.get('/count', authenticateToken, async (req, res) => {
  try {
    const uid = req.user && req.user.id;
    if (!uid || !/^[0-9a-fA-F-]{36}$/.test(String(uid))) {
      return res.json({ success: true, data: { unreadCount: 0 } });
    }

    const unreadCount = await Notification.count({
      where: { recipient_id: uid, is_read: false }
    });
    res.json({ success: true, data: { unreadCount } });
  } catch (error) {
    console.error('Error fetching unread notification count:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route GET /api/notifications/:id
 * @desc Get a specific notification
 * @access Private
 */
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const notification = await Notification.findByPk(id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    if (notification.recipient_id !== req.user.id && notification.sender_id !== req.user.id) {
      return res.status(403).json({
        error: 'Not authorized',
        message: 'Not authorized to view this notification'
      });
    }
    
    res.json(notification);
  } catch (error) {
    console.error('Error fetching notification:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route PUT /api/notifications/:id/read
 * @desc Mark a notification as read
 * @access Private
 */
router.put('/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const notification = await Notification.findByPk(id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    if (notification.recipient_id !== req.user.id) {
      return res.status(403).json({
        error: 'Not authorized',
        message: 'Not authorized to mark this notification as read'
      });
    }
    
    await notification.update({ is_read: true });
    socketService.sendToUser(req.user.id, 'notifications_updated', { id });

    res.json(notification);
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.put('/read-all', authenticateToken, async (req, res) => {
  try {
    const uid = req.user && req.user.id;
    if (!uid || !/^[0-9a-fA-F-]{36}$/.test(String(uid))) {
      return res.json({ success: true, data: { markedCount: 0 } });
    }

  const [affectedCount] = await Notification.update(
      { is_read: true },
      { where: { recipient_id: uid, is_read: false } }
    );
    socketService.sendToUser(uid, 'notifications_updated', { all: true, markedCount: affectedCount });
    res.json({ success: true, data: { markedCount: affectedCount } });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route DELETE /api/notifications/:id
 * @desc Delete a notification
 * @access Private
 */
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const notification = await Notification.findByPk(id);
    if (!notification) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    if (notification.recipient_id !== req.user.id) {
      return res.status(403).json({
        error: 'Not authorized',
        message: 'Not authorized to delete this notification'
      });
    }
    
    await notification.destroy();
    
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * @route POST /api/notifications/broadcast
 * @desc Create notifications for multiple users or roles
 * @access Private (System Admin only)
 */
router.post('/broadcast', authenticateToken, async (req, res) => {
  try {
    const { recipients, roles, message, type, title, payload } = req.body;
    
    // Only allow system admins to broadcast
    if (req.user.role !== 'system_admin') {
      return res.status(403).json({ error: 'Not authorized to broadcast notifications' });
    }
    
    const createdNotifications = [];
    const targetUsers = new Set();
    
    // Add specific recipients
    if (recipients && Array.isArray(recipients)) {
      recipients.forEach(id => targetUsers.add(id));
    }
    
    // Add users by role
    if (roles && Array.isArray(roles)) {
      try {
        const { User } = require('../models');
        const usersByRole = await User.findAll({
          where: { role: roles },
          attributes: ['id']
        });
        usersByRole.forEach(user => targetUsers.add(user.id));
      } catch (roleError) {
        console.error('Error fetching users by role:', roleError);
      }
    }
    
    // Create notifications for all target users
    for (const userId of targetUsers) {
      try {
        const notification = await Notification.create({
          recipient_id: userId,
          sender_id: req.user.id,
          type: type || 'system',
          message,
          title: title || 'System Notification',
          payload: payload || {},
          is_read: false
        });
        
        createdNotifications.push(notification);
        
        // Send real-time notification
        if (socketService && typeof socketService.sendToUser === 'function') {
          socketService.sendToUser(userId, 'notification_received', notification);
        }
      } catch (createError) {
        console.error(`Error creating notification for user ${userId}:`, createError);
      }
    }
    
    // Broadcast notification count update to all target users
    if (socketService) {
      targetUsers.forEach(userId => {
        socketService.sendToUser(userId, 'notifications_updated', {
          unreadCount: null, // Force refresh
          timestamp: new Date()
        });
      });
    }
    
    res.status(201).json({
      success: true,
      data: {
        created: createdNotifications.length,
        notifications: createdNotifications
      }
    });
  } catch (error) {
    console.error('Error broadcasting notifications:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
