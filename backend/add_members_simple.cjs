// Simple script to add members using direct database connection
const { Pool } = require('pg');

// Database connection - use the same as backend
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/flow_space'
});

async function addMembersToProject() {
  try {
    console.log('🔍 Adding members to project...');
    
    const projectId = '052ba4d1-aa2a-4d73-a371-0fd5ba43baaf';
    
    // Add Busisiwe Dhlamini as owner
    console.log('➕ Adding Busisiwe as project member...');
    
    const insertResult = await pool.query(`
      INSERT INTO project_members (project_id, user_id, role, joined_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (project_id, user_id) DO NOTHING
    `, [
      projectId, 
      '00356a1b-6e08-44b8-8499-a4491d14e988', 
      'owner'
    ]);
    
    console.log('✅ Successfully added Busisiwe via database insert');
    console.log('📊 Insert result:', insertResult.rows);
    
    // Add Naomi Dhlamini as contributor
    console.log('➕ Adding Naomi as project member...');
    
    const insertResult2 = await pool.query(`
      INSERT INTO project_members (project_id, user_id, role, joined_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (project_id, user_id) DO NOTHING
    `, [
      projectId, 
      '00f9d470-7b55-4753-aa70-5b77e1a6b66c', 
      'contributor'
    ]);
    
    console.log('✅ Successfully added Naomi via database insert');
    
    // Add Busisiwe Dhlamini (Khonology) as contributor
    console.log('➕ Adding Busisiwe (Khonology) as project member...');
    
    const insertResult3 = await pool.query(`
      INSERT INTO project_members (project_id, user_id, role, joined_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (project_id, user_id) DO NOTHING
    `, [
      projectId, 
      '2bf58eec-6bca-4056-b656-0b66c34eeb94', 
      'contributor'
    ]);
    
    console.log('✅ Successfully added Busisiwe (Khonology) via database insert');
    
    // Verify the members were added
    console.log('🔍 Verifying members...');
    const verifyResult = await pool.query(`
      SELECT 
        pm.id,
        pm.project_id,
        pm.user_id,
        pm.role,
        pm.joined_at,
        u.first_name,
        u.last_name,
        u.email
      FROM project_members pm
      LEFT JOIN users u ON pm.user_id = u.id
      WHERE pm.project_id = $1
      ORDER BY pm.role, u.first_name
    `, [projectId]);
    
    console.log('📊 Current project members:');
    verifyResult.rows.forEach((row, index) => {
      console.log(`  ${index + 1}. ${row.first_name} ${row.last_name} (${row.email}) - ${row.role}`);
    });
    
    console.log(`✅ Total members: ${verifyResult.rows.length}`);
    
    await pool.end();
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    await pool.end();
  }
}

addMembersToProject();
