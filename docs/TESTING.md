# Testing and validation

[Documentation](README.md) · [Development](DEVELOPMENT.md) · [Architecture](ARCHITECTURE.md)

Run commands from the repository root with Godot **4.7.2** on `PATH`. Import once
after a fresh clone or resource change:

```sh
godot --headless --path . --editor --import
```

Tests return a nonzero exit status on failed assertions. A passing desktop run
does not certify mobile ergonomics, performance, native SDKs, or store compliance.

## Choose checks for your change

| Change | Suggested checks |
|---|---|
| Guide prose, navigation, or README images | Review links/anchors, English prose, alt text, GitHub rendering, `git diff --check`; check store assets if referenced |
| Website or guides published on Pages | [Website checks](WEBSITE.md#run-and-validate): unit tests, production build/link checks, and browser/accessibility checks |
| Gameplay, economy, or data | Python/repository checks, full Godot suite, relevant balance simulations |
| UI, language, fonts, or accessibility | Quick suite plus `--ui`; add wide/rotation/gesture checks and physical-device review as applicable |
| Save, settings, or lifecycle | `--mobile` plus full suite and the [device checklist](PLATFORM_INTEGRATION.md#physical-device-checklist) |
| Build, native plugin, or workflow | Python tests, repository/security checks, platform builds, and artifact validation |
| Marketing copy or graphics | [Store validation and capture workflow](PLAY_STORE_UPDATE.md#8-regeneration-validation-and-provenance) |

New logic and bug fixes should include a small regression test. Add GDScript
checks to [test_runner.gd](../scripts/tests/test_runner.gd) or suitable existing
test scenes; add tool checks under [tools/tests/](../tools/tests/).

## Repository and Python checks

```sh
python3 -m unittest discover -s tools/tests -v
python3 tools/check_repository.py
git diff --check
```

The Python suite covers store validation, credential/package guards, and release
workflow behavior using disposable fixtures—not production credentials. Install
JDK 17 (`keytool` and `jarsigner`) to exercise the signing regression; without it,
that test is skipped locally. CI requires those tools and does not permit the
skip. Never provide a real signing key to a test.

The font checks use `fonttools==4.57.0` (installed explicitly in CI); without it they
are skipped locally. The export-identity integration check similarly needs Godot on
`PATH`. Run both before changing fonts or candidate packaging. The artifact-size
tests cover compressed versus expanded totals, PCK accounting, and rejection of
invalid/development resources. Custom-engine promotion additionally requires testing
the actual [exported candidates](RELEASES.md#main-releases-and-manual-validation),
not only this editor-based suite.

CI also runs pinned Gitleaks, actionlint, and ShellCheck. Maintainers can install
the checksum-verified versions with
[tools/install_security_tools.sh](../tools/install_security_tools.sh). A clean
credential scan does not prove that every possible secret is absent.

When changing `NOTICE` or third-party licenses, regenerate the bundled text with
`python3 tools/build_notices.py` and review its diff. Do not regenerate unrelated
assets as a prerequisite for a prose-only change.

## Godot regression suites

```sh
# Complete mechanics, progression, geometry, UI, audio, privacy, and persistence checks.
godot --headless --path . res://scenes/tests/test_runner.tscn

# Focused regressions: combat packets, economy, migration, themes, UI, invasions, and locales.
godot --headless --path . res://scenes/tests/test_runner.tscn -- --quick

# Focused save, settings, haptics, and application-lifecycle checks.
godot --headless --path . res://scenes/tests/test_runner.tscn -- --mobile
```

All modes also exercise privacy-safe local HTTP delivery tests. They do not send
real analytics to Aptabase. Results are printed to the console and written to
`user://test_results.txt`; use the process exit code as well as that report.

## Balance and progression simulations

For behavior-preserving refactors, record a baseline **before changing runtime
scripts**, then compare afterward using the same engine, machine, and local day:

```sh
mkdir -p /tmp/opencode
godot --headless --path . res://scenes/tests/refactor_check.tscn -- --record=/tmp/opencode/invade-baseline.json
godot --headless --path . res://scenes/tests/refactor_check.tscn -- --compare=/tmp/opencode/invade-baseline.json
```

This compares built levels in every language/orientation, packet formations, and
victory results/save state for first clears and replays across all modes. Daily
missions depend on the local date, so this is a before/after aid, not a timeless
golden fixture. Run the normal suites too: these signatures do not measure frame
times, input behavior, or rendered pixels. Music cache tests in the normal suite
compare PCM bytes and loop boundaries, exercise corrupt/unwritable caches, and
print cold/warm timings without a hardware-dependent timing assertion.

```sh
# 720 campaign simulations, plus expedition/invasion samples.
godot --headless --path . res://scenes/tests/balance_check.tscn

# Representative invasion fronts across regions and difficulty tiers.
godot --headless --path . res://scenes/tests/balance_check.tscn -- --invasions

# Victory → upgrade → next level, and defeat → upgrade → retry through real buttons.
godot --headless --path . res://scenes/tests/balance_check.tscn -- --flow
```

The campaign run uses four upgrade strategies and six decision cadences for
each of 30 levels. It checks accessibility of progression for the simulated
strategy, not player retention or universally optimal balance. Test with new
players before making broader claims.

## Visual and interaction checks

These commands require a rendering display. Run directly on desktop, or prefix
them with `xvfb-run -a` on Linux without a display. Do not substitute `--headless`
when you need images.

```sh
# Real UI flows in all 15 languages; English/Spanish cover both appearance themes.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --ui

# Preview one language's UI flows.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --ui --lang=ar

# Invasion map/region/front UI in English and Spanish, light/dark.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --invasion-ui

# 1920×1080 layouts and resizing during battle.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --wide-ui

# Mobile-sized portrait ↔ landscape rotation with moving troops and overlays.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --rotate-ui

# Touch/mouse scrolling and troop-drag gestures in both orientations.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --gestures
```

Images from these UI checks are written to `user://*.png`, not to the tracked
store gallery. See [Development](DEVELOPMENT.md#saves-and-independent-worktrees)
for the user-data directory. Inspect full-size captures as well as thumbnails:
automated fit/glyph checks cannot approve translation quality or usability.

### Performance captures

```sh
XDG_DATA_HOME=/tmp/opencode/invade-perf-data LP_NUM_THREADS=4 xvfb-run -a \
  godot --path . --audio-driver Dummy --disable-vsync \
  res://scenes/tests/performance_check.tscn -- --out=/tmp/opencode/invade-perf
```

This reuses the deterministic store fixtures without replacing store artwork.
It captures six real scenes and all three troop styles (including a 2× preview),
and writes PNGs plus `metrics.json` with average draw calls and elapsed frame time.
Run the same command/environment before and after a rendering change. Rendering
must be enabled; headless results cannot measure draw calls or pixels.
The software renderer's frame times are not mobile FPS or battery measurements.
See [performance validation](PERFORMANCE.md) for the optimization results and
the remaining physical-device release gates.

## Store material checks

```sh
# Offline text, locale, field-length, and alt-text checks; no writes.
python3 tools/build_store_listings.py --check

# Also verify image formats, caption provenance, and hashes; write an upload ZIP.
python3 tools/build_store_listings.py --package
```

Packaging reads the committed graphics and writes `build/play-store-listing.zip`;
it does not publish to Play. A full capture run **replaces tracked image files and
the manifest**. Use the [store guide](PLAY_STORE_UPDATE.md) for generation,
single-locale previews, source-image provenance, and owner publication gates.

Do not treat the dated [store validation record](store_assets/validation.md) as
the result of a new run. Exact pixel hashes can vary by rendering environment.

## Save and telemetry isolation

Test-scene startup selects `user://automation_startup_save.json` before autoloads
read player data, then each suite switches to its own fixture save. Store captures
also compare the normal player-save hash before and after generation. Headless
runs, editor tooling, test scenes, and `--no-telemetry` suppress provider startup.
Manual size candidates are different: they respect the privacy toggles and tag
their telemetry for device validation; see [Analytics](ANALYTICS.md).
Ordinary editor-launched gameplay can also send data if the settings allow it.

Worktrees can still share Godot user data. Do not run these commands concurrently
against the same data directory or run multiple store generators in one checkout.
Use distinct user-data roots for independent runs, and inspect outputs from the
correct run. Never restore a test fixture over a real player's save.

## Manual review and CI scope

Before a UI or release change, inspect small and large displays, both orientations,
safe areas, long text, RTL, alternate controls, contrast, audio, haptics, offline
play, lifecycle interruptions, and backups. Use the
[physical-device checklist](PLATFORM_INTEGRATION.md#physical-device-checklist).
Accessibility labels and desktop screenshots alone do not prove TalkBack or
VoiceOver support on mobile.

The [CI workflow](../.github/workflows/ci.yml) runs Python/security checks, the full
Godot suite on Linux, locale/wide UI checks, store generation, Android exports,
and an iOS build with quick regressions. Rotation, gesture, and the longer balance
simulations are available locally but are not all run by the current workflow.
See [Releases](RELEASES.md) for artifact verification and signing boundaries.

Document warnings honestly. For example, the October 28 store validation recorded
passing suites with shutdown resource-leak warnings; a passing exit code does
not mean a warning-free engine run.
