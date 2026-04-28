-- Add missing columns to sprint_metrics table
-- This migration adds the columns that the server.js code expects

DO $$
BEGIN
    -- Check if the table exists before adding columns
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sprint_metrics') THEN
        
        -- Add missing columns if they don't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'committed_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN committed_points INTEGER DEFAULT 0;
        END IF;
        
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'sprint_metrics' AND column_name = 'carried_over_points') THEN
            ALTER TABLE sprint_metrics ADD COLUMN carried_over_points INTEGER DEFAULT 0;
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
        
        RAISE NOTICE 'Successfully added missing columns to sprint_metrics table';
    ELSE
        RAISE NOTICE 'sprint_metrics table does not exist - skipping column additions';
    END IF;
END $$;
