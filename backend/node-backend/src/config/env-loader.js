const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

const initialNodeEnv = process.env.NODE_ENV;
const environment = String(initialNodeEnv || 'development').toLowerCase();

// Try a few sensible locations for environment files
const candidates = [
	path.resolve(__dirname, '..', '..', `.env.${environment}`),     // node-backend/.env.sit, .env.prod, etc.
	path.resolve(__dirname, '..', '..', '.env'),                   // node-backend/.env (fallback)
	path.resolve(__dirname, '..', '..', '..', '.env'),              // backend/.env
	path.resolve(__dirname, '..', '..', '..', '..', '.env')         // repo root .env (last fallback)
];
// Prefer .env.<NODE_ENV>; if NODE_ENV was unset or is "development", also try common local files
// (e.g. only .env.sit exists — typical when pointing a dev machine at a shared SIT config).
const envSpecificCandidates = [
	path.resolve(__dirname, '..', '..', `.env.${environment}`),
];
if (!initialNodeEnv || environment === 'development') {
	envSpecificCandidates.push(
		path.resolve(__dirname, '..', '..', '.env.local'),
		path.resolve(__dirname, '..', '..', '.env.sit'),
		path.resolve(__dirname, '..', '..', '.env.staging')
	);
}

const loadedPaths = [];
for (const p of candidates) {
	if (fs.existsSync(p)) {
		dotenv.config({ path: p });
		loadedPaths.push(p);
		break;
	}
}

if (loadedPaths.length === 0) {
	dotenv.config({ override: false });
}

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

const resolvedEnv = String(process.env.NODE_ENV || 'development').toLowerCase();
console.log('='.repeat(50));
console.log(`🌍 Environment: ${resolvedEnv.toUpperCase()}`);
console.log('='.repeat(50));
console.log('Environment variables loaded from:', loadedPaths[0] || 'process.env (none found)');
console.log('DATABASE_URL:', process.env.DATABASE_URL ? '*** (set)' : 'undefined');
console.log('NODE_ENV:', process.env.NODE_ENV || 'undefined');
console.log('PORT:', process.env.PORT || '8000 (default)');
console.log('='.repeat(50));

module.exports = process.env;
