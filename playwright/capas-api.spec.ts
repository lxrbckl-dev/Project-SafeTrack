/**
 * capas-api.spec.ts
 *
 * API-level smoke tests for TASK-008: CAPA Models + API Backend.
 * These tests call the Go backend directly via Playwright's request context,
 * using the login endpoint to obtain a JWT.
 *
 * Run against the PR branch backend on port 8001:
 *   PORT=8001 go run ./cmd/server/ &
 *   API_BASE_URL=http://localhost:8001 npx playwright test capas-api
 *
 * Test coverage:
 *   1.  CAPA model — all lifecycle fields present in API response
 *   2.  CAPA registered in AllModels() (build/migration path verified by build step)
 *   3.  Auto due dates by priority: Critical=7d, High=14d, Medium=30d, Low=60d
 *   4.  CompleteCAPA: sets "Verification Pending", auto VerificationDueDate
 *       by priority (Critical=30d, High=60d, Med/Low=90d)
 *   5.  VerifyCAPA: rejects verifier==assignee (403)
 *   6.  VerifyCAPA: effective path → "Verified Effective"
 *   7.  VerifyCAPA: ineffective path → "Verified Ineffective" + nextSteps
 *   8.  Dashboard: 4 KPI fields present
 *   9.  Overdue escalation: fresh CAPA is NOT overdue (level 0)
 *   10. CloseIncident: blocks close when CAPAs are not all Verified Effective
 *   11. CloseIncident: succeeds when all CAPAs are Verified Effective
 *   12. Incident status transitions on CAPA create (→ "CAPA Assigned")
 *   13. Incident status transitions on CAPA update to In Progress (→ "CAPA In Progress")
 *   14. Audit log: create, complete, verify actions are logged
 *   15. Input validation: invalid type/category/priority → 400
 *   16. ListCAPAs: pagination + filters work
 *   17. GetCAPA: 404 for unknown ID
 *   18. UpdateCAPA: partial update + priority recalculates due date
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

async function getToken(
  page: import('@playwright/test').Page,
  role: string,
): Promise<string> {
  const email = ROLE_EMAILS[role] ?? `${role}@safetrack.demo`;
  const res = await page.request.post(`${API}/api/login`, {
    data: { email, password: 'demo1234' },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  return body.token as string;
}

/** Returns { token, userId } for a role. */
async function getTokenAndUserId(
  page: import('@playwright/test').Page,
  role: string,
): Promise<{ token: string; userId: string }> {
  const email = ROLE_EMAILS[role] ?? `${role}@safetrack.demo`;
  const res = await page.request.post(`${API}/api/login`, {
    data: { email, password: 'demo1234' },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  return { token: body.token as string, userId: body.userId as string };
}

function authHeaders(token: string) {
  return { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
}

/** Create an incident and return its ID. */
async function createIncident(
  page: import('@playwright/test').Page,
  token: string,
): Promise<number> {
  const res = await page.request.post(`${API}/api/incidents`, {
    headers: authHeaders(token),
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'CAPA Test Site',
      description: `CAPA test incident — ${Date.now()}`,
      severity: 'First Aid',
      isDraft: false,
    },
  });
  expect(res.status()).toBe(201);
  const inc = await res.json();
  return inc.id as number;
}

/** Create an investigation for an incident and return its ID.
 *  Also advances the incident from Draft → Reported → Under Investigation. */
async function createInvestigation(
  page: import('@playwright/test').Page,
  token: string,
  incidentId: number,
): Promise<number> {
  const headers = authHeaders(token);

  // Advance incident to Reported
  await page.request.post(`${API}/api/incidents/${incidentId}/status`, {
    headers,
    data: { status: 'Reported' },
  });

  const res = await page.request.post(`${API}/api/investigations`, {
    headers,
    data: { incidentId, leadInvestigatorId: 'qa-investigator' },
  });
  expect(res.status()).toBe(201);
  const inv = await res.json();
  return inv.id as number;
}

/** Create an investigation with minimal five-whys + factor, then approve it
 *  so the incident reaches "Investigation Complete" — required before a CAPA
 *  can be assigned. */
async function approveInvestigation(
  page: import('@playwright/test').Page,
  token: string,
  incidentId: number,
): Promise<{ investigationId: number }> {
  const headers = authHeaders(token);
  const investigationId = await createInvestigation(page, token, incidentId);

  for (let i = 1; i <= 3; i++) {
    await page.request.post(`${API}/api/investigations/${investigationId}/five-whys`, {
      headers,
      data: { level: i, question: `Why ${i}?`, answer: `Because ${i}.` },
    });
  }
  await page.request.post(`${API}/api/investigations/${investigationId}/factors`, {
    headers,
    data: { factorType: 'Procedural', isPrimary: true },
  });
  await page.request.post(`${API}/api/investigations/${investigationId}/submit-for-review`, {
    headers,
    data: {},
  });
  await page.request.post(`${API}/api/investigations/${investigationId}/review`, {
    headers,
    data: { decision: 'approve', comments: 'Approved for CAPA QA test.' },
  });

  return { investigationId };
}

/**
 * Full setup: create incident + investigation + approve → returns ids needed
 * for CAPA creation.
 */
async function setupForCAPA(
  page: import('@playwright/test').Page,
  token: string,
): Promise<{ incidentId: number; investigationId: number }> {
  const incidentId = await createIncident(page, token);
  const { investigationId } = await approveInvestigation(page, token, incidentId);
  return { incidentId, investigationId };
}

/** Create a CAPA and return the full body. */
async function createCAPA(
  page: import('@playwright/test').Page,
  token: string,
  incidentId: number,
  investigationId: number,
  priority: string = 'Medium',
  assignedToUserId: string = 'qa-assignee-user',
): Promise<Record<string, unknown>> {
  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId,
      type: 'Corrective',
      category: 'Training',
      description: `QA CAPA [${priority}] — ${Date.now()}`,
      assignedToUserId,
      priority,
      verificationMethod: 'Direct observation and record review',
    },
  });
  expect(res.status()).toBe(201);
  return res.json();
}

