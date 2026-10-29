# invade.io brand assets

[Project home](../../README.md) · [Asset workflows](../../docs/DEVELOPMENT.md#geography-and-brand-assets) · [Store graphics](../../docs/PLAY_STORE_UPDATE.md)

All icon PNGs are rendered from the vector app icon (`/icon.svg`).

- `play-store-icon-512.png` — Google Play Store listing icon (512 × 512 PNG).
- `icon-48.png` through `icon-192.png` — Android launcher density sizes (mdpi through xxxhdpi).
- `icon-1024.png` — iOS app icon and high-resolution master.
- `adaptive-foreground-432.png`, `adaptive-background-432.png`, and `adaptive-monochrome-432.png` — Android adaptive icon layers.
- `boot_splash.png` — branded Godot boot splash; the engine splash is configured in `project.godot`.

The Android and iOS export presets already point to their platform icon assets.

The gameplay-led feature graphic and localized galleries live in
[`docs/store_assets/`](../../docs/store_assets/), not here. Keep launcher artwork
distinct from promotional screenshots; follow the store capture workflow to
regenerate the latter. Preserve applicable [license and attribution notices](../../NOTICE).
