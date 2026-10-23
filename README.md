# invade.io

Juego vertical de estrategia territorial en Godot 4.7.

## Experiencia de jugador

- El menú principal tiene cinco secciones en una barra inferior:
  **Jugar** (mapa del continente, ficha del nivel y «Continuar» a un toque; conquista libre
  y desafío diario como accesos directos), **Invasiones** (regiones reales, tres frentes y
  progreso permanente), **Retos** (recompensa diaria con racha, desafío y misiones),
  **Ejército** (mejoras y aspecto) y **Progreso** (nivel, invasiones, atlas y logros).
  Un punto dorado avisa de recompensas pendientes y de una mejora de combate asequible; no hay
  ventanas emergentes al entrar al menú. Sólo la sección activa queda resaltada.
- Aspecto unificado en `scripts/ui/ui_theme_helper.gd` (paletas clara y oscura, tipografía y
  tema global de Godot con variaciones como `PrimaryButton`, `Sheet`, `HudBar`, `CompactCard`
  o `Caption`) e iconos SVG en `scripts/ui/icons.gd`. El modo claro/oscuro se elige en
  Ajustes › Apariencia y se aplica al instante, también en plena batalla. Una partida nueva
  abre en claro con el mapa **Día claro**; las preferencias guardadas se respetan y el tema
  del mapa se elige aparte en Ejército › Aspecto. Los temas claros ajustan también los
  nombres y las fronteras del campo de batalla para conservar el contraste.
  Los componentes leen `UIThemeHelper.colors`: una única paleta activa, sin copias por color.
- Tropas en paquetes: cada orden sale de la base en grupos pequeños, uno tras otro
  (`scripts/battle/troop.gd`). Las tropas quedan reservadas al dar la orden; las que aún no han
  salido se pierden si cae la base y vuelven a la guarnición si se ordena la retirada.
- En batalla: bases controladas, objetivo de medalla (ganar sin perder bases), anillo de
  destino con la defensa estimada al llegar (verde sobra, dorado ajustado, rojo faltan), ficha
  de base al tocarla, bases llenas marcadas, jefes con arco de refuerzos y textos breves al
  capturar bases especiales. Opción «Reducir movimiento» en accesibilidad.
- Victoria: XP sobre la barra de rango, desbloqueos, ciudades nuevas, marca personal, un
  único siguiente objetivo (`scripts/data/next_goal.gd`) y cobro de misiones sin salir.
  «Mejorar y seguir» sigue disponible después de la primera compra; las sugerencias priorizan
  reclutamiento y guarnición, nunca botín para resolver un combate. Derrota: consejo según lo
  ocurrido, XP y un pequeño premio de oro al capturar bases y resistir al menos 15 s en un
  nivel pendiente (máximo dos premios por nivel, sin diarios ni expediciones). El remate en
  cámara lenta dura como máximo 0,65 s reales por batalla.
- Cada sección es un script corto registrado en `MainMenuUI.TABS`. Las desplazables heredan de
  `ScrollPage` e implementan sólo `_build()`: se redibujan solas al cambiar el oro.
- Campaña de 30 niveles, **36 regiones de invasión con 108 frentes**, conquista libre,
  atlas y tienda de estética. Las invasiones se abren al vencer la campaña de cada continente;
  cada región tiene tres frentes (Frontera, Avance y Capital), estrellas y dominio total.
- La pestaña **Invasiones** muestra el mapa del continente, sus regiones y una ficha con el
  siguiente frente siempre a un toque. Completar una región paga oro; dominar sus tres frentes
  con 3★ paga un extra y completar todas las regiones de un continente desbloquea su color de
  ejército. Las estrellas de invasión viven separadas de las 90 estrellas de campaña.
