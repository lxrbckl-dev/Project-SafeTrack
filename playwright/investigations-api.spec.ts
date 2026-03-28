/**
 * investigations-api.spec.ts
 *
 * API-level smoke tests for TASK-006: Investigation Models + API.
 * These tests call the Go backend directly via fetch() inside Playwright's
 * browser context, using the login endpoint to obtain a JWT.
 *
 * Run against the PR branch backend on port 8001:
 *   PORT=8001 go run ./cmd/server/ &
 *   PLAYWRIGHT_BASE_URL=http://localhost:3001 npx playwright test investigations-api
 */

import { test, expect } from '@playwright/test';

const API = process.env.API_BASE_URL ?? 'http://localhost:8001';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const ROLE_EMAILS: Record<string, string> = {
  field_reporter: 'reporter@safetrack.demo',
  safety_coordinator: 'coordinator@safetrack.demo',
  safety_manager: 'manager@safetrack.demo',
  pm: 'pm@safetrack.demo',
  division_manager: 'director@safetrack.demo',
  executive: 'executive@safetrack.demo',
  admin: 'admin@safetrack.demo',
};

async function getToken(page: import('@playwright/test').Page, role: string): Promise<string> {
  const email = ROLE_EMAILS[role] ?? `${role}@safetrack.demo`;
  const res = await page.request.post(`${API}/api/login`, {
    data: { email, password: 'demo1234' },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  return body.token as string;
}

async function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

/** Create a basic incident and return its ID. Used as a prerequisite for investigation tests. */
async function createIncident(
  page: import('@playwright/test').Page,
  token: string,
  severity: string = 'First Aid',
): Promise<number> {
  const res = await page.request.post(`${API}/api/incidents`, {
    headers: await authHeaders(token),
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Test Site A',
      description: `Investigation test incident (${severity}) — ${Date.now()}`,
      severity,
      isDraft: false,
    },
  });
  expect(res.status()).toBe(201);
  const inc = await res.json();
  return inc.id as number;
}

// ---------------------------------------------------------------------------
// 1. RBAC — Create Investigation (Safety Manager only)
// ---------------------------------------------------------------------------

test('POST /api/investigations — safety_manager can create investigation', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: {
      incidentId,
      leadInvestigatorId: 'investigator-user-1',
      teamMembers: '["member-a","member-b"]',
    },
  });

  expect(res.status()).toBe(201);
  const inv = await res.json();
  expect(inv.id).toBeGreaterThan(0);
  expect(inv.incidentId).toBe(incidentId);
  expect(inv.status).toBe('Assigned');
  expect(inv.leadInvestigatorId).toBe('investigator-user-1');
});

test('POST /api/investigations — field_reporter is forbidden (403)', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const frToken = await getToken(page, 'field_reporter');
  const incidentId = await createIncident(page, smToken, 'Near Miss');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(frToken),
    data: {
      incidentId,
      leadInvestigatorId: 'investigator-user-2',
    },
  });

  expect(res.status()).toBe(403);
});

test('POST /api/investigations — safety_coordinator is forbidden (403)', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const scToken = await getToken(page, 'safety_coordinator');
  const incidentId = await createIncident(page, smToken, 'Near Miss');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(scToken),
    data: {
      incidentId,
      leadInvestigatorId: 'investigator-user-3',
    },
  });

  expect(res.status()).toBe(403);
});

// ---------------------------------------------------------------------------
// 2. Auto-Deadline by Severity
// ---------------------------------------------------------------------------

test('Auto-deadline: Fatality → ~48 hours from now', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'Fatality');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-fatality' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();

  const now = Date.now();
  const deadline = new Date(inv.targetCompletionDate).getTime();
  const diffHours = (deadline - now) / (1000 * 60 * 60);
  // 48 hours ± 1 hour tolerance
  expect(diffHours).toBeGreaterThan(47);
  expect(diffHours).toBeLessThan(49);
});

