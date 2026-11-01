import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

for (const locale of ['', 'es/']) {
  test(`player journey, images, themes, and keyboard: ${locale || 'en'}`, async ({ page, isMobile }, info) => {
    const errors: string[] = [];
    const remote: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('request', (request) => { if (!request.url().startsWith('http://127.0.0.1:4327/')) remote.push(request.url()); });
    await page.goto(locale || './');
    await expect(page.locator('html')).toHaveAttribute('lang', locale ? 'es' : 'en');
    await expect(page.getByRole('heading', { level: 1 })).toHaveCount(1);
    await page.keyboard.press('Tab');
    await expect(page.locator('.skip-link')).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/#main$/);
    await page.locator('#theme-choice').selectOption('light');
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'light');
    await page.locator('#theme-choice').selectOption('dark');
    await page.reload();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
    await page.locator('#theme-choice').selectOption('auto');
    if (isMobile) {
      await page.locator('.mobile-nav summary').click();
      await expect(page.locator('.mobile-nav nav')).toBeVisible();
      await page.locator('.mobile-nav a').first().click();
      await expect(page.locator('.mobile-nav')).not.toHaveAttribute('open');
    }
    await page.screenshot({ path: info.outputPath('home-top.png') });
    for (const width of [320, 768, 1280]) {
      await page.setViewportSize({ width, height: 900 });
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), `Overflow at ${width}px`).toBe(true);
    }
    await page.locator('#gallery').scrollIntoViewIfNeeded();
    const gallery = page.locator('.gallery img');
    await expect(gallery).toHaveCount(8);
    for (const image of await gallery.all()) {
      await image.scrollIntoViewIfNeeded();
      await expect(image).toHaveJSProperty('complete', true);
      expect(await image.evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);
    }
    await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }));
    await page.screenshot({ path: info.outputPath('home-full.png'), fullPage: true });
    await page.goto(`${locale}download/`);
    await expect(page.locator('.platform-grid .card')).toHaveCount(4);
    await expect(page.locator('.primary-card a')).toHaveAttribute('href', /play\.google\.com/);
    await page.goto(`${locale}community/`);
    await expect(page.locator('.contribution-steps li')).toHaveCount(4);
    expect(errors).toEqual([]);
    expect(remote).toEqual([]);
  });
}

for (const route of ['', 'es/', 'download/', 'es/download/', 'community/', 'es/community/', 'docs/', 'docs/architecture/', 'docs/gameplay/', 'licenses/', 'privacy-policy.html']) {
  test(`accessible rendered page: /${route}`, async ({ page }) => {
    await page.goto(route || './');
    const audit = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa']).analyze();
    expect(audit.violations).toEqual([]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });
}

test('documentation search, source links, and build-time diagram', async ({ page }) => {
  await page.goto('docs/architecture/');
  await expect(page.locator('.architecture-diagram')).toHaveAttribute('tabindex', '0');
  await expect(page.getByRole('img', { name: /Architecture flowchart/ })).toBeVisible();
  await expect(page.locator('a[href*="/blob/"]').first()).toHaveAttribute('href', /\/blob\/[0-9a-f]{40}\//);
  await page.getByRole('button', { name: 'Search', exact: true }).click();
  const search = page.locator('#starlight__search input');
  await expect(search).toBeVisible();
  await search.fill('backups');
  const result = page.locator('.pagefind-ui__result-link').first();
  await expect(result).toBeVisible();
  await expect(result).toHaveAttribute('href', /\/invade\.io\//);
  await result.click();
  await expect(page.locator('h1')).toBeVisible();
});

test('the essential player experience works without JavaScript', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:4327/invade.io/es/');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Mapas reales');
  await page.locator('.mobile-nav summary').click();
  await expect(page.locator('.mobile-nav nav')).toBeVisible();
  await page.locator('#faq details').first().locator('summary').click();
  await expect(page.locator('#faq details').first().locator('p')).toBeVisible();
  await expect(page.locator('.gallery a')).toHaveCount(8);
  await context.close();
});
