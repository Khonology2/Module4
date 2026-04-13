const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const router = express.Router();
const { User, UserProfile } = require('../models');
const EmailService = require('../services/emailService');
const emailService = new EmailService();
const { authenticateToken } = require('../middleware/auth');

/**
 * @route POST /api/auth/register
 * @desc Register a new user
 * @access Public
 */
router.post('/register', async (req, res) => {
  try {
    // Support multiple field name formats
    const { 
      email, 
      password, 
      fullName,
      firstName: reqFirstName,
      lastName: reqLastName,
      first_name: reqFirstNameSnake,
      last_name: reqLastNameSnake,
      role = 'user' 
    } = req.body;

    // Determine first name and last name from various input formats
    let firstName, lastName;
    
    console.log('Registration request body:', req.body);
    console.log('Extracted fields:', { email, password, fullName, reqFirstName, reqLastName, reqFirstNameSnake, reqLastNameSnake, role });
    
    if (fullName) {
      // If fullName is provided, split it
      const nameParts = fullName.split(' ');
      firstName = nameParts[0];
      lastName = nameParts.slice(1).join(' ');
    } else if (reqFirstName || reqFirstNameSnake) {
      // If separate firstName/lastName fields are provided (camelCase or snake_case)
      firstName = reqFirstName || reqFirstNameSnake || '';
      lastName = reqLastName || reqLastNameSnake || '';
    }
    
    console.log('Determined firstName:', firstName);
    console.log('Determined lastName:', lastName);

    // Validate input
    if (!email || !password || !firstName) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Email, password, first name, and last name are required'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({
      where: { email }
    });

    if (existingUser) {
      return res.status(409).json({
        error: 'User already exists',
        message: 'A user with this email or username already exists'
      });
    }

    // Hash password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    const cleanRole = String(role || 'user')
      .toLowerCase()
      .replace('userrole.', '')
      .replace(/[_\s-]+/g, '');
    const roleMap = {
      'stakeholder': 'systemAdmin',
      'systemadmin': 'systemAdmin',
      'admin': 'systemAdmin',
      'deliverylead': 'deliveryLead',
      'clientreviewer': 'clientReviewer',
      'scrummaster': 'teamMember',
      'qaengineer': 'teamMember',
      'developer': 'teamMember',
      'teammember': 'teamMember',
      'user': 'user'
    };
    const normalizedRole = roleMap[cleanRole] || 'user';

    const user = await User.create({
      email,
      hashed_password: hashedPassword,
      first_name: firstName,
      last_name: lastName,
      role: normalizedRole,
      is_active: true
    });

    const enabled = (process.env.ENABLE_EMAIL_VERIFICATION === 'true') || (process.env.EMAIL_VERIFICATION_ENABLED === 'true') || (process.env.EMAIL_SERVICE_ENABLED === 'true') || ((process.env.SMTP_USER && process.env.SMTP_PASS) ? true : false);
    let emailVerificationSent = false;
    if (enabled) {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      await user.update({ verification_token: code });
      const name = [user.first_name, user.last_name].filter(Boolean).join(' ') || user.email;
      const result = await emailService.sendVerificationEmail(user.email, name, code);
      emailVerificationSent = !!(result && result.success);
    }

    // Generate JWT token
    const token = jwt.sign(
      { sub: user.id, email: user.email, role: user.role, type: 'access' },
      process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production',
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_active: user.is_active
      },
      token,
      expires_in: 86400,
      emailVerificationSent
    });

  } catch (error) {
    console.error('Registration error:', error);
    console.error('Error details:', error.message);
    console.error('Error stack:', error.stack);
    console.error('Request body was:', JSON.stringify(req.body, null, 2));
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to register user',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * @route POST /api/auth/login
 * @desc Login user
 * @access Public
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Email and password are required'
      });
    }

    // Find user
    const user = await User.findOne({
      where: { email }
    });

    if (!user) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid email or password'
      });
    }

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.hashed_password);

    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid email or password'
      });
    }

    // Check if user is active
    if (!user.is_active) {
      return res.status(403).json({
        error: 'Account not active',
        message: 'Your account is not active. Please contact support.'
      });
    }

    // Update last login
    await user.update({ last_login: new Date() });

    // Generate JWT token
    const token = jwt.sign(
      { sub: user.id, email: user.email, role: user.role, type: 'access' },
      process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production',
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        role: user.role,
        is_active: user.is_active
      },
      token
    });

  } catch (error) {
    console.error('Login error:', error);
    console.error('Error details:', error.message);
    console.error('Request body was:', JSON.stringify(req.body, null, 2));
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to login'
    });
  }
});

