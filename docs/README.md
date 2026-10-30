# invade.io documentation

[Project home](../README.md) · [Contributing](../CONTRIBUTING.md) · [Google Play](https://play.google.com/store/apps/details?id=macarronesc.invadeio)

Welcome to the reference for playing, developing, and maintaining invade.io.
Choose a path below; you do not need mobile build tools or store credentials to
start contributing.

Read these same guides with navigation and search on the
[project website](https://macarronesc.github.io/invade.io/docs/), or browse the
[visual game tour](https://macarronesc.github.io/invade.io/). The website is built
from these canonical Markdown files, not a separately edited copy. Pages deploys
from `main`; this checkout can contain changes not published yet.

## Play and understand

| Guide | What you will find |
|---|---|
| [Gameplay](GAMEPLAY.md) | Controls, game modes, continent rules, progression, settings, and backups |
| [Platform integration](PLATFORM_INTEGRATION.md) | Android/iOS behavior, test-build installation, and device limitations |
| [Privacy policy](https://macarronesc.github.io/invade.io/privacy-policy.html) | The public policy for the distributed application |

## Develop and contribute

1. [Set up the project](DEVELOPMENT.md) and run it without telemetry.
2. Read the [architecture overview](ARCHITECTURE.md) to locate the relevant system.
3. Use the [testing guide](TESTING.md) to choose checks for your change.
4. Follow [CONTRIBUTING.md](../CONTRIBUTING.md) to open a focused PR against `dev`.

Translations, UI review, physical-device reports, and documentation are useful
contributions alongside code. The development guide includes
[localization](DEVELOPMENT.md#localization) and
[asset-generation workflows](DEVELOPMENT.md#geography-and-brand-assets).

## Build and maintain

| Guide | Scope |
|---|---|
| [Releases](RELEASES.md) | CI, artifact types, versioning, signing boundaries, and release recovery |
| [Google Play publishing](PLAY_STORE.md) | Updating the existing Android application and configuring local exports |
| [Play Store refresh](PLAY_STORE_UPDATE.md) | Localized copy, screenshot provenance, packaging, and Console review |
| [Telemetry](ANALYTICS.md) | Privacy settings, event schema, providers, and Debug/Release behavior |
| [Security policy](../SECURITY.md) | Private reports, credentials, and maintainer review requirements |
| [Website and documentation publishing](WEBSITE.md) | Astro/Starlight setup, content sources, web checks, and Pages deployment |

## Project status

Documentation describes the **current checkout**, not a guarantee about the
version installed from a store. Check [project.godot](../project.godot) for the
source version and [GitHub releases](https://github.com/macarronesc/invade.io/releases)
for published build artifacts. A GitHub release is not automatic store submission.

| Area | Current scope |
|---|---|
| Android | Available on [Google Play](https://play.google.com/store/apps/details?id=macarronesc.invadeio); Debug APKs use a separate app identifier |
| iOS | CI produces unsigned IPAs for SideStore testing, not App Store or TestFlight releases |
| Desktop | Linux/macOS development; desktop use is not a promise of a packaged desktop release |
| Game modes | Offline, single-player campaign, invasions, expeditions, and daily challenges |
| Progress | Local saves and manual JSON backups; no account or cloud synchronization |
| Online competition | No multiplayer, live PvP, or online leaderboard |
| Accessibility | Configurable presentation and alternate battle controls; mobile screen-reader support is not established |

The October 28, 2026 marketing material targets source version **0.3.1**. On
October 30 the public policy described enabled telemetry defaults, while the
Google Play listing still contained older descriptions and opt-in/no-collection
wording. GitHub offered a **0.3.2** release while this development checkout declared
**0.3.1**. These are dated public-page observations, not a live status feed or
verification of the shipped binary. Before publishing, match the build, listing, policy, and Data safety
declarations using the [store update checklist](PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate).

## Keeping these guides accurate

- Keep setup in [Development](DEVELOPMENT.md), commands in [Testing](TESTING.md),
  gameplay rules in [Gameplay](GAMEPLAY.md), and signing policy in [Releases](RELEASES.md).
- Write first-party guide prose in English. Localized game/store text and
  historical release payloads remain in their intended languages.
- Link to the source of a rule rather than copying constants into several guides.
- When changing behavior, update the affected guide and screenshots if necessary.
  Do not regenerate the store gallery for a text-only documentation change.
- After editing guides, validate the generated site with the [website checks](WEBSITE.md#run-and-validate).
- Keep unsupported features distinct from implemented ones. An idea is not a
  release commitment, and an automated test is not physical-device certification.
