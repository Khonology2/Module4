const socketIO = require('socket.io');
const mqtt = require('mqtt');
const axios = require('axios');
const net = require('net');
let Aedes;
const jwt = require('jsonwebtoken');
const { loggingService } = require('./loggingService');
const { Sprint } = require('../models');

class SocketService {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map();
    this.rooms = new Map();
    this.mqttClient = null;
    this.mqttTopics = [];
    this.mqttConnected = false;
    this.mqttDisabled = false;
    this.mqttLastErrorLog = 0;
  }

  initialize(server) {
    this.io = socketIO(server, {
      cors: {
        origin: "*",
        methods: ["GET", "POST"],
        credentials: true
      }
    });

    this.io.use(this.authenticateSocket.bind(this));
    this.io.on('connection', this.handleConnection.bind(this));

    console.log('Socket.io server initialized');
    this.initializeEmbeddedBroker();
    this.initializeIot();
  }

  initializeEmbeddedBroker() {
    try {
      const embedded = String(process.env.IOT_EMBEDDED_BROKER || '').toLowerCase() === 'true';
      if (!embedded) return;
      const port = Number(process.env.IOT_MQTT_PORT || 1883);
      if (!Aedes) {
        try { Aedes = require('aedes'); } catch (_) { Aedes = null; }
      }
      if (!Aedes) { console.warn('⚠️ Embedded MQTT broker requested but aedes not installed'); return; }
      const aedes = Aedes();
      const server = net.createServer(aedes.handle);
      server.listen(port, () => {
        console.log(`✅ Embedded MQTT broker listening on port ${port}`);
      });
      aedes.on('clientReady', (client) => {
        console.log('🔌 MQTT client connected:', client && client.id);
      });
      aedes.on('publish', (packet, client) => {
        if (packet && packet.topic) {
          const src = client && client.id ? client.id : 'broker';
          if (String(process.env.IOT_LOG_LEVEL || 'warn').toLowerCase() === 'info') {
            console.log('📦 MQTT message', { topic: packet.topic, src });
          }
        }
      });
      this.embeddedBrokerServer = server;
      this.aedes = aedes;
    } catch (e) {}
  }

  async authenticateSocket(socket, next) {
    try {
      const h = socket.handshake || {};
      const authHeader = (h.headers && (h.headers.authorization || h.headers.Authorization)) || '';
      const bearer = authHeader && authHeader.split(' ')[0].toLowerCase() === 'bearer' ? authHeader.split(' ').slice(1).join(' ') : '';
      const token = (h.auth && h.auth.token) || (h.query && h.query.token) || bearer;
      if (!token) {
        return next(new Error('Authentication error: No token provided'));
      }
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production');
      socket.userId = decoded.sub || decoded.userId;
      socket.userRole = decoded.role || decoded.userRole;
      socket.email = decoded.email || decoded.userEmail;
      next();
    } catch (error) {
      console.error('Socket authentication failed:', error.message);
      next(new Error('Authentication error: Invalid token'));
    }
  }

  handleConnection(socket) {
    const { userId, userRole, email } = socket;
    
    console.log('User connected via WebSocket:', { 
      userId, 
      userRole, 
      email,
      socketId: socket.id 
    });

    // Add user to connected users map
    this.connectedUsers.set(userId, {
      socketId: socket.id,
      userId,
      userRole,
      email,
      connectedAt: new Date(),
      lastActivity: new Date()
    });

    // Join user to their personal room
    socket.join(`user:${userId}`);
    
    // Join user to role-based rooms
    socket.join(`role:${userRole}`);
    
    // Join user to global room
    socket.join('global');

    // Handle real-time events
    this.setupEventHandlers(socket);

    // Handle disconnection
    socket.on('disconnect', (reason) => {
      console.log('User disconnected from WebSocket:', { 
        userId, 
        email,
        reason,
        socketId: socket.id 
      });
      
      this.connectedUsers.delete(userId);
      
      // Broadcast user offline status
      socket.to('global').emit('user_offline', { 
        userId, 
        email,
        timestamp: new Date()
      });
    });

    // Broadcast user online status
    socket.to('global').emit('user_online', { 
      userId, 
      email,
      userRole,
      timestamp: new Date()
    });

    // Send connection confirmation
    socket.emit('connected', { 
      message: 'Successfully connected to real-time server',
      userId,
      userRole,
      timestamp: new Date()
    });
  }

  setupEventHandlers(socket) {
    const { userId, userRole, email } = socket;

    socket.on('join_role_room', (data = {}) => {
      try {
        const role = String(data.role || userRole || '').trim();
        if (role) {
          socket.join(`role:${role}`);
          socket.emit('joined_role_room', { role });
        }
      } catch (_) {}
    });

    socket.on('leave_role_room', (data = {}) => {
      try {
        const role = String(data.role || userRole || '').trim();
        if (role) {
          socket.leave(`role:${role}`);
          socket.emit('left_role_room', { role });
        }
      } catch (_) {}
    });

    // Deliverable events
    socket.on('deliverable_created', (data) => {
      console.log('Deliverable created via WebSocket:', { 
        userId, 
        email,
        deliverableId: data.id 
      });
      
      // Broadcast to all users except sender
      socket.broadcast.emit('deliverable_created', {
        ...data,
        createdBy: userId,
        timestamp: new Date()
      });
    });

    socket.on('deliverable_updated', (data) => {
      console.log('Deliverable updated via WebSocket:', { 
        userId, 
        email,
        deliverableId: data.id 
      });
      
      // Broadcast to all users
      this.io.emit('deliverable_updated', {
        ...data,
        updatedBy: userId,
        timestamp: new Date()
      });
    });

    socket.on('deliverable_deleted', (data) => {
      console.log('Deliverable deleted via WebSocket:', { 
        userId, 
        email,
        deliverableId: data.id 
      });
      
      // Broadcast to all users
      this.io.emit('deliverable_deleted', {
        ...data,
        deletedBy: userId,
        timestamp: new Date()
      });
    });

    // Sprint events
    socket.on('sprint_created', (data) => {
      console.log('Sprint created via WebSocket:', { 
        userId, 
        email,
        sprintId: data.id 
      });
      
      socket.broadcast.emit('sprint_created', {
        ...data,
        createdBy: userId,
        timestamp: new Date()
      });
    });

    socket.on('sprint_updated', (data) => {
      console.log('Sprint updated via WebSocket:', { 
        userId, 
        email,
        sprintId: data.id 
      });
      
      this.io.emit('sprint_updated', {
        ...data,
        updatedBy: userId,
        timestamp: new Date()
      });
    });

    // Notification events
    socket.on('notification_sent', (data) => {
      console.log('Notification sent via WebSocket:', { 
        userId, 
        email,
        notificationId: data.id 
      });
      
      // Send to specific user if recipient is specified
      if (data.recipientId && data.recipientId !== userId) {
        this.io.to(`user:${data.recipientId}`).emit('notification_received', {
          ...data,
          timestamp: new Date()
        });
      } else {
        // Broadcast to appropriate role or all users
        const target = data.role ? `role:${data.role}` : 'global';
        socket.to(target).emit('notification_received', {
          ...data,
          timestamp: new Date()
        });
      }
    });

    // Presence events
    socket.on('user_activity', (data) => {
      const userData = this.connectedUsers.get(userId);
      if (userData) {
        userData.lastActivity = new Date();
        this.connectedUsers.set(userId, userData);
      }
      
      socket.to('global').emit('user_activity_update', {
        userId,
        email,
        activity: data.activity,
        timestamp: new Date()
      });
    });

    // Error handling
    socket.on('error', (error) => {
      console.error('Socket error:', { 
        userId, 
        email,
        error: error.message 
      });
    });

    // Work progress events
    socket.on('deliverable_progress_update', (data) => {
      console.log('Deliverable progress updated via WebSocket:', { 
        userId, 
        email,
        deliverableId: data.deliverable?.id 
      });
      
      // Broadcast to all users with role-based filtering
      this._broadcastWorkProgress('deliverable_progress_updated', data, userId);
    });

    socket.on('sprint_progress_update', (data) => {
      console.log('Sprint progress updated via WebSocket:', { 
        userId, 
        email,
        sprintId: data.sprint?.id 
      });
      
      // Broadcast to all users with role-based filtering
      this._broadcastWorkProgress('sprint_progress_updated', data, userId);

      try {
        const targetRoles = data.targetRoles || [];
        const s = data.sprint || {};
        const m = data.metrics || {};
        const mix = s.defect_severity_mix || m.severity || {};
        const metrics = {
          id: String(s.id || m.id || ''),
          sprintId: String(s.id || m.sprintId || ''),
          committedPoints: Number(s.committed_points || m.committedPoints || 0),
          completedPoints: Number(s.completed_points || m.completedPoints || 0),
          carriedOverPoints: Number(s.carried_over_points || m.carriedOverPoints || 0),
          testPassRate: Number(s.test_pass_rate || m.testPassRate || 0),
          defectsOpened: Number(s.defects_opened || m.defectsOpened || 0),
          defectsClosed: Number(s.defects_closed || m.defectsClosed || 0),
          criticalDefects: Number(mix.critical || 0),
          highDefects: Number(mix.high || 0),
          mediumDefects: Number(mix.medium || 0),
          lowDefects: Number(mix.low || 0),
          codeReviewCompletion: Number(s.code_review_completion || m.codeReviewCompletion || 0),
          documentationStatus: Number(s.documentation_status || m.documentationStatus || 0),
          risks: String(s.blockers || m.risks || ''),
          mitigations: String(s.decisions || m.mitigations || ''),
          scopeChanges: `${Number(s.added_during_sprint || m.scopeAdded || 0)}/${Number(s.removed_during_sprint || m.scopeRemoved || 0)}`,
          uatNotes: String(s.uat_notes || m.uatNotes || ''),
          recordedAt: new Date().toISOString(),
          recordedBy: String(s.updated_by || s.created_by || m.recordedBy || userId || '')
        };
        const coverage = Number(s.code_coverage || m.codeCoverage || data.coverage || 0);
        const defects = {
          opened: Number(s.defects_opened || m.defectsOpened || 0),
          closed: Number(s.defects_closed || m.defectsClosed || 0),
          severity: mix
        };

        if (targetRoles.length === 0) {
          this.io.emit('qa_metrics_update', metrics);
          this.io.emit('qa_coverage_update', coverage);
          this.io.emit('qa_defects_update', defects);
        } else {
          targetRoles.forEach(role => {
            this.io.to(`role:${role}`).emit('qa_metrics_update', metrics);
            this.io.to(`role:${role}`).emit('qa_coverage_update', coverage);
            this.io.to(`role:${role}`).emit('qa_defects_update', defects);
          });
        }
      } catch (e) {}
    });

    socket.on('work_assignment', (data) => {
      console.log('Work assigned via WebSocket:', { 
        userId, 
        email,
        assigneeId: data.assigneeId 
      });
      
      // Broadcast to target roles or specific user
      this._broadcastWorkAssignment(data, userId);
    });

    socket.on('work_completion', (data) => {
      console.log('Work completed via WebSocket:', { 
        userId, 
        email,
        workItem: data.workItem 
      });
      
      // Broadcast to target roles
      this._broadcastWorkCompletion(data, userId);
    });

    socket.on('role_sync_update', (data) => {
      console.log('Role sync update via WebSocket:', { 
        userId, 
        email,
        syncType: data.type 
      });
      
      // Broadcast to target roles
      this._broadcastRoleSync(data, userId);
    });

    socket.on('qa_command', async (data) => {
      try {
        const sprintId = data && (data.sprintId || data.sprint_id);
        let sprint = null;
        if (sprintId) {
          sprint = await Sprint.findByPk(sprintId);
        }
        if (!sprint) {
          sprint = await Sprint.findOne({ order: [['updated_at', 'DESC']] });
        }
        const mix = sprint && sprint.defect_severity_mix ? sprint.defect_severity_mix : {};
        const metrics = sprint ? {
          id: String(sprint.id || ''),
          sprintId: String(sprint.id || ''),
          committedPoints: Number(sprint.committed_points || 0),
          completedPoints: Number(sprint.completed_points || 0),
          carriedOverPoints: Number(sprint.carried_over_points || 0),
          testPassRate: Number(sprint.test_pass_rate || 0),
          defectsOpened: Number(sprint.defects_opened || 0),
          defectsClosed: Number(sprint.defects_closed || 0),
          criticalDefects: Number(mix.critical || 0),
          highDefects: Number(mix.high || 0),
          mediumDefects: Number(mix.medium || 0),
          lowDefects: Number(mix.low || 0),
          codeReviewCompletion: Number(sprint.code_review_completion || 0),
          documentationStatus: Number(sprint.documentation_status || 0),
          risks: String(sprint.blockers || ''),
          mitigations: String(sprint.decisions || ''),
          scopeChanges: `${Number(sprint.added_during_sprint || 0)}/${Number(sprint.removed_during_sprint || 0)}`,
          uatNotes: String(sprint.uat_notes || ''),
          recordedAt: new Date().toISOString(),
          recordedBy: String(sprint.created_by || '')
        } : {
          id: '0',
          sprintId: '0',
          committedPoints: 0,
          completedPoints: 0,
          carriedOverPoints: 0,
          testPassRate: 0,
          defectsOpened: 0,
          defectsClosed: 0,
          criticalDefects: 0,
          highDefects: 0,
          mediumDefects: 0,
          lowDefects: 0,
          codeReviewCompletion: 0,
          documentationStatus: 0,
          risks: '',
          mitigations: '',
          scopeChanges: '',
          uatNotes: '',
          recordedAt: new Date().toISOString(),
          recordedBy: ''
        };
        const coverage = sprint ? Number(sprint.code_coverage || 0) : 0;
        const defects = sprint ? {
          opened: Number(sprint.defects_opened || 0),
          closed: Number(sprint.defects_closed || 0),
          severity: mix
        } : { opened: 0, closed: 0, severity: {} };
        this.io.to(`user:${userId}`).emit('qa_metrics_update', metrics);
        this.io.to(`user:${userId}`).emit('qa_coverage_update', coverage);
        this.io.to(`user:${userId}`).emit('qa_defects_update', defects);
      } catch (e) {}
    });
  }

  initializeIot() {
    try {
      const enabled = String(process.env.IOT_ENABLED || '').toLowerCase() === 'true';
      const url = process.env.IOT_MQTT_URL || '';
      if (!enabled || !url) { console.log('IoT MQTT disabled or URL missing'); return; }
      const required = String(process.env.IOT_REQUIRED || '').toLowerCase() === 'true';
      const logLevel = String(process.env.IOT_LOG_LEVEL || 'info').toLowerCase();
      const opts = {};
      if (process.env.IOT_MQTT_USERNAME) opts.username = process.env.IOT_MQTT_USERNAME;
      if (process.env.IOT_MQTT_PASSWORD) opts.password = process.env.IOT_MQTT_PASSWORD;
      this.mqttClient = mqtt.connect(url, opts);
      this.mqttTopics = (process.env.IOT_TOPICS || '').split(',').map(s => s.trim()).filter(Boolean);
      this.mqttClient.on('connect', () => {
        console.log('✅ IoT MQTT connected');
        this.mqttConnected = true;
        this.mqttDisabled = false;
        if (this.mqttTopics.length > 0) {
          this.mqttClient.subscribe(this.mqttTopics, (err) => {
            if (err) console.error('❌ IoT MQTT subscribe error:', err.message);
            else console.log('✅ IoT MQTT subscribed to topics:', this.mqttTopics.join(', '));
          });
        }
      });
      this.mqttClient.on('reconnect', () => {
        if (!this._shouldSuppress('reconnect', logLevel)) console.log('↻ IoT MQTT reconnecting');
      });
      this.mqttClient.on('error', (err) => {
        if (!this._shouldSuppress('error', logLevel)) console.error('❌ IoT MQTT error:', err && err.message ? err.message : 'unknown');
      });
      this.mqttClient.on('close', () => {
        if (!this._shouldSuppress('close', logLevel)) console.warn('⚠️ IoT MQTT connection closed');
        this.mqttConnected = false;
        if (!required) {
          this.mqttDisabled = true;
        }
      });
      this.mqttClient.on('message', (topic, payload) => {
        this._handleIotMessage(topic, payload);
      });
      console.log('⚙️ IoT MQTT initialization attempted:', { url, topics: this.mqttTopics });
      setTimeout(() => {
        if (!this.mqttConnected && !required) {
          this.mqttDisabled = true;
          console.warn('⚠️ IoT MQTT not connected; IoT features will be inactive until broker is available');
        }
      }, 5000);
    } catch (e) {}
  }

  _shouldSuppress(type, logLevel) {
    const now = Date.now();
    const interval = 10000;
    if (logLevel === 'silent') return true;
    if (now - this.mqttLastErrorLog < interval) return true;
    this.mqttLastErrorLog = now;
    return false;
  }

  _handleIotMessage(topic, payload) {
    try {
      const text = payload && payload.toString ? payload.toString('utf8') : String(payload || '');
      let data = null;
      try { data = JSON.parse(text); } catch (_) {}
      if (!data) return;
      const roles = Array.isArray(data.targetRoles) ? data.targetRoles : (Array.isArray(data.roles) ? data.roles : []);
      let event = data.event || '';
      if (!event) {
        if (topic.endsWith('/metrics')) event = 'qa_metrics_update';
        else if (topic.endsWith('/coverage')) event = 'qa_coverage_update';
        else if (topic.endsWith('/defects')) event = 'qa_defects_update';
        else if (topic.includes('deliverables/create')) event = 'deliverable_created';
        else if (topic.includes('deliverables/update')) event = 'deliverable_updated';
        else if (topic.includes('deliverables/delete')) event = 'deliverable_deleted';
        else if (topic.includes('sprints/create')) event = 'sprint_created';
        else if (topic.includes('sprints/update')) event = 'sprint_updated';
        else if (topic.includes('work/progress/sprint')) event = 'sprint_progress_updated';
        else if (topic.includes('work/progress/deliverable')) event = 'deliverable_progress_updated';
        else if (topic.includes('notifications')) event = 'notification_received';
        else if (topic.includes('presence/online')) event = 'user_online';
        else if (topic.includes('presence/offline')) event = 'user_offline';
      }
      if (!event) return;
      const payloadData = data.payload !== undefined ? data.payload : data;
      console.log('🔔 IoT event received', { topic, event, roles });
      if (roles.length === 0) {
        this.io.emit(event, payloadData);
      } else {
        roles.forEach(role => {
          this.io.to(`role:${role}`).emit(event, payloadData);
        });
      }

      const wantAi = String(process.env.IOT_AI_SUMMARY_ENABLED || '').toLowerCase() === 'true';
      const aiTopic = String(process.env.IOT_AI_SUMMARY_TOPIC || '').trim();
      if (wantAi && (event === 'sprint_progress_updated' || event === 'deliverable_progress_updated' || (aiTopic && topic.includes(aiTopic)))) {
        const port = process.env.PORT || 3001;
        const msgs = [
          { role: 'system', content: 'Create a concise summary of IoT telemetry for PM/QA.' },
          { role: 'user', content: JSON.stringify(payloadData).slice(0, 4000) }
        ];
        axios.post(`http://localhost:${port}/api/v1/ai/chat`, { messages: msgs, max_tokens: 256 })
          .then(r => {
            const content = ((r.data || {}).data || {}).content || '';
            const summary = { text: content, sourceTopic: topic, event };
            if (roles.length === 0) this.io.emit('iot_ai_summary', summary);
            else roles.forEach(role => this.io.to(`role:${role}`).emit('iot_ai_summary', summary));
          })
          .catch(() => {});
      }
    } catch (e) {}
  }

  // Utility methods
  broadcastToRole(role, event, data) {
    this.io.to(`role:${role}`).emit(event, {
      ...data,
      timestamp: new Date()
    });
  }

  sendToUser(userId, event, data) {
    this.io.to(`user:${userId}`).emit(event, {
      ...data,
      timestamp: new Date()
    });
  }

  sendToRole(role, event, data) {
    this.io.to(`role:${role}`).emit(event, {
      ...data,
      timestamp: new Date()
    });
  }

  broadcastToAll(event, data) {
    this.io.emit(event, {
      ...data,
      timestamp: new Date()
    });
  }

  getConnectedUsers() {
    return Array.from(this.connectedUsers.values());
  }

  getUserCount() {
    return this.connectedUsers.size;
  }

  getUsersByRole(role) {
    return this.getConnectedUsers().filter(user => user.userRole === role);
  }

  // Work progress broadcasting methods
  _broadcastWorkProgress(event, data, userId) {
    const targetRoles = data.targetRoles || [];
    const broadcastData = {
      ...data,
      updatedBy: userId,
      timestamp: new Date()
    };

    if (targetRoles.length === 0) {
      // Broadcast to all users
      this.io.emit(event, broadcastData);
    } else {
      // Broadcast to specific roles
      targetRoles.forEach(role => {
        this.io.to(`role:${role}`).emit(event, broadcastData);
      });
    }
  }

  _broadcastWorkAssignment(data, userId) {
    const targetRoles = data.targetRoles || [];
    const assigneeId = data.assigneeId;
    const broadcastData = {
      ...data,
      assignedBy: userId,
      timestamp: new Date()
    };

    // Send to assignee if specified
    if (assigneeId) {
      this.io.to(`user:${assigneeId}`).emit('work_assigned', broadcastData);
    }

    // Broadcast to target roles
    if (targetRoles.length > 0) {
      targetRoles.forEach(role => {
        this.io.to(`role:${role}`).emit('work_assigned', broadcastData);
      });
    } else {
      // Default broadcast to all users
      this.io.emit('work_assigned', broadcastData);
    }
  }

  _broadcastWorkCompletion(data, userId) {
    const targetRoles = data.targetRoles || [];
    const broadcastData = {
      ...data,
      completedBy: userId,
      timestamp: new Date()
    };

    if (targetRoles.length === 0) {
      // Broadcast to all users
      this.io.emit('work_completed', broadcastData);
    } else {
      // Broadcast to specific roles
      targetRoles.forEach(role => {
        this.io.to(`role:${role}`).emit('work_completed', broadcastData);
      });
    }
  }

  _broadcastRoleSync(data, userId) {
    const targetRoles = data.targetRoles || [];
    const broadcastData = {
      ...data,
      syncBy: userId,
      timestamp: new Date()
    };

    if (targetRoles.length === 0) {
      // Broadcast to all users
      this.io.emit('role_sync_update', broadcastData);
    } else {
      // Broadcast to specific roles
      targetRoles.forEach(role => {
        this.io.to(`role:${role}`).emit('role_sync_update', broadcastData);
      });
    }
  }
}

module.exports = new SocketService();
