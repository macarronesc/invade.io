# invade.io — Play Store refresh and publishing guide

[Documentation](README.md) · [Android publishing](PLAY_STORE.md) · [Release process](RELEASES.md)

**Prepared for the repository's 0.3.1 release, 28 October 2026.**

This document records the implemented marketing work, the files to upload, and the
checks the owner must make in Play Console. Nothing in this workflow publishes an
app, changes the live listing, or changes the game's telemetry defaults.

## 1. Start here

1. Review `build/store_capture/contact_en.png` and `contact_es.png`, then the other
   language contact sheets. These are review sheets, **not upload screenshots**.
2. Read the English or Spanish listing in `docs/store_listing/`.
3. Confirm that the production release matches this source version, particularly
   its telemetry behavior. Do not copy the 0.3.1 privacy paragraph onto an older release.
4. Have native speakers review translated copy, especially the 13 non-EN/ES full
   descriptions, which began as machine-translated drafts. Short graphic captions
   have been edited for game terminology and layout, but that is not native-speaker approval.
5. Build the upload ZIP with the commands below. Extract it locally; paste the text
   and upload the individual PNG files in Play Console. The ZIP is not a Console import format.

```sh
# Text, locale, field-length and alt-text checks: offline, no writes.
python3 tools/build_store_listings.py --check

# Fresh real-scene captures and final graphics. Requires Godot 4.7.2 and a display.
# On a desktop, omit xvfb-run. Do not use Godot --headless for image generation.
xvfb-run -a godot --audio-driver Dummy --path . res://scenes/tests/store_assets.tscn -- --no-telemetry

# Validate all graphics, caption provenance and hashes, then package the material.
python3 tools/build_store_listings.py --package
```

**Delivery:** `build/play-store-listing.zip`. It contains copy and images grouped
by Play Console locale, the existing 512 px icon, capture manifest and this guide.
`build/` is intentionally ignored by Git; the reproducible source and final PNGs
live in `docs/`. Rebuild the ZIP after changing any text, image or this guide.

CI also generates this material and exposes a **play-store-listing** review artifact
in GitHub Actions for seven days, including the ZIP and language contact sheets.
It does not upload anything to Play Console or modify signing/release permissions.

## 2. What changed, and why

| Before | Implemented improvement | Purpose |
|---|---|---|
| Brand-only titles | Localized brand + genre/territory-conquest titles, within 30 characters | Explain the game to unfamiliar visitors |
| Outdated two-language/15-achievement description | Consistent copy for 15 languages, 20 achievements, 36 regions and 108 fronts | Match the current game and show its depth |
| A menu opens the gallery | The first three images show real attacks on distinct maps | Make the core interaction understandable before asking visitors to read |
| Uncaptioned UI-test screenshots | Eight images per language with one benefit-led headline and short supporting line | Explain the experience at thumbnail size |
| Mostly empty progress | A representative mid-game fixture with 51 cities, earned upgrades and achievements | Show what continuing to play can unlock |
| Cosmetics/atlas below the visible area | Real scrolling to troop styles/base shapes/map themes and the populated atlas | Make those features visible rather than merely claiming them |
| Repeated icon + logo feature graphic | A gameplay-led map confrontation, cropped below the HUD, with a smaller wordmark | Communicate the game beyond the icon |
| Screenshots depend on a prior `--ui` run | One self-contained Godot capture scene | Avoid stale or missing source screenshots |
| Different themes by locale | A consistent light presentation, a genuine dark appearance screen and dark-blue captions | Keep markets coherent while demonstrating both UI themes |
| PNG screenshots retain alpha | Explicit RGB8 final PNGs at the target dimensions | Match the documented Play upload format |
| No large-screen material | Four uncaptioned 1920×1080 tablet captures per language | Show actual landscape layouts without adding phone-marketing overlays |
| Manual, disconnected files | Offline validation, hashes, ordered manifest, localized alt text and upload ZIP | Reduce publishing mistakes |

The icon is deliberately unchanged. There are no invented troops, fake controls,
device frames, testimonials, ranking badges, install calls-to-action or competitor branding.
No gameplay feature, monetization system, analytics service or account system was added.

## 3. Positioning and message hierarchy

