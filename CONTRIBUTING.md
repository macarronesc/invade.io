# Contributing to invade.io

Thanks for helping improve invade.io. Code, translation review, UI/accessibility
feedback, device testing, and documentation are all welcome.

[Documentation](docs/README.md) · [Development setup](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Testing](docs/TESTING.md)

## Start here

1. Browse the [issues](https://github.com/macarronesc/invade.io/issues), or open a
   focused proposal before making a large behavior change. Do not assume a
   feature mentioned as unsupported is a promised roadmap item.
2. Fork the repository and branch from **`dev`**. Open contribution PRs against
   `dev`; only release PRs target `main`.
3. Use **Godot 4.7.2** and follow the [setup guide](docs/DEVELOPMENT.md). Ordinary
   development needs no server, accounts, or store credentials.
4. Keep the change focused, explain the behavior and motivation, and include a
   regression test for new logic or a bug fix. Match the surrounding code style.
5. Run the [checks appropriate to your change](docs/TESTING.md#choose-checks-for-your-change)
   and report commands, results, warnings, skips, and device limitations in the PR.

For UI changes, include representative before/after images and check long text,
RTL, themes, and orientation. For translation changes, preserve formatting tokens
and reviewed overrides; see [localization](docs/DEVELOPMENT.md#localization).
For guide-only changes, check links, alt text, English prose, and rendered layout.
Guides are also rendered on the website; run the affected
[website checks](docs/WEBSITE.md#run-and-validate) to catch broken routes/anchors.
Do not regenerate unrelated store graphics just to edit documentation.

## Report bugs and suggest improvements

Use [GitHub issues](https://github.com/macarronesc/invade.io/issues) for ordinary
bugs. Include the app version or commit, platform/device, reproduction steps,
expected/actual behavior, and relevant language/theme/orientation. Share only
sanitized logs or screenshots. Player support is also available at
[alegandro2507@gmail.com](mailto:alegandro2507@gmail.com).

Report vulnerabilities [privately](SECURITY.md), never as a public bug report.

## Protect player data and credentials

Test scenes select isolated startup storage before autoloads read saves. The game has no server,
accounts, or store credentials needed for development. PR builds are Debug, unsigned by the Play
upload key, and use a separate application ID so they do not replace the Play installation.
Back up any existing SideStore/test save before changing test identifiers; old test saves do not
automatically migrate. Never change the published `macarronesc.invadeio` package identifier.

Worktrees can share desktop user data; use the [isolation guidance](docs/DEVELOPMENT.md#saves-and-independent-worktrees)
for independent runs. Ordinary editor/MCP gameplay can transmit telemetry; use
`godot --path . -- --no-telemetry` for a manual run without provider traffic.

Do not commit signing files, `.env`, `.godot/export_credentials.cfg`, service-account credentials,
private logs, or generated build folders. Git ignores are not a security or export boundary.
Review executable third-party/native changes particularly carefully; CI cannot prove code benign.
Follow [SECURITY.md](SECURITY.md) for private reports. First-party code/assets remain Apache-2.0;
submitted contributions are under that license (section 5), and third-party notices must remain.

## License and attribution

`NOTICE` identifies **macarronesc** as the original author of invade.io's code. Commercial use,
modification, and proprietary derivatives remain permitted. When redistributing the original or
derivative code, preserve relevant copyright and attribution notices under Apache-2.0 sections
4(c) and 4(d), whether modified or not. Include the relevant NOTICE attribution in at least one
license-permitted location: a distributed NOTICE file, source/documentation, or a product notice
display. Our builds include it in the offline license viewer. This does not require public credit
for private/internal use or a main-screen credit, add new license conditions, or relicense third-party
work. Regenerate `assets/legal/notices.txt` after editing NOTICE or license files.

```sh
python3 tools/build_notices.py
```

## Review boundaries

Workflow, signing, native-plugin, telemetry, and license changes need explicit maintainer scrutiny.
Fork workflows require approval. CI tests pushed tips and PR merge results, not each intermediate
game snapshot in a multi-commit push; the secret scan covers commit history too.

Update affected guides when behavior changes. First-party guide prose is English;
localized game/store content keeps its intended languages. Do not publish private
account configuration or change legal/privacy disclosures as unrelated cleanup.

## Releases

Every merge to `main` must bump the semantic version consistently in `project.godot` and all export
presets, and increase both Android version codes. Confirm the new code is unused in Play Console.
After all checks and your signing approval, CI creates a GitHub release for the exact tested commit.
It does not publish to Play or App Store Connect. Do not merge a release PR with failing checks.
Never reuse or move a release tag, replace published assets, or commit a PAT for release automation.

The GitHub debug APK is not a Play update; the AAB is for Play Console, and the unsigned IPA is
for SideStore, not TestFlight or App Store. Preserve all bundled license notices.

The [release guide](docs/RELEASES.md) is authoritative for CI/signing boundaries,
version checks, artifact verification, and failure recovery. A documentation PR
to `dev` does not require changing the application version; merging to `main`
must follow the normal release requirements.