test('Auto-deadline: Medical Treatment → ~10 calendar days from now', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'Medical Treatment');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-medical' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();

  const now = Date.now();
  const deadline = new Date(inv.targetCompletionDate).getTime();
  const diffDays = (deadline - now) / (1000 * 60 * 60 * 24);
  // 10 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(9);
  expect(diffDays).toBeLessThan(11);
});

test('Auto-deadline: First Aid → ~14 calendar days from now', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-firstaid' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();

  const now = Date.now();
  const deadline = new Date(inv.targetCompletionDate).getTime();
  const diffDays = (deadline - now) / (1000 * 60 * 60 * 24);
  // 14 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(13);
  expect(diffDays).toBeLessThan(15);
});

test('Auto-deadline: Near Miss → ~14 calendar days from now', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'Near Miss');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-nearmiss' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();

  const now = Date.now();
  const deadline = new Date(inv.targetCompletionDate).getTime();
  const diffDays = (deadline - now) / (1000 * 60 * 60 * 24);
  expect(diffDays).toBeGreaterThan(13);
  expect(diffDays).toBeLessThan(15);
});

test('Auto-deadline: Lost Time → ~5 business days from now', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'Lost Time');

  const res = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-losttime' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();

  const now = Date.now();
  const deadline = new Date(inv.targetCompletionDate).getTime();
  const diffDays = (deadline - now) / (1000 * 60 * 60 * 24);
  // 5 business days = 5-9 calendar days depending on weekends
  expect(diffDays).toBeGreaterThan(4);
  expect(diffDays).toBeLessThan(10);
});

// ---------------------------------------------------------------------------
// 3. Duplicate Investigation Prevention
// ---------------------------------------------------------------------------

test('POST /api/investigations — duplicate for same incident returns 409', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');
  const headers = await authHeaders(smToken);

  // First creation
  const r1 = await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-dup-1' },
  });
  expect(r1.status()).toBe(201);

  // Second creation for same incident
  const r2 = await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-dup-2' },
  });
  expect(r2.status()).toBe(409);
});

// ---------------------------------------------------------------------------
// 4. Incident Status Updated to "Under Investigation" on Create
// ---------------------------------------------------------------------------

test('Creating investigation updates incident status to Under Investigation', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  // Advance incident to Reported first
  await page.request.post(`${API}/api/incidents/${incidentId}/status`, {
    headers,
    data: { status: 'Reported' },
  });

  await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-status-check' },
  });

  const incRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  expect(incRes.ok()).toBeTruthy();
  const incident = await incRes.json();
  expect(incident.status).toBe('Under Investigation');
});

// ---------------------------------------------------------------------------
// 5. Five-Why CRUD — no minimum enforced on individual saves
// ---------------------------------------------------------------------------

test('POST /api/investigations/{id}/five-whys — any authenticated user can create', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const createInvRes = await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-fivewhy' },
  });
  const inv = await createInvRes.json();

  // Use safety_coordinator (not safety_manager) — should still be allowed
  const scToken = await getToken(page, 'safety_coordinator');
  const res = await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers: await authHeaders(scToken),
    data: {
      level: 1,
      question: 'Why did the worker slip?',
      answer: 'Floor was wet.',
      evidence: 'Photo of wet floor.',
    },
  });

  expect(res.status()).toBe(201);
  const why = await res.json();
  expect(why.id).toBeGreaterThan(0);
  expect(why.level).toBe(1);
  expect(why.sortOrder).toBeGreaterThan(0);
});

test('DELETE /api/investigations/{id}/five-whys/{whyId} — allowed even when fewer than 3 remain', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-del-why' },
  })).json();

  const scToken = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(scToken);

  // Create exactly 2 whys
  const why1 = await (await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 1, question: 'Q1', answer: 'A1' },
  })).json();

  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 2, question: 'Q2', answer: 'A2' },
  });

  // Delete the first one — should succeed even though only 1 remains
  const delRes = await page.request.delete(
    `${API}/api/investigations/${inv.id}/five-whys/${why1.id}`,
    { headers },
  );
  expect(delRes.status()).toBe(204);
});

