# Website and documentation publishing

[Documentation](README.md) · [Contributing](../CONTRIBUTING.md) · [Release safeguards](RELEASES.md)

The public website is a static Astro project in `website/`. Its custom English
and Spanish player pages share a design with the English Starlight documentation.
It has no backend, accounts, advertising, website analytics, or remotely loaded
fonts. GitHub Pages serves the files and has its own hosting/privacy practices.
The theme preference is stored in the browser. The game's telemetry is separate;
see [Telemetry](ANALYTICS.md) and the [privacy policy](privacy-policy.html).

## Run and validate

Use Node.js **24 LTS**, its bundled npm, and Python 3.10+ for the static-output
validator. No Godot editor or mobile credentials are needed to build the website.
Run these commands from `website/`:

```sh
npm ci
npm test
npm run build
npm run preview
```

Open `http://localhost:4321/invade.io/`. `npm run dev` prepares the same content
before starting the development server. Restart it after editing canonical guides.
Generated files, dependencies, and output are ignored by Git; do not edit them.
Build/dev startup clears Astro's content cache so edits to the Markdown adapter
cannot silently reuse previously rendered guides.

For browser checks, install Playwright's Chromium once, then run:

```sh
npx playwright install --with-deps chromium
npm run test:browser
```

The browser suite uses the production preview, desktop/mobile viewports, keyboard
navigation, search, theme switching, English/Spanish routes, and automated
accessibility checks. It is not a substitute for human readability and screen-reader
review. Build-time checks validate internal links/anchors/assets, legal text
preservation, and the absence of private/development files in the output.

## Sources and ownership

- `website/src/components/` and `website/src/layouts/`: the player-facing pages.
- `website/src/data/`: English/Spanish website copy and selected real screenshots.
- `website/src/styles/`: shared brand tokens, player layouts, and documentation styles.
- `website/scripts/site.mjs`: the site base, public links, and explicit guide list.
- `website/scripts/prepare.mjs`: copies selected public assets and generates Starlight
  entries from the canonical Markdown. It never writes to the original guides,
  game assets, player saves, or store-capture manifest.
- `website/scripts/content.mjs`: adapts Markdown links and renders diagrams at build
  time. Guide links stay on the site; source-code links refer to the documented
  Git commit. Edit links target the original guide on `dev`.

Keep technical prose in English. Player-page translations are manually maintained
in English and Spanish; the game's 15 languages do not imply translated technical
guides. Store-listing translations and historical notes remain in their intended
languages. Review new marketing claims against the actual store build.

## Images, licenses, and privacy

Use the existing PNGs in `docs/store_assets/`; Astro generates responsive WebP
derivatives without changing the source files. Only selected images are emitted,
and lower-page gallery images load lazily. Do not copy the full store gallery or
`assets/data/geo.json` into the website. Do not add a renderer, game export, remote
analytics, embeds, or a new font service just for decoration.

Screenshots show real scenes with representative mid-game progress, not the initial
state of a new install. The capture manifest describes source provenance, not
Google Play publication. See [store material](PLAY_STORE_UPDATE.md) before generating
new captures. Regeneration is unnecessary for ordinary website prose/style changes.

`docs/privacy-policy.html` is copied **byte-for-byte** to the existing public
`/invade.io/privacy-policy.html` URL. Do not change legal disclosures as a visual
cleanup. The website's license page preserves `LICENSE`, `NOTICE`, bundled
third-party notices, font notices, and the website framework notices separately.

## GitHub Pages and release boundaries

`.github/workflows/pages.yml` builds and checks pull requests without deployment
credentials. Only `main` deploys the complete static output to the `github-pages`
environment. Actions are SHA-pinned, dependency installs use the committed lockfile,
and production deployment permissions are scoped to the deployment job. No game
signing secret or Play Console credential is needed.

### Download a dev PR preview

Every PR targeting `dev` builds a separate website and documentation preview,
including PRs that change only game code. PRs targeting `main` still run website
checks; main pushes retain the existing website-related path filter and deployment.
No PR deploys to the production site or posts a comment.

After the **Website and documentation** run succeeds, download its
`website-preview-pr-<NUMBER>` artifact from Actions (GitHub sign-in required).
It expires after seven days. Unzip it into an empty directory, then run:

```sh
tar -xf artifact.tar
python3 -m http.server 8000 --bind 127.0.0.1
```

Run the server from that directory and open `http://localhost:8000/invade.io/`
or `http://localhost:8000/invade.io/docs/`. No Node.js or dependencies are needed
to view the checked static output. Opening HTML with `file://` will not correctly
serve the project-base assets or documentation search. Production canonical/legal
URLs remain unchanged; this download is a local review build, not a public preview
deployment or a statement of the current store version. Treat fork PR content as
untrusted and do not reuse a server directory containing private files.

Keep `site` and `base` aligned with `website/scripts/site.mjs`. GitHub Pages serves
this project under `/invade.io/`, not the domain root. Test deep links, search,
images, the 404 page, and the unchanged policy address after deployment.

The game release rules have **not** been relaxed: integrating into `main` still
requires the existing version/release process. Website work must not bypass
platform checks, signing approval, or version validation. A GitHub release is not
confirmation of the Google Play version; the website links to published releases
without guessing store rollout state or exposing expiring Actions artifacts.

The `.gdignore`, export exclusions, and artifact guard keep `website/` out of
Godot imports and mobile packages. Preserve them when changing the directory.
No website change should alter gameplay, scenes, translations, or game visuals.

## Implementation validation record

Checked on 30 October 2026 in the isolated website worktree; these are dated
local results, not a production deployment or device certification:

- Clean `npm ci`; production build/type checks and 25-page offline output check passed.
- Four Node content-adapter tests and two Python output-validator tests passed.
- Thirty Chromium browser tests passed across desktop/dark and mobile/light,
  including axe checks, search, themes, keyboard use, and no-JavaScript player pages.
- All 34 repository Python tests, actionlint, repository credential checks, and
  npm's dependency advisory check passed with no reported vulnerabilities.
- The Godot quick suite passed 3,773 checks before website integration. After
  rebasing onto the latest `dev`, the complete suite passed 5,942 checks. Existing
  shutdown RID/ObjectDB resource-leak warnings remained; this was not a
  warning-free engine run.
- All 22 English preview PNG hashes matched the pre-change baseline before the
  rebase. No game scripts, scenes, assets, translations or `project.godot` are
  changed by this website commit; the rebased change set was verified against
  `origin/dev`.
- A real Godot Android-preset PCK export passed the artifact guard: 182 entries,
  bundled notices intact, and no website resources. This was not a signed APK/AAB.
- An unthrottled local Chromium check measured approximately 221–259 KiB for the
  initial home-page payload at 390/1280 px, including about 1.1 KiB of external
  JavaScript. These are local observations, not field Core Web Vitals or retention data.

Safari/Firefox, physical devices, human assistive-technology review, GitHub-hosted
Actions/deployment, signed mobile artifacts, and Play Console were not verified.
The public listing/policy/build alignment still requires owner review before release.
