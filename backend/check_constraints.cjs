const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'flow_space',
  password: 'postgres',
  port: 5432
});

async function checkConstraints() {
  try {
    const result = await pool.query(`
      SELECT conname, pg_get_constraintdef(oid) as consrc
      FROM pg_constraint 
      WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'deliverables') 
      AND contype = 'c'
    `);
    
    console.log('🔍 Check constraints for deliverables table:');
    result.rows.forEach(c => {
      console.log(`   ${c.conname}: ${c.consrc}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkConstraints();
