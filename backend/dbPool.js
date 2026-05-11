// Database pool configuration for ES Module compatibility
import pkg from 'pg';
const { Pool } = pkg;

function resolveSslFromDatabaseUrl(databaseUrl) {
  try {
    const parsed = new URL(databaseUrl);
    const host = String(parsed.hostname || '').toLowerCase();
    const sslMode = String(parsed.searchParams.get('sslmode') || '').toLowerCase();
    const isRenderHost = host.includes('render.com');
    const requiresSslMode = ['require', 'verify-ca', 'verify-full', 'prefer'].includes(sslMode);
    return isRenderHost || requiresSslMode;
  } catch (_) {
    return false;
  }
}

// Safest approach: Use ONLY DATABASE_URL to avoid credential mismatches
function createPool() {
  console.log('🛜 Using DATABASE_URL (safest approach)');
  console.log('📊 Connection URL:', process.env.DATABASE_URL ? '***CONFIGURED***' : 'NOT SET');

  if (!process.env.DATABASE_URL) {
    const usingRenderHost = String(process.env.DB_HOST || '').includes('render.com');
    const sslEnabled = process.env.DB_SSL === 'true' || usingRenderHost;
    return new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      database: process.env.DB_NAME || 'flow_space',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
      ssl: sslEnabled ? { rejectUnauthorized: false } : false,
    });
  }

  // SSL CONFIGURATION - Enable SSL in production, respect DB_SSL setting
  const isProduction = process.env.NODE_ENV === 'production' || process.env.RENDER === 'true';
  const forcedSsl = process.env.DB_SSL === 'true';
  const inferredSslFromUrl = resolveSslFromDatabaseUrl(process.env.DATABASE_URL);
  const sslEnabled = forcedSsl || isProduction || inferredSslFromUrl;
  console.log('🔒 SSL Enabled:', sslEnabled);
  console.log('🌍 Production Environment:', isProduction);
  
  return new Pool({
    connectionString: String(process.env.DATABASE_URL || '').trim(),
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
      sslEnabled:
        process.env.DB_SSL === 'true'
        || process.env.NODE_ENV === 'production'
        || process.env.RENDER === 'true'
        || resolveSslFromDatabaseUrl(process.env.DATABASE_URL || '')
    });
  }
};

// Test connection after a short delay to ensure the app is fully started
setTimeout(testConnection, 2000);

export default pool;
