const { sequelize } = require('../models');

/**
 * Migration: Create user_signatures table
 * Purpose: Store reusable user signatures for document signing
 */
async function up() {
  try {
    console.log('[user-signatures] Creating user_signatures table...');
    
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS user_signatures (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES Users(id) ON DELETE CASCADE,
        signature_data TEXT NOT NULL,
        signature_type VARCHAR(20) DEFAULT 'drawn' CHECK (signature_type IN ('drawn', 'typed', 'uploaded')),
        is_default BOOLEAN DEFAULT FALSE,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        last_used_at TIMESTAMP,
        
        CONSTRAINT user_signatures_user_id_fkey FOREIGN KEY (user_id) 
          REFERENCES Users(id) ON DELETE CASCADE
      )
    `);

    // Create indexes for performance
    await sequelize.query(`
      CREATE INDEX IF NOT EXISTS idx_user_signatures_user_id 
      ON user_signatures(user_id);
    `);

    await sequelize.query(`
      CREATE INDEX IF NOT EXISTS idx_user_signatures_default_active 
      ON user_signatures(user_id, is_default, is_active);
    `);

    console.log('[user-signatures] ✅ user_signatures table created successfully');
  } catch (error) {
    console.error('[user-signatures] Error creating table:', error);
    throw error;
  }
}

async function down() {
  try {
    console.log('[user-signatures] Dropping user_signatures table...');
    
    await sequelize.query('DROP TABLE IF EXISTS user_signatures CASCADE');
    
    console.log('[user-signatures] ✅ user_signatures table dropped successfully');
  } catch (error) {
    console.error('[user-signatures] Error dropping table:', error);
    throw error;
  }
}

module.exports = { up, down };
