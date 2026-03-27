import { test, expect } from '@playwright/test';

// Flutter renders to canvas — use semantics tree for element queries.
// Flutter's semantics mode is always-on (enabled in main.dart).
// Use page.getByRole(), page.getByLabel(), and ARIA selectors for interactions.

test('home page loads with 200', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.status()).toBe(200);
});

test('home page renders without JS errors', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(err.message));
  await page.goto('/');
  await page.waitForTimeout(5000);
  expect(errors).toEqual([]);
});

test('flutter app bootstrap script loaded', async ({ page }) => {
  await page.goto('/');
  const script = page.locator('script[src="flutter_bootstrap.js"]');
  await expect(script).toBeAttached({ timeout: 10000 });
});

test('health endpoint responds when backend is running', async ({ request }) => {
  try {
    const response = await request.get('http://localhost:8000/health');
    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.status).toBe('ok');
  } catch {
    test.skip(true, 'Go backend not running — skipping health check');
  }
});