/**
 * @route GET /api/auth/me
 * @desc Get current user profile
 * @access Private
 */
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ['password'] }
    });

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }

    const email = user.email || '';
    const namePart = typeof email === 'string' ? email.split('@')[0] : '';
    const splitName = namePart.includes('.') ? namePart.split('.') : [];
    const fallbackFirst = user.first_name || (splitName[0] ? splitName[0] : namePart);
    const fallbackLast = user.last_name || (splitName[1] ? splitName[1] : '');
    const displayName = [fallbackFirst, fallbackLast].filter(Boolean).join(' ') || user.username || email;
    const isActive = (user.is_active === true) || (user.status === 'active') || true;
    const createdAt = user.created_at || new Date();
    const lastLogin = user.last_login || user.updated_at || null;

    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: email,
        first_name: fallbackFirst || null,
        last_name: fallbackLast || null,
        name: displayName,
        role: user.role,
        status: user.status || null,
        is_active: isActive,
        last_login: lastLogin,
        created_at: createdAt
      }
    });

  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to get user profile'
    });
  }
});

/**
 * @route POST /api/auth/refresh
 * @desc Refresh JWT token
 * @access Private
 */
router.post('/refresh', authenticateToken, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ['password'] }
    });

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }

    // Generate new JWT token
    const token = jwt.sign(
      { sub: user.id, username: user.username, role: user.role, type: 'access' },
      process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production',
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Token refreshed successfully',
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        status: user.status
      },
      token
    });

  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to refresh token'
    });
  }
});

/**
 * @route POST /api/auth/logout
 * @desc Logout user (client-side token removal)
 * @access Private
 */
router.post('/logout', authenticateToken, (req, res) => {
  res.json({
    message: 'Logout successful',
    note: 'Client should remove the JWT token from storage'
  });
});

router.post('/resend-verification', async (req, res) => {
  try {
    const { email } = req.body || {};
    if (!email) {
      return res.status(400).json({ success: false, error: 'Email is required' });
    }
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    const enabled = (process.env.ENABLE_EMAIL_VERIFICATION === 'true') || (process.env.EMAIL_VERIFICATION_ENABLED === 'true') || (process.env.EMAIL_SERVICE_ENABLED === 'true') || ((process.env.SMTP_USER && process.env.SMTP_PASS) ? true : false);
    if (!enabled) {
      return res.status(200).json({ success: true, message: 'Email verification disabled' });
    }
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    await user.update({ verification_token: code });
    const name = [user.first_name, user.last_name].filter(Boolean).join(' ') || user.email;
    const result = await emailService.sendVerificationEmail(user.email, name, code);
    if (result && result.success === false) {
      return res.status(500).json({ success: false, error: result.error || 'Failed to send email' });
    }
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Resend verification error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

router.post('/verify-email', async (req, res) => {
  try {
    const { email, verificationCode, verification_code, code } = req.body || {};
    const verificationCodeFinal = verificationCode || verification_code || code;
    console.log('Verify email request:', { email, verificationCodeFinal });
    
    if (!email || !verificationCodeFinal) {
      return res.status(400).json({ success: false, error: 'Email and verification code are required' });
    }
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    if (user.verification_token !== verificationCodeFinal) {
      return res.status(400).json({ success: false, error: 'Invalid verification code' });
    }
    await user.update({ is_verified: true, verification_token: null });
    const profile = await UserProfile.findOne({ where: { user_id: user.id } });
    if (profile) {
      await profile.update({ is_email_verified: true });
    }
    return res.status(200).json({ success: true, data: { verified: true } });
  } catch (error) {
    console.error('Verify email error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

router.get('/verification-status', async (req, res) => {
  try {
    const email = req.query.email;
    if (!email) {
      return res.status(400).json({ success: false, error: 'Email is required' });
    }
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    const profile = await UserProfile.findOne({ where: { user_id: user.id } });
    const isVerified = (user.is_verified === true) || (profile && profile.is_email_verified === true);
    return res.status(200).json({ success: true, data: { verified: isVerified } });
  } catch (error) {
    console.error('Verification status error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

/**
 * @route POST /api/auth/change-password
 * @desc Change user password
 * @access Private
 */
router.post('/change-password', authenticateToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        error: 'Missing required fields',
        message: 'Current password and new password are required'
      });
    }

    const user = await User.findByPk(userId);

    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: 'User not found'
      });
    }

    // Verify current password
    const isValidPassword = await bcrypt.compare(currentPassword, user.hashed_password);

    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Invalid current password',
        message: 'Current password is incorrect'
      });
    }

    // Hash new password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await user.update({ hashed_password: hashedPassword });

    res.json({
      message: 'Password changed successfully'
    });

  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: 'Failed to change password'
    });
  }
});

