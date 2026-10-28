# Publicar invade.io en Google Play

> **La aplicación ya está publicada.** Para renovar la ficha, las capturas, los idiomas
> y las declaraciones de una actualización, usa [PLAY_STORE_UPDATE.md](PLAY_STORE_UPDATE.md).
> Los pasos de alta inicial que aparecen más abajo son referencia histórica, no trabajo pendiente.

Plan completo y comprobaciones para subir el juego a Google Play sin Android Studio. Cada punto
indica **qué falta, dónde se hace (código, GitHub o Play Console) y cómo se comprueba**.

- Paquete Android: `macarronesc.invadeio` (permanente: no se puede cambiar nunca)
- Bundle iOS: `macarronesc.invadeio` (el mismo identificador en las dos plataformas)
- Nombre en la tienda: `invade.io` · Desarrollador: `macarronesc` · Correo: `alegandro2507@gmail.com`
- Botones: **Android** (APK de pruebas) y **Android AAB** (paquete de Play, firmado)

## 1. Estado frente a los requisitos

| Requisito de Google Play | Estado | Detalle |
|---|---|---|
| Target API 36 (obligatorio desde el 31 ago 2026) | ✅ | `gradle_build/target_sdk="36"` en ambos presets |
| Paquete AAB (no APK) para apps nuevas | ✅ | Preset «Android AAB» con `gradle_build/export_format=1` |
| Build firmada y no depurable | ✅ | El flujo firma con la clave de subida; la verificación rechaza paquetes depurables |
| 64 bits | ✅ | Sólo `arm64-v8a` |
| 16 KB de página (obligatorio para API 35+, exigible a las actualizaciones desde el 1 feb 2027) | ✅ | AGP 8.6.1 + NDK 29 alinean a 16 KB; lo comprueba el script |
| Permisos mínimos | ✅ | `VIBRATE`, `INTERNET` y `ACCESS_NETWORK_STATE`; estadísticas e informes de fallos empiezan activos en 0.3.1, con baja independiente |
| Declaración de datos (Data Safety) | ⬜ revisar en Play Console | Actividad de la app, diagnósticos y país aproximado derivado de la IP; opciones activadas por defecto, con baja independiente |
| Política de privacidad | ✅ `docs/privacy-policy.html` | Actualizada para Aptabase y Sentry; hay que publicarla en una URL (paso 4) |
| Icono 512×512 | ✅ | `assets/brand/play-store-icon-512.png` |
| Gráfico destacado 1024×500 sin alfa | ✅ | `docs/store_assets/feature-graphic-1024x500.png` |
| Capturas de tienda | ✅ generador de 8 por idioma | `docs/store_assets/screenshots_<idioma>/` (1080×1920), más 4 capturas de tableta por idioma; validar antes de subir |
| Orientación y redimensionado en pantallas grandes | ⚠️ Implementado; verificar el AAB/dispositivo | Sensor sin bloqueo; menú y batalla adaptan el tablero al apaisado y al cambio de tamaño |
| Optimización R8 | ⚠️ Configurada en CI; verificar AAB firmado | Minificación sólo release; el AAB debe incluir el mapa R8 |
| Título ≤ 30, corta ≤ 80, completa ≤ 4000 | ⚠️ | Los 15 borradores cumplen límites; revisar las traducciones antes de publicarlas |
| Ficha, categoría y etiquetas | ⬜ | Paso 4 |
| Declaraciones de contenido de Play Console | ⬜ | Paso 5 |
| Cuenta de desarrollador verificada en un móvil | ⬜ | Paso 5 (sólo cuentas personales nuevas) |
| Prueba cerrada 12 probadores × 14 días | ⬜ | Paso 5: es el camino crítico real |
| Pruebas en dispositivo real | ⬜ | Paso 6 |

## 2. Lo que ya está hecho en el repositorio

- `export_presets.cfg`: preset **Android AAB** (formato AAB, sólo arm64-v8a, minSdk 24, targetSdk 36,
  versionName 0.3.1, versionCode 5, VIBRATE e iconos, incluido el monocromo). La firma **no** está
  en el repositorio: se lee de las variables `GODOT_ANDROID_KEYSTORE_RELEASE_*`. Antes de subir,
  confirma en Play Console que el código 5 siga disponible; si ya se usó, elige el siguiente código libre.
