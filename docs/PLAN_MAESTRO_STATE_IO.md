# Documento de Diseño y Arquitectura de Juego (GDD & TDD)
## Proyecto: **INVADE.IO** — Conquista Territorial y Campaña Mundial

---

## 1. Visión General y Concepto

### 1.1 Premisa
**INVADE.IO** es un videojuego de estrategia táctica en tiempo real (RTS abstracto) inspirado directamente en las mecánicas de *State.io*. El jugador asume el liderazgo de una facción (color Azul) con el objetivo de conquistar territorios divididos en nodos en un mapa geopolítico interactivo que recorre los diferentes continentes de la Tierra (Europa, Asia, América del Norte, América del Sur, África y Oceanía).

### 1.2 Pilares de Diseño
1. **Control Intuitivo y Dinámico (Pick up & Play):** Selección mediante toque/arrastre con respuesta inmediata, visualizando flechas dinámicas y tropas marchando al instante.
2. **Estrategia Numérica Emergente:** Cada territorio tiene un contador visible de tropas. Ganar depende de la gestión de flujos de tropas, cálculo mental rápido y sincronización de ataques multi-frente.
3. **Campaña de Conquista Mundial:** Progresión a través de los continentes de la Tierra con dificultad incremental, diferentes configuraciones topológicas y facciones enemigas rivales.
4. **Bucle de Recompensa y Metajuego:** Conquistas recompensadas con oro y estrellas que permiten mejorar la velocidad de producción, tropas iniciales y velocidad de movimiento.

---

## 2. Mecánicas Principales de Juego (Core Gameplay Mechanics)

### 2.1 Facciones y Colores
El juego maneja hasta 5 facciones simultáneas en batalla:
- **Jugador:** Azul brillante (`#2196F3` / `Color(0.13, 0.59, 0.95)`)
- **Enemigo 1:** Rojo (`#F44336` / `Color(0.96, 0.26, 0.21)`)
- **Enemigo 2:** Amarillo / Ámbar (`#FFC107` / `Color(1.0, 0.76, 0.03)`)
- **Enemigo 3:** Verde (`#4CAF50` / `Color(0.30, 0.69, 0.31)`)
- **Neutral:** Gris pizarra (`#78909C` / `Color(0.47, 0.56, 0.61)`)

### 2.2 Nodos de Territorio (Bases)
Cada territorio del mapa se modela como un nodo/base circular con las siguientes propiedades:
- **ID y Nombre Territorial:** (ej. `node_francia`, "Francia").
- **Propietario (`faction`):** Enum (`NEUTRAL`, `PLAYER`, `ENEMY_1`, `ENEMY_2`, `ENEMY_3`).
- **Tropas Actuales (`troops`):** Entero que representa la guarnición actual.
- **Nivel de Base (`tier`):**
  - **Tier 1 (Pueblo):** Capacidad max 30, radio 40px, tasa base de producción 1.0 tropa/segundo.
  - **Tier 2 (Ciudad):** Capacidad max 65, radio 52px, tasa base de producción 1.6 tropas/segundo.
  - **Tier 3 (Metrópolis / Capital):** Capacidad max 100, radio 64px, tasa base de producción 2.2 tropas/segundo.
- **Producción Automática:**
  - Las bases en posesión de una facción activa (Jugador o Enemigos) generan tropas automáticamente según la fórmula:
    $$\text{TasaEfectiva} = \text{TasaBase} \times (1.0 + \text{MejoraProducción} \times 0.15)$$
  - Las bases **neutrales** NO generan tropas pasivas; tienen una guarnición estática que debe ser vencida.
  - Si las tropas alcanzan el límite de capacidad de la base, la producción se ralentiza o pausa hasta que se envíen tropas.

### 2.3 Sistema de Despliegue y Marcha de Tropas
- **Gesto de Arrastre (Drag-to-Target):**
  - El jugador pulsa sobre una de sus bases y arrastra el dedo o ratón hacia una base objetivo (aliada, neutral o enemiga).
  - Se dibuja una flecha guía animada o línea punteada dinámica que conecta el origen con el destino.
  - **Multi-Origen (Chaining / Multi-Select):** Si el jugador arrastra cruzando varias de sus bases antes de soltar en el objetivo, todas las bases aliadas seleccionadas enviarán tropas al objetivo coordinadamente.
