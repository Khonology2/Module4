import pkg from 'pg';
const { Pool } = pkg;

// Database connection - same as server.js
function createPool() {
  console.log('🛜 Using DATABASE_URL (safest approach)');
  console.log('📊 Connection URL:', process.env.DATABASE_URL ? '***CONFIGURED***' : 'NOT SET');
  
  if (!process.env.DATABASE_URL) {
    return new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME || 'flow_space',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      ssl: false,
    });
  }

  // SSL CONFIGURATION - Enable SSL in production, respect DB_SSL setting
  const isProduction = process.env.NODE_ENV === 'production' || process.env.RENDER === 'true';
  const sslEnabled = process.env.DB_SSL === 'true' || isProduction;
  console.log('🔒 SSL Enabled:', sslEnabled);
  console.log('🌍 Production Environment:', isProduction);
  
  return new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: sslEnabled ? {
      rejectUnauthorized: false,
    } : false,
  });
}

const pool = createPool();

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Starting sprint metrics migration...');
    
    // Check if the table exists
    const tableCheck = await client.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'sprint_metrics'
      );
    `);
    
    if (!tableCheck.rows[0].exists) {
      console.log('sprint_metrics table does not exist - skipping column additions');
      return;
    }
    
    console.log('sprint_metrics table exists, adding missing columns...');
    
    // List of columns to add with their types
    const columnsToAdd = [
      { name: 'committed_points', type: 'INTEGER DEFAULT 0' },
      { name: 'carried_over_points', type: 'INTEGER DEFAULT 0' },
      { name: 'code_coverage', type: 'INTEGER DEFAULT 0' },
      { name: 'escaped_defects', type: 'INTEGER DEFAULT 0' },
      { name: 'defects_opened', type: 'INTEGER DEFAULT 0' },
      { name: 'defects_closed', type: 'INTEGER DEFAULT 0' },
      { name: 'code_review_completion', type: 'INTEGER DEFAULT 0' },
      { name: 'documentation_status', type: 'INTEGER DEFAULT 0' },
      { name: 'uat_pass_rate', type: 'INTEGER DEFAULT 0' },
      { name: 'risks', type: 'TEXT' },
      { name: 'blockers', type: 'TEXT' },
      { name: 'decisions', type: 'TEXT' }
    ];
    
    for (const column of columnsToAdd) {
      // Check if column already exists
      const columnCheck = await client.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.columns 
          WHERE table_schema = 'public' 
          AND table_name = 'sprint_metrics' 
          AND column_name = '${column.name}'
        );
      `);
      
      if (!columnCheck.rows[0].exists) {
        console.log(`Adding column: ${column.name}`);
        await client.query(`
          ALTER TABLE sprint_metrics ADD COLUMN ${column.name} ${column.type};
        `);
        console.log(`✓ Added column: ${column.name}`);
      } else {
        console.log(`✓ Column already exists: ${column.name}`);
      }
    }
    
    console.log('✅ Successfully completed sprint metrics migration!');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
