const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

// Get environment from NODE_ENV or default to 'development'
const environment = process.env.NODE_ENV || 'development';

// Load base .env first (if present), then load env-specific .env.<env> (if present).
// This prevents a missing key in .env.<env> from "hiding" a key that exists in .env.
const baseCandidates = [
	path.resolve(__dirname, '..', '..', '.env'),                    // node-backend/.env
	path.resolve(__dirname, '..', '..', '..', '.env'),              // backend/.env
	path.resolve(__dirname, '..', '..', '..', '..', '.env')         // repo root .env
];
const envSpecificCandidates = [
	path.resolve(__dirname, '..', '..', `.env.${environment}`),     // node-backend/.env.development, .env.sit, etc.
];
const localOverrideCandidates = [
	path.resolve(__dirname, '..', '..', '.env.local'),
	path.resolve(__dirname, '..', '..', `.env.${environment}.local`),
];

const loadedPaths = [];
for (const p of baseCandidates) {
	if (fs.existsSync(p)) {
		const result = dotenv.config({ path: p, override: true });
		loadedPaths.push(p);
		try {
			const parsed = result && result.parsed ? result.parsed : null;
			const hasGeminiInFile = !!(parsed && Object.prototype.hasOwnProperty.call(parsed, 'GEMINI_API_KEY'));
			console.log('GEMINI_API_KEY in loaded env file:', hasGeminiInFile ? 'yes' : 'no');
		} catch (_) {}
		break;
	}
}
for (const p of envSpecificCandidates) {
	if (fs.existsSync(p)) {
		dotenv.config({ path: p, override: true });
		loadedPaths.push(p);
		break;
	}
}
for (const p of localOverrideCandidates) {
	if (fs.existsSync(p)) {
		dotenv.config({ path: p, override: true });
		loadedPaths.push(p);
	}
}

if (loadedPaths.length === 0) {
	dotenv.config({ override: false });
}

try {
	const host = (process.env.DB_HOST || process.env.PGHOST || '').trim();
	const port = (process.env.DB_PORT || process.env.PGPORT || '5432').trim();
	const name = (process.env.DB_NAME || process.env.PGDATABASE || '').trim();
	const user = (process.env.DB_USER || process.env.PGUSER || '').trim();
	const password = (process.env.DB_PASSWORD || process.env.PGPASSWORD || '').trim();

	// Keep local DB connectivity stable across branch switches/pulls.
	if (host && name && user && password) {
		process.env.DATABASE_URL = `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${name}`;
	}
} catch (_) {}

try {
	if (!process.env.GEMINI_API_KEY) {
		const keys = Object.keys(process.env || {});
		const normalizedTarget = 'GEMINI_API_KEY';
		const candidate = keys.find((k) => {
			if (!k || k === normalizedTarget) return false;
			const norm = String(k).replace(/[^\w]/g, '');
			return norm === normalizedTarget;
		});
		if (candidate && process.env[candidate]) {
			process.env.GEMINI_API_KEY = process.env[candidate];
			console.log('Normalized GEMINI_API_KEY from env key:', candidate);
		}
	}
} catch (_) {}

try {
	process.env.ENV_LOADED_FROM = loadedPaths.join(';');
} catch (_) {}

console.log('='.repeat(50));
console.log(`🌍 Environment: ${environment.toUpperCase()}`);
console.log('='.repeat(50));
console.log('Environment variables loaded from:', loadedPaths.length > 0 ? loadedPaths.join(' -> ') : 'process.env (none found)');
console.log('DATABASE_URL:', process.env.DATABASE_URL ? '*** (set)' : 'undefined');
console.log('GEMINI_API_KEY:', process.env.GEMINI_API_KEY ? '*** (set)' : 'undefined');
console.log('NODE_ENV:', process.env.NODE_ENV || 'undefined');
console.log('PORT:', process.env.PORT || '8000 (default)');
console.log('='.repeat(50));

module.exports = process.env;
