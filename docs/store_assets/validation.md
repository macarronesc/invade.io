# Store material — validation record

## Release-candidate revalidation

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