**Core promise:** approachable territory strategy on real-world maps, with tactical
decisions, progression, offline play and no advertising interruptions.

1. What the player does: drag between bases, send troops, capture territory.
2. Why decisions matter: factories, fortresses, capitals, bosses and continent rules.
3. Why there is more to discover: campaign, invasions, expeditions and daily challenges.
4. Why keep playing: upgrades, cosmetic rewards, atlas, ranks and achievements.
5. Why it fits the player: offline, no ads or purchases, 15 languages and accessibility options.

Returning players get a clearer view of content and goals already present. New
players see the interaction before the menus. These are marketing hypotheses, not
measured acquisition or retention improvements; use the measurement plan in §10.

Do not advertise multiplayer, live PvP, online rankings, cloud saves, all cities of
the world as campaign objectives, or guaranteed battle lengths. The daily challenge
runs locally and has comparable starting forces; sharing copies a result card.

## 4. Exact material and screenshot order

### Text

Each `docs/store_listing/<game-locale>.md` has exactly three fenced blocks:

1. App title, at most **30 characters**.
2. Short description, at most **80 characters**.
3. Full description, at most **4,000 characters**.

Only paste the block contents, not Markdown headings or fences. The ZIP already
separates them into `title.txt`, `short_description.txt` and `full_description.txt`.

English title: **invade.io: Territory Strategy** (29 characters).
Spanish title: **invade.io: Conquista el mapa** (28 characters).

Titles change only the listing; the installed game's name and permanent package
identifier `macarronesc.invadeio` remain unchanged.

### Phone gallery

Final source: `docs/store_assets/screenshots_<game-locale>/`.
ZIP: `<play-locale>/phone/`. Upload **only the eight PNGs**, in numeric order.

| File | English headline | Source/proof |
|---|---|---|
| `1_conquer.png` | Drag. Send. Conquer. | Athens → Istanbul troop dispatch, `europe_4` |
| `2_tactics.png` | Every base changes the battle | European factory/fortress/boss map, `europe_5` |
| `3_invasions.png` | 36 regions. 108 fronts. | Iberia's capital front, `inv_iberia_3` |
| `4_campaign.png` | Six continents. More to conquer. | Campaign map, stars and expedition entry |
| `5_daily.png` | A different challenge every day | Fixed real daily-challenge seed, with its rule/objective |
| `6_upgrades.png` | Build a stronger army | Real upgrade cards and next upgrade effects |
| `7_cosmetics.png` | Make every conquest yours | Real appearance screen, scrolled to troop/base/map options |
| `8_atlas.png` | Track every conquest | Real atlas with conquered cities and achievement progress |

All final phone images are **1080×1920, 24-bit RGB PNG**. A 320 px caption band
occupies one-sixth of the height. The remaining 1080×1600 area is a real game
viewport rendered at that supported size: no stretching, fictional UI or handset frame.

The fixture represents achievable mid-game progress, **not the initial rewards of
a new installation**. It is isolated from player saves. Battle production and AI
advance in fixed simulation steps before a valid attack is dispatched; combat rules
and army counts are not inflated for the image. No fabricated victory screen is used.

Every PNG has a matching `.alt.txt` in the ZIP. Paste that localized description
into the image's alt-text field where Console offers it; do not upload the text file as an image.
Alt text describes the image rather than repeating the headline, and is ≤140 characters.

### Tablet gallery

Source: `docs/store_assets/tablet_<game-locale>/`. ZIP: `<play-locale>/tablet/`.
The four PNGs show campaign, an invasion battle, appearance options and the atlas.
They are **1920×1080 RGB**, rendered from the actual landscape layout, without
additional marketing text. Use them in the appropriate tablet screenshot sections
after checking the installed release on the corresponding devices. Reusing the set
for both tablet sizes is appropriate only if the real layouts match.

### Feature graphic and icon

- `docs/store_assets/feature-graphic-1024x500.png`: **1024×500 RGB**, no alpha.
  The ZIP includes the same brand-only graphic in each locale directory plus localized alt text.
- `assets/brand/play-store-icon-512.png`: existing **512×512 RGBA** icon, packaged
  as `icon-512.png`. Do not replace Android launcher assets with the feature graphic.
