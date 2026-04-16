const { UserSignature, sequelize } = require('../models');
const { verifyToken } = require('../utils/authUtils');

/**
 * Enhanced signature service with reusable signature support
 * Manages user signatures, DocuSign integration, and audit trail
 */
class SignatureService {
  
  /**
   * Get all signatures for a user
   * @param {string} userId - User ID
   * @returns {Array} - User's signatures
   */
  static async getUserSignatures(userId) {
    try {
      return await UserSignature.getAllForUser(userId);
    } catch (error) {
      console.error('Error fetching user signatures:', error);
      throw error;
    }
  }

  /**
   * Get user's default signature
   * @param {string} userId - User ID
   * @returns {Object|null} - Default signature or null
   */
  static async getDefaultSignature(userId) {
    try {
      return await UserSignature.getDefaultForUser(userId);
    } catch (error) {
      console.error('Error fetching default signature:', error);
      throw error;
    }
  }

  /**
   * Save a new signature for user
   * @param {string} userId - User ID
   * @param {string} signatureData - Base64 signature data
   * @param {string} signatureType - Type of signature (drawn, typed, uploaded)
   * @param {boolean} isDefault - Whether to set as default
   * @returns {Object} - Created signature
   */
  static async saveSignature(userId, signatureData, signatureType = 'drawn', isDefault = false) {
    try {
      // If setting as default, unset existing default
      if (isDefault) {
        await UserSignature.update(
          { is_default: false },
          { where: { user_id: userId } }
        );
      }

      return await UserSignature.createSignature(userId, signatureData, signatureType, isDefault);
    } catch (error) {
      console.error('Error saving signature:', error);
      throw error;
    }
  }

  /**
   * Update existing signature
   * @param {string} signatureId - Signature ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} updates - Updates to apply
   * @returns {Object|null} - Updated signature or null
   */
  static async updateSignature(signatureId, userId, updates) {
    try {
      const signature = await UserSignature.findOne({
        where: { id: signatureId, user_id: userId }
      });

      if (!signature) {
        throw new Error('Signature not found or unauthorized');
      }

      // If setting as default, unset others
      if (updates.is_default) {
        await UserSignature.update(
          { is_default: false },
          { where: { user_id: userId } }
        );
      }

      return await signature.update(updates);
    } catch (error) {
      console.error('Error updating signature:', error);
      throw error;
    }
  }

  /**
   * Delete signature
   * @param {string} signatureId - Signature ID
   * @param {string} userId - User ID (for authorization)
   * @returns {boolean} - Success status
   */
  static async deleteSignature(signatureId, userId) {
    try {
      const result = await UserSignature.destroy({
        where: { id: signatureId, user_id: userId }
      });

      return result > 0;
    } catch (error) {
      console.error('Error deleting signature:', error);
      throw error;
    }
  }

  /**
   * Set signature as default
   * @param {string} signatureId - Signature ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Object|null} - Updated signature or null
   */
  static async setDefaultSignature(signatureId, userId) {
    try {
      const signature = await UserSignature.findOne({
        where: { id: signatureId, user_id: userId }
      });

      if (!signature) {
        throw new Error('Signature not found or unauthorized');
      }

      await signature.setAsDefault();
      return signature;
    } catch (error) {
      console.error('Error setting default signature:', error);
      throw error;
    }
  }

