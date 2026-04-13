const { verifyToken } = require('../utils/authUtils');

/**
 * Middleware to authenticate JWT token
 * @param {object} req - Express request object
 * @param {object} res - Express response object
 * @param {function} next - Express next function
 */
const authenticateToken = async (req, res, next) => {
  try {
    if (req.method === 'OPTIONS') {
      return next();
    }
    const authHeader = req.headers.authorization;
    let token = authHeader && authHeader.split(' ')[1];
    if (!token && req.headers['x-access-token']) {
      token = String(req.headers['x-access-token']);
    }
    if (!token && req.query && (req.query.access_token || req.query.token)) {
      token = String(req.query.access_token || req.query.token);
    }
    
    if (!token) {
      return res.status(401).json({
        error: 'Access token required',
        message: 'Please provide a valid authentication token'
      });
    }
    
    const payload = verifyToken(token);
    if (!payload || payload.type !== 'access') {
      return res.status(401).json({
        error: 'Invalid token',
        message: 'The provided token is invalid or expired'
      });
    }
    
    // Attach user information to request
    req.user = {
      id: payload.sub, // UUID should not be parsed as integer
      email: payload.email,
      role: payload.role
    };
    
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    return res.status(401).json({
      error: 'Authentication failed',
      message: 'Invalid or missing token'
    });
  }
};

/**
 * Middleware to require active user
 * @param {object} req - Express request object
 * @param {object} res - Express response object
 * @param {function} next - Express next function
 */
const requireActiveUser = async (req, res, next) => {
  try {
    // This would typically check if the user is active in the database
    // For now, we'll assume all authenticated users are active
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Please authenticate to access this resource'
      });
    }
    
    next();
  } catch (error) {
    console.error('Active user check error:', error);
    return res.status(500).json({
      error: 'User status check failed',
      message: 'An error occurred while checking user status'
    });
  }
};

/**
 * Middleware to require specific user roles
 * @param {array} allowedRoles - Array of allowed roles
 * @returns {function} - Express middleware function
 */
const requireRole = (allowedRoles) => {
  return (req, res, next) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          message: 'Please authenticate to access this resource'
        });
      }
      
      // Normalize role names for comparison
      const normalize = (r) => String(r || '')
        .toLowerCase()
        .replace(/[_\s-]+/g, '');
      const userRole = normalize(req.user.role);
      const normalizedAllowedRoles = allowedRoles.map(role => normalize(role));
      
      if (!normalizedAllowedRoles.includes(userRole)) {
        return res.status(403).json({
          error: 'Insufficient permissions',
          message: 'You do not have permission to access this resource'
        });
      }
      
      next();
    } catch (error) {
      console.error('Role check error:', error);
      return res.status(500).json({
        error: 'Permission check failed',
        message: 'An error occurred while checking user permissions'
      });
    }
  };
};

module.exports = {
  authenticateToken,
  requireActiveUser,
  requireRole
};
