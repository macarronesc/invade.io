import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: false,
  workers: 1,
  timeout: 45_000,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:4327/invade.io/',
    contextOptions: { reducedMotion: 'reduce' },
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop-dark', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 900 }, colorScheme: 'dark' } },
    { name: 'mobile-light', use: { ...devices['Pixel 7'], colorScheme: 'light' } },
  ],
  webServer: {
    command: 'npm run preview -- --port 4327 --ignore-lock',
    url: 'http://127.0.0.1:4327/invade.io/',
    reuseExistingServer: false,
    stdout: 'pipe',
    env: { ASTRO_TELEMETRY_DISABLED: '1' },
  },
});