- `project.godot`: permite redimensionado y rotación con `SCREEN_SENSOR`. La UI mantiene un lienzo con el lado corto
  a 1080 unidades lógicas; Jugar coloca mapa/ficha en columnas en apaisado, y la batalla calcula un
  tablero 1920×1080 con cámara que se vuelve a encajar al girar/redimensionar.
- `.github/workflows/ci.yml`: comprueba secretos/versiones, ejecuta la suite completa y las pruebas
  visuales, exporta el APK Debug con identificador `.debug` y valida un AAB **sin firma** en todas
  las ramas/PR. Sólo un push a `main` puede solicitar `play-release`: un runner nuevo, sin checkout
  ni ejecución del juego, firma el AAB aprobado. Faltan credenciales: falla, nunca omite la firma.
  Tras pasar todas las comprobaciones publica una release de GitHub; no sube a Play automáticamente.
- `scripts/enable_android_r8.sh` + `tools/android/proguard-rules.pro`: parche reproducible e idempotente
  para la plantilla Android que Godot genera en `android/build/` (Godot aplana allí los archivos del
  subdirectorio `app/`; esa carpeta está ignorada por Git). R8 se activa sólo en `release`, sin resource
  shrinking. Las reglas conservan el acceso Java/JNI que necesita Godot; la GDExtension de Sentry es
  nativa y no la optimiza R8.
- `scripts/verify_play_bundle.sh`: puerta de calidad. En el **AAB**: ZIP íntegro, manifiesto,
  arm64 sin 32 bits, `geo.json` presente, sin código de test, **firma válida**, **segmentos ELF de
  todas las librerías a 16 KB**, **la alineación de 16 KB que el paquete pide** (con bundletool),
  identificador, lista exacta de permisos, sin `debuggable`, sin bloqueo de orientación/aspecto y con
  el mapa de desofuscación R8. En el **APK**: target/min SDK, arquitecturas, permisos y **`zipalign -c -P 16`**,
  que verifica el empaquetado real de las librerías.
- `scripts/tests/test_runner.gd` comprueba que los 30 niveles de campaña, los 108 frentes de invasión,
  conquista y desafío diario mantienen ciudades, fuerzas y tiempos, y que las bases apaisadas no se
  solapan. `balance_check.tscn -- --wide-ui` prueba y captura menú y batalla a 1920×1080, incluido un
  giro durante una partida.
- Las capturas de tienda se generan directamente desde escenas reales, con titulares localizados,
  en los 15 idiomas. `store_assets.tscn` ya no depende de una ejecución anterior de `--ui`.
  La suite `balance_check.tscn -- --ui` sigue siendo una comprobación de interfaz independiente.
- Correcciones de esta revisión: el tutorial de arrastre ya no puede congelar la batalla (caduca a los
  20 s), la tarjeta de ayuda abre y cierra bien con el botón atrás de Android, dos glifos que se veían
  como cuadros vacíos, el aviso de logro ya no tapa la cabecera de batalla, los botones de reclamar se
  corrigen solos si la recompensa ya no está disponible, y `geo.json` ya no tiene nombres de ciudad
  sin glifo (12 ciudades). Un test nuevo (`test_ui_glyph_coverage`) impide que vuelva a pasar.

## 3. Falta: clave de subida y secretos de GitHub

Se hace **una sola vez**. No hace falta Android Studio: `keytool` viene con cualquier JDK.

```sh
# 1. Crear la clave de subida, fuera del repositorio. keytool la pide por pantalla
#    (nunca en la línea de comandos: así no queda en el historial del shell).
keytool -genkeypair -v -keystore upload.keystore -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=macarronesc, O=invade.io, C=ES"

# 2. Comprobar que la clave existe (vuelve a pedir la contraseña)
keytool -list -v -keystore upload.keystore | head -20

# 3. Pasarla a texto en un solo renglón
base64 -i upload.keystore | tr -d '\n' > upload.keystore.b64   # macOS
base64 -w0 upload.keystore > upload.keystore.b64               # Linux/GNU
wc -l upload.keystore.b64   # debe decir 0 (una sola línea)

# 4. En GitHub, crea el Environment "play-release", limita deployments a main y añade revisores.
#    Guarda ahí los tres secretos (no como repository secrets).
gh secret set ANDROID_KEYSTORE_BASE64 --env play-release --repo macarronesc/invade.io < upload.keystore.b64
gh secret set ANDROID_KEY_ALIAS      --env play-release --repo macarronesc/invade.io --body 'upload'
gh secret set ANDROID_KEY_PASSWORD   --env play-release --repo macarronesc/invade.io
# Sin gh: Settings → Environments → play-release → Environment secrets
# 5. Huella SHA-256 PÚBLICA del certificado de subida; compárala con Play Console.
gh variable set ANDROID_UPLOAD_CERT_SHA256 --env play-release --repo macarronesc/invade.io
```

