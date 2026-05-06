module.exports = (sequelize, DataTypes) => {
  const AuditLog = sequelize.define('AuditLog', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.UUID,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    user_email: {
      type: DataTypes.STRING(255)
    },
    user_role: {
      type: DataTypes.STRING(100)
    },
    session_id: {
      type: DataTypes.STRING(500)
    },
    ip_address: {
      type: DataTypes.STRING(50)
    },
    user_agent: {
      type: DataTypes.STRING(500)
    },
    action: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    action_category: {
      type: DataTypes.STRING(100)
    },
    entity_type: {
      type: DataTypes.STRING(100)
    },
    entity_id: {
      type: DataTypes.STRING(255)
    },
    entity_name: {
      type: DataTypes.STRING(255)
    },
    old_values: {
      type: DataTypes.JSON
    },
    new_values: {
      type: DataTypes.JSON
    },
    changed_fields: {
      type: DataTypes.JSON
    },
    request_id: {
      type: DataTypes.STRING(500)
    },
    endpoint: {
      type: DataTypes.STRING(500)
    },
    http_method: {
      type: DataTypes.STRING(10)
    },
    status_code: {
      type: DataTypes.INTEGER
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'audit_logs',
    underscored: true,
    timestamps: false
  });

  AuditLog.associate = function(models) {
    AuditLog.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user'
    });

    AuditLog.belongsTo(models.Deliverable, {
      foreignKey: 'entity_id',
      constraints: false,
      as: 'deliverable'
    });

    AuditLog.belongsTo(models.Sprint, {
      foreignKey: 'entity_id',
      constraints: false,
      as: 'sprint'
    });

    AuditLog.belongsTo(models.Signoff, {
      foreignKey: 'entity_id',
      constraints: false,
      as: 'signoff'
    });
  };

  // Static method to log changes
  AuditLog.logChange = async function(user, entity, action, oldValues = null, newValues = null, additionalData = {}) {
    let changedFields = {};
    
    if (oldValues && newValues) {
      for (const key of Object.keys(oldValues)) {
        if (oldValues[key] !== newValues[key]) {
          changedFields[key] = {
            old: oldValues[key],
            new: newValues[key]
          };
        }
      }
    }

    const entityName = entity.name || entity.title || entity.id.toString();
    
    return await AuditLog.create({
      user_id: user ? user.id : null,
      user_email: user ? user.email : null,
      user_role: user ? user.role : null,
      action,
      action_category: entity.constructor.name.toLowerCase(),
      entity_type: entity.constructor.name.toLowerCase(),
      entity_id: entity.id ? entity.id.toString() : null,
      entity_name: entityName,
      old_values: oldValues,
      new_values: newValues,
      changed_fields: changedFields,
      ...additionalData
    });
  };

  AuditLog.afterCreate(async (auditLog) => {
    try {
      if (!global.realtimeEvents) return;
      global.realtimeEvents.emit('audit_log_created', auditLog.toJSON());
    } catch (error) {
      console.error('Error in audit log afterCreate hook:', error);
    }
  });

  return AuditLog;
};
