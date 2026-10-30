# Telemetry and privacy

[Documentation](README.md) · [Development](DEVELOPMENT.md) · [Release guide](RELEASES.md) · [Security](../SECURITY.md)

Usage statistics and crash reporting are implemented in
[telemetry.gd](../scripts/autoload/telemetry.gd). Gameplay does not require either
provider or an internet connection. There is no project-operated game backend.

This guide describes the current source, not a verification of the installed
store build. Before distribution, match the binary, listing, policy, and Data
safety declarations using the [publication gate](PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate).

## Settings and defaults

**Usage statistics** and **Crash reports** are independently controlled in
**Settings → Privacy**. Both default to enabled for new installations and saves
without the corresponding setting. A saved value always wins, including `false`;
existing saves cannot distinguish an old default from an explicit opt-out, so
the game does not force those values to `true`. No save-format migration is needed.

Disabling a setting stops future capture for that option. Disabling analytics
also discards its unsent queue; a network request already in progress may still
finish. Importing a backup or resetting progress preserves the current privacy
choices. These controls do not individually delete data already received by a
provider.

An enabled default is **not prior consent**. The applicable legal basis, consent
requirements, retention, and store disclosures require owner review for the
regions and SDK configuration being distributed. A settings toggle or store
description alone does not establish compliance.

## Providers and configuration

