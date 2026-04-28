/**
 * One-off script to set hashed_password for an existing user (e.g. after DB sync added nullable column).
 * Run from backend/node-backend: node scripts/set-user-password.js <email> <newPassword>
 * Example: node scripts/set-user-password.js deliverylead_20260129@example.com "Test#871329!"
 */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });

const { sequelize } = require('../src/models');
const { User } = require('../src/models');
const { getPasswordHash } = require('../src/utils/authUtils');

async function setUserPassword() {
  const email = process.argv[2];
  const newPassword = process.argv[3];

  if (!email || !newPassword) {
    console.log('Usage: node scripts/set-user-password.js <email> <newPassword>');
    console.log('Example: node scripts/set-user-password.js user@example.com "MyNewPass123!"');
    process.exit(1);
  }

  try {
    await sequelize.authenticate();
    console.log('✅ Database connected');

    const user = await User.findOne({ where: { email } });
    if (!user) {
      console.log('❌ User not found with email:', email);
      process.exit(1);
    }

    const hashedPassword = await getPasswordHash(newPassword);
    await user.update({ hashed_password: hashedPassword });
    console.log('✅ Password set for:', email);
    console.log('   You can now log in with this email and the password you provided.');
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

setUserPassword();