Si ya existen secretos homónimos a nivel de repositorio, elimínalos después de comprobar el Environment.
La protección del Environment y de la rama `main` es parte del límite de seguridad de la firma.
El propietario debe aprobar manualmente la firma; no hay bypass de administrador. Mientras sólo
haya un mantenedor, se permite su autoaprobación del despliegue (no es revisión independiente).
La huella inicial se obtuvo del último AAB de `main`, no de acceso a Play Console: compruébala allí.

**La contraseña debe ser sólo ASCII**: letras, números y signos como `! $ = ? # - . _ + @ ~ | &`.
Un solo carácter fuera de ASCII (por ejemplo `£`, `ñ`, `á`) hace fallar la creación de la clave con
`Password is not ASCII`: el almacén PKCS12 cifra la clave privada con un algoritmo que no admite otra
cosa. Tampoco conviene intentar evitarlo con un almacén `JKS` (aceptaría esa contraseña, pero el
mismo valor viaja luego por Gradle, por variables de entorno y por los secretos de GitHub: mejor
quitarlo de la ecuación). La **misma** contraseña para almacén y clave: el plugin Gradle de Godot usa
una sola para las dos, y PKCS12 también lo exige.

Guardas a tener en cuenta:

- **Copia de seguridad** de `upload.keystore` y su contraseña en un gestor de contraseñas y en un
  soporte cifrado fuera del repositorio. Si se pierde, Google permite **resetear la clave de subida**
  desde Play Console (la clave de firma de la app la custodia Google con Play App Signing).
- Nunca subir la clave ni el `.b64` a git: `.gitignore` ya los bloquea.
- Si alguien obtiene la clave no puede publicar en tu nombre (Play exige tu cuenta), pero podría firmar
  APKs falsificados; por eso no se comparte.
- Rotación: si se filtra, se genera otra y se solicita el reset en Play Console; el juego publicado no
  se ve afectado.

## 4. Falta: ficha de la tienda

| Campo | Valor |
|---|---|
| Nombre | `invade.io` |
| Descripción corta / completa | `docs/store_listing/es.md` (ES) y `en.md` (EN) |
| Icono | `assets/brand/play-store-icon-512.png` |
| Gráfico destacado | `docs/store_assets/feature-graphic-1024x500.png` |
| Capturas | `docs/store_assets/screenshots_es/` (y `_en/`) |
| Categoría | Juegos → Estrategia |
| Etiquetas | Estrategia, Un jugador, Sin conexión (las que ofrezca Play) |
| Correo de soporte | `alegandro2507@gmail.com` |
| Política de privacidad | URL pública del paso siguiente |

**Política de privacidad**: `docs/privacy-policy.html` (ES + EN) describe la analítica opcional,
los diagnósticos y el país aproximado derivado de la IP. Para publicarla con una URL activa, sin
servidor propio:

1. GitHub → **Settings → Pages** → *Source*: `GitHub Actions`. El workflow `pages.yml`
   despliega únicamente `docs/privacy-policy.html` desde `main`, con Actions fijadas por SHA.
2. En un minuto estará en `https://macarronesc.github.io/invade.io/privacy-policy.html`.
   Ese es el enlace que se pega en Play Console (App content → Privacy policy).
3. Alternativa: cualquier hosting estático propio; sólo cambia la URL.

Los recursos gráficos se regeneran cuando cambien los mapas o el tema:

```sh
xvfb-run -a godot --audio-driver Dummy --path . res://scenes/tests/store_assets.tscn -- --no-telemetry
python3 tools/build_store_listings.py --package  # valida y crea build/play-store-listing.zip
```

