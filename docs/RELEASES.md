# CI, signing and releases

[Documentation](README.md) · [Testing](TESTING.md) · [Android publishing](PLAY_STORE.md) · [Security](../SECURITY.md)

This guide owns the release/signing rules. For test installation, use
[Platform integration](PLATFORM_INTEGRATION.md); for localized store material, use
[Play Store refresh](PLAY_STORE_UPDATE.md). A source checkout or GitHub release
does not establish which binary or listing is currently distributed by a store.

## Trust boundaries

`.github/workflows/ci.yml` runs for branch pushes, PRs (including forks and PRs targeting main),
and manual validation. All jobs default to `contents: read`; checkout never stores credentials.
`checks` runs pinned/checksummed Gitleaks, actionlint, ShellCheck, repository guards, regression
tests, and version validation. `build-android` and `build-ios` retain their required check names.

Every branch produces a Debug APK and ordinary non-main builds produce a Debug IPA, with the separate
`macarronesc.invadeio.debug` identifier. Android also builds an **unsigned** production candidate
on PRs so the AAB pipeline is checked before merge, without any production credential. Never
distribute that validation AAB as a signed release. Artifacts expire after seven days.

Telemetry defaults to enabled unless a saved preference disables it. Classification follows the
engine build, not the branch, signing, or package format: ordinary CI APKs are Debug, all candidate AABs
are Release, and the main IPA and opt-in size-candidate APK/IPA are Release. Aptabase uses `isDebug`; Sentry uses
`debug`/`production`. Editor-launched gameplay is Debug; automated test scenes and headless runs
never initialize providers. See [Telemetry](ANALYTICS.md) for privacy and pre-publication checks.

Only `push` to `refs/heads/main` can request production signing. Manual runs and PRs cannot.
`sign-android` waits for both platform jobs and checks, then requests owner approval through
`play-release`. It uses a fresh runner, no checkout, no Gradle, and no game/contributor scripts.
It downloads only the unsigned artifact from this workflow run, signs it with environment-only
credentials, rejects partial signatures, verifies the expected certificate fingerprint, and removes
the key. The only job with `contents: write` is `release`, which never receives signing secrets.

`release` creates a draft for the exact tested commit, attaches AAB, unsigned IPA and clearly labeled
Debug APK, then publishes it with GitHub-generated change notes. No build-summary paragraph,
commit file or checksum manifest is generated. A failed prerequisite cannot publish.
Existing tags/releases are never overwritten. There is no Play/App Store API credential or upload.
GitHub's immutable-release setting remains enabled: it protects published assets/tags and
automatically creates a release attestation. That attestation is not a workflow-generated asset.

## Before merging a release

1. Increase semantic version in project and every preset, both Android version codes, and the
   version assertions in [test_runner.gd](../scripts/tests/test_runner.gd). CI checks consistency and increase over main.