- **Cantidad Enviada:**
  - Por defecto se envía el **50%** de las tropas actuales de la base (o mínimo 1 tropa) para evitar dejar la base origen completamente desprotegida ante contraataques.
  - Opción de alternar mediante botón rápido en HUD o pulsación doble para enviar el **100%**.
- **Comportamiento de las Tropas en Marcha:**
  - Las tropas se instancian como pequeñas unidades esféricas o convoyes que avanzan en línea recta hacia el centro de la base destino a una velocidad constante:
    $$\text{Velocidad} = \text{VelocidadBase} \times (1.0 + \text{MejoraVelocidad} \times 0.10)$$
  - Al impactar con la base destino:
    - **Si la base destino es aliada (misma facción):** Se suman a la guarnición:
      $$\text{TropasDestino} = \text{TropasDestino} + \text{TropasEntrantes}$$
    - **Si la base destino es neutral o enemiga:** Se produce combate:
      $$\text{Diferencia} = \text{TropasDestino} - \text{TropasEntrantes}$$
      - Si $\text{Diferencia} > 0$: La base resiste y sus tropas quedan en $\text{Diferencia}$.
      - Si $\text{Diferencia} == 0$: La base queda en 0 tropas (neutralizada).
      - Si $\text{Diferencia} < 0$: La base es **conquistada** por la facción atacante, adoptando su color e iniciando con $|\text{Diferencia}|$ tropas.

### 2.4 Inteligencia Artificial (AI Bots)
Para recrear la experiencia competitiva de *State.io*, los bots operan de forma descentralizada mediante una máquina de estados y evaluación heurística periódica:
- **Frecuencia de Decisión:** Cada bot evalúa el tablero cada 1.2 a 2.0 segundos (con jitter aleatorio para simular reflejos humanos).
- **Cálculo de Utilidad de Ataque:**
  Para cada base propia $B_{src}$ y cada base destino potencial $B_{dst}$:
  $$\text{Score} = \frac{W_{\text{tipo}} \times (T_{src} \times 0.5 - T_{dst})}{\text{Distancia}(B_{src}, B_{dst})^{0.8}}$$
  Donde $W_{\text{tipo}}$ prioriza:
  1. Bases neutrales pequeñas accesibles ($W = 2.0$).
  2. Bases enemigas débiles con menos tropas que el envío ($W = 1.6$).
  3. Bases aliadas amenazadas para refuerzo ($W = 1.3$).
- **Personalidades de Bots:**
  - *Expansionista:* Prioriza asegurar todos los nodos neutrales antes de entrar en conflicto.
  - *Agresivo:* Ataca inmediatamente las bases del jugador o del rival más cercano.
  - *Oportunista:* Espera a que dos facciones luchen entre sí y ataca la base debilitada inmediatamente tras el asedio.

### 2.5 Condiciones de Fin de Partida
- **Victoria:** Todas las bases enemigas han sido eliminadas y no quedan tropas hostiles en tránsito.
- **Derrota:** El jugador no posee ninguna base y no tiene tropas en tránsito en el mapa.

---

## 3. Campaña Mundial y Progresión de Niveles

### 3.1 Estructura Geográfica (Continentes)
El juego organiza la progresión a través de 6 continentes temáticos:
1. **Europa:**
   - Dificultad: Inicial / Tutorial a Media.
   - Niveles: Europa Occidental (España/Francia), Europa Central (Alemania/Polonia), Islas Británicas, Países Nórdicos, Europa Oriental.
   - Adversarios: 1 Facción Enemiga (Rojo).
2. **América del Norte:**
   - Dificultad: Media.
   - Niveles: Costa Este, Grandes Llanuras, Costa Oeste, Canadá, México y Caribe.
   - Adversarios: 2 Facciones Enemigas (Rojo y Amarillo).
3. **América del Sur:**
   - Dificultad: Media-Alta.
   - Niveles: Cuenca del Amazonas, Cordillera de los Andes, Cono Sur, Región Caribeña.
   - Adversarios: 2 Facciones Enemigas con bases de mayor guarnición.
4. **África:**
   - Dificultad: Alta.
   - Niveles: Norte del Sáhara, Cuerno de África, África Central, África Austral.
   - Adversarios: 3 Facciones Enemigas simultáneas.
5. **Asia:**
   - Dificultad: Muy Alta (Mega-mapas con alta densidad de nodos).
   - Niveles: Oriente Medio, Subcontinente Indio, Este Asiático, Sudeste Asiático, Estepas del Norte.
   - Adversarios: 3 Facciones altamente agresivas.
