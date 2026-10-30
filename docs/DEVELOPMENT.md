# Development guide

[Documentation](README.md) · [Architecture](ARCHITECTURE.md) · [Testing](TESTING.md) · [Contributing](../CONTRIBUTING.md)

Start here to run invade.io or make your first change. The normal workflow uses
the checked-in assets; rebuilding geography, fonts, or store graphics is optional.

## Prerequisites

| Tool | Needed for |
|---|---|
| [Godot 4.7.2, standard editor](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) | Importing, editing, running, and GDScript tests; no .NET SDK needed |
| Git | Cloning and contributing |
| Python 3.10+ | Repository tools and Python tests; use a current maintained Python release |
| A rendering display | Playing and visual checks; Linux CI uses `xvfb-run` for the latter |

Linux and macOS are the current development environments. The vendored Sentry
extension includes Android, iOS, Linux, and macOS binaries; Windows/Web binaries
and library entries are not included. Do not assume those exports work without
restoring compatible upstream components and testing them.

Export templates are needed **only for exports**. Android SDK/JDK setup, macOS
with Xcode for iOS, and production signing are separate from normal development.
No account, backend, production keystore, or store credential is required to run
the game or contribute.

## Clone, import, and run

```sh
git clone --branch dev https://github.com/macarronesc/invade.io.git
cd invade.io
godot --version
godot --headless --path . --editor --import
godot --path . -- --no-telemetry
```

`godot --version` should report 4.7.2. If your executable has another name or is
not on `PATH`, substitute its full path. On macOS, the standard application
binary is normally `/Applications/Godot.app/Contents/MacOS/Godot`.

To edit, import `project.godot` from Godot's project manager or run:

```sh
godot --editor --path .
```

Press **F6** to run the current scene or **F5** for the project. Its main scene is
[main_menu.tscn](../scenes/ui/main_menu.tscn), but a new save goes straight into
the first tutorial battle. Mouse dragging emulates touch on desktop.

