const { sequelize, User, Notification, ApprovalRequest, Project } = require('../models');
const { QueryTypes, Op } = require('sequelize');

class SchedulerService {
  async ensureSignOffReportsTable() {
    try {
      await sequelize.query(
        "CREATE TABLE IF NOT EXISTS sign_off_reports (\n" +
          "  id SERIAL PRIMARY KEY,\n" +
          "  deliverable_id VARCHAR(255),\n" +
          "  created_by VARCHAR(255),\n" +
          "  status VARCHAR(50) DEFAULT 'draft',\n" +
          "  content JSONB,\n" +
          "  created_at TIMESTAMP DEFAULT NOW(),\n" +
          "  updated_at TIMESTAMP DEFAULT NOW()\n" +
          ")"
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * Run all scheduled tasks (Reminders & Escalations)
   * Can be called by the automated scheduler or manually via API
   * @param {Object} options - Options object
   * @param {boolean} options.force - If true, bypasses duplicate checks (optional, mostly for testing)
   * @returns {Promise<Object>} - Summary of actions taken
   */
  async runScheduledTasks(options = {}) {
    const results = {
      remindersSent: 0,
      escalationsSent: 0,
      errors: []
    };

    try {
      // --- 1. Reminders for Reports ---
      const reportsTableReady = await this.ensureSignOffReportsTable();
      const dueReports = reportsTableReady
        ? await sequelize.query(
            "SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status = 'submitted' AND updated_at <= NOW() - INTERVAL '1 day'",
            { type: QueryTypes.SELECT }
          )
        : [];

      const clientReviewers = await User.findAll({ where: { role: { [Op.in]: ['clientReviewer', 'ClientReviewer', 'clientreviewer'] }, is_active: true } });
      
      if (dueReports && dueReports.length > 0 && clientReviewers && clientReviewers.length > 0) {
        for (const report of dueReports) {
          try {
            const content = typeof report.content === 'string' ? (() => { try { return JSON.parse(report.content); } catch { return {}; } })() : (report.content || {});
            const title = content.reportTitle || content.report_title || 'Sign-Off Report';

            // Prevent duplicate reminders (check last 2 days) unless forced
            if (!options.force) {
              const recentReminders = await sequelize.query(
                "SELECT id FROM notifications WHERE type = 'approval' AND message LIKE :msgPattern AND created_at >= NOW() - INTERVAL '2 days'",
                { type: QueryTypes.SELECT, replacements: { msgPattern: `%${title}%` } }
              );
              if (recentReminders && recentReminders.length > 0) continue;
            }

            const notifications = clientReviewers.map((client) => ({
              recipient_id: client.id,
              sender_id: report.created_by || null,
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
            results.remindersSent += notifications.length;
          } catch (innerErr) {
            console.error(`Error processing report reminder for ${report.id}:`, innerErr);
            results.errors.push(`Report ${report.id}: ${innerErr.message}`);
          }
        }
      }

      // --- 2. Reminders for Approval Requests ---
      if (ApprovalRequest) {
        const dueApprovals = await ApprovalRequest.findAll({
          where: {
            status: 'pending',
            due_date: { [Op.lte]: new Date(Date.now() + 24 * 60 * 60 * 1000) } // Due within 24h or overdue
          }
        });

        if (dueApprovals && dueApprovals.length > 0 && clientReviewers && clientReviewers.length > 0) {
          for (const approval of dueApprovals) {
            try {
              // Check recent reminders
              if (!options.force) {
                const recent = await sequelize.query(
                  "SELECT id FROM notifications WHERE type = 'approval' AND payload->>'approval_request_id' = :id AND created_at >= NOW() - INTERVAL '2 days'",
                  { type: QueryTypes.SELECT, replacements: { id: String(approval.id) } }
                );
                if (recent && recent.length > 0) continue;
              }

              // Notify client reviewers
              const notifications = clientReviewers.map((client) => ({
                recipient_id: client.id,
                sender_id: approval.requested_by || null,
                type: 'approval',
                message: `Reminder: Approval pending for request #${approval.id}`,
                payload: {
                  approval_request_id: approval.id,
                  deliverable_id: approval.deliverable_id
                },
                is_read: false,
                created_at: new Date(),
              }));
              await Notification.bulkCreate(notifications);
              results.remindersSent += notifications.length;
            } catch (innerErr) {
              console.error(`Error processing approval reminder for ${approval.id}:`, innerErr);
              results.errors.push(`Approval ${approval.id}: ${innerErr.message}`);
            }
          }
        }
      }

      const now = new Date();
      const dueProjects = await Project.findAll({
        where: {
          end_date: { [Op.lte]: now },
          status: { [Op.notIn]: ['completed', 'cancelled'] },
          owner_id: { [Op.ne]: null },
        },
      });

      if (dueProjects && dueProjects.length > 0) {
        for (const project of dueProjects) {
          try {
            if (!options.force) {
              const recent = await sequelize.query(
                "SELECT id FROM notifications WHERE type = 'system' AND payload->>'project_id' = :id AND created_at >= NOW() - INTERVAL '1 day'",
                { type: QueryTypes.SELECT, replacements: { id: String(project.id) } }
              );
              if (recent && recent.length > 0) continue;
            }

            await Notification.create({
              recipient_id: project.owner_id,
              sender_id: null,
              type: 'system',
              message: `Reminder: Project "${project.name}" has reached its due date and is not marked as completed.`,
              payload: {
                project_id: project.id,
                project_name: project.name,
                end_date: project.end_date,
                status: project.status,
                reason: 'project_due_date',
              },
              is_read: false,
              created_at: new Date(),
            });

            results.remindersSent += 1;
          } catch (innerErr) {
            console.error(`Error processing project due-date reminder for ${project.id}:`, innerErr);
            results.errors.push(`Project ${project.id}: ${innerErr.message}`);
          }
        }
      }

      // --- 3. Escalations ---
      const timeoutHours = parseInt(process.env.ESCALATION_TIMEOUT_HOURS || '48');
      const interval = `INTERVAL '${timeoutHours} hours'`;
      
      // Escalation: Reports
      const stalledReports = reportsTableReady
        ? await sequelize.query(
            `SELECT id, created_by, status, content, updated_at FROM sign_off_reports WHERE status = 'submitted' AND updated_at <= NOW() - ${interval}`,
            { type: QueryTypes.SELECT }
          )
        : [];

      // Escalation: Approvals
      let stalledApprovals = [];
      if (ApprovalRequest) {
         stalledApprovals = await ApprovalRequest.findAll({
            where: {
               status: 'pending',
               updated_at: { [Op.lte]: new Date(Date.now() - timeoutHours * 60 * 60 * 1000) }
            }
         });
      }

      const admins = await User.findAll({ where: { role: { [Op.in]: ['systemAdmin', 'SystemAdmin', 'deliveryLead', 'DeliveryLead'] }, is_active: true } });
      
      if (admins && admins.length > 0) {
        // Process Report Escalations
        for (const report of (stalledReports || [])) {
           try {
             const content = typeof report.content === 'string' ? (() => { try { return JSON.parse(report.content); } catch { return {}; } })() : (report.content || {});
             const title = content.reportTitle || content.report_title || 'Sign-Off Report';
             
             if (!options.force) {
               const recent = await sequelize.query(
                  "SELECT id FROM notifications WHERE type = 'escalation' AND message LIKE :msgPattern AND created_at >= NOW() - INTERVAL '24 hours'",
                  { type: QueryTypes.SELECT, replacements: { msgPattern: `%${title}%` } }
               );
               if (recent && recent.length > 0) continue;
             }

             const notifications = admins.map(admin => ({
                recipient_id: admin.id,
                sender_id: null,
                type: 'escalation',
                message: `ESCALATION: Report "${title}" has been pending for over ${timeoutHours} hours.`,
                payload: { report_id: report.id, report_title: title },
                is_read: false,
                created_at: new Date()
             }));
             await Notification.bulkCreate(notifications);
             results.escalationsSent += notifications.length;
           } catch (innerErr) {
             console.error(`Error processing report escalation for ${report.id}:`, innerErr);
             results.errors.push(`Escalation Report ${report.id}: ${innerErr.message}`);
           }
        }

        // Process Approval Escalations
        for (const approval of (stalledApprovals || [])) {
           try {
             if (!options.force) {
               const recent = await sequelize.query(
                  "SELECT id FROM notifications WHERE type = 'escalation' AND payload->>'approval_request_id' = :id AND created_at >= NOW() - INTERVAL '24 hours'",
                  { type: QueryTypes.SELECT, replacements: { id: String(approval.id) } }
               );
               if (recent && recent.length > 0) continue;
             }

             const notifications = admins.map(admin => ({
                recipient_id: admin.id,
                sender_id: null,
                type: 'escalation',
                message: `ESCALATION: Approval Request #${approval.id} has been pending for over ${timeoutHours} hours.`,
                payload: { approval_request_id: approval.id },
                is_read: false,
                created_at: new Date()
             }));
             await Notification.bulkCreate(notifications);
             results.escalationsSent += notifications.length;
           } catch (innerErr) {
             console.error(`Error processing approval escalation for ${approval.id}:`, innerErr);
             results.errors.push(`Escalation Approval ${approval.id}: ${innerErr.message}`);
           }
        }
      }

    } catch (err) {
      console.error('Error in scheduled tasks:', err);
      results.errors.push(`Global error: ${err.message}`);
      throw err;
    }

    return results;
  }
}

module.exports = new SchedulerService();