| Provider | Integration | Role |
|---|---|---|
| [Aptabase](https://aptabase.com/) | [Vendored Godot client](../addons/aptabase/) | Usage events; the `A-EU-*` app key selects the EU endpoint |
| [Sentry](https://sentry.io/) | [Vendored Godot GDExtension](../addons/sentry/) | Native/GDScript crash and error reports, including available ANR/session-health information |

Public ingestion identifiers are configured at the top of `telemetry.gd`:

```gdscript
const APTABASE_KEY := "A-EU-..."
const SENTRY_DSN := "https://...@o....ingest.sentry.io/..."
```

These are client identifiers, not administrative credentials. With empty values,
the corresponding provider stays disabled and gameplay remains functional. Never
embed provider administration tokens in source, exports, or CI-generated client
configuration. Public ingestion endpoints can receive fabricated events; monitor
quotas and abuse in the provider dashboards. Pricing/limits can change; consult
the providers rather than relying on an old repository estimate.

The Sentry distribution is trimmed to Android, iOS, Linux, and macOS. Windows/Web
exports require restoring compatible upstream binaries and extension entries,
followed by platform testing. See the [dependency inventory](RELEASES.md#dependency-inventory).

## Development and test runs

The editor tooling itself, `scenes/tests/` executions (including windowed tests),
headless runs, and `--no-telemetry` do not initialize providers. Changing privacy
settings in those contexts does not bypass the guard.

**Playing the game from the editor or MCP is different:** it is a Debug game
process and can send data if privacy settings permit. For manual play without
provider traffic:

```sh
godot --path . -- --no-telemetry
```

`--telemetry-debug` prints the first-party event stream in Debug runs; it does
**not** disable transmission. Do not share private device logs. Tests use a local
HTTP server and synthetic identifiers to exercise the client without sending
real events to Aptabase.

## Debug versus production

Both providers use `OS.is_debug_build()`, not branch names, file formats, signing,
or package identifiers. Aptabase sets `systemProps.isDebug`; Sentry uses the
`debug` or `production` environment. Manual size candidates are the exception:
they use the `size_candidate` environment, an `<version>-size` Aptabase app
version, and a `build_channel=size_candidate` event property. They still respect
the on-device privacy toggles and share the configured key/DSN rather than using
separate provider projects; filter by those tags in the dashboards.

| Execution or CI artifact | Engine build | Sentry environment |
|---|---|---|
| Gameplay from the editor/MCP or CLI editor binary | Debug | `debug` |
| Ordinary CI APK, including the GitHub release attachment | Debug | `debug` |
| CI candidate AAB, including an unsigned PR candidate | Release | `production` |
| IPA from a push to `main` | Release | `production` |
| Ordinary IPA from PRs, other branches, or manual workflow runs | Debug | `debug` |
| Opt-in size-candidate Release APK/IPA (`.size` identifier) | Release | `size_candidate`; Aptabase events carry `build_channel=size_candidate` |

Manual exports follow the selected build mode: an AAB exported with
`--export-debug` is Debug; an APK exported with `--export-release` is Release.
Test/headless suppression still takes precedence over this classification.

When analytics starts, `session_start` is flushed immediately; subsequent events
use the normal batching interval. Successful transport is not printed in Release.
Transport failures appear as local Godot/Xcode warnings and are not attached as
Sentry logs (`attach_log = false`).

For iPhone diagnosis, use a Debug IPA from a branch/manual validation run. Look
for `[Aptabase] initialized`, `[Aptabase] sent`, or request failures in the device
console. The Debug CI build retains the native backup picker; its logs may contain
server responses and must not be posted publicly without careful review.

## Event reference

First-party custom properties contain short strings and numbers; booleans are
converted to `0`/`1`. They do not include names, email, free-form player text, or
project-defined persistent account/device identifiers.

| Event | Main properties |
|---|---|
| `session_start` | `first_run`, `player_level`, `total_stars`, `invasion_stars`, `language` |
| `session_end` | `duration_s`, `duration_bucket`, `reason`, `levels_started`, `levels_finished`, `tabs` |
| `tab_view` | `tab`, `previous_tab` |
| `screen_view` | `screen`, such as `settings` |
| `level_start` | `level`, `mode`, `attempt`, `prev_stars`, `first_clear`, `player_level`, `total_stars`, `invasion_stars`, `upgrade_sum`, `combat_upgrades`, `speed`; campaign/invasion events also have `continent`, `level_no` |
| `level_end` | Level context plus `outcome`, `duration_s`, `real_seconds`, `duration_bucket`, `stars`, `is_replay`, `first_clear`, `new_medal`, `new_record`, `new_cities`, `captures`, `gold`, `player_level_after` |
| `upgrade_bought` | `upgrade`, `new_level`, `coins_after`, `player_level` |
| `reward_claimed` | `kind` (`daily`/`achievement`), plus `amount`/`streak` for daily rewards or `id` for achievements |

Size-candidate builds add `build_channel=size_candidate` to every event so they can
be filtered out of production dashboards.

`mode` is `campaign`, `daily`, `conquest`, or `invasion`; `outcome` is `win`,
`loss`, or `quit`. `attempt` counts attempts at a level within the current session,
not an identity across sessions. The current achievement callback emits the
`reward_claimed` event on **unlock**; do not interpret it as proof of manual gold
collection. `level_end.duration_s` is simulation time; `real_seconds` measures
elapsed wall-clock time since the recorded start, including interruptions.

Aptabase adds system context such as language, OS, app/SDK version, and device
model, plus a temporary session identifier that changes after restart or an hour
of inactivity. HTTP providers also receive the connection IP; Aptabase can infer
approximate country. Review native SDK payloads and dashboard settings rather
than assuming the first-party property table describes every transmitted field.

If the process terminates abruptly, `session_end` cannot be relied on. A crash
report may still be available when reporting is enabled, but analytics session
durations will be incomplete.

## Interpreting the data

- **Session duration:** group `session_end` by `duration_bucket` or sum
  `duration_s` in an export. Missing end events are a known limit.
- **Difficulty:** group `level_end` by `level` and `outcome`. Separate losses and
  quits; segment by `player_level` and `combat_upgrades` before interpreting a
  low win rate as a balance problem.
- **Engagement:** inspect replays, stars, abandonments, time, and mode use.
  Frequent visits combined with frequent quits can indicate friction, not success.
- **Navigation/economy:** use `tab_view`, `screen_view`, `upgrade_bought`, and the
  documented reward-event semantics.
- **Crashes:** Sentry receives `screen`, `level`, `mode`, and `player_level` tags
  plus battle breadcrumbs when enabled. Review release/session health alongside
  native platform reports.

Temporary session IDs do not provide persistent-player cohorts. This integration
does not establish user retention, MAU, or cross-session user funnels. Use store
reports where available, and do not claim retention gains from store conversion
or aggregate sessions. Adding persistent tracking would be a separate privacy
and product decision, not a documentation change.

## Native reporting and publication checks

Sentry starts after loading privacy settings. It disables default PII, attached
logs, scene trees, and tracing, and does not set a game user. Do not add
`SentrySDK.set_user()` or project-specific identifiers without an explicit privacy
review. Providers can still receive connection IPs; verify IP removal and actual
retention in their dashboards.

Early engine-startup crashes before initialization are outside this integration;
Play Console and App Store Connect reports remain relevant. Native stack traces
need matching debug symbols uploaded using `sentry-cli`; readable symbols are not
implied by a passing export. GDScript stack tracking is enabled in the project.
Measure any performance impact on low-end hardware before changing that setting.

Before distribution:

- Review the actual APK/AAB/IPA and native provider behavior on physical devices.
- Publish the matching [policy source](privacy-policy.html) at the existing public
  URL, after owner review; a local edit is not a deployed policy.
- Review Play Data safety for app activity, diagnostics, IP-derived location, and
  session/SDK identifiers, including currently distributed tracks in scope.
- For App Store Connect, review Usage Data, Diagnostics, Coarse Location, and
  tracking declarations against the effective provider configuration.
- Verify retention, deletion/contact handling, consent obligations, and audience
  settings; do not copy provider assumptions into store forms.
- The bundled iOS Sentry framework has no `PrivacyInfo.xcprivacy`. Before App Store
  distribution, verify current SDK requirements and supply the appropriate
  privacy manifest. The existing unsigned SideStore workflow is not App Store
  readiness certification.