**Privacy:** the CLI launch above disables telemetry for that run. Ordinary
gameplay launched from the editor or MCP is a Debug game and can send data under
the privacy settings. For editor play, add `--no-telemetry` to **Project Settings
→ Editor → Run → Main Run Args** locally, or use the CLI command. Do not commit
personal editor/run configuration. Headless runs and test scenes suppress
providers automatically; see [Telemetry](ANALYTICS.md#development-and-test-runs).

## Make a focused change

1. Create a branch from `dev` in your fork or a separate worktree.
2. Use the [source map](ARCHITECTURE.md#where-to-make-a-change) to find the shared
   implementation and its callers. Keep the existing layers and naming.
3. Add a regression test for new logic or a bug fix. Use the relevant existing
   test scene or Python test module rather than adding a second test framework.
4. Run the [appropriate checks](TESTING.md#choose-checks-for-your-change), update
   the affected documentation, and inspect `git diff` before opening a PR.

Use tabs for GDScript indentation, follow the surrounding Python/shell style,
and use stable translation keys for visible text. Reuse `UIThemeHelper`, icons,
and existing page patterns rather than embedding a second theme in a screen.
New guide prose and explanations should be in English; do not rename stable
identifiers or translate existing code comments as unrelated cleanup.

## Saves and independent worktrees

Normal desktop play writes to Godot's `user://` directory. Open it through
**Project → Open User Data Folder**. On Linux, its default location is
`~/.local/share/godot/app_userdata/invade.io/`; other platforms use Godot's
[platform-specific paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).

**Worktrees separate source files, not user data.** Two checkouts with the same
project name can use the same local save and test-output filenames. Back up
progress before manual experiments, and do not run tests/captures concurrently
against shared user data. On Linux, you can isolate an entire run with a separate
data root:

```sh
XDG_DATA_HOME="$PWD/build/dev-user-data" godot --path . -- --no-telemetry
```

The [test scenes](TESTING.md#save-and-telemetry-isolation) select dedicated save
files before loading fixtures, but concurrent suites should still use distinct
data roots. Do not commit saves, private logs, `.godot/`, or generated `build/`
contents. Debug mobile app identifiers also differ from production; see
[installation safety](PLATFORM_INTEGRATION.md#installation-and-save-safety).

## Localization

The runtime reads stable keys from [locale/strings.csv](../locale/strings.csv).
[LanguageCatalog](../scripts/data/language_catalog.gd) defines supported codes,
system-locale aliases, font scripts, and RTL direction. City names come from
[geo.json](../assets/data/geo.json), with English fallback.

### Change existing text or add a key

1. Edit the CSV while preserving its header, unique keys, quoting, formatting
   tokens such as `%s`/`%d`, and token order. Add English/Spanish source text and
   have translations reviewed for meaning and layout.
2. Reviewed overrides live in
   [tools/locale_overrides.py](../tools/locale_overrides.py). Update the override
   as well when changing a value it owns; otherwise regeneration can restore the
   previous text.
3. If you want machine-generated drafts for empty cells, explicitly run:

   ```sh
   python3 tools/build_locale_csv.py --translate --overrides
   ```

   This contacts a public translation service, writes the CSV and an ignored
   cache, and reapplies overrides. It is an authoring step, not a read-only
   validator or a substitute for native-speaker review.
4. Rebuild font subsets if the text introduces glyphs not already covered, then
   reimport with Godot and run glyph/layout checks from [Testing](TESTING.md).
   Review the generated `.translation` files in your diff.

### Rebuild font subsets when needed

The optional font tool requires `fonttools` and licensed Noto source fonts. Use a
virtual environment rather than changing the project's runtime dependencies:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install fonttools==4.57.0
.venv/bin/python tools/build_locale_fonts.py /path/to/noto-source-fonts
godot --headless --path . --editor --import
```

The directory must contain `notosans.ttf`, `notosansarabic.ttf`,
`notosansdevanagari.ttf`, `notosanssc.ttf`, `notosansjp.ttf`, and `notosanskr.ttf`
from the [Google Fonts Noto families](https://fonts.google.com/noto). Rename local
copies of downloaded source fonts to the expected filenames as needed. The tool
includes UI text, city names, store captions, and native language-picker labels.
It also pins the unused width axis at its existing default while retaining variable
weights; do not generate static-weight replacements or drop shaping tables.
Preserve [OFL notices](../assets/fonts/LICENSE-OFL.txt). Inspect Arabic shaping,
Hindi marks, CJK glyphs, long labels, and RTL behavior—not just missing glyphs.
Maps and the brand stay unmirrored in Arabic.

Adding a language also reaches the catalog, project translation registration,
font mapping, tools, store locale mapping, and tests. Do not advertise support
until those paths and native-language review are complete.

## Geography and brand assets

Geography is already checked in; do not rebuild it for ordinary gameplay work.
[build_geo_data.py](../tools/build_geo_data.py) downloads Natural Earth data and
rewrites `assets/data/geo.json`. Its optional dependencies are `pyshp` and
`shapely`:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install pyshp shapely
.venv/bin/python tools/build_geo_data.py /path/to/natural-earth-cache
```

Keep city keys stable: levels, atlas progress, and saves reference them. Review
the complete data diff and run geography, localization, and save-compatibility
tests after regeneration. [add_geo_names.py](../tools/add_geo_names.py) can update
localized city names from a populated-places DBF without rebuilding the geometry;
it also writes `geo.json`.

The [brand asset inventory](../assets/brand/README.md) identifies launcher icons
and the boot splash. For promotional art, follow the existing
[Play Store capture workflow](PLAY_STORE_UPDATE.md#8-regeneration-validation-and-provenance).
Full capture runs replace tracked graphics; locale previews write only to
`build/store_capture/`. Do not manually edit generated PNGs or their hashes.

## Troubleshooting

| Symptom | Check |
|---|---|
| Unknown classes, missing textures, or failed first test run | Confirm Godot 4.7.2 and complete `--editor --import` before running scenes |
| Native-extension loading fails | Check OS/architecture against the bundled Sentry libraries; do not disable safeguards to hide an unsupported platform |
| The game opens directly in battle | Expected on a new save; finish or leave the tutorial to reach the menu |
| A changed translation is not visible | Reimport the CSV, confirm the active language, and check reviewed overrides |
| A square appears instead of a character | Regenerate the relevant font subset and run glyph checks |
| Capture is blank or rejects `--headless` | Use a rendering display or Linux `xvfb-run`; headless mode cannot produce these graphics |
| Progress appears to be shared across checkouts | Isolate user data, not just source directories |
| APK/IPA does not update the Play installation | Debug installs intentionally use a different application identifier |

For mobile exports, continue with [Platform integration](PLATFORM_INTEGRATION.md)
and [Google Play publishing](PLAY_STORE.md). For private security concerns, use
[SECURITY.md](../SECURITY.md), not a public issue or log upload.

## Website development

The optional [Astro/Starlight website](WEBSITE.md) uses Node.js 24 and npm inside
`website/`. These are **not** game development prerequisites. Keep web dependencies
and generated output in that isolated directory; do not change game scripts or
regenerate store captures just to work on the website. Canonical guide edits are
published by the website build and should pass its link/content checks.
