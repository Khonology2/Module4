const { Sequelize } = require('sequelize');
require('dotenv').config({ path: '../../.env' });

// Temporary hardcoded PostgreSQL connection to bypass dotenv issues
const DATABASE_URL = 'postgresql://postgres:property007@localhost:5432/flow_space';
const DB_HOST = '127.0.0.1';
const DB_PORT = '5432';
const DB_NAME = 'flow_space';
const DB_USER = 'postgres';
const DB_PASSWORD = 'property007';
const NODE_ENV = 'development';

let sequelize;

// Use SQLite for development, PostgreSQL for production
if (NODE_ENV === 'development' && DB_USER === 'sqlite') {
  // SQLite configuration for development
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: DB_NAME || './database.sqlite',
    logging: console.log,
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
    if (!DB_HOST || !DB_NAME || !DB_USER || !DB_PASSWORD) {
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