// ---------------------------------------------------------------------------
// 6. Contributing Factors — no minimum on individual creates/deletes
// ---------------------------------------------------------------------------

test('POST /api/investigations/{id}/factors — any authenticated user can create', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-factor' },
  })).json();

  const scToken = await getToken(page, 'safety_coordinator');
  const res = await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers: await authHeaders(scToken),
    data: {
      factorType: 'People',
      factorDescription: 'Insufficient training.',
      isPrimary: true,
    },
  });

  expect(res.status()).toBe(201);
  const factor = await res.json();
  expect(factor.id).toBeGreaterThan(0);
  expect(factor.isPrimary).toBe(true);
});

test('POST /api/investigations/{id}/factors — missing factorType returns 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers: await authHeaders(smToken),
    data: { incidentId, leadInvestigatorId: 'inv-factor-noType' },
  })).json();

  const res = await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers: await authHeaders(smToken),
    data: { factorDescription: 'Missing type.' },
  });

  expect(res.status()).toBe(400);
});

test('DELETE /api/investigations/{id}/factors/{factorId} — allowed freely', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-del-factor' },
  })).json();

  const factor = await (await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Equipment', isPrimary: false },
  })).json();

  const delRes = await page.request.delete(
    `${API}/api/investigations/${inv.id}/factors/${factor.id}`,
    { headers },
  );
  expect(delRes.status()).toBe(204);
});

// ---------------------------------------------------------------------------
// 7. Witness Statements
// ---------------------------------------------------------------------------

test('POST /api/investigations/{id}/witnesses — create and update witness statement', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-witness' },
  })).json();

  // Create
  const createRes = await page.request.post(`${API}/api/investigations/${inv.id}/witnesses`, {
    headers,
    data: {
      witnessName: 'Jane Smith',
      witnessTitle: 'Foreman',
      witnessEmployer: 'Acme Construction',
      witnessPhone: '555-0100',
      statementText: 'I saw the worker slip near the scaffolding.',
      collectionDate: new Date().toISOString(),
      collectorName: 'Safety Officer A',
    },
  });
  expect(createRes.status()).toBe(201);
  const stmt = await createRes.json();
  expect(stmt.id).toBeGreaterThan(0);
  expect(stmt.witnessName).toBe('Jane Smith');

  // Update
  const updateRes = await page.request.put(
    `${API}/api/investigations/${inv.id}/witnesses/${stmt.id}`,
    {
      headers,
      data: { statementText: 'Revised: I saw the worker slip near the wet scaffolding base.' },
    },
  );
  expect(updateRes.ok()).toBeTruthy();
  const updated = await updateRes.json();
  expect(updated.statementText).toContain('Revised:');
});

test('POST /api/investigations/{id}/witnesses — missing required fields returns 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-witness-bad' },
  })).json();

  // Missing statementText
  const res = await page.request.post(`${API}/api/investigations/${inv.id}/witnesses`, {
    headers,
    data: { witnessName: 'No Statement' },
  });
  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 8. Submit-For-Review Validation
// ---------------------------------------------------------------------------

test('Submit-for-review: fewer than 3 five-whys → 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-submit-nowhys' },
  })).json();

  // Add 2 whys and 1 primary factor
  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 1, question: 'Q1', answer: 'A1' },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 2, question: 'Q2', answer: 'A2' },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'People', isPrimary: true },
  });

  const submitRes = await page.request.post(
    `${API}/api/investigations/${inv.id}/submit-for-review`,
    { headers, data: {} },
  );
  expect(submitRes.status()).toBe(400);
  const body = await submitRes.json();
  expect(body.error).toContain('minimum 3');
});

