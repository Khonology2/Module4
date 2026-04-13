require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'flow_space',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
  connectionString: process.env.DATABASE_URL,
});

async function addMetricsToExistingSprints() {
  try {
    console.log('🔧 Adding metrics to existing sprints...');
    
    // Get all sprints without metrics
    const sprintsWithoutMetrics = await pool.query(`
      SELECT s.id, s.name, s.project_id, p.name as project_name, s.created_at
      FROM sprints s
      LEFT JOIN projects p ON s.project_id = p.id
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      WHERE sm.sprint_id IS NULL
      ORDER BY s.created_at DESC
    `);
    
    console.log(`\n📋 Found ${sprintsWithoutMetrics.rows.length} sprints without metrics:`);
    
    if (sprintsWithoutMetrics.rows.length === 0) {
      console.log('✅ All sprints already have metrics!');
      return;
    }
    
    let addedCount = 0;
    
    for (const sprint of sprintsWithoutMetrics.rows) {
      try {
        // Add default metrics for this sprint with correct data types
        await pool.query(`
          INSERT INTO sprint_metrics (
            sprint_id, 
            planned_points, 
            committed_points, 
            completed_points, 
            carried_over_points,
            test_pass_rate,
            code_coverage,
            escaped_defects,
            defects_opened,
            defects_closed,
            code_review_completion,
            documentation_status,
            uat_notes,
            uat_pass_rate,
            risks,
            blockers,
            decisions,
            created_at,
            updated_at
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW(), NOW()
          )
        `, [
          sprint.id,           // sprint_id
          20,                  // planned_points (integer)
          18,                  // committed_points (integer)
          0,                   // completed_points (integer)
          0,                   // carried_over_points (integer)
          0.0,                 // test_pass_rate (double precision)
          0.0,                 // code_coverage (numeric)
          0,                   // escaped_defects (integer)
          0,                   // defects_opened (integer)
          0,                   // defects_closed (integer)
          0.0,                 // code_review_completion (double precision)
          0.0,                 // documentation_status (double precision - was string!)
          '',                  // uat_notes (text)
          0.0,                 // uat_pass_rate (numeric)
          '',                  // risks (text)
          '',                  // blockers (text)
          ''                   // decisions (text)
        ]);
        
        console.log(`✅ Added metrics to sprint: ${sprint.name} (${sprint.project_name})`);
        addedCount++;
        
      } catch (error) {
        console.log(`❌ Failed to add metrics to sprint ${sprint.name}: ${error.message}`);
      }
    }
    
    console.log(`\n🎉 Successfully added metrics to ${addedCount} sprint(s)!`);
    
    // Verify the results
    const verification = await pool.query(`
      SELECT s.id, s.name, p.name as project_name,
             CASE WHEN sm.sprint_id IS NOT NULL THEN 'YES' ELSE 'NO' END as has_metrics
      FROM sprints s
      LEFT JOIN projects p ON s.project_id = p.id
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      ORDER BY s.created_at DESC
    `);
    
    console.log('\n📊 Updated sprint status:');
    verification.rows.forEach(row => {
      console.log(`   ${row.has_metrics === 'YES' ? '✅' : '❌'} ${row.name} (${row.project_name}) - Metrics: ${row.has_metrics}`);
    });
    
    // Show sample metrics
    const sampleMetrics = await pool.query(`
      SELECT s.name, p.name as project_name, sm.*
      FROM sprints s
      LEFT JOIN projects p ON s.project_id = p.id
      LEFT JOIN sprint_metrics sm ON s.id = sm.sprint_id
      WHERE sm.sprint_id IS NOT NULL
      LIMIT 3
    `);
    
    if (sampleMetrics.rows.length > 0) {
      console.log('\n📈 Sample metrics added:');
      sampleMetrics.rows.forEach(row => {
        console.log(`   🏃 ${row.name} (${row.project_name}):`);
        console.log(`      📊 Planned: ${row.planned_points} | Committed: ${row.committed_points} | Completed: ${row.completed_points}`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

addMetricsToExistingSprints();
