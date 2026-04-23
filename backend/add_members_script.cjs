// Simple script to add members to project via API
const axios = require('axios');

const API_BASE = 'http://localhost:8000/api/v1';

// Get auth token (you'll need to replace this with your actual token)
const authToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjAwMzU2YTFiLTZlMDgtNDRiOC04NDk5LWE0NDkxZDE0ZTk4OCIsImVtYWlsIjoiZGhsYW1pbmluYW9taTFAZ21haWwuY29tIiwicm9sZSI6ImRlbGl2ZXJ5TGVhZCIsImlhdCI6MTc3Mzg0NzAyMCwiZXhwIjoxNzczOTMzNDIwfQ.QFd_pKhM5x2xbqM5g_N1RMpjypqGJjT2Lr4ywgsktrk';

async function addMembersToProject() {
  try {
    console.log('🔍 Adding members to project...');
    
    // Get the database pool directly
    const { sequelize, QueryTypes } = require('./node-backend/src/models');
    
    const projectId = '052ba4d1-aa2a-4d73-a371-0fd5ba43baaf';
    
    // Add Busisiwe Dhlamini as owner
    console.log('➕ Adding Busisiwe as project member...');
    
    const insertResult = await sequelize.query(`
      INSERT INTO project_members (project_id, user_id, role, added_at)
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT (project_id, user_id) DO NOTHING
    `, {
      replacements: [projectId, '00356a1b-6e08-44b8-8499-a4491d14e988', 'owner'],
      type: QueryTypes.INSERT
    });
    
    console.log('✅ Successfully added Busisiwe via direct database insert');
    console.log('📊 Insert result:', insertResult);
    
    // Test the project endpoint to see if members are now included
    console.log('🔍 Testing project endpoint...');
    
    const axios = require('axios');
    const projectResponse = await axios.get(`${API_BASE}/projects/${projectId}`, {
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'Content-Type': 'application/json'
      }
    });
    
    console.log('📊 Project response:', {
      hasMembers: !!projectResponse.data.data.members,
      memberCount: projectResponse.data.data.members?.length || 0,
      members: projectResponse.data.data.members
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
    }
  }
}

addMembersToProject();
