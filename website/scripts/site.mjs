export const SITE = 'https://macarronesc.github.io';
export const BASE = '/invade.io';
export const REPO = 'https://github.com/macarronesc/invade.io';
export const PLAY = 'https://play.google.com/store/apps/details?id=macarronesc.invadeio';
export const href = (path = '') => `${BASE}/${path.replace(/^\/+/, '')}`;

// Only these first-party guides are published; the repository is never a public directory.
export const guides = [
  ['docs/README.md', '', 'Start here'],
  ['docs/GAMEPLAY.md', 'gameplay', 'Play'],
  ['docs/DEVELOPMENT.md', 'development', 'Develop'],
  ['CONTRIBUTING.md', 'contributing', 'Develop'],
  ['docs/ARCHITECTURE.md', 'architecture', 'Develop'],
  ['docs/TESTING.md', 'testing', 'Develop'],
  ['docs/PLATFORM_INTEGRATION.md', 'platforms', 'Develop'],
  ['docs/RELEASES.md', 'releases', 'Maintain'],
  ['docs/PLAY_STORE.md', 'publishing', 'Maintain'],
  ['docs/PLAY_STORE_UPDATE.md', 'store-material', 'Maintain'],
  ['docs/store_listing/release_notes.md', 'release-notes', 'Maintain'],
  ['docs/store_assets/validation.md', 'capture-validation', 'Maintain'],
  ['assets/brand/README.md', 'brand', 'Maintain'],
  ['docs/ANALYTICS.md', 'telemetry', 'Trust'],
  ['SECURITY.md', 'security', 'Trust'],
  ['docs/WEBSITE.md', 'website', 'Maintain'],
];

export const guideUrl = (slug) => href(`docs/${slug ? `${slug}/` : ''}`);
