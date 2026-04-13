// Database pool configuration for ES Module compatibility
import pkg from 'pg';
const { Pool } = pkg;

// Safest approach: Use ONLY DATABASE_URL to avoid credential mismatches
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

// Test database connection
pool.on('connect', () => {
  console.log('✅ Connected to PostgreSQL database via DATABASE_URL');
});

pool.on('error', (err) => {
  console.error('❌ Database pool error:', err.message);
  console.error('❌ Database error details:', err);
});

pool.on('remove', () => {
  console.log('🔌 Database connection removed from pool');
});

// Test the database connection on startup
const testConnection = async () => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW() as current_time, version() as version');
    client.release();
    console.log('✅ Database connection test successful');
    console.log('📊 Database time:', result.rows[0].current_time);
    console.log('🗄️  Database version:', result.rows[0].version.split(' ')[0]);
  } catch (error) {
    console.error('❌ Database connection test failed:', error.message);
    console.error('❌ Connection details:', {
      hasDatabaseUrl: !!process.env.DATABASE_URL,
      nodeEnv: process.env.NODE_ENV,
      isRender: process.env.RENDER === 'true',
      sslEnabled: process.env.DB_SSL === 'true' || process.env.NODE_ENV === 'production' || process.env.RENDER === 'true'
    });
  }
};

// Test connection after a short delay to ensure the app is fully started
setTimeout(testConnection, 2000);

export default pool;
