const express = require('express');
const router = express.Router();
const SignatureService = require('../services/SignatureService');
const { verifyToken } = require('../utils/authUtils');

/**
 * Middleware to verify user authentication
 */
function authenticateUser(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const decoded = verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

/**
 * @route GET /api/signatures
 * @desc Get all signatures for authenticated user
 * @access Private
 */
router.get('/', authenticateUser, async (req, res) => {
  try {
    const signatures = await SignatureService.getUserSignatures(req.user.userId);
    res.json({
      success: true,
      data: signatures
    });
  } catch (error) {
    console.error('Error fetching signatures:', error);
    res.status(500).json({ 
      error: 'Failed to fetch signatures',
      details: error.message 
    });
  }
});

/**
 * @route GET /api/signatures/default
 * @desc Get user's default signature
 * @access Private
 */
router.get('/default', authenticateUser, async (req, res) => {
  try {
    const signature = await SignatureService.getDefaultSignature(req.user.userId);
    res.json({
      success: true,
      data: signature
    });
  } catch (error) {
    console.error('Error fetching default signature:', error);
    res.status(500).json({ 
      error: 'Failed to fetch default signature',
      details: error.message 
    });
  }
});

/**
 * @route POST /api/signatures
 * @desc Save new signature
 * @access Private
 */
router.post('/', authenticateUser, async (req, res) => {
  try {
    const { signatureData, signatureType, isDefault } = req.body;
    
    if (!signatureData) {
      return res.status(400).json({ 
        error: 'Signature data is required' 
      });
    }

    const signature = await SignatureService.saveSignature(
      req.user.userId,
      signatureData,
      signatureType || 'drawn',
      isDefault || false
    );

    res.json({
      success: true,
      data: signature,
      message: 'Signature saved successfully'
    });
  } catch (error) {
    console.error('Error saving signature:', error);
    res.status(500).json({ 
      error: 'Failed to save signature',
      details: error.message 
    });
  }
});

/**
 * @route PUT /api/signatures/:signatureId
 * @desc Update existing signature
 * @access Private
 */
router.put('/:signatureId', authenticateUser, async (req, res) => {
  try {
    const { signatureId } = req.params;
    const updates = req.body;

    const signature = await SignatureService.updateSignature(
      signatureId,
      req.user.userId,
      updates
    );

    res.json({
      success: true,
      data: signature,
      message: 'Signature updated successfully'
    });
  } catch (error) {
    console.error('Error updating signature:', error);
    res.status(500).json({ 
      error: 'Failed to update signature',
      details: error.message 
    });
  }
});

/**
 * @route DELETE /api/signatures/:signatureId
 * @desc Delete signature
 * @access Private
 */
router.delete('/:signatureId', authenticateUser, async (req, res) => {
  try {
    const { signatureId } = req.params;
    
    const success = await SignatureService.deleteSignature(
      signatureId,
      req.user.userId
    );

    if (success) {
      res.json({
        success: true,
        message: 'Signature deleted successfully'
      });
    } else {
      res.status(404).json({
        error: 'Signature not found'
      });
    }
  } catch (error) {
    console.error('Error deleting signature:', error);
    res.status(500).json({ 
      error: 'Failed to delete signature',
      details: error.message 
    });
  }
});

/**
 * @route POST /api/signatures/:signatureId/set-default
 * @desc Set signature as default
 * @access Private
 */
router.post('/:signatureId/set-default', authenticateUser, async (req, res) => {
  try {
    const { signatureId } = req.params;
    
    const signature = await SignatureService.setDefaultSignature(
      signatureId,
      req.user.userId
    );

    res.json({
      success: true,
      data: signature,
      message: 'Signature set as default'
    });
  } catch (error) {
    console.error('Error setting default signature:', error);
    res.status(500).json({ 
      error: 'Failed to set default signature',
      details: error.message 
    });
  }
});

/**
 * @route POST /api/signatures/sign-document
 * @desc Sign document using saved signature
 * @access Private
 */
router.post('/sign-document', authenticateUser, async (req, res) => {
  try {
    const { reportId, signatureId, signOffData } = req.body;
    
    if (!reportId || !signatureId) {
      return res.status(400).json({ 
        error: 'Report ID and Signature ID are required' 
      });
    }

    // Verify signature ownership
    const verification = await SignatureService.verifySignature(signatureId, req.user.userId);
    if (!verification.valid) {
      return res.status(403).json({ 
        error: 'Invalid or unauthorized signature' 
      });
    }

    const result = await SignatureService.signWithSavedSignature(
      reportId,
      req.user.userId,
      signatureId,
      signOffData
    );

    res.json({
      success: true,
      data: result,
      message: 'Document signed successfully'
    });
  } catch (error) {
    console.error('Error signing document:', error);
    res.status(500).json({ 
      error: 'Failed to sign document',
      details: error.message 
    });
  }
});

/**
 * @route GET /api/signatures/audit/:reportId
 * @desc Get signature audit trail for report
 * @access Private
 */
router.get('/audit/:reportId', authenticateUser, async (req, res) => {
  try {
    const { reportId } = req.params;
    
    const auditTrail = await SignatureService.getSignatureAuditTrail(reportId);
    
    res.json({
      success: true,
      data: auditTrail
    });
  } catch (error) {
    console.error('Error fetching audit trail:', error);
    res.status(500).json({ 
      error: 'Failed to fetch audit trail',
      details: error.message 
    });
  }
});

module.exports = router;