- Tres misiones diarias con recompensas manuales de oro y XP. El rango del jugador
  (`scripts/data/player_rank.gd`) no modifica el combate: regala estética en ciertos rangos,
  igual que vencer al jefe de cada continente. Colecciones del atlas por continente con
  premio y acceso directo a un nivel desbloqueado con ciudades pendientes. No se promete
  completar todas las ciudades del mundo: las colecciones sólo usan ciudades de campaña.
- Economía: costes cuadráticos suaves, oro de campaña creciente y +150 de oro base por la
  primera victoria contra cada jefe. Las repeticiones no vuelven a pagar ese bonus. El
  comprobador verifica una compra de combate cada 1–3 victorias con la estrategia recomendada;
  el ritmo todavía debe contrastarse con jugadores reales.
- La racha diaria perdona un día de ausencia.
- Desafío diario con tarjeta en el idioma activo para copiar y pegar en un chat (no requiere servidor).
  Incluye la velocidad usada; los segundos son tiempo de simulación. Se juega sin mejoras de
  combate para que las marcas sean comparables y cada día rota una regla de continente.
  Algunos días también se gana manteniendo capitales, fábricas o fortalezas; se explica antes
  de jugar y se muestra el contador en batalla. La IA usa decisiones aleatorias deterministas.
  Las marcas normalizadas anteriores se conservan con su versión de balance, pero no se
  comparan con tiempos de la nueva IA. La tarjeta compartida incluye esa versión.
- Conquista libre en expediciones de 5 regiones con reglas rotatorias; la quinta tiene jefe
  y paga oro doble. El avance entre regiones se conserva entre sesiones.
- Guardados v7 compatibles con el progreso anterior: monedas, mejoras, ciudades, cosméticos
  comprados, invasiones y las misiones del día se conservan. Un guardado v6 carga con las
  invasiones a cero. Al día siguiente entran los nuevos objetivos.
- Ajustes desde el menú y la pausa: idioma, sonido, música, volúmenes, vibración,
  velocidad, paleta accesible y privacidad. La velocidad afecta a ambos bandos y no acelera el reloj diario.
- 15 idiomas de interfaz y datos: inglés, español, portugués (Brasil), francés, alemán,
  italiano, ruso, turco, árabe, hindi, indonesio, vietnamita, chino simplificado, japonés
  y coreano. El árabe usa diseño RTL. El idioma inicial sigue al dispositivo y se puede
  cambiar en Ajustes; las partidas antiguas conservan el suyo.
- Traducciones en `locale/strings.csv` (claves estables, sin texto duplicado en el código).
  Las fuentes Noto por escritura están en `assets/fonts/locale/`; los nombres de ciudad
  localizados vienen de Natural Earth dentro de `assets/data/geo.json`. Para añadir textos,
  edita `locale/strings.csv` y ejecuta `python3 tools/build_locale_csv.py --translate --overrides`;
  después regenera las fuentes con `python3 tools/build_locale_fonts.py <fuentes Noto>`.
- Estadísticas de uso e informes de fallos opcionales (Aptabase y Sentry), desactivados de forma
  predeterminada y activables por separado en Ajustes → Privacidad. No hay cuentas ni identificadores
  persistentes; el juego sigue funcionando sin conexión. Configuración y eventos en `docs/ANALYTICS.md`.
- Respuesta táctil con intensidad persistente y botón de prueba en móviles compatibles,
  un pulso por asalto y límite de repetición. No requiere plugins nativos.
- Guardado automático local con copia de recuperación `.previous`, aviso de errores y reintento
  desde Ajustes. Las versiones futuras se protegen contra sobrescritura. No hay nube.
- Al cambiar de app se guardan los datos, se suspende el audio y se cancela el gesto activo.
  La batalla queda en pausa hasta tocar Reanudar; cerrar el proceso no conserva el combate.
- Copias JSON exportables/restaurables desde ajustes del menú. Una restauración
  pide confirmación y conserva la partida sustituida en `invade_save.json.backup`.
- No hay poderes activos (propuesta 9).

## Reglas de campaña

Los tres primeros niveles conservan su tutorial. A partir de ahí:

