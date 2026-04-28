// Quick fix for PostgreSQL credentials
const fs = require('fs');

// Read current server.js
const serverContent = fs.readFileSync('./server.js', 'utf8');

// Replace the database configuration section
const updatedContent = serverContent.replace(
  /connectionString: process\.env\.DATABASE_URL.*$/m,
  `connectionString: 'postgresql://postgres:property007@localhost:5432/flow_space'`
);

// Write back to server.js
fs.writeFileSync('./server.js', updatedContent);

console.log('✅ Updated server.js with correct PostgreSQL credentials');
console.log('🔄 Please restart your server: npm start');
