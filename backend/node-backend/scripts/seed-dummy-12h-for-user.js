/**
 * Seeds temporary QA data (12h TTL) for local testing: projects, sprints, deliverables, notifications.
 * Cleanup runs automatically when the API server starts (dummyDataCleanupService) every 15 minutes.
 *
 * Usage (from backend/node-backend):
 *   set DUMMY_USER_EMAIL=deliverylead_20260129@example.com
 *   node scripts/seed-dummy-12h-for-user.js
 *
 * Optional: DUMMY_REPLACE=1 — remove non-expired dummy rows for this user first (same email), then re-seed.
 * Env files (first existing → last; later files override): .env.sit, .env.development, .env.local, ../.env, .env
 * Auto-create missing user: @example.com addresses, or DUMMY_ENSURE_USER=1. Password: DUMMY_USER_PASSWORD or DeliveryLead123!
 */

const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');

const backendRoot = path.join(__dirname, '..');
const envCandidates = [
  path.join(backendRoot, '.env.sit'),
  path.join(backendRoot, '.env.development'),
  path.join(backendRoot, '.env.local'),
  path.join(backendRoot, '..', '.env'),
  path.join(backendRoot, '.env'),
];
for (const p of envCandidates) {
  if (fs.existsSync(p)) {
    dotenv.config({ path: p, override: true });
    console.log('[seed-dummy-12h] Loaded env:', p);
  }
}

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { QueryTypes } = require('sequelize');
const { sequelize, User, Project, Sprint, Deliverable, DeliverableSprint, Notification, ProjectMember } = require('../src/models');
const { ensureProjectsSchema } = require('../src/config/ensureProjectsSchema');
const { runExpiredDummy12hCleanup } = require('../src/services/dummyDataCleanupService');

const EMAIL = process.env.DUMMY_USER_EMAIL || 'deliverylead_20260129@example.com';
const HOURS = 12;
const COUNTS = { projects: 12, sprints: 10, deliverables: 6, notifications: 13 };

const PREFIX = '[DUMMY 12h]';

async function ensureNotificationsPayloadColumn() {
  if (sequelize.getDialect() !== 'postgres') return;
  try {
    await sequelize.query(
      'ALTER TABLE notifications ADD COLUMN IF NOT EXISTS payload JSONB',
    );
  } catch (e) {
    console.warn('[seed-dummy-12h] notifications.payload ensure:', e.message);
  }
}

/** Align legacy `sprints` rows with columns this seed uses (idempotent). */
async function ensureSprintColumnsForSeed() {
  if (sequelize.getDialect() !== 'postgres') return;
  const stmts = [
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS committed_points INTEGER DEFAULT 0',
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS completed_points INTEGER DEFAULT 0',
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS planned_points INTEGER DEFAULT 0',
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS progress DOUBLE PRECISION DEFAULT 0',
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS description TEXT',
    'ALTER TABLE sprints ADD COLUMN IF NOT EXISTS created_by VARCHAR(255)',
  ];
  for (const sql of stmts) {
    try {
      await sequelize.query(sql);
    } catch (e) {
      console.warn('[seed-dummy-12h] sprints column ensure:', e.message);
    }
  }
}

async function resolveSeedUser() {
  let user = await User.findOne({ where: { email: EMAIL } });
  if (user) return user;

  const allowCreate =
    process.env.DUMMY_ENSURE_USER === '1' ||
    (process.env.DUMMY_ENSURE_USER !== '0' && /@example\.com$/i.test(EMAIL));

  if (!allowCreate) {
    console.error(`[seed-dummy-12h] No user with email: ${EMAIL}`);
    console.error(
      '  Fix: register that user, set DUMMY_USER_EMAIL to an existing account, or set DUMMY_ENSURE_USER=1 (dev only).',
    );
    process.exit(1);
  }

  const plain = process.env.DUMMY_USER_PASSWORD || 'DeliveryLead123!';
  const hashed = await bcrypt.hash(plain, 12);
  user = await User.create({
    email: EMAIL,
    hashed_password: hashed,
    first_name: 'Delivery',
    last_name: 'Lead',
    role: 'delivery_lead',
    is_active: true,
    is_verified: true,
  });
  console.log(`[seed-dummy-12h] Created user ${EMAIL} (delivery_lead). Sign in with that email and your password (default: DeliveryLead123! if DUMMY_USER_PASSWORD unset).`);
  return user;
}