| Continente | Regla |
|---|---|
| Europa | Capital marcada ★, +50% producción para quien la controle |
| Norteamérica | Fábricas neutrales que aceleran el reclutamiento |
| Sudamérica | Selva: todas las tropas marchan un 20% más despacio |
| África | Oasis marcado ★, +75% producción |
| Asia | Fortaleza neutral en la frontera |
| Oceanía | Rutas marítimas conectadas, obligatorias para jugador e IA |

El ritmo de combate vive en `LevelDatabase.get_balance()`, separado del índice geográfico:
intervalos completos, una orden por ciclo al empezar, coordinación gradual y un respiro al
abrir continente o expedición. Comprar mejoras nunca endurece a los enemigos. Europa 4
enseña a capturar una fábrica; Europa 5 introduce la fortaleza y un jefe con un solo rival.
Las invasiones reutilizan las seis reglas como firma de región (capital, fábrica, fortaleza,
selva, rutas marítimas u oasis) y reservan la capital y el jefe para el tercer frente.

Cada quinto nivel tiene un jefe ♛: fortaleza de nivel 3 y 6–10 tropas cada 28–22 segundos
mientras permanezca en manos del enemigo original. Cantidades y tiempos se anuncian en la ficha.
Las reglas se explican en el mapa de campaña y durante la batalla. El desafío diario usa
la regla de un continente distinto cada día; las expediciones también rotan esas reglas.

## Validación

```sh
godot --headless --path . res://scenes/tests/test_runner.tscn
```

La suite utiliza un guardado de pruebas separado; nunca sobrescribe la partida real.
Para verificar únicamente las nuevas funcionalidades, sin ejecutar la suite larga:

```sh
godot --headless --path . res://scenes/tests/test_runner.tscn -- --quick
```

Para comprobar únicamente guardado, hápticos, pausa y ajustes:

```sh
godot --headless --path . res://scenes/tests/test_runner.tscn -- --mobile
```

El modo rápido cubre paquetes, choques con distintos deltas, migración, economía, medallas,
colecciones, rangos, objetivos diarios, ritmo de IA y cambio de tema sin perder la selección.

```sh
# 720 partidas: los 30 niveles, cuatro estrategias de mejoras y decisiones cada 2–4 s.
godot --headless --path . res://scenes/tests/balance_check.tscn
# Muestra de invasiones por niveles y capturas de la pestaña en ES/EN, claro/oscuro.
godot --headless --path . res://scenes/tests/balance_check.tscn -- --invasions
godot --path . res://scenes/tests/balance_check.tscn -- --invasion-ui
# Botones reales: victoria → compra → siguiente nivel; derrota → compra → reintento.
godot --headless --path . res://scenes/tests/balance_check.tscn -- --flow
# Capturas y comprobaciones de interacción en los 15 idiomas.
godot --path . res://scenes/tests/balance_check.tscn -- --ui
# Ventana apaisada 1920×1080: menú a dos columnas, batalla, giro durante la partida.
xvfb-run -a godot --path . res://scenes/tests/balance_check.tscn -- --wide-ui
```

Para la ficha de Google Play (necesita pantalla real o `xvfb-run`):

```sh
# Gráfico destacado 1024×500 y capturas ordenadas en docs/store_assets/
godot --path . res://scenes/tests/store_assets.tscn
# Plantilla Gradle + R8 para exportar localmente; se ejecuta una vez por plantilla instalada.
godot --headless --path . --install-android-build-template --export-debug "Android" build/android/invadeio.apk
bash scripts/enable_android_r8.sh
godot --headless --path . --export-release "Android AAB" build/android/invadeio.aab
# Antes de subir: firma, 64 bits, 16 KB, orientación, R8 y contenido del APK/AAB.
BUNDLETOOL_JAR=/path/to/bundletool.jar bash scripts/verify_play_bundle.sh build/android/invadeio.aab build/android/invadeio.apk
```

