# Flow-Space Database Migration Guide

## 🎯 Overview

This guide helps you migrate and manage the Flow-Space database for both local development and production deployment on Render.

## 📁 Database Configuration Files

### Local Development
- **`.env`** - Local development database settings
- **`.env.local`** - Alternative local configuration file

### Production/Render
- **`.env.production`** - Production database settings (for reference)
- **Render Environment Variables** - Actual production settings

## 🗄️ Database Setup

### Local Development Database

Your local development uses PostgreSQL on `127.0.0.1:5432` with database name `flow_space`.

```bash
# Test local database connection
npm run test-db

# Run local migrations (if needed)
npm run migrate
```

### Production/Render Database

Your production database is hosted on Render:
- **Host**: `dpg-d6p6de5m5p6s73dlguqg-a.virginia-postgres.render.com`
- **Database**: `dssoh`
- **User**: `dssoh_user`

```bash
# Migrate Render database
npm run migrate-render

# Test Render database connection
npm run test-render
```

## 🔄 Environment-Specific Configuration

The application automatically detects the environment and uses the appropriate database:

### Development Environment
- Uses local PostgreSQL (`127.0.0.1:5432`)
- Reads from `.env` file
- SSL disabled

### Production/Render Environment
- Uses Render PostgreSQL database
- Uses `DATABASE_URL` environment variable
- SSL enabled with `rejectUnauthorized: false`

## 🚀 Migration Commands

### Local Development
```bash
# Test database connection
npm run test-db

# Run migrations
npm run migrate

# Check database status
npm run db-status
```

### Production/Render
```bash
# Migrate Render database
npm run migrate-render

# Test Render database
npm run test-render
```

## 📋 Database Schema

The migration creates the following tables:

### Core Tables
- **users** - User accounts and authentication
- **projects** - Project management
- **deliverables** - Project deliverables
- **sprints** - Sprint management

### Supporting Tables
- **approval_requests** - Deliverable approvals
- **notifications** - User notifications
- **audit_logs** - Audit trail
- **user_sessions** - Session management

### Additional Tables
- **activity_logs** - Activity tracking
- **client_reviews** - Client review management
- **documents** - Document management
- **epics** - Epic management
- **permissions** - Role permissions
- **project_members** - Project team assignments
- **sign_off_reports** - Sign-off reports
- **tickets** - Issue tracking
- **user_roles** - User role definitions

## 🔑 Default Admin User

A default admin user is created during migration:

**Email**: `admin@flownet.works`  
**Password**: `admin123`  
**Role**: `system_admin`

⚠️ **IMPORTANT**: Change the default password after first login!

## 🛠️ Database Features

### Indexes
- Performance indexes on frequently queried columns
- Unique constraints on emails and project keys
- Composite indexes for complex queries

### Triggers
- Automatic `updated_at` timestamp updates
- Data consistency checks

### Views
- `active_users` - Active user accounts
- `project_summary` - Project overview with statistics
- `user_project_assignments` - User-project relationships

### Security
- Row Level Security (RLS) ready (optional)
- Password hashing with bcrypt
- JWT token authentication

## 📊 Connection Testing

### Local Database Test
```bash
cd backend
npm run test-db
```

Expected output:
```
🌍 Environment: development
🚀 Render Deployed: NO
🏠 Using Local Development Database
📊 Local DB: postgres@127.0.0.1:5432/flow_space
✅ Connected to PostgreSQL database (development)
🎉 All database tests passed!
```

### Render Database Test
```bash
cd backend
npm run test-render
```

Expected output:
```
🚀 Starting Flow-Space Render Database Migration...
📊 Target Database: dssoh (PostgreSQL on Render)
✅ Connected to Render database: dssoh
🎉 Render database migration completed successfully!
```

## 🔧 Troubleshooting

### Common Issues

#### Connection Refused
```bash
Error: ECONNREFUSED
```
**Solution**: Check if PostgreSQL is running locally
```bash
# Windows
net start postgresql

# macOS/Linux
brew services start postgresql
# or
sudo systemctl start postgresql
```

#### Authentication Failed
```bash
Error: password authentication failed for user "postgres"
```
**Solution**: Verify database credentials in `.env` file

#### Database Doesn't Exist
```bash
Error: database "flow_space" does not exist
```
**Solution**: Create the database
```sql
CREATE DATABASE flow_space;
```

#### SSL Issues (Production)
```bash
Error: SSL SYSCALL error: EOF detected
```
**Solution**: The database pool is configured with `rejectUnauthorized: false` for Render compatibility.

### Environment Detection

The application uses these environment variables to detect the deployment environment:

- `NODE_ENV=production` - Production mode
- `RENDER=true` - Render deployment
- `RENDER_SERVICE_ID` - Render service identifier

## 📝 Migration Files

### `001_initial_schema.sql`
- Complete database schema
- Tables, indexes, triggers, and views
- Default admin user creation
- Extensions and configuration

### `run-migration.js`
- Local database migration runner
- Uses environment-specific configuration
- Comprehensive logging and error handling

### `migrate-render.js`
- Render database migration runner
- Direct connection to Render database
- Production-ready error handling

## 🚀 Deployment Steps

### 1. Local Development Setup
```bash
# Clone repository
git clone <repository-url>
cd Flow-Space/backend

# Install dependencies
npm install

# Test local database
npm run test-db

# Start development server
npm run dev
```

### 2. Production Deployment
```bash
# Migrate Render database
npm run migrate-render

# Deploy to Render
# (Render will automatically set DATABASE_URL)
```

### 3. Post-Deployment
```bash
# Test production database
npm run test-render

# Change default admin password
# (Login to app and update password)
```

## 📞 Support

If you encounter issues:

1. Check the error messages in the console
2. Verify environment variables are set correctly
3. Ensure database is running and accessible
4. Review the troubleshooting section above

## 🔄 Backup and Recovery

### Local Backup
```bash
pg_dump -h 127.0.0.1 -U postgres flow_space > backup.sql
```

### Render Backup
Render provides automatic backups. Check your Render dashboard for backup settings.

### Recovery
```bash
# Local
psql -h 127.0.0.1 -U postgres flow_space < backup.sql

# Render (use Render dashboard or migrate-render.js)
```

---

**Last Updated**: March 2026  
**Version**: 1.0.0  
**Database**: PostgreSQL 16+
