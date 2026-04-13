-- Fix sprints table - add missing created_by column
-- This will resolve the sprint creation error

DO $$
BEGIN;

-- Add created_by column to sprints table if it doesn't exist
ALTER TABLE sprints 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- Add updated_by column to sprints table if it doesn't exist  
ALTER TABLE sprints 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- Update existing sprints to set created_by to owner_id if null
UPDATE sprints 
SET created_by = (SELECT project_id FROM projects WHERE id = sprints.project_id LIMIT 1)
WHERE created_by IS NULL;

COMMIT;
$$;

-- Verify the changes
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'sprints' 
    AND column_name IN ('created_by', 'updated_by')
ORDER BY column_name;
