import { test, expect } from '@playwright/test';

test('the browser demo starts and fills the screen without third-party requests', async ({ page }, info) => {
  const problems: string[] = [];
  const origin = new URL(info.project.use.baseURL!).origin;
  page.on('pageerror', (error) => problems.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') problems.push(message.text()); });
  page.on('response', (response) => { if (response.status() >= 400) problems.push(`${response.status()} ${response.url()}`); });
  page.on('request', (request) => { if (new URL(request.url()).origin !== origin) problems.push(`remote ${request.url()}`); });

  await page.goto('play/game/');
  const play = page.locator('#status-play');
  if (await play.isVisible()) await play.click(); // phones get a tap-to-play step for full screen
  await expect(page.locator('#status')).toHaveCount(0, { timeout: 90_000 });

  const view = page.viewportSize()!;
  const canvas = (await page.locator('canvas').boundingBox())!;
  expect(Math.abs(canvas.width - view.width)).toBeLessThanOrEqual(2);
  expect(Math.abs(canvas.height - view.height)).toBeLessThanOrEqual(2);
  // A blank page compresses to a few KiB; the first map has detail.
  await expect.poll(async () => (await page.screenshot()).length, { timeout: 60_000 }).toBeGreaterThan(40_000);
  expect(problems).toEqual([]);
});
