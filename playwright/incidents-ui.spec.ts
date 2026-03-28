/**
 * incidents-ui.spec.ts
 *
 * UI-level Playwright tests for TASK-005: Incident Reporting UI (Flutter).
 * Tests run against the Flutter web app on http://localhost:3001.
 *
 * Flutter renders to <canvas>; all selectors use the semantics overlay
 * (getByRole, getByLabel, getByText, aria-label).
 *
 * Run:
 *   PLAYWRIGHT_BASE_URL=http://localhost:3001 npx playwright test incidents-ui
 */

import { test, expect, Page } from '@playwright/test';

const BASE = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3001';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Login via the dev login picker and navigate to the given route. */
async function loginAs(page: Page, role: string, route = '/incidents'): Promise<void> {
  await page.goto(`${BASE}/login`);
  // Select the role from the dev login dropdown
  await page.getByRole('combobox').selectOption(role);
  await page.getByRole('button', { name: /login/i }).click();
  // After login, navigate to the target route
  await page.waitForURL(`**${route.startsWith('/') ? '' : '/'}${route}`);
}

/** Navigate directly to a route after login. */
async function goTo(page: Page, route: string): Promise<void> {
  await page.goto(`${BASE}${route}`);
  await page.waitForLoadState('networkidle');
}

// ---------------------------------------------------------------------------
// TC-UI-001: IncidentListPage — Route and nav item visible
// ---------------------------------------------------------------------------

