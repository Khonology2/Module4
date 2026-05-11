const express = require('express');
const router = express.Router();

function normalizeLinks(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item || '').trim())
    .filter(Boolean);
}

function normalizeItems(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (typeof item === 'string') return item.trim();
      if (item && typeof item === 'object') {
        return String(item.text || item.title || item.description || '').trim();
      }
      return '';
    })
    .filter(Boolean);
}

function statusFromSeverity(score) {
  if (score <= 0) return 'green';
  if (score <= 2) return 'amber';
  return 'red';
}

function analyzeEvidence(evidenceLinks) {
  const links = normalizeLinks(evidenceLinks);
  const lower = links.map((link) => link.toLowerCase());
  const hasDemo = lower.some((v) => v.includes('demo') || v.includes('video') || v.includes('live'));
  const hasRepo = lower.some((v) => v.includes('repo') || v.includes('github') || v.includes('gitlab') || v.includes('bitbucket'));
  const hasTests = lower.some((v) => v.includes('test') || v.includes('coverage') || v.includes('report') || v.includes('result'));
  const hasDocs = lower.some((v) => v.includes('doc') || v.includes('guide') || v.includes('readme') || v.includes('wiki'));
  return { links, hasDemo, hasRepo, hasTests, hasDocs };
}

function evaluateReadiness(payload) {
  const title = String(payload.deliverableTitle || '').trim();
  const description = String(payload.deliverableDescription || '').trim();
  const definitionOfDone = normalizeItems(payload.definitionOfDone);
  const sprintIds = normalizeItems(payload.sprintIds);
  const evidence = analyzeEvidence(payload.evidenceLinks);
  const sprintMetrics = payload.sprintMetrics && typeof payload.sprintMetrics === 'object'
    ? payload.sprintMetrics
    : {};
  const issues = [];
  const recommendations = [];
  const risks = [];
  const missingItems = [];

  if (!title) {
    issues.push('Deliverable title is missing');
    missingItems.push('Deliverable title');
  }
  if (!description) {
    issues.push('Deliverable description is missing');
    missingItems.push('Deliverable description');
  }
  if (definitionOfDone.length === 0) {
    issues.push('Definition of Done is missing');
    missingItems.push('Definition of Done');
  } else if (definitionOfDone.length < 3) {
    issues.push('Definition of Done should contain at least 3 items');
    missingItems.push('More Definition of Done items');
  }
  if (sprintIds.length === 0) {
    issues.push('No contributing sprints are linked');
    missingItems.push('Linked sprint');
  }
  if (evidence.links.length === 0) {
    issues.push('No delivery evidence is attached');
    missingItems.push('Evidence links');
  }
  if (!evidence.hasTests) {
    issues.push('Test evidence is missing');
    missingItems.push('Test evidence');
  }
  if (!evidence.hasDemo) {
    recommendations.push('Attach a demo link or walkthrough video');
  }
  if (!evidence.hasRepo) {
    recommendations.push('Attach a repository link for traceability');
  }
  if (!evidence.hasDocs) {
    recommendations.push('Attach a user guide or supporting documentation');
  }

  const testPassRate = Number(sprintMetrics.test_pass_rate ?? sprintMetrics.testPassRate ?? 0);
  const codeCoverage = Number(sprintMetrics.code_coverage ?? sprintMetrics.codeCoverage ?? 0);
  const defectsOpened = Number(sprintMetrics.defects_opened ?? sprintMetrics.defectsOpened ?? 0);
  const defectsClosed = Number(sprintMetrics.defects_closed ?? sprintMetrics.defectsClosed ?? 0);
  const escapedDefects = Number(sprintMetrics.escaped_defects ?? sprintMetrics.escapedDefects ?? 0);

  if (testPassRate > 0 && testPassRate < 90) {
    issues.push(`Test pass rate is below threshold at ${testPassRate}%`);
    risks.push('Low test pass rate may increase client feedback and rework');
  }
  if (codeCoverage > 0 && codeCoverage < 75) {
    recommendations.push(`Increase code coverage from ${codeCoverage}% to at least 75%`);
  }
  if (defectsOpened > defectsClosed && defectsOpened > 0) {
    issues.push('Defects opened exceed defects closed across linked sprint data');
    risks.push('Outstanding defects may affect sign-off confidence');
  }
  if (escapedDefects > 0) {
    issues.push(`Escaped defects recorded: ${escapedDefects}`);
    risks.push('Escaped defects indicate unresolved acceptance hygiene');
  }

  const score = issues.length;
  const status = statusFromSeverity(score);
  const priorityActions = [...issues, ...recommendations].slice(0, 3);
  const aiInsights = status === 'green'
    ? 'All readiness checks passed. The deliverable is ready for client review.'
    : status === 'amber'
      ? 'Some readiness gaps remain. Resolve or acknowledge them before submission.'
      : 'Critical readiness gaps were detected. Client submission should be blocked until they are resolved or internally approved.';

  return {
    status,
    confidence: status === 'green' ? 0.94 : status === 'amber' ? 0.86 : 0.9,
    issues,
    recommendations,
    risks,
    missingItems,
    priorityActions,
    aiInsights,
  };
}

