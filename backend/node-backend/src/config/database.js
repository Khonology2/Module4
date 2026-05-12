const { Sequelize } = require('sequelize');
require('./env-loader');

const NODE_ENV = String(process.env.NODE_ENV || 'development').toLowerCase();
const DATABASE_URL = (process.env.DATABASE_URL || '').trim();
const DB_DIALECT = String(process.env.DB_DIALECT || '').trim().toLowerCase();
const DB_HOST = (process.env.DB_HOST || process.env.PGHOST || '').trim();
const DB_PORT = (process.env.DB_PORT || process.env.PGPORT || '5432').trim();
const DB_NAME = (process.env.DB_NAME || process.env.PGDATABASE || '').trim();
const DB_USER = (process.env.DB_USER || process.env.PGUSER || '').trim();
const DB_PASSWORD = (process.env.DB_PASSWORD || process.env.PGPASSWORD || '').trim();
const SQLITE_PATH = (process.env.SQLITE_PATH || '').trim();

let sequelize;

if (NODE_ENV !== 'production' &&
    (DB_DIALECT === 'sqlite' ||
        DB_USER.toLowerCase() === 'sqlite' ||
        DATABASE_URL.toLowerCase().startsWith('sqlite:'))) {
  // SQLite configuration for development
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: SQLITE_PATH || DB_NAME || './database.sqlite',
    logging: NODE_ENV === 'development' ? console.log : false,
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000
    }
  });
} else {
  const enableSsl = NODE_ENV === 'production';

  if (DATABASE_URL) {
    sequelize = new Sequelize(DATABASE_URL, {
      dialect: 'postgres',
      logging: NODE_ENV === 'development' ? console.log : false,
      pool: {
        max: 10,
        min: 0,
        acquire: 30000,
        idle: 10000
      },
      dialectOptions: enableSsl
          ? {
              ssl: {
                require: true,
                rejectUnauthorized: false
              }
            }
          : {}
    });
  } else {
    if (!DB_HOST || !DB_NAME || !DB_USER) {
      throw new Error(
        'Missing PostgreSQL env vars: DATABASE_URL or DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD'
      );
    }

    sequelize = new Sequelize(DB_NAME, DB_USER, DB_PASSWORD, {
      host: DB_HOST,
      port: parseInt(DB_PORT, 10),
      dialect: 'postgres',
      logging: NODE_ENV === 'development' ? console.log : false,
      pool: {
        max: 10,
        min: 0,
        acquire: 30000,
        idle: 10000
      },
      dialectOptions: enableSsl
          ? {
              ssl: {
                require: true,
                rejectUnauthorized: false
              }
            }
          : {}
    });
  }
}

// Test database connection
async function testConnection() {
  try {
    await sequelize.authenticate();
    console.log('✅ Database connection established successfully');
    return true;
  } catch (error) {
    console.error('❌ Unable to connect to the database:', error);
    return false;
  }
}

// Sync database tables
async function syncDatabase({ force = false, alter = true } = {}) {
  try {
    await sequelize.sync({ force, alter });
    console.log('Database synchronized successfully.');
    return true;
  } catch (error) {
    console.error('Error synchronizing database:', error);
    return false;
  }
}

module.exports = {
  sequelize,
  testConnection,
  syncDatabase
};
