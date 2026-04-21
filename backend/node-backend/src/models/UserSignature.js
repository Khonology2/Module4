module.exports = (sequelize, DataTypes) => {
  const UserSignature = sequelize.define('UserSignature', {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4
    },
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id'
      }
    },
    signature_data: {
      type: DataTypes.TEXT,
      allowNull: false,
      comment: 'Base64 encoded signature image data'
    },
    signature_type: {
      type: DataTypes.ENUM('drawn', 'typed', 'uploaded'),
      defaultValue: 'drawn',
      allowNull: false
    },
    is_default: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'Whether this is the user default signature'
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      comment: 'Whether this signature is currently active'
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    updated_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    },
    last_used_at: {
      type: DataTypes.DATE,
      allowNull: true,
      comment: 'When this signature was last used for signing'
    }
  }, {
    tableName: 'user_signatures',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    indexes: [
      {
        fields: ['user_id']
      },
      {
        fields: ['user_id', 'is_default', 'is_active']
      }
    ]
  });

  // Associations
  UserSignature.associate = (models) => {
    UserSignature.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user'
    });
  };

  // Instance methods
  UserSignature.prototype.markAsUsed = async function() {
    this.last_used_at = new Date();
    await this.save();
  };

  UserSignature.prototype.setAsDefault = async function() {
    // Unset all other signatures for this user
    await UserSignature.update(
      { is_default: false },
      { 
        where: { 
          user_id: this.user_id,
          id: { [sequelize.Sequelize.Op.ne]: this.id }
        }
      }
    );
    
    // Set this as default
    this.is_default = true;
    await this.save();
  };

  // Class methods
  UserSignature.getDefaultForUser = async function(userId) {
    return await UserSignature.findOne({
      where: {
        user_id: userId,
        is_default: true,
        is_active: true
      },
      include: [{
        model: sequelize.models.User,
        as: 'user',
        attributes: ['id', 'email', 'first_name', 'last_name']
      }]
    });
  };

  UserSignature.getAllForUser = async function(userId) {
    return await UserSignature.findAll({
      where: {
        user_id: userId,
        is_active: true
      },
      order: [
        ['is_default', 'DESC'],
        ['last_used_at', 'DESC'],
        ['created_at', 'DESC']
      ],
      include: [{
        model: sequelize.models.User,
        as: 'user',
        attributes: ['id', 'email', 'first_name', 'last_name']
      }]
    });
  };

  UserSignature.createSignature = async function(userId, signatureData, signatureType = 'drawn', isDefault = false) {
    return await UserSignature.create({
      user_id: userId,
      signature_data: signatureData,
      signature_type: signatureType,
      is_default: isDefault,
      is_active: true
    });
  };

  return UserSignature;
};
