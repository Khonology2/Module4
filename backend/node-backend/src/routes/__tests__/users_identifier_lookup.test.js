const request = require('supertest');
const express = require('express');
const bodyParser = require('body-parser');

const mockUser = {
  findByPk: jest.fn(),
  findOne: jest.fn(),
};

const mockUserProfile = {
  destroy: jest.fn(),
};

jest.mock('../../models', () => ({
  User: mockUser,
  UserProfile: mockUserProfile,
}));

jest.mock('../../middleware/auth', () => ({
  authenticateToken: (req, _res, next) => {
    req.user = { id: 'admin-1', role: 'admin' };
    next();
  },
  requireRole: () => (_req, _res, next) => next(),
}));

const usersRouter = require('../users');

function makeApp() {
  const app = express();
  app.use(bodyParser.json());
  app.use('/api/users', usersRouter);
  return app;
}

describe('users identifier lookup', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('fetches a user by email without attempting a UUID primary-key lookup', async () => {
    const app = makeApp();
    mockUser.findOne.mockResolvedValue({
      id: 'c3648705-53c5-4113-9441-ba503f62b032',
      email: 'nkabindethabang77@gmail.com',
      first_name: 'Thabang',
      last_name: 'Nkabinde',
      role: 'deliveryLead',
      is_active: true,
      last_login: null,
      created_at: '2026-05-01T00:00:00.000Z',
      updated_at: '2026-05-01T00:00:00.000Z',
    });

    const res = await request(app).get('/api/users/nkabindethabang77@gmail.com');

    expect(res.status).toBe(200);
    expect(mockUser.findByPk).not.toHaveBeenCalled();
    expect(mockUser.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        attributes: expect.arrayContaining(['id', 'email', 'role']),
        where: { email: 'nkabindethabang77@gmail.com' },
      }),
    );
    expect(res.body.user.email).toBe('nkabindethabang77@gmail.com');
  });

  it('updates a user role when the route parameter is an email identifier', async () => {
    const app = makeApp();
    const update = jest.fn().mockResolvedValue(undefined);

    mockUser.findOne.mockResolvedValue({
      id: 'c3648705-53c5-4113-9441-ba503f62b032',
      email: 'nkabindethabang77@gmail.com',
      first_name: 'Thabang',
      last_name: 'Nkabinde',
      role: 'developer',
      is_active: true,
      last_login: null,
      created_at: '2026-05-01T00:00:00.000Z',
      update,
    });

    const res = await request(app)
      .put('/api/users/nkabindethabang77@gmail.com/role')
      .send({ role: 'deliveryLead' });

    expect(res.status).toBe(200);
    expect(mockUser.findByPk).not.toHaveBeenCalled();
    expect(mockUser.findOne).toHaveBeenCalledWith({
      where: { email: 'nkabindethabang77@gmail.com' },
    });
    expect(update).toHaveBeenCalledWith(
      { role: 'deliveryLead' },
      { updatedBy: 'admin-1' },
    );
    expect(res.body.user.role).toBe('developer');
  });

  it('still fetches a user by primary key when the identifier is a UUID', async () => {
    const app = makeApp();
    const id = 'c3648705-53c5-4113-9441-ba503f62b032';

    mockUser.findByPk.mockResolvedValue({
      id,
      email: 'uuid-user@example.com',
      first_name: 'Uuid',
      last_name: 'User',
      role: 'admin',
      is_active: true,
      last_login: null,
      created_at: '2026-05-01T00:00:00.000Z',
      updated_at: '2026-05-01T00:00:00.000Z',
    });

    const res = await request(app).get(`/api/users/${id}`);

    expect(res.status).toBe(200);
    expect(mockUser.findByPk).toHaveBeenCalledWith(
      id,
      expect.objectContaining({
        attributes: expect.arrayContaining(['id', 'email', 'role']),
      }),
    );
    expect(mockUser.findOne).not.toHaveBeenCalled();
  });
});
