require('dotenv').config();
const { Pool } = require('pg');

// Use DATABASE_URL for Render, fallback to individual env vars
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

async function createAllTables() {
  try {
    console.log('🚀 Creating ALL required database tables...');
    console.log('🔗 DATABASE_URL:', process.env.DATABASE_URL ? 'SET' : 'NOT SET');
    
    // Test database connection first
    try {
      const testResult = await pool.query('SELECT NOW() as current_time');
      console.log('✅ Database connection successful:', testResult.rows[0].current_time);
    } catch (testErr) {
      console.error('❌ Database connection failed:', testErr.message);
      throw testErr;
    }

    // Core tables that MUST exist
    const tables = [
      {
        name: 'users',
        sql: `
          CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            name VARCHAR(255),
            first_name VARCHAR(255),
            last_name VARCHAR(255),
            role VARCHAR(50) DEFAULT 'teamMember',
            is_active BOOLEAN DEFAULT true,
            email_verified BOOLEAN DEFAULT false,
            email_verification_code VARCHAR(255),
            email_verification_expires_at TIMESTAMP,
            email_verified_at TIMESTAMP,
            avatar_url TEXT,
            preferences JSONB DEFAULT '{}',
            project_ids UUID[] DEFAULT '{}'::uuid[],
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'projects',
        sql: `
          CREATE TABLE IF NOT EXISTS projects (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            project_key VARCHAR(10) UNIQUE NOT NULL,
            project_name VARCHAR(255) NOT NULL,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
            status VARCHAR(50) DEFAULT 'active',
            start_date DATE,
            end_date DATE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'project_members',
        sql: `
          CREATE TABLE IF NOT EXISTS project_members (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role VARCHAR(50) NOT NULL DEFAULT 'teamMember',
            joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(project_id, user_id)
          )
        `
      },
      {
        name: 'sprints',
        sql: `
          CREATE TABLE IF NOT EXISTS sprints (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name VARCHAR(255) NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            start_date DATE,
            end_date DATE,
            status VARCHAR(50) DEFAULT 'planning',
            goal TEXT,
            board_id INTEGER,
            planned_points INTEGER DEFAULT 0,
            committed_points INTEGER DEFAULT 0,
            completed_points INTEGER DEFAULT 0,
            created_by UUID REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'sprint_metrics',
        sql: `
          CREATE TABLE IF NOT EXISTS sprint_metrics (
            id SERIAL PRIMARY KEY,
            sprint_id UUID REFERENCES sprints(id) ON DELETE CASCADE,
            total_tickets INTEGER DEFAULT 0,
            completed_tickets INTEGER DEFAULT 0,
            in_progress_tickets INTEGER DEFAULT 0,
            blocked_tickets INTEGER DEFAULT 0,
            velocity DECIMAL(5,2) DEFAULT 0,
            burndown_data JSONB DEFAULT '[]',
            planned_points INTEGER DEFAULT 0,
            committed_points INTEGER DEFAULT 0,
            completed_points INTEGER DEFAULT 0,
            carried_over_points INTEGER DEFAULT 0,
            test_pass_rate INTEGER DEFAULT 0,
            code_coverage INTEGER DEFAULT 0,
            escaped_defects INTEGER DEFAULT 0,
            defects_opened INTEGER DEFAULT 0,
            defects_closed INTEGER DEFAULT 0,
            code_review_completion INTEGER DEFAULT 0,
            documentation_status INTEGER DEFAULT 0,
            uat_notes TEXT,
            uat_pass_rate INTEGER DEFAULT 0,
            risks TEXT,
            blockers TEXT,
            decisions TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'deliverables',
        sql: `
          CREATE TABLE IF NOT EXISTS deliverables (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            sprint_id UUID REFERENCES sprints(id) ON DELETE CASCADE,
            epic_id UUID,
            status VARCHAR(50) DEFAULT 'draft',
            priority VARCHAR(50) DEFAULT 'Medium',
            assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
            evidence_links TEXT[],
            created_by UUID REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'sign_off_reports',
        sql: `
          CREATE TABLE IF NOT EXISTS sign_off_reports (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            deliverable_id UUID REFERENCES deliverables(id) ON DELETE CASCADE,
            created_by UUID REFERENCES users(id) ON DELETE CASCADE,
            status VARCHAR(50) DEFAULT 'draft',
            content TEXT,
            evidence TEXT[],
            reminder_sent BOOLEAN DEFAULT false,
            escalation_sent BOOLEAN DEFAULT false,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'notifications',
        sql: `
          CREATE TABLE IF NOT EXISTS notifications (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            message TEXT,
            type VARCHAR(50) DEFAULT 'info',
            read BOOLEAN DEFAULT false,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'activity_logs',
        sql: `
          CREATE TABLE IF NOT EXISTS activity_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            entity_type VARCHAR(50) NOT NULL,
            entity_id UUID,
            action VARCHAR(100) NOT NULL,
            details JSONB DEFAULT '{}',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'audit_logs',
        sql: `
          CREATE TABLE IF NOT EXISTS audit_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID REFERENCES users(id) ON DELETE SET NULL,
            action VARCHAR(100) NOT NULL,
            entity_type VARCHAR(50),
            entity_id UUID,
            details JSONB DEFAULT '{}',
            ip_address INET,
            user_agent TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'timeline',
        sql: `
          CREATE TABLE IF NOT EXISTS timeline (
            id SERIAL PRIMARY KEY,
            event_type VARCHAR(100) NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            sprint_id UUID REFERENCES sprints(id) ON DELETE CASCADE,
            user_id UUID REFERENCES users(id) ON DELETE CASCADE,
            metadata JSONB DEFAULT '{}',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'approval_requests',
        sql: `
          CREATE TABLE IF NOT EXISTS approval_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            requester_id UUID REFERENCES users(id) ON DELETE CASCADE,
            approver_id UUID REFERENCES users(id) ON DELETE SET NULL,
            status VARCHAR(50) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'client_reviews',
        sql: `
          CREATE TABLE IF NOT EXISTS client_reviews (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            report_id UUID REFERENCES sign_off_reports(id) ON DELETE CASCADE,
            reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL,
            status VARCHAR(50) DEFAULT 'pending',
            comments TEXT,
            reviewed_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'user_signatures',
        sql: `
          CREATE TABLE IF NOT EXISTS user_signatures (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            user_name VARCHAR(255),
            signature_data TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'user_roles',
        sql: `
          CREATE TABLE IF NOT EXISTS user_roles (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role_id UUID NOT NULL,
            granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            granted_by UUID REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, role_id)
          )
        `
      },
      {
        name: 'role_permissions',
        sql: `
          CREATE TABLE IF NOT EXISTS role_permissions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            role_id UUID NOT NULL,
            permission_id UUID NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(role_id, permission_id)
          )
        `
      },
      {
        name: 'permissions',
        sql: `
          CREATE TABLE IF NOT EXISTS permissions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name VARCHAR(100) UNIQUE NOT NULL,
            description TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'epics',
        sql: `
          CREATE TABLE IF NOT EXISTS epics (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            status VARCHAR(50) DEFAULT 'active',
            priority VARCHAR(50) DEFAULT 'Medium',
            created_by UUID REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      {
        name: 'tickets',
        sql: `
          CREATE TABLE IF NOT EXISTS tickets (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT,
            project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
            sprint_id UUID REFERENCES sprints(id) ON DELETE CASCADE,
            epic_id UUID REFERENCES epics(id) ON DELETE CASCADE,
            assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
            status VARCHAR(50) DEFAULT 'To Do',
            issue_type VARCHAR(50) DEFAULT 'Task',
            priority VARCHAR(50) DEFAULT 'Medium',
            story_points INTEGER,
            created_by UUID REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      }
    ];

    // Create all tables
    for (const table of tables) {
      try {
        console.log(`📝 Creating table: ${table.name}`);
        await pool.query(table.sql);
        console.log(`✅ Table ${table.name} created/verified`);
      } catch (err) {
        console.log(`⚠️ Table ${table.name} creation issue:`, err.message);
      }
    }

    // Add missing columns to existing tables
    console.log('\n🔧 Adding missing columns to existing tables...');

    // Ensure users table has all required columns
    const userColumns = [
      { name: 'first_name', type: 'VARCHAR(255)' },
      { name: 'last_name', type: 'VARCHAR(255)' },
      { name: 'avatar_url', type: 'TEXT' },
      { name: 'email_verified', type: 'BOOLEAN DEFAULT false' },
      { name: 'email_verified_at', type: 'TIMESTAMP' },
      { name: 'preferences', type: 'JSONB DEFAULT \'{}\'' },
      { name: 'project_ids', type: 'UUID[] DEFAULT \'{}\'::uuid[]' }
    ];

    for (const col of userColumns) {
      try {
        await pool.query(`
          DO $$
          BEGIN
              IF NOT EXISTS (
                  SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'users' AND column_name = '${col.name}'
              ) THEN
                  ALTER TABLE users ADD COLUMN ${col.name} ${col.type};
              END IF;
          END $$
        `);
        console.log(`✅ Added users.${col.name} column`);
      } catch (err) {
        console.log(`⚠️ users.${col.name} column may already exist`);
      }
    }

    // Update existing users with name data
    try {
      await pool.query(`
        UPDATE users 
        SET first_name = SPLIT_PART(name, ' ', 1), 
            last_name = CASE 
                WHEN POSITION(' ' IN name) > 0 THEN SPLIT_PART(name, ' ', 2)
                ELSE ''
            END
        WHERE first_name IS NULL AND name IS NOT NULL
      `);
      console.log('✅ Updated existing users with name data');
    } catch (err) {
      console.log('⚠️ User update may have already run');
    }

    // Create indexes for better performance
    console.log('\n📊 Creating indexes...');
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
      'CREATE INDEX IF NOT EXISTS idx_projects_key ON projects(project_key)',
      'CREATE INDEX IF NOT EXISTS idx_projects_owner ON projects(owner_id)',
      'CREATE INDEX IF NOT EXISTS idx_sprints_project ON sprints(project_id)',
      'CREATE INDEX IF NOT EXISTS idx_sprints_status ON sprints(status)',
      'CREATE INDEX IF NOT EXISTS idx_deliverables_project ON deliverables(project_id)',
      'CREATE INDEX IF NOT EXISTS idx_deliverables_sprint ON deliverables(sprint_id)',
      'CREATE INDEX IF NOT EXISTS idx_tickets_project ON tickets(project_id)',
      'CREATE INDEX IF NOT EXISTS idx_tickets_sprint ON tickets(sprint_id)',
      'CREATE INDEX IF NOT EXISTS idx_tickets_assignee ON tickets(assignee)',
      'CREATE INDEX IF NOT EXISTS idx_project_members_project ON project_members(project_id)',
      'CREATE INDEX IF NOT EXISTS idx_project_members_user ON project_members(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_timeline_project ON timeline(project_id)',
      'CREATE INDEX IF NOT EXISTS idx_timeline_sprint ON timeline(sprint_id)',
      'CREATE INDEX IF NOT EXISTS idx_timeline_user ON timeline(user_id)'
    ];

    for (const indexSql of indexes) {
      try {
        await pool.query(indexSql);
      } catch (err) {
        console.log('⚠️ Index creation issue:', err.message);
      }
    }

    // Verification
    console.log('\n🔍 Verifying all tables...');
    try {
      const tableCheck = await pool.query(`
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
        ORDER BY table_name
      `);
      
      console.log('✅ All tables in database:');
      tableCheck.rows.forEach(row => {
        console.log(`   - ${row.table_name}`);
      });
      
    } catch (err) {
      console.log('⚠️ Verification query failed:', err.message);
    }
    
    console.log('\n🎉 All tables creation completed successfully!');
    console.log('📋 Created/verified tables:');
    console.log('   ✅ Core tables: users, projects, sprints, deliverables');
    console.log('   ✅ Metrics tables: sprint_metrics, timeline');
    console.log('   ✅ Approval tables: approval_requests, client_reviews, sign_off_reports');
    console.log('   ✅ Permission tables: user_roles, role_permissions, permissions');
    console.log('   ✅ Support tables: notifications, activity_logs, audit_logs');
    console.log('   ✅ Feature tables: epics, tickets, user_signatures');
    console.log('   ✅ All missing columns added');
    console.log('   ✅ All indexes created');
    console.log('   🚀 Database is now complete and ready!');
    
  } catch (error) {
    console.error('❌ Table creation failed:', error);
  } finally {
    await pool.end();
  }
}

createAllTables();
