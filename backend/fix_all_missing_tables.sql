-- ============================================
-- Flow-Space: Fix All Missing Tables and Columns
-- ============================================

-- 1. Add missing created_by column to sprints table (fix TEXT vs UUID issue)
DO $$
BEGIN
    -- Check if column exists and its type
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sprints' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE sprints ADD COLUMN created_by TEXT;
    END IF;
END $$;

-- 2. Ensure sprint_metrics table has all required columns
DO $$
BEGIN
    -- Create sprint_metrics table if it doesn't exist
    CREATE TABLE IF NOT EXISTS sprint_metrics (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sprint_id UUID REFERENCES sprints(id) ON DELETE CASCADE,
        planned_points INTEGER DEFAULT 0,
        committed_points INTEGER DEFAULT 0,
        completed_points INTEGER DEFAULT 0,
        carried_over_points INTEGER DEFAULT 0,
        test_pass_rate DECIMAL(5,2) DEFAULT 0.00,
        code_coverage DECIMAL(5,2) DEFAULT 0.00,
        escaped_defects INTEGER DEFAULT 0,
        defects_opened INTEGER DEFAULT 0,
        defects_closed INTEGER DEFAULT 0,
        code_review_completion DECIMAL(5,2) DEFAULT 0.00,
        documentation_status TEXT DEFAULT 'pending',
        uat_notes TEXT,
        uat_pass_rate DECIMAL(5,2) DEFAULT 0.00,
        points_added_during_sprint INTEGER DEFAULT 0,
        points_removed_during_sprint INTEGER DEFAULT 0,
        scope_changes TEXT,
        blockers TEXT,
        decisions TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        UNIQUE(sprint_id)
    );

    -- Add any missing columns to existing sprint_metrics table
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS planned_points INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS committed_points INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS completed_points INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS carried_over_points INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS test_pass_rate DECIMAL(5,2) DEFAULT 0.00;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS code_coverage DECIMAL(5,2) DEFAULT 0.00;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS escaped_defects INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS defects_opened INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS defects_closed INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS code_review_completion DECIMAL(5,2) DEFAULT 0.00;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS documentation_status TEXT DEFAULT 'pending';
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS uat_notes TEXT;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS uat_pass_rate DECIMAL(5,2) DEFAULT 0.00;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS points_added_during_sprint INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS points_removed_during_sprint INTEGER DEFAULT 0;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS scope_changes TEXT;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS blockers TEXT;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS decisions TEXT;
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    ALTER TABLE sprint_metrics ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
END $$;

-- 3. Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Apply updated_at trigger to sprint_metrics
DROP TRIGGER IF EXISTS update_sprint_metrics_updated_at ON sprint_metrics;
CREATE TRIGGER update_sprint_metrics_updated_at 
    BEFORE UPDATE ON sprint_metrics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. Create indexes for sprint_metrics
CREATE INDEX IF NOT EXISTS idx_sprint_metrics_sprint ON sprint_metrics(sprint_id);

-- 6. Create tickets table (if missing)
CREATE TABLE IF NOT EXISTS tickets (
    ticket_id TEXT PRIMARY KEY,
    ticket_key TEXT UNIQUE NOT NULL,
    summary TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'To Do' CHECK (status IN ('To Do', 'In Progress', 'Done', 'Blocked')),
    issue_type TEXT DEFAULT 'Task' CHECK (issue_type IN ('Task', 'Bug', 'Story', 'Epic', 'Subtask')),
    priority TEXT DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    assignee TEXT,
    reporter TEXT,
    sprint_id TEXT,
    project_id TEXT,
    user_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Create activity_log table (if missing)
CREATE TABLE IF NOT EXISTS activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    activity_title VARCHAR(255) NOT NULL,
    activity_description TEXT,
    deliverable_id TEXT,
    sprint_id TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Add missing columns to projects table
ALTER TABLE projects ADD COLUMN IF NOT EXISTS key TEXT UNIQUE;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS project_type TEXT DEFAULT 'software';
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_by TEXT;

-- 9. Add missing columns to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS deliverable_id TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS sprint_id TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS action_url TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 10. Add missing columns to deliverables table
ALTER TABLE deliverables ADD COLUMN IF NOT EXISTS progress DECIMAL(5,2) DEFAULT 0.00 CHECK (progress >= 0 AND progress <= 100);
ALTER TABLE deliverables ADD COLUMN IF NOT EXISTS sprint_id TEXT;
ALTER TABLE deliverables ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'Medium';

-- 11. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tickets_sprint_id ON tickets(sprint_id);
CREATE INDEX IF NOT EXISTS idx_tickets_project_id ON tickets(project_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_assignee ON tickets(assignee);
CREATE INDEX IF NOT EXISTS idx_tickets_user_id ON tickets(user_id);

CREATE INDEX IF NOT EXISTS idx_activity_log_user_id ON activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_deliverable_id ON activity_log(deliverable_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_created_at ON activity_log(created_at);

CREATE INDEX IF NOT EXISTS idx_projects_key ON projects(key);
CREATE INDEX IF NOT EXISTS idx_projects_created_by ON projects(created_by);

CREATE INDEX IF NOT EXISTS idx_notifications_deliverable_id ON notifications(deliverable_id);
CREATE INDEX IF NOT EXISTS idx_notifications_sprint_id ON notifications(sprint_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_by ON notifications(created_by);

CREATE INDEX IF NOT EXISTS idx_deliverables_sprint_id ON deliverables(sprint_id);
CREATE INDEX IF NOT EXISTS idx_deliverables_progress ON deliverables(progress);

-- 12. Apply updated_at triggers to other tables
DROP TRIGGER IF EXISTS update_tickets_updated_at ON tickets;
CREATE TRIGGER update_tickets_updated_at 
    BEFORE UPDATE ON tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notifications_updated_at ON notifications;
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Verification queries (run these to check)
-- ============================================
SELECT 'sprint_metrics table columns:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sprint_metrics' 
ORDER BY column_name;

SELECT 'sprints table created_by column:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'sprints' AND column_name = 'created_by';

SELECT 'Missing tables check:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
    AND table_name IN ('tickets', 'activity_log', 'sprint_metrics')
ORDER BY table_name;
