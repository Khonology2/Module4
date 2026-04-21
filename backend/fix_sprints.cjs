// Fix sprints table by adding missing columns
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/flow_space'
});

async function fixSprintsTable() {
  try {
    console.log('🔧 Fixing sprints table...');
    
    // Add created_by column
    console.log('➕ Adding created_by column...');
    await pool.query(`
      ALTER TABLE sprints 
      ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL
    `);
    
    // Add updated_by column
    console.log('➕ Adding updated_by column...');
    await pool.query(`
      ALTER TABLE sprints 
      ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES users(id) ON DELETE SET NULL
    `);
    
    // Update existing sprints to set created_by to project owner if null
    console.log('🔄 Updating existing records...');
    await pool.query(`
      UPDATE sprints 
      SET created_by = (SELECT owner_id FROM projects WHERE id = sprints.project_id LIMIT 1)
      WHERE created_by IS NULL
    `);
    
    // Verify the changes
    console.log('✅ Verifying changes...');
    const result = await pool.query(`
      SELECT 
        column_name,
        data_type,
        is_nullable
      FROM information_schema.columns 
      WHERE table_name = 'sprints' 
        AND column_name IN ('created_by', 'updated_by')
      ORDER BY column_name
    `);
    
    console.log('📊 Updated sprints table columns:');
    result.rows.forEach(col => {
      console.log(`  - ${col.column_name}: ${col.data_type} (nullable: ${col.is_nullable})`);
    });
    
    console.log('✅ Sprints table fixed successfully!');
    
    await pool.end();
    
  } catch (error) {
    console.error('❌ Error fixing sprints table:', error.message);
    await pool.end();
  }
}

fixSprintsTable();