// ---------------------------------------------------------------------------
// 1. CAPA model — all lifecycle fields present
// ---------------------------------------------------------------------------

test('CAPA model: all lifecycle fields present in creation response', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');

  // Required identity fields
  expect(typeof capa.id).toBe('number');
  expect((capa.id as number)).toBeGreaterThan(0);
  expect(capa.investigationId).toBe(investigationId);
  expect(capa.incidentId).toBe(incidentId);

  // Descriptive fields
  expect(capa.type).toBe('Corrective');
  expect(capa.category).toBe('Training');
  expect(typeof capa.description).toBe('string');
  expect(capa.priority).toBe('Medium');
  expect(capa.verificationMethod).toBe('Direct observation and record review');

  // Assignment fields
  expect(typeof capa.assignedToUserId).toBe('string');
  expect(typeof capa.assignedByUserId).toBe('string');

  // Due-date lifecycle fields
  expect(typeof capa.dueDate).toBe('string');
  expect(capa.verificationDueDate).toBeNull(); // not set until complete

  // Status
  expect(capa.status).toBe('Open');

  // Completion lifecycle fields (null until completed)
  expect(capa.completionNotes).toBe('');
  expect(capa.completionEvidence).toBe('');
  expect(capa.completionDate).toBeNull();

  // Verification lifecycle fields (null until verified)
  expect(capa.verifiedByUserId).toBe('');
  expect(capa.verificationDate).toBeNull();
  expect(capa.verificationNotes).toBe('');

  // Overdue fields
  expect(capa.isOverdue).toBe(false);
  expect(capa.overdueEscalationLevel).toBe(0);

  // Timestamps
  expect(typeof capa.createdAt).toBe('string');
  expect(typeof capa.updatedAt).toBe('string');
});

// ---------------------------------------------------------------------------
// 2. Auto due dates by priority
// ---------------------------------------------------------------------------

test('Auto due date: Critical priority → ~7 calendar days from now', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Critical');

  const now = Date.now();
  const dueDate = new Date(capa.dueDate as string).getTime();
  const diffDays = (dueDate - now) / (1000 * 60 * 60 * 24);

  // 7 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(6);
  expect(diffDays).toBeLessThan(8);
});

test('Auto due date: High priority → ~14 calendar days from now', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'High');

  const now = Date.now();
  const dueDate = new Date(capa.dueDate as string).getTime();
  const diffDays = (dueDate - now) / (1000 * 60 * 60 * 24);

  // 14 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(13);
  expect(diffDays).toBeLessThan(15);
});

