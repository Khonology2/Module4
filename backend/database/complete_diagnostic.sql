-- Complete diagnostic to find the exact issue with project members
-- This will show us the full data flow from database to API

-- Step 1: Check what projects exist
SELECT '=== PROJECTS TABLE ===' as info;
SELECT id, name, key, owner_id FROM projects WHERE id = '00356a1b-6e08-44b8-8499-a4491d14e988';

-- Step 2: Check project members directly
SELECT '=== PROJECT_MEMBERS TABLE ===' as info;
SELECT project_id, user_id, role, joined_at FROM project_members WHERE project_id = '00356a1b-6e08-44b8-8499-a4491d14e988';

-- Step 3: Check what users exist for those member IDs
SELECT '=== USERS TABLE ===' as info;
SELECT id, name, email FROM users WHERE id IN (
    SELECT user_id FROM project_members WHERE project_id = '00356a1b-6e08-44b8-8499-a4491d14e988'
);

-- Step 4: Test the exact API query (simulate what backend does)
SELECT '=== API SIMULATION ===' as info;
SELECT 
    p.id as project_id,
    p.name as project_name,
    p.key as project_key,
    pm.id as member_id,
    pm.role as member_role,
    pm.user_id,
    u.name as user_name,
    u.email as user_email,
    pm.joined_at
FROM projects p
LEFT JOIN project_members pm ON p.id = pm.project_id
LEFT JOIN users u ON pm.user_id = u.id
WHERE p.id = '00356a1b-6e08-44b8-8499-a4491d14e988'
ORDER BY pm.role, u.name;

-- Step 5: Check if the issue is with User model associations
SELECT '=== USER MODEL CHECK ===' as info;
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('first_name', 'last_name')
ORDER BY ordinal_position;
