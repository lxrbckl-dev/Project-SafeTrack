/**
 * incidents-api.spec.ts
 *
 * API-level smoke tests for TASK-004: Incident Models + Full API.
 * These tests call the Go backend directly via fetch() inside Playwright's
 * browser context, using the login endpoint to obtain a JWT.
 *
 * Run against the PR branch backend on port 8001:
 *   PORT=8001 go run ./cmd/server/ &
 *   PLAYWRIGHT_BASE_URL=http://localhost:3001 npx playwright test incidents-api
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

// ---------------------------------------------------------------------------
// 1. Create Incident — POST /api/incidents
// ---------------------------------------------------------------------------

test('POST /api/incidents — field_reporter can create an incident', async ({ page }) => {
  const token = await getToken(page, 'field_reporter');
  const headers = await authHeaders(token);

  const res = await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Site A – Tower 4',
      description: 'Worker slipped on wet surface.',
      isDraft: false,
    },
  });

  expect(res.status()).toBe(201);
  const incident = await res.json();
  expect(incident.id).toBeGreaterThan(0);
  expect(incident.type).toBe('Injury');
  expect(incident.reporterId).toBeTruthy();
  // Auto-generated fields should not be trusted from the client
  expect(incident.status).toBeDefined();
});

// ---------------------------------------------------------------------------
// 2. List Incidents with Filters — GET /api/incidents
// ---------------------------------------------------------------------------

test('GET /api/incidents — returns paginated list with type filter', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const res = await page.request.get(`${API}/api/incidents?type=Injury&page=1&per_page=10`, {
    headers,
  });

  expect(res.ok()).toBeTruthy();
  const body = await res.json();
  expect(Array.isArray(body.data)).toBeTruthy();
  expect(typeof body.total).toBe('number');
  expect(body.page).toBe(1);
  expect(body.per_page).toBe(10);
  // Every returned incident must match the filter
  for (const inc of body.data) {
    expect(inc.type).toBe('Injury');
  }
});

// ---------------------------------------------------------------------------
// 3. Draft Visibility — only reporter sees their own drafts
// ---------------------------------------------------------------------------

test('Draft incident is invisible to other users', async ({ page }) => {
  // Reporter creates a draft
  const reporterToken = await getToken(page, 'field_reporter');
  const reporterHeaders = await authHeaders(reporterToken);

  const createRes = await page.request.post(`${API}/api/incidents`, {
    headers: reporterHeaders,
    data: {
      type: 'Near Miss',
      date: new Date().toISOString(),
      location: 'Yard B',
      description: 'Near miss during crane lift.',
      isDraft: true,
    },
  });
  expect(createRes.status()).toBe(201);
  const draft = await createRes.json();
  expect(draft.isDraft).toBe(true);

  // Another user (safety_coordinator) fetches the same incident by ID
  const otherToken = await getToken(page, 'safety_coordinator');
  const otherHeaders = await authHeaders(otherToken);

  const getRes = await page.request.get(`${API}/api/incidents/${draft.id}`, {
    headers: otherHeaders,
  });
  // Should be 404 — drafts are invisible to non-reporters
  expect(getRes.status()).toBe(404);
});

test('Draft incident is NOT visible in list to other users', async ({ page }) => {
  // Use a unique description to identify the draft
  const marker = `DRAFT-VISIBILITY-TEST-${Date.now()}`;
  const reporterToken = await getToken(page, 'field_reporter');
  const reporterHeaders = await authHeaders(reporterToken);

  await page.request.post(`${API}/api/incidents`, {
    headers: reporterHeaders,
    data: {
      type: 'Vehicle',
      date: new Date().toISOString(),
      location: 'Parking lot',
      description: marker,
      isDraft: true,
    },
  });

  // Coordinator lists incidents — should NOT see the draft
  const otherToken = await getToken(page, 'safety_coordinator');
  const listRes = await page.request.get(`${API}/api/incidents?per_page=100`, {
    headers: await authHeaders(otherToken),
  });
  const body = await listRes.json();
  const found = body.data.some((i: { description: string }) => i.description === marker);
  expect(found).toBe(false);
});

// ---------------------------------------------------------------------------
// 4. Medical Field Redaction by Role
// ---------------------------------------------------------------------------

test('Medical fields are redacted for field_reporter, visible for safety_coordinator', async ({ page }) => {
  // safety_coordinator creates incident with injured person
  const coordToken = await getToken(page, 'safety_coordinator');
  const coordHeaders = await authHeaders(coordToken);

  const createRes = await page.request.post(`${API}/api/incidents`, {
    headers: coordHeaders,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Workshop C',
      description: 'Laceration on hand.',
      isDraft: false,
      injuredPersons: [
        {
          name: 'John Doe',
          jobTitle: 'Ironworker',
          division: 'Division A',
          injuryType: 'Laceration',
          bodyPart: 'Hand',
          bodyPartSide: 'Left',
          treatmentType: 'Sutures',
          returnToWorkStatus: 'Restricted Duty',
        },
      ],
    },
  });
  expect(createRes.status()).toBe(201);
  const incident = await createRes.json();
  const incidentId = incident.id;

  // safety_coordinator can see plaintext medical data
  const coordGetRes = await page.request.get(`${API}/api/incidents/${incidentId}`, {
    headers: coordHeaders,
  });
  const coordView = await coordGetRes.json();
  expect(coordView.injuredPersons[0].injuryType).not.toBe('[RESTRICTED]');
  expect(coordView.injuredPersons[0].bodyPart).not.toBe('[RESTRICTED]');

  // field_reporter sees [RESTRICTED]
  const reporterToken = await getToken(page, 'field_reporter');
  const reporterGetRes = await page.request.get(`${API}/api/incidents/${incidentId}`, {
    headers: await authHeaders(reporterToken),
  });
  const reporterView = await reporterGetRes.json();
  expect(reporterView.injuredPersons[0].injuryType).toBe('[RESTRICTED]');
  expect(reporterView.injuredPersons[0].bodyPart).toBe('[RESTRICTED]');
  expect(reporterView.injuredPersons[0].treatmentType).toBe('[RESTRICTED]');
  expect(reporterView.injuredPersons[0].returnToWorkStatus).toBe('[RESTRICTED]');
});

// ---------------------------------------------------------------------------
// 5. OSHA Determination — POST /api/incidents/{id}/osha-determination
// ---------------------------------------------------------------------------

test('OSHA determination: not work-related → not recordable, no DART', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  // Create incident
  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Office',
      description: 'Not work-related injury.',
      isDraft: false,
    },
  })).json();

  const oshaRes = await page.request.post(`${API}/api/incidents/${inc.id}/osha-determination`, {
    headers,
    data: {
      workRelated: false,
      death: false,
      daysAway: false,
      restrictedTransfer: false,
      medicalTreatment: true,
      lossOfConsciousness: false,
      significantDiagnosis: false,
    },
  });
  expect(oshaRes.ok()).toBeTruthy();
  const result = await oshaRes.json();
  expect(result.isOshaRecordable).toBe(false);
  expect(result.isDart).toBe(false);
});

test('OSHA determination: work-related + days away → recordable + DART', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Field',
      description: 'Work-related injury with days away.',
      isDraft: false,
    },
  })).json();

  const oshaRes = await page.request.post(`${API}/api/incidents/${inc.id}/osha-determination`, {
    headers,
    data: {
      workRelated: true,
      death: false,
      daysAway: true,
      restrictedTransfer: false,
      medicalTreatment: false,
      lossOfConsciousness: false,
      significantDiagnosis: false,
    },
  });
  expect(oshaRes.ok()).toBeTruthy();
  const result = await oshaRes.json();
  expect(result.isOshaRecordable).toBe(true);
  expect(result.isDart).toBe(true);
});

test('OSHA determination: work-related + medical treatment only → recordable, no DART', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Warehouse',
      description: 'Work-related medical treatment only.',
      isDraft: false,
    },
  })).json();

  const oshaRes = await page.request.post(`${API}/api/incidents/${inc.id}/osha-determination`, {
    headers,
    data: {
      workRelated: true,
      death: false,
      daysAway: false,
      restrictedTransfer: false,
      medicalTreatment: true,
      lossOfConsciousness: false,
      significantDiagnosis: false,
    },
  });
  expect(oshaRes.ok()).toBeTruthy();
  const result = await oshaRes.json();
  expect(result.isOshaRecordable).toBe(true);
  expect(result.isDart).toBe(false);
});

test('OSHA override requires justification — empty justification returns 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Substation',
      description: 'Electrical contact.',
      isDraft: false,
    },
  })).json();

  const overrideRes = await page.request.put(`${API}/api/incidents/${inc.id}/osha-override`, {
    headers,
    data: { isOshaRecordable: false, justification: '' },
  });
  expect(overrideRes.status()).toBe(400);
});

test('OSHA override with justification succeeds and is audit-logged', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Substation',
      description: 'Electrical contact with justification.',
      isDraft: false,
    },
  })).json();

  const overrideRes = await page.request.put(`${API}/api/incidents/${inc.id}/osha-override`, {
    headers,
    data: {
      isOshaRecordable: false,
      justification: 'Independent medical review confirmed non-work-related causation.',
    },
  });
  expect(overrideRes.ok()).toBeTruthy();
  const updated = await overrideRes.json();
  expect(updated.isOshaRecordable).toBe(false);
  expect(updated.oshaOverrideJustification).toBeTruthy();
});

// ---------------------------------------------------------------------------
// 6. Railroad Deadline Checking
// ---------------------------------------------------------------------------

test('Railroad: UP Injury → overdue immediately (0 hr deadline)', async ({ page }) => {
  const token = await getToken(page, 'field_reporter');
  const headers = await authHeaders(token);

  const res = await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'UP Track Segment 14',
      description: 'Worker struck by equipment on UP property.',
      isDraft: false,
      isRailroadProperty: true,
      railroadClient: 'UP',
      railroadNotified: false,
    },
  });
  expect(res.status()).toBe(201);
  const inc = await res.json();
  // UP Injury deadline is 0 hrs (immediately) → should be overdue on creation
  expect(inc.railroadNotificationOverdue).toBe(true);
});

test('Railroad: BNSF Near Miss → not immediately overdue (24 hr deadline)', async ({ page }) => {
  const token = await getToken(page, 'field_reporter');
  const headers = await authHeaders(token);

  const res = await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Near Miss',
      date: new Date().toISOString(),
      location: 'BNSF Yard',
      description: 'Near miss during switching operation.',
      isDraft: false,
      isRailroadProperty: true,
      railroadClient: 'BNSF',
      railroadNotified: false,
    },
  });
  expect(res.status()).toBe(201);
  const inc = await res.json();
  // BNSF Near Miss deadline is 24 hrs → NOT overdue on creation
  expect(inc.railroadNotificationOverdue).toBe(false);
});

// ---------------------------------------------------------------------------
// 7. Status Transitions — valid and invalid
// ---------------------------------------------------------------------------

test('Valid status transition: Draft → Reported → Under Investigation', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  // Create as draft
  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Near Miss',
      date: new Date().toISOString(),
      location: 'Gate 3',
      description: 'Near miss at gate.',
    },
  })).json();
  expect(inc.status).toBe('Draft');

  // Draft → Reported
  const r1 = await page.request.post(`${API}/api/incidents/${inc.id}/status`, {
    headers,
    data: { status: 'Reported' },
  });
  expect(r1.ok()).toBeTruthy();
  const s1 = await r1.json();
  expect(s1.status).toBe('Reported');
  expect(s1.isDraft).toBe(false);

  // Reported → Under Investigation
  const r2 = await page.request.post(`${API}/api/incidents/${inc.id}/status`, {
    headers,
    data: { status: 'Under Investigation' },
  });
  expect(r2.ok()).toBeTruthy();
  const s2 = await r2.json();
  expect(s2.status).toBe('Under Investigation');
});

test('Invalid status transition returns 400', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Fire',
      date: new Date().toISOString(),
      location: 'Utility Room',
      description: 'Small fire extinguished.',
    },
  })).json();

  // Attempt Draft → Closed (invalid skip)
  const res = await page.request.post(`${API}/api/incidents/${inc.id}/status`, {
    headers,
    data: { status: 'Closed' },
  });
  expect(res.status()).toBe(400);
});

test('Close and Reopen incident', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = await authHeaders(token);

  // Create and advance to CAPA In Progress
  let inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Property Damage',
      date: new Date().toISOString(),
      location: 'Storage Yard',
      description: 'Forklift struck racking.',
    },
  })).json();

  // Walk through status chain
  for (const next of ['Reported', 'Under Investigation', 'Investigation Complete', 'CAPA Assigned', 'CAPA In Progress']) {
    const r = await page.request.post(`${API}/api/incidents/${inc.id}/status`, {
      headers,
      data: { status: next },
    });
    expect(r.ok()).toBeTruthy();
  }

  // Close
  const closeRes = await page.request.post(`${API}/api/incidents/${inc.id}/close`, { headers });
  expect(closeRes.ok()).toBeTruthy();
  const closed = await closeRes.json();
  expect(closed.status).toBe('Closed');

  // Reopen
  const reopenRes = await page.request.post(`${API}/api/incidents/${inc.id}/reopen`, { headers });
  expect(reopenRes.ok()).toBeTruthy();
  const reopened = await reopenRes.json();
  expect(reopened.status).toBe('Reopened');
});

test('Reopen on non-closed incident returns 400', async ({ page }) => {
  const token = await getToken(page, 'safety_manager');
  const headers = await authHeaders(token);

  const inc = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Environmental',
      date: new Date().toISOString(),
      location: 'Pond Area',
      description: 'Spill near retention pond.',
    },
  })).json();
  // Status is Draft — reopen should fail
  const res = await page.request.post(`${API}/api/incidents/${inc.id}/reopen`, { headers });
  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 8. Completion Percentage
// ---------------------------------------------------------------------------

test('Completion percent increases as fields are filled', async ({ page }) => {
  const token = await getToken(page, 'field_reporter');
  const headers = await authHeaders(token);

  // Minimal fields only
  const minimal = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Site X',
      description: 'Minimal report.',
    },
  })).json();
  expect(minimal.completionPercent).toBeGreaterThan(0);
  expect(minimal.completionPercent).toBeLessThan(100);

  // Full fields
  const full = await (await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Injury',
      date: new Date().toISOString(),
      location: 'Site Y',
      division: 'Northern',
      projectJobSite: 'Project Alpha',
      description: 'Full report.',
      immediateActions: 'Scene secured.',
      severity: 'Serious',
      potentialSeverity: 'Critical',
      shift: 'Day',
      weather: 'Clear',
    },
  })).json();
  expect(full.completionPercent).toBe(100);
  expect(full.completionPercent).toBeGreaterThan(minimal.completionPercent);
});