- Contact sheets and raw captures stay in `build/store_capture/`; do not upload them.

## 5. Locale mapping

Game locales are not always the same identifiers as Console locales. Packaging
uses the following mapping; select the matching language, not a guessed country.

| Game/source | Play Console/ZIP | Language |
|---|---|---|
| `en` | `en-US` | English (United States) |
| `es` | `es-ES` | Spanish (Spain) |
| `pt_BR` | `pt-BR` | Portuguese (Brazil) |
| `fr` | `fr-FR` | French |
| `de` | `de-DE` | German |
| `it` | `it-IT` | Italian |
| `ru` | `ru-RU` | Russian |
| `tr` | `tr-TR` | Turkish |
| `ar` | `ar` | Arabic |
| `hi` | `hi-IN` | Hindi |
| `id` | `id` | Indonesian |
| `vi` | `vi` | Vietnamese |
| `zh_CN` | `zh-CN` | Simplified Chinese |
| `ja` | `ja-JP` | Japanese |
| `ko` | `ko-KR` | Korean |

Arabic captions and the game's interface use RTL; geographic maps and the brand
are not mirrored. Per-script Noto subsets include the new caption characters.
Language support does not mean the app is distributed in every country; review
country availability separately. No Traditional Chinese or other unsupported translation is promised.

## 6. Update the published listing in Play Console

Console navigation labels can change. Work in the existing application; **do not
create a new app or change its package identifier**.

### Store presence → Main store listing

1. Keep a copy of the current text, image order and screenshots before replacing them.
2. Select the default listing language and paste its title, short and full description.
3. Upload the eight phone PNGs in order. Remove the old phone images so the gallery
   does not mix the two campaigns or exceed eight slots.
4. Replace the feature graphic; retain the icon for this first iteration.
5. Add the tablet set in the matching device sections, not the phone section.
6. Add localized alt text to phone images, tablet images and the feature graphic.
7. Add/update each of the other supported language listings with its own text and
   graphics. Check previews; do not assume English screenshots automatically become localized.
8. Preview the result on a phone-sized display: the first image must explain the
   game, headings must be readable, and the first three images must show gameplay.

Main-listing assets can appear across test tracks. An internal testing track is
not a private alternate main listing. Use Console previews or a suitable custom
listing for creative preparation, and review submission/publishing status carefully.

### Store presence → Store settings

- Recommended type/category: **Game → Strategy**. The public listing inspected on
  28 October used Simulation. This is a recommendation, not a change already made in Console.
- Select up to five genuinely relevant tags from Console's available choices.
  Strategy, single-player and offline characteristics are relevant; do not invent
  tags, select multiplayer, or add accessibility tags before real-device verification.
- Keep support email `alegandro2507@gmail.com` unless the owner chooses another.
- Confirm the developer contact information and country availability.
- Review supported form factors and Play Games on PC availability. Generated tablet
  images are not proof that all devices or PC distribution have been tested.
- Leave external marketing settings to the owner's distribution preference; there
  is no automatic opt-in or advertising campaign in this change.

## 7. Mandatory privacy, audience and release gate

The live English/Spanish listing inspected on 28 October said two languages,
15 achievements, no network permission and no data collection. Its release notes
advertised 15 languages and telemetry off by default. The public privacy page dated
22 October also described opt-in telemetry. **Those statements were not changed remotely.**

The checked-out **0.3.1** code has `share_analytics=true` and `share_crashes=true`
as defaults for new/missing settings; saved false choices are preserved. It includes
Aptabase and Sentry and requests network permissions. The local privacy-policy
source already describes this behavior. This marketing work does not change it.

Before submitting:

- [ ] Confirm the actual production AAB/version and the commit used for captures.
      The manifest records the base commit and whether the working tree was dirty.
      These prepared assets include local changes until you commit them; do not
      mistake the recorded base commit for an already released build.
- [ ] Match the full-description privacy paragraph to the shipped build. If the
      production app still has opt-in defaults, use accurate wording for that build,
      not the supplied 0.3.1 defaults paragraph. Preserve honesty in every translation.
- [ ] Review consent/disclosure requirements before shipping enabled-by-default
      analytics; a toggle or store description is not itself prior consent.