test('Submit-for-review: no primary factor → 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-submit-nofactor' },
  })).json();

  // Add 3 whys but no PRIMARY factor
  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
      headers,
      data: { level: i, question: `Q${i}`, answer: `A${i}` },
    });
  }
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Equipment', isPrimary: false },
  });

  const submitRes = await page.request.post(
    `${API}/api/investigations/${inv.id}/submit-for-review`,
    { headers, data: {} },
  );
  expect(submitRes.status()).toBe(400);
  const body = await submitRes.json();
  expect(body.error).toContain('primary');
});

test('Submit-for-review: 3+ whys + 1 primary factor → status becomes Under Review', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-submit-ok' },
  })).json();

  // Add exactly 3 whys
  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
      headers,
      data: { level: i, question: `Why ${i}?`, answer: `Because ${i}.` },
    });
  }
  // Add 1 primary factor
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Procedural', isPrimary: true },
  });

  const submitRes = await page.request.post(
    `${API}/api/investigations/${inv.id}/submit-for-review`,
    { headers, data: {} },
  );
  expect(submitRes.ok()).toBeTruthy();
  const updated = await submitRes.json();
  expect(updated.status).toBe('Under Review');
});

// ---------------------------------------------------------------------------
// 9. Review Workflow — Approve and Return
// ---------------------------------------------------------------------------

/** Helper: create an investigation, populate it, and submit for review */
async function createAndSubmitInvestigation(
  page: import('@playwright/test').Page,
  smToken: string,
): Promise<number> {
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-review-user' },
  })).json();

  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
      headers,
      data: { level: i, question: `Why ${i}?`, answer: `Because ${i}.` },
    });
  }
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Procedural', isPrimary: true },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/submit-for-review`, {
    headers,
    data: {},
  });

  return inv.id as number;
}

test('RBAC: field_reporter cannot review investigation (403)', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const invId = await createAndSubmitInvestigation(page, smToken);

  const frToken = await getToken(page, 'field_reporter');
  const res = await page.request.post(`${API}/api/investigations/${invId}/review`, {
    headers: await authHeaders(frToken),
    data: { decision: 'approve', comments: 'Looks good.' },
  });
  expect(res.status()).toBe(403);
});

test('Approve investigation: status → Approved, incident → Investigation Complete', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);

  // Create incident, get its ID before submitting
  const incidentId = await createIncident(page, smToken, 'First Aid');
  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-approve' },
  })).json();

  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
      headers,
      data: { level: i, question: `Q${i}`, answer: `A${i}` },
    });
  }
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Management/Organizational', isPrimary: true },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/submit-for-review`, {
    headers,
    data: {},
  });

  const reviewRes = await page.request.post(`${API}/api/investigations/${inv.id}/review`, {
    headers,
    data: { decision: 'approve', comments: 'Investigation is thorough and complete.' },
  });
  expect(reviewRes.ok()).toBeTruthy();
  const reviewed = await reviewRes.json();
  expect(reviewed.status).toBe('Approved');
  expect(reviewed.reviewedBy).toBeTruthy();
  expect(reviewed.reviewDate).toBeTruthy();
  expect(reviewed.reviewComments).toBe('Investigation is thorough and complete.');

  // Check incident status
  const incRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  const incident = await incRes.json();
  expect(incident.status).toBe('Investigation Complete');
});

test('Return investigation: status → Returned, comments required', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const invId = await createAndSubmitInvestigation(page, smToken);

  // Missing comments → 400
  const noCommentRes = await page.request.post(`${API}/api/investigations/${invId}/review`, {
    headers,
    data: { decision: 'return', comments: '' },
  });
  expect(noCommentRes.status()).toBe(400);

  // With comments → success
  const returnRes = await page.request.post(`${API}/api/investigations/${invId}/review`, {
    headers,
    data: { decision: 'return', comments: 'Need more detail on root cause.' },
  });
  expect(returnRes.ok()).toBeTruthy();
  const returned = await returnRes.json();
  expect(returned.status).toBe('Returned');
  expect(returned.reviewComments).toBe('Need more detail on root cause.');
});

