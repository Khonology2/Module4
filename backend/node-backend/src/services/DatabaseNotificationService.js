const { Client } = require('pg');
const EventEmitter = require('events');
const { loggingService, LogLevel, LogCategory } = require('./loggingService');

class DatabaseNotificationService extends EventEmitter {
    constructor() {
        super();
        this.client = null;
        this.isConnected = false;
        this.listeners = new Map();
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
        this.reconnectDelay = 5000; // 5 seconds
        this.socketService = null;
        this.modelEventsInitialized = false;
        
        // Set up global event emitter for model hooks
        this.setupGlobalEventEmitter();
    }

    shouldUseSsl(connectionString) {
        if (String(process.env.NODE_ENV || '').toLowerCase() !== 'production') return false;
        const cs = (connectionString || '').toString();
        if (/sslmode=disable/i.test(cs)) return false;
        return true;
    }

    /**
     * Initialize the database notification service
     * @param {string} connectionString - PostgreSQL connection string
     */
    async initialize(connectionString) {
        try {
            const ssl = this.shouldUseSsl(connectionString)
                ? { rejectUnauthorized: false }
                : undefined;

            this.client = new Client({
                connectionString,
                ssl,
                connectionTimeoutMillis: 10000,
                keepAlive: true
            });

            // Set up event handlers
            this.client.on('notification', this.handleNotification.bind(this));
            this.client.on('error', this.handleError.bind(this));
            this.client.on('end', this.handleDisconnect.bind(this));

            await this.client.connect();
            this.isConnected = true;
            this.reconnectAttempts = 0;

            // Listen to all relevant channels
            await this.listenToChannels([
                'table_changes',
                'role_changes', 
                'user_presence'
            ]);

            loggingService.log(LogLevel.INFO, LogCategory.DATABASE, 
                'Database notification service initialized and connected',
                null,
                { channels: ['table_changes', 'role_changes', 'user_presence'] }
            );

            return true;
        } catch (error) {
            loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                'Failed to initialize database notification service',
                error,
                { connectionString: this.maskConnectionString(connectionString) }
            );
            
            await this.attemptReconnect(connectionString);
            return false;
        }
    }

    /**
     * Listen to specific PostgreSQL channels
     * @param {string[]} channels - Array of channel names to listen to
     */
    async listenToChannels(channels) {
        if (!this.isConnected || !this.client) {
            throw new Error('Database notification service not connected');
        }

        for (const channel of channels) {
            try {
                await this.client.query(`LISTEN ${channel}`);
                loggingService.log(LogLevel.INFO, LogCategory.DATABASE,
                    `Listening to database channel: ${channel}`
                );
            } catch (error) {
                loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                    `Failed to listen to channel: ${channel}`,
                    error
                );
            }
        }
    }

    /**
     * Handle incoming database notifications
     * @param {Object} msg - PostgreSQL notification message
     */
    handleNotification(msg) {
        try {
            const { channel, payload } = msg;
            const data = JSON.parse(payload);

            loggingService.log(LogLevel.DEBUG, LogCategory.DATABASE,
                `Received database notification from channel: ${channel}`,
                null,
                { channel, data }
            );

            // Notify all listeners for this channel
            if (this.listeners.has(channel)) {
                const channelListeners = this.listeners.get(channel);
                for (const listener of channelListeners) {
                    try {
                        listener(data, channel);
                    } catch (error) {
                        loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                            'Error in notification listener',
                            error,
                            { channel, listener: listener.toString() }
                        );
                    }
                }
            }

            // Also notify wildcard listeners
            if (this.listeners.has('*')) {
                const wildcardListeners = this.listeners.get('*');
                for (const listener of wildcardListeners) {
                    try {
                        listener(data, channel);
                    } catch (error) {
                        loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                            'Error in wildcard notification listener',
                            error,
                            { channel, listener: listener.toString() }
                        );
                    }
                }
            }

        } catch (error) {
            loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                'Error processing database notification',
                error,
                { message: msg }
            );
        }
    }

    /**
     * Add a listener for specific channel or all channels
     * @param {string} channel - Channel name or '*' for all channels
     * @param {Function} listener - Callback function
     */
    addListener(channel, listener) {
        if (!this.listeners.has(channel)) {
            this.listeners.set(channel, []);
        }
        this.listeners.get(channel).push(listener);

        loggingService.log(LogLevel.INFO, LogCategory.DATABASE,
            `Added listener for channel: ${channel}`,
            null,
            { listenerCount: this.listeners.get(channel).length }
        );
    }

    /**
     * Remove a listener
     * @param {string} channel - Channel name
     * @param {Function} listener - Callback function to remove
     */
    removeListener(channel, listener) {
        if (this.listeners.has(channel)) {
            const listeners = this.listeners.get(channel);
            const index = listeners.indexOf(listener);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
    }

    /**
     * Handle database connection errors
     * @param {Error} error - Connection error
     */
    handleError(error) {
        loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
            'Database notification service connection error',
            error
        );

        this.isConnected = false;
        this.cleanup();
    }

    /**
     * Handle database disconnection
     */
    handleDisconnect() {
        loggingService.log(LogLevel.WARN, LogCategory.DATABASE,
            'Database notification service disconnected'
        );

        this.isConnected = false;
        this.cleanup();
    }

    /**
     * Attempt to reconnect to the database
     * @param {string} connectionString - PostgreSQL connection string
     */
    async attemptReconnect(connectionString) {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            loggingService.log(LogLevel.ERROR, LogCategory.DATABASE,
                'Max reconnection attempts reached. Giving up.'
            );
            return;
        }

        this.reconnectAttempts++;
        const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

        loggingService.log(LogLevel.INFO, LogCategory.DATABASE,
            `Attempting to reconnect in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`
        );

        setTimeout(async () => {
            try {
                await this.initialize(connectionString);
            } catch (error) {
                await this.attemptReconnect(connectionString);
            }
        }, delay);
    }

    /**
     * Clean up resources
     */
    cleanup() {
        if (this.client) {
            this.client.removeAllListeners();
            this.client.end().catch(() => {});
            this.client = null;
        }
    }

    /**
     * Get service status
     */
    getStatus() {
        return {
            isConnected: this.isConnected,
            reconnectAttempts: this.reconnectAttempts,
            listenerCount: this.listeners.size,
            channels: Array.from(this.listeners.keys())
        };
    }

    /**
     * Set up global event emitter for model hooks
     */
    setupGlobalEventEmitter() {
        // Create global event emitter if it doesn't exist
        if (!global.realtimeEvents) {
            const EventEmitter = require('events');
            global.realtimeEvents = new EventEmitter();
            
            // Set up listeners for model events
            this.setupModelEventListeners();
        }
    }

    /**
     * Set up listeners for model events and forward to socket service
     */
    setupModelEventListeners() {
        if (!global.realtimeEvents) return;
        if (this.modelEventsInitialized) return;

        const { User, Notification } = require('../models');
        const { Op } = require('sequelize');

        const broadcastAll = (event, data) => {
            if (this.socketService) {
                this.socketService.broadcastToAll(event, data);
            }
        };

        const broadcastRoles = (roles, event, data) => {
            if (this.socketService) {
                roles.forEach(r => this.socketService.broadcastToRole(r, event, data));
            }
        };

        const notifyAll = async (type, message, payload, senderId = null) => {
            const users = await User.findAll({ where: { is_active: true } });
            const notifications = users.map(u => ({
                recipient_id: u.id,
                sender_id: senderId,
                type,
                message,
                payload,
                is_read: false,
                created_at: new Date()
            }));
            if (notifications.length > 0) {
                await Notification.bulkCreate(notifications);
                broadcastAll('notification_received', { type, message, payload });
            }
        };

        const notifyRoles = async (roles, type, message, payload, senderId = null) => {
            const roleVariants = roles.flatMap(r => [r, r.charAt(0).toUpperCase() + r.slice(1), r.toLowerCase()]);
            const recipients = await User.findAll({ where: { role: { [Op.in]: roleVariants }, is_active: true } });
            const notifications = recipients.map(u => ({
                recipient_id: u.id,
                sender_id: senderId,
                type,
                message,
                payload,
                is_read: false,
                created_at: new Date()
            }));
            if (notifications.length > 0) {
                await Notification.bulkCreate(notifications);
                broadcastRoles(roleVariants, 'notification_received', { type, message, payload });
            }
        };

        global.realtimeEvents.on('deliverable_created', async (data) => {
            const title = data && data.title ? data.title : 'Deliverable';
            await notifyAll('deliverable', `Deliverable created: ${title}`, { deliverable_id: data && data.id });
            broadcastAll('deliverable_created', data);
        });

        global.realtimeEvents.on('deliverable_updated', async (data) => {
            const title = data && data.title ? data.title : 'Deliverable';
            await notifyRoles(['deliveryLead','scrumMaster','developer','qaEngineer','projectManager'], 'deliverable', `Deliverable updated: ${title}`, { deliverable_id: data && data.id });
            broadcastAll('deliverable_updated', data);
        });

        global.realtimeEvents.on('ticket_created', async (data) => {
            const summary = data && (data.summary || data.title) ? (data.summary || data.title) : 'Ticket';
            await notifyRoles(['deliveryLead','scrumMaster','developer','qaEngineer','projectManager'], 'ticket', `Ticket created: ${summary}`, { ticket_id: data && (data.ticket_id || data.id), sprint_id: data && data.sprint_id });
            broadcastAll('ticket_created', data);
        });

        global.realtimeEvents.on('ticket_updated', async (data) => {
            const summary = data && (data.summary || data.title) ? (data.summary || data.title) : 'Ticket';
            await notifyRoles(['deliveryLead','scrumMaster','developer','qaEngineer','projectManager'], 'ticket', `Ticket updated: ${summary}`, { ticket_id: data && (data.ticket_id || data.id), sprint_id: data && data.sprint_id });
            broadcastAll('ticket_updated', data);
        });

        global.realtimeEvents.on('ticket_deleted', async (data) => {
            const summary = data && (data.summary || data.title) ? (data.summary || data.title) : 'Ticket';
            await notifyRoles(['deliveryLead','scrumMaster','developer','qaEngineer','projectManager'], 'ticket', `Ticket deleted: ${summary}`, { ticket_id: data && (data.ticket_id || data.id), sprint_id: data && data.sprint_id });
            broadcastAll('ticket_deleted', data);
        });

        global.realtimeEvents.on('sprint_created', async (data) => {
            const name = data && data.name ? data.name : 'Sprint';
            await notifyAll('sprint', `Sprint created: ${name}`, { sprint_id: data && data.id });
            broadcastAll('sprint_created', data);
        });

        global.realtimeEvents.on('sprint_updated', async (data) => {
            const name = data && data.name ? data.name : 'Sprint';
            await notifyRoles(['deliveryLead','scrumMaster','developer','qaEngineer','projectManager'], 'sprint', `Sprint updated: ${name}`, { sprint_id: data && data.id });
            broadcastAll('sprint_updated', data);
        });

        global.realtimeEvents.on('project_created', async (data) => {
            const name = data && data.name ? data.name : 'Project';
            await notifyAll('project', `Project created: ${name}`, { project_id: data && data.id });
            broadcastAll('project_created', data);
        });

        global.realtimeEvents.on('project_updated', async (data) => {
            const name = data && data.name ? data.name : 'Project';
            await notifyRoles(['deliveryLead','projectManager','scrumMaster','developer','qaEngineer'], 'project', `Project updated: ${name}`, { project_id: data && data.id });
            broadcastAll('project_updated', data);
        });

        global.realtimeEvents.on('report_created', async (data) => {
            const title = data && data.reportTitle ? data.reportTitle : 'Sign-Off Report';
            const senderId = data && data.created_by && /^[0-9a-fA-F-]{36}$/.test(data.created_by) ? data.created_by : null;
            await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'approval', `Report created: ${title}`, { report_id: data && data.id, action_url: `/enhanced-client-review/${data && data.id}` }, senderId);
        });

        global.realtimeEvents.on('document_uploaded', async (data) => {
            const name = data && (data.name || data.originalName || data.filename) ? (data.name || data.originalName || data.filename) : 'Document';
            const senderId = data && data.uploaded_by && /^[0-9a-fA-F-]{36}$/.test(String(data.uploaded_by)) ? String(data.uploaded_by) : null;
            try {
                await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'document', `Document uploaded: ${name}`, { document_id: data && (data.id || data.filename), url: data && (data.file_path || data.url) }, senderId);
            } catch (_) {}
            broadcastAll('document_uploaded', data);
        });

        global.realtimeEvents.on('document_deleted', async (data) => {
            const docId = data && (data.id || data.document_id);
            try {
                await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'document', `Document deleted`, { document_id: docId }, null);
            } catch (_) {}
            broadcastAll('document_deleted', data);
        });

        global.realtimeEvents.on('report_submitted', async (data) => {
            const title = data && data.reportTitle ? data.reportTitle : 'Sign-Off Report';
            const senderId = data && data.created_by && /^[0-9a-fA-F-]{36}$/.test(data.created_by) ? data.created_by : null;
            await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'approval', `Report submitted: ${title}`, { report_id: data && data.id, action_url: `/enhanced-client-review/${data && data.id}` }, senderId);
        });

        global.realtimeEvents.on('report_approved', async (data) => {
            const title = data && data.reportTitle ? data.reportTitle : 'Sign-Off Report';
            const senderId = data && data.created_by && /^[0-9a-fA-F-]{36}$/.test(data.created_by) ? data.created_by : null;
            await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'approval', `Report approved: ${title}`, { report_id: data && data.id, action_url: `/enhanced-client-review/${data && data.id}` }, senderId);
        });

        global.realtimeEvents.on('report_change_requested', async (data) => {
            const title = data && data.reportTitle ? data.reportTitle : 'Sign-Off Report';
            const senderId = data && data.created_by && /^[0-9a-fA-F-]{36}$/.test(data.created_by) ? data.created_by : null;
            await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'change_request', `Changes requested: ${title}`, { report_id: data && data.id, action_url: `/enhanced-client-review/${data && data.id}` }, senderId);
        });

        this.modelEventsInitialized = true;
    }

    /**
     * Set the socket service for event forwarding
     * @param {Object} socketService - Socket service instance
     */
    setSocketService(socketService) {
        this.socketService = socketService;
        
        // Re-setup model event listeners to ensure they use the new socket service
        if (global.realtimeEvents) {
            this.setupModelEventListeners();
        }
        
        loggingService.log(LogLevel.INFO, LogCategory.WEBSOCKET,
            'Socket service integrated with database notification service'
        );
    }

    /**
     * Mask sensitive information in connection string
     * @param {string} connectionString - Original connection string
     */
    maskConnectionString(connectionString) {
        return connectionString.replace(/:[^:@]*@/, ':****@');
    }

    /**
     * Shutdown the service gracefully
     */
    async shutdown() {
        loggingService.log(LogLevel.INFO, LogCategory.DATABASE,
            'Shutting down database notification service'
        );

        this.cleanup();
        this.listeners.clear();
        this.isConnected = false;
    }
}

// Global instance
const databaseNotificationService = new DatabaseNotificationService();

module.exports = {
    DatabaseNotificationService,
    databaseNotificationService
};
        global.realtimeEvents.on('report_updated', async (data) => {
            const title = data && data.reportTitle ? data.reportTitle : 'Sign-Off Report';
            try {
                await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'approval', `Report updated: ${title}`, { report_id: data && data.id, status: data && data.status }, null);
            } catch (_) {}
            broadcastAll('report_updated', data);
        });

        global.realtimeEvents.on('report_deleted', async (data) => {
            try {
                await notifyRoles(['clientReviewer','deliveryLead','systemAdmin'], 'approval', `Report deleted`, { report_id: data && data.id }, null);
            } catch (_) {}
            broadcastAll('report_deleted', data);
        });
