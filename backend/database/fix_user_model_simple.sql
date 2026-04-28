-- Simple fix for User model - split name into first_name and last_name
-- This version uses standard SQL functions that work in PostgreSQL

DO $$
BEGIN
    -- Add first_name column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE users ADD COLUMN first_name VARCHAR(255);
        RAISE NOTICE '✅ Added first_name column';
    END IF;
    
    -- Add last_name column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'last_name'
    ) THEN
        ALTER TABLE users ADD COLUMN last_name VARCHAR(255);
        RAISE NOTICE '✅ Added last_name column';
    END IF;
END $$;

-- Update existing users to split name into first_name and last_name
UPDATE users 
SET 
    first_name = CASE 
        WHEN name LIKE '% %' THEN TRIM(SPLIT_PART(name, ' ')[1])
        ELSE name
    END,
    last_name = CASE 
        WHEN name LIKE '% %' AND LENGTH(SPLIT_PART(name, ' ')) > 1 THEN TRIM(SPLIT_PART(name, ' ')[2])
        ELSE ''
    END
WHERE first_name IS NULL OR last_name IS NULL;

-- Show results
SELECT id, email, name, first_name, last_name 
FROM users 
LIMIT 5;
