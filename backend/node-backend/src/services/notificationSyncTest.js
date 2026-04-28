/**
 * Notification Synchronization Test Service
 * Used to test cross-portal notification synchronization
 */

const { User, Notification } = require('../models');
const socketService = require('./socketService');

class NotificationSyncTest {
  constructor() {
    this.testResults = [];
  }

  /**
   * Test notification synchronization between different user roles
   */
  async testCrossPortalSync() {
    console.log('🧪 Starting cross-portal notification sync test...');
    
    try {
      // Get test users for different roles
      const teamMember = await User.findOne({ where: { role: 'team_member' } });
      const systemAdmin = await User.findOne({ where: { role: 'system_admin' } });
      const deliveryLead = await User.findOne({ where: { role: 'delivery_lead' } });

      if (!teamMember || !systemAdmin || !deliveryLead) {
        throw new Error('Missing test users for required roles');
      }

      console.log(`👥 Test users found: TM=${teamMember.id}, SA=${systemAdmin.id}, DL=${deliveryLead.id}`);

      // Test 1: Create notification for team member
      const testNotification1 = await Notification.create({
        recipient_id: teamMember.id,
        sender_id: systemAdmin.id,
        type: 'system',
        message: 'Test notification for team member',
        title: 'Sync Test 1',
        is_read: false
      });

      console.log(`✅ Test 1: Created notification ${testNotification1.id} for team member`);

      // Test 2: Broadcast notification to multiple roles
      const broadcastNotification = await this.createBroadcastNotification({
        recipients: [teamMember.id, deliveryLead.id],
        roles: ['system_admin'],
        message: 'Broadcast test notification',
        title: 'Sync Test 2 - Broadcast',
        type: 'system'
      });

      console.log(`✅ Test 2: Broadcast notification created`);

      // Test 3: Verify notification counts
      const teamMemberCount = await Notification.count({
        where: { recipient_id: teamMember.id, is_read: false }
      });
      
      const systemAdminCount = await Notification.count({
        where: { recipient_id: systemAdmin.id, is_read: false }
      });

      console.log(`📊 Notification counts - TM: ${teamMemberCount}, SA: ${systemAdminCount}`);

      // Test 4: Test real-time broadcasting
      if (socketService) {
        console.log('🔄 Testing real-time broadcasting...');
        
        // Send to team member
        socketService.sendToUser(teamMember.id, 'notification_received', {
          ...testNotification1.dataValues,
          sync_type: 'direct_send'
        });

        // Send to system admin role
        socketService.sendToRole('system_admin', 'notification_received', {
          ...broadcastNotification.dataValues,
          sync_type: 'role_broadcast',
          target_role: 'system_admin'
        });

        // Send count updates
        socketService.sendToUser(teamMember.id, 'notifications_updated', {
          unreadCount: teamMemberCount,
          timestamp: new Date()
        });

        console.log('✅ Test 4: Real-time broadcasting completed');
      }

      // Test 5: Cleanup test notifications
      await Notification.destroy({ where: { id: testNotification1.id } });
      
      this.testResults.push({
        test: 'Cross-Portal Sync',
        status: 'PASSED',
        details: {
          teamMemberNotifications: teamMemberCount,
          systemAdminNotifications: systemAdminCount,
          realTimeEnabled: !!socketService
        }
      });

      console.log('🎉 Cross-portal notification sync test completed successfully!');
      return true;

    } catch (error) {
      console.error('❌ Cross-portal sync test failed:', error);
      this.testResults.push({
        test: 'Cross-Portal Sync',
        status: 'FAILED',
        error: error.message
      });
      return false;
    }
  }

  /**
   * Create a broadcast notification (simulates the broadcast endpoint)
   */
  async createBroadcastNotification({ recipients, roles, message, title, type }) {
    const notifications = [];
    
    // Create for specific recipients
    for (const recipientId of recipients) {
      const notification = await Notification.create({
        recipient_id: recipientId,
        sender_id: 'system-test', // System generated
        type,
        message,
        title,
        is_read: false,
        payload: { broadcast_to_roles: roles }
      });
      notifications.push(notification);
    }

    // Create for users in specified roles
    const { User } = require('../models');
    const usersByRole = await User.findAll({
      where: { role: roles },
      attributes: ['id']
    });

    for (const user of usersByRole) {
      if (!recipients.includes(user.id)) {
        const notification = await Notification.create({
          recipient_id: user.id,
          sender_id: 'system-test',
          type,
          message,
          title,
          is_read: false,
          payload: { broadcast_to_roles: roles }
        });
        notifications.push(notification);
      }
    }

    return notifications[0]; // Return first notification for testing
  }

  /**
   * Test notification count synchronization
   */
  async testCountSync() {
    console.log('🧪 Testing notification count synchronization...');
    
    try {
      const { User } = require('../models');
      const users = await User.findAll({ limit: 5 });
      
      for (const user of users) {
        const count = await Notification.count({
          where: { recipient_id: user.id, is_read: false }
        });

        // Send count update via socket
        if (socketService) {
          socketService.sendToUser(user.id, 'notifications_updated', {
            unreadCount: count,
            timestamp: new Date()
          });
        }

        console.log(`📊 User ${user.role} (${user.id}): ${count} unread notifications`);
      }

      this.testResults.push({
        test: 'Count Sync',
        status: 'PASSED',
        details: { usersTested: users.length }
      });

      return true;
    } catch (error) {
      console.error('❌ Count sync test failed:', error);
      this.testResults.push({
        test: 'Count Sync',
        status: 'FAILED',
        error: error.message
      });
      return false;
    }
  }

  /**
   * Run all notification synchronization tests
   */
  async runAllTests() {
    console.log('🚀 Starting notification synchronization test suite...');
    
    this.testResults = [];
    
    const syncTest = await this.testCrossPortalSync();
    const countTest = await this.testCountSync();
    
    console.log('\n📋 Test Results Summary:');
    this.testResults.forEach(result => {
      const icon = result.status === 'PASSED' ? '✅' : '❌';
      console.log(`${icon} ${result.test}: ${result.status}`);
      if (result.error) console.log(`   Error: ${result.error}`);
      if (result.details) console.log(`   Details:`, result.details);
    });

    const allPassed = this.testResults.every(r => r.status === 'PASSED');
    console.log(`\n🎯 Overall Result: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
    
    return allPassed;
  }

  /**
   * Get test results
   */
  getTestResults() {
    return this.testResults;
  }
}

module.exports = NotificationSyncTest;
