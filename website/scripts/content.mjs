import path from 'node:path';
import { renderMermaidSVG } from 'beautiful-mermaid';
import { REPO, guides, guideUrl, href } from './site.mjs';

const routes = new Map(guides.map(([source, slug]) => [source, guideUrl(slug)]));
routes.set('README.md', href());
routes.set('LICENSE', href('licenses/'));
routes.set('NOTICE', href('licenses/#original-author'));
routes.set('assets/legal/notices.txt', href('licenses/#third-party'));
routes.set('docs/privacy-policy.html', href('privacy-policy.html'));

export function resolveLink(url, source, commit) {
  if (/^(?:https?:|mailto:|tel:|#|\/\/)/i.test(url)) return url;
  if (/^[a-z][a-z\d+.-]*:/i.test(url)) throw new Error(`Unsupported URL: ${url}`);
  const [file, fragment = ''] = url.split(/(?=#)/, 2);
  const target = path.posix.normalize(path.posix.join(path.posix.dirname(source), file));
  if (target.startsWith('../') || path.posix.isAbsolute(target)) {
    throw new Error(`Link escapes the repository: ${url}`);
  }
  if (routes.has(target)) return routes.get(target) + fragment;
  const kind = file.endsWith('/') ? 'tree' : 'blob';
  return `${REPO}/${kind}/${commit}/${target.split('/').map(encodeURIComponent).join('/')}${fragment}`;
}

export const escapeHtml = (text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

export function transformTree(node, source, commit) {
  if (node.type === 'link' || node.type === 'definition') node.url = resolveLink(node.url, source, commit);
  if (node.type === 'image') {
    const target = path.posix.normalize(path.posix.join(path.posix.dirname(source), node.url));
    if (target !== 'docs/store_assets/tablet_en/4_atlas.png') {
      throw new Error(`Add an explicit public image mapping for ${target}`);
    }
    node.url = href('media/atlas.png');
  }
  if (node.type === 'code' && node.lang === 'mermaid') {
    const svg = renderMermaidSVG(node.value, { bg: '#f3f7fc', fg: '#14283e', accent: '#1367b8', font: 'system-ui' });
    node.type = 'html';
    node.value = `<figure class="architecture-diagram" tabindex="0" aria-label="Architecture diagram; scroll horizontally to explore">${svg.replace('<svg ', '<svg role="img" aria-label="Architecture flowchart; a text explanation follows" ')}<figcaption>Generated from the diagram in the source guide.</figcaption></figure><details><summary>Diagram source</summary><pre><code>${escapeHtml(node.value)}</code></pre></details>`;
  }
  for (const child of node.children ?? []) transformTree(child, source, commit);
}

export function repositoryMarkdown() {
  return (tree, file) => {
    const data = file.data.astro?.frontmatter;
    if (data?.source) transformTree(tree, data.source, data.sourceCommit);
  };
}

export function guideContent(text, source, commit, version, dirty = false) {
  const match = text.match(/^# (.+)\r?\n/);
  if (!match) throw new Error(`Missing guide title: ${source}`);
  const frontmatter = {
    title: match[1],
    description: `${match[1]} — invade.io project documentation.`,
    source,
    sourceCommit: commit,
    editUrl: `${REPO}/edit/dev/${source}`,
  };
  const metadata = Object.entries(frontmatter).map(([key, value]) => `${key}: ${JSON.stringify(value)}`).join('\n');
  return `---\n${metadata}\n---\n\n> **Source reference:** version ${version}, commit [${commit.slice(0, 7)}](${REPO}/tree/${commit}).${dirty ? ' This preview includes uncommitted changes.' : ''} This is not a statement of the version currently on Google Play.\n\n${text.slice(match[0].length)}`;
}