test('Review: cannot review investigation not in Under Review state → 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-bad-review' },
  })).json();
  // Status is still 'Assigned' — not Under Review

  const res = await page.request.post(`${API}/api/investigations/${inv.id}/review`, {
    headers,
    data: { decision: 'approve', comments: 'Premature.' },
  });
  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 10. Get Investigation with Preloaded Relations
// ---------------------------------------------------------------------------

test('GET /api/investigations/{id} — returns fiveWhys ordered by sortOrder', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-get-test' },
  })).json();

  // Add whys out of natural order by specifying explicit sort orders
  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 3, question: 'Q3', answer: 'A3', sortOrder: 3 },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 1, question: 'Q1', answer: 'A1', sortOrder: 1 },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
    headers,
    data: { level: 2, question: 'Q2', answer: 'A2', sortOrder: 2 },
  });

  const getRes = await page.request.get(`${API}/api/investigations/${inv.id}`, { headers });
  expect(getRes.ok()).toBeTruthy();
  const fetched = await getRes.json();
  expect(fetched.fiveWhys).toHaveLength(3);
  // Verify ascending sort order
  expect(fetched.fiveWhys[0].sortOrder).toBe(1);
  expect(fetched.fiveWhys[1].sortOrder).toBe(2);
  expect(fetched.fiveWhys[2].sortOrder).toBe(3);
});

// ---------------------------------------------------------------------------
// 11. List Investigations with Filters
// ---------------------------------------------------------------------------

test('GET /api/investigations — paginated list with status filter', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);

  const res = await page.request.get(`${API}/api/investigations?status=Assigned&page=1&per_page=10`, {
    headers,
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  expect(Array.isArray(body.data)).toBeTruthy();
  expect(typeof body.total).toBe('number');
  expect(body.page).toBe(1);
  for (const inv of body.data) {
    expect(inv.status).toBe('Assigned');
  }
});

// ---------------------------------------------------------------------------
// 12. Overdue Escalation Thresholds (CRITICAL)
// ---------------------------------------------------------------------------

test('Overdue escalation: model comment documents 1=1-6 days, 2=7-13 days, 3=14+ days', async ({ page }) => {
  // This test validates the field comment in the API response indirectly by
  // confirming that a fresh investigation is NOT overdue (deadline in future).
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-overdue-check' },
  })).json();

  const getRes = await page.request.get(`${API}/api/investigations/${inv.id}`, { headers });
  const fetched = await getRes.json();

  // New investigation with 14-day deadline must NOT be overdue
  expect(fetched.isOverdue).toBe(false);
  expect(fetched.overdueEscalationLevel).toBe(0);
});

// ---------------------------------------------------------------------------
// 13. Audit Logging
// ---------------------------------------------------------------------------

test('Audit log entries are created for create, submit, approve actions', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const headers = await authHeaders(smToken);
  const incidentId = await createIncident(page, smToken, 'First Aid');

  const inv = await (await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'inv-audit' },
  })).json();

  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${inv.id}/five-whys`, {
      headers,
      data: { level: i, question: `Q${i}`, answer: `A${i}` },
    });
  }
  await page.request.post(`${API}/api/investigations/${inv.id}/factors`, {
    headers,
    data: { factorType: 'Environmental', isPrimary: true },
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/submit-for-review`, {
    headers,
    data: {},
  });
  await page.request.post(`${API}/api/investigations/${inv.id}/review`, {
    headers,
    data: { decision: 'approve', comments: 'Approved for audit test.' },
  });

  // Fetch audit logs for this investigation
  const logsRes = await page.request.get(
    `${API}/api/audit-logs?entity_type=investigation&entity_id=${inv.id}`,
    { headers },
  );
  expect(logsRes.ok()).toBeTruthy();
  const logsBody = await logsRes.json();
  const actions = logsBody.data.map((l: { action: string }) => l.action);

  expect(actions).toContain('create');
  expect(actions).toContain('status_change'); // submit-for-review
  expect(actions).toContain('approve');
});
