import { execFileSync } from 'node:child_process';
import { copyFile, mkdir, readFile, readdir, unlink, writeFile } from 'node:fs/promises';
import { guides, SITE, BASE } from './site.mjs';
import { guideContent } from './content.mjs';

const root = new URL('../../', import.meta.url);
const web = new URL('../', import.meta.url);
const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
const dirty = Boolean(execFileSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' }).trim());
const project = await readFile(new URL('project.godot', root), 'utf8');
const version = project.match(/^config\/version="([\d.]+)"$/m)?.[1];
if (!version) throw new Error('Missing source version');

const output = new URL('src/content/docs/docs/', web);
await mkdir(output, { recursive: true });
const filenames = new Set(guides.map(([, slug]) => `${slug || 'index'}.md`));
for (const name of await readdir(output)) {
  if (name.endsWith('.md') && !filenames.has(name)) await unlink(new URL(name, output));
}
for (const [source, slug] of guides) {
  const text = await readFile(new URL(source, root), 'utf8');
  await writeFile(new URL(`${slug || 'index'}.md`, output), guideContent(text, source, commit, version, dirty));
}

// Keep legal text byte-for-byte, and copy only named public assets.
for (const [source, target] of [
  ['docs/privacy-policy.html', 'privacy-policy.html'],
  ['icon.svg', 'favicon.svg'],
  ['docs/store_assets/feature-graphic-1024x500.png', 'social.png'],
  ['docs/store_assets/tablet_en/4_atlas.png', 'media/atlas.png'],
  ['assets/fonts/LICENSE-OFL.txt', 'font-license.txt'],
]) {
  const destination = new URL(`public/${target}`, web);
  await mkdir(new URL('./', destination), { recursive: true });
  await copyFile(new URL(source, root), destination);
}
await mkdir(new URL('src/generated/', web), { recursive: true });
await writeFile(new URL('src/generated/project.json', web), JSON.stringify({ version, commit, dirty }, null, 2) + '\n');
const licenses = [];
for (const [name, location] of [
  ['Astro', 'astro/LICENSE'],
  ['Starlight', '@astrojs/starlight/LICENSE'],
  ['Pagefind', 'pagefind/LICENSE/LICENSE'],
  ['beautiful-mermaid', 'beautiful-mermaid/LICENSE'],
]) {
  licenses.push({ name, text: await readFile(new URL(`node_modules/${location}`, web), 'utf8') });
}
await writeFile(new URL('src/generated/licenses.json', web), JSON.stringify(licenses, null, 2) + '\n');
await writeFile(new URL('public/robots.txt', web), `User-agent: *\nAllow: ${BASE}/\nSitemap: ${SITE}${BASE}/sitemap-index.xml\n`);
console.log(`Prepared ${guides.length} canonical guides for source ${version} (${commit.slice(0, 7)}).`);
