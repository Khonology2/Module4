-- Test query to check if project members are being retrieved correctly
-- Run this to see the actual data structure

-- Test with a specific project ID (use one from your database)
SELECT 
    p.id as project_id,
    p.name as project_name,
    pm.id as member_id,
    pm.role as member_role,
    u.id as user_id,
    u.name as user_name,
    u.email as user_email
FROM projects p
LEFT JOIN project_members pm ON p.id = pm.project_id
LEFT JOIN users u ON pm.user_id = u.id
WHERE p.id = '00356a1b-6e08-44b8-8499-a4491d14e988'  -- Use actual PDH project ID
ORDER BY pm.role, u.name;
