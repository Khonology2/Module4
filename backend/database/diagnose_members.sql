-- Diagnostic script to check project members and users
-- Run this to see what data actually exists

-- Check what users exist
SELECT 'USERS:' as info, id, name, email, role FROM users;

-- Check what projects exist  
SELECT 'PROJECTS:' as info, id, name, key, owner_id FROM projects;

-- Check current project members
SELECT 'PROJECT_MEMBERS:' as info, pm.project_id, p.name as project_name, 
       pm.user_id, u.name as user_name, u.email, pm.role 
FROM project_members pm
JOIN projects p ON pm.project_id = p.id  
JOIN users u ON pm.user_id = u.id
ORDER BY p.name;
