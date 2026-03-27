import { defineConfig } from '@playwright/test';

// SWE dev server runs on :3000, QA test server runs on :3001
// QA agent: override baseURL when testing PR branches:
//   npx playwright test --config=playwright.config.ts --grep "..." -- --base-url=http://localhost:3001
// Or set PLAYWRIGHT_BASE_URL=http://localhost:3001 in environment

export default defineConfig({
  testDir: '.',
  testMatch: '*.spec.ts',
  timeout: 30000,
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    headless: true,
  },
});