2. Confirm the Android code is unused in Play Console; this repository cannot query your console.
3. Review the exact commit, native/workflow changes, passing checks, notices and permissions.
4. Compare the public `play-release` variable `ANDROID_UPLOAD_CERT_SHA256` with Play Console's
   **upload** certificate (not Google's separate app-signing certificate). Its initial baseline came
   from the previously successful main AAB, not an independent Play Console check.
5. Approve signing only for the expected main commit. Download the release, verify its asset digests, test on
   devices, then upload the AAB to the intended Play track manually.
6. Match privacy defaults/disclosures, the public policy, Data safety, audience
   settings, and release notes to the actual builds. Use the
   [store publication gate](PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate).

```sh
gh api 'repos/macarronesc/invade.io/releases/tags/v<VERSION>' --jq '.assets[] | [.name, .digest] | @tsv'
sha256sum invadeio.aab invade.io.ipa invadeio-debug.apk
```

Compare the local hashes with GitHub's `sha256:` asset digests. On macOS, use
`shasum -a 256` instead. The release tag identifies the tested source commit;
do not substitute an artifact from a different workflow run. GitHub's release
attestation binds that tag/commit to the published asset digests.

### Historical cleanup

The published `v0.3.1` and `v0.3.2` releases are immutable; their existing
`COMMIT.txt`, `SHA256SUMS` and attestations remain. Disabling immutability would
affect future releases only, and would remove GitHub's asset/tag protection.
Do not delete and recreate published releases to hide these historical files.
Old Actions job summaries cannot be edited separately: removing them requires
deleting their entire workflow runs, including logs/artifacts. Preserve that history;
the workflow no longer generates Android/iOS summaries for new runs.

If upload/publication fails after a draft/tag was created, investigate the existing draft and commit.
Complete the verified draft manually, or explicitly remove a failed unpublished draft/tag before
retrying. Never delete or replace an already published release to make CI green. Old signing jobs
must be re-reviewed; re-running a workflow is not approval of a different commit.

## GitHub configuration

These are maintainer-managed settings to preserve and verify in GitHub, not
configuration a local checkout can prove is enabled:

- Keep secret scanning, push protection, Dependabot alerts/security updates and private reports enabled.
- Actions: selected GitHub-owned Actions plus the exact pinned Android setup action; external
  contributors require approval. Preserve SHA pinning in CI and Pages.
- `main`/`dev`: require `checks`, `build-android`, and `build-ios`, strict checks,
  administrator enforcement, resolved conversations, and no force pushes/deletion.
- `play-release`: only branch `main`, owner approval, no admin bypass, three environment secrets
  and the public certificate fingerprint. Keep `ci` and repository secrets empty.
- Pages: Actions source; `pages.yml` checks and packages only the generated public website,
  selected guides/assets, and unchanged policy. It deploys main with scoped `pages: write`/OIDC
  permissions. Existing policy URL must remain unchanged. See [website maintenance](WEBSITE.md).
- Independent PR/code-owner approval and prevention of deployment self-review require a second
  trusted maintainer. See [SECURITY.md](../SECURITY.md); do not silently lock out the sole owner.

The previous repository audit did not establish non-provider pattern/validity
checks as enabled. Recheck account capabilities/settings rather than assuming
they are covered by the workflow. Gitleaks and
tracked-file/package guards supplement provider scanning; they do not prove all possible secrets
absent. Review push-protection bypass alerts. Account MFA, OAuth/GitHub Apps, store access, native
SDK payloads and physical-device behavior require owner/device checks outside this repository.

## Package and license checks

`tools/verify_artifact.py` inspects APK/AAB ZIP resources and the IPA's Godot PCK directory.
It rejects development resources, sensitive paths/material, duplicate/unsafe paths, unsupported
PCK variants and missing notices. `scripts/verify_play_bundle.sh` requires Android verification
tools, checks all permission namespaces, and allows unsigned AABs **only** when explicitly requested
by the pre-signing build. SDK/permission/orientation/R8/alignment checks still apply to that candidate.

The project remains Apache-2.0. `NOTICE` credits **macarronesc** for the original code and links
to the original repository. Redistributed derivatives must retain relevant attribution under
Apache-2.0 section 4(d); commercial/proprietary use remains allowed. Other contributors retain
their copyrights and third-party licenses remain separate. This does not add a private-use or
main-screen credit requirement. Existing license grants are not retroactively changed.
Regenerate bundled notices with `python3 tools/build_notices.py` after NOTICE/license changes.
Settings shows the original-author credit, those notices and Godot's license information offline.
Package checks reject exports missing the original NOTICE attribution.

## Export size and custom engine candidates

PRs, commits and `dev` builds use official Godot templates. A push to `main`
builds the pinned custom engine and uses it for the release AAB, Release IPA and
Debug APK. The manual `optimized_templates` flow remains available for validation
on any branch and keeps its separate `.size` identity. Fonts retain their glyph
coverage and weight variation but pin unused width variation; export-only
launcher/store artwork is excluded from the runtime pack, not from native icon
generation. The game logo, splash, all languages, ICU text data, procedural audio,
backups and Sentry remain.

CI verifies package contents and licenses without generating size tables or job
summaries. Run the same content check locally with:

```sh
python3 tools/verify_artifact.py build/android/invadeio.aab
```

Archive bytes, expanded file bytes, and store delivery sizes are different metrics.
Android still uses bundletool for manifest/alignment verification, not delivery
size reports. Only manual engine-candidate APKs need a disposable test key;
no production credential enters a build job. Play Console and
Xcode's App Thinning Size Report/App Store Connect remain the delivery-size authority.
The current unsigned SideStore IPA does not establish an App Store download size.

### Main releases and manual validation

Main release builds use the custom engine automatically. The manual
**optimized_templates** option remains available to validate the same engine on any
branch. It is restricted to manual runs: it cannot activate on a push/PR and never
enters production signing or publishing.

Release jobs fail closed if the exported engine or IPA size indicates that a stock
template was used by mistake. Signing and publication do not run in that case.

`scripts/build_mobile_templates.sh` downloads checksum-pinned Godot 4.7.2 source
(`ed1daf0bf001b61586d9930840f2f1394092c079`) and builds arm64 Debug/Release templates.
`tools/mobile_template_profile.py` enables size optimization and ThinLTO, removes 3D,
2D physics/navigation, Vulkan and Metal, and retains the GL Compatibility driver.
SVG, advanced shaping, GUI dialogs, HTTPS, threads and GDExtensions keep their defaults.
No class-name auto-stripping is used. Debug/Release native picker ABIs still match.

Android builds a real `android_source.zip` through Gradle; pointing a Gradle export
at `custom_template/release` would not replace its engine. iOS builds its own template
archive. Main releases keep the normal `macarronesc.invadeio` identity and production
telemetry. The manual run produces an installable Release `invadeio-size-candidate.apk`
and unsigned Release `invade.io-size-candidate.ipa`, both with the independent
`macarronesc.invadeio.size` identifier. Candidates respect the on-device privacy
toggles, so physical-device validation can exercise both providers. Their telemetry
is tagged instead of mixed with production: Aptabase events carry
`build_channel=size_candidate` and an `<version>-size` app version, and Sentry uses
the `size_candidate` environment. Turn both toggles off for a pure size run.
The APK's disposable certificate changes between runs: export any candidate progress
before replacing it. Neither artifact updates the store or normal Debug installation.

Local compilation requires Python with `venv`/pip, a C++ toolchain, and either the
Android SDK/JDK/NDK listed above or macOS with Xcode/iOS support. Android CI uses an
x86_64 Linux host; the Android NDK's host tools cannot run natively on ARM64 Linux.
Use a fresh build
directory outside the project (or add `.gdignore` to a local build directory):

```sh
bash scripts/build_mobile_templates.sh android /path/to/temporary/android-templates
# On macOS:
bash scripts/build_mobile_templates.sh ios /path/to/temporary/ios-templates
```

These commands produce templates; CI installs them for main releases or manual
candidates. They do not sign or publish. When Godot changes, update the source
commit/checksum, builder version guard, templates, native headers, CI download
hashes and tests together.

**Changing the profile or using it outside main releases is a separate reviewed
change.** Before changing it, compare a stock and custom export from the same
commit, check actual native sizes and Android 16 KB alignment, and complete the
physical-device checklist in
[Platform integration](PLATFORM_INTEGRATION.md#physical-device-checklist). Test Arabic,
Hindi and CJK wrapping, runtime SVGs, all game modes, native backup/restore, audio,
privacy opt-outs, lifecycle events, save-preserving updates, startup and frame times.
Editor tests alone do not exercise the stripped engine. Do not remove ICU/Sentry,
loosen JNI keep rules, or enable resource shrinking without a separately measured,
device-tested candidate; their smaller possible gains do not justify silent regressions.

## Dependency inventory

| Component | Pinned source/version | Update process |
|---|---|---|
| Godot and templates | 4.7.2, hashes in CI | Review release/advisories; update version and all hashes together |
| Custom template builder | Godot commit/hash in `scripts/build_mobile_templates.sh`; SCons version/hash in `tools/requirements-mobile-templates.txt` | Update with the matching editor/templates and validate candidates |
| Sentry Godot | Official 2.3.0+8ec9083 archive | Review upstream advisories and releases manually |
| Aptabase Godot | 0.0.1, locally modified `addons/aptabase` | Review changes and privacy/HTTP tests |
| Android | SDK 36, build-tools 36.1.0, NDK 29.0.14206865 | Review template/SDK compatibility and manifests |
| bundletool | 1.18.3, checksum in CI | Review/update checksum and alignment checks |
| Actions | Full SHAs in workflows | Weekly Dependabot PRs to dev |
| Security tools | Versions/hashes in `tools/install_security_tools.sh` | Review upstream advisories/releases manually |
| Fonts/geography | OFL Noto/Fredoka; public-domain Natural Earth | Preserve source metadata/licenses and regenerate/test subsets |

Sentry 2.3.0 archive SHA-256:
`f8de89d3860b00b19bf52eb3b9d66cd3ac3e5522a375e72f16f60672450c7417`.
All bundled binaries matched that release during the audit. Local differences are the trimmed
platform entries in `sentry.gdextension` and Godot's `.uid`, not modified executable binaries.
Check [upstream releases](https://github.com/getsentry/sentry-godot/releases),
advisories, changelogs, and native/device compatibility before upgrading; the
existence of a newer release alone is not evidence of a vulnerability. Dependabot does not audit these
vendored binaries or automatically update checksum-pinned download URLs.

The iOS picker must match the engine template ABI: `bash scripts/build_ios_backup_picker.sh Debug`
for Debug exports, or `Release` (the default) for Release. CI chooses the matching mode explicitly;
never disable the picker just to make a Debug archive link.
