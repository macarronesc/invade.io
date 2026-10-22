# invade.io — versionado y notas de versión

Cómo se numera la aplicación, dónde se cambia cada número y los textos que se pegan en Play Console
y en GitHub en cada publicación. El campo «Novedades» de Play admite **500 caracteres por idioma**;
los bloques de este documento ya están medidos.

Pareja de este documento: [plan de publicación en Google Play](../PLAY_STORE.md).

## 1. Cómo se numera

| Número | Dónde vive | Qué es | Regla |
|---|---|---|---|
| `version/name` | `export_presets.cfg`, presets «Android» y «Android AAB» | lo que ve el jugador | `MAYOR.MENOR.PARCHE` |
| `version/code` | los mismos dos presets | entero interno de Play | **+1 en cada subida, jamás se repite** |
| `application/short_version` | `export_presets.cfg`, preset «iOS» | lo que ve el jugador | mismo `MAYOR.MENOR.PARCHE` |
| `application/version` | el preset «iOS» | número de compilación | +1 en cada subida a App Store Connect |

Qué significa cada salto:

- **PARCHE** (`0.1.0` → `0.1.1`): arreglos, sin contenido nuevo.
- **MENOR** (`0.1.1` → `0.2.0`): contenido o funciones nuevas (niveles, modos, reglas).
- **MAYOR** (`1.0.0`): hitos grandes, como la salida en tiendas o rehacer algo de raíz.

Reglas que no se pueden saltar:

- Un `version/code` **no se reutiliza nunca**, ni siquiera en pruebas internas o en ramas: Play lo
  compara con todos los códigos ya subidos de esa app. Sube +1 aunque el nombre no cambie.
- Los **dos presets Android** llevan el mismo nombre y el mismo código, para que el APK de pruebas y
  el AAB de Play no se confundan.
- El máximo de Play es 2100000000: a +1 por subida hay margen de sobra.
- Android e iOS son **independientes**: Play mira el código de Android; App Store Connect exige además
  que el número de compilación crezca dentro de la misma versión de marketing.
- Los códigos ya usados se consultan en Play Console → *Test and release → App bundle explorer*.
- Compatibilidad de partidas: el guardado se migra solo desde versiones anteriores y una versión
  antigua nunca sobrescribe una más nueva (avisaría y bloquearía el guardado hasta actualizar).

## 2. Antes de cada publicación

1. `version/name` y `version/code` en los presets «Android» y «Android AAB».
2. `application/short_version` y `application/version` en el preset «iOS».
3. Añadir una sección en este documento con las novedades de esa versión y una fila en el historial.

El resto del proceso (commit, GitHub Actions, descarga del AAB, subida a Play) está en
[PLAY_STORE.md §6](../PLAY_STORE.md).

## 3. invade.io 0.1.0 — primera versión pública

`versionCode` 1 · `versionName` 0.1.0 · estados: prueba interna → prueba cerrada → producción.

### Novedades en Play Console (español)

Campo «Novedades» de la versión. 452/500 caracteres.

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

Campo «What's new» de la versión. 437/500 caracteres.

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

### Notas completas (GitHub Releases y anuncio)

Sin límite de caracteres. Sustituir la fecha y, si Play registra otro identificador, el enlace.

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

### Qué NO prometer

Ni nube, ni cuentas, ni clasificación online, ni compras, ni anuncios, ni multijugador: la ficha y las
novedades deben describir sólo lo que la app hace. Tampoco conviene repetir palabras clave para
posicionar: Play lo considera spam.

## 4. Historial de versiones

| Versión | versionCode | Fecha | Qué cambió |
|---|---|---|---|
| 0.1.0 | 1 | *(al publicar)* | Primera versión pública: campaña de 30 niveles, conquista libre, desafío diario, misiones, logros, atlas y estética |
