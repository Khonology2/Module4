-- Database Migration Script for Flow-Space
-- Target: PostgreSQL (Render)
-- Database: dssoh

-- ===========================================
-- 1. CREATE EXTENSIONS
-- ===========================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===========================================
-- 2. USERS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name || ' ' || last_name, email)
    ) STORED,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'team_member',
    is_active BOOLEAN DEFAULT true,
    email_verified BOOLEAN DEFAULT false,
    email_verified_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    avatar_url TEXT,
    preferences JSONB DEFAULT '{}',
    project_ids TEXT[] DEFAULT '{}'
);

-- ===========================================
-- 3. PROJECTS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    key VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    client_name VARCHAR(255),
    project_type VARCHAR(100) DEFAULT 'Software Development',
    status VARCHAR(50) DEFAULT 'planning',
    priority VARCHAR(20) DEFAULT 'medium',
    start_date DATE,
    end_date DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(id),
    owner_id UUID REFERENCES users(id),
    tags TEXT[] DEFAULT '{}',
    members JSONB DEFAULT '[]'
);

-- ===========================================
-- 4. DELIVERABLES TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS deliverables (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'draft',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to UUID REFERENCES users(id),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_date TIMESTAMP,
    completion_date TIMESTAMP,
    tags TEXT[] DEFAULT '{}',
    file_attachments JSONB DEFAULT '[]',
    approval_status VARCHAR(50) DEFAULT 'pending',
    submission_notes TEXT
);

-- ===========================================
-- 5. SPRINTS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS sprints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'planning',
    start_date DATE,
    end_date DATE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    goals JSONB DEFAULT '[]',
    deliverable_ids UUID[] DEFAULT '{}'
);

-- ===========================================
-- 6. APPROVAL REQUESTS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS approval_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deliverable_id UUID REFERENCES deliverables(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    requested_by UUID REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMP,
    review_notes TEXT,
    evidence_links TEXT[] DEFAULT '{}'
);

-- ===========================================
-- 7. NOTIFICATIONS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50) DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    related_id UUID,
    related_type VARCHAR(50)
);

-- ===========================================
-- 8. AUDIT LOGS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===========================================
-- 9. USER SESSIONS TABLE
-- ===========================================
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true
);

-- ===========================================
-- 10. CREATE INDEXES
-- ===========================================

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Projects table indexes
CREATE INDEX IF NOT EXISTS idx_projects_key ON projects(key);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_created_by ON projects(created_by);
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON projects(owner_id);

-- Deliverables table indexes
CREATE INDEX IF NOT EXISTS idx_deliverables_project_id ON deliverables(project_id);
CREATE INDEX IF NOT EXISTS idx_deliverables_status ON deliverables(status);
CREATE INDEX IF NOT EXISTS idx_deliverables_assigned_to ON deliverables(assigned_to);
CREATE INDEX IF NOT EXISTS idx_deliverables_due_date ON deliverables(due_date);

-- Sprints table indexes
CREATE INDEX IF NOT EXISTS idx_sprints_project_id ON sprints(project_id);
CREATE INDEX IF NOT EXISTS idx_sprints_status ON sprints(status);
CREATE INDEX IF NOT EXISTS idx_sprints_dates ON sprints(start_date, end_date);

-- Approval requests table indexes
CREATE INDEX IF NOT EXISTS idx_approval_requests_deliverable_id ON approval_requests(deliverable_id);
CREATE INDEX IF NOT EXISTS idx_approval_requests_status ON approval_requests(status);
CREATE INDEX IF NOT EXISTS idx_approval_requests_requested_by ON approval_requests(requested_by);

-- Notifications table indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);

-- Audit logs table indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- User sessions table indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

-- ===========================================
-- 11. CREATE TRIGGERS FOR UPDATED_AT
-- ===========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deliverables_updated_at BEFORE UPDATE ON deliverables
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sprints_updated_at BEFORE UPDATE ON sprints
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_approval_requests_updated_at BEFORE UPDATE ON approval_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===========================================
-- 12. CREATE VIEWS
-- ===========================================

-- Active users view
CREATE OR REPLACE VIEW active_users AS
SELECT * FROM users WHERE is_active = true;

-- Project summary view
CREATE OR REPLACE VIEW project_summary AS
SELECT 
    p.id,
    p.name,
    p.key,
    p.status,
    p.start_date,
    p.end_date,
    COUNT(d.id) as deliverable_count,
    COUNT(CASE WHEN d.status = 'completed' THEN 1 END) as completed_deliverables,
    COUNT(s.id) as sprint_count,
    p.created_at
FROM projects p
LEFT JOIN deliverables d ON p.id = d.project_id
LEFT JOIN sprints s ON p.id = s.project_id
GROUP BY p.id, p.name, p.key, p.status, p.start_date, p.end_date, p.created_at;

-- User project assignments view
CREATE OR REPLACE VIEW user_project_assignments AS
SELECT 
    u.id as user_id,
    u.name as user_name,
    u.email,
    p.id as project_id,
    p.name as project_name,
    p.key as project_key,
    p.status as project_status
FROM users u
CROSS JOIN LATERAL jsonb_array_elements(p.members) member
JOIN projects p ON member->>'id' = u.id
WHERE u.is_active = true;

-- ===========================================
-- 13. INSERT DEFAULT DATA
-- ===========================================

-- Insert default admin user (if not exists)
INSERT INTO users (id, email, first_name, last_name, password_hash, role, is_active, email_verified)
SELECT 
    uuid_generate_v4(),
    'admin@flownet.works',
    'System',
    'Administrator',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', -- password: admin123
    'system_admin',
    true,
    true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@flownet.works');

-- ===========================================
-- 14. SET UP ROW LEVEL SECURITY (Optional)
-- ===========================================

-- Enable RLS for sensitive tables
-- ALTER TABLE users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE deliverables ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (examples)
-- CREATE POLICY users_own_profile ON users FOR ALL USING (id = current_setting('app.current_user_id')::uuid);

-- ===========================================
-- 15. COMPLETION MESSAGE
-- ===========================================

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE 'Flow-Space Database Migration Completed!';
    RAISE NOTICE '=========================================';
    RAISE NOTICE 'Database: dssoh';
    RAISE NOTICE 'Tables created: 10';
    RAISE NOTICE 'Indexes created: 25+';
    RAISE NOTICE 'Views created: 3';
    RAISE NOTICE 'Triggers created: 5';
    RAISE NOTICE 'Default admin user: admin@flownet.works (password: admin123)';
    RAISE NOTICE '=========================================';
END $$;
