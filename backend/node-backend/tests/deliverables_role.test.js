const request = require('supertest');
const express = require('express');

// Mock dependencies
jest.mock('../src/models', () => ({
  Deliverable: {
    findByPk: jest.fn(),
    findAll: jest.fn(),
    create: jest.fn(),
  },
  DeliverableSprint: {
    findAll: jest.fn(),
  },
  AuditLog: {
    logChange: jest.fn(),
  },
  User: {},
}));

jest.mock('../src/middleware/auth', () => ({
  authenticateToken: (req, res, next) => {
    // Allow tests to specify the role via header
    const role = req.headers['mock-role'] || 'user';
    req.user = { id: 'test-user-id', role: role };
    next();
  },
  requireRole: () => (_req, _res, next) => next(),
}));

const deliverablesRouter = require('../src/routes/deliverables');
const { Deliverable, AuditLog } = require('../src/models');

const app = express();
app.use(express.json());
app.use('/api/deliverables', deliverablesRouter);

describe('Deliverable Role Logic', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('PUT /api/deliverables/:id', () => {
    it('should allow Owner to assign owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'owner')
        .send({ owner_id: 'new-owner-id' });

      expect(response.status).toBe(200);
      expect(mockDeliverable.update).toHaveBeenCalledWith(expect.objectContaining({ owner_id: 'new-owner-id' }));
      expect(AuditLog.logChange).toHaveBeenCalled();
    });

    it('should allow Admin (systemAdmin) to assign owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'systemAdmin')
        .send({ owner_id: 'new-owner-id' });

      expect(response.status).toBe(200);
      expect(mockDeliverable.update).toHaveBeenCalled();
    });

    it('should allow Delivery Lead to assign owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'deliveryLead')
        .send({ owner_id: 'new-owner-id' });

      expect(response.status).toBe(200);
      expect(mockDeliverable.update).toHaveBeenCalled();
    });

    it('should forbid regular User from assigning owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'user')
        .send({ owner_id: 'new-owner-id' });

      expect(response.status).toBe(403);
      expect(response.body.error).toContain('Only Owners, Admins, and Delivery Leads can assign deliverable owners');
      expect(mockDeliverable.update).not.toHaveBeenCalled();
    });

    it('should allow regular User to update other fields', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: 'existing-owner',
        toJSON: () => ({ id: 'del-1', owner_id: 'existing-owner' }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'user')
        .send({ title: 'New Title' });

      expect(response.status).toBe(200);
      expect(mockDeliverable.update).toHaveBeenCalledWith(expect.objectContaining({ title: 'New Title' }));
    });

    it('should prevent setting status to Active without owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'owner')
        .send({ status: 'active' });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Cannot set status to Active/In Progress without an assigned owner');
      expect(mockDeliverable.update).not.toHaveBeenCalled();
    });

    it('should prevent setting status to In Progress without owner', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'owner')
        .send({ status: 'in_progress' });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Cannot set status to Active/In Progress without an assigned owner');
      expect(mockDeliverable.update).not.toHaveBeenCalled();
    });

    it('should allow setting status to Active if owner is being assigned simultaneously', async () => {
      const mockDeliverable = {
        id: 'del-1',
        owner_id: null,
        toJSON: () => ({ id: 'del-1', owner_id: null }),
        update: jest.fn(),
      };
      Deliverable.findByPk.mockResolvedValue(mockDeliverable);

      const response = await request(app)
        .put('/api/deliverables/del-1')
        .set('mock-role', 'owner')
        .send({ status: 'active', owner_id: 'new-owner' });

      expect(response.status).toBe(200);
      expect(mockDeliverable.update).toHaveBeenCalled();
    });
  });
});
