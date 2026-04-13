module.exports = (sequelize, DataTypes) => {
  const ProjectMember = sequelize.define('ProjectMember', {
    id: {
      type: DataTypes.BIGINT,
      primaryKey: true,
      autoIncrement: true
    },
    project_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'projects',
        key: 'id'
      }
    },
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    role: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: 'contributor'
    },
    added_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
      field: 'joined_at',
    },
  }, {
    tableName: 'project_members',
    underscored: true,
    timestamps: false
  });

  ProjectMember.associate = (models) => {
    ProjectMember.belongsTo(models.Project, {
      foreignKey: 'project_id',
      as: 'project'
    });
    ProjectMember.belongsTo(models.User, {
      foreignKey: 'user_id',
      as: 'user'
    });
  };

  return ProjectMember;
};
