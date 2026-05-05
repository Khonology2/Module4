const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

jest.mock('../../middleware/auth', () => ({
  authenticateToken: (req, _res, next) => {
    req.user = { id: '1', role: 'deliveryLead', email: 'dl@example.com' };
    next();
  },
  requireRole: () => (_req, _res, next) => next(),
}));

jest.mock('../../models', () => ({
  Sprint: {
    findByPk: jest.fn(),
  },
  Project: {},
}));

const sprintsRouter = require('../sprints');
const { Sprint } = require('../../models');

function makeApp() {
  const app = express();
  app.use(bodyParser.json());
  app.use('/api/sprints', sprintsRouter);
  return app;
}

describe('PUT /api/sprints/:id/status', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('updates sprint status and returns 200', async () => {
    const mockSprint = { id: 3, status: 'draft', update: jest.fn() };
    Sprint.findByPk.mockResolvedValue(mockSprint);
    mockSprint.update.mockImplementation(async (patch) => {
      mockSprint.status = patch.status;
    });

    const app = makeApp();
    const res = await request(app)
      .put('/api/sprints/3/status')
      .send({ status: 'in_progress' });

    expect(res.status).toBe(200);
    expect(Sprint.findByPk).toHaveBeenCalledWith('3');
    expect(mockSprint.update).toHaveBeenCalledWith({ status: 'in_progress' });
    expect(res.body.success).toBe(true);
  });

  it('returns 400 when status is missing', async () => {
    const app = makeApp();
    const res = await request(app).put('/api/sprints/3/status').send({});
    expect(res.status).toBe(400);
  });

  it('returns 404 when sprint not found', async () => {
    Sprint.findByPk.mockResolvedValue(null);
    const app = makeApp();
    const res = await request(app)
      .put('/api/sprints/3/status')
      .send({ status: 'completed' });
    expect(res.status).toBe(404);
  });
});
