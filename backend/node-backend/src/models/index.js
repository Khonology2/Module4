const database = require('../config/database');
const { DataTypes } = require('sequelize');

// Import all models
const Deliverable = require('./Deliverable');
const Sprint = require('./Sprint');
const DeliverableSprint = require('./DeliverableSprint');
const EpicFeature = require('./EpicFeature');
const EpicFeatureSprint = require('./EpicFeatureSprint');
const Signoff = require('./Signoff');
const AuditLog = require('./AuditLog');
const User = require('./User');
const UserProfile = require('./UserProfile');
const RefreshToken = require('./RefreshToken');
const UserSettings = require('./UserSettings');
const Notification = require('./Notification');
const Project = require('./Project');
const ApprovalRequest = require('./ApprovalRequest');
const Ticket = require('./Ticket');
const DeliverableArtifact = require('./DeliverableArtifact');
const ProjectMember = require('./ProjectMember');
const Timeline = require('./Timeline');

// Function to initialize models with the database connection
function initializeModels(sequelize) {
  const models = {
    Deliverable: Deliverable(sequelize, DataTypes),
    Sprint: Sprint(sequelize, DataTypes),
    DeliverableSprint: DeliverableSprint(sequelize, DataTypes),
    EpicFeature: EpicFeature(sequelize, DataTypes),
    EpicFeatureSprint: EpicFeatureSprint(sequelize, DataTypes),
    Signoff: Signoff(sequelize, DataTypes),
    AuditLog: AuditLog(sequelize, DataTypes),
    User: User(sequelize, DataTypes),
    UserProfile: UserProfile(sequelize, DataTypes),
    RefreshToken: RefreshToken(sequelize, DataTypes),
    UserSettings: UserSettings(sequelize, DataTypes),
    Notification: Notification(sequelize, DataTypes),
    Project: Project(sequelize, DataTypes),
    ApprovalRequest: ApprovalRequest(sequelize, DataTypes),
    Ticket: Ticket(sequelize, DataTypes),
    DeliverableArtifact: DeliverableArtifact(sequelize, DataTypes),
    ProjectMember: ProjectMember(sequelize, DataTypes),
    Timeline: Timeline(sequelize, DataTypes)
  };

  // Set up associations
  Object.keys(models).forEach(modelName => {
    if (models[modelName].associate) {
      models[modelName].associate(models);
    }
  });

  return models;
}

// Initialize models with the database connection
const models = initializeModels(database.sequelize);

module.exports = {
  sequelize: database.sequelize,
  ...models,
  initializeModels
};
