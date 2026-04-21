-- Add members to the Deployment project
-- This will fix the empty members array issue

INSERT INTO project_members (project_id, user_id, role, added_at)
SELECT 
    '052ba4d1-aa2a-4d73-a371-0fd5ba43baaf' as project_id,
    u.id as user_id,
    'contributor' as role,
    NOW() as added_at
FROM users u
WHERE u.email IN (
    'dhlamininaomi1@gmail.com',
    'admin@flowspace.com'
)
AND NOT EXISTS (
    SELECT 1 FROM project_members pm 
    WHERE pm.project_id = '052ba4d1-aa2a-4d73-a371-0fd5ba43baaf' 
    AND pm.user_id = u.id
);

-- Show the results
SELECT 
    p.name as project_name,
    p.id as project_id,
    pm.role as member_role,
    u.name as user_name,
    u.email as user_email,
    pm.added_at
FROM project_members pm
JOIN projects p ON pm.project_id = p.id
JOIN users u ON pm.user_id = u.id
WHERE pm.project_id = '052ba4d1-aa2a-4d73-a371-0fd5ba43baaf'
ORDER BY pm.role, u.name;
