const jwt = require('jsonwebtoken');
const crypto = require('crypto');

function normalizeRole(roleLike) {
  const raw = String(roleLike || '').trim();
  const normalized = raw.toLowerCase().replace(/[^a-z0-9]/g, '');

  if (normalized.includes('systemadmin') || normalized.includes('administrator') || normalized === 'admin') {
    return 'systemAdmin';
  }
  if (normalized.includes('deliverymanager') || normalized.includes('deliverylead') || normalized.includes('manager') || normalized === 'lead') {
    return 'deliveryLead';
  }
  if (normalized.includes('clientreviewer') || normalized.includes('client') || normalized.includes('reviewer')) {
    return 'clientReviewer';
  }
  if (normalized.includes('teammember') || normalized === 'member' || normalized === 'team') {
    return 'teamMember';
  }
  return 'teamMember';
}

function dashboardForRole(role) {
  const map = {
    systemAdmin: '/dashboard',
    deliveryLead: '/dashboard',
    clientReviewer: '/dashboard',
    teamMember: '/dashboard'
  };
  return map[role] || '/dashboard';
}

function tryBase64Decode(value) {
  try {
    const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
    return Buffer.from(normalized, 'base64').toString('utf8');
  } catch (_) {
    return null;
  }
}

function decryptUpstreamToken(token, decryptionKey) {
  const key = Buffer.from(decryptionKey, 'base64');
  const parts = token.split('.');

  if (parts.length === 1) {
    const decoded = tryBase64Decode(token);
    if (decoded) return decoded;
  }

  if (parts.length >= 2) {
    const iv = Buffer.from(parts[0], 'base64');
    const cipherText = Buffer.from(parts[1], 'base64');
    if (iv.length > 0 && cipherText.length > 0) {
      try {
        const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
        const plain = Buffer.concat([decipher.update(cipherText), decipher.final()]);
        return plain.toString('utf8');
      } catch (_) {
        // Ignore and try other fallbacks.
      }
    }
  }

  throw new Error('Unable to decrypt upstream token');
}

function verifyUpstreamJwt(token, jwtSecret) {
  return jwt.verify(token, jwtSecret, {
    algorithms: ['HS256', 'HS384', 'HS512']
  });
}

function parseAndVerifyUpstreamToken(rawToken) {
  const upstreamToken = String(rawToken || '').trim();
  if (!upstreamToken) {
    const error = new Error('Token is required');
    error.code = 'TOKEN_MISSING';
    throw error;
  }

  const ssoJwtSecret = process.env.SSO_JWT_SECRET;
  const ssoDecryptionKey = process.env.SSO_DECRYPTION_KEY;
  if (!ssoJwtSecret || !ssoDecryptionKey) {
    const error = new Error('SSO keys are not configured');
    error.code = 'SSO_CONFIG_INVALID';
    throw error;
  }

  let decoded;
  try {
    decoded = verifyUpstreamJwt(upstreamToken, ssoJwtSecret);
  } catch (_) {
    try {
      const decrypted = decryptUpstreamToken(upstreamToken, ssoDecryptionKey);
      decoded = verifyUpstreamJwt(decrypted, ssoJwtSecret);
    } catch (innerError) {
      const error = new Error('Invalid upstream token');
      error.code = 'TOKEN_INVALID';
      error.cause = innerError;
      throw error;
    }
  }

  const email = decoded.email || decoded.user_email || decoded.preferred_username;
  const roleClaim = decoded.role || decoded.persona || (Array.isArray(decoded.roles) ? decoded.roles[0] : decoded.roles);
  const mappedRole = normalizeRole(roleClaim);

  if (!email) {
    const error = new Error('Upstream token is missing email');
    error.code = 'TOKEN_CLAIMS_INVALID';
    throw error;
  }

  return {
    claims: decoded,
    email: String(email).toLowerCase(),
    name: decoded.name || decoded.full_name || '',
    role: mappedRole,
    dashboard: dashboardForRole(mappedRole)
  };
}

function issueAppTokens(user) {
  const accessSecret = process.env.APP_JWT_SECRET || process.env.JWT_SECRET;
  const refreshSecret = process.env.APP_REFRESH_JWT_SECRET || process.env.JWT_SECRET;
  const accessTtl = process.env.ACCESS_TOKEN_TTL || '15m';
  const refreshTtl = process.env.REFRESH_TOKEN_TTL || '7d';

  const access_token = jwt.sign(
    {
      sub: user.id,
      email: user.email,
      role: user.role,
      type: 'access'
    },
    accessSecret,
    { expiresIn: accessTtl }
  );

  const refresh_token = jwt.sign(
    {
      sub: user.id,
      type: 'refresh'
    },
    refreshSecret,
    { expiresIn: refreshTtl, jwtid: crypto.randomUUID() }
  );

  return { access_token, refresh_token };
}

module.exports = {
  parseAndVerifyUpstreamToken,
  issueAppTokens,
  dashboardForRole,
  normalizeRole
};