  /**
   * Sign document using saved signature
   * @param {string} reportId - Report ID
   * @param {string} userId - User ID
   * @param {string} signatureId - Signature ID to use
   * @param {Object} signOffData - Additional sign-off data
   * @returns {Object} - Signing result
   */
  static async signWithSavedSignature(reportId, userId, signatureId, signOffData = {}) {
    const transaction = await sequelize.transaction();
    
    try {
      // Get signature
      const signature = await UserSignature.findOne({
        where: { id: signatureId, user_id: userId, is_active: true }
      });

      if (!signature) {
        throw new Error('Signature not found or inactive');
      }

      // Mark signature as used
      await signature.markAsUsed();

      // Create audit log entry
      const auditLog = await this.createAuditLog({
        reportId,
        userId,
        signatureId: signature.id,
        action: 'document_signed',
        signatureData: signature.signature_data,
        metadata: {
          signatureType: signature.signature_type,
          signOffData,
          timestamp: new Date().toISOString()
        }
      }, { transaction });

      // Update report status if needed
      await this.updateReportSignStatus(reportId, userId, {
        status: 'signed',
        signatureId: signature.id,
        signedAt: new Date(),
        auditLogId: auditLog.id
      }, { transaction });

      await transaction.commit();

      return {
        success: true,
        signatureId: signature.id,
        auditLogId: auditLog.id,
        signedAt: new Date(),
        message: 'Document signed successfully with saved signature'
      };

    } catch (error) {
      await transaction.rollback();
      console.error('Error signing with saved signature:', error);
      throw error;
    }
  }

  /**
   * Create audit log for signature actions
   * @param {Object} logData - Log entry data
   * @param {Object} transaction - Database transaction
   * @returns {Object} - Created audit log
   */
  static async createAuditLog(logData, transaction = null) {
    const AuditLog = sequelize.models.AuditLog;
    
    return await AuditLog.create({
      entity_type: 'report',
      entity_id: logData.reportId,
      user_id: logData.userId,
      action: logData.action,
      details: {
        signatureId: logData.signatureId,
        signatureData: logData.signatureData,
        metadata: logData.metadata
      },
      created_at: new Date()
    }, { transaction });
  }

  /**
   * Update report signing status
   * @param {string} reportId - Report ID
   * @param {string} userId - User ID
   * @param {Object} statusData - Status update data
   * @param {Object} transaction - Database transaction
   */
  static async updateReportSignStatus(reportId, userId, statusData, transaction = null) {
    // This would integrate with your existing report/signoff models
    // Implementation depends on your current report structure
    
    // Example implementation - adjust based on your actual models
    try {
      const Signoff = sequelize.models.Signoff;
      
      await Signoff.upsert({
        entity_type: 'report',
        entity_id: reportId,
        user_id: userId,
        status: statusData.status,
        signature_id: statusData.signatureId,
        signed_at: statusData.signedAt,
        audit_log_id: statusData.auditLogId,
        updated_at: new Date()
      }, { transaction });

    } catch (error) {
      console.error('Error updating report sign status:', error);
      // Don't throw here as it might be a different model structure
    }
  }

  /**
   * Get signature audit trail
   * @param {string} reportId - Report ID
   * @returns {Array} - Audit log entries
   */
  static async getSignatureAuditTrail(reportId) {
    try {
      const AuditLog = sequelize.models.AuditLog;
      
      return await AuditLog.findAll({
        where: {
          entity_type: 'report',
          entity_id: reportId,
          action: ['document_signed', 'signature_created', 'signature_updated']
        },
        order: [['created_at', 'DESC']],
        include: [{
          model: sequelize.models.User,
          as: 'user',
          attributes: ['id', 'email', 'first_name', 'last_name']
        }]
      });
    } catch (error) {
      console.error('Error fetching audit trail:', error);
      throw error;
    }
  }

  /**
   * Verify signature ownership and validity
   * @param {string} signatureId - Signature ID
   * @param {string} userId - User ID
   * @returns {Object} - Verification result
   */
  static async verifySignature(signatureId, userId) {
    try {
      const signature = await UserSignature.findOne({
        where: { id: signatureId, user_id: userId, is_active: true }
      });

      return {
        valid: !!signature,
        signature: signature,
        canUse: signature && signature.is_active
      };
    } catch (error) {
      console.error('Error verifying signature:', error);
      return { valid: false, canUse: false };
    }
  }
}

module.exports = SignatureService;