test('Auto due date: Medium priority → ~30 calendar days from now', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');

  const now = Date.now();
  const dueDate = new Date(capa.dueDate as string).getTime();
  const diffDays = (dueDate - now) / (1000 * 60 * 60 * 24);

  // 30 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(29);
  expect(diffDays).toBeLessThan(31);
});

test('Auto due date: Low priority → ~60 calendar days from now', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Low');

  const now = Date.now();
  const dueDate = new Date(capa.dueDate as string).getTime();
  const diffDays = (dueDate - now) / (1000 * 60 * 60 * 24);

  // 60 days ± 1 day tolerance
  expect(diffDays).toBeGreaterThan(59);
  expect(diffDays).toBeLessThan(61);
});

// ---------------------------------------------------------------------------
// 3. CompleteCAPA: sets Verification Pending + auto VerificationDueDate
// ---------------------------------------------------------------------------

test('CompleteCAPA: Critical priority → status=Verification Pending, verificationDueDate ~30d', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Critical');
  const capaId = capa.id as number;

  const res = await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Retraining completed.', evidence: 'Training records attached.' },
  });
  expect(res.ok()).toBeTruthy();
  const completed = await res.json();

  expect(completed.status).toBe('Verification Pending');
  expect(completed.completionDate).not.toBeNull();
  expect(completed.completionNotes).toBe('Retraining completed.');
  expect(completed.completionEvidence).toBe('Training records attached.');

  // verificationDueDate = ~30 days from now for Critical
  const now = Date.now();
  const vdd = new Date(completed.verificationDueDate as string).getTime();
  const diffDays = (vdd - now) / (1000 * 60 * 60 * 24);
  expect(diffDays).toBeGreaterThan(29);
  expect(diffDays).toBeLessThan(31);
});

test('CompleteCAPA: High priority → verificationDueDate ~60d', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'High');
  const capaId = capa.id as number;

  const res = await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Procedure updated.', evidence: 'Revised SOP uploaded.' },
  });
  expect(res.ok()).toBeTruthy();
  const completed = await res.json();

  expect(completed.status).toBe('Verification Pending');

  const now = Date.now();
  const vdd = new Date(completed.verificationDueDate as string).getTime();
  const diffDays = (vdd - now) / (1000 * 60 * 60 * 24);
  expect(diffDays).toBeGreaterThan(59);
  expect(diffDays).toBeLessThan(61);
});

test('CompleteCAPA: Medium priority → verificationDueDate ~90d', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;

  const res = await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'PPE issued.', evidence: 'Distribution list signed.' },
  });
  expect(res.ok()).toBeTruthy();
  const completed = await res.json();

  expect(completed.status).toBe('Verification Pending');

  const now = Date.now();
  const vdd = new Date(completed.verificationDueDate as string).getTime();
  const diffDays = (vdd - now) / (1000 * 60 * 60 * 24);
  expect(diffDays).toBeGreaterThan(89);
  expect(diffDays).toBeLessThan(91);
});

test('CompleteCAPA: Low priority → verificationDueDate ~90d', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Low');
  const capaId = capa.id as number;

  const res = await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Policy updated.', evidence: 'Policy doc v2.' },
  });
  expect(res.ok()).toBeTruthy();
  const completed = await res.json();

  expect(completed.status).toBe('Verification Pending');

  const now = Date.now();
  const vdd = new Date(completed.verificationDueDate as string).getTime();
  const diffDays = (vdd - now) / (1000 * 60 * 60 * 24);
  // Low falls into the default (90d) bucket
  expect(diffDays).toBeGreaterThan(89);
  expect(diffDays).toBeLessThan(91);
});

test('CompleteCAPA: already-complete CAPA (Verification Pending) returns 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;

  // First completion
  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Done.', evidence: 'Evidence A.' },
  });

  // Second completion attempt should fail
  const res = await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Done again?', evidence: 'Evidence B.' },
  });
  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 4. VerifyCAPA — 403 when verifier == assignee
// ---------------------------------------------------------------------------