Estos comprobadores usan guardados separados y devuelven error si falla una condición. Las capturas
no sustituyen las pruebas de ergonomía y rendimiento en un móvil real ni las pruebas de retención con
nuevos jugadores. La exportación local del AAB necesita las variables de firma descritas en
`docs/PLAY_STORE.md`.

## Integración móvil

El preset Android habilita `VIBRATE` y target SDK 36; el preset **Android AAB** genera el paquete
firmado que pide Google Play (ver [plan de publicación](docs/PLAY_STORE.md)). Instala el SDK Android,
las plantillas de Godot 4.7.2 y la plantilla Gradle desde **Proyecto → Instalar plantilla de
compilación Android** antes de exportar. La firma de publicación se toma de las variables
`GODOT_ANDROID_KEYSTORE_RELEASE_*`, nunca del repositorio. El guardado usa `user://` en ambas
plataformas y no necesita acceso general al almacenamiento del teléfono.

### IPA para pruebas con SideStore

El workflow `.github/workflows/build-ios.yml` genera una **IPA sin firmar** para iPhone
usando Godot 4.7.2 y Xcode en un runner macOS de GitHub. No requiere un Mac propio,
cuenta Apple en GitHub, certificados ni secretos. Ejecuta las pruebas rápidas antes de compilar.

1. Haz commit de los cambios y súbelos con `git push`.
2. Cada push a cualquier rama o etiqueta inicia la compilación del último commit automáticamente.
   También puedes iniciarla desde **Actions → Build iOS IPA (SideStore) → Run workflow**.
3. Cuando termine correctamente, descarga **invade.io.ipa** desde **Artifacts**.
   Se descarga directamente como IPA, sin un ZIP adicional, y se conserva durante 7 días.
4. Guarda el archivo en **Archivos** del iPhone. Con Wi-Fi y LocalDevVPN activos,
   abre **SideStore → My Apps → +** y selecciona la IPA.

Los commits locales no activan GitHub Actions hasta hacer push. Un push con varios commits
genera una IPA del último, no una IPA por cada commit intermedio. Los runners estándar son
gratuitos en repositorios públicos; en privados se aplican las cuotas de GitHub Actions.
La IPA no sirve para el App Store, TestFlight ni para instalarla directamente sin firma:
SideStore la firma con tu cuenta y gestiona su renovación. La renovación no exige recompilar.

El identificador estable es `macarronesc.invadeio` (el mismo en Android). La primera IPA con este
identificador se instala como una app nueva: el guardado de la instalación anterior
(`io.github.macarronesc.invadeio`) no se hereda, así que conviene desinstalarla y empezar de cero.
A partir de ahí, para actualizar el juego importa la nueva IPA con la misma cuenta de SideStore sin
desinstalar la anterior.
`0000000000` es sólo un marcador en el preset, no un Team ID real. Al actualizar Godot,
actualiza también los dos SHA-256 de sus descargas en el workflow de iOS (el de Android comprueba SHA-512).

Una compilación correcta no sustituye probar controles, audio, zonas seguras y guardado
en un iPhone real. Los servicios de tienda siguen pendientes:

La propuesta 11 está **pendiente de plugins, configuración de las tiendas y móvil real**.
Las copias manuales no son guardado en la nube ni las estadísticas locales son
clasificaciones online. Ver [requisitos de integración](docs/PLATFORM_INTEGRATION.md) y, para
Android, el [plan de publicación en Google Play](docs/PLAY_STORE.md).

## Licencia

El código y los recursos propios del proyecto se distribuyen bajo Apache-2.0 (ver `LICENSE`). Los
componentes de terceros conservan sus licencias y avisos: Aptabase y Sentry bajo MIT
(`addons/aptabase/LICENSE` y `addons/sentry/LICENSE.md`), las fuentes bajo OFL
(`assets/fonts/LICENSE-OFL.txt`) y los datos cartográficos de Natural Earth en el dominio público.