6. **Oceanía:**
   - Dificultad: Máxima / Nivel Maestro.
   - Niveles: Australia Oriental, Australia Occidental, Nueva Zelanda, Archipiélagos del Pacífico.

### 3.2 Sistema de Recompensas
- **Monedas de Oro por Victoria:** 50 oro base + 10 oro por cada base controlada al finalizar.
- **Calificación por Estrellas (1 a 3):**
  - $\star\star\star$: Victoria en menos de 45 segundos sin perder ninguna base inicial.
  - $\star\star$: Victoria en menos de 90 segundos.
  - $\star$: Victoria independientemente del tiempo.

---

## 4. Sistema de Mejoras (Upgrades)

El jugador invierte sus monedas en la pantalla de mejoras permanente entre batallas:
1. **Guarnición Inicial (Starting Troops):**
   - Nivel 0: +0 tropas adicionales.
   - Por nivel: +5 tropas a la base inicial del jugador al comenzar la partida.
   - Coste: $C_n = 50 \times (1.8)^n$
2. **Velocidad de Producción (Production Rate):**
   - Aumenta la velocidad de reclutamiento de todas las bases aliadas en +15% por nivel.
   - Coste: $C_n = 75 \times (1.8)^n$
3. **Velocidad de Marcha (Troop Speed):**
   - Aumenta la velocidad de desplazamiento de las unidades en el mapa en +10% por nivel.
   - Coste: $C_n = 60 \times (1.8)^n$
4. **Bonus de Recompensa (Gold Multiplier):**
   - Incrementa las monedas obtenidas tras cada victoria en +20% por nivel.
   - Coste: $C_n = 100 \times (1.8)^n$

---

## 5. Diseño de la Interfaz Gráfica (UI / UX)

### 5.1 Especificación de Pantallas y Wireframes

#### Pantalla 1: Menú Principal (`MainMenu`)
- **Cabecera:** Logo en negrita "INVADE.IO", indicador de monedas de oro en la esquina superior derecha con icono dorado.
- **Centro:** Ilustración estilizada o silueta del globo terráqueo con nodos interactivos flotantes de fondo.
- **Botones de Acción:**
  - `JUGAR`: Botón prominente de color verde brillante que lleva a la selección de continente o al siguiente nivel pendiente.
  - `MEJORAS`: Botón con icono de escudo/estrella que abre el panel de upgrades.
  - `AJUSTES`: Botón con icono de engranaje para configuración de audio, idioma y reinicio de partida.

#### Pantalla 2: Mapa Mundial y Selección de Niveles (`WorldMap`)
- **Navegación Superior:** Botón Atrás, Título del Continente actual, Carrusel/Pestañas para cambiar de continente (Europa, América, Asia, etc.).
- **Área Central:** Mapa estilizado con los nodos de nivel interconectados por líneas de puntos.
  - Nodo Desbloqueado: Círculo con número de nivel y 0-3 estrellas doradas debajo.
  - Nodo Bloqueado: Círculo oscuro con icono de candado.
  - Nodo Actual: Efecto de pulso y borde blanco iluminado.
- **Pie:** Botón "JUGAR NIVEL SELECCIONADO" e información de recompensas estimadas.

#### Pantalla 3: Interfaz de Batalla (`BattleHUD`)
- **Barra de Dominancia Superior:**
  - Barra horizontal segmentada en la parte superior de la pantalla que muestra en tiempo real la proporción de tropas/territorios entre las facciones:
    `[=== Azul (45%) ===|== Rojo (30%) ==|= Amarillo (25%) =]`
- **Indicador de Nivel:** Texto centrado bajo la barra: "Europa - Nivel 2: Europa Central".
- **Botón de Pausa:** En la esquina superior izquierda. Abre el diálogo de pausa (Reanudar, Reiniciar, Salir al Mapa).
- **Indicador de Modo de Envío:** Conmutador rápido "50% / 100%" en la esquina inferior izquierda.

#### Pantalla 4: Modal de Victoria (`VictoryDialog`)
- Cartel "¡VICTORIA!" con animación de escala y confeti.
- Representación gráfica de 1 a 3 estrellas con sonido de revelación.
- Detalle de recompensas: "+120 Monedas de Oro".
- Botón "CONTINUAR" / "SIGUIENTE NIVEL" y botón "MAPA".

#### Pantalla 5: Modal de Derrota (`DefeatDialog`)
- Cartel "TERRITORIO PERDIDO" con tono sobrio.
- Mensaje motivacional / Consejo táctico (ej. "Mejora tu velocidad de producción en la tienda").
- Botón "REINTENTAR" y botón "MEJORAS".