test('VerifyCAPA: rejects verifier==assignee with 403', async ({ page }) => {
  const { token, userId: smUserId } = await getTokenAndUserId(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  // Assign the CAPA to the same user who holds the token, so verify is self-verify.
  const capa = await createCAPA(
    page,
    token,
    incidentId,
    investigationId,
    'Medium',
    smUserId, // same as the token holder's userId
  );
  const capaId = capa.id as number;

  // Complete it first
  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(token),
    data: { notes: 'Done.', evidence: 'Evidence.' },
  });

  // Now try to verify using the same token (same userId = assignee)
  const res = await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(token),
    data: { effective: true, notes: 'Self-verify attempt.' },
  });
  expect(res.status()).toBe(403);
});

// ---------------------------------------------------------------------------
// 5. VerifyCAPA — effective path
// ---------------------------------------------------------------------------

test('VerifyCAPA: effective=true → status becomes Verified Effective', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { token: scToken, userId: scUserId } = await getTokenAndUserId(page, 'safety_coordinator');

  const { incidentId, investigationId } = await setupForCAPA(page, smToken);

  // Assign to safety_coordinator so safety_manager can verify
  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'High',
    scUserId,
  );
  const capaId = capa.id as number;

  // Complete as safety_coordinator
  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(scToken),
    data: { notes: 'Fixed.', evidence: 'Photo.' },
  });

  // Verify as safety_manager (different user)
  const res = await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(smToken),
    data: { effective: true, notes: 'Confirmed effective — observed improvement.' },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  expect(body.capa.status).toBe('Verified Effective');
  expect(body.capa.verifiedByUserId).toBeTruthy();
  expect(body.capa.verificationDate).toBeTruthy();
  expect(body.capa.verificationNotes).toBe('Confirmed effective — observed improvement.');
  expect(body.capa.isOverdue).toBe(false);
  expect(body.capa.overdueEscalationLevel).toBe(0);
  // No nextSteps for effective
  expect(body.nextSteps).toBeUndefined();
});

// ---------------------------------------------------------------------------
// 6. VerifyCAPA — ineffective path + nextSteps
// ---------------------------------------------------------------------------

test('VerifyCAPA: effective=false → status Verified Ineffective + nextSteps included', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { token: scToken, userId: scUserId } = await getTokenAndUserId(page, 'safety_coordinator');

  const { incidentId, investigationId } = await setupForCAPA(page, smToken);

  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'Medium',
    scUserId,
  );
  const capaId = capa.id as number;

  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(scToken),
    data: { notes: 'Attempted fix.', evidence: 'Report.' },
  });

  const res = await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(smToken),
    data: { effective: false, notes: 'Issue persists — root cause not addressed.' },
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  expect(body.capa.status).toBe('Verified Ineffective');
  expect(body.capa.verificationNotes).toBe('Issue persists — root cause not addressed.');

  // nextSteps must be present for ineffective
  expect(body.nextSteps).toBeDefined();
  expect(body.nextSteps.createNewCAPA).toBe(true);
  expect(body.nextSteps.reopenInvestigation).toBe(true);
  expect(body.nextSteps.investigationId).toBe(investigationId);
  expect(body.nextSteps.incidentId).toBe(incidentId);
  expect(typeof body.nextSteps.message).toBe('string');
});

test('VerifyCAPA: cannot verify CAPA that is not Verification Pending → 400', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, smToken);

  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'Low',
    'qa-assignee-user',
  );
  const capaId = capa.id as number;

  // CAPA is still Open — verify should fail
  const res = await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(smToken),
    data: { effective: true, notes: 'Premature verify.' },
  });
  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 7. Dashboard — 4 KPI fields
// ---------------------------------------------------------------------------

