# Contributing to invade.io

Open a fork PR against `dev`; release PRs target `main`. Keep changes focused, explain behavior
changes, and include a regression test for new logic or bug fixes. Use Godot 4.7.2.

```sh
python3 tools/build_notices.py
python3 -m unittest discover -s tools/tests -v
python3 tools/check_repository.py
godot --headless --path . --editor --import
godot --headless --path . res://scenes/tests/test_runner.tscn
```

Test scenes select isolated startup storage before autoloads read saves. The game has no server,
accounts, or store credentials needed for development. PR builds are Debug, unsigned by the Play
upload key, and use a separate application ID so they do not replace the Play installation.
Back up any existing SideStore/test save before changing test identifiers; old test saves do not
automatically migrate. Never change the published `macarronesc.invadeio` package identifier.

Do not commit signing files, `.env`, `.godot/export_credentials.cfg`, service-account credentials,
private logs, or generated build folders. Git ignores are not a security or export boundary.
Review executable third-party/native changes particularly carefully; CI cannot prove code benign.
Follow [SECURITY.md](SECURITY.md) for private reports. First-party code/assets remain Apache-2.0;
submitted contributions are under that license (section 5), and third-party notices must remain.

Workflow, signing, native-plugin, telemetry, and license changes need explicit maintainer scrutiny.
Fork workflows require approval. CI tests pushed tips and PR merge results, not each intermediate
game snapshot in a multi-commit push; the secret scan covers commit history too.

## Releases

Every merge to `main` must bump the semantic version consistently in `project.godot` and all export
presets, and increase both Android version codes. Confirm the new code is unused in Play Console.
After all checks and your signing approval, CI creates a GitHub release for the exact tested commit.
It does not publish to Play or App Store Connect. Do not merge a release PR with failing checks.
Never reuse or move a release tag, replace published assets, or commit a PAT for release automation.

The GitHub debug APK is not a Play update; the AAB is for Play Console, and the unsigned IPA is
for SideStore, not TestFlight or App Store. Preserve all bundled license notices.
