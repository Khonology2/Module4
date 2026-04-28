import pool from './dbPool.js';

async function populateTimeline() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    console.log('🔍 Checking for sprints without timeline entries...');
    
    // Get sprints without timeline entries
    const sprintsResult = await client.query(`
      SELECT s.id, s.name, s.status, s.start_date, s.end_date, s.created_by
      FROM sprints s
      LEFT JOIN timeline t ON s.id = t.entity_id AND t.entity_type = 'sprint'
      WHERE t.id IS NULL
    `);
    
    console.log(`📊 Found ${sprintsResult.rows.length} sprints without timeline entries`);
    
    for (const sprint of sprintsResult.rows) {
      await client.query(`
        INSERT INTO timeline (
          entity_type, entity_id, title, description, 
          start_date, end_date, created_by, status, 
          priority, tags, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        'sprint',
        sprint.id,
        sprint.name,
        `Sprint: ${sprint.name}`,
        sprint.start_date,
        sprint.end_date,
        sprint.created_by,
        sprint.status || 'planning',
        'medium',
        '[]',
        '{}'
      ]);
      
      console.log(`✅ Created timeline entry for sprint: ${sprint.name}`);
    }
    
    console.log('🔍 Checking for projects without timeline entries...');
    
    // Get projects without timeline entries
    const projectsResult = await client.query(`
      SELECT p.id, p.name, p.status, p.start_date, p.end_date, p.created_by
      FROM projects p
      LEFT JOIN timeline t ON p.id = t.entity_id AND t.entity_type = 'project'
      WHERE t.id IS NULL
    `);
    
    console.log(`📊 Found ${projectsResult.rows.length} projects without timeline entries`);
    
    for (const project of projectsResult.rows) {
      await client.query(`
        INSERT INTO timeline (
          entity_type, entity_id, title, description, 
          start_date, end_date, created_by, status, 
          priority, tags, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [
        'project',
        project.id,
        project.name,
        `Project: ${project.name}`,
        project.start_date,
        project.end_date,
        project.created_by,
        project.status || 'active',
        'medium',
        '[]',
        '{}'
      ]);
      
      console.log(`✅ Created timeline entry for project: ${project.name}`);
    }
    
    await client.query('COMMIT');
    console.log('🎉 Timeline population completed successfully!');
    
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Error populating timeline:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Run the population
populateTimeline()
  .then(() => {
    console.log('✅ Timeline population finished');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Timeline population failed:', error);
    process.exit(1);
  });
