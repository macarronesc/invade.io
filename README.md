# invade.io

Juego vertical de estrategia territorial en Godot 4.7.

## Experiencia de jugador

- El menú principal tiene cuatro secciones en una barra inferior:
  **Jugar** (mapa del continente, ficha del nivel y «Continuar» a un toque; conquista libre
  y desafío diario como accesos directos), **Retos** (recompensa diaria con racha, desafío
  y misiones), **Ejército** (mejoras y aspecto) y **Progreso** (nivel, atlas y logros).
  Un punto dorado avisa de recompensas pendientes y de la primera mejora asequible; no hay
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
  «Mejorar y seguir» propone la primera compra; los premios se pueden equipar desde el
  resultado. Derrota: consejo según lo ocurrido, XP ganada y «Mejorar» sólo si hay una mejora
  asequible. El remate en cámara lenta dura como máximo 0,65 s reales por batalla.
- Cada sección es un script corto registrado en `MainMenuUI.TABS`. Las desplazables heredan de
  `ScrollPage` e implementan sólo `_build()`: se redibujan solas al cambiar el oro.
- Campaña de 30 niveles, conquista libre, atlas y tienda de estética.
- Tres misiones diarias con recompensas manuales de oro y XP. El rango del jugador
  (`scripts/data/player_rank.gd`) no modifica el combate: regala estética en ciertos rangos,
  igual que vencer al jefe de cada continente. Colecciones del atlas por continente con
  premio y acceso directo a un nivel desbloqueado con ciudades pendientes. No se promete
  completar todas las ciudades del mundo: las colecciones sólo usan ciudades de campaña.
- Economía: el coste de las mejoras crece de forma cuadrática suave, evitando el salto de
  casi 200× del coste original. La primera compra se sugiere en Ejército y en el resultado;
  el ritmo de compras todavía debe calibrarse con jugadores reales.
- La racha diaria perdona un día de ausencia.
- Desafío diario con tarjeta ES/EN para copiar y pegar en un chat (no requiere servidor).
  Incluye la velocidad usada; los segundos son tiempo de simulación. Se juega sin mejoras de
  combate para que las marcas sean comparables y cada día rota una regla de continente.
  Algunos días también se gana manteniendo capitales, fábricas o fortalezas; se explica antes
  de jugar y se muestra el contador en batalla. La IA usa decisiones aleatorias deterministas.
  Las antiguas marcas con mejoras no se mezclan con las normalizadas.
- Conquista libre en expediciones de 5 regiones con reglas rotatorias; la quinta tiene jefe
  y paga oro doble. El avance entre regiones se conserva entre sesiones.
- Guardados v5 compatibles con el progreso anterior: monedas, mejoras, ciudades, cosméticos
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

Cada quinto nivel tiene un jefe ♛: fortaleza de nivel 3, guarnición reforzada y
10 tropas cada 18 segundos mientras permanezca en manos del enemigo original.
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
colecciones, rangos, objetivos diarios y cambio de tema sin perder la selección. Las capturas
de escritorio no sustituyen las pruebas de ergonomía y rendimiento en un móvil real ni las
pruebas de retención con nuevos jugadores.

## Integración móvil

La propuesta 11 está **pendiente de plugins, configuración de las tiendas y móvil real**.
Las copias manuales no son guardado en la nube ni las estadísticas locales son
clasificaciones online. Ver [requisitos de integración](docs/PLATFORM_INTEGRATION.md).
