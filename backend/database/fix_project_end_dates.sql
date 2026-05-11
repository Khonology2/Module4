-- Complete projects table migration and fix missing end dates
-- This script adds missing columns and updates null end dates

-- Step 1: Add all missing columns to projects table
DO $$
BEGIN
    -- Add key column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'key'
    ) THEN
        ALTER TABLE projects ADD COLUMN key VARCHAR(50);
    END IF;
    
    -- Add client_name column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'client_name'
    ) THEN
        ALTER TABLE projects ADD COLUMN client_name VARCHAR(255);
    END IF;
    
    -- Add project_type column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'project_type'
    ) THEN
        ALTER TABLE projects ADD COLUMN project_type VARCHAR(50) DEFAULT 'agile';
    END IF;
    
    -- Add start_date column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'start_date'
    ) THEN
        ALTER TABLE projects ADD COLUMN start_date TIMESTAMP;
    END IF;
    
    -- Add end_date column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'end_date'
    ) THEN
        ALTER TABLE projects ADD COLUMN end_date TIMESTAMP;
    END IF;
    
    -- Add priority column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'priority'
    ) THEN
        ALTER TABLE projects ADD COLUMN priority VARCHAR(20) DEFAULT 'medium';
    END IF;
    
    -- Add created_by column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'created_by'
    ) THEN
        ALTER TABLE projects ADD COLUMN created_by UUID;
    END IF;
    
    -- Add tags column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'tags'
    ) THEN
        ALTER TABLE projects ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add metadata column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'projects' AND column_name = 'metadata'
    ) THEN
        ALTER TABLE projects ADD COLUMN metadata JSONB DEFAULT '{}';
    END IF;
END $$;

-- Step 2: Fix missing end dates for existing projects
UPDATE projects 
SET end_date = start_date + INTERVAL '6 months'
WHERE end_date IS NULL 
AND start_date IS NOT NULL;

-- For projects that don't have start dates either, set them to reasonable defaults
UPDATE projects 
SET 
  start_date = NOW() - INTERVAL '3 months',
  end_date = NOW() + INTERVAL '3 months'
WHERE end_date IS NULL 
AND start_date IS NULL;

-- Step 3: Set default values for other missing fields
UPDATE projects 
SET 
  key = UPPER(SUBSTRING(REPLACE(name, ' ', ''), 1, 10)),
  project_type = 'software',
  priority = 'medium',
  client_name = 'Internal Client'
WHERE key IS NULL;

-- Step 4: Set created_by if null
UPDATE projects 
SET created_by = owner_id 
WHERE created_by IS NULL 
AND owner_id IS NOT NULL;

-- Show updated projects
SELECT 
  id, 
  name, 
  key,
  client_name,
  project_type,
  priority,
  start_date, 
  end_date,
  created_by,
  CASE 
    WHEN end_date IS NULL THEN 'No end date'
    ELSE 'Has end date: ' || TO_CHAR(end_date, 'DD/MM/YYYY')
  END as end_date_status
FROM projects 
ORDER BY created_at DESC;
