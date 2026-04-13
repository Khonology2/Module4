/**
 * Delete multiple users by email with related row cleanup.
 * Run from backend/node-backend:
 *   node scripts/delete-users-batch.js
 */
const path = require('path');
const { Op } = require('sequelize');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });

const {
  sequelize,
  User,
  UserProfile,
  RefreshToken,
  UserSettings,
  AuditLog,
  ProjectMember,
  ApprovalRequest,
  Project,
  Deliverable,
} = require('../src/models');

// Pass emails as CLI args, e.g. node scripts/delete-users-batch.js user@x.com
const DEFAULT_EMAILS = [];

async function deleteUserCascade(user) {
  const id = user.id;
  const email = user.email;

  const n1 = await RefreshToken.destroy({ where: { user_id: id } });
  const n2 = await UserProfile.destroy({ where: { user_id: id } });
  const n3 = await UserSettings.destroy({ where: { user_id: id } });

  // DB may use user_id (not recipient_id/sender_id) — raw SQL covers variants
  let n4 = 0;
  for (const sql of [
    'DELETE FROM notifications WHERE user_id = :id',
    'DELETE FROM notifications WHERE recipient_id = :id OR sender_id = :id',
    "DELETE FROM notifications WHERE created_by::text = :idText",
  ]) {
    try {
      const [_, meta] = await sequelize.query(sql, {
        replacements: { id, idText: String(id) },
      });
      n4 += Number(meta) || 0;
    } catch (_) {
      /* column may not exist */
    }
  }

  const n5 = await AuditLog.destroy({ where: { user_id: id } });
  const n6 = await ProjectMember.destroy({ where: { user_id: id } });
  const n7 = await ApprovalRequest.destroy({
    where: { [Op.or]: [{ requested_by: id }, { approved_by: id }] },
  });

  // created_by is often NOT NULL — reassign to any other user, then clear owner_id
  const otherUser = await User.findOne({ where: { id: { [Op.ne]: id } } });
  let projUp = 0;
  if (otherUser) {
    const [a] = await Project.update(
      { created_by: otherUser.id },
      { where: { created_by: id } },
    );
    const [b] = await Project.update({ owner_id: null }, { where: { owner_id: id } });
    projUp = (a || 0) + (b || 0);
  } else {
    console.warn('  ⚠️ No other user to reassign projects; delete may fail if FKs require it');
  }
  const [delUp] = await Deliverable.update(
    { owner_id: null },
    { where: { owner_id: id } },
  );

  try {
    await sequelize.query('DELETE FROM user_signatures WHERE user_id = :id', {
      replacements: { id },
    });
  } catch (e) {
    if (!String(e.message).includes('does not exist')) {
      console.warn('  (user_signatures):', e.message);
    }
  }

  await user.destroy();

  console.log(`✅ Deleted ${email}`);
  console.log(
    `   tokens:${n1} profiles:${n2} settings:${n3} notifications:${n4} audit:${n5} project_members:${n6} approval_req:${n7} projects nulled:${projUp} deliverables owner nulled:${delUp}`,
  );
}

async function main() {
  const emailsFromCli = process.argv.slice(2).filter(Boolean);
  const EMAILS = emailsFromCli.length ? emailsFromCli : DEFAULT_EMAILS;

  if (!EMAILS.length) {
    console.log(
      'Usage: node scripts/delete-users-batch.js <email> [more@emails ...]',
    );
    process.exit(0);
  }

  await sequelize.authenticate();
  console.log('✅ Database connected\n');

  for (const email of EMAILS) {
    const user = await User.findOne({ where: { email } });
    if (!user) {
      console.log(`⏭️  Skip (not found): ${email}`);
      continue;
    }
    try {
      await deleteUserCascade(user);
    } catch (err) {
      console.error(`❌ Failed ${email}:`, err.message);
      if (err.parent) console.error(err.parent.message);
    }
  }

  const remaining = await User.count();
  console.log(`\n📊 Users remaining in DB: ${remaining}`);
  await sequelize.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
