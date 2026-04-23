#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const environments = ['prod', 'sit', 'dev', 'local'];
const targetEnv = process.argv[2];

if (!targetEnv) {
  console.log('Usage: node switch-env.js <environment>');
  console.log('Available environments:', environments.join(', '));
  process.exit(1);
}

if (!environments.includes(targetEnv.toLowerCase())) {
  console.error(`❌ Invalid environment: ${targetEnv}`);
  console.log('Available environments:', environments.join(', '));
  process.exit(1);
}

// Update frontend environment
const frontendEnvPath = path.join(__dirname, '..', 'frontend', 'lib', 'config', 'environment.dart');
let frontendContent = fs.readFileSync(frontendEnvPath, 'utf8');

// Replace the current environment
frontendContent = frontendContent.replace(
  /static const String _currentEnvironment = '[^']*';/,
  `static const String _currentEnvironment = '${targetEnv.toUpperCase()}';`
);

fs.writeFileSync(frontendEnvPath, frontendContent);
console.log(`✅ Frontend environment updated to: ${targetEnv.toUpperCase()}`);

// Create/update backend environment file
const backendEnvPath = path.join(__dirname, '..', 'backend', 'node-backend', `.env.${targetEnv.toLowerCase()}`);

if (!fs.existsSync(backendEnvPath)) {
  const template = `# ${targetEnv.toUpperCase()} Environment Configuration
NODE_ENV=${targetEnv.toLowerCase()}
PORT=8000

# Database Configuration for ${targetEnv.toUpperCase()}
DB_HOST=localhost
DB_PORT=5432
DB_NAME=flow_space_${targetEnv.toLowerCase()}
DB_USER=postgres
DB_PASSWORD=your_${targetEnv.toLowerCase()}_password

# JWT Configuration
JWT_SECRET=your_${targetEnv.toLowerCase()}_jwt_secret_key_here
JWT_EXPIRES_IN=7d

# CORS Configuration
CORS_ORIGIN=http://localhost:3000

# API Configuration
API_VERSION=v1
API_BASE_URL=https://flow-space-${targetEnv.toLowerCase()}.onrender.com

# Logging
LOG_LEVEL=${targetEnv.toLowerCase() === 'prod' ? 'info' : 'debug'}
`;
  
  fs.writeFileSync(backendEnvPath, template);
  console.log(`✅ Backend environment file created: ${backendEnvPath}`);
} else {
  console.log(`✅ Backend environment file already exists: ${backendEnvPath}`);
}

console.log(`\n🎉 Environment successfully switched to: ${targetEnv.toUpperCase()}`);
console.log('\n📋 Next steps:');
console.log('1. Update the database credentials in the backend .env file');
console.log('2. Restart your backend server with NODE_ENV=' + targetEnv.toLowerCase());
console.log('3. Restart your Flutter app to pick up the frontend changes');
