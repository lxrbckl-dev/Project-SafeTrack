/**
 * incident-links.spec.ts
 *
 * API-level smoke tests for TASK-011: Manual Recurrence Linking.
 * These tests call the Go backend directly via Playwright's request context,
 * using the login endpoint to obtain a JWT.
 *
 * Run against the PR branch backend on port 8001:
 *   PORT=8001 go run ./cmd/server/ &
 *   PLAYWRIGHT_BASE_URL=http://localhost:3001 npx playwright test incident-links
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

/** Create a published incident and return its id. */
async function createIncident(
  page: import('@playwright/test').Page,
  token: string,
  overrides: Record<string, unknown> = {},
): Promise<number> {
  const headers = await authHeaders(token);
  const res = await page.request.post(`${API}/api/incidents`, {
    headers,
    data: {
      type: 'Near Miss',
      date: new Date().toISOString(),
      location: 'Test Site',
      description: `Test incident ${Date.now()}`,
      isDraft: false,
      ...overrides,
    },
  });
  expect(res.status()).toBe(201);
  const inc = await res.json();
  return inc.id as number;
}

// ---------------------------------------------------------------------------
// 1. Create link — Safety Coordinator role
// ---------------------------------------------------------------------------

test('POST /api/incident-links — Safety Coordinator can create a link', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const id1 = await createIncident(page, token);
  const id2 = await createIncident(page, token);

  const res = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: {
      incidentId1: id1,
      incidentId2: id2,
      similarityType: 'Same Location',
      notes: 'Both occurred at the same tower.',
    },
  });

  expect(res.status()).toBe(201);
  const link = await res.json();
  expect(link.id).toBeGreaterThan(0);
  expect(link.similarityType).toBe('Same Location');
});

// ---------------------------------------------------------------------------
// 2. Create link rejected for Field Reporter (403)
// ---------------------------------------------------------------------------

test('POST /api/incident-links — Field Reporter receives 403', async ({ page }) => {
  const coordToken = await getToken(page, 'safety_coordinator');
  const reporterToken = await getToken(page, 'field_reporter');

  const id1 = await createIncident(page, coordToken);
  const id2 = await createIncident(page, coordToken);

  const res = await page.request.post(`${API}/api/incident-links`, {
    headers: await authHeaders(reporterToken),
    data: {
      incidentId1: id1,
      incidentId2: id2,
      similarityType: 'Same Type',
    },
  });

  expect(res.status()).toBe(403);
});

// ---------------------------------------------------------------------------
// 3. All 5 similarity types work
// ---------------------------------------------------------------------------

const SIMILARITY_TYPES = [
  'Same Location',
  'Same Type',
  'Same Root Cause',
  'Same Equipment',
  'Same Person',
];

for (const simType of SIMILARITY_TYPES) {
  test(`POST /api/incident-links — similarityType "${simType}" is accepted`, async ({ page }) => {
    const token = await getToken(page, 'safety_coordinator');
    const headers = await authHeaders(token);

    const id1 = await createIncident(page, token);
    const id2 = await createIncident(page, token);

    const res = await page.request.post(`${API}/api/incident-links`, {
      headers,
      data: { incidentId1: id1, incidentId2: id2, similarityType: simType },
    });

    expect(res.status()).toBe(201);
    const link = await res.json();
    expect(link.similarityType).toBe(simType);
  });
}

// ---------------------------------------------------------------------------
// 4. Get links for an incident
// ---------------------------------------------------------------------------

test('GET /api/incidents/{id}/links — returns links with enriched incident summaries', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const id1 = await createIncident(page, token);
  const id2 = await createIncident(page, token);
  const id3 = await createIncident(page, token);

  // Create two links involving id1
  await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id2, similarityType: 'Same Type' },
  });
  await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id3, similarityType: 'Same Location' },
  });

  const res = await page.request.get(`${API}/api/incidents/${id1}/links`, { headers });
  expect(res.ok()).toBeTruthy();
  const links = await res.json();

  expect(Array.isArray(links)).toBeTruthy();
  expect(links.length).toBeGreaterThanOrEqual(2);

  // Each item should have a linkedIncident summary
  for (const item of links) {
    expect(item.linkedIncident).toBeDefined();
    expect(item.linkedIncident.id).toBeGreaterThan(0);
    expect(typeof item.linkedIncident.type).toBe('string');
    expect(typeof item.linkedIncident.location).toBe('string');
  }
});

// ---------------------------------------------------------------------------
// 5. Delete link — Safety Coordinator
// ---------------------------------------------------------------------------

