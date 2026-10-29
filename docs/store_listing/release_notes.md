# Versioning and release-note reference

[Documentation](../README.md) · [Release process](../RELEASES.md) · [Google Play publishing](../PLAY_STORE.md)

This document contains version-specific Play Console text and historical draft
announcement payloads. Play's **What's new** field permits **500 characters per
language**. Use only the blocks for the build being distributed, not this entire
document. Localized payloads below are preserved in their intended languages.

**Publication is not established by this file.** Historical dates were not
recorded here, and early announcement templates contain placeholders and claims
that must not be copied as current behavior. Confirm the shipped binary and
current [privacy/publication gate](../PLAY_STORE_UPDATE.md#7-mandatory-privacy-audience-and-release-gate).
The [0.3.2 candidate notes](#candidate-invadeio-032--telemetry-defaults-and-store-refresh)
are not suitable for a listing-only refresh without that application build.

## Version fields

The [release guide](../RELEASES.md#before-merging-a-release) owns the required
version-increase checks. This table identifies the corresponding fields:

| Field | Location | Meaning | Rule |
|---|---|---|---|
| `config/version` | `project.godot` | Source/release version, also used by telemetry | `MAJOR.MINOR.PATCH` |
| `version/name` | Android and Android AAB export presets | Player-visible version | Matches the source version |
| `version/code` | Both Android presets | Internal Play version code | Increasing, never reused for the production package |
| `application/short_version` | Both iOS presets | Player-visible version | Matches the source version |
| `application/version` | iOS presets | Build number | CI supplies `GITHUB_RUN_NUMBER` to Xcode; App Store distribution needs increasing valid build numbers |

Convention: patch versions are fixes, minor versions introduce content/features,
and major versions mark substantial milestones. The two Android presets must
have matching names/codes; Play's maximum code is 2,100,000,000. Android and iOS
store numbering are independent. Check used Android codes in **App bundle
explorer**, never by guessing from source history.

Older save formats are validated/migrated by the game. A future-format save
blocks writes rather than being overwritten; this is separate from application
version numbering.

## Before each release

Follow [RELEASES.md](../RELEASES.md#before-merging-a-release), add accurate notes
and a history entry here, and confirm the artifact and Console version. Do not
treat a placeholder date or prepared text as a record of publication.

## Historical draft: invade.io 0.1.0 — first public release

`versionCode` 1 · `versionName` 0.1.0. The original templates describe an internal
test → closed test → production sequence; actual publication dates are not
recorded here. These are archived payloads, not the current feature reference.

### Play Console notes (Spanish)

Historical localized payload; verify applicability before reuse.

```
Primera versión pública de invade.io.
• Campaña de 30 niveles: capitales, fábricas, selva, oasis, fortalezas y rutas marítimas.
• Conquista libre en expediciones y desafío diario con reglas rotatorias.
• Misiones diarias, racha que perdona un día de ausencia y 20 logros.
• Invasiones regionales de tres frentes sobre ciudades reales.
• Mejoras de ejército, rangos, atlas de ciudades reales y estética desbloqueable.
• Sin anuncios, sin compras y sin conexión. Guardado local con copia exportable.
15 idiomas, incluido español e inglés.
```

### What's new on Play (English)

Historical English payload; verify applicability before reuse.

```
First public release of invade.io.
• A 30-level campaign: capitals, factories, jungle, oases, fortresses and sea routes.
• Free-conquest expeditions and a daily challenge with rotating rules.
• Daily missions, a streak that forgives one missed day, and 20 achievements.
• Regional three-front invasions across real cities.
• Army upgrades, ranks, an atlas of real cities and unlockable looks.
• No ads, no purchases, plays offline. Local save with an exportable backup.
15 languages, including Spanish and English.
```

### Archived long-form announcement templates

These original Spanish/English templates have no Play field-length limit and
contain publication-date placeholders. They are retained for history, not as
verified current announcements. In particular, historical network/privacy and
accessibility wording must not override the current source or shipped behavior.

```
invade.io 0.1.0 — primera versión pública

Ya disponible en Google Play:
https://play.google.com/store/apps/details?id=macarronesc.invadeio
(FECHA DE PUBLICACIÓN)

Estrategia territorial en vertical y con una mano: eliges una base, arrastras el dedo y las tropas
marchan a conquistar la siguiente. El mapa es el mundo real, con costas, fronteras y más de mil
ciudades auténticas.

Qué incluye esta 0.1.0
• Campaña de 30 niveles repartida en seis continentes, cada uno con su regla: capitales que producen
  un 50 % más, fábricas neutrales, selva que frena las marchas un 20 %, oasis, fortalezas y rutas
  marítimas obligatorias. Cada quinto nivel espera un jefe con refuerzos propios.
• Conquista libre en expediciones de cinco regiones, con jefe y oro doble al cerrar cada una.
• Desafío diario con reglas rotatorias y las mismas fuerzas para todos los jugadores.
• Misiones diarias, recompensa con racha que perdona un día de ausencia y 20 logros.
• Invasiones regionales de tres frentes sobre ciudades reales.
• Mejoras de ejército (guarnición, reclutamiento, velocidad de marcha y botín), rangos, colecciones
  de ciudades reales y estética desbloqueable que no altera el combate.
• 15 idiomas, tema claro y oscuro, paleta para daltonismo, opción de reducir movimiento,
  velocidad de juego y respuesta táctil ajustable.

Lo que todavía no tiene
Ni anuncios, ni compras, ni cuentas, ni conexión. El progreso vive en el móvil y se puede exportar una
copia cuando se quiera. Requiere Android 7.0 o superior.

Primer número de la serie: 0.1.0 con versionCode 1. Las versiones siguientes suben el nombre y el
código tal como se explica en docs/store_listing/release_notes.md.
```

```
invade.io 0.1.0 — first public release

Available now on Google Play:
https://play.google.com/store/apps/details?id=macarronesc.invadeio
(PUBLISH DATE)

One-handed portrait territorial strategy: pick a base, drag your finger and your troops march out to
take the next one. The map is the real world, with coastlines, borders and more than a thousand real
cities.

What's in 0.1.0
• A 30-level campaign across six continents, each with its own rule: capitals that produce 50 % more,
  neutral factories, jungle that slows marches by 20 %, oases, fortresses and mandatory sea routes.
  Every fifth level waits a boss with its own reinforcements.
• Free conquest in five-region expeditions, each ending with a boss and double gold.
• A daily challenge with rotating rules and equal forces for every player.
• Daily missions, a streak reward that forgives one missed day, and 20 achievements.
• Regional three-front invasions across real cities.
• Army upgrades (garrison, recruitment, march speed and spoils), ranks, collections of real cities
  and unlockable looks that never change combat.
• 15 languages, light and dark themes, colour-blind palette, reduced-motion option, game speed
  and adjustable haptic feedback.

What it does not have yet
No ads, no purchases, no accounts, no connection. Progress lives on your phone and you can export a
copy whenever you want. Requires Android 7.0 or higher.

First release of the series: 0.1.0 with versionCode 1. Later versions bump the name and the code as
described in docs/store_listing/release_notes.md.
```

### Claims to avoid

Only advertise implemented behavior. Do not promise cloud saves, accounts,
online rankings, purchases, advertising, or multiplayer. Avoid keyword stuffing
and do not treat historical copy as a current privacy statement.

## Reference: invade.io 0.2.0 — invasions and languages

`versionCode` 3 · `versionName` 0.2.0.

Historical internal Console label: `0.2.0 (3) — Invasiones y 15 idiomas`.

Play Console payloads (under 500 characters per language):

```
<es-ES>
¡Nueva actualización de invade.io!
• 36 regiones de invasión y 108 frentes, con progreso, recompensas y logros.
• Juega en 15 idiomas, incluido el árabe con interfaz de derecha a izquierda.
• Mejoras de navegación, resumen de batalla, contraste del mapa y respuesta táctil.
• Estadísticas de uso e informes de fallos opcionales, desactivados de forma predeterminada.
• Tu progreso anterior se conserva al actualizar.
</es-ES>
<en-US>
A major update for invade.io!
• Explore 36 invasion regions and 108 fronts, with progression, rewards, and achievements.
• Play in 15 languages, including Arabic with a right-to-left interface.
• Improved navigation, battle briefings, map contrast, and haptic feedback.
• Usage analytics and crash reports are optional and off by default.
• Your existing progress is preserved when you update.
</en-US>
```

## Candidate: invade.io 0.3.1 — contributions and build safety

`versionCode` 5 · **owner must confirm code availability and publication status in Play Console**.

- Offline open-source licenses in Settings.
- Test installations separated from the production app and its saves.
- PR CI, secret/package checks, and isolated, approved production signing.

Publish the matching policy and review Data safety/consent requirements before
distributing. Proposed payloads below apply **only to a shipped 0.3.1 binary**,
not a listing refresh without a build. Each locale's text is under 500 characters;
confirm actual production behavior first:

```text
<es-ES>
• Consulta las licencias de código abierto desde Ajustes, también sin conexión.
• Se conserva tu progreso al actualizar.
</es-ES>
<en-US>
• Open-source licenses are available in Settings, including offline.
• Your existing progress is preserved when you update.
</en-US>
```

Listing assets and update procedure: [PLAY_STORE_UPDATE.md](../PLAY_STORE_UPDATE.md).

## Candidate: invade.io 0.3.2 — telemetry defaults and store refresh

`versionCode` 6 · **owner must confirm code availability and publication status in Play Console**.

- Usage statistics and crash reports start enabled for new or missing settings; saved choices, including opt-outs, remain unchanged.
- Each option can be disabled separately in Settings → Privacy; analytics events waiting to be sent are discarded when disabled.
- Telemetry uses the actual Godot Debug/Release build type; editor tooling, tests, and headless runs do not initialize providers.
- The Play listing and its localized phone/tablet gallery are refreshed across 15 languages. These are store materials, not new in-game features.

Publish the matching policy and review Data safety/consent requirements before
distributing. Proposed payloads below apply **only to a shipped 0.3.2 binary**;
confirm actual production behavior first:

```text
<es-ES>
• Las estadísticas de uso y los informes de fallos empiezan activados; se respetan tus preferencias guardadas. Desactiva cada opción en Ajustes → Privacidad.
• Tu progreso se conserva al actualizar.
</es-ES>
<en-US>
• Usage statistics and crash reports now start enabled; your saved choices are respected. Turn either off in Settings → Privacy.
• Your existing progress is preserved when you update.
</en-US>
```

Listing assets and update procedure: [PLAY_STORE_UPDATE.md](../PLAY_STORE_UPDATE.md).

## Reference: invade.io 0.3.0 — accessibility and large screens

`versionCode` 4 · `versionName` 0.3.0.

Historical Play Console payloads (under 500 characters per language). The phrase
“screen-reader-friendly” describes the controls, not verified mobile TalkBack or
VoiceOver support; see [platform limitations](../PLATFORM_INTEGRATION.md#accessibility).

```
<es-ES>
¡Nueva actualización de invade.io!
• Más accesibilidad: texto grande, más contraste y controles de batalla para lector de pantalla.
• Menús y batallas para tabletas y apaisado, incluso al girar durante una partida.
• Partidas nuevas y guardados sin idioma siguen el idioma del dispositivo; se conserva tu elección.
• Más estabilidad en iPhone y diagnósticos opcionales.
• Tu progreso se conserva al actualizar.
</es-ES>
<en-US>
New invade.io update!
• Accessibility options: larger text, stronger map contrast, and screen-reader-friendly battle controls.
• Menus and battles adapt to tablets and landscape screens, including rotation during a match.
• New games and older saves without a saved language follow your device language; saved choices stay in place.
• Improved iPhone stability and optional diagnostics.
• Your progress is preserved when you update.
</en-US>
```

## Version reference

Dates were not recorded in this document. Confirm distributed versions in Play
Console and exact commits in GitHub releases; these rows are not deployment logs.

| Version | versionCode | Publication date | Scope described by the reference notes |
|---|---|---|---|
| 0.1.0 | 1 | Not recorded | Initial campaign, free conquest, daily challenge/missions, achievements, atlas, and cosmetics draft |
| 0.2.0 | 3 | Not recorded | 36 invasion regions / 108 fronts, 15 languages, optional telemetry, and UI improvements |
| 0.3.0 | 4 | Not recorded | Alternate controls, large-screen layouts, iOS improvements, and device-locale selection |
| 0.3.1 | 5 | Verify before distribution | License viewer and build isolation/hardening |
| 0.3.2 | 6 | Verify before distribution | Enabled telemetry defaults and localized store refresh |
