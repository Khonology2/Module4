const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

// JWT configuration
const SECRET_KEY = process.env.APP_JWT_SECRET || process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production';
const ALGORITHM = process.env.ALGORITHM || 'HS256';
const ACCESS_TOKEN_EXPIRE_MINUTES = parseInt(process.env.ACCESS_TOKEN_EXPIRE_MINUTES) || 30;
const REFRESH_TOKEN_EXPIRE_DAYS = parseInt(process.env.REFRESH_TOKEN_EXPIRE_DAYS) || 7;

/**
 * Verify a password against its hash
 * @param {string} plainPassword - Plain text password
 * @param {string} hashedPassword - Hashed password
 * @returns {Promise<boolean>} - True if password matches
 */
const verifyPassword = async (plainPassword, hashedPassword) => {
  return await bcrypt.compare(plainPassword, hashedPassword);
};

/**
 * Hash a password
 * @param {string} password - Plain text password
 * @returns {Promise<string>} - Hashed password
 */
const getPasswordHash = async (password) => {
  const saltRounds = 12;
  return await bcrypt.hash(password, saltRounds);
};

/**
 * Create a JWT access token
 * @param {object} data - Data to include in token
 * @param {number} expiresDelta - Expiration time in minutes
 * @returns {string} - JWT access token
 */
const createAccessToken = (data, expiresDelta = null) => {
  const toEncode = { ...data };
  const expiresIn = expiresDelta || ACCESS_TOKEN_EXPIRE_MINUTES * 60;
  
  return jwt.sign(
    { ...toEncode, type: 'access' },
    SECRET_KEY,
    { algorithm: ALGORITHM, expiresIn }
  );
};

/**
 * Create a JWT refresh token
 * @param {object} data - Data to include in token
 * @returns {string} - JWT refresh token
 */
const createRefreshToken = (data) => {
  const expiresIn = REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60; // Convert days to seconds
  
  return jwt.sign(
    { ...data, type: 'refresh' },
    SECRET_KEY,
    { algorithm: ALGORITHM, expiresIn }
  );
};

/**
 * Verify a JWT token and return its payload
 * @param {string} token - JWT token
 * @returns {object|null} - Token payload or null if invalid
 */
const verifyToken = (token) => {
  try {
    return jwt.verify(token, SECRET_KEY, { algorithms: [ALGORITHM] });
  } catch (error) {
    return null;
  }
};

/**
 * Generate a random verification token
 * @param {number} length - Token length
 * @returns {string} - Random verification token
 */
const generateVerificationToken = (length = 32) => {
  return crypto.randomBytes(length).toString('hex').slice(0, length);
};

/**
 * Generate a random password reset token
 * @param {number} length - Token length
 * @returns {string} - Random password reset token
 */
const generatePasswordResetToken = (length = 64) => {
  return crypto.randomBytes(length).toString('hex').slice(0, length);
};

/**
 * Extract data from a valid JWT token
 * @param {string} token - JWT token
 * @returns {object|null} - Token data or null if invalid
 */
const getTokenData = (token) => {
  const payload = verifyToken(token);
  if (payload) {
    return {
      user_id: payload.sub,
      email: payload.email,
      role: payload.role,
      exp: payload.exp
    };
  }
  return null;
};

/**
 * Create both access and refresh tokens
 * @param {number} userId - User ID
 * @param {string} email - User email
 * @param {string} role - User role
 * @returns {object} - Object containing access and refresh tokens
 */
const createTokens = (userId, email, role) => {
  const accessToken = createAccessToken({
    sub: userId.toString(),
    email,
    role
  });
  
  const refreshToken = createRefreshToken({
    sub: userId.toString(),
    email,
    role
  });
  
  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    token_type: 'bearer',
    expires_in: ACCESS_TOKEN_EXPIRE_MINUTES * 60
  };
};

/**
 * Validate user role
 * @param {string} role - Role to validate
 * @returns {boolean} - True if role is valid
 */
const validateUserRole = (role) => {
  const validRoles = ['system_admin', 'admin', 'manager', 'user', 'guest'];
  return validRoles.includes(role);
};

/**
 * Get default user role for new registrations
 * @returns {string} - Default user role
 */
const getDefaultUserRole = () => {
  return 'user';
};

module.exports = {
  verifyPassword,
  getPasswordHash,
  createAccessToken,
  createRefreshToken,
  verifyToken,
  generateVerificationToken,
  generatePasswordResetToken,
  getTokenData,
  createTokens,
  validateUserRole,
  getDefaultUserRole
};