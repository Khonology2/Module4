-- Fix User model - simplest approach
-- Just add columns and basic update

-- Add first_name column if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE users ADD COLUMN first_name VARCHAR(255);
        RAISE NOTICE '✅ Added first_name column';
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
        RAISE NOTICE '✅ Added last_name column';
    END IF;
END $$;

-- Simple update for Busisiwe Dhlamini
UPDATE users 
SET first_name = 'Busisiwe', last_name = 'Dhlamini'
WHERE name LIKE '%Busisiwe%';

-- Simple update for Naomi Dhlamini  
UPDATE users 
SET first_name = 'Naomi', last_name = 'Dhlamini'
WHERE name LIKE '%Naomi%' AND name LIKE '%Dhlamini%';

-- Show results
SELECT id, email, name, first_name, last_name 
FROM users 
WHERE name LIKE '%Dhlamini%'
LIMIT 5;
