const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const env = require('./config/env-loader');
const fs = require('fs');
const path = require('path');

// Prefer SQLite for local development unless Postgres is explicitly forced.
// This prevents startup failure when a local Postgres instance is not running.
try {
  const forcePostgres = String(process.env.FORCE_POSTGRES || '').toLowerCase() === 'true';
  const nodeEnv = String(process.env.NODE_ENV || 'development').toLowerCase();
  const isDevLike = nodeEnv !== 'production';
  const sqliteFile = path.resolve(__dirname, '..', 'database.sqlite');
  const hasLocalSqliteFile = fs.existsSync(sqliteFile);

  if (isDevLike && !forcePostgres && hasLocalSqliteFile) {
    // Set a few common env var names used by different config implementations.
    process.env.DB_DIALECT = 'sqlite';
    process.env.DIALECT = 'sqlite';
    process.env.USE_SQLITE = 'true';
    process.env.SQLITE_STORAGE = sqliteFile;
    process.env.SQLITE_DB_PATH = sqliteFile;

    // Ensure Sequelize doesn't attempt Postgres.
    delete process.env.DATABASE_URL;
  }
} catch (_) {}

const app = express();

// Add this logging middleware at the very beginning
app.use((req, res, next) => {
  console.log(`Incoming request: ${req.method} ${req.url}`);
  next();
});

// Import database configuration
const { testConnection, syncDatabase } = require('./config/database');

// Import models
const { sequelize, User, Notification, Ticket, ApprovalRequest } = require('./models');
const { QueryTypes, Op } = require('sequelize');

// Import middleware
const { loggingMiddleware } = require('./middleware/loggingMiddleware');
const { performanceMiddleware } = require('./middleware/performanceMiddleware');

// Import routes
const authRoutes = require('./routes/auth');
const { authenticateToken } = require('./middleware/auth');
const deliverablesRoutes = require('./routes/deliverables');
const sprintsRoutes = require('./routes/sprints');
const projectsRoutes = require('./routes/projects');
const analyticsRoutes = require('./routes/analytics');
const auditRoutes = require('./routes/audit');
const fileUploadRoutes = require('./routes/fileUpload');
const monitoringRoutes = require('./routes/monitoring');
const notificationsRoutes = require('./routes/notifications');
const profileRoutes = require('./routes/profile');
const settingsRoutes = require('./routes/settings');
const signoffRoutes = require('./routes/signoff');
const aiRoutes = require('./routes/ai');
const websocketRoutes = require('./routes/websocket');
const systemRoutes = require('./routes/system');
const usersRoutes = require('./routes/users');
const approvalsRoutes = require('./routes/approvals');
const documentsRoutes = require('./routes/documents');
const epicFeaturesRoutes = require('./routes/epicFeatures');
const timelineRoutes = require('./routes/timeline');

// Import services
const { presenceService } = require('./services/presenceService');
const { notificationService } = require('./services/notificationService');
const analyticsService = require('./services/analyticsService');
const { loggingService } = require('./services/loggingService');
const socketService = require('./services/socketService');
const { databaseNotificationService } = require('./services/DatabaseNotificationService');

// Middleware
app.use(helmet());
app.use(compression());
const defaultAllowedOrigins = [
  'http://localhost:3000',
  'http://localhost:5173',
  'http://localhost:5500',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:8080',
];
const envAllowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);
const allowedOrigins = envAllowedOrigins.length > 0 ? envAllowedOrigins : defaultAllowedOrigins;

