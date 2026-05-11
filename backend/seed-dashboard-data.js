import 'dotenv/config';
import bcrypt from 'bcryptjs';
import pool from './dbPool.js';

async function ensureUser(email, name, role, password) {
  const found = await pool.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [email]);
  if (found.rows[0]) return found.rows[0].id;
  const hash = await bcrypt.hash(password, 10);
  const res = await pool.query(
    `INSERT INTO users (email, password_hash, name, role, is_active, email_verified)
     VALUES ($1, $2, $3, $4, true, true)
     RETURNING id`,
    [email, hash, name, role]
  );
  return res.rows[0].id;
}

async function ensureOne(selectSql, selectParams, insertSql, insertParams) {
  const found = await pool.query(selectSql, selectParams);
  if (found.rows[0]) return found.rows[0].id;
  const res = await pool.query(insertSql, insertParams);
  return res.rows[0].id;
}

async function main() {
  try {
    await pool.query('BEGIN');

    const adminId = await ensureUser('admin.demo@flowspace.local', 'System Admin Demo', 'systemAdmin', 'Admin123!');
    const leadId = await ensureUser('lead.demo@flowspace.local', 'Delivery Lead Demo', 'deliveryLead', 'Lead123!');
    const reviewerId = await ensureUser('reviewer.demo@flowspace.local', 'Client Reviewer Demo', 'clientReviewer', 'Reviewer123!');
    const memberId = await ensureUser('member.demo@flowspace.local', 'Team Member Demo', 'teamMember', 'Member123!');

    const projectId = await ensureOne(
      'SELECT id FROM projects WHERE name = $1 LIMIT 1',
      ['Module4 Dashboard Demo Project'],
      `INSERT INTO projects (name, description, owner_id, status)
       VALUES ($1, $2, $3, 'active') RETURNING id`,
      ['Module4 Dashboard Demo Project', 'Sample project for dashboard views', leadId]
    );

    await pool.query(
      `INSERT INTO project_members (project_id, user_id, role) VALUES
      ($1,$2,'systemAdmin'),($1,$3,'deliveryLead'),($1,$4,'clientReviewer'),($1,$5,'teamMember')
      ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
      [projectId, adminId, leadId, reviewerId, memberId]
    );

    const sprintAlphaId = await ensureOne(
      'SELECT id FROM sprints WHERE name = $1 AND project_id = $2 LIMIT 1',
      ['Sprint Alpha', projectId],
      `INSERT INTO sprints (name, project_id, status, start_date, end_date)
       VALUES ('Sprint Alpha', $1, 'completed', CURRENT_TIMESTAMP - INTERVAL '21 days', CURRENT_TIMESTAMP - INTERVAL '14 days')
       RETURNING id`,
      [projectId]
    );
    const sprintBetaId = await ensureOne(
      'SELECT id FROM sprints WHERE name = $1 AND project_id = $2 LIMIT 1',
      ['Sprint Beta', projectId],
      `INSERT INTO sprints (name, project_id, status, start_date, end_date)
       VALUES ('Sprint Beta', $1, 'in_progress', CURRENT_TIMESTAMP - INTERVAL '7 days', CURRENT_TIMESTAMP + INTERVAL '7 days')
       RETURNING id`,
      [projectId]
    );

    const d1 = await ensureOne(
      'SELECT id FROM deliverables WHERE title = $1 AND project_id = $2 LIMIT 1',
      ['Authentication Module Hardening', projectId],
      `INSERT INTO deliverables
      (title, description, status, project_id, created_by, assigned_to, sprint_id, due_date, priority, progress, definition_of_done, evidence, readiness_gates)
      VALUES
      ('Authentication Module Hardening','Improve auth reliability','submitted',$1,$2,$3,$4,CURRENT_TIMESTAMP - INTERVAL '2 days','High',100,$5::jsonb,$6::jsonb,$7::jsonb)
      RETURNING id`,
      [projectId, leadId, memberId, sprintAlphaId, JSON.stringify(['Code complete','Tests passed']), JSON.stringify(['auth-report.pdf']), JSON.stringify(['Quality Gate'])]
    );
    const d2 = await ensureOne(
      'SELECT id FROM deliverables WHERE title = $1 AND project_id = $2 LIMIT 1',
      ['Dashboard KPI Cards', projectId],
      `INSERT INTO deliverables
      (title, description, status, project_id, created_by, assigned_to, sprint_id, due_date, priority, progress, definition_of_done, evidence, readiness_gates)
      VALUES
      ('Dashboard KPI Cards','Realtime KPI cards for dashboard','approved',$1,$2,$3,$4,CURRENT_TIMESTAMP + INTERVAL '2 days','High',100,$5::jsonb,$6::jsonb,$7::jsonb)
      RETURNING id`,
      [projectId, leadId, memberId, sprintBetaId, JSON.stringify(['UX validated','A11y checked']), JSON.stringify(['kpi-screenshots.png']), JSON.stringify(['Quality Gate','Security Gate'])]
    );

    await pool.query(
      `INSERT INTO sign_off_reports (deliverable_id, created_by, status, report_title, content, evidence, submitted_at, approved_at)
       SELECT $1,$2,'approved','Auth Module Sign-off',$3::jsonb,$4::jsonb,CURRENT_TIMESTAMP - INTERVAL '4 days',CURRENT_TIMESTAMP - INTERVAL '3 days'
       WHERE NOT EXISTS (SELECT 1 FROM sign_off_reports WHERE deliverable_id=$1)`,
      [d1, leadId, JSON.stringify({ summary: 'All checks passed' }), JSON.stringify(['auth-test-results.pdf'])]
    );
    await pool.query(
      `INSERT INTO sign_off_reports (deliverable_id, created_by, status, report_title, content, evidence, submitted_at)
       SELECT $1,$2,'submitted','Dashboard KPI Sign-off',$3::jsonb,$4::jsonb,CURRENT_TIMESTAMP - INTERVAL '1 day'
       WHERE NOT EXISTS (SELECT 1 FROM sign_off_reports WHERE deliverable_id=$1)`,
      [d2, leadId, JSON.stringify({ summary: 'Awaiting review' }), JSON.stringify(['kpi-video.mp4'])]
    );

    const reports = await pool.query('SELECT id, deliverable_id FROM sign_off_reports WHERE deliverable_id = ANY($1::uuid[])', [[d1, d2]]);
    const reportA = reports.rows.find((r) => r.deliverable_id === d1)?.id;
    const reportB = reports.rows.find((r) => r.deliverable_id === d2)?.id;

    if (reportA) {
      await pool.query(
        `INSERT INTO client_reviews (report_id, reviewer_id, status, feedback, approved_at)
         SELECT $1,$2,'approved','Looks good for release',CURRENT_TIMESTAMP - INTERVAL '2 days'
         WHERE NOT EXISTS (SELECT 1 FROM client_reviews WHERE report_id=$1 AND reviewer_id=$2)`,
        [reportA, reviewerId]
      );
    }
    if (reportB) {
      await pool.query(
        `INSERT INTO client_reviews (report_id, reviewer_id, status, feedback)
         SELECT $1,$2,'pending','Review in progress'
         WHERE NOT EXISTS (SELECT 1 FROM client_reviews WHERE report_id=$1 AND reviewer_id=$2)`,
        [reportB, reviewerId]
      );
    }

    await pool.query(
      `INSERT INTO approval_requests (title, description, requested_by, reviewed_by, reviewed_at, review_reason, status, priority, category, deliverable_id, evidence_links, definition_of_done, deliverable_title, deliverable_description)
       SELECT 'Production Approval - Auth Hardening','Request release approval for auth hardening',$1,$2,CURRENT_TIMESTAMP - INTERVAL '2 days','All criteria met','approved','high','release',$3,ARRAY['auth-report.pdf'],ARRAY['Tests passed','Security scan clean'],'Authentication Module Hardening','Improve auth reliability'
       WHERE NOT EXISTS (SELECT 1 FROM approval_requests WHERE title='Production Approval - Auth Hardening' AND deliverable_id=$3)`,
      [leadId, reviewerId, d1]
    );
    await pool.query(
      `INSERT INTO approval_requests (title, description, requested_by, status, priority, category, deliverable_id, evidence_links, definition_of_done, deliverable_title, deliverable_description)
       SELECT 'Client Review - KPI Cards','Request client sign-off for KPI cards',$1,'pending','medium','ui',$2,ARRAY['kpi-cards.mp4'],ARRAY['UX validated','Accessibility checked'],'Dashboard KPI Cards','Realtime KPI cards for dashboard'
       WHERE NOT EXISTS (SELECT 1 FROM approval_requests WHERE title='Client Review - KPI Cards' AND deliverable_id=$2)`,
      [leadId, d2]
    );

    await pool.query(
      `INSERT INTO notifications (user_id, title, message, type, action_url)
       SELECT $1,'Welcome to demo data','Sample records loaded for dashboard testing.','success','/dashboard'
       WHERE NOT EXISTS (SELECT 1 FROM notifications WHERE user_id=$1 AND title='Welcome to demo data')`,
      [leadId]
    );

    await pool.query(
      `INSERT INTO sprint_metrics (sprint_id, committed_points, completed_points, carried_over_points, test_pass_rate, defects_opened, defects_closed, critical_defects, high_defects, medium_defects, low_defects, code_review_completion, documentation_status, risks, mitigations, scope_changes, uat_notes, recorded_by)
       SELECT $1,34,31,3,96.5,9,8,0,1,3,5,92.0,89.0,'External API latency spikes','Added retries + circuit breaker','One widget deferred','UAT passed with minor UX notes','Delivery Lead Demo'
       WHERE NOT EXISTS (SELECT 1 FROM sprint_metrics WHERE sprint_id=$1)`,
      [sprintBetaId]
    );

    await pool.query(
      `INSERT INTO user_signatures (user_id, user_name, signature_data, signature_type, is_default, is_active, last_used_at)
       SELECT $1,'Client Reviewer Demo','data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9h','typed',true,true,CURRENT_TIMESTAMP - INTERVAL '1 day'
       WHERE NOT EXISTS (SELECT 1 FROM user_signatures WHERE user_id=$1 AND is_default=true)`,
      [reviewerId]
    );

    await pool.query(
      `INSERT INTO activity_logs (user_id, entity_type, entity_id, action, description, old_values, new_values, ip_address, user_agent)
       SELECT $1,'deliverable',$2,'status_updated','Deliverable moved to approved status',$3::jsonb,$4::jsonb,'127.0.0.1','Seed Script'
       WHERE NOT EXISTS (SELECT 1 FROM activity_logs WHERE user_id=$1 AND action='status_updated' AND entity_id=$2)`,
      [leadId, d2, JSON.stringify({ status: 'submitted' }), JSON.stringify({ status: 'approved' })]
    );

    // Ensure every active team member sees dashboard data
    const teamMembers = await pool.query(
      `SELECT id, name
       FROM users
       WHERE role = 'teamMember' AND is_active = true`
    );
    for (const member of teamMembers.rows) {
      const memberIdLocal = member.id;
      const memberName = member.name || 'Team Member';

      await pool.query(
        `INSERT INTO project_members (project_id, user_id, role)
         VALUES ($1, $2, 'teamMember')
         ON CONFLICT (project_id, user_id) DO UPDATE SET role = EXCLUDED.role`,
        [projectId, memberIdLocal]
      );

      const memberDeliverable = await ensureOne(
        'SELECT id FROM deliverables WHERE title = $1 AND assigned_to = $2 LIMIT 1',
        [`${memberName} - Dashboard Demo Task`, memberIdLocal],
        `INSERT INTO deliverables
         (title, description, status, project_id, created_by, assigned_to, sprint_id, due_date, priority, progress, definition_of_done, evidence, readiness_gates)
         VALUES
         ($1,'Task created specifically for dashboard preview','in_progress',$2,$3,$4,$5,CURRENT_TIMESTAMP + INTERVAL '3 days','Medium',55,$6::jsonb,$7::jsonb,$8::jsonb)
         RETURNING id`,
        [
          `${memberName} - Dashboard Demo Task`,
          projectId,
          leadId,
          memberIdLocal,
          sprintBetaId,
          JSON.stringify(['Dev done', 'Peer review pending']),
          JSON.stringify(['preview-note.txt']),
          JSON.stringify(['Quality Gate']),
        ]
      );

      await pool.query(
        `INSERT INTO notifications (user_id, title, message, type, action_url)
         SELECT $1, 'New assigned deliverable', 'You have a demo deliverable assigned for dashboard preview.', 'info', '/deliverables'
         WHERE NOT EXISTS (
           SELECT 1 FROM notifications WHERE user_id = $1 AND title = 'New assigned deliverable'
         )`,
        [memberIdLocal]
      );

      await pool.query(
        `INSERT INTO activity_logs (user_id, entity_type, entity_id, action, description, old_values, new_values, ip_address, user_agent)
         SELECT $1,'deliverable',$2,'assigned','Demo deliverable assigned for dashboard preview',NULL,$3::jsonb,'127.0.0.1','Seed Script'
         WHERE NOT EXISTS (
           SELECT 1 FROM activity_logs WHERE user_id = $1 AND action = 'assigned' AND entity_id = $2
         )`,
        [memberIdLocal, memberDeliverable, JSON.stringify({ status: 'in_progress' })]
      );
    }

    await pool.query('COMMIT');
    console.log('✅ Sample dashboard data inserted successfully.');
  } catch (error) {
    await pool.query('ROLLBACK');
    console.error('❌ Failed to seed sample data:', error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
