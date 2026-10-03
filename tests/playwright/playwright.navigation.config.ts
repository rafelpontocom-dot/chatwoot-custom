import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e/ui',
  testMatch: 'navigation-upgrade.smoke.spec.ts',
  timeout: 180_000,
  expect: { timeout: 15_000 },
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  outputDir: './test-results/navigation',
  use: {
    baseURL: process.env.BASE_URL || 'http://127.0.0.1:3011',
    headless: true,
    actionTimeout: 15_000,
    viewport: { width: 1440, height: 900 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    launchOptions: {
      executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH,
    },
  },
  webServer: {
    command: 'bundle exec rails server -e test -p 3011 -b 127.0.0.1',
    url: 'http://127.0.0.1:3011/app/login',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: { DISABLE_MINI_PROFILER: '1' },
  },
});
