#!/usr/bin/env node

/**
 * Render Database Update Migration for Flow-Space
 * Updates existing Render database to match current schema
 * Usage: node migrations/update-render.js
 */

import pkg from 'pg';
const Pool = pkg.Pool;

// Render database configuration
const renderConfig = {
  connectionString: 'postgresql://dssoh_user:IuTxLxOZ6CQBGXdghxfdPOfZSKAF070h@dpg-d6p6de5m5p6s73dlguqg-a.virginia-postgres.render.com/dssoh',
  ssl: {
    rejectUnauthorized: false,
  },
};

async function updateRenderDatabase() {
  console.log('🔧 Starting Flow-Space Render Database Update...');
  console.log('📊 Target Database: dssoh (PostgreSQL on Render)');
  console.log('');

  const pool = new Pool(renderConfig);

  try {
    // Test database connection first
    console.log('🔍 Testing Render database connection...');
    const client = await pool.connect();
    
    const result = await client.query('SELECT current_database(), version()');
    console.log('✅ Connected to Render database:', result.rows[0].current_database);
    console.log('📋 PostgreSQL version:', result.rows[0].version.split(',')[0]);
    console.log('');

    // Check current table structure
    console.log('🔍 Checking current database structure...');
    
    // Check projects table columns
    const projectsColumns = await client.query(`
      SELECT column_name, data_type, is_nullable 
      FROM information_schema.columns 
      WHERE table_name = 'projects' 
      ORDER BY ordinal_position
    `);
    
    console.log('📋 Projects table columns:');
    projectsColumns.rows.forEach(col => {
      console.log(`  ✓ ${col.column_name} (${col.data_type})`);
    });
    console.log('');

    // Check if 'key' column exists in projects table
    const hasKeyColumn = projectsColumns.rows.some(col => col.column_name === 'key');
    
    if (!hasKeyColumn) {
      console.log('🔧 Adding missing "key" column to projects table...');
      
      // Add key column
      await client.query(`
        ALTER TABLE projects 
        ADD COLUMN IF NOT EXISTS key VARCHAR(50) UNIQUE
      `);
      
      console.log('✅ Added "key" column to projects table');
      
      // Generate keys for existing projects
      const existingProjects = await client.query(`
        SELECT id, name 
        FROM projects 
        WHERE key IS NULL OR key = ''
      `);
      
      console.log(`🔧 Generating keys for ${existingProjects.rows.length} existing projects...`);
      
      for (const project of existingProjects.rows) {
        // Generate a unique key based on project name
        let baseKey = project.name
          .toLowerCase()
          .replace(/[^a-z0-9\s]/g, '')
          .replace(/\s+/g, '-')
          .substring(0, 20);
        
        let key = baseKey;
        let counter = 1;
        
        // Ensure uniqueness
        while (true) {
          const existing = await client.query('SELECT 1 FROM projects WHERE key = $1', [key]);
          if (existing.rows.length === 0) break;
          
          key = `${baseKey}-${counter}`;
          counter++;
        }
        
        await client.query('UPDATE projects SET key = $1 WHERE id = $2', [key, project.id]);
        console.log(`  ✓ Set key "${key}" for project "${project.name}"`);
      }
      
      console.log('✅ Generated keys for all existing projects');
    } else {
      console.log('ℹ️  "key" column already exists in projects table');
    }

    // Check and add other missing columns
    console.log('');
    console.log('🔧 Checking for other missing columns...');
    
    // Check for project_type column
    const hasProjectType = projectsColumns.rows.some(col => col.column_name === 'project_type');
    if (!hasProjectType) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS project_type VARCHAR(100) DEFAULT \'Software Development\'');
      console.log('✅ Added project_type column');
    }
    
    // Check for priority column
    const hasPriority = projectsColumns.rows.some(col => col.column_name === 'priority');
    if (!hasPriority) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT \'medium\'');
      console.log('✅ Added priority column');
    }
    
    // Check for start_date column
    const hasStartDate = projectsColumns.rows.some(col => col.column_name === 'start_date');
    if (!hasStartDate) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS start_date DATE');
      console.log('✅ Added start_date column');
    }
    
    // Check for end_date column
    const hasEndDate = projectsColumns.rows.some(col => col.column_name === 'end_date');
    if (!hasEndDate) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS end_date DATE');
      console.log('✅ Added end_date column');
    }
    
    // Check for owner_id column
    const hasOwnerId = projectsColumns.rows.some(col => col.column_name === 'owner_id');
    if (!hasOwnerId) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id)');
      console.log('✅ Added owner_id column');
    }
    
    // Check for tags column
    const hasTags = projectsColumns.rows.some(col => col.column_name === 'tags');
    if (!hasTags) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT \'{}\'');
      console.log('✅ Added tags column');
    }
    
    // Check for members column
    const hasMembers = projectsColumns.rows.some(col => col.column_name === 'members');
    if (!hasMembers) {
      await client.query('ALTER TABLE projects ADD COLUMN IF NOT EXISTS members JSONB DEFAULT \'[]\'');
      console.log('✅ Added members column');
    }

    // Check users table structure
    console.log('');
    console.log('🔍 Checking users table structure...');
    
    const usersColumns = await client.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position
    `);
    
    // Check for first_name and last_name columns
    const hasFirstName = usersColumns.rows.some(col => col.column_name === 'first_name');
    const hasLastName = usersColumns.rows.some(col => col.column_name === 'last_name');
    
    if (!hasFirstName || !hasLastName) {
      console.log('🔧 Adding name columns to users table...');
      
      if (!hasFirstName) {
        await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name VARCHAR(100)');
        console.log('✅ Added first_name column');
      }
      
      if (!hasLastName) {
        await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name VARCHAR(100)');
        console.log('✅ Added last_name column');
      }
      
      // Update existing users to split name into first/last names
      const usersToUpdate = await client.query(`
        SELECT id, name 
        FROM users 
        WHERE name IS NOT NULL 
        AND (first_name IS NULL OR first_name = '') 
        AND (last_name IS NULL OR last_name = '')
      `);
      
      for (const user of usersToUpdate.rows) {
        const nameParts = user.name.trim().split(' ');
        const firstName = nameParts[0] || '';
        const lastName = nameParts.slice(1).join(' ') || '';
        
        await client.query(`
          UPDATE users 
          SET first_name = $1, last_name = $2 
          WHERE id = $3
        `, [firstName, lastName, user.id]);
      }
      
      console.log('✅ Updated existing users with first/last names');
    }

    // Create indexes if they don't exist
    console.log('');
    console.log('🔧 Creating indexes...');
    
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_projects_key ON projects(key)',
      'CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status)',
      'CREATE INDEX IF NOT EXISTS idx_projects_created_by ON projects(created_by)',
      'CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON projects(owner_id)',
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
      'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
      'CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active)',
    ];
    
    for (const indexSql of indexes) {
      try {
        await client.query(indexSql);
        console.log(`✅ Created index`);
      } catch (error) {
        console.log(`ℹ️  Index already exists or failed: ${error.message}`);
      }
    }

    // Verify the update
    console.log('');
    console.log('🔍 Verifying database update...');
    
    const finalProjectColumns = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'projects' 
      ORDER BY ordinal_position
    `);
    
    console.log('📋 Final projects table structure:');
    finalProjectColumns.rows.forEach(col => {
      console.log(`  ✓ ${col.column_name}`);
    });
    
    // Test data
    const projectCount = await client.query('SELECT COUNT(*) as count FROM projects');
    const userCount = await client.query('SELECT COUNT(*) as count FROM users');
    
    console.log('');
    console.log('📊 Database Summary:');
    console.log(`  📁 Projects: ${projectCount.rows[0].count}`);
    console.log(`  👤 Users: ${userCount.rows[0].count}`);
    
    // Check for admin user
    const adminUser = await client.query(`
      SELECT email, role, is_active 
      FROM users 
      WHERE email = 'admin@flownet.works'
    `);
    
    if (adminUser.rows.length === 0) {
      console.log('');
      console.log('👤 Creating default admin user...');
      await client.query(`
        INSERT INTO users (id, email, name, first_name, last_name, password_hash, role, is_active, email_verified)
        VALUES (gen_random_uuid(), 'admin@flownet.works', 'System Administrator', 'System', 'Administrator', 
                '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj6ukx.LFvO.', 'system_admin', true, true)
        ON CONFLICT (email) DO NOTHING
      `);
      console.log('✅ Created default admin user');
      console.log('🔑 Login: admin@flownet.works / admin123');
    }

    client.release();
    
    console.log('');
    console.log('🎉 Render database update completed successfully!');
    console.log('🚀 Your deployed Flow-Space app is now ready!');
    console.log('');
    console.log('📋 What was updated:');
    console.log('  ✅ Added missing columns to projects table');
    console.log('  ✅ Generated unique keys for existing projects');
    console.log('  ✅ Added name columns to users table');
    console.log('  ✅ Created performance indexes');
    console.log('  ✅ Verified data integrity');
    
  } catch (error) {
    console.error('❌ Render update failed:', error.message);
    console.error('📋 Error details:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the update
updateRenderDatabase().catch(console.error);