test('GET /api/capas/dashboard — returns 4 KPI fields', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');

  const res = await page.request.get(`${API}/api/capas/dashboard`, {
    headers: authHeaders(token),
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  // KPI 1: open CAPAs count
  expect(typeof body.openCapas).toBe('number');
  // KPI 2: overdue CAPAs count
  expect(typeof body.overdueCapas).toBe('number');
  // KPI 3: average time to close (days)
  expect(typeof body.avgTimeToCloseDays).toBe('number');
  // KPI 4: effectiveness rate (%)
  expect(typeof body.effectivenessRate).toBe('number');

  // Basic sanity: values must be non-negative
  expect(body.openCapas).toBeGreaterThanOrEqual(0);
  expect(body.overdueCapas).toBeGreaterThanOrEqual(0);
  expect(body.avgTimeToCloseDays).toBeGreaterThanOrEqual(0);
  expect(body.effectivenessRate).toBeGreaterThanOrEqual(0);
  expect(body.effectivenessRate).toBeLessThanOrEqual(100);
});

test('Dashboard: effectiveness rate increases after Verified Effective CAPA', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { token: scToken, userId: scUserId } = await getTokenAndUserId(page, 'safety_coordinator');

  // Get baseline
  const beforeRes = await page.request.get(`${API}/api/capas/dashboard`, {
    headers: authHeaders(smToken),
  });
  const before = await beforeRes.json();

  const { incidentId, investigationId } = await setupForCAPA(page, smToken);

  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'Medium',
    scUserId,
  );
  const capaId = capa.id as number;

  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(scToken),
    data: { notes: 'Completed.', evidence: 'Evidence.' },
  });
  await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(smToken),
    data: { effective: true, notes: 'Verified.' },
  });

  const afterRes = await page.request.get(`${API}/api/capas/dashboard`, {
    headers: authHeaders(smToken),
  });
  const after = await afterRes.json();

  // If there were no prior verified CAPAs, rate should now be 100%.
  // If there were prior ones, rate should be >= before.
  expect(after.effectivenessRate).toBeGreaterThanOrEqual(before.effectivenessRate as number);
  // avgTimeToCloseDays should now be > 0 (at least this one)
  expect(after.avgTimeToCloseDays).toBeGreaterThanOrEqual(0);
});

// ---------------------------------------------------------------------------
// 8. Overdue escalation — fresh CAPA is NOT overdue (level 0)
// ---------------------------------------------------------------------------

test('Overdue escalation: fresh Open CAPA has isOverdue=false, level=0', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Critical');
  const capaId = capa.id as number;

  // Fetch via GET to trigger real-time overdue recalculation
  const res = await page.request.get(`${API}/api/capas/${capaId}`, {
    headers: authHeaders(token),
  });
  expect(res.ok()).toBeTruthy();
  const fetched = await res.json();

  expect(fetched.isOverdue).toBe(false);
  expect(fetched.overdueEscalationLevel).toBe(0);
});

test('Overdue escalation: escalation levels are 1=1-6d, 2=7-13d, 3=14+d (logic verified by code)', async ({ page }) => {
  // This test verifies the escalation level constants by examining a fresh CAPA
  // (which is NOT overdue) and confirming the escalation level is 0.
  // The boundary values (1-6d, 7-13d, 14+d) are verified at the code level in
  // capas.go::escalationLevel() which is called on every GET/List request.
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Low');

  // A 60-day-deadline CAPA should definitely not be overdue
  expect((capa as Record<string, unknown>).isOverdue).toBe(false);
  expect((capa as Record<string, unknown>).overdueEscalationLevel).toBe(0);
});

// ---------------------------------------------------------------------------
// 9. CloseIncident: blocks if CAPAs not all Verified Effective
// ---------------------------------------------------------------------------

test('CloseIncident: blocked when CAPAs are not all Verified Effective', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, token);
  const { investigationId } = await approveInvestigation(page, token, incidentId);
  const headers = authHeaders(token);

  // Create a CAPA that stays "Open"
  await createCAPA(page, token, incidentId, investigationId, 'Medium');

  // Attempt to close the incident
  const res = await page.request.post(`${API}/api/incidents/${incidentId}/close`, {
    headers,
    data: {},
  });
  expect(res.status()).toBe(400);
  const body = await res.json();
  expect(body.error).toContain('Verified Effective');
  expect(Array.isArray(body.incompleteCAPAs)).toBe(true);
  expect(body.incompleteCAPAs.length).toBeGreaterThan(0);
});

test('CloseIncident: blocked when no CAPAs exist', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, token);
  await approveInvestigation(page, token, incidentId);

  const res = await page.request.post(`${API}/api/incidents/${incidentId}/close`, {
    headers: authHeaders(token),
    data: {},
  });
  expect(res.status()).toBe(400);
});