- [ ] Publish the matching policy at
      `https://macarronesc.github.io/invade.io/privacy-policy.html` and verify the
      public contents. The existing Pages workflow deploys from `main`; merely
      editing a local HTML file does not update the public page.
- [ ] Review Data safety for **all currently distributed versions/tracks** that
      are in scope. Optional telemetry is still collection when data leaves the
      device. Check app activity, crash/diagnostic data, IP-derived location and
      session identifiers against the SDKs and provider configuration.
- [ ] Determine whether the service-provider sharing exception applies; do not
      mark all third-party processing as sharing or as no collection by assumption.
- [ ] Keep the no-ads/no-purchases and no-account access declarations only while
      they remain true. No credentials are needed to review this game.
- [ ] Confirm target audience and Families settings. The public page displayed a
      Families commitment, while the repository policy says the game is not directed
      at under-13s. Resolve this intentionally; **PEGI 3 is not a target-audience choice**.
- [ ] Keep IARC/content-rating answers truthful. Do not manufacture a new rating
      based on a marketing preference.
- [ ] For an app release, use an unused increasing versionCode, follow
      `docs/RELEASES.md`, and run the existing Android bundle verification. No
      signing credentials or release codes were changed for this store refresh.

Data safety worksheet for the owner (verify with the SDK/provider settings, not
automatic form answers):

| Data to investigate | Likely Console category/purpose | Required confirmation |
|---|---|---|
| Level outcomes, time, tabs, upgrades | App activity; analytics | What actually leaves the device and whether every user can opt out |
| Crash traces, device/OS and performance context | Crash logs/diagnostics; analytics | Native report contents, retention and any attached identifiers |
| Country inferred from a connection IP | Approximate location; analytics | Whether the provider performs/stores that inference |
| Temporary session IDs and SDK-generated identifiers | Review Device or other IDs definitions | Do not assume a temporary identifier never needs declaration |
| Encrypted requests and deletion/contact process | Security practices | Verify actual transport and what deletion requests can be fulfilled; deleting a local save is not deletion of provider data |

A listing-only update need not invent an application release. If shipping the
pending 0.3.1 build too, write accurate release notes from
`docs/store_listing/release_notes.md`; do not describe captioned store screenshots
as newly implemented in-game functionality.
The ZIP includes that document as `release-notes-reference.md`; use only the
matching release section, not the historical notes for another version.

## 8. Regeneration, validation and provenance

### Edit the material

- Titles/short/full descriptions: `docs/store_listing/*.md` (three blocks per locale).
- Headlines/subtitles/alt text: `docs/store_listing/graphics.json` (one entry per locale).
- Scenarios, fixture, artwork layout and capture order: `scripts/tests/store_assets.gd`.
- Locale mapping, upload validation and ZIP creation: `tools/build_store_listings.py`.
- Fonts: `tools/build_locale_fonts.py` now also reads the marketing captions.

For new caption characters, regenerate the existing per-script font subsets from
the licensed Noto source fonts, then let Godot import the changed resources:

```sh
python3 tools/build_locale_fonts.py /path/to/noto-source-fonts
godot --headless --path . --editor --import
```

`--translate` is an explicit authoring operation: it replaces non-EN/ES full
description drafts and fills missing graphics locales through the existing online
translator. It preserves titles/short descriptions and existing graphics edits.
**Do not run it over native-reviewed full descriptions without backing up those edits.**
Normal checking, capture and packaging do not call a translation service.

### Review one locale without replacing the final set

```sh
xvfb-run -a godot --audio-driver Dummy --path . res://scenes/tests/store_assets.tscn -- --lang=ar --no-telemetry
```

This writes only `build/store_capture/` preview material. It does not publish a
partial locale set into `docs/store_assets/` or replace its manifest. Run without
`--lang` after approval to publish the complete generated set locally.
Run only one capture process per checkout; staging filenames and the synthetic
save are shared. Use separate workspaces if captures need to run concurrently.

The generator resets a separate fixture for every image/language, uses fixed seeds,
checks real dispatches and scroll positions, validates font coverage and caption
bounds, rejects non-rendering headless use, and checks that the real save hash did
not change. Telemetry is suppressed by the test-scene guard and `--no-telemetry`.
The synthetic save path is selected before fixture interactions; production tests
and capture scripts remain excluded by `export_presets.cfg`.

