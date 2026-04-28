import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import pool from './dbPool.js';

const DEFAULT_PASSWORD = 'Temp123!';

const ROLE_USERS = [
  { role: 'systemAdmin', firstName: 'System', lastName: 'Admin' },
  { role: 'admin', firstName: 'Platform', lastName: 'Admin' },
  { role: 'projectManager', firstName: 'Project', lastName: 'Manager' },
  { role: 'deliveryLead', firstName: 'Delivery', lastName: 'Lead' },
  { role: 'teamMember', firstName: 'Team', lastName: 'Member' },
  { role: 'client', firstName: 'Client', lastName: 'User' },
  { role: 'clientReviewer', firstName: 'Client', lastName: 'Reviewer' },
  { role: 'developer', firstName: 'App', lastName: 'Developer' },
  { role: 'scrumMaster', firstName: 'Scrum', lastName: 'Master' },
  { role: 'qaEngineer', firstName: 'QA', lastName: 'Engineer' },
  { role: 'stakeholder', firstName: 'Business', lastName: 'Stakeholder' },
];

function slugifyRole(role) {
  return role.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase();
}

async function ensurePasswordHashColumn() {
  await pool.query(`
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)
  `);
}

async function upsertRoleUser({ role, firstName, lastName }, passwordHash) {
  const email = `${slugifyRole(role)}.demo@flowspace.local`;
  const fullName = `${firstName} ${lastName}`.trim();

  const existing = await pool.query(
    'SELECT id FROM users WHERE email = $1 LIMIT 1',
    [email]
  );

  if (existing.rows[0]) {
    const userId = existing.rows[0].id;
    try {
      await pool.query(
        `UPDATE users
         SET first_name = $1,
             last_name = $2,
             role = $3,
             is_active = true,
             email_verified = true,
             password_hash = $4,
             updated_at = NOW()
         WHERE id = $5`,
        [firstName, lastName, role, passwordHash, userId]
      );
    } catch (err) {
      await pool.query(
        `UPDATE users
         SET name = $1,
             role = $2,
             is_active = true,
             email_verified = true,
             password_hash = $3,
             updated_at = NOW()
         WHERE id = $4`,
        [fullName, role, passwordHash, userId]
      );
    }
    return { email, role, created: false };
  }

  const userId = uuidv4();
  try {
    await pool.query(
      `INSERT INTO users
        (id, email, password_hash, first_name, last_name, role, is_active, email_verified, created_at, updated_at)
       VALUES
        ($1, $2, $3, $4, $5, $6, true, true, NOW(), NOW())`,
      [userId, email, passwordHash, firstName, lastName, role]
    );
  } catch (err) {
    await pool.query(
      `INSERT INTO users
        (id, email, password_hash, name, role, is_active, email_verified, created_at, updated_at)
       VALUES
        ($1, $2, $3, $4, $5, true, true, NOW(), NOW())`,
      [userId, email, passwordHash, fullName, role]
    );
  }

  return { email, role, created: true };
}

async function main() {
  const results = [];
  try {
    await ensurePasswordHashColumn();
    const passwordHash = await bcrypt.hash(DEFAULT_PASSWORD, 10);

    for (const roleUser of ROLE_USERS) {
      const result = await upsertRoleUser(roleUser, passwordHash);
      results.push(result);
    }

    console.log('\n✅ Role users are ready.\n');
    console.log(`Shared password for all users: ${DEFAULT_PASSWORD}\n`);
    console.log('Credentials:');
    for (const item of results) {
      console.log(
        `- ${item.role.padEnd(14, ' ')} | ${item.email} | ${item.created ? 'created' : 'updated'}`
      );
    }
  } catch (error) {
    console.error('❌ Failed to seed role users:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
