/**
 * Set a user's role to System Admin (DB value depends on USERS_ROLE_FORMAT — same as auth/register).
 *
 * Default (legacy CHECK): role = 'admin'  → Flutter treats as System Admin.
 * If USERS_ROLE_FORMAT=snake: role = 'system_admin'
 *
 * Run from backend/node-backend:
 *   node scripts/promote-user-to-admin.js <email>
 */
const path = require('path');
const { Op } = require('sequelize');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });

const { sequelize, User } = require('../src/models');

async function main() {
  const email = (process.argv[2] || '').trim();
  if (!email) {
    console.log('Usage: node scripts/promote-user-to-admin.js <email>');
    process.exit(1);
  }

  const format = String(process.env.USERS_ROLE_FORMAT || 'legacy').toLowerCase();
  const roleForDatabase = format === 'snake' ? 'system_admin' : 'admin';

  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    // Case-insensitive match (Postgres ILIKE) — registration may store different casing
    let user = await User.findOne({
      where: { email: { [Op.iLike]: email } }
    });
    if (!user) {
      console.log('❌ No user found with email (case-insensitive):', email);
      const recent = await User.findAll({
        attributes: ['email', 'role'],
        order: [['created_at', 'DESC']],
        limit: 20
      });
      if (recent.length) {
        console.log('\nMost recent emails in this database (copy the exact one):');
        recent.forEach((u) => console.log('  -', u.email, '(' + u.role + ')'));
      } else {
        console.log('(No rows in users — register in the app first, then run this again.)');
      }
      process.exit(1);
    }

    await user.update({ role: roleForDatabase });
    console.log('✅ Updated role to', roleForDatabase, 'for', user.email);
    console.log('   Log out of the app (or clear site data) and sign in again to refresh your token.');
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.parent) console.error(error.parent.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

main();