All renders must finish successfully before final files are replaced. Each file
is staged and renamed; the manifest is written last. This is **not** a transactional
filesystem-wide rollback if a disk error interrupts publication. Packaging fails
closed on mismatched hashes/missing files; regenerate after repairing the error.
Only the explicitly named old gallery PNGs are retired; unrelated files are not deleted.

`docs/store_assets/manifest.json` records version, Godot version, commit/dirty flag,
fixed seed/day, scenario, raw-source path, localized copy and SHA-256 for each output.
The package validator checks image sizes/color type, complete locale sets, file
order, alt text and hashes. Changed captions require a new capture, not reuse of
stale images. Exact pixels can vary between GPU/font-renderer versions; deterministic
scenario state is not a cross-platform pixel-hash guarantee.

### Regression commands

```sh
python3 -m unittest discover -s tools/tests -v
python3 tools/check_repository.py
godot --headless --path . res://scenes/tests/test_runner.tscn -- --quick
python3 tools/build_store_listings.py --package
```

Review real-size images and thumbnails, not only passing tests. Inspect Arabic
shaping/direction, Hindi marks, CJK glyphs and long German/French captions. Also
compare representative screenshots against the actual Android release on a phone
and tablet. Desktop rendering does not prove touch ergonomics, TalkBack, haptics,
safe areas, performance or the native SDKs' data behavior on those devices.

## 9. Phase review record

| Phase | Review and resulting correction |
|---|---|
| Messaging | Checked feature counts against code and text lengths for all 15 locales. Removed obsolete no-network/no-collection promises; made daily play explicitly local |
| English creative proof | Reviewed first-three captures, full images and contact sheet. Changed attack timing to capture troops before arrival; fixed atlas/cosmetic scrolling; used the real dark theme so white base-shape frames remain visible; removed the banner's clipped HUD and moved branding away from the action |
| Localization | Added caption glyphs to Noto subsets; shortened the Russian campaign headline, fixed RTL artwork placement, and rewrote incorrect/awkward translated game terminology and expedition rules. The generator checks every rendered locale for fit/glyphs; native-speaker approval remains a publication gate |
| Packaging and QA | Added offline field/image/hash checks, regression tests, explicit locale mapping, tablet outputs, alt text and the self-contained ZIP |
| Measurement preparation | Defined a baseline and controlled test process below. No Console experiment or acquisition result is claimed |

The operational validation result for the generated delivery is recorded in
`docs/store_assets/validation.md`. Its hardware/native-language/Console limitations
remain applicable even when automated checks pass.

## 10. Measure before expanding the campaign

1. Record the publication date and current store visitors, acquisitions and listing
   conversion using Play Console's definitions. Save the original gallery as the baseline.
2. Segment by listing language/country and traffic source where reports support it;
   do not mix an advertising spike with organic conversion and call it a creative win.
3. At sufficient traffic, test the first screenshot or first-three sequence as one
   variable. Keep the title, icon and other images fixed during that experiment.
4. Choose the decision metric and stopping rule before starting; use Console's
   experiment confidence reporting rather than picking a winner after a few installs.
   With very low traffic, collect qualitative feedback instead of declaring significance.
5. Ask unfamiliar players what the game is, how to send troops and what they would
   unlock next after viewing the gallery. Correct misleading expectations first.
6. Monitor available retention/crash reports after release. Better store conversion
   is not evidence of better retention. Existing aggregate session analytics do not
   provide persistent-user retention cohorts; no new tracking identifier was added.
7. Test a simplified icon or a different headline only after the gallery has a useful
   baseline. A short real-gameplay video is a later creative project, not a requirement
   to use this package. No video, paid campaign or automated publishing was added.

## References

- [Google Play preview assets and screenshot guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Google Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Categories and tags](https://support.google.com/googleplay/android-developer/answer/9859673?hl=en)
- [Live listing](https://play.google.com/store/apps/details?id=macarronesc.invadeio)
- Internal: `docs/PLAY_STORE.md`, `docs/RELEASES.md`, `docs/ANALYTICS.md`, `docs/privacy-policy.html`.