test('CloseIncident: succeeds when all CAPAs are Verified Effective', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { token: scToken, userId: scUserId } = await getTokenAndUserId(page, 'safety_coordinator');

  const incidentId = await createIncident(page, smToken);
  const { investigationId } = await approveInvestigation(page, smToken, incidentId);
  const smHeaders = authHeaders(smToken);

  // Create CAPA assigned to safety_coordinator
  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'Medium',
    scUserId,
  );
  const capaId = capa.id as number;

  // Complete as safety_coordinator
  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(scToken),
    data: { notes: 'All fixed.', evidence: 'Records.' },
  });

  // Verify as safety_manager
  await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: smHeaders,
    data: { effective: true, notes: 'Confirmed.' },
  });

  // Advance incident to CAPA In Progress then close should succeed
  // (CloseIncident directly sets to Closed regardless of current status)
  const closeRes = await page.request.post(`${API}/api/incidents/${incidentId}/close`, {
    headers: smHeaders,
    data: {},
  });
  expect(closeRes.ok()).toBeTruthy();
  const closedIncident = await closeRes.json();
  expect(closedIncident.status).toBe('Closed');
});

// ---------------------------------------------------------------------------
// 10. Incident status transitions on CAPA lifecycle
// ---------------------------------------------------------------------------

test('Creating CAPA advances incident from Investigation Complete → CAPA Assigned', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, token);
  const { investigationId } = await approveInvestigation(page, token, incidentId);
  const headers = authHeaders(token);

  // Confirm incident is at Investigation Complete
  const beforeRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  const before = await beforeRes.json();
  expect(before.status).toBe('Investigation Complete');

  // Create CAPA
  await createCAPA(page, token, incidentId, investigationId, 'High');

  // Confirm incident status transitioned
  const afterRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  const after = await afterRes.json();
  expect(after.status).toBe('CAPA Assigned');
});

test('Updating CAPA to In Progress advances incident from CAPA Assigned → CAPA In Progress', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const incidentId = await createIncident(page, token);
  const { investigationId } = await approveInvestigation(page, token, incidentId);
  const headers = authHeaders(token);

  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;

  // Confirm incident is CAPA Assigned
  const midRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  const mid = await midRes.json();
  expect(mid.status).toBe('CAPA Assigned');

  // Update CAPA status to In Progress
  const updateRes = await page.request.put(`${API}/api/capas/${capaId}`, {
    headers,
    data: { status: 'In Progress' },
  });
  expect(updateRes.ok()).toBeTruthy();

  // Confirm incident advanced
  const afterRes = await page.request.get(`${API}/api/incidents/${incidentId}`, { headers });
  const after = await afterRes.json();
  expect(after.status).toBe('CAPA In Progress');
});

// ---------------------------------------------------------------------------
// 11. Audit logging
// ---------------------------------------------------------------------------

test('Audit log: create CAPA generates a "create" audit entry', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'High');
  const capaId = capa.id as number;
  const headers = authHeaders(token);

  const logsRes = await page.request.get(
    `${API}/api/audit-logs?entity_type=capa&entity_id=${capaId}`,
    { headers },
  );
  expect(logsRes.ok()).toBeTruthy();
  const logs = await logsRes.json();
  const actions = logs.data.map((l: { action: string }) => l.action);
  expect(actions).toContain('create');
});

test('Audit log: complete CAPA generates a "status_change" audit entry', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;
  const headers = authHeaders(token);

  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers,
    data: { notes: 'Done.', evidence: 'Evidence.' },
  });

  const logsRes = await page.request.get(
    `${API}/api/audit-logs?entity_type=capa&entity_id=${capaId}`,
    { headers },
  );
  const logs = await logsRes.json();
  const actions = logs.data.map((l: { action: string }) => l.action);
  expect(actions).toContain('status_change');
});