async function removeActiveDummyForUser(userId) {
  if (String(process.env.DUMMY_REPLACE || '') !== '1') return;
  const dialect = sequelize.getDialect();
  const sub =
    dialect === 'postgres'
      ? `(metadata::jsonb->>'dummy_12h_seed') IN ('true', '1')`
      : `json_extract(metadata, '$.dummy_12h_seed') IS NOT NULL AND json_extract(metadata, '$.dummy_12h_seed') != 0`;

  const rows = await sequelize.query(
    `SELECT id FROM projects WHERE owner_id = :uid AND ${sub}`,
    { replacements: { uid: userId } },
  );
  const listRows = Array.isArray(rows[0]) ? rows[0] : rows;
  const ids = listRows.map((r) => r.id);
  if (ids.length === 0) return;
  const list = ids
    .filter((id) => /^[0-9a-fA-F-]{36}$/.test(String(id)))
    .map((id) => `'${id}'`)
    .join(', ');
  if (!list) return;

  if (dialect === 'postgres') {
    try {
      await sequelize.query(
        `DELETE FROM notifications WHERE recipient_id = :uid AND (payload::jsonb->>'dummy_12h_seed') IN ('true', '1')`,
        { replacements: { uid: userId } },
      );
    } catch (e) {
      if (!String(e.message || '').includes('recipient_id')) throw e;
      await sequelize.query(
        `DELETE FROM notifications WHERE user_id = :uid AND (payload::jsonb->>'dummy_12h_seed') IN ('true', '1')`,
        { replacements: { uid: userId } },
      );
    }
  } else {
    await sequelize.query(`DELETE FROM notifications WHERE recipient_id = ? AND json_extract(payload, '$.dummy_12h_seed') IS NOT NULL`, {
      replacements: [userId],
    });
  }
  await sequelize.query(
    `DELETE FROM deliverable_sprints WHERE deliverable_id IN (SELECT id FROM deliverables WHERE project_id IN (${list}))`,
  );
  await sequelize.query(`DELETE FROM deliverables WHERE project_id IN (${list})`);
  await sequelize.query(`DELETE FROM sprints WHERE project_id IN (${list})`);
  await sequelize.query(`DELETE FROM project_members WHERE project_id IN (${list})`);
  await sequelize.query(`DELETE FROM projects WHERE id IN (${list})`);
  console.log(`[seed-dummy-12h] DUMMY_REPLACE: removed ${ids.length} prior dummy project(s) for user.`);
}

