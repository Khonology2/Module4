const { Sequelize, Op } = require('sequelize');
const { AuditLog, User, Deliverable, Sprint, Signoff, Notification, sequelize } = require('../models');
const os = require('os');
const process = require('process');

function normalizeStatus(value) {
  return String(value || '').toLowerCase().replace(/[\s_-]+/g, '');
}

class AnalyticsService {
  constructor() {
    this._isRunning = false;
    this.metricsCache = {};
    this.performanceMetrics = {
      responseTimes: [],
      errorRates: [],
      throughput: []
    };
    this.cacheTtl = 1800; // 30 minutes - reduced frequency to prevent server overload
    this.startTime = Date.now();
  }

  async start() {
    if (this._isRunning) return;
    this._isRunning = true;
    await this._periodicMetricsUpdate();
  }

  async stop() {
    this._isRunning = false;
  }

  async _periodicMetricsUpdate() {
    while (this._isRunning) {
      try {
        await this._updateAllMetrics();
        await new Promise(resolve => setTimeout(resolve, this.cacheTtl * 1000));
      } catch (error) {
        console.error('Error in periodic metrics update:', error);
        await new Promise(resolve => setTimeout(resolve, 60000)); // Wait 1 minute on error
      }
    }
  }

  async _updateAllMetrics() {
    try {
      this.metricsCache = {
        user_activity: await this._getUserActivityMetrics(),
        system_usage: await this._getSystemUsageMetrics(),
        project_metrics: await this._getProjectMetrics(),
        signoff_reports: await this._getSignoffMetrics(),
        performance: await this._getPerformanceMetrics(),
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('Error updating all metrics:', error);
    }
  }

  async getMetrics(metricType = null) {
    if (Object.keys(this.metricsCache).length === 0) {
      await this._updateAllMetrics();
    }

    if (metricType) {
      return this.metricsCache[metricType] || {};
    }

    // Return flat structure for frontend compatibility
    const metrics = this.metricsCache;
    const userActivity = metrics.user_activity || {};
    const projectMetrics = metrics.project_metrics || {};
    const signoffMetrics = metrics.signoff_reports || {};

    // Convert to frontend-expected format
    const flatMetrics = {
      // User metrics
      total_users: userActivity.total_users || 0,
      active_users_24h: userActivity.active_users_24h || 0,
      
      // Sprint metrics
      total_sprints: projectMetrics.total_sprints || 0,
      active_sprints: projectMetrics.sprint_status?.active || 0,
      completed_sprints: projectMetrics.sprint_status?.completed || 0,
      
      // Deliverable metrics
      total_deliverables: projectMetrics.total_deliverables || 0,
      pending_deliverables: projectMetrics.deliverable_status?.pending || 0,
      completed_deliverables: projectMetrics.deliverable_status?.completed || 0,
      overdue_deliverables: projectMetrics.deliverable_status?.overdue || 0,
      draft_reports: signoffMetrics.draft_reports || 0,
      submitted_reports: signoffMetrics.submitted_reports || 0,
      approved_reports: signoffMetrics.approved_reports || 0,
      change_requested_reports: signoffMetrics.change_requested_reports || 0,
      total_reports: signoffMetrics.total_reports || 0,
      avg_signoff_days: signoffMetrics.avg_signoff_days || 0,
      
      // System metrics
      system_usage: metrics.system_usage || {},
      performance: metrics.performance || {},
      user_activity: userActivity,
      timestamp: metrics.timestamp || ''
    };

    return flatMetrics;
  }

  async _getUserActivityMetrics() {
    try {
      const userCounts = await User.findAll({
        attributes: ['role', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
        group: ['role']
      });

      const activeUsers = await User.count({
        where: {
          last_login: {
            [Op.gte]: new Date(Date.now() - 24 * 60 * 60 * 1000)
          }
        }
      });

      const totalUsers = await User.count();

      const usersByRole = {};
      userCounts.forEach(item => {
        usersByRole[item.role] = parseInt(item.get('count'));
      });

      const signoffMetrics = await this._getSignoffMetrics();
      return {
        total_users: totalUsers,
        users_by_role: usersByRole,
        active_users_24h: activeUsers,
        avg_review_time: signoffMetrics.avg_review_time_hours || 0,
      };
    } catch (error) {
      console.error('Error getting user activity metrics:', error);
      return {};
    }
  }

  async _getSystemUsageMetrics() {
    try {
      const commonActions = await AuditLog.findAll({
        attributes: ['action', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
        group: ['action'],
        order: [[Sequelize.fn('COUNT', Sequelize.col('id')), 'DESC']],
        limit: 10
      });

      const totalActions = await AuditLog.count();
      const actionsLast24h = await AuditLog.count({
        where: {
          created_at: {
            [Op.gte]: new Date(Date.now() - 24 * 60 * 60 * 1000)
          }
        }
      });

      // Calculate system resources
      const cpus = os.cpus();
      const cpuUsage = cpus.reduce((acc, cpu) => {
        const total = Object.values(cpu.times).reduce((a, b) => a + b, 0);
        const idle = cpu.times.idle;
        return acc + ((total - idle) / total);
      }, 0) / cpus.length * 100;

      const totalMem = os.totalmem();
      const freeMem = os.freemem();
      const usedMem = totalMem - freeMem;
      const memoryUsage = (usedMem / totalMem) * 100;

      return {
        total_actions: totalActions,
        common_actions: commonActions.map(item => ({
          action: item.action,
          count: parseInt(item.get('count'))
        })),
        actions_last_24h: actionsLast24h,
        cpuUsage: parseFloat(cpuUsage.toFixed(1)),
        memoryUsage: parseFloat(memoryUsage.toFixed(1)),
        diskUsage: 45.5, // Placeholder as Node.js doesn't have native disk usage without external libs
        uptime: os.uptime(),
        responseTime: this.performanceMetrics.responseTimes.length > 0 
          ? this.performanceMetrics.responseTimes.reduce((a, b) => a + b, 0) / this.performanceMetrics.responseTimes.length * 1000 
          : 0
      };
    } catch (error) {
      console.error('Error getting system usage metrics:', error);
      return {};
    }
  }

  async _getProjectMetrics() {
    try {
      const deliverableStatus = await Deliverable.findAll({
        attributes: ['status', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
        group: ['status']
      });

      const sprintStatus = await Sprint.findAll({
        attributes: ['status', [Sequelize.fn('COUNT', Sequelize.col('id')), 'count']],
        group: ['status']
      });

      const totalDeliverables = await Deliverable.count();
      const totalSprints = await Sprint.count();

      const deliverableStatusObj = {};
      deliverableStatus.forEach(item => {
        deliverableStatusObj[item.status] = parseInt(item.get('count'));
      });

      const sprintStatusObj = {};
      sprintStatus.forEach(item => {
        sprintStatusObj[item.status] = parseInt(item.get('count'));
      });

      const signoffMetrics = await this._getSignoffMetrics();
      return {
        total_deliverables: totalDeliverables,
        total_sprints: totalSprints,
        deliverable_status: deliverableStatusObj,
        sprint_status: sprintStatusObj,
        signoff_reports: signoffMetrics,
      };
    } catch (error) {
      console.error('Error getting project metrics:', error);
      return {};
    }
  }

  async _getSignoffMetrics() {
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
      const rows = await sequelize.query(
        'SELECT id, status, content, created_at, updated_at FROM sign_off_reports',
        { type: Sequelize.QueryTypes.SELECT }
      );
      const metrics = {
        total_reports: rows.length,
        draft_reports: 0,
        submitted_reports: 0,
        approved_reports: 0,
        change_requested_reports: 0,
        rejected_reports: 0,
        avg_signoff_days: 0,
        avg_review_time_hours: 0,
      };
      const reviewDurationsHours = [];
      const reviewDurationsDays = [];
      for (const row of rows) {
        const status = normalizeStatus(row.status);
        if (status === 'draft') metrics.draft_reports += 1;
        else if (status === 'submitted') metrics.submitted_reports += 1;
        else if (status === 'approved') metrics.approved_reports += 1;
        else if (status === 'changerequested') metrics.change_requested_reports += 1;
        else if (status === 'rejected') metrics.rejected_reports += 1;
        let content = row.content || {};
        if (typeof content === 'string') {
          try {
            content = JSON.parse(content);
          } catch (_) {
            content = {};
          }
        }
        const submittedAt = content.submittedAt || content.submitted_at || row.created_at;
        const reviewedAt = content.approvedAt || content.approved_at || content.reviewedAt || content.reviewed_at;
        if (submittedAt && reviewedAt) {
          const start = new Date(submittedAt);
          const end = new Date(reviewedAt);
          if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime()) && end >= start) {
            const hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
            reviewDurationsHours.push(hours);
            reviewDurationsDays.push(hours / 24);
          }
        }
      }
      if (reviewDurationsHours.length > 0) {
        metrics.avg_review_time_hours = Number(
          (reviewDurationsHours.reduce((sum, value) => sum + value, 0) / reviewDurationsHours.length).toFixed(1)
        );
        metrics.avg_signoff_days = Number(
          (reviewDurationsDays.reduce((sum, value) => sum + value, 0) / reviewDurationsDays.length).toFixed(1)
        );
      }
      return metrics;
    } catch (error) {
      console.error('Error getting sign-off metrics:', error);
      return {
        total_reports: 0,
        draft_reports: 0,
        submitted_reports: 0,
        approved_reports: 0,
        change_requested_reports: 0,
        rejected_reports: 0,
        avg_signoff_days: 0,
        avg_review_time_hours: 0,
      };
    }
  }

  async getUserAnalytics(userId) {
    try {
      const userActions = await AuditLog.count({
        where: { user_id: userId }
      });

      const userActions24h = await AuditLog.count({
        where: {
          user_id: userId,
          created_at: {
            [Op.gte]: new Date(Date.now() - 24 * 60 * 60 * 1000)
          }
        }
      });

      return {
        total_actions: userActions,
        actions_24h: userActions24h
      };
    } catch (error) {
      console.error('Error getting user analytics:', error);
      return {};
    }
  }

  async _getPerformanceMetrics() {
    try {
      // System metrics
      const cpuUsage = os.loadavg()[0]; // 1-minute load average
      const totalMem = os.totalmem();
      const freeMem = os.freemem();
      const usedMem = totalMem - freeMem;
      
      // Process metrics
      const processMemory = process.memoryUsage().rss / 1024 / 1024; // MB
      
      // Uptime
      const uptime = (Date.now() - this.startTime) / 1000; // seconds
      
      // Format uptime
      const days = Math.floor(uptime / 86400);
      const hours = Math.floor((uptime % 86400) / 3600);
      const minutes = Math.floor((uptime % 3600) / 60);
      const seconds = Math.floor(uptime % 60);
      
      const uptimeFormatted = `${days}d ${hours}h ${minutes}m ${seconds}s`;

      return {
        cpu_percent: (cpuUsage / os.cpus().length) * 100,
        memory_percent: (usedMem / totalMem) * 100,
        memory_used_mb: usedMem / 1024 / 1024,
        memory_total_mb: totalMem / 1024 / 1024,
        process_memory_mb: processMemory,
        uptime_seconds: uptime,
        uptime_formatted: uptimeFormatted
      };
    } catch (error) {
      console.error('Error getting performance metrics:', error);
      return { error: 'Unable to collect performance metrics' };
    }
  }

  recordResponseTime(responseTime) {
    this.performanceMetrics.responseTimes.push(responseTime);
    // Keep only last 1000 measurements
    if (this.performanceMetrics.responseTimes.length > 1000) {
      this.performanceMetrics.responseTimes = this.performanceMetrics.responseTimes.slice(-1000);
    }
  }

  recordError() {
    this.performanceMetrics.errorRates.push(1);
    if (this.performanceMetrics.errorRates.length > 1000) {
      this.performanceMetrics.errorRates = this.performanceMetrics.errorRates.slice(-1000);
    }
  }

  recordSuccess() {
    this.performanceMetrics.errorRates.push(0);
    if (this.performanceMetrics.errorRates.length > 1000) {
      this.performanceMetrics.errorRates = this.performanceMetrics.errorRates.slice(-1000);
    }
  }
}

// Global analytics service instance
const analyticsService = new AnalyticsService();

module.exports = analyticsService;