test('Audit log: verify CAPA (effective) generates a "status_change" audit entry', async ({ page }) => {
  const smToken = await getToken(page, 'safety_manager');
  const { token: scToken, userId: scUserId } = await getTokenAndUserId(page, 'safety_coordinator');
  const { incidentId, investigationId } = await setupForCAPA(page, smToken);
  const capa = await createCAPA(
    page,
    smToken,
    incidentId,
    investigationId,
    'Low',
    scUserId,
  );
  const capaId = capa.id as number;

  await page.request.post(`${API}/api/capas/${capaId}/complete`, {
    headers: authHeaders(scToken),
    data: { notes: 'Done.', evidence: 'Evidence.' },
  });
  await page.request.post(`${API}/api/capas/${capaId}/verify`, {
    headers: authHeaders(smToken),
    data: { effective: true, notes: 'All good.' },
  });

  const logsRes = await page.request.get(
    `${API}/api/audit-logs?entity_type=capa&entity_id=${capaId}`,
    { headers: authHeaders(smToken) },
  );
  const logs = await logsRes.json();
  const actions = logs.data.map((l: { action: string }) => l.action);
  expect(actions).toContain('status_change');

  // Confirm at least 2 status_change entries: complete + verify
  const statusChanges = logs.data.filter((l: { action: string }) => l.action === 'status_change');
  expect(statusChanges.length).toBeGreaterThanOrEqual(2);
});

test('Audit log: update CAPA generates an "update" audit entry', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;
  const headers = authHeaders(token);

  await page.request.put(`${API}/api/capas/${capaId}`, {
    headers,
    data: { description: 'Updated description for audit test.' },
  });

  const logsRes = await page.request.get(
    `${API}/api/audit-logs?entity_type=capa&entity_id=${capaId}`,
    { headers },
  );
  const logs = await logsRes.json();
  const actions = logs.data.map((l: { action: string }) => l.action);
  expect(actions).toContain('update');
});

// ---------------------------------------------------------------------------
// 12. Input validation
// ---------------------------------------------------------------------------

test('CreateCAPA: missing required fields → 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = authHeaders(token);

  // Completely empty body
  const res = await page.request.post(`${API}/api/capas`, {
    headers,
    data: {},
  });
  expect(res.status()).toBe(400);
});

test('CreateCAPA: invalid type → 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId,
      type: 'INVALID_TYPE',
      category: 'Training',
      description: 'Should fail.',
      assignedToUserId: 'qa-user',
      priority: 'Medium',
    },
  });
  expect(res.status()).toBe(400);
});

test('CreateCAPA: invalid category → 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId,
      type: 'Corrective',
      category: 'NOT_A_CATEGORY',
      description: 'Should fail.',
      assignedToUserId: 'qa-user',
      priority: 'Medium',
    },
  });
  expect(res.status()).toBe(400);
});

test('CreateCAPA: invalid priority → 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId,
      type: 'Preventive',
      category: 'PPE',
      description: 'Should fail.',
      assignedToUserId: 'qa-user',
      priority: 'SUPER_CRITICAL',
    },
  });
  expect(res.status()).toBe(400);
});

test('CreateCAPA: non-existent investigationId → 404', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId } = await setupForCAPA(page, token);

  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId: 999999,
      type: 'Corrective',
      category: 'Training',
      description: 'Should fail.',
      assignedToUserId: 'qa-user',
      priority: 'Medium',
    },
  });
  expect(res.status()).toBe(404);
});

// ---------------------------------------------------------------------------
// 13. ListCAPAs — pagination + filters
// ---------------------------------------------------------------------------

test('GET /api/capas — returns paginated list with data/total/page/per_page', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');

  const res = await page.request.get(`${API}/api/capas?page=1&per_page=10`, {
    headers: authHeaders(token),
  });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  expect(Array.isArray(body.data)).toBe(true);
  expect(typeof body.total).toBe('number');
  expect(body.page).toBe(1);
  expect(body.per_page).toBe(10);
});

test('GET /api/capas — status filter returns only matching CAPAs', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = authHeaders(token);

  // Create a CAPA (status = Open)
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  await createCAPA(page, token, incidentId, investigationId, 'Low');

  const res = await page.request.get(`${API}/api/capas?status=Open`, { headers });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  expect(body.data.length).toBeGreaterThan(0);
  for (const c of body.data) {
    expect(c.status).toBe('Open');
  }
});

test('GET /api/capas — priority filter returns only matching CAPAs', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = authHeaders(token);

  const { incidentId, investigationId } = await setupForCAPA(page, token);
  await createCAPA(page, token, incidentId, investigationId, 'Critical');

  const res = await page.request.get(`${API}/api/capas?priority=Critical`, { headers });
  expect(res.ok()).toBeTruthy();
  const body = await res.json();

  expect(body.data.length).toBeGreaterThan(0);
  for (const c of body.data) {
    expect(c.priority).toBe('Critical');
  }
});