test('DELETE /api/incident-links/{id} — Safety Coordinator can delete a link', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const id1 = await createIncident(page, token);
  const id2 = await createIncident(page, token);

  const createRes = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id2, similarityType: 'Same Equipment' },
  });
  expect(createRes.status()).toBe(201);
  const link = await createRes.json();

  const deleteRes = await page.request.delete(`${API}/api/incident-links/${link.id}`, { headers });
  expect(deleteRes.status()).toBe(204);

  // Confirm the link is gone
  const linksRes = await page.request.get(`${API}/api/incidents/${id1}/links`, { headers });
  const remaining = await linksRes.json();
  const stillExists = remaining.some((l: { id: number }) => l.id === link.id);
  expect(stillExists).toBe(false);
});

// ---------------------------------------------------------------------------
// 6. Delete rejected for non-Safety Coordinator
// ---------------------------------------------------------------------------

test('DELETE /api/incident-links/{id} — Field Reporter receives 403', async ({ page }) => {
  const coordToken = await getToken(page, 'safety_coordinator');
  const reporterToken = await getToken(page, 'field_reporter');

  const id1 = await createIncident(page, coordToken);
  const id2 = await createIncident(page, coordToken);

  const createRes = await page.request.post(`${API}/api/incident-links`, {
    headers: await authHeaders(coordToken),
    data: { incidentId1: id1, incidentId2: id2, similarityType: 'Same Person' },
  });
  expect(createRes.status()).toBe(201);
  const link = await createRes.json();

  const deleteRes = await page.request.delete(`${API}/api/incident-links/${link.id}`, {
    headers: await authHeaders(reporterToken),
  });
  expect(deleteRes.status()).toBe(403);
});

// ---------------------------------------------------------------------------
// 7. Cluster endpoint returns grouped incidents
// ---------------------------------------------------------------------------

test('GET /api/incident-clusters — returns clusters with incidents and commonThreads', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  // Create a cluster of 3 incidents
  const idA = await createIncident(page, token);
  const idB = await createIncident(page, token);
  const idC = await createIncident(page, token);

  await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: idA, incidentId2: idB, similarityType: 'Same Root Cause' },
  });
  await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: idB, incidentId2: idC, similarityType: 'Same Root Cause' },
  });

  const res = await page.request.get(`${API}/api/incident-clusters`, { headers });
  expect(res.ok()).toBeTruthy();
  const clusters = await res.json();

  expect(Array.isArray(clusters)).toBeTruthy();

  // Find the cluster that contains our incidents
  const ourCluster = clusters.find(
    (c: { incidents: { id: number }[] }) =>
      c.incidents.some((i) => i.id === idA || i.id === idB || i.id === idC),
  );
  expect(ourCluster).toBeDefined();
  expect(ourCluster.incidents.length).toBeGreaterThanOrEqual(3);
  expect(Array.isArray(ourCluster.commonThreads)).toBeTruthy();
  expect(ourCluster.commonThreads.length).toBeGreaterThan(0);
  expect(ourCluster.commonThreads[0].similarityType).toBeDefined();
  expect(ourCluster.commonThreads[0].count).toBeGreaterThan(0);
});

// ---------------------------------------------------------------------------
// 8. Self-link rejected
// ---------------------------------------------------------------------------

test('POST /api/incident-links — self-link returns 400', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const id1 = await createIncident(page, token);

  const res = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id1, similarityType: 'Same Location' },
  });

  expect(res.status()).toBe(400);
});

// ---------------------------------------------------------------------------
// 9. Duplicate link rejected
// ---------------------------------------------------------------------------

test('POST /api/incident-links — duplicate link returns error', async ({ page }) => {
  const token = await getToken(page, 'safety_coordinator');
  const headers = await authHeaders(token);

  const id1 = await createIncident(page, token);
  const id2 = await createIncident(page, token);

  // First link succeeds
  const first = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id2, similarityType: 'Same Type' },
  });
  expect(first.status()).toBe(201);

  // Exact duplicate should fail (unique constraint on normalised pair)
  const second = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id1, incidentId2: id2, similarityType: 'Same Type' },
  });
  expect(second.status()).toBeGreaterThanOrEqual(400);

  // Reversed order (B,A) should also fail due to normalisation
  const reversed = await page.request.post(`${API}/api/incident-links`, {
    headers,
    data: { incidentId1: id2, incidentId2: id1, similarityType: 'Same Type' },
  });
  expect(reversed.status()).toBeGreaterThanOrEqual(400);
});
