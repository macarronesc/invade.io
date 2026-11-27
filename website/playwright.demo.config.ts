import { defineConfig, devices } from '@playwright/test';

// Runs against the checked static output after the Pages workflow has exported the Godot demo into dist/play/game/.
export default defineConfig({
  testDir: './tests/demo',
  workers: 1,
  timeout: 120_000,
  reporter: 'list',
  use: {
    baseURL: 'http://127.0.0.1:4328/invade.io/',
    launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] },
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 900 } } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
    { name: 'mobile-landscape', use: { ...devices['Pixel 7 landscape'] } },
  ],
  webServer: {
    command: 'npm run preview -- --port 4328 --ignore-lock',
    url: 'http://127.0.0.1:4328/invade.io/',
    reuseExistingServer: false,
    stdout: 'pipe',
    env: { ASTRO_TELEMETRY_DISABLED: '1' },
  },
});
