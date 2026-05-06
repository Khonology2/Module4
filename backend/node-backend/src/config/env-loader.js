const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

// Get environment from NODE_ENV or default to 'development'
const environment = process.env.NODE_ENV || 'development';

// Try a few sensible locations for environment files
const candidates = [
	path.resolve(__dirname, '..', '..', `.env.${environment}`),     // node-backend/.env.sit, .env.prod, etc.
	path.resolve(__dirname, '..', '..', '.env'),                   // node-backend/.env (fallback)
	path.resolve(__dirname, '..', '..', '..', '.env'),              // backend/.env
	path.resolve(__dirname, '..', '..', '..', '..', '.env')         // repo root .env (last fallback)
];

let loadedPath = null;
for (const p of candidates) {
	if (fs.existsSync(p)) {
		dotenv.config({ path: p });
		loadedPath = p;
		break;
	}
}

// If none found, fall back to default dotenv behaviour (will use process.env)
if (!loadedPath) {
	dotenv.config();
}

console.log('='.repeat(50));
console.log(`🌍 Environment: ${environment.toUpperCase()}`);
console.log('='.repeat(50));
console.log('Environment variables loaded from:', loadedPath || 'process.env (none found)');
console.log('DATABASE_URL:', process.env.DATABASE_URL ? '*** (set)' : 'undefined');
console.log('NODE_ENV:', process.env.NODE_ENV || 'undefined');
console.log('PORT:', process.env.PORT || '3001 (default)');
console.log('='.repeat(50));

module.exports = process.env;