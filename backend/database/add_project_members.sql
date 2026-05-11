-- Add sample project members to existing projects
-- This will fix the mock member issue by linking real users to projects

-- First, let's see what users we have available
SELECT id, name, email, role FROM users LIMIT 10;

-- Add project members for existing projects
INSERT INTO project_members (project_id, user_id, role, joined_at)
SELECT 
    p.id as project_id,
    u.id as user_id,
    CASE 
        WHEN u.role = 'systemAdmin' THEN 'owner'
        WHEN u.role = 'deliveryLead' THEN 'owner'
        ELSE 'contributor'
    END as role,
    NOW() as joined_at
FROM projects p
CROSS JOIN users u
WHERE u.email IN (
    'dhlamininaomi1@gmail.com',  -- From the terminal logs
    'admin@flowspace.com'       -- Common admin email
)
AND NOT EXISTS (
    SELECT 1 FROM project_members pm 
    WHERE pm.project_id = p.id AND pm.user_id = u.id
)
LIMIT 10;

-- Show the results
SELECT 
    p.name as project_name,
    p.key as project_key,
    u.name as user_name,
    u.email as user_email,
    pm.role as member_role,
    pm.joined_at
FROM project_members pm
JOIN projects p ON pm.project_id = p.id
JOIN users u ON pm.user_id = u.id
ORDER BY p.name, pm.role;
