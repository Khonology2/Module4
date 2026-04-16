const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

const mockSequelize = {
  query: jest.fn(),
  getDialect: jest.fn(() => 'postgres'),
};

jest.mock('../../models', () => ({
  Signoff: { create: jest.fn() },
  AuditLog: {},
  Deliverable: {},
  Sprint: {},
  User: { findAll: jest.fn() },
  sequelize: mockSequelize,
}));

const signoffRouter = require('../signoff');

function makeApp() {
  const app = express();
  app.use(bodyParser.json());
  app.use((req, res, next) => {
    req.user = { id: 'user-1', email: 'user@example.com', role: 'developer' };
    next();
  });
  app.use('/api/sign-off-reports', signoffRouter);
  return app;
}

describe('POST /api/sign-off-reports', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSequelize.query.mockReset();
  });

  it('returns 400 when deliverableId is missing', async () => {
    const app = makeApp();

    mockSequelize.query.mockImplementation(async (sql) => {
      if (String(sql).toUpperCase().includes('CREATE TABLE')) return [[], null];
      return [[], null];
    });

    const res = await request(app)
      .post('/api/sign-off-reports')
      .send({ reportTitle: 'Title', reportContent: 'Content' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('deliverableId is required');
  });

  it('creates a report and returns 201 with normalized status', async () => {
    const app = makeApp();

    mockSequelize.query.mockImplementation(async (sql) => {
      const s = String(sql).toUpperCase();
      if (s.includes('CREATE TABLE')) return [[], null];
      if (s.includes('INSERT INTO SIGN_OFF_REPORTS')) {
        return [
          [
            [
              {
                id: 'report-1',
                deliverable_id: 'deliverable-1',
                created_by: 'user-1',
                status: 'submitted',
                content: {
                  reportTitle: 'Title',
                  reportContent: 'Content',
                  sprintIds: [],
                  status: 'submitted',
                },
                created_at: '2026-01-01T00:00:00.000Z',
                updated_at: '2026-01-01T00:00:00.000Z',
              },
            ],
            null,
          ],
        ][0];
      }
      return [[], null];
    });

    const res = await request(app)
      .post('/api/sign-off-reports')
      .send({
        deliverableId: ' deliverable-1 ',
        reportTitle: ' Title ',
        reportContent: ' Content ',
        status: 'submitted',
      });

    expect(res.status).toBe(201);
    expect(res.body).toEqual(
      expect.objectContaining({
        id: 'report-1',
        deliverableId: 'deliverable-1',
        reportTitle: 'Title',
        reportContent: 'Content',
        status: 'submitted',
        createdBy: 'user-1',
      }),
    );

    const insertCall = mockSequelize.query.mock.calls.find((c) =>
      String(c[0]).toUpperCase().includes('INSERT INTO SIGN_OFF_REPORTS'),
    );
    expect(insertCall).toBeTruthy();
    const insertSql = insertCall[0];
    expect(insertSql).toContain('VALUES ($1, $2, $3, $4::jsonb)');

    const insertOpts = insertCall[1];
    expect(insertOpts).toEqual(
      expect.objectContaining({
        bind: expect.arrayContaining(['deliverable-1', 'user-1', 'submitted']),
      }),
    );
  });
});
