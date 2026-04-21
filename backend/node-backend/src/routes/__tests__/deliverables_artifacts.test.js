const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');
const multer = require('multer');

// Mock models
const mockDeliverable = {
  findByPk: jest.fn(),
};
const mockUser = {
  findByPk: jest.fn(),
};
const mockDeliverableArtifact = {
  create: jest.fn(),
  findOne: jest.fn(),
};

// Mock file upload service
const mockFileUploadService = {
  uploadFile: jest.fn(),
  deleteFile: jest.fn(),
};

jest.mock('../../models', () => ({
  Deliverable: mockDeliverable,
  User: mockUser,
  DeliverableArtifact: mockDeliverableArtifact,
  DeliverableSprint: {},
  AuditLog: { logChange: jest.fn() },
}));

jest.mock('../../services/fileUploadService', () => mockFileUploadService);

// Mock auth middleware
const mockAuthenticateToken = jest.fn((req, res, next) => {
  req.user = { id: 'user-1', role: 'developer' }; // Default user
  next();
});

jest.mock('../../middleware/auth', () => ({
  authenticateToken: mockAuthenticateToken,
  requireRole: () => (_req, _res, next) => next(),
}));

// Setup app
const deliverablesRouter = require('../deliverables');
const app = express();
app.use(bodyParser.json());
app.use('/api/deliverables', deliverablesRouter);

describe('POST /api/deliverables/:id/artifacts - RBAC', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should allow owner to upload artifact', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '100', role: 'developer' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100',
    });

    mockUser.findByPk.mockResolvedValue({
        id: 100,
        first_name: 'John',
        last_name: 'Doe'
    });

    mockFileUploadService.uploadFile.mockResolvedValue({
      filename: 'test.pdf',
      originalName: 'test.pdf',
      url: '/uploads/test.pdf'
    });

    mockDeliverableArtifact.create.mockResolvedValue({
      id: 1,
      filename: 'test.pdf'
    });

    const res = await request(app)
      .post('/api/deliverables/1/artifacts')
      .attach('file', Buffer.from('test content'), 'test.pdf');

    expect(res.status).toBe(201);
    expect(mockFileUploadService.uploadFile).toHaveBeenCalled();
  });

  it('should deny non-owner developer from uploading artifact', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '101', role: 'developer' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100', // Different owner
    });

    const res = await request(app)
      .post('/api/deliverables/1/artifacts')
      .attach('file', Buffer.from('test content'), 'test.pdf');

    expect(res.status).toBe(403);
    expect(res.body.error).toMatch(/only upload artifacts to deliverables assigned to you/i);
    expect(mockFileUploadService.uploadFile).not.toHaveBeenCalled();
  });

  it('should allow admin to upload artifact regardless of owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '999', role: 'admin' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100',
    });
    
    mockUser.findByPk.mockResolvedValue({
        id: 999,
        first_name: 'Admin',
        last_name: 'User'
    });

    mockFileUploadService.uploadFile.mockResolvedValue({
      filename: 'admin_upload.pdf',
      originalName: 'admin_upload.pdf',
      url: '/uploads/admin_upload.pdf'
    });
    
    mockDeliverableArtifact.create.mockResolvedValue({
        id: 2,
        filename: 'admin_upload.pdf'
    });

    const res = await request(app)
      .post('/api/deliverables/1/artifacts')
      .attach('file', Buffer.from('test content'), 'admin_upload.pdf');

    expect(res.status).toBe(201);
  });
});

describe('DELETE /api/deliverables/:id/artifacts/:artifactId - RBAC', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should allow owner to delete artifact', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '100', role: 'developer' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100',
    });

    mockDeliverableArtifact.findOne.mockResolvedValue({
      id: 1,
      filename: 'test.pdf',
      uploaded_by: '100',
      destroy: jest.fn(),
      toJSON: jest.fn().mockReturnValue({})
    });

    mockFileUploadService.deleteFile.mockResolvedValue(true);

    const res = await request(app).delete('/api/deliverables/1/artifacts/1');

    expect(res.status).toBe(200);
    expect(mockFileUploadService.deleteFile).toHaveBeenCalled();
  });

  it('should deny non-owner/non-uploader from deleting artifact', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '101', role: 'developer' }; // Not owner, not uploader
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100',
    });

    mockDeliverableArtifact.findOne.mockResolvedValue({
      id: 1,
      filename: 'test.pdf',
      uploaded_by: '100', // Uploaded by owner
      destroy: jest.fn(),
      toJSON: jest.fn().mockReturnValue({})
    });

    const res = await request(app).delete('/api/deliverables/1/artifacts/1');

    expect(res.status).toBe(403);
    expect(mockFileUploadService.deleteFile).not.toHaveBeenCalled();
  });

  it('should allow admin to delete artifact', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: '999', role: 'admin' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: '100',
    });

    mockDeliverableArtifact.findOne.mockResolvedValue({
      id: 1,
      filename: 'test.pdf',
      uploaded_by: '100',
      destroy: jest.fn(),
      toJSON: jest.fn().mockReturnValue({})
    });

    mockFileUploadService.deleteFile.mockResolvedValue(true);

    const res = await request(app).delete('/api/deliverables/1/artifacts/1');

    expect(res.status).toBe(200);
    expect(mockFileUploadService.deleteFile).toHaveBeenCalled();
  });
});
