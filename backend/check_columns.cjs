const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'flow_space',
  password: 'postgres',
  port: 5432
});

async function checkColumns() {
  try {
    const result = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'digital_signatures'
      ORDER BY ordinal_position
    `);
    
    console.log('digital_signatures columns:');
    result.rows.forEach(r => {
      console.log(`   ${r.column_name}: ${r.data_type}`);
    });
    
  } catch (error) {
    console.error(error);
  } finally {
    await pool.end();
  }
}

checkColumns();
