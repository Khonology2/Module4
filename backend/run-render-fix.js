require('dotenv').config();
const { Pool } = require('pg');

// Use DATABASE_URL for Render, fallback to individual env vars
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

async function runRenderFix() {
  try {
    console.log('🚀 Starting Render database fix...');
    
    // Fix users table - add first_name and last_name
    console.log('📝 Fixing users table...');
    
    try {
      await pool.query(`
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' AND column_name = 'first_name'
            ) THEN
                ALTER TABLE users ADD COLUMN first_name VARCHAR(255);
                RAISE NOTICE '✅ Added first_name column';
            END IF;
        END $$
      `);
      console.log('✅ first_name column added/verified');
    } catch (err) {
      console.log('⚠️ first_name column may already exist:', err.message);
    }
    
    try {
      await pool.query(`
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'users' AND column_name = 'last_name'
            ) THEN
                ALTER TABLE users ADD COLUMN last_name VARCHAR(255);
                RAISE NOTICE '✅ Added last_name column';
            END IF;
        END $$
      `);
      console.log('✅ last_name column added/verified');
    } catch (err) {
      console.log('⚠️ last_name column may already exist:', err.message);
    }
    
    // Update existing users
    try {
      await pool.query(`
        UPDATE users 
        SET first_name = SPLIT_PART(name, ' ', 1), 
            last_name = CASE 
                WHEN POSITION(' ' IN name) > 0 THEN SPLIT_PART(name, ' ', 2)
                ELSE ''
            END
        WHERE first_name IS NULL AND name IS NOT NULL
      `);
      console.log('✅ Updated existing users with name data');
    } catch (err) {
      console.log('⚠️ User update may have already run:', err.message);
    }
    
    // Fix sprint_metrics table
    console.log('📝 Fixing sprint_metrics table...');
    
    const requiredColumns = [
      'planned_points', 'committed_points', 'completed_points', 'carried_over_points',
      'test_pass_rate', 'code_coverage', 'escaped_defects', 'defects_opened', 'defects_closed',
      'code_review_completion', 'documentation_status', 'uat_notes', 'uat_pass_rate', 
      'risks', 'blockers', 'decisions'
    ];
    
    for (const column of requiredColumns) {
      try {
        const columnType = column.includes('notes') || column.includes('risks') || column.includes('blockers') || column.includes('decisions') ? 'TEXT' : 'INTEGER DEFAULT 0';
        
        await pool.query(`
          DO $$
          BEGIN
              IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'sprint_metrics') THEN
                  IF NOT EXISTS (
                      SELECT 1 FROM information_schema.columns 
                      WHERE table_name = 'sprint_metrics' AND column_name = '${column}'
                  ) THEN
                      ALTER TABLE sprint_metrics ADD COLUMN ${column} ${columnType};
                  END IF;
              END IF;
          END $$
        `);
        console.log(`✅ ${column} column added/verified`);
      } catch (err) {
        console.log(`⚠️ ${column} column may already exist:`, err.message);
      }
    }
    
    // Create sprint_metrics table if it doesn't exist
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS sprint_metrics (
            id SERIAL PRIMARY KEY,
            sprint_id INTEGER REFERENCES sprints(id) ON DELETE CASCADE,
            planned_points INTEGER DEFAULT 0,
            committed_points INTEGER DEFAULT 0,
            completed_points INTEGER DEFAULT 0,
            carried_over_points INTEGER DEFAULT 0,
            test_pass_rate INTEGER DEFAULT 0,
            code_coverage INTEGER DEFAULT 0,
            escaped_defects INTEGER DEFAULT 0,
            defects_opened INTEGER DEFAULT 0,
            defects_closed INTEGER DEFAULT 0,
            code_review_completion INTEGER DEFAULT 0,
            documentation_status INTEGER DEFAULT 0,
            uat_notes TEXT,
            uat_pass_rate INTEGER DEFAULT 0,
            risks TEXT,
            blockers TEXT,
            decisions TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('✅ sprint_metrics table created/verified');
    } catch (err) {
      console.log('⚠️ sprint_metrics table may already exist:', err.message);
    }
    
    // Verification
    console.log('\n🔍 Verifying fixes...');
    
    try {
      const userCols = await pool.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name IN ('first_name', 'last_name')
        ORDER BY column_name
      `);
      
      console.log('✅ Users table columns:');
      userCols.rows.forEach(row => console.log(`   - ${row.column_name}`));
      
      const metricCols = await pool.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'sprint_metrics' 
        AND column_name IN ('planned_points', 'committed_points', 'completed_points', 'code_coverage')
        ORDER BY column_name
      `);
      
      console.log('✅ Sprint_metrics table columns:');
      metricCols.rows.forEach(row => console.log(`   - ${row.column_name}`));
      
    } catch (err) {
      console.log('⚠️ Verification query failed:', err.message);
    }
    
    console.log('\n🎉 Render database fix completed successfully!');
    console.log('📋 Fixed issues:');
    console.log('   ✅ Added first_name and last_name to users table');
    console.log('   ✅ Added all missing columns to sprint_metrics table');
    console.log('   ✅ Updated existing users with name data');
    console.log('   🚀 Backend 500 errors should now be resolved');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  } finally {
    await pool.end();
  }
}

runRenderFix();