router.post('/analyze', async (req, res) => {
  try {
    const analysis = evaluateReadiness(req.body || {});
    return res.json(analysis);
  } catch (error) {
    console.error('Release readiness analysis error:', error);
    return res.status(500).json({ error: 'Failed to analyze release readiness' });
  }
});

router.post('/suggest-items', async (req, res) => {
  try {
    const suggestions = [
      'Code review completed',
      'Integration test evidence attached',
      'Client demo link attached',
      'User guide or release notes attached',
      'Known limitations documented',
      'Acceptance test summary attached',
    ];
    return res.json({ suggestions });
  } catch (error) {
    console.error('Release readiness suggestion error:', error);
    return res.status(500).json({ error: 'Failed to suggest readiness items' });
  }
});

router.post('/analyze-sprints', async (req, res) => {
  try {
    const sprintMetrics = Array.isArray(req.body?.sprintMetrics) ? req.body.sprintMetrics : [];
    if (sprintMetrics.length === 0) {
      return res.json({
        overallHealth: 'warning',
        concerns: ['No sprint metrics supplied'],
        strengths: [],
      });
    }
    const avgPassRate = sprintMetrics.reduce((sum, item) => sum + Number(item.test_pass_rate ?? item.testPassRate ?? 0), 0) / sprintMetrics.length;
    const avgVelocity = sprintMetrics.reduce((sum, item) => sum + Number(item.completed_points ?? item.completedPoints ?? 0), 0) / sprintMetrics.length;
    const scopeChangeCount = sprintMetrics.filter((item) => Number(item.points_added ?? item.pointsAdded ?? 0) > 0 || Number(item.points_removed ?? item.pointsRemoved ?? 0) > 0).length;
    const concerns = [];
    const strengths = [];
    if (avgPassRate < 90) {
      concerns.push(`Average test pass rate is ${avgPassRate.toFixed(1)}%`);
    } else {
      strengths.push(`Average test pass rate is ${avgPassRate.toFixed(1)}%`);
    }
    if (avgVelocity > 0) {
      strengths.push(`Average completed points are ${avgVelocity.toFixed(1)}`);
    }
    if (scopeChangeCount > 0) {
      concerns.push(`${scopeChangeCount} sprint(s) had scope changes`);
    }
    return res.json({
      overallHealth: concerns.length > 1 ? 'warning' : 'good',
      concerns,
      strengths,
    });
  } catch (error) {
    console.error('Sprint readiness analysis error:', error);
    return res.status(500).json({ error: 'Failed to analyze sprint metrics' });
  }
});

module.exports = router;
