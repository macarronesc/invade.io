# Performance optimization and validation

[Testing](TESTING.md) · [Architecture](ARCHITECTURE.md)

## Scope

The optimization branch starts at `6918cd0` (0.3.2). It preserves combat,
production, AI decisions, level layouts, progression, rewards, accessibility,
and save formats. There are no new dependencies or gameplay features.

- Troop dots, base circles and atlas dots use a shared tinted disc texture.
  Compatibility can batch these rectangles instead of submitting each circle
  as a separate polygon. Counts, formations, sizes, colours and layering stay
  the same; rasterized edges are not pixel-identical to procedural circles.
- Disconnected land fills share one indexed triangle array. Projected geography
  retains its triangulation and outlines for retries and page rebuilds.
  Antialiased coastlines and borders are retained.
- Play and Invasion animate at the existing 20 Hz for five seconds after input,
  then stop processing. Touch, scrolling and keyboard input wake them. Reduced
  motion disables their processing, and settings suspends the covered page.
- The menu logo has its rounded corners baked into its SVG, avoiding an
  offscreen clipping pass. It is a rendition of `icon.svg`; update both if the
  brand changes.
- Battle events check only the affected achievement statistic; victory and
  menu checks still evaluate all achievements. Analytics HTTP uses a worker
  thread without changing consent, schemas, queue limits or delivery order.
- Slider/continent-navigation saves wait until 0.5 seconds after the last change.
  Pause, background, close and explicit saves still flush immediately. Saves
  serialize once and copy the previous validated bytes directly, retaining
  atomic temporary-file writes, future-version rejection and recovery files.
- Cosmetic lookups are indexed rather than caching a potentially stale player
  palette. HUD theme overrides only change when needed. Font variations retain
  only the existing current-locale bold/regular caches, not every past locale.
- Cosmetic purchases coalesce their presentation updates. Region selection
  rebuilds its detail contents, not its map or region selector, preserving focus.
  Native iOS picker completion disconnects all sibling callbacks.

## Measured rendering results

October 30, 2026: Godot 4.7.2, GL Compatibility, Mesa llvmpipe on Linux/Xvfb.
The `performance_check.tscn` fixtures average 30 rendered frames per case.
These are **draw calls**, not frame-rate promises for a phone:

| Fixture | Before | After | Reduction |
|---|---:|---:|---:|
| Troop classic, 16 packets at 1×/2× | 576 | 1 | 99.8% |
| Troop big, 16 packets at 1×/2× | 576 | 1 | 99.8% |
| Troop halo, 16 packets at 1×/2× | 864 | 1 | 99.9% |
| Army cosmetics | 224 | 100 | 55.4% |
| Atlas | 993 | 687 | 30.8% |
| Campaign menu | 1,018 | 877 | 13.9% |
| Europe 4 battle | 1,269 | 1,021 | 19.5% |
| Europe 5 battle | 3,223 | 2,698 | 16.3% |
| Iberia 3 battle | 835 | 641 | 23.2% |

Deterministic before/after scene images differ on at most 0.408% of pixels;
the largest mean absolute RGB difference is 0.0693 on a 0–255 scale. Changes
are localized to circle and logo rasterization, not layouts, text or map edges.
The isolated dot previews differ more (up to 2.562% of their pixels), because
most of that small fixture is dots. These measurements do not certify every
zoom, GPU, locale or cosmetic combination on physical devices.

## Validation record

- Baseline: 5,942 Godot assertions passed before runtime changes.
- Final full suite: 6,021 assertions passed; mobile/save subset: 998 passed.
- All 32 before/after gameplay/progression signatures match, including all
  languages/orientations, formations and victory/replay state across modes.
- Python tool tests: 35 passed. Repository guard and whitespace checks passed.
- Campaign/expedition/invasion balance simulations completed.
- Rendered UI checks completed in all 15 languages, plus invasion UI, wide
  screens, portrait/landscape rotation and touch/mouse gestures.
- Victory → upgrade → next and defeat → upgrade → retry flows passed.
- Android-resource PCK export completed; all 162 entries passed the artifact
  guard, including the menu logo and bundled notices, with test/development
  resources excluded. No store publication or signing done.

The full suite has the same pre-existing shutdown warnings as baseline:
one CanvasItem RID, three ObjectDB instances and one resource still in use.
The gesture harness also reports an ObjectDB shutdown warning. Xvfb warns that
the driver cannot change VSync. These are not a warning-free release certificate.

## Deliberate limits and release gates

- Keep troop snapshots and the current collision/siege loops. The snapshots
  protect iteration when arrival/capture callbacks remove orders; replacing
  them or adding spatial indexing needs a measured simulation bottleneck.
- Keep antialiased borders, the battle background node and Sentry call stacks.
  Removing them would trade visual fidelity, viewport isolation or diagnostics
  for unproven savings. No FPS cap or new audio/geo storage format is introduced.
- A hard kill without a lifecycle notification can lose the last 0.5 seconds
  of slider/navigation preferences. Purchases/rewards and lifecycle saves are
  still synchronous.
- Before production, test the actual custom-engine Android/iOS builds on
  low-end devices: sustained frame pacing, memory, battery/thermal behaviour,
  zoomed discs/halos, resume/background, offline analytics, native picker retries,
  and TalkBack/VoiceOver. Desktop mocks cannot validate native picker behaviour
  or certify fun, ergonomics and battery savings; those still need playtesting.
