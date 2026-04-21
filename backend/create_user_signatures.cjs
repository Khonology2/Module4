const pool = require('./dbPool.js');

async function createUserSignaturesTable() {
  try {
    console.log('Creating user_signatures table...');
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_signatures (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name VARCHAR(255),
        signature_data TEXT NOT NULL,
        signature_type VARCHAR(20) DEFAULT 'drawn' CHECK (signature_type IN ('drawn', 'typed', 'uploaded')),
        is_default BOOLEAN DEFAULT FALSE,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        last_used_at TIMESTAMP
      )
    `);

    console.log('✅ user_signatures table created successfully');

    // Create indexes
    await pool.query('CREATE INDEX IF NOT EXISTS idx_user_signatures_user_id ON user_signatures(user_id)');
    await pool.query('CREATE INDEX IF NOT EXISTS idx_user_signatures_default_active ON user_signatures(user_id, is_default, is_active)');
    
    console.log('✅ Indexes created successfully');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating table:', error);
    process.exit(1);
  }
}

createUserSignaturesTable();
