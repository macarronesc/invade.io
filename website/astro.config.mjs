import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import { unified } from '@astrojs/markdown-remark';
import { SITE, BASE, REPO, guides, href } from './scripts/site.mjs';
import { repositoryMarkdown } from './scripts/content.mjs';

// Starlight makes wide tables scrollable (display:block; overflow:auto), so give
// each table keyboard access without relying on client-side JavaScript.
function accessibleTables() {
  return (tree) => {
    const walk = (node) => {
      if (node.type === 'table') {
        node.data = { ...node.data, hProperties: { ...node.data?.hProperties, tabindex: '0' } };
      }
      for (const child of node.children ?? []) walk(child);
    };
    walk(tree);
  };
}

export default defineConfig({
  site: SITE,
  base: BASE,
  trailingSlash: 'always',
  output: 'static',
  markdown: { processor: unified({ remarkPlugins: [repositoryMarkdown, accessibleTables] }) },
  integrations: [starlight({
    title: 'invade.io',
    disable404Route: true,
    description: 'Territory strategy on real-world maps. Built with Godot. Open to everyone.',
    logo: { src: '../icon.svg' },
    social: [{ icon: 'github', label: 'GitHub', href: REPO }],
    customCss: ['./src/styles/docs.css'],
    sidebar: [
      { label: 'Game website', link: '/' },
      ...['Start here', 'Play', 'Develop', 'Maintain', 'Trust'].map((group) => ({
        label: group,
        items: guides.filter(([, , section]) => section === group).map(([, slug]) => ({
          label: ({ '': 'Documentation', gameplay: 'Gameplay', development: 'Run locally', contributing: 'Contributing', architecture: 'Architecture', testing: 'Testing', forking: 'Make your own version', platforms: 'Platforms', releases: 'Releases', publishing: 'Google Play', 'store-material': 'Store material', 'release-notes': 'Release-note reference', 'capture-validation': 'Capture validation record', brand: 'Brand assets', telemetry: 'Telemetry', security: 'Security', website: 'Website maintenance' })[slug],
          link: `/docs/${slug ? `${slug}/` : ''}`,
        })),
      })),
      { label: 'Licenses & credits', link: '/licenses/' },
      { label: 'Privacy policy', link: `${SITE}${href('privacy-policy.html')}` },
    ],
    head: [{ tag: 'link', attrs: { rel: 'icon', href: href('favicon.svg'), type: 'image/svg+xml' } }],
  })],
});
