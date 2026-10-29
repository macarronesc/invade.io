# Google Play publishing

[Documentation](README.md) · [Releases](RELEASES.md) · [Store material](PLAY_STORE_UPDATE.md) · [Platform testing](PLATFORM_INTEGRATION.md)

**invade.io is already published on Google Play.** Use this guide to maintain the
existing application, not to create a replacement listing or register a new
package. Initial account registration and historical closed-test steps are not
outstanding project work.

- Permanent production package: **`macarronesc.invadeio`**.
- Debug APK identifier: **`macarronesc.invadeio.debug`**; it does not update Play.
- [Existing listing](https://play.google.com/store/apps/details?id=macarronesc.invadeio).
- Support contact: [alegandro2507@gmail.com](mailto:alegandro2507@gmail.com).

## Choose the operation

| Task | Procedure |
|---|---|
| Update text, screenshots, languages, or feature graphic | [Play Store refresh and publishing guide](PLAY_STORE_UPDATE.md) |
| Release a new application build | [Release process](RELEASES.md#before-merging-a-release), then the update checklist below |
| Produce or verify a local Android build | [Local Android export](#local-android-export) |
| Repair signing configuration | [Owner-only signing setup](#owner-only-signing-setup) |

The screenshot package is review/upload material, not proof it is live. A listing
refresh alone does not require inventing an application version. Conversely, do
not publish new privacy/defaults wording for a binary that behaves differently.

## Update the published application

1. Follow [RELEASES.md](RELEASES.md) to prepare a release PR to `main`. Keep the
   semantic version synchronized across project/presets, increase both Android
   version codes, and update the version assertions. Confirm the new code is
   unused in Play Console; source values do not prove availability.
2. Review the exact commit, passing checks, notices, native/workflow changes,
   permissions, and upload-certificate fingerprint before approving production
   signing. Missing credentials must fail, not skip signing.
3. Download the signed `invadeio.aab`, `COMMIT.txt`, and `SHA256SUMS` from the
   resulting GitHub release. Check the checksums and test the exact artifact:

   ```sh
   sha256sum --check SHA256SUMS
   ```

   Download all files listed in `SHA256SUMS` when checking the entire manifest.
   On macOS, use `shasum -a 256 --check SHA256SUMS`.
4. Upload the AAB to the intended track of the **existing** Play application.
   Select only the matching version's text from
   [release_notes.md](store_listing/release_notes.md). The Debug APK is not a
   production update and the unsigned candidate is not the signed upload bundle.
5. Review the pre-launch report and test install/update, offline play, saves,
   native backups, rotation, performance, and privacy settings on real devices.
6. Complete the [privacy, audience, and listing gate](PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate)
   for the actual distributed builds/tracks, then publish through Play Console.
   Choose rollout scope intentionally and monitor available crash/install reports.

CI creates verified GitHub release artifacts; it does **not** upload to Google
Play or App Store Connect. Do not reuse version codes, move release tags, or
replace published assets. See [release recovery](RELEASES.md#before-merging-a-release)
if an unpublished draft or upload fails.

## Local Android export

Ordinary contributors can use CI test artifacts without production credentials.
Local export needs Godot 4.7.2 and matching export templates, JDK 17, Android SDK
36, build-tools 36.1.0, NDK 29.0.14206865, and the Gradle template. The pinned
toolchain and checksums are recorded in [CI](../.github/workflows/ci.yml).
Configure the Android/Java SDK paths in Godot's Editor Settings.

Run the following sequence from the repository root:

```sh
mkdir -p build/android

# Install the Gradle template and produce a Debug APK.
godot --headless --path . --install-android-build-template --export-debug "Android" build/android/invadeio.apk
bash scripts/verify_play_bundle.sh build/android/invadeio.apk

# Enable release R8 after template installation; do not reinstall between steps.
bash scripts/enable_android_r8.sh

# Owner-only: requires release signing variables supplied outside the repository.
godot --headless --path . --export-release "Android AAB" build/android/invadeio.aab

# Verify the signed AAB and APK together; requires Java and bundletool.
BUNDLETOOL_JAR=/path/to/bundletool.jar bash scripts/verify_play_bundle.sh build/android/invadeio.aab build/android/invadeio.apk
```

Production signing reads `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Supply them through a secure local
environment; never commit them or `.godot/export_credentials.cfg`. Contributors
should not request the owner's upload key to run tests.

The [R8 script](../scripts/enable_android_r8.sh) reproducibly patches the generated
`android/build/` template. It enables release minification without resource
shrinking and retains required Godot Java/JNI access. Reinstalling the template
can replace those changes; rerun the patch afterward. R8 does not optimize
GDScript, geography, fonts, or native Godot/Sentry libraries, and is not evidence
of a measured RAM improvement.

### What verification establishes

[verify_play_bundle.sh](../scripts/verify_play_bundle.sh) checks archive integrity,
identifiers, SDK values, exact permissions, architectures, native alignment,
orientation/aspect restrictions, and required resources. Release AAB checks also
require a valid signature and the R8 mapping. The combined APK check uses
`zipalign -c -P 16` for actual native-library packaging. The AAB preset exports
arm64 only, with minimum SDK 24 and target SDK 36.

[verify_artifact.py](../tools/verify_artifact.py) rejects development resources,
sensitive material, unsafe archive paths, and missing notices. CI explicitly
permits an unsigned candidate **only before** isolated signing; this exception
does not make it distributable.

These checks do not establish upload-key registration, version-code availability,
current Play policy compliance, device performance, or correctness of Data safety
answers. Confirm current requirements in
[Android's Google Play guidance](https://developer.android.com/distribute/best-practices)
and the Console rather than treating historical deadlines as evergreen advice.

## Owner-only signing setup

This is maintenance of an existing application's signing boundary. **Use the
registered upload key.** Do not generate a replacement just because a checkout
has no keystore; key rotation/recovery must follow Play Console's process.

Maintain a GitHub **`play-release` environment** restricted to `main`, with manual
owner approval and no administrator bypass. Its environment secrets are:

| Secret or variable | Purpose |
|---|---|
| `ANDROID_KEYSTORE_BASE64` (secret) | Base64-encoded upload keystore |
| `ANDROID_KEY_ALIAS` (secret) | Upload-key alias |
| `ANDROID_KEY_PASSWORD` (secret) | Shared keystore/key password used by the signing job |
| `ANDROID_UPLOAD_CERT_SHA256` (public variable) | Expected upload certificate SHA-256, independently checked in Play Console |

Keep production secrets out of repository-level secrets and untrusted jobs.
After verifying environment setup, remove obsolete repository-level copies if
present. The isolated signing runner has no checkout and executes no game or
contributor build scripts; preserve that boundary. The release job never receives
signing secrets. See [Security](../SECURITY.md) for the solo-maintainer approval
limitation and exposure response.

For initial setup or an explicitly approved rotation, create the key **outside
the repository**. Let `keytool` prompt for passwords rather than putting them in
shell history:

```sh
keytool -genkeypair -v -keystore /secure/path/upload.keystore -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=macarronesc, O=invade.io, C=ES"
keytool -list -v -keystore /secure/path/upload.keystore -alias upload
```

Use the same strong ASCII password for key and store for compatibility with the
current PKCS12/Gradle setup. Keep encrypted off-repository backups of the key and
password. Base64 is transport encoding, **not encryption**; handle an encoded key
with the same care as the original. Never upload real credentials to a scanner
or expose secret values in commands, logs, screenshots, or documentation.

If the upload key is lost/exposed, use Play Console's upload-key reset process
and rotate credentials. Deleting a tracked file does not revoke a key. Google
Play App Signing holds the separate app-signing key; its certificate is not the
upload-certificate fingerprint used by this workflow. Confirm the right
certificate for each integration in **App integrity → Play App Signing**.

## Listing, policy, and publication boundaries

The [store update guide](PLAY_STORE_UPDATE.md) owns text, device-gallery order,
locale mapping, alt text, translation review, packaging, and measurement. Reuse
the existing icon and real-scene capture pipeline instead of manually editing
generated images.

The public privacy-policy URL must remain:

`https://macarronesc.github.io/invade.io/privacy-policy.html`

[pages.yml](../.github/workflows/pages.yml) packages **only**
[privacy-policy.html](privacy-policy.html) and deploys from `main`. Developer
Markdown guides are read on GitHub, not deployed by that workflow. Before merging
a policy change to `main`, have the owner verify its disclosures against shipped
builds, then check the actual public page after deployment. An English-only
presentation does not resolve a mismatch in telemetry defaults.

Review category/tags, target audience, Families settings, Data safety, distribution
countries, and large-screen/PC availability in the existing application. Do not
copy historical account-registration instructions or predict an IARC rating.
No-ads/no-purchases/no-account statements must remain true of the shipped game;
optional telemetry still needs accurate collection disclosures when data leaves
the device. Online services and notifications are not required for this release
and are not integrated; see [Platform scope](PLATFORM_INTEGRATION.md#features-not-integrated).
