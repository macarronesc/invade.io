# invade.io

Juego vertical de estrategia territorial en Godot 4.7.

## Experiencia de jugador

- Campaña de 30 niveles, conquista libre, atlas y tienda de estética.
- Tres misiones diarias con recompensas manuales de oro y XP. El nivel de jugador
  es visual: no modifica el equilibrio de las partidas.
- Desafío diario con tarjeta ES/EN para copiar y pegar en un chat (no requiere servidor).
  Incluye la velocidad usada; los segundos son tiempo de simulación.
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
Las reglas se explican en el mapa de campaña y durante la batalla.
No alteran las regiones procedurales del diario ni de conquista libre.

## Validación

```sh
godot --headless --path . res://scenes/tests/test_runner.tscn
```

La suite utiliza un guardado de pruebas separado; nunca sobrescribe la partida real.

## Integración móvil

La propuesta 11 está **pendiente de plugins, configuración de las tiendas y móvil real**.
Las copias manuales no son guardado en la nube ni las estadísticas locales son
clasificaciones online. Ver [requisitos de integración](docs/PLATFORM_INTEGRATION.md).
