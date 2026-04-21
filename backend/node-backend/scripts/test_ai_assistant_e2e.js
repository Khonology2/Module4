const axios = require('axios');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const { User } = require('../src/models');

const API_BASE = process.env.API_BASE_URL || 'http://localhost:8000/api/v1';

async function getAnyUser() {
  const u = await User.findOne({
    order: [['created_at', 'DESC']],
  });
  if (!u) {
    throw new Error('No users found in database.');
  }
  return u;
}

function makeToken(user) {
  const secret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production';
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role, type: 'access' },
    secret,
    { expiresIn: '1h' },
  );
}

async function main() {
  const user = await getAnyUser();
  const token = makeToken(user);
  const headers = { Authorization: `Bearer ${token}` };

  const status = await axios.get(`${API_BASE}/ai/status`, { headers });
  console.log('ai.status:', status.data);

  const snapshot = await axios.get(`${API_BASE}/ai/snapshot`, { headers });
  console.log('ai.snapshot.meta:', snapshot.data && snapshot.data.meta ? snapshot.data.meta : snapshot.data);

  const prompts = [
    'how many sprints are on the system?',
    'list the sprint names',
    'how many projects are on the system?',
    'list the project names',
    'list the users on the system',
    'list the deliverables',
    'Show project details for project DELANDSIGH',
  ];

  for (const p of prompts) {
    const r = await axios.post(`${API_BASE}/ai/chat`, {
      messages: [{ role: 'user', content: p }],
      temperature: 0.2,
      max_tokens: 400,
    }, { headers });
    const data = r.data || {};
    const payload = data.data || data;
    console.log('\nPROMPT:', p);
    console.log('RESPONSE:', payload.content);
    console.log('MODEL:', payload.model);
  }
}

main().catch((e) => {
  const msg = (e && e.response && e.response.data) ? JSON.stringify(e.response.data) : (e && e.message ? e.message : String(e));
  console.error('E2E test failed:', msg);
  process.exitCode = 1;
});