#### Pantalla 6: Menú de Mejoras (`UpgradeMenu`)
- Saldo de monedas visible en la parte superior.
- Cuatro tarjetas de mejora verticales con:
  - Icono distintivo.
  - Nombre de la mejora y descripción del efecto actual.
  - Nivel actual (ej. `Nv. 3`).
  - Barra de progreso del nivel.
  - Botón de compra que muestra el coste (ej. `250 🪙`) o "MÁXIMO".

---

## 6. Arquitectura Técnica en Godot 4.7

### 6.1 Estructura del Proyecto
```
invade.io/
├── project.godot
├── docs/
│   └── PLAN_MAESTRO_STATE_IO.md
├── scenes/
│   ├── battle/
│   │   ├── base_node.tscn
│   │   ├── troop.tscn
│   │   └── battle_field.tscn
│   └── ui/
│       ├── main_menu.tscn
│       ├── world_map.tscn
│       ├── battle_hud.tscn
│       ├── upgrade_menu.tscn
│       └── victory_dialog.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── event_bus.gd
│   │   └── audio_manager.gd
│   ├── battle/
│   │   ├── base_node.gd
│   │   ├── troop.gd
│   │   ├── battle_controller.gd
│   │   └── ai_controller.gd
│   ├── data/
│   │   └── level_database.gd
│   ├── ui/
│   │   ├── main_menu.gd
│   │   ├── world_map.gd
│   │   ├── battle_hud.gd
│   │   └── upgrade_menu.gd
│   └── tests/
│       └── test_runner.gd
└── assets/
    └── icon.svg
```

### 6.2 Autoloads (Singletons)
1. **`EventBus` (`scripts/autoload/event_bus.gd`):**
   Desacopla la lógica de juego mediante señales globales:
   - `signal base_selected(base: BaseNode)`
   - `signal base_deselected(base: BaseNode)`
   - `signal base_captured(base: BaseNode, previous_faction: int, new_faction: int)`
   - `signal troops_dispatched(from_base: BaseNode, to_base: BaseNode, count: int, faction: int)`
   - `signal battle_won(stats: Dictionary)`
   - `signal battle_lost()`
   - `signal coins_updated(total_coins: int)`
   - `signal upgrade_purchased(upgrade_id: String, new_level: int)`

2. **`GameManager` (`scripts/autoload/game_manager.gd`):**
   Gestiona la persistencia de datos (guardado en `user://save_game.json`), progreso de niveles, inventario de monedas y cálculo de modificadores de mejoras activos.

3. **`AudioManager` (`scripts/autoload/audio_manager.gd`):**
   Sintetizador de efectos de sonido procedurales para garantizar feedback sonoro completo sin requerir archivos WAV/OGG pesados externos:
   - `play_click()`: Selección de interfaz.
   - `play_launch()`: Despliegue de tropas.
   - `play_capture()`: Conquista de base.
   - `play_reinforce()`: Refuerzo de base aliada.
   - `play_victory()`: Arpegio armónico triunfal.
   - `play_defeat()`: Tono descendente de derrota.

---

## 7. Plan de Pruebas y Validación Automatizada

Para validar rigurosamente el funcionamiento correcto de las mecánicas se diseñará una suite de pruebas ejecutable con Godot en modo headless (`test_runner.gd`) que verifica:
1. **Cálculo de Producción:** Comprobar que una base del jugador genera exactamente la cantidad esperada de tropas por segundo y que las bases neutrales no producen.
2. **Envío y Deducción de Tropas:** Comprobar que al enviar tropas se descuenta el porcentaje correcto de la base origen y se instancia la entidad tropa.
3. **Mecánica de Refuerzo:** Validar que una tropa que llega a una base de la misma facción incrementa las tropas.
4. **Mecánica de Conquista:** Validar que una tropa enemiga decrementa las tropas de una base neutral/rival y, al superar la guarnición, transfiere la propiedad e invierte el color.
5. **Detector de Fin de Partida:** Validar emisión de `battle_won` al caer la última base rival y `battle_lost` al ser erradicado el jugador.
6. **Sistema de Mejoras:** Validar que comprar una mejora descuenta oro, incrementa el nivel y aplica el multiplicador en tiempo de juego.
7. **Progresión de Campaña:** Validar desbloqueo secuencial de niveles tras ganar.
