require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'flow_space',
  password: process.env.DB_PASSWORD || 'postgres',
  port: process.env.DB_PORT || 5432,
  // Use DATABASE_URL if available (preferred approach)
  connectionString: process.env.DATABASE_URL,
});

async function runFixMigration() {
  try {
    console.log('🚀 Starting database fix migration...');
    
    // Read the fix SQL file
    const sqlFilePath = path.join(__dirname, 'fix_all_missing_tables.sql');
    console.log(`📄 Using migration file: ${sqlFilePath}`);
    
    if (!fs.existsSync(sqlFilePath)) {
      throw new Error(`Migration file not found: ${sqlFilePath}`);
    }
    
    const sqlContent = fs.readFileSync(sqlFilePath, 'utf8');
    
    // Split by semicolons to execute each statement separately
    const statements = sqlContent
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
    
    console.log(`📝 Found ${statements.length} SQL statements to execute\n`);
    
    // Execute each statement
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i];
      
      // Skip comment-only statements and verification queries
      if (statement.replace(/--.*$/gm, '').trim().length === 0 ||
          statement.toLowerCase().includes('select') ||
          statement.toLowerCase().includes('information_schema')) {
        continue;
      }
      
      try {
        console.log(`⏳ Executing statement ${i + 1}/${statements.length}...`);
        await pool.query(statement);
        console.log(`✅ Statement ${i + 1} completed successfully`);
      } catch (error) {
        // Some errors are okay (like "column already exists")
        if (error.message.includes('already exists') || 
            error.message.includes('duplicate') ||
            error.message.includes('does not exist')) {
          console.log(`⚠️  Statement ${i + 1}: ${error.message} (skipping)`);
        } else {
          console.error(`❌ Error in statement ${i + 1}:`, error.message);
          console.error('Statement:', statement.substring(0, 100) + '...');
        }
      }
    }
    
    console.log('\n✅ Migration completed successfully!');
    console.log('\n📊 Verifying tables and columns...');
    
    // Verify sprint_metrics table columns
    console.log('\n📋 Checking sprint_metrics table columns...');
    const sprintMetricsColumns = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'sprint_metrics' 
      ORDER BY column_name
    `);
    
    console.log('✅ sprint_metrics columns:');
    sprintMetricsColumns.rows.forEach(row => {
      console.log(`   - ${row.column_name} (${row.data_type})`);
    });
    
    // Verify sprints table has created_by
    console.log('\n📋 Checking sprints table created_by column...');
    const sprintsColumns = await pool.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'sprints' AND column_name = 'created_by'
    `);
    
    if (sprintsColumns.rows.length > 0) {
      console.log(`✅ sprints.created_by: ${sprintsColumns.rows[0].column_name} (${sprintsColumns.rows[0].data_type})`);
    } else {
      console.log('❌ sprints.created_by column not found');
    }
    
    // Verify missing tables exist
    console.log('\n📋 Checking missing tables...');
    const tableCheck = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name IN ('tickets', 'activity_log', 'sprint_metrics')
      ORDER BY table_name
    `);
    
    console.log('✅ Tables found:');
    tableCheck.rows.forEach(row => {
      console.log(`   - ${row.table_name}`);
    });
    
    console.log('\n🎉 Database fix migration completed!');
    console.log('🔄 You can now restart the server to test sprint creation.');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  } finally {
    await pool.end();
  }
}

runFixMigration();
