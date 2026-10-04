# invade.io

Juego vertical de estrategia territorial en Godot 4.7.

## Experiencia de jugador

- El menú principal tiene cuatro secciones en una barra inferior:
  **Jugar** (mapa del continente, ficha del nivel y «Continuar» a un toque; conquista libre
  y desafío diario como accesos directos), **Retos** (recompensa diaria con racha, desafío
  y misiones), **Ejército** (mejoras y aspecto) y **Progreso** (nivel, atlas y logros).
  Un punto dorado avisa de recompensas pendientes y de una mejora de combate asequible; no hay
  ventanas emergentes al entrar al menú. Sólo la sección activa queda resaltada.
- Aspecto unificado en `scripts/ui/ui_theme_helper.gd` (paletas clara y oscura, tipografía y
  tema global de Godot con variaciones como `PrimaryButton`, `Sheet`, `HudBar` o `Caption`) e
  iconos SVG en `scripts/ui/icons.gd`. El modo claro/oscuro se elige en Ajustes › Apariencia y
  se aplica al instante, también en plena batalla; el mapa conserva su tema de la tienda.
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
- Campaña de 30 niveles, conquista libre, atlas y tienda de estética.
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
- Desafío diario con tarjeta ES/EN para copiar y pegar en un chat (no requiere servidor).
  Incluye la velocidad usada; los segundos son tiempo de simulación. Se juega sin mejoras de
  combate para que las marcas sean comparables y cada día rota una regla de continente.
  Algunos días también se gana manteniendo capitales, fábricas o fortalezas; se explica antes
  de jugar y se muestra el contador en batalla. La IA usa decisiones aleatorias deterministas.
  Las marcas normalizadas anteriores se conservan con su versión de balance, pero no se
  comparan con tiempos de la nueva IA. La tarjeta compartida incluye esa versión.
- Conquista libre en expediciones de 5 regiones con reglas rotatorias; la quinta tiene jefe
  y paga oro doble. El avance entre regiones se conserva entre sesiones.
- Guardados v6 compatibles con el progreso anterior: monedas, mejoras, ciudades, cosméticos
  comprados y las misiones del día se conservan. Al día siguiente entran los nuevos objetivos.
- Ajustes desde el menú y la pausa: idioma, sonido, música, volúmenes, vibración,
  velocidad y paleta accesible. La velocidad afecta a ambos bandos y no acelera el reloj diario.
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

El modo rápido cubre paquetes, choques con distintos deltas, migración, economía, medallas,
colecciones, rangos, objetivos diarios, ritmo de IA y cambio de tema sin perder la selección.

```sh
# 720 partidas: los 30 niveles, cuatro estrategias de mejoras y decisiones cada 2–4 s.
godot --headless --path . res://scenes/tests/balance_check.tscn
# Botones reales: victoria → compra → siguiente nivel; derrota → compra → reintento.
godot --headless --path . res://scenes/tests/balance_check.tscn -- --flow
# En escritorio: 24 capturas ES/EN, claro/oscuro y comprobación de límites de pantalla.
godot --path . res://scenes/tests/balance_check.tscn -- --ui
```

Estos comprobadores usan guardados separados y devuelven error si falla una condición. Las capturas
de escritorio no sustituyen las pruebas de ergonomía y rendimiento en un móvil real ni las
pruebas de retención con nuevos jugadores.

## Integración móvil

### IPA para pruebas con SideStore

El workflow `.github/workflows/build-ios.yml` genera una **IPA sin firmar** para iPhone
usando Godot 4.7.2 y Xcode en un runner macOS de GitHub. No requiere un Mac propio,
cuenta Apple en GitHub, certificados ni secretos. Ejecuta las pruebas rápidas antes de compilar.

1. Sube estos archivos a la rama principal del repositorio.
2. Abre **Actions → Build iOS IPA (SideStore) → Run workflow**.
3. Cuando termine correctamente, descarga **invade.io.ipa** desde **Artifacts**.
   Se descarga directamente como IPA, sin un ZIP adicional, y se conserva durante 7 días.
4. Guarda el archivo en **Archivos** del iPhone. Con Wi-Fi y LocalDevVPN activos,
   abre **SideStore → My Apps → +** y selecciona la IPA.

La compilación es manual para no generar una IPA con cada cambio. Los runners estándar
son gratuitos en repositorios públicos; en privados se aplican las cuotas de GitHub Actions.
La IPA no sirve para el App Store, TestFlight ni para instalarla directamente sin firma:
SideStore la firma con tu cuenta y gestiona su renovación. La renovación no exige recompilar.

El identificador estable es `io.github.macarronesc.invadeio`. Para actualizar el juego,
importa la nueva IPA con la misma cuenta de SideStore sin desinstalar la anterior.
`0000000000` es sólo un marcador en el preset, no un Team ID real. Al actualizar Godot,
actualiza también los dos SHA-256 de sus descargas en el workflow.

Una compilación correcta no sustituye probar controles, audio, zonas seguras y guardado
en un iPhone real. Los servicios de tienda siguen pendientes:

La propuesta 11 está **pendiente de plugins, configuración de las tiendas y móvil real**.
Las copias manuales no son guardado en la nube ni las estadísticas locales son
clasificaciones online. Ver [requisitos de integración](docs/PLATFORM_INTEGRATION.md).
