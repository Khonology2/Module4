const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

// Mock models
const mockDeliverable = {
  findByPk: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  toJSON: jest.fn().mockReturnValue({}),
};
const mockAuditLog = {
  logChange: jest.fn(),
};
const mockUser = {};

jest.mock('../../models', () => ({
  Deliverable: mockDeliverable,
  AuditLog: mockAuditLog,
  User: mockUser,
  DeliverableSprint: {},
  Signoff: {},
  DeliverableArtifact: { create: jest.fn() },
}));

// Mock fileUploadService
const mockFileUploadService = {
  uploadFile: jest.fn(),
};
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

const deliverablesRouter = require('../deliverables');

const app = express();
app.use(bodyParser.json());
app.use('/api/deliverables', deliverablesRouter);

describe('PUT /api/deliverables/:id - Role Access Control', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should deny non-owners/admins from assigning an owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'dev-1', role: 'developer' };
      next();
    });

    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: jest.fn(),
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ owner_id: 'new-owner' });

    expect(res.status).toBe(403);
    expect(res.body.error).toBe('Only Owners, Admins, and Delivery Leads can assign deliverable owners');
  });

  it('should allow owners to assign an owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'owner-1', role: 'owner' };
      next();
    });

    const mockUpdate = jest.fn();
    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: mockUpdate,
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ owner_id: 'new-owner' });

    expect(res.status).toBe(200);
    expect(mockUpdate).toHaveBeenCalled();
  });
  
  it('should allow admins to assign an owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'admin-1', role: 'admin' };
      next();
    });

    const mockUpdate = jest.fn();
    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: mockUpdate,
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ owner_id: 'new-owner' });

    expect(res.status).toBe(200);
    expect(mockUpdate).toHaveBeenCalled();
  });

  it('should allow system admins to assign an owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'sysadmin-1', role: 'systemAdmin' };
      next();
    });

    const mockUpdate = jest.fn();
    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: mockUpdate,
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ owner_id: 'new-owner' });

    expect(res.status).toBe(200);
    expect(mockUpdate).toHaveBeenCalled();
  });

  it('should allow delivery leads to assign an owner', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'lead-1', role: 'deliveryLead' };
      next();
    });

    const mockUpdate = jest.fn();
    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: mockUpdate,
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ owner_id: 'new-owner' });

    expect(res.status).toBe(200);
    expect(mockUpdate).toHaveBeenCalled();
  });

  it('should allow non-owners to update other fields', async () => {
    mockAuthenticateToken.mockImplementation((req, res, next) => {
      req.user = { id: 'dev-1', role: 'developer' };
      next();
    });

    const mockUpdate = jest.fn();
    mockDeliverable.findByPk.mockResolvedValue({
      id: 1,
      owner_id: 'old-owner',
      update: mockUpdate,
      toJSON: jest.fn().mockReturnValue({ owner_id: 'old-owner' }),
    });

    const res = await request(app)
      .put('/api/deliverables/1')
      .send({ title: 'New Title' }); // No owner_id change

    expect(res.status).toBe(200);
    expect(mockUpdate).toHaveBeenCalled();
  });
});
