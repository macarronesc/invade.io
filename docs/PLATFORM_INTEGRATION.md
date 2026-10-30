# Android and iOS integration

[Documentation](README.md) · [Development](DEVELOPMENT.md) · [Testing](TESTING.md) · [Releases](RELEASES.md)

This guide describes implemented platform behavior and test-build installation.
Android is available on Google Play. iOS currently has unsigned SideStore test
builds, not an App Store or TestFlight distribution workflow.

## Platform and build scope

| Platform | Current configuration |
|---|---|
| Android | Minimum SDK 24 (Android 7.0), target SDK 36; Debug APK and Release AAB export presets |
| iOS | Minimum iOS 15, arm64, native backup picker, unsigned IPA produced on macOS CI |
| Linux/macOS | Development and validation environments; no desktop release preset |
| Windows/Web | Not included in the trimmed Sentry extension; not supported export targets without additional integration work |

Android declares `VIBRATE`, `INTERNET`, and `ACCESS_NETWORK_STATE`. Haptics use
Godot's `Input.vibrate_handheld()` without a dedicated haptic plugin. Network
permissions support optional analytics/crash reports, enabled by default in this
source with independent opt-outs. Gameplay itself remains offline. Read
[Telemetry](ANALYTICS.md) before testing ordinary gameplay with a network connection.

Godot allows resizing and sensor-driven rotation. Menus and battles adapt to
portrait/landscape, with board relayout during battle; daily challenges retain a
canonical board. Generated tablet screenshots show supported layouts, not
physical-device or Play Games on PC certification.

## Installation and save safety

The production identifier is **`macarronesc.invadeio`**. Do not change it: it
identifies the published application and its private storage.

CI Debug APKs and ordinary non-production IPAs use **`macarronesc.invadeio.debug`** so they
do not replace the store installation. They have separate saves. Changing a test
identifier does not migrate old progress automatically; export a backup before
switching installations. Avoid uninstalling the same variant when updating it.

| Artifact | Intended use |
|---|---|
| `invadeio-debug.apk` | Android test installation; not a Play update |
| `invadeio-unsigned.aab` | CI validation candidate; not a signed release to distribute |
| `invadeio.aab` | Owner-approved, signed bundle for manual Play Console upload |
| `invade.io-debug.ipa` | Unsigned Debug iPhone build for SideStore |
| `invade.io.ipa` | Unsigned Release iPhone build from a push to `main`, also for SideStore |
| `invadeio-size-candidate.apk` | Opt-in custom-engine Release test build; disposable certificate and separate `.size` saves |
| `invade.io-size-candidate.ipa` | Opt-in custom-engine unsigned Release iPhone build; separate `.size` saves |