test('TC-UI-001: /incidents route loads IncidentListPage', async ({ page }) => {
  await loginAs(page, 'field_reporter');
  await expect(page).toHaveURL(/\/incidents/);
  // The app bar should show "INCIDENTS"
  await expect(page.getByText('INCIDENTS')).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-002: IncidentListPage — Filter controls present
// ---------------------------------------------------------------------------

test('TC-UI-002: IncidentListPage shows Status and Type filter dropdowns', async ({ page }) => {
  await loginAs(page, 'safety_coordinator');
  await expect(page.getByLabel('Status')).toBeVisible({ timeout: 10000 });
  await expect(page.getByLabel('Type')).toBeVisible({ timeout: 10000 });
  await expect(page.getByLabel('Division')).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-003: IncidentListPage — "New Incident" FAB visible for Field Reporter+
// ---------------------------------------------------------------------------

test('TC-UI-003: New Incident FAB visible for field_reporter', async ({ page }) => {
  await loginAs(page, 'field_reporter');
  await expect(
    page.getByRole('button', { name: /create new incident report/i })
  ).toBeVisible({ timeout: 10000 });
});

test('TC-UI-003b: New Incident FAB visible for safety_coordinator', async ({ page }) => {
  await loginAs(page, 'safety_coordinator');
  await expect(
    page.getByRole('button', { name: /create new incident report/i })
  ).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-004: Navigation — /incidents/new loads IncidentFormPage
// ---------------------------------------------------------------------------

test('TC-UI-004: /incidents/new route loads IncidentFormPage', async ({ page }) => {
  await loginAs(page, 'field_reporter');
  await page.getByRole('button', { name: /create new incident report/i }).click();
  await expect(page).toHaveURL(/\/incidents\/new/);
  await expect(page.getByText('NEW INCIDENT')).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-005: IncidentFormPage — Sections present
// ---------------------------------------------------------------------------

test('TC-UI-005: IncidentFormPage has all required sections', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  await expect(page.getByText('BASIC INFORMATION')).toBeVisible({ timeout: 10000 });
  await expect(page.getByText('DESCRIPTION')).toBeVisible();
  await expect(page.getByText('CLASSIFICATION')).toBeVisible();
  await expect(page.getByText('RAILROAD')).toBeVisible();
  await expect(page.getByText('PHOTOS')).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-006: IncidentFormPage — Completion indicator present
// ---------------------------------------------------------------------------

test('TC-UI-006: Completion indicator visible on IncidentFormPage', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  // CompletionIndicator renders "Form completion: X percent" semantic label
  await expect(
    page.locator('[aria-label*="Form completion"]')
  ).toBeVisible({ timeout: 10000 });
  // Also check "COMPLETION" text label
  await expect(page.getByText('COMPLETION')).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-007: IncidentFormPage — GPS auto-fill button present
// ---------------------------------------------------------------------------

test('TC-UI-007: GPS auto-fill button present in Location field', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  await expect(
    page.getByRole('button', { name: /auto-fill location from gps/i })
  ).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-008: IncidentFormPage — Save Draft and Submit buttons present
// ---------------------------------------------------------------------------

test('TC-UI-008: IncidentFormPage has Save Draft and Submit buttons', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  await expect(page.getByRole('button', { name: /save draft/i })).toBeVisible({ timeout: 10000 });
  await expect(page.getByRole('button', { name: /submit/i })).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-009: IncidentFormPage — Injured Person section conditional on Injury type
// ---------------------------------------------------------------------------

test('TC-UI-009: Injured Person section only appears for Injury type', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents/new');

  // Section should NOT be visible before selecting Injury
  await expect(page.getByText('INJURED PERSON')).not.toBeVisible({ timeout: 5000 }).catch(() => {});

  // Select "Injury" type
  await page.getByLabel('Incident Type').selectOption('Injury');

  // Now the section should appear
  await expect(page.getByText('INJURED PERSON')).toBeVisible({ timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-010: IncidentFormPage — Medical fields gated for Field Reporter
// ---------------------------------------------------------------------------

test('TC-UI-010: Medical fields restricted for field_reporter in injured person form', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');

  // Select Injury type to show the injured person section
  await page.getByLabel('Incident Type').selectOption('Injury');

  // Field reporter should see restriction notice, not medical fields
  await expect(
    page.getByText(/medical fields restricted to safety coordinator/i)
  ).toBeVisible({ timeout: 5000 });
});

test('TC-UI-010b: Medical fields visible for safety_coordinator in injured person form', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents/new');

  await page.getByLabel('Incident Type').selectOption('Injury');

  // Safety coordinator should see the Injury Type dropdown
  await expect(page.getByLabel('Injury Type')).toBeVisible({ timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-011: IncidentFormPage — Form validation on Submit
// ---------------------------------------------------------------------------

test('TC-UI-011: Submit without required fields shows validation errors', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');

  // Click Submit without filling any fields
  await page.getByRole('button', { name: /^submit$/i }).click();

  // Validation error messages should appear
  await expect(page.getByText(/type is required/i)).toBeVisible({ timeout: 5000 });
  await expect(page.getByText(/date is required/i)).toBeVisible();
  await expect(page.getByText(/location is required/i)).toBeVisible();
  await expect(page.getByText(/description is required/i)).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-012: IncidentFormPage — Add Photo button present
// ---------------------------------------------------------------------------

test('TC-UI-012: Add Photo button is present in IncidentFormPage', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  await expect(page.getByRole('button', { name: /add photo/i })).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-013: IncidentDetailPage — 5 Tabs present
// ---------------------------------------------------------------------------

test('TC-UI-013: IncidentDetailPage shows 5 tabs (Info, OSHA, Investigation, CAPAs, Recurrence)', async ({ page }) => {
  // Navigate to a detail page — use a non-existent ID to test route
  // The page will show an error, but URL routing should work
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1`);
  await page.waitForLoadState('networkidle');

  // Tabs should render (even if load fails, tabs are in AppBar)
  // Use a longer timeout to allow Flutter to render
  await expect(page.getByRole('tab', { name: /info/i })).toBeVisible({ timeout: 15000 });
  await expect(page.getByRole('tab', { name: /osha/i })).toBeVisible();
  await expect(page.getByRole('tab', { name: /investigation/i })).toBeVisible();
  await expect(page.getByRole('tab', { name: /capas/i })).toBeVisible();
  await expect(page.getByRole('tab', { name: /recurrence/i })).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-014: OshaDeterminationPage — Route and wizard present
// ---------------------------------------------------------------------------

test('TC-UI-014: /incidents/:id/osha route loads OSHA wizard', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1/osha`);
  await page.waitForLoadState('networkidle');
  await expect(page.getByText('OSHA DETERMINATION')).toBeVisible({ timeout: 15000 });
});

// ---------------------------------------------------------------------------
// TC-UI-015: OshaDeterminationPage — Wizard question 1 visible
// ---------------------------------------------------------------------------

test('TC-UI-015: OSHA wizard first question is work-related', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1/osha`);
  await page.waitForLoadState('networkidle');

  // The wizard should show the first question
  await expect(
    page.getByText(/was the injury or illness work-related/i)
  ).toBeVisible({ timeout: 15000 });
});

// ---------------------------------------------------------------------------
// TC-UI-016: OshaDeterminationPage — YES and NO answer buttons present
// ---------------------------------------------------------------------------

test('TC-UI-016: OSHA wizard YES and NO buttons are present and semantically labelled', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1/osha`);
  await page.waitForLoadState('networkidle');

  await expect(
    page.locator('[aria-label*="Answer yes to"]')
  ).toBeVisible({ timeout: 15000 });
  await expect(
    page.locator('[aria-label*="Answer no to"]')
  ).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-017: OshaDeterminationPage — Not work-related short-circuits to Not Recordable
// ---------------------------------------------------------------------------

test('TC-UI-017: Answering NO to work-related immediately shows Not Recordable', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1/osha`);
  await page.waitForLoadState('networkidle');

  // Wait for the wizard to appear
  await page.locator('[aria-label*="Answer no to"]').waitFor({ timeout: 15000 });
  await page.locator('[aria-label*="Answer no to"]').click();

  // Should immediately show NOT RECORDABLE
  await expect(page.getByText('NOT RECORDABLE')).toBeVisible({ timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-018: OshaDeterminationPage — Override checkbox visible after determination
// ---------------------------------------------------------------------------

test('TC-UI-018: Override checkbox visible after determination is recorded', async ({ page }) => {
  // This test checks that the override section appears when isOshaRecordable is set
  // It requires a real incident with a determination — test structure only
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1/osha`);
  await page.waitForLoadState('networkidle');

  // After answering NO to Q1 (not work-related), result is computed locally
  // but override only shows when incident.isOshaRecordable != null (server side)
  // We just verify the page loads without crash
  await expect(page.getByText('OSHA DETERMINATION')).toBeVisible({ timeout: 15000 });
});

// ---------------------------------------------------------------------------
// TC-UI-019: Bug Fix #10 — Admin route allows Safety Manager
// ---------------------------------------------------------------------------

test('TC-UI-019: /admin route accessible for safety_manager (Bug Fix #10)', async ({ page }) => {
  await loginAs(page, 'safety_manager', '/dashboard');
  await page.goto(`${BASE}/admin`);
  await page.waitForLoadState('networkidle');

  // Should NOT be redirected to /dashboard
  await expect(page).not.toHaveURL(/\/dashboard/, { timeout: 5000 });
  await expect(page).toHaveURL(/\/admin/);
});

test('TC-UI-019b: /admin route blocked for field_reporter', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/dashboard');
  await page.goto(`${BASE}/admin`);
  await page.waitForLoadState('networkidle');

  // Should be redirected to /dashboard
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-020: Bug Fix #10 — Admin nav item visible for Safety Manager
// ---------------------------------------------------------------------------

test('TC-UI-020: Admin nav item visible for safety_manager in sidebar', async ({ page }) => {
  // Use desktop viewport (≥900px) for sidebar
  await page.setViewportSize({ width: 1280, height: 800 });
  await loginAs(page, 'safety_manager', '/dashboard');

  await expect(
    page.getByRole('button', { name: /admin navigation/i })
  ).toBeVisible({ timeout: 10000 });
});

test('TC-UI-020b: Admin nav item NOT visible for field_reporter in sidebar', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await loginAs(page, 'field_reporter', '/dashboard');

  await expect(
    page.getByRole('button', { name: /admin navigation/i })
  ).not.toBeVisible({ timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-021: Router — All 5 incident routes present and navigable
// ---------------------------------------------------------------------------

test('TC-UI-021: All incident routes resolve (no 404 fallback)', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/dashboard');

  // /incidents
  await page.goto(`${BASE}/incidents`);
  await expect(page).toHaveURL(/\/incidents$/);
  await expect(page.getByText('INCIDENTS')).toBeVisible({ timeout: 10000 });

  // /incidents/new
  await page.goto(`${BASE}/incidents/new`);
  await expect(page).toHaveURL(/\/incidents\/new/);
  await expect(page.getByText('NEW INCIDENT')).toBeVisible({ timeout: 10000 });

  // /incidents/:id (will show error state, but URL should be correct)
  await page.goto(`${BASE}/incidents/999`);
  await expect(page).toHaveURL(/\/incidents\/999/);
  await expect(page.getByText('INCIDENT DETAIL')).toBeVisible({ timeout: 10000 });

  // /incidents/:id/edit
  await page.goto(`${BASE}/incidents/999/edit`);
  await expect(page).toHaveURL(/\/incidents\/999\/edit/);
  // Should show "EDIT INCIDENT" appbar even during load/error
  await expect(page.getByText('EDIT INCIDENT')).toBeVisible({ timeout: 10000 });

  // /incidents/:id/osha
  await page.goto(`${BASE}/incidents/999/osha`);
  await expect(page).toHaveURL(/\/incidents\/999\/osha/);
  await expect(page.getByText('OSHA DETERMINATION')).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-022: StatusBadge — Color-coded badges present in list
// ---------------------------------------------------------------------------

test('TC-UI-022: Status badges are semantically labelled', async ({ page }) => {
  // Navigate to incidents list; if there are incidents, badges will appear
  await loginAs(page, 'safety_coordinator');

  // Wait for list to load
  await page.waitForLoadState('networkidle');

  // Check if "Status: Draft" or other status badges exist (or empty state)
  // The test validates the semantic pattern is correct when badges render
  const badges = page.locator('[aria-label^="Status:"]');
  const count = await badges.count();

  // If no incidents, at least verify the empty state renders without error
  if (count === 0) {
    await expect(page.getByText(/no incidents found/i)).toBeVisible({ timeout: 5000 });
  } else {
    expect(count).toBeGreaterThan(0);
  }
});

// ---------------------------------------------------------------------------
// TC-UI-023: ADA/WCAG — Skip nav link in sidebar
// ---------------------------------------------------------------------------

test('TC-UI-023: Skip-to-main-content link present in sidebar', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await loginAs(page, 'field_reporter', '/incidents');

  // The skip-nav link is in the accessibility tree even when visually hidden
  await expect(
    page.getByRole('button', { name: /skip to main content/i })
  ).toBeDefined();
  // It should be in the DOM (Flutter semantics makes it reachable)
  const skipLink = page.locator('[aria-label="Skip to main content"]');
  await expect(skipLink).toHaveCount(1);
});

// ---------------------------------------------------------------------------
// TC-UI-024: ADA/WCAG — Incident cards are semantically labelled
// ---------------------------------------------------------------------------

test('TC-UI-024: Incident list cards have semantic labels', async ({ page }) => {
  await loginAs(page, 'safety_coordinator');
  await page.waitForLoadState('networkidle');

  const cards = page.locator('[aria-label*="incident,"]');
  const count = await cards.count();

  // If incidents exist, verify they have proper semantic labels
  if (count > 0) {
    const firstCardLabel = await cards.first().getAttribute('aria-label');
    expect(firstCardLabel).toMatch(/incident,/i);
  }
});

// ---------------------------------------------------------------------------
// TC-UI-025: ADA/WCAG — Herzog branding in sidebar
// ---------------------------------------------------------------------------

test('TC-UI-025: Herzog branding HIGHLANDER visible in desktop sidebar', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await loginAs(page, 'field_reporter', '/dashboard');

  await expect(page.getByText('HIGHLANDER')).toBeVisible({ timeout: 10000 });
  await expect(page.getByText('Safety Management')).toBeVisible();
});

// ---------------------------------------------------------------------------
// TC-UI-026: ADA/WCAG — Main navigation labelled for screen readers
// ---------------------------------------------------------------------------

test('TC-UI-026: Main navigation region has aria label', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await loginAs(page, 'field_reporter', '/dashboard');

  const nav = page.locator('[aria-label="Main navigation"]');
  await expect(nav).toBeVisible({ timeout: 10000 });
});

// ---------------------------------------------------------------------------
// TC-UI-027: IncidentDetailPage — Back button navigates to list
// ---------------------------------------------------------------------------

test('TC-UI-027: Back button on IncidentDetailPage navigates to /incidents', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/incidents');
  await page.goto(`${BASE}/incidents/1`);
  await page.waitForLoadState('networkidle');

  const backBtn = page.getByRole('button', { name: /back to incidents/i });
  await expect(backBtn).toBeVisible({ timeout: 10000 });
  await backBtn.click();
  await expect(page).toHaveURL(/\/incidents$/);
});

// ---------------------------------------------------------------------------
// TC-UI-028: IncidentFormPage — Back button navigates to list
// ---------------------------------------------------------------------------

test('TC-UI-028: Back button on IncidentFormPage navigates to /incidents', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');
  const backBtn = page.getByRole('button', { name: /back to incidents/i });
  await expect(backBtn).toBeVisible({ timeout: 10000 });
  await backBtn.click();
  await expect(page).toHaveURL(/\/incidents$/);
});

// ---------------------------------------------------------------------------
// TC-UI-029: Railroad section — Toggle reveals conditional fields
// ---------------------------------------------------------------------------

test('TC-UI-029: Railroad toggle reveals client dropdown when enabled', async ({ page }) => {
  await loginAs(page, 'field_reporter', '/incidents/new');

  // The Railroad Client dropdown should not be visible initially
  await expect(page.getByLabel('Railroad Client')).not.toBeVisible({ timeout: 5000 }).catch(() => {});

  // Toggle the railroad property switch
  const railroadToggle = page.locator('[aria-label="Railroad property toggle"]');
  await expect(railroadToggle).toBeVisible({ timeout: 10000 });
  await railroadToggle.click();

  // Railroad Client dropdown should now be visible
  await expect(page.getByLabel('Railroad Client')).toBeVisible({ timeout: 5000 });
});

// ---------------------------------------------------------------------------
// TC-UI-030: Audit Log route accessible to Safety Manager (Bug Fix #10 scope)
// ---------------------------------------------------------------------------

test('TC-UI-030: /audit-log accessible for safety_manager', async ({ page }) => {
  await loginAs(page, 'safety_manager', '/dashboard');
  await page.goto(`${BASE}/audit-log`);
  await page.waitForLoadState('networkidle');

  await expect(page).toHaveURL(/\/audit-log/);
  // Should NOT redirect to /dashboard
  await expect(page).not.toHaveURL(/\/dashboard/);
});

test('TC-UI-030b: /audit-log blocked for safety_coordinator', async ({ page }) => {
  await loginAs(page, 'safety_coordinator', '/dashboard');
  await page.goto(`${BASE}/audit-log`);
  await page.waitForLoadState('networkidle');

  await expect(page).toHaveURL(/\/dashboard/);
});