app.use(cors({
  origin: function(origin, callback) {
    if (!origin) return callback(null, true);
    if (/^http:\/\/localhost:\d+$/.test(origin) || /^http:\/\/127\.0\.0\.1:\d+$/.test(origin)) {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  optionsSuccessStatus: 204
}));
app.options('*', cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Custom middleware
app.use(loggingMiddleware);
app.use(performanceMiddleware);
app.use(morgan('combined'));

try {
  const baseUploadDir = path.join(__dirname, '..', 'uploads');
  const profilePicturesDir = path.join(baseUploadDir, 'profile_pictures');
  fs.mkdirSync(profilePicturesDir, { recursive: true });
  app.use('/uploads', express.static(baseUploadDir));
} catch (e) {}

// Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/deliverables', deliverablesRoutes);
app.use('/api/v1/sprints', sprintsRoutes);
app.use('/api/v1/projects', projectsRoutes);
const { optionalAuthenticateToken } = require('./middleware/auth');
app.use('/api/v1/signoff', authenticateToken, signoffRoutes);
app.use('/api/v1/sign-off-reports', optionalAuthenticateToken, signoffRoutes);
const aiLimiter = rateLimit({ windowMs: 60 * 1000, max: 30 });
app.use('/api/v1/ai', authenticateToken, aiLimiter, aiRoutes);
app.use('/api/ai', authenticateToken, aiLimiter, aiRoutes);
app.use('/ai', authenticateToken, aiLimiter, aiRoutes);
app.use('/api/v1/audit', auditRoutes);
app.use('/api/v1/settings', settingsRoutes);
app.use('/api/v1/profile', profileRoutes);
app.use('/api/v1/ws', websocketRoutes);
app.use('/api/v1/notifications', notificationsRoutes);
app.use('/api/v1/files', fileUploadRoutes);
app.use('/api/v1/analytics', analyticsRoutes);
app.use('/api/v1/monitoring', monitoringRoutes);
app.use('/api/v1/system', systemRoutes);
app.use('/api/v1/users', usersRoutes);
app.use('/api/v1/approvals', authenticateToken, approvalsRoutes);
app.use('/api/v1/audit-logs', auditRoutes);
app.use('/api/v1/documents', documentsRoutes);
app.use('/api/v1/epic-features', epicFeaturesRoutes);
app.use('/api/v1/timeline', timelineRoutes);
app.post('/api/v1/iot/ingest', (req, res) => {
  try {
    const { topic, payload, roles, targetRoles, event } = req.body || {};
    const t = typeof topic === 'string' ? topic : '';
    const p = payload !== undefined ? payload : (event ? { event, payload: req.body } : req.body);
    const enriched = { ...(p || {}), roles: roles || targetRoles };
    socketService._handleIotMessage(t || 'iot/ingest', Buffer.from(JSON.stringify(enriched)));
    res.json({ success: true });
  } catch (e) {
    res.status(400).json({ success: false, error: 'invalid payload' });
  }
});

// Sprint tickets compatibility endpoints (minimal implementation to unblock UI)
app.get('/api/v1/sprints/:id/tickets', async (req, res) => {
  try {
    const sprintId = req.params.id;
    const tickets = await Ticket.findAll({
      where: { sprint_id: sprintId },
      order: [['updated_at', 'DESC']]
    });
    res.json({ success: true, data: tickets });
  } catch (error) {
    console.error('Error fetching sprint tickets:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message,
      stack: error.stack
    });
  }
});

app.post('/api/v1/tickets', async (req, res) => {
  try {
    const { sprintId, title, description, assignee, priority, type } = req.body || {};
    if (!sprintId || !title || !description) {
      return res.status(400).json({ success: false, error: 'Sprint ID, title, and description are required' });
    }
    const key = `T-${Date.now()}`;
    const created = await Ticket.create({
      ticket_id: key,
      ticket_key: key,
      sprint_id: parseInt(sprintId),
      summary: title,
      description,
      status: 'To Do',
      assignee: assignee || null,
      priority: (priority || 'medium').toString(),
      issue_type: (type || 'task').toString()
    });

    if (global.realtimeEvents) {
      global.realtimeEvents.emit('ticket_created', {
        id: created.id,
        ticket_id: created.ticket_id,
        ticket_key: created.ticket_key,
        sprint_id: created.sprint_id,
        summary: created.summary,
        status: created.status,
        priority: created.priority,
        assignee: created.assignee,
        created_at: created.created_at,
        updated_at: created.updated_at
      });
    }

    res.status(201).json({ success: true, data: created });
  } catch (error) {
    console.error('Error creating ticket:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.put('/api/v1/tickets/:ticketId/status', async (req, res) => {
  try {
    const { ticketId } = req.params;
    const { status } = req.body || {};
    if (!status) {
      return res.status(400).json({ success: false, error: 'Status is required' });
    }
    const ticket = await Ticket.findOne({ where: { ticket_id: ticketId } });
    if (!ticket) {
      return res.status(404).json({ success: false, error: 'Ticket not found' });
    }
    await ticket.update({ status });

    if (global.realtimeEvents) {
      global.realtimeEvents.emit('ticket_updated', {
        id: ticket.id,
        ticket_id: ticket.ticket_id,
        ticket_key: ticket.ticket_key,
        sprint_id: ticket.sprint_id,
        summary: ticket.summary,
        status: ticket.status,
        priority: ticket.priority,
        assignee: ticket.assignee,
        updated_at: ticket.updated_at
      });
    }

    res.json({ success: true, data: ticket });
  } catch (error) {
    console.error('Error updating ticket status:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.put('/api/v1/tickets/:ticketId', async (req, res) => {
  try {
    const { ticketId } = req.params;
    const updates = req.body || {};
    const ticket = await Ticket.findOne({ where: { ticket_id: ticketId } });
    if (!ticket) {
      return res.status(404).json({ success: false, error: 'Ticket not found' });
    }
    await ticket.update(updates);

    if (global.realtimeEvents) {
      global.realtimeEvents.emit('ticket_updated', {
        id: ticket.id,
        ticket_id: ticket.ticket_id,
        ticket_key: ticket.ticket_key,
        sprint_id: ticket.sprint_id,
        summary: ticket.summary,
        status: ticket.status,
        priority: ticket.priority,
        assignee: ticket.assignee,
        updated_at: ticket.updated_at
      });
    }

    res.json({ success: true, data: ticket });
  } catch (error) {
    console.error('Error updating ticket:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Public alias for system routes
app.use('/system', systemRoutes);

// Health check endpoints
app.get('/', (req, res) => {
  res.json({ message: 'Hackathon Backend API is running' });
});

app.get('/health', (req, res) => {
  const iotEnabled = String(process.env.IOT_ENABLED || '').toLowerCase() === 'true';
  res.json({ status: 'healthy', iot: { enabled: iotEnabled } });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong!'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Database connection and server startup
const PORT = process.env.PORT || 8000;

function isTruthy(value, defaultValue = false) {
  if (value === undefined || value === null || value === '') return defaultValue;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

async function startServer() {
  try {
    // Test database connection
    await sequelize.authenticate();
    const shouldSync =
      process.env.NODE_ENV === 'development' || isTruthy(process.env.DB_AUTO_SYNC, false);
    const shouldAlter = isTruthy(process.env.DB_AUTO_ALTER, false);
    const syncOk = shouldSync ? await syncDatabase({ alter: shouldAlter }) : true;
    console.log('✅ Database connection established successfully');
    if (!syncOk) {
      console.warn('⚠️ Database sync failed; continuing without alter sync');
    } else if (!shouldSync) {
      console.log('ℹ️ Database auto-sync disabled by environment settings');
    }

    try {
      if (sequelize.getDialect() === 'postgres') {
        await sequelize.query("ALTER TABLE sprints ADD COLUMN IF NOT EXISTS created_by VARCHAR(255)");
        await sequelize.query("ALTER TABLE projects ADD COLUMN IF NOT EXISTS owner_id UUID");
        await sequelize.query("ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_by UUID");
        // Ensure legacy audit_logs schema is compatible with current model.
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS user_email VARCHAR(255)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS user_role VARCHAR(100)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS session_id VARCHAR(500)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS ip_address VARCHAR(50)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS user_agent VARCHAR(500)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS action_category VARCHAR(100)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS entity_name VARCHAR(255)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS old_values JSONB");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS new_values JSONB");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS changed_fields JSONB");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS request_id VARCHAR(500)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS endpoint VARCHAR(500)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS http_method VARCHAR(10)");
        await sequelize.query("ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS status_code INTEGER");
      }
    } catch (e) {
      console.warn('⚠️ Unable to ensure compatibility columns; continuing', e?.message || e);
    }
    
    // Development-only safe sync (never run when DB_AUTO_SYNC is explicitly false)
    if (process.env.NODE_ENV === 'development' && shouldSync) {
      // Use safe sync instead of alter to prevent infinite loops
      try {
        await sequelize.sync({ force: false });
        console.log('✅ Database synchronized safely');
      } catch (error) {
        console.warn('⚠️ Database safe sync failed; continuing', error?.message || error);
      }
    }
    
    // Start server first to ensure it's listening
    const server = app.listen(PORT, () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📚 API Documentation: http://localhost:${PORT}/api-docs`);
      
      // Initialize Socket.io server
      socketService.initialize(server);
      console.log('✅ Socket.io server initialized for real-time communication');
      console.log('🔧 IoT MQTT status:', {
        enabled: String(process.env.IOT_ENABLED || '').toLowerCase() === 'true',
        url: process.env.IOT_MQTT_URL || ''
      });
      
      // Initialize Database Notification Service
      const dbConnectionString = process.env.DATABASE_URL;
      if (dbConnectionString) {
        databaseNotificationService.initialize(dbConnectionString)
          .then((ok) => {
            if (ok) {
              console.log('✅ Database notification service initialized');
              databaseNotificationService.setSocketService(socketService);
              console.log('✅ Real-time services integrated successfully');
            } else {
              console.warn('⚠️ Database notification service unavailable; continuing without LISTEN/NOTIFY');
            }
          })
          .catch(error => {
            console.error('❌ Failed to initialize database notification service:', error);
          });
      } else {
        console.warn('⚠️ DATABASE_URL not set, database notification service disabled');
      }
      
      // Start background services after server is listening
      // Analytics service is now started on-demand via API endpoints to prevent server overload
      loggingService.start().catch(error => {
        console.error('Failed to start logging service:', error);
      });
      
  console.log('✅ Background services started successfully');
  console.log(`🔗 Access your backend at: http://localhost:${PORT}/`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`🔗 API v1 endpoints: http://localhost:${PORT}/api/v1/`);
      console.log(`🔌 WebSocket endpoint: ws://localhost:${PORT}`);
      console.log(`🔧 IoT enabled: ${String(process.env.IOT_ENABLED || '').toLowerCase() === 'true'}`);
      const hasOpenRouter = !!(process.env.OPENROUTER_API_KEY || process.env.OpenRouter_API_KEY);
      console.log(hasOpenRouter ? '✅ OpenRouter API key detected' : '⚠️ OpenRouter API key missing');
      if (hasOpenRouter) {
        console.log(`🤖 AI chat endpoint ready: http://localhost:${PORT}/api/v1/ai/chat`);
      } else {
        console.warn('AI features disabled until OPENROUTER_API_KEY is set');
      }

      const schedulerService = require('./services/schedulerService');

      const runScheduledTasks = async () => {
        try {
          await schedulerService.runScheduledTasks();
        } catch (err) {
          console.error('Error in scheduled tasks:', err);
        }
      };

      runScheduledTasks();
      setInterval(runScheduledTasks, 30 * 60 * 1000);
    });
    server.on('error', (err) => {
      if (err && err.code === 'EADDRINUSE') {
        console.error(`Port ${PORT} is already in use; another instance is running. Continuing without starting a new server.`);
        return;
      }
      console.error('Server error:', err);
    });
    
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    setTimeout(() => {
      try { startServer(); } catch (_) {}
    }, 5000);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  
  // Stop background services
  await analyticsService.stop();
  await loggingService.stop();
  
  // Close database connection
  await sequelize.close();
  
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🛑 Received SIGINT, shutting down gracefully');
  
  // Stop background services
  await analyticsService.stop();
  await loggingService.stop();
  
  // Close database connection
  await sequelize.close();
  
  process.exit(0);
});

// Start the server
startServer();

module.exports = app;
process.on('uncaughtException', (err) => {
  try {
    console.error('Uncaught exception:', err);
  } catch (_) {}
});

process.on('unhandledRejection', (reason) => {
  try {
    console.error('Unhandled rejection:', reason);
  } catch (_) {}
});
