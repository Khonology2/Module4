module.exports = (sequelize, DataTypes) => {
  const RepositoryDocument = sequelize.define('RepositoryDocument', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    filename: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
    },
    original_name: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    title: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    tags: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    file_type: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    file_size: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    url: {
      type: DataTypes.STRING(1000),
      allowNull: false,
    },
    storage_provider: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'cloudinary',
    },
    cloudinary_public_id: {
      type: DataTypes.STRING(512),
      allowNull: true,
    },
    cloudinary_resource_type: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    cloudinary_version: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    project_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    project_key: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    sprint_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    deliverable_id: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    uploaded_by: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    uploader_name: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    created_at: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  }, {
    tableName: 'repository_documents',
    underscored: true,
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: false,
  });

  RepositoryDocument.associate = function(models) {
    RepositoryDocument.belongsTo(models.User, {
      foreignKey: 'uploaded_by',
      as: 'uploader',
    });
  };

  return RepositoryDocument;
};