/**
 * @route POST /api/auth/validate-token
 * @desc Validate external JWT token and return user information
 * @access Public
 */
router.post('/validate-token', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        error: 'Token is required',
        message: 'Please provide a JWT token for validation'
      });
    }

    // Validate the JWT token
    const decodedToken = validateJwtToken(token);
    
    // Extract user information
    const userInfo = extractUserInfo(decodedToken);
    
    // Get user role from token (if available)
    let userRole = decodedToken.role || decodedToken.user_role || 'user';
    
    // Check if roles is an array and extract relevant role
    if (decodedToken.roles && Array.isArray(decodedToken.roles)) {
      // Look for specific roles in the roles array
      const roleMapping = {
        'system admin': ['system admin', 'system_admin', 'admin', 'system administrator'],
        'client reviewer': ['client reviewer', 'client_reviewer', 'client'],
        'delivery lead': ['delivery lead', 'delivery_lead', 'delivery'],
        'team member': ['team member', 'team_member', 'team']
      };
      
      // Find the first matching role
      for (const [mappedRole, keywords] of Object.entries(roleMapping)) {
        if (decodedToken.roles.some(role => 
          keywords.some(keyword => role.toLowerCase().includes(keyword.toLowerCase()))
        )) {
          userRole = mappedRole;
          break;
        }
      }
    }
    
    // Determine dashboard URL based on role
    const dashboardUrl = getDashboardUrl(userRole);
    
    // Return success response with user information
    res.json({
      success: true,
      message: 'Token validated successfully',
      user: {
        ...userInfo,
        role: userRole
      },
      redirect: {
        url: dashboardUrl,
        role: userRole
      },
      token: decodedToken // Include full decoded token for additional data
    });

  } catch (error) {
    if (error instanceof JWTValidationError) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token',
        message: error.message
      });
    } else {
      console.error('Unexpected error in token validation:', error);
      return res.status(500).json({
        success: false,
        error: 'Validation failed',
        message: 'An unexpected error occurred during token validation'
      });
    }
  }
});

/**
 * Helper function to determine dashboard URL based on user role
 * @param {string} role - User role
 * @returns {string} Dashboard URL
 */
function getDashboardUrl(role) {
  const dashboardRoutes = {
    'system admin': '/admin/dashboard',
    'system_admin': '/admin/dashboard',
    'client reviewer': '/client/dashboard',
    'client_reviewer': '/client/dashboard',
    'delivery lead': '/delivery/dashboard',
    'delivery_lead': '/delivery/dashboard',
    'team member': '/team/dashboard',
    'team_member': '/team/dashboard',
    'admin': '/admin/dashboard',
    'manager': '/manager/dashboard', 
    'developer': '/developer/dashboard',
    'user': '/user/dashboard'
  };
  
  return dashboardRoutes[role.toLowerCase()] || '/user/dashboard';
}

module.exports = router;