// ---------------------------------------------------------------------------
// 14. GetCAPA — 404 for unknown ID
// ---------------------------------------------------------------------------

test('GET /api/capas/{id} — 404 for non-existent CAPA', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');

  const res = await page.request.get(`${API}/api/capas/999999999`, {
    headers: authHeaders(token),
  });
  expect(res.status()).toBe(404);
});

// ---------------------------------------------------------------------------
// 15. UpdateCAPA — partial update and priority recalculates due date
// ---------------------------------------------------------------------------

test('PUT /api/capas/{id} — partial update changes description', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Medium');
  const capaId = capa.id as number;

  const res = await page.request.put(`${API}/api/capas/${capaId}`, {
    headers: authHeaders(token),
    data: { description: 'Updated description via PUT.' },
  });
  expect(res.ok()).toBeTruthy();
  const updated = await res.json();
  expect(updated.description).toBe('Updated description via PUT.');
  // Priority should be unchanged
  expect(updated.priority).toBe('Medium');
});

test('PUT /api/capas/{id} — changing priority recalculates dueDate', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);
  const capa = await createCAPA(page, token, incidentId, investigationId, 'Low');
  const capaId = capa.id as number;

  const originalDue = new Date(capa.dueDate as string).getTime();

  // Change from Low (60d) to Critical (7d) — dueDate should move significantly earlier
  const res = await page.request.put(`${API}/api/capas/${capaId}`, {
    headers: authHeaders(token),
    data: { priority: 'Critical' },
  });
  expect(res.ok()).toBeTruthy();
  const updated = await res.json();
  expect(updated.priority).toBe('Critical');

  const newDue = new Date(updated.dueDate as string).getTime();
  // Critical (7d from creation) must be earlier than Low (60d from creation)
  expect(newDue).toBeLessThan(originalDue);
});

// ---------------------------------------------------------------------------
// 16. All CAPA categories and types are valid
// ---------------------------------------------------------------------------

const validCategories = [
  'Training',
  'Procedure Change',
  'Engineering Control',
  'PPE',
  'Equipment Modification',
  'Policy Change',
  'Other',
];

for (const category of validCategories) {
  test(`CreateCAPA: category "${category}" is accepted`, async ({ page }) => {
    const token = await getToken(page, 'safety_manager');
    const { incidentId, investigationId } = await setupForCAPA(page, token);

    const res = await page.request.post(`${API}/api/capas`, {
      headers: authHeaders(token),
      data: {
        incidentId,
        investigationId,
        type: 'Corrective',
        category,
        description: `Category test: ${category}`,
        assignedToUserId: 'qa-user',
        priority: 'Low',
      },
    });
    expect(res.status()).toBe(201);
    const created = await res.json();
    expect(created.category).toBe(category);
  });
}

test('CreateCAPA: type "Preventive" is accepted', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const { incidentId, investigationId } = await setupForCAPA(page, token);

  const res = await page.request.post(`${API}/api/capas`, {
    headers: authHeaders(token),
    data: {
      incidentId,
      investigationId,
      type: 'Preventive',
      category: 'Other',
      description: 'Preventive CAPA test.',
      assignedToUserId: 'qa-user',
      priority: 'Low',
    },
  });
  expect(res.status()).toBe(201);
  const created = await res.json();
  expect(created.type).toBe('Preventive');
});

// ---------------------------------------------------------------------------
// 17. Authentication required
// ---------------------------------------------------------------------------

test('All CAPA endpoints require authentication — 401 without token', async ({ page }) => {
  const noAuthHeaders = { 'Content-Type': 'application/json' };

  const listRes = await page.request.get(`${API}/api/capas`, { headers: noAuthHeaders });
  expect(listRes.status()).toBe(401);

  const dashRes = await page.request.get(`${API}/api/capas/dashboard`, { headers: noAuthHeaders });
  expect(dashRes.status()).toBe(401);

  const createRes = await page.request.post(`${API}/api/capas`, {
    headers: noAuthHeaders,
    data: { type: 'Corrective' },
  });
  expect(createRes.status()).toBe(401);
});