## 5. Falta: Play Console (camino crítico)

Todo esto se hace en la web de Play Console; el orden importa.

1. **Cuenta de desarrollador** (25 USD, pago único). Verificación de identidad y de dispositivo: con
   una cuenta personal nueva hay que abrir la app **Play Console** en un Android real (Android 10+) y
   pulsar *Verify*.
2. **Crear la app**: nombre `invade.io`, idioma predeterminado de la ficha español, tipo *Juego*, gratis.
   La app detecta el idioma del dispositivo; la ficha se puede traducir a los mercados principales.
   Aceptar las declaraciones de políticas y de exportación, y los términos de Play App Signing.
3. **App content** (Política y programas → Contenido de la app), con estas respuestas:
   - **Privacidad**: URL del paso 4.
   - **Anuncios**: No, la app no contiene anuncios.
   - **Acceso a la app**: todas las funciones están disponibles sin iniciar sesión (no hay cuentas).
   - **Público objetivo**: 13 años o más; *no* dirigida a familias/niños.
   - **Clasificación de contenido**: rellenar el cuestionario (IARC). Respuestas honestas: sin
     violencia contra personas (unidades y bases abstractas), sin contenido sexual, sin lenguaje
     soez, sin drogas, sin apuestas, sin contenido generado por usuarios, sin compras. Resultado
     esperable: *Todos / PEGI 3*.
   - **Seguridad de los datos**: *¿La app recoge o comparte datos?* → **Sí**. Declara actividad en la
     app, diagnósticos y ubicación aproximada (país inferido por Aptabase a partir de la IP). Los
     eventos de uso incluyen un identificador temporal de sesión. No hay cuentas ni publicidad; cada
     opción está activada por defecto y se puede desactivar en Ajustes → Privacidad; se respetan
     las bajas guardadas. Antes de publicar, revisa si la región o la tienda exige consentimiento
     previo: un valor predeterminado activo no lo sustituye. Revisa en Play
     Console si el identificador temporal se clasifica como «Device or other IDs». Google considera
     «recogida» cualquier dato que salga del dispositivo, incluida la IP recibida por los proveedores.
   - **Noticias, COVID-19, apps gubernamentales, financieras y de salud**: No.
   - **Permisos peligrosos**: ninguno (VIBRATE, INTERNET y ACCESS_NETWORK_STATE no lo son), así que no
     hay formulario.
4. **Prueba interna** (Probar y publicar → Pruebas → Prueba interna): subir
   `invadeio.aab` desde la release de GitHub, añadirte como probador y comprobar en
   tu móvil que instala, abre y guarda. Si el AAB no sube, Play dirá el motivo exacto (normalmente
   versión repetida o firma).
5. **Prueba cerrada** (obligatoria para cuentas personales nuevas): crear la pista, invitar a
   **12 personas** que mantengan la prueba optada **14 días seguidos** sin salirse, y recoger
   opiniones. Cada subida nueva puede seguir testeándose: aprovechar para corregir lo que reporten.
6. **Solicitar acceso a producción** (Dashboard → *Apply for production*): preguntas sobre la prueba,
   el público y la preparación. La revisión suele tardar 7 días o menos.
7. **Producción**: crear la versión con el mismo AAB (no hay que recompilar), revisar el informe
   previo al lanzamiento (*Pre-launch report*) y lanzar el despliegue por fases (por ejemplo 20 %).

**Registrar el identificador del paquete** (Android developer verification → *Register package name*):
el paquete es `macarronesc.invadeio` y Play pide la **huella SHA-256 de una clave tuya**. Antes de
publicar la única que existe es la de subida:

```sh
keytool -list -v -keystore upload.keystore -alias upload | grep -i sha256
# Copia el valor con dos puntos: SHA256: 5B:2C:...:9F
# Si el campo pide base64:
keytool -list -v -keystore upload.keystore -alias upload | grep -i sha256 | awk '{print $2}' \
  | tr -d ':' | xxd -r -p | base64
```

Debe ser **la misma clave** con la que firma GitHub Actions (`ANDROID_KEYSTORE_BASE64`): si el
identificador se registra con una huella y el AAB llega firmado con otra, Play rechaza la subida. Si
la pantalla ofrece tres opciones (Play Console / clave local / Android Studio), para una app sin
publicar la buena es **la clave local**. Cuando el paquete ya esté publicado, la huella de la clave de
firma de Google aparece en *Test and release → App integrity → Play App Signing*; ésa es la que se usa
para App Links e integraciones, no la de subida.

