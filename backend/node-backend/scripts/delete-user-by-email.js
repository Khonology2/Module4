/**
 * Delete a user by email (and related rows the API would clean up).
 * Does not require an admin JWT — use only on your local/dev database.
 *
 * Run from backend/node-backend:
 *   node scripts/delete-user-by-email.js <email>
 *
 * Example:
 *   node scripts/delete-user-by-email.js mahangeteddy@gmail.om
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });

const { sequelize, User, UserProfile, RefreshToken } = require('../src/models');

async function main() {
  const email = (process.argv[2] || '').trim();
  if (!email) {
    console.log('Usage: node scripts/delete-user-by-email.js <email>');
    process.exit(1);
  }

  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    const user = await User.findOne({ where: { email } });
    if (!user) {
      console.log('❌ No user found with email:', email);
      process.exit(1);
    }

    const id = user.id;
    console.log('Found user:', email, 'id:', id, 'role:', user.role);

    const rt = await RefreshToken.destroy({ where: { user_id: id } });
    console.log('Removed refresh tokens:', rt);

    const prof = await UserProfile.destroy({ where: { user_id: id } });
    console.log('Removed user_profiles rows:', prof);

    await user.destroy();
    console.log('✅ User deleted:', email);
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.parent) console.error(error.parent.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

main();
