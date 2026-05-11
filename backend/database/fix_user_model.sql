-- Fix User model to match what backend expects
-- This adds first_name and last_name columns if they don't exist

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
        WHEN POSITION(' ' IN name) > 0 THEN SUBSTRING(name, 1, POSITION(' ' IN name) - 1)
        WHEN POSITION(' ' IN name) = 1 THEN SUBSTRING(name, POSITION(' ' IN name) + 2)
        ELSE name
    END,
    last_name = CASE 
        WHEN POSITION(' ' IN name) > 0 THEN SUBSTRING(name, POSITION(' ' IN name) + 1)
        ELSE ''
    END
WHERE first_name IS NULL OR last_name IS NULL;

-- Show the results
SELECT id, email, name, first_name, last_name 
FROM users 
LIMIT 10;
