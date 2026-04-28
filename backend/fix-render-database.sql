-- FIX RENDER DATABASE - Complete Migration Script
-- This script fixes all the missing columns causing 500 errors

-- ============================================
-- FIX USERS TABLE - Add first_name and last_name
-- ============================================

-- Add first_name column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE users ADD COLUMN first_name VARCHAR(255);
        RAISE NOTICE '✅ Added first_name column to users table';
    END IF;
END $$;

-- Add last_name column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'last_name'
    ) THEN
        ALTER TABLE users ADD COLUMN last_name VARCHAR(255);
        RAISE NOTICE '✅ Added last_name column to users table';
    END IF;
END $$;

-- Update existing users to populate first_name and last_name from name field
UPDATE users 
SET first_name = SPLIT_PART(name, ' ', 1), 
    last_name = CASE 
        WHEN POSITION(' ' IN name) > 0 THEN SPLIT_PART(name, ' ', 2)
        ELSE ''
    END
WHERE first_name IS NULL AND name IS NOT NULL;

-- ============================================
-- FIX SPRINT_METRICS TABLE - Add all missing columns
-- ============================================

-- Check if sprint_metrics table exists, then add missing columns
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sprint_metrics') THEN
        
        -- Add all missing columns that server.js expects
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'planned_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN planned_points INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'committed_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN committed_points INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'completed_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN completed_points INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'carried_over_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN carried_over_points INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'test_pass_rate') THEN
            ALTER TABLE sprint_metrics ADD COLUMN test_pass_rate INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'code_coverage') THEN
            ALTER TABLE sprint_metrics ADD COLUMN code_coverage INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'escaped_defects') THEN
            ALTER TABLE sprint_metrics ADD COLUMN escaped_defects INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'defects_opened') THEN
            ALTER TABLE sprint_metrics ADD COLUMN defects_opened INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'defects_closed') THEN
            ALTER TABLE sprint_metrics ADD COLUMN defects_closed INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'code_review_completion') THEN
            ALTER TABLE sprint_metrics ADD COLUMN code_review_completion INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'documentation_status') THEN
            ALTER TABLE sprint_metrics ADD COLUMN documentation_status INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'uat_notes') THEN
            ALTER TABLE sprint_metrics ADD COLUMN uat_notes TEXT;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'uat_pass_rate') THEN
            ALTER TABLE sprint_metrics ADD COLUMN uat_pass_rate INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'risks') THEN
            ALTER TABLE sprint_metrics ADD COLUMN risks TEXT;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'blockers') THEN
            ALTER TABLE sprint_metrics ADD COLUMN blockers TEXT;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'decisions') THEN
            ALTER TABLE sprint_metrics ADD COLUMN decisions TEXT;
        END IF;
        
        RAISE NOTICE '✅ Added all missing columns to sprint_metrics table';
    ELSE
        RAISE NOTICE '⚠️ sprint_metrics table does not exist - creating it';
        
        -- Create the table if it doesn't exist
        CREATE TABLE sprint_metrics (
            id SERIAL PRIMARY KEY,
            sprint_id INTEGER REFERENCES sprints(id) ON DELETE CASCADE,
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
        );
        
        RAISE NOTICE '✅ Created sprint_metrics table with all required columns';
    END IF;
END $$;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify users table has the required columns
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('first_name', 'last_name')
ORDER BY column_name;

-- Verify sprint_metrics table has the required columns
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'sprint_metrics' 
AND column_name IN ('planned_points', 'committed_points', 'completed_points', 'carried_over_points', 'test_pass_rate', 'code_coverage', 'escaped_defects', 'defects_opened', 'defects_closed', 'code_review_completion', 'documentation_status', 'uat_notes', 'uat_pass_rate', 'risks', 'blockers', 'decisions')
ORDER BY column_name;

-- Show sample data to verify fixes
SELECT 'Sample users with name fields:' as info;
SELECT id, email, name, first_name, last_name 
FROM users 
LIMIT 3;

SELECT 'Sample sprint_metrics (if any exist):' as info;
SELECT * FROM sprint_metrics 
LIMIT 3;

RAISE NOTICE '🎉 Database migration completed successfully!';
RAISE NOTICE '📋 The following issues have been fixed:';
RAISE NOTICE '   ✅ Added first_name and last_name columns to users table';
RAISE NOTICE '   ✅ Added all missing columns to sprint_metrics table';
RAISE NOTICE '   ✅ Updated existing users with name data';
RAISE NOTICE '   🚀 Backend 500 errors should now be resolved';
