# Make your own version

[Documentation](README.md) · [Contributing](../CONTRIBUTING.md) · [Development](DEVELOPMENT.md) · [Telemetry](ANALYTICS.md)

invade.io is Apache-2.0: you may fork it, change it, and publish your own game,
including commercially. This guide lists what must change so your version is
clearly yours, builds on its own, and never talks to the original project's services.

## 1. Keep the legal notices

- Keep [LICENSE](../LICENSE) and [NOTICE](../NOTICE), and add your own line to NOTICE.
- Keep third-party licenses (`assets/legal/notices.txt`, `addons/*/LICENSE*`).
  `python3 tools/build_notices.py` regenerates the in-game list.
- Do not present your version as the original, and do not reuse the original
  store listing, screenshots or icon without changing them.

## 2. Rename it

| What | Where |
|---|---|
| Game name | `config/name` and `config/version` in `project.godot` |
| Android package | `package/unique_name` in both Android presets of `export_presets.cfg` |
| iOS bundle | `application/bundle_identifier` in the iOS presets |
| Icon and splash | `icon.svg` and `assets/brand/` (see its README) |
| Links and URLs | `Telemetry.PRIVACY_URL` and `DailyShare.URL` in `scripts/`, plus `website/scripts/site.mjs` |

Search for `macarronesc` and `invade.io` to find the remaining references.

## 3. Remove the original's telemetry

The usage statistics and crash reports go to the original project's Aptabase app
and Sentry project. Your version must not send data there:

1. Empty `APTABASE_KEY` and `SENTRY_DSN` in `scripts/autoload/telemetry.gd`;
   both systems then stay off and gameplay is unaffected.
2. If you add your own keys, update the privacy policy
   (`docs/privacy-policy.html`) and the in-game Settings → Privacy text.

## 4. Build and test

```sh
godot --headless --path . --editor --import
godot --headless --path . res://scenes/tests/test_runner.tscn
godot --path . -- --no-telemetry
```

Some tests assert the original's package names and version rules; update them in
the same change as the rename ([Testing](TESTING.md)). Store graphics are
reproducible with `scenes/tests/store_assets.tscn`, and the trailer with
`scripts/render_trailer.sh`.

## 5. Publish

- **Android / iOS:** [Platform integration](PLATFORM_INTEGRATION.md) and
  [Google Play publishing](PLAY_STORE.md). You need your own signing keys.
- **Browser:** the `Web` preset runs without the telemetry extension. Export with
  the Godot 4.7.2 `web_nothreads_*` templates and host the folder anywhere that
  serves static files; no special headers are needed.
- **Website:** `website/` is a static Astro site; see [Website](WEBSITE.md).

If you build something with it, open an issue or discussion so it can be linked
from the project.