Notas de la cuenta: si es **de organización** no aplica la prueba cerrada obligatoria, pero sí la
verificación de identidad. El reloj de los 14 días sólo empieza cuando los 12 probadores están dentro,
así que conviene reclutarlos **antes** de subir el primer AAB.

## 6. Publicar una actualización

1. Cambiar `version/code` en los dos presets Android (debe crecer siempre) y, si procede,
   `version/name` (por ejemplo `0.3.1`). Mantén `application/config/version` en `project.godot`
   sincronizado: Sentry lo usa como identificador de release.
2. Abre una PR de release a `main` con versión y códigos mayores. Tras el merge, CI verifica el
   candidato; aprueba la firma sólo después de revisar commit, checks, permisos y código de Play.
3. Descarga `invadeio.aab` de la release de GitHub, verifica `SHA256SUMS` y súbelo a la pista correspondiente; escribe las
   notas de la versión (el texto de cada publicación está en
   [store_listing/release_notes.md](store_listing/release_notes.md)) y publicar.

Los `version/code` ya usados no se pueden repetir nunca en la misma app.
El APK se llama `invadeio-debug.apk`, usa `.debug` y no actualiza la instalación de Play.
Detalles y recuperación de publicaciones parciales: [RELEASES.md](RELEASES.md).

## 7. Comprobar antes de subir

```sh
# Un APK suelto: target/min SDK, arquitecturas y permisos
bash scripts/verify_play_bundle.sh build/android/invadeio.apk

# Instalación/actualización local del template: no vuelvas a instalarlo entre estos pasos.
godot --headless --path . --install-android-build-template --export-debug "Android" build/android/invadeio.apk
bash scripts/enable_android_r8.sh
godot --headless --path . --export-release "Android AAB" build/android/invadeio.aab

# El paquete de Play: firma, orientación, R8/mapa, 16 KB, permisos y contenido.
# Requiere firma, Java y bundletool; CI configura estas variables/credenciales.
BUNDLETOOL_JAR=/path/to/bundletool.jar bash scripts/verify_play_bundle.sh build/android/invadeio.aab build/android/invadeio.apk
```

El script falla con un mensaje concreto en cuanto algo no cumple, así que sirve igual en local y en
CI (es lo que ejecuta el flujo antes de publicar el artefacto). Lo que **no** puede comprobar y hay que
ver en Play Console: que la clave de subida coincida con la registrada, la declaración de datos y el
informe previo al lanzamiento. R8 optimiza Java/Kotlin; no reduce GDScript, el motor/librerías nativas,
geografía ni fuentes, así que no se debe prometer una reducción de RAM sin medirla. Antes de producción,
instala el AAB de prueba en un móvil y una tableta/plegable, gira y redimensiona la ventana durante menú
y batalla, y comprueba el flujo nativo de Sentry con los informes habilitados (R8 no procesa
esa GDExtension nativa).

## 8. Decisiones y avisos

- **Cuenta**: personal (con prueba cerrada de 12×14 días y verificación en móvil) u organización
  (sin prueba obligatoria). Cambia el calendario, no el código.
- **Nombre**: existió una app «invade.io» retirada de Play en 2018 (otro paquete, `com.tdg.ppio`). No
  hay conflicto técnico, pero si la revisión pregunta por el nombre, la respuesta es simple: juego
  distinto, desarrollador distinto, arte y audio propios.
- **Play Games on PC**: los juegos gratis aparecen también en la versión de PC salvo que se desactive.
  El juego es vertical y táctil; conviene revisar esa opción en Play Console (form factors) antes de
  publicar.
- **Pendiente de dispositivo real**: ergonomía con muesca y barra de gestos, vibración, rendimiento en
  un móvil de gama baja (el mapa repinta durante las capturas), 16 KB y arranque en frío. La lista de
  pruebas está en `docs/PLATFORM_INTEGRATION.md`.
- **Fuera de alcance** (no hace falta para publicar): guardado en nube, notificaciones, clasificación
  online, compras. Añadirlas obliga a actualizar la política de privacidad y la declaración de datos.
