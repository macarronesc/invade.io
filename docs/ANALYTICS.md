# Analítica y fallos de invade.io

La instrumentación vive en `scripts/autoload/telemetry.gd`. No hay backend propio: el cliente de
Aptabase está en `addons/aptabase` y Sentry usa su GDExtension para Godot.

- **Aptabase** (`addons/aptabase`): estadísticas de uso. La clave `A-EU-*` usa el endpoint de la UE:
  [eu.aptabase.com](https://eu.aptabase.com). Plan gratuito: 20.000 eventos/mes (unas 1.000-1.500
  sesiones con este esquema); el plan de 200.000 eventos cuesta 10 USD/mes.
- **Sentry** (`addons/sentry`): fallos nativos y de GDScript, ANR y salud de versiones. DSN desde
  [sentry.io](https://sentry.io). Plan gratuito: 5.000 errores/mes y 30 días de retención.

El addon de Sentry se ha recortado a Android, iOS, Linux y macOS (las plataformas de desarrollo y
publicación actuales) para no arrastrar binarios de Windows ni Web. Si algún día se exporta a esas
plataformas, hay que restaurar sus binarios y sus entradas en `sentry.gdextension`.

Las dos claves son públicas de cliente y se pegan al principio de `telemetry.gd`:

```gdscript
const APTABASE_KEY := "A-EU-..."
const SENTRY_DSN := "https://...@o....ingest.sentry.io/..."
```

Con las claves vacías el juego funciona igual y no envía nada. En tests headless, en el editor y con
`--no-telemetry` tampoco se inicializa nada. `--telemetry-debug` imprime los eventos por consola en
una compilación de depuración.

La IPA de GitHub Actions se compila como `Release`, por lo que los envíos correctos no se imprimen en
esa compilación. Los fallos de transporte aparecen como avisos en la consola local de Godot/Xcode; no
se adjuntan a Sentry (`attach_log = false`). La suite headless verifica el cliente contra un servidor
HTTP local y no envía eventos ni claves reales a Aptabase.

## Eventos

Todas las propiedades personalizadas son cadenas o números. No se envían nombres, correos, texto
libre ni identificadores persistentes de cuenta o dispositivo. Aptabase también recibe propiedades
del sistema (idioma, SO, versión y modelo del dispositivo); como cualquier servicio HTTP, recibe la IP
de conexión y puede inferir el país aproximado. Cada evento de Aptabase lleva además un identificador
temporal de sesión que cambia al reiniciar la app o tras una hora sin actividad; no se reutiliza entre
sesiones.

| Evento | Propiedades principales |
|---|---|
| `session_start` | `first_run`, `player_level`, `total_stars`, `invasion_stars`, `language` |
| `session_end` | `duration_s`, `duration_bucket`, `reason`, `levels_started`, `levels_finished`, `tabs` |
| `tab_view` | `tab`, `previous_tab` |
| `screen_view` | `screen` (por ejemplo `settings`) |
| `level_start` | `level`, `mode`, `attempt`, `prev_stars`, `first_clear`, `player_level`, `total_stars`, `invasion_stars`, `upgrade_sum`, `combat_upgrades`, `speed` y, en campaña/invasiones, `continent`, `level_no` |
| `level_end` | las anteriores más `outcome` (`win`/`loss`/`quit`), `duration_s`, `real_seconds`, `duration_bucket`, `stars`, `is_replay`, `first_clear`, `new_medal`, `new_record`, `new_cities`, `captures`, `gold`, `player_level_after` |
| `upgrade_bought` | `upgrade`, `new_level`, `coins_after`, `player_level` |
| `reward_claimed` | `kind` (`daily`/`achievement`), `amount`, `streak` o `id` |

`mode` es `campaign`, `daily`, `conquest` o `invasion`. `attempt` cuenta los intentos de ese nivel
dentro de la sesión actual (no identifica al jugador entre sesiones).

Si el proceso muere de golpe no se envía `session_end`; el fallo queda registrado en Sentry y la
duración de esa sesión no se contabiliza.

## Cómo responder las preguntas

- **Tiempo en la app**: eventos `session_end`, filtrando por `duration_bucket`; la duración exacta
  está en `duration_s`. Para periodos largos, exporta CSV y suma.
- **Niveles más difíciles**: `level_end` agrupado por `level` y `outcome`. Tasa de victoria =
  victorias / (victorias + derrotas); añade `quit` para medir abandono y `attempt` para reintentos.
  Segmenta por `player_level` y `combat_upgrades` para separar dificultad de falta de mejoras.
- **Niveles más interesantes**: repeticiones (`is_replay`), tasa de abandono, estrellas, tiempo y
  participación en modos (`mode`). Un nivel con muchas visitas y mucho abandono suele necesitar ajuste.
- **Interacción general**: `tab_view` muestra qué secciones se abren; `screen_view` registra Ajustes;
  `upgrade_bought` y `reward_claimed` muestran el ritmo de progresión.
- **Fallos**: en Sentry, cada evento lleva etiquetas `screen`, `level`, `mode` y `player_level`, y
  breadcrumbs `level_start`/`level_end`. Release Health da la tasa de sesiones sin fallo por versión.

Aptabase usa un identificador temporal por sesión, no se conserva entre aperturas. Por eso
**no calcula retención por usuario, MAU ni
embudos entre usuarios**. Para retención e instalaciones usa Google Play Console y App Store Connect;
para embudos dentro del juego haría falta un servicio con identificador y consentimiento (PostHog o
GameAnalytics).

## Privacidad

`Ajustes → Privacidad` permite activar por separado estadísticas y fallos; ambos empiezan desactivados.
Al retirar una opción, se descarta la cola de analítica no enviada y se detiene la captura futura. Una
solicitud que ya esté en curso aún podría completarse. La política pública está en
`docs/privacy-policy.html` y la declaración de Play en `docs/PLAY_STORE.md`. Declara actividad de la
app, diagnósticos y, si Aptabase conserva la inferencia por IP, ubicación aproximada. En App Store
Connect revisa **Usage Data**, **Diagnostics** y **Coarse Location** según la configuración efectiva
de los proveedores; declara también que no se usan para tracking.

La configuración minimiza los datos, pero la base legal y las declaraciones finales dependen de tu
jurisdicción y de la retención configurada en cada proveedor. Revísalas con asesoría antes de publicar.
Las opciones de privacidad se conservan al reiniciar el progreso o importar una copia.

Sentry se configura con `send_default_pii = false`, sin logs adjuntos, sin capturas, sin árbol de
escena y sin usuario. Aun así, el proveedor puede recibir la IP de conexión; revisa la configuración
de eliminación de IP en el panel. No se debe llamar nunca a `SentrySDK.set_user()` ni enviar
identificadores propios.

Sentry se inicializa después de cargar los ajustes para respetar una baja anterior. Los fallos
nativos ocurridos antes de ese punto (arranque del motor) no se capturan aquí: Play Console y App
Store Connect siguen siendo la red de seguridad para esos casos.

Para que las trazas nativas sean legibles hay que subir los símbolos de depuración de Godot y Sentry
con `sentry-cli` desde el flujo de compilación; las trazas de GDScript ya llegan con su contexto.
Sentry activa `always_track_call_stacks` en los ajustes del proyecto para poder reconstruir esas
trazas; si el rendimiento en un móvil de gama muy baja se resiente, se puede desactivar a cambio de
perder el detalle de las trazas de GDScript.

El flujo iOS actual genera una IPA sin firma para SideStore. El framework Sentry incluido no contiene
`PrivacyInfo.xcprivacy`; antes de distribuir en App Store, verifica los requisitos vigentes del SDK y
añade el manifiesto de privacidad que corresponda.
