# Store material — validation record

## Release 1.0.0 revalidation

Date: 27 November 2026. Target source version: **1.0.0** (Android versionCode 9).

- Full Godot capture of all 19 locales: 152 phone images, 76 tablet images and one
  feature graphic, published with `build_store_listings.py --publish`. The manifest
  records version 1.0.0 and the clean capture commit.
- 65 of the 229 PNGs changed. Conquer, tactics, upgrades, cosmetics, tablet invasions,
  tablet cosmetics and tablet atlas captures and the feature graphic are byte-identical to the
  previous capture (one Japanese daily capture differs by a single pixel).
  The changes are:
  - the invasions headline (59 regions, 177 fronts) in the 15 languages that still
    carried the old 36/108 counts or a mixed 36/177 caption;
  - the atlas subtitle (28 achievements) in every language;
  - the campaign phone and tablet captures in the 15 original languages, which now
    show the Ascension teaser line ("Ascension opens when every campaign level is
    cleared") above the map. The four newest languages were already captured after
    that change.
- The 1.0.0 Play release notes cover all 19 locales and fit the 500-character limit
  (checked by `tools/tests/test_store_assets.py`, which now also covers `ar`, `id`,
  `vi`, `uk` and `th`; this fixed an existing 502-character Indonesian 0.4.0 block).
- Full regression suite: 8,871 passed, 0 failed (same count as `dev` before the version
  bump). Quick: 7,362 passed. Mobile: 1,310 passed. Balance, ascension, invasions,
  threat, flow, UI (all languages and Arabic), invasion-UI, wide-UI, rotation and
  gestures checks passed. Existing Godot shutdown resource-leak warnings remain.
- Python tools suite: 53 tests. `tools/check_repository.py`, `tools/check_release.py
  --base origin/main`, actionlint, ShellCheck and Gitleaks (history and working tree)
  pass. Website: build (28 pages), unit tests and 68 browser tests pass.
- Not covered: physical-device testing, TalkBack/VoiceOver, native-speaker review of the
  draft translations and the Play Console checks listed in `docs/RELEASES.md`.

## Language expansion: Polish, Ukrainian, Traditional Chinese, Thai

Date: 24 November 2026. Source version: **0.5.0** (no version change).

- The four languages were captured on their own (`--lang=pl,th,uk,zh_TW`) and merged
  with `build_store_listings.py --publish --lang ...`. The manifest records the clean
  commit in `partial_updates`; the other 15 languages' entries and files were not touched.
- Before/after check for the original languages: English, Arabic and Japanese phone
  and tablet captures (36 images) are byte-identical to captures taken before any
  change on the same machine and renderer.
- Contact sheets and rendered UI flows for the new languages were reviewed (headlines
  fit, Thai tone marks and Traditional Chinese glyphs render, no clipping). This is not
  native-speaker approval: every new language is marked `draft` in
  `assets/data/languages.json` and its UI copy, store text and captions began as
  machine drafts that were corrected by hand for game terminology.
- Full regression suite: 6,375 passed, 0 failed (all 19 languages for glyph coverage,
  placeholders and UI fit). Python tools suite: 50 tests. `--ui`, `--wide-ui`, both launch
  checks and `refactor_check` passed; all 32 pre-existing refactor signatures match the
  pre-change baseline (the 8 new language/orientation signatures are new).
- Capture time is about 40 seconds per language on a software renderer.

## Release-candidate revalidation

Date: 9 November 2026. Target source version: **0.5.0**.

- Full Godot capture completed for 15 locales: 120 phone images, 60 tablet images,
  and one feature graphic. The manifest records version 0.5.0, commit `d2c36a2`,
  and a clean working tree at capture time.
- 105 of the 181 PNGs changed: the four menu screenshots per locale and three
  tablet menu screenshots per locale. The battle screenshots (conquer, tactics,
  invasions, daily) and the feature graphic are byte-identical to 0.4.0. The menu
  changes are the new header heart (Ko-fi support) button, visible square/diamond
  base shapes in the Army tab, and a larger campaign map because the level card is
  now a scrollable area in portrait. English/Arabic phone and English tablet
  captures were reviewed; no clipping, missing-text, or blank-image regression.
- `python3 tools/build_store_listings.py --check` and the Python tools suite
  (38 tests) passed.
- Full regression suite: 6,128 passed, 0 failed. Quick: 4,644 passed. Mobile:
  1,039 passed. Balance, invasions, flow, UI (en/ar), invasion-UI, wide-UI,
  rotation, gestures, and launch (capture/slow-startup) checks passed. Existing
  Godot shutdown resource-leak warnings remain.
- `refactor_check` against `v0.4.0`: formations and all other signatures match;
  level and reward signatures differ only because of the documented 0.5.0 fixes
  (conquest rule rotation, invasion/daily payout correction, replay bookmark).

## Previous release-candidate revalidation (0.4.0)

Date: 1 November 2026. Target source version: **0.4.0**.

- Full Godot capture completed for 15 locales: 120 phone images, 60 tablet images,
  and one feature graphic. The manifest records version 0.4.0, commit `050f96c`,
  and a clean working tree at capture time.
- All 181 PNGs changed from the 0.3.2 set: the new menu logo, batched disc
  rendering, and reused map geometry alter the captured scenes. English and
  Spanish contact sheets and the feature graphic were reviewed; no layout,
  clipping, missing-text, or blank-image regression was found.
- `python3 tools/build_store_listings.py --check` and `--package` passed. The
  package is generated under ignored `build/` and is not published to Play.
- Full regression suite: 6,052 passed, 0 failed. Quick: 4,592 passed. Mobile:
  1,029 passed. Launch, UI, wide-UI, rotation, and gesture checks passed. Existing
  Godot shutdown resource-leak warnings remain.

## Earlier release-candidate revalidation (0.3.2)

Date: 29 October 2026. Target source version: **0.3.2**.

- Full Godot capture completed for 15 locales: 120 phone images, 60 tablet images,
  and one feature graphic. The manifest now records version 0.3.2 and the capture
  commit with `working_tree_dirty=true`.
- All 181 PNGs were byte-for-byte identical to the previously reviewed 0.3.1 set;
  no new visual review was needed for this version-only capture refresh.
- `python3 tools/build_store_listings.py --check` and `--package` passed. The
  package is generated under ignored `build/` and is not published to Play.
- The complete regression suite passed (5,233 passed, 0 failed); existing Godot
  shutdown resource-leak warnings are recorded below.

The earlier detailed design/visual review and test record follows.

## Previous full validation (28 October 2026; source 0.3.1)

Date: 28 October 2026. Target source version: **0.3.1**.

## Execution results

| Check | Result |
|---|---|
| All 15 titles, short descriptions and full descriptions | Pass: within 30 / 80 / 4,000 characters |
| Localized captions and alt text | Pass: complete language coverage; alt text ≤140 characters |
| Godot quick regression suite | **3,773 passed, 0 failed** |
| Godot complete regression suite | **5,233 passed, 0 failed** |
| Complete Python suite | **20 passed, 0 skipped**, including image integrity, changed-caption rejection and upload ZIP contents/CRC |
| Repository credential-file check | Pass: 0 failures |
| GitHub Actions workflow lint | Pass: actionlint |
| Final all-language capture | **Pass: 15 languages, 120 phone images, 60 tablet images and one feature graphic** |
| Image dimensions, RGB/RGBA format, file order, caption/alt provenance and SHA-256 | Pass for the complete final set |
| Rejected capture commands | Headless and unsupported-locale invocations return failure without modifying final images |
| Player-save protection | Pass: generator's before/after real-save hash check |

Both Godot regression-suite modes returned success but printed resource-leak
messages during shutdown. These warnings were not investigated as part of this
store-material task; they are not being presented as a warning-free engine test.

## Rendering environment and review

- Godot **4.7.2**, GL Compatibility renderer, Linux Xvfb/Mesa llvmpipe software rendering.
- Eight phone images per language, **1080×1920 RGB8**.
- Four uncaptioned tablet images per language, **1920×1080 RGB8**.
- Feature graphic **1024×500 RGB8**; existing icon **512×512 RGBA**, 86,542 bytes.
- Real gameplay scenes, fixed simulation steps/day/seed, isolated synthetic save.
- First-three attack captures, full images and contact sheets across all 15 languages inspected during design.
- Corrected capture timing, atlas/appearance scrolling, cropped banner HUD,
  Russian headline length, RTL artwork placement/counter direction, a duplicated
  Korean heading used for scrolling, and ambiguous translated expedition rules.
- The appearance image uses the genuine dark theme so white square/diamond base
  frames are visible. Shared phone/tablet alt text describes only content visible in both views.
- Text fit and glyph checks are built into the generator. Explicit on-canvas bounds
  checks supplement nonblank-image checks, which alone cannot detect misplaced text.

Final source filenames, localized text, source scenarios, version, base commit,
working-tree state and SHA-256 image checksums are recorded by a successful complete
run in `manifest.json`. A preview run does not replace that manifest. The final
source image set contains **181 PNGs**, approximately **38.4 MiB** in total. The
base commit is recorded with `working_tree_dirty=true`: the capture was made with
uncommitted changes. This records capture-time provenance, not confirmation that
the material belongs to a published application release.

## Publication gates not covered by these checks

- Native-speaker approval of marketing translations; automated coverage/shaping checks are not linguistic approval.
- Actual Android production build, phone/tablet behavior, performance, TalkBack and native telemetry behavior.
- Current Play Console version, privacy/Data safety answers, consent requirements, target audience and Families settings.
- Publication of the matching privacy policy; nothing was deployed or submitted to Google Play.
- A/B testing, acquisition uplift and retention outcomes. A measurement process is documented, not an experiment result.

See `docs/PLAY_STORE_UPDATE.md` for the full change record, upload order and owner checklist.
