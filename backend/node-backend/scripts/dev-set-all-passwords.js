/**
 * LOCAL DEVELOPMENT ONLY: set the same bcrypt-hashed password for every user row.
 * Real passwords cannot be read back from the DB (only hashes exist).
 *
 * Usage (from backend/node-backend):
 *   node scripts/dev-set-all-passwords.js "YourNewPassword123!"
 */
const path = require('path');
const fs = require('fs');

const envCandidates = [
  path.resolve(__dirname, '..', '.env'),
  path.resolve(__dirname, '..', '..', '.env'),
  path.resolve(__dirname, '..', '..', '..', '.env'),
];
for (const p of envCandidates) {
  if (fs.existsSync(p)) {
    require('dotenv').config({ path: p });
    break;
  }
}

if (process.env.NODE_ENV === 'production') {
  console.error('Refusing to run: NODE_ENV is production.');
  process.exit(1);
}

const { sequelize } = require('../src/models');
const { User } = require('../src/models');
const { getPasswordHash } = require('../src/utils/authUtils');

async function main() {
  const newPassword = process.argv[2];
  if (!newPassword) {
    console.log('Usage: node scripts/dev-set-all-passwords.js "<password>"');
    console.log('Sets that password for every user (local dev only).');
    process.exit(1);
  }

  try {
    await sequelize.authenticate();
    console.log('✅ Database connected\n');

    const users = await User.findAll({
      attributes: ['id', 'email', 'first_name', 'last_name', 'role'],
      order: [['email', 'ASC']],
    });

    if (users.length === 0) {
      console.log('No users found.');
      return;
    }

    const hash = await getPasswordHash(newPassword);
    for (const user of users) {
      await user.update({ hashed_password: hash });
    }

    console.log('All accounts now use this password (copy for logins):\n');
    console.log(newPassword);
    console.log('\n' + '='.repeat(80));
    console.log('Email'.padEnd(42) + 'Role');
    console.log('-'.repeat(80));
    users.forEach((u) => {
      console.log(`${u.email.padEnd(42)}${u.role}`);
    });
    console.log('='.repeat(80));
  } catch (err) {
    console.error('❌', err.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

main();