See [Releases](RELEASES.md) for workflow triggers, approval, checksums, and retention.
The [size-candidate workflow](RELEASES.md#validate-the-smaller-engine-without-publishing)
never publishes. Back up candidate progress before replacing an APK signed by a
different disposable certificate; these builds cannot update the store installation.
Contributors never need the production upload key or Apple/store credentials.

### Android

For ordinary development, [run in Godot](DEVELOPMENT.md). For on-device testing,
download a Debug APK from a successful GitHub Actions run and install it through
your device's supported test-installation workflow. Only install artifacts you
trust; Android may require approval for installation from that source.

Local export requires the matching Godot templates, JDK 17, Android SDK, and
Gradle build template. Follow [Google Play publishing](PLAY_STORE.md#local-android-export)
for the tested build sequence and verification commands. AABs are uploaded to
Play Console; they are not directly installable APKs.

### iPhone with SideStore

1. Push your branch or update a PR. CI validates the pushed tip/proposed merge;
   local commits do not trigger it. A multi-commit push builds the latest state,
   not a separate IPA for every intermediate commit.
2. Open **Actions → CI and releases** and select a successful run. Manual runs
   validate only; an ordinary manual run on `main` produces a Debug IPA and does
   not publish a release. Enabling `optimized_templates` instead produces the
   separate Release size-candidate IPA described above, still without publishing.
3. Download `invade.io-debug.ipa` for ordinary branch/PR/manual runs,
   `invade.io-size-candidate.ipa` for an opt-in size-candidate run, or
   `invade.io.ipa` for a push to `main`. Raw artifacts are retained for seven days.
4. Save the IPA in Files. With SideStore and its current VPN/network requirements
   configured, open **SideStore → My Apps → +** and select the file. Follow
   [SideStore's installation guidance](https://docs.sidestore.io/) for signing,
   refresh requirements, and account limitations.

CI does not use Apple signing certificates. SideStore signs with your account
and manages renewal; renewal does not require rebuilding the game. Keep the same
account/variant when updating and back up test progress first. An unsigned IPA
cannot be installed directly as an App Store/TestFlight build.

The preset's `0000000000` Team ID is a placeholder, not a credential. For local
iOS export on macOS, build the native picker in the matching engine mode:

```sh
bash scripts/build_ios_backup_picker.sh Debug
# For a Release export instead:
bash scripts/build_ios_backup_picker.sh Release
```

The script downloads checksum-verified headers and generates the native library
and plugin configuration. Debug/Release ABIs differ; CI selects the matching
mode explicitly. Do not disable the picker just to make linking succeed.

## Persistence and native backups

[GameManager](../scripts/autoload/game_manager.gd) implements shared, versioned
local persistence:

- `save_data()` supplies the document for normal saves and manual exports.
- `write_save()` writes a temporary file before renaming it and reports errors.
- `save_game()` retains `.previous`, exposes failure to the UI, and permits retry
  from Settings. Future save versions block writes instead of being overwritten.
- `load_game()` can recover `.previous` when the main save is absent or invalid;
  invalid originals are preserved under `.corrupt` names without replacing older
  preserved corrupt files.
- `import_save()` validates structure/fields and size (at most 2,000,000 bytes),
  rejects future formats, preserves `.backup`, and rolls memory state back if
  writing fails. The UI requires confirmation and disables restore during battle.
- Import/reset preserve existing privacy choices. A failed reset/import does not
  silently replace the in-memory progress with the requested new state.

Android uses its native Storage Access Framework picker through Godot. iOS uses
the project's [UIDocumentPicker plugin](../ios/plugins/backup_file_picker/).
Desktop uses a native file dialog. Saves use app-private `user://` storage;
general phone-storage access is not required.

Manual backups are not authentication, synchronization, conflict resolution, or
cloud recovery. Uninstalling can erase local progress. Local data is editable and
is not a trustworthy authority for competitive rankings.

## Lifecycle and haptics

When the app loses focus or enters the background, `GameManager` saves progress,
`AudioManager` suspends playback without changing preferences, and the battle
cancels active gestures and opens pause. Returning does not automatically resume,
including when interruption happened during a help/resume animation. An ongoing
battle is not persisted across process termination.

Haptic intensity is validated and saved. Pulses are clamped to 20–120 ms and
rate-limited; a combined assault emits one pulse, and a stronger pulse can replace
a shorter one. The Settings test button is disabled on desktop. Device support,
feel, and interruptions still need physical testing.

## Accessibility

The game provides larger text, a color-blind palette, reduced motion, higher map
contrast, safe-area handling, and alternate battle controls with accessible names.

Godot 4.7.2 exposes supported desktop accessibility interfaces, but this project
does not establish TalkBack/VoiceOver support on Android/iOS. Settings consults
`AccessibilityServer.is_supported()` and explains the mobile limitation. No native
mobile accessibility bridge is included. Do not advertise mobile screen-reader
support without a compatible bridge/engine and physical-device verification.

## Physical-device checklist

Before distributing a build, check the exact artifact on the intended platforms:

- [ ] Start, win, buy an upgrade, change settings, and reopen in airplane mode.
- [ ] Check small phones, safe areas/notches, gesture bars, tablets/foldables,
      rotation, and resizing during menus and battles with troops in motion.
- [ ] Test haptic intensity, opt-out, order/capture/result pulses, and a device
      with no supported haptic motor.
- [ ] Interrupt a drag, manual pause, help overlay, and resume animation by
      switching apps, locking the phone, or receiving a call. Simulation/audio
      must stop; resume must remain explicit.
- [ ] Terminate after saving, then update without uninstalling. Progress should
      remain; an interrupted battle should not be restored.
- [ ] Export/import through the real native picker; test cancellation, inaccessible
      destinations, invalid/future/oversized backups, and write failures safely.
- [ ] Check English/Spanish, representative long-text languages, Arabic RTL, both
      themes, text scales, contrast, and alternate controls. Verify actual
      assistive technology before claiming support.
- [ ] On a clean profile, test a supported locale such as `fr-FR`/`ar-EG` and an
      unsupported one. Change language, relaunch, and confirm the saved choice
      takes precedence. An old save without a language should follow the device.
- [ ] Check native crash/reporting behavior and privacy opt-outs, cold start,
      low-end performance, and Android 16 KB library compatibility as applicable.

The [mobile suite](TESTING.md#godot-regression-suites) simulates lifecycle events
and write failures in separate saves. It cannot certify haptic feel, real OS
interruptions, native SDK traffic, a signed production artifact, or screen readers.

## Features not integrated

There is no Play Games/Game Center login, online leaderboard, cloud save, or local
notification integration. The UI does not offer connection buttons for services
that do not exist. These are scope boundaries, not promised future releases.

Any future integration needs an explicitly reviewed plugin/SDK, real service
identifiers, permission/consent handling, privacy/store updates, failure-path
tests, and physical-device validation. Cloud changes also need conflict/migration
rules that never silently replace local progress; rankings need common timing
rules and a trustworthy authority, not direct submission of editable local records.
