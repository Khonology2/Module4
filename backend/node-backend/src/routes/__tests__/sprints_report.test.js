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

jest.mock('../../services/sprintCarryOverService', () => ({
  carryOverOverdueDeliverablesForProject: jest.fn(async () => {}),
}));

jest.mock('../../models', () => ({
  Sprint: {
    findByPk: jest.fn(),
  },
  Project: {},
  Deliverable: {},
  User: {},
}));

const sprintsRouter = require('../sprints');
const { Sprint } = require('../../models');

function makeApp() {
  const app = express();
  app.use(bodyParser.json());
  app.use('/api/sprints', sprintsRouter);
  return app;
}

describe('GET /api/sprints/:id/report', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('requests deliverables with owner include that does not reference a non-existent User.name column', async () => {
    Sprint.findByPk
      .mockResolvedValueOnce({ id: 3, project_id: 'proj-1', status: 'planning' })
      .mockResolvedValueOnce({
        id: 3,
        name: 'Sprint 3',
        status: 'planning',
        project_id: 'proj-1',
        start_date: null,
        end_date: null,
        project: { id: 'proj-1', name: 'Project', key: 'PRJ' },
        deliverables: [
          {
            id: 10,
            title: 'D1',
            description: '',
            status: 'draft',
            due_date: null,
            created_at: null,
            updated_at: null,
            submitted_at: null,
            approved_at: null,
            owner: { id: 'u1', email: 'u1@example.com', first_name: 'A', last_name: 'B', role: 'user' },
          },
        ],
      });

    const app = makeApp();
    const res = await request(app).get('/api/sprints/3/report');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);

    const secondCallArgs = Sprint.findByPk.mock.calls[1][1];
    const deliverablesInclude = secondCallArgs.include.find((i) => i && i.as === 'deliverables');
    expect(deliverablesInclude).toBeTruthy();
    const ownerInclude = deliverablesInclude.include.find((i) => i && i.as === 'owner');
    expect(ownerInclude).toBeTruthy();
    expect(ownerInclude.attributes).toEqual(['id', 'email', 'first_name', 'last_name', 'role']);
  });
});