async function main() {
  await sequelize.authenticate();
  if (sequelize.getDialect() === 'postgres') {
    await ensureProjectsSchema(sequelize);
    await ensureNotificationsPayloadColumn();
    await ensureSprintColumnsForSeed();
  }

  await runExpiredDummy12hCleanup(sequelize);

  const user = await resolveSeedUser();

  await removeActiveDummyForUser(user.id);

  const expiresAt = new Date(Date.now() + HOURS * 60 * 60 * 1000);
  const batchId = crypto.randomUUID();
  const metaBase = {
    dummy_12h_seed: true,
    expires_at: expiresAt.toISOString(),
    dummy_batch_id: batchId,
    note: 'Temporary QA data — auto-deleted 12h after seed',
  };

  const payloadBase = {
    dummy_12h_seed: true,
    expires_at: expiresAt.toISOString(),
    dummy_batch_id: batchId,
  };

  const t = await sequelize.transaction();
  try {
    const projects = [];
    for (let i = 0; i < COUNTS.projects; i++) {
      const n = i + 1;
      const key = `DMY12H-${String(n).padStart(2, '0')}`;
      const p = await Project.create(
        {
          name: `${PREFIX} Project ${n}`,
          key,
          description: `${PREFIX} Sample project ${n} for UI testing (expires ${expiresAt.toISOString()})`,
          status: 'active',
          owner_id: user.id,
          created_by: user.id,
          project_type: 'software',
          client_name: 'Demo Client',
          client_owner_name: 'Demo Owner',
          metadata: { ...metaBase, project_index: n },
        },
        { transaction: t },
      );
      projects.push(p);
      await ProjectMember.create(
        {
          project_id: p.id,
          user_id: user.id,
          role: 'owner',
        },
        { transaction: t },
      );
    }

    const sprints = [];
    // Keep values compatible with DB check constraints (avoid e.g. "review" if not allowed).
    const statuses = ['planning', 'active', 'active', 'active', 'completed'];
    const usePgMinimalSprints = sequelize.getDialect() === 'postgres';

    for (let i = 0; i < COUNTS.sprints; i++) {
      const p = projects[i % projects.length];
      const start = new Date();
      start.setDate(start.getDate() - (14 - i));
      const end = new Date(start);
      end.setDate(end.getDate() + 14);
      const st = statuses[i % statuses.length];

      if (usePgMinimalSprints) {
        const rows = await sequelize.query(
          `INSERT INTO sprints (project_id, name, start_date, end_date, committed_points, completed_points, status, created_by, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id`,
          {
            bind: [
              p.id,
              `${PREFIX} Sprint ${i + 1}`,
              start,
              end,
              20 + i * 3,
              5 + i * 2,
              st,
              user.id,
            ],
            transaction: t,
            type: QueryTypes.SELECT,
          },
        );
        sprints.push({ id: rows[0].id });
      } else {
        const sp = await Sprint.create(
          {
            project_id: p.id,
            name: `${PREFIX} Sprint ${i + 1}`,
            description: `${PREFIX} Sprint for ${p.name}`,
            start_date: start,
            end_date: end,
            status: st,
            committed_points: 20 + i * 3,
            completed_points: 5 + i * 2,
            planned_points: 30,
            progress: 0.2 + i * 0.05,
            created_by: user.email,
          },
          { transaction: t },
        );
        sprints.push(sp);
      }
    }

    const deliverables = [];
    const delStatuses = ['draft', 'in_progress', 'in_review', 'submitted', 'approved', 'in_progress'];

    for (let i = 0; i < COUNTS.deliverables; i++) {
      const p = projects[i % projects.length];
      const due = new Date(Date.now() + (i + 1) * 86400000);

      let dId;
      if (usePgMinimalSprints) {
        const rows = await sequelize.query(
          `INSERT INTO deliverables (title, description, status, project_id, owner_id, created_by, assigned_to, due_date, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW()) RETURNING id`,
          {
            bind: [
              `${PREFIX} Deliverable ${i + 1}`,
              `${PREFIX} Test deliverable linked to ${p.name}`,
              delStatuses[i % delStatuses.length],
              p.id,
              user.id,
              user.id,
              user.id,
              due,
            ],
            transaction: t,
            type: QueryTypes.SELECT,
          },
        );
        dId = rows[0].id;
        deliverables.push({ id: dId });
      } else {
        const d = await Deliverable.create(
          {
            title: `${PREFIX} Deliverable ${i + 1}`,
            description: `${PREFIX} Test deliverable linked to ${p.name}`,
            status: delStatuses[i % delStatuses.length],
            priority: ['low', 'medium', 'high'][i % 3],
            project_id: p.id,
            owner_id: user.id,
            created_by: user.email,
            assigned_to: user.email,
            due_date: due,
          },
          { transaction: t },
        );
        deliverables.push(d);
        dId = d.id;
      }

      if (sprints[i]) {
        const sid = sprints[i].id;
        if (usePgMinimalSprints) {
          await sequelize.query(
            `INSERT INTO deliverable_sprints (deliverable_id, sprint_id) VALUES ($1, $2)`,
            { bind: [dId, sid], transaction: t },
          );
        } else {
          await DeliverableSprint.create(
            {
              deliverable_id: dId,
              sprint_id: sid,
              contribution_percentage: 100,
            },
            { transaction: t },
          );
        }
      }
    }

    const notifSpecs = [
      { type: 'sprint', message: `${PREFIX} Sprint "Sprint 1" started` },
      { type: 'sprint', message: `${PREFIX} Sprint review scheduled tomorrow` },
      { type: 'deliverable', message: `${PREFIX} New deliverable assigned to you` },
      { type: 'deliverable', message: `${PREFIX} Deliverable moved to in_review` },
      { type: 'approval', message: `${PREFIX} Approval requested for sign-off` },
      { type: 'system', message: `${PREFIX} System: project workspace synced` },
      { type: 'team', message: `${PREFIX} Team: standup notes posted` },
      { type: 'sprint', message: `${PREFIX} Burndown updated for active sprint` },
      { type: 'deliverable', message: `${PREFIX} Due date approaching for deliverable` },
      { type: 'repository', message: `${PREFIX} Repository: branch protection enabled` },
      { type: 'file', message: `${PREFIX} New file uploaded to project docs` },
      { type: 'system', message: `${PREFIX} Reminder: complete sprint retrospective` },
      { type: 'deliverable', message: `${PREFIX} Deliverable approved — nice work` },
    ];

    for (let i = 0; i < COUNTS.notifications; i++) {
      const spec = notifSpecs[i] || { type: 'system', message: `${PREFIX} Notification ${i + 1}` };
      const payloadObj = { ...payloadBase, index: i + 1, seed_type: spec.type };
      if (usePgMinimalSprints) {
        const title = spec.message.length > 250 ? `${spec.message.slice(0, 247)}...` : spec.message;
        // DB enforces notifications_type_check: review | change_request | report | metrics | reminder | approval
        const dbNotifTypes = ['review', 'metrics', 'reminder', 'approval', 'report', 'change_request'];
        const dbType = dbNotifTypes[i % dbNotifTypes.length];
        await sequelize.query(
          `INSERT INTO notifications (id, user_id, title, message, type, priority, is_read, payload, created_at)
           VALUES (gen_random_uuid(), $1, $2, $3, $6, 'medium', $4, $5::jsonb, NOW())`,
          {
            bind: [
              user.id,
              title,
              spec.message,
              i % 4 === 0,
              JSON.stringify(payloadObj),
              dbType,
            ],
            transaction: t,
          },
        );
      } else {
        await Notification.create(
          {
            recipient_id: user.id,
            sender_id: user.id,
            type: spec.type,
            message: spec.message,
            payload: payloadObj,
            is_read: i % 4 === 0,
            created_at: new Date(),
          },
          { transaction: t },
        );
      }
    }

    await t.commit();
    console.log('[seed-dummy-12h] Done.');
    console.log(`  User: ${EMAIL} (${user.id})`);
    console.log(`  Projects: ${COUNTS.projects}, Sprints: ${COUNTS.sprints}, Deliverables: ${COUNTS.deliverables}, Notifications: ${COUNTS.notifications}`);
    console.log(`  Expires at (UTC): ${expiresAt.toISOString()}`);
    console.log(`  Batch: ${batchId}`);
  } catch (e) {
    await t.rollback();
    console.error('[seed-dummy-12h] Failed:', e);
    process.exit(1);
  }

  await sequelize.close();
}

main();
