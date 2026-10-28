# CI, signing and releases

## Trust boundaries

`.github/workflows/ci.yml` runs for branch pushes, PRs (including forks and PRs targeting main),
and manual validation. All jobs default to `contents: read`; checkout never stores credentials.
`checks` runs pinned/checksummed Gitleaks, actionlint, ShellCheck, repository guards, regression
tests, and version validation. `build-android` and `build-ios` retain their required check names.

Every branch produces a Debug APK and non-main builds produce a Debug IPA, with the separate
`macarronesc.invadeio.debug` identifier. Android also builds an **unsigned** production candidate
on PRs so the AAB pipeline is checked before merge, without any production credential. Never
distribute that validation AAB as a signed release. Artifacts expire after seven days.

Only `push` to `refs/heads/main` can request production signing. Manual runs and PRs cannot.
`sign-android` waits for both platform jobs and checks, then requests owner approval through
`play-release`. It uses a fresh runner, no checkout, no Gradle, and no game/contributor scripts.
It downloads only the unsigned artifact from this workflow run, signs it with environment-only
credentials, rejects partial signatures, verifies the expected certificate fingerprint, and removes
the key. The only job with `contents: write` is `release`, which never receives signing secrets.

`release` creates a draft for the exact tested commit, attaches AAB, unsigned IPA, clearly labeled
Debug APK, `COMMIT.txt` and `SHA256SUMS`, then publishes it. A failed prerequisite cannot publish.
Existing tags/releases are never overwritten. There is no Play/App Store API credential or upload.

## Before merging a release

1. Increase semantic version in project and every preset, both Android version codes, and the
   version assertions in `scripts/tests/test_runner.gd`. CI checks consistency and increase over main.
2. Confirm the Android code is unused in Play Console; this repository cannot query your console.
3. Review the exact commit, native/workflow changes, passing checks, notices and permissions.
4. Compare the public `play-release` variable `ANDROID_UPLOAD_CERT_SHA256` with Play Console's
   **upload** certificate (not Google's separate app-signing certificate). Its initial baseline came
   from the previously successful main AAB, not an independent Play Console check.
5. Approve signing only for the expected main commit. Download the release, check hashes, test on
   devices, then upload the AAB to the intended Play track manually.

```sh
sha256sum --check SHA256SUMS
```

If upload/publication fails after a draft/tag was created, investigate the existing draft and commit.
Complete the verified draft manually, or explicitly remove a failed unpublished draft/tag before
retrying. Never delete or replace an already published release to make CI green. Old signing jobs
must be re-reviewed; re-running a workflow is not approval of a different commit.

## GitHub configuration

- Secret scanning, push protection, Dependabot alerts/security updates and private reports: enabled.
- Actions: selected GitHub-owned Actions plus the exact pinned Android setup action; external
  contributors require approval. SHA pinning must remain enforced once Pages uses this workflow.
- `main`/`dev`: preserve required builds, strict checks, admin enforcement, no force/deletion and
  resolved conversations. `checks` is also required, following its first successful GitHub runs.
- `play-release`: only branch `main`, owner approval, no admin bypass, three environment secrets
  and the public certificate fingerprint. `ci` and repository secrets remain empty.
- Pages: Actions source; `pages.yml` packages only the public policy and deploys main with scoped
  `pages: write`/OIDC permissions. Existing policy URL must remain unchanged.
- Independent PR/code-owner approval and prevention of deployment self-review require a second
  trusted maintainer. See SECURITY.md; do not silently lock out the sole owner.

The API did not enable non-provider patterns/validity checks in this repository. Gitleaks and
tracked-file/package guards supplement provider scanning; they do not prove all possible secrets
absent. Review push-protection bypass alerts. Account MFA, OAuth/GitHub Apps, store access, native
SDK payloads and physical-device behavior require owner/device checks outside this repository.

## Package and license checks

`tools/verify_artifact.py` inspects APK/AAB ZIP resources and the IPA's Godot PCK directory.
It rejects development resources, sensitive paths/material, duplicate/unsafe paths, unsupported
PCK variants and missing notices. `scripts/verify_play_bundle.sh` requires Android verification
tools, checks all permission namespaces, and allows unsigned AABs **only** when explicitly requested
by the pre-signing build. SDK/permission/orientation/R8/alignment checks still apply to that candidate.

The project remains Apache-2.0. Original contributions retain their copyright; third-party licenses
remain separate. Regenerate bundled notices with `python3 tools/build_notices.py` after changes.
Settings shows those notices and Godot's built-in license/copyright information offline.

## Dependency inventory

| Component | Pinned source/version | Update process |
|---|---|---|
| Godot and templates | 4.7.2, hashes in CI | Review release/advisories; update version and all hashes together |
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
Sentry 2.4.0 is available; availability alone is not evidence that 2.3.0 is vulnerable. Check its
changelog and native/device compatibility before upgrading. Dependabot does not audit these
vendored binaries or automatically update checksum-pinned download URLs.

The iOS picker must match the engine template ABI: `bash scripts/build_ios_backup_picker.sh Debug`
for Debug exports, or `Release` (the default) for Release. CI chooses the matching mode explicitly;
never disable the picker just to make a Debug archive link.
