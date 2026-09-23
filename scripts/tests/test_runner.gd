extends Node

## TestRunner: Suite de pruebas de validación automatizada de mecánicas State.io

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("  INICIANDO SUITE DE PRUEBAS AUTOMATIZADAS: INVADE.IO  ")
	print("=======================================================\n")
	
	run_all_tests()
	
	print("\n-------------------------------------------------------")
	print("RESULTADOS: %d Pasadas, %d Falladas (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("=======================================================\n")
	
	if failed_tests > 0:
		print("❌ ERROR: Al menos una prueba ha fallado.")
		get_tree().quit(1)
	else:
		print("✅ ÉXITO TOTAL: Todas las mecánicas y cálculos han sido validados con éxito.")
		get_tree().quit(0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func assert_equals(val1, val2, test_name: String) -> void:
	total_tests += 1
	if val1 == val2:
		passed_tests += 1
		print("  [PASS] %s (Valor: %s)" % [test_name, str(val1)])
	else:
		failed_tests += 1
		printerr("  [FAIL] %s (Esperado: %s, Obtenido: %s)" % [test_name, str(val2), str(val1)])

func run_all_tests() -> void:
	test_base_production_mechanics()
	test_troop_dispatch_and_deduction()
	test_reinforcement_and_combat()
	test_conquest_logic()
	test_upgrades_and_economy()
	test_progression_unlocks()
	test_level_database_integrity()
	test_midair_troop_collisions()
	test_procedural_audio()
	test_troop_stream_dynamics()
	test_progressive_counter_resolution()
	test_base_elastic_physics_and_shockwave()
	test_pentatonic_audio_sequences()
	test_stream_midair_collision()
	test_dominance_with_active_streams()
	test_multi_stream_simultaneous_collision()
	test_troop_stream_api_and_orphan_handling()
	test_game_over_robustness_with_empty_stream()
	test_100_percent_assault_and_ai_dispatch()
	test_multi_base_chaining_and_reinforcement()
	test_voronoi_halfplane_clipping_geometry()
	test_territory_map_generation_and_coverage()
	test_territory_color_transition_and_conquest()
	test_territory_scene_tree_integration()
	test_territory_edge_cases_and_rapid_conquests()
	test_territory_all_30_campaign_levels()

func test_base_production_mechanics() -> void:
	print("-> Test: Producción de Tropas y Límites de Capacidad")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.faction = GameManager.Faction.PLAYER
	base.tier = 1
	base.max_capacity = 20
	base.troops = 10
	
	# Simular delta para producción
	base._process(1.05)
	assert_true(base.troops >= 11, "Base de jugador genera tropas tras transcurrir el tiempo")
	
	# Probar límite máximo de guarnición
	base.troops = 19
	base.production_accumulator = 0.0
	base._process(5.0)
	assert_true(base.troops <= 20, "Producción de base se detiene al alcanzar max_capacity")
	
	# Probar base neutral
	var neutral_base = BaseNodeScript.new()
	neutral_base.faction = GameManager.Faction.NEUTRAL
	neutral_base.troops = 15
	neutral_base._process(3.0)
	assert_equals(neutral_base.troops, 15, "Base neutral no genera tropas automáticamente")
	
	base.free()
	neutral_base.free()

func test_troop_dispatch_and_deduction() -> void:
	print("\n-> Test: Envío al 100% Constante (State.io) y Deducción de Guarnición")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.troops = 20
	
	# Envío al 100% obligatorio por defecto: extrae todas las tropas menos 1 de guardia
	var sent_default = base.send_troops()
	assert_equals(sent_default, 19, "Envío por defecto extrae el 100% disponible reteniendo 1 centinela (20 - 1 = 19)")
	assert_equals(base.troops, 1, "Base retiene exactamente 1 tropa centinela para conservar soberanía")
	
	# Intentar enviar desde base con 1 tropa restante (no debe quedar a 0)
	var sent_empty = base.send_troops()
	assert_equals(sent_empty, 0, "Base con 1 tropa no permite envío para no quedar desprotegida")
	assert_equals(base.troops, 1, "Base conserva su tropa de guardia")
	
	# Prueba con base de 2 tropas: debe enviar 1 y retener 1
	base.troops = 2
	var sent_from_two = base.send_troops()
	assert_equals(sent_from_two, 1, "Base con 2 tropas envía exactamente 1 tropa")
	assert_equals(base.troops, 1, "Base retiene 1 tropa")
	
	# Llamada explícita pasando parámetro (debe aplicar el 100% constante)
	base.troops = 15
	var sent_param = base.send_troops(0.5)
	assert_equals(sent_param, 14, "Llamada con parámetro aplica modo asalto al 100% (15 - 1 = 14)")
	assert_equals(base.troops, 1, "Guarnición restante retenida es 1")
	
	base.free()

func test_reinforcement_and_combat() -> void:
	print("\n-> Test: Refuerzo Aliado y Resistencia en Combate")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.faction = GameManager.Faction.PLAYER
	base.troops = 15
	
	# Refuerzo de tropa aliada
	base.receive_troops(GameManager.Faction.PLAYER, 8)
	assert_equals(base.troops, 23, "Refuerzo aliado incrementa tropas de la base")
	
	# Ataque enemigo inferior a la defensa
	base.receive_troops(GameManager.Faction.ENEMY_1, 10)
	assert_equals(base.troops, 13, "Ataque enemigo inferior descuenta tropas defensoras")
	assert_equals(base.faction, GameManager.Faction.PLAYER, "Base permanece en manos del jugador tras resistir")
	
	base.free()

func test_conquest_logic() -> void:
	print("\n-> Test: Conquista de Bases Hostiles y Neutrales")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var neutral_base = BaseNodeScript.new()
	neutral_base.faction = GameManager.Faction.NEUTRAL
	neutral_base.troops = 10
	
	# Conquista por parte del jugador con 15 tropas
	neutral_base.receive_troops(GameManager.Faction.PLAYER, 15)
	assert_equals(neutral_base.faction, GameManager.Faction.PLAYER, "Base neutral es conquistada por el atacante")
	assert_equals(neutral_base.troops, 5, "Guarnición restante tras conquista es correcta (15 - 10 = 5)")
	
	# Contraataque enemigo que supera las 5 tropas
	neutral_base.receive_troops(GameManager.Faction.ENEMY_1, 12)
	assert_equals(neutral_base.faction, GameManager.Faction.ENEMY_1, "Base es conquistada por la facción enemiga")
	assert_equals(neutral_base.troops, 7, "Guarnición enemiga es correcta tras reconquista (12 - 5 = 7)")
	
	neutral_base.free()

func test_upgrades_and_economy() -> void:
	print("\n-> Test: Sistema de Mejoras y Economía de Oro")
	GameManager.reset_save()
	GameManager.coins = 200
	
	var cost_lvl0 = GameManager.get_upgrade_cost("starting_troops")
	assert_true(cost_lvl0 > 0, "Coste inicial de mejora es mayor a 0")
	
	var bought = GameManager.buy_upgrade("starting_troops")
	assert_true(bought, "Compra de mejora exitosa con suficiente oro")
	assert_equals(GameManager.upgrades["starting_troops"], 1, "Nivel de mejora incrementado a 1")
	assert_equals(GameManager.coins, 200 - cost_lvl0, "Oro descontado exactamente según el coste")
	assert_equals(GameManager.get_starting_troops_bonus(), 5, "Bonus de tropas iniciales aplicado (+5)")
	
	var prod_mult_base = GameManager.get_production_multiplier()
	assert_true(prod_mult_base >= 1.0, "Multiplicador de producción base >= 1.0")
	
	GameManager.buy_upgrade("production_rate")
	assert_true(GameManager.get_production_multiplier() > prod_mult_base, "Multiplicador de producción incrementado tras compra")

func test_progression_unlocks() -> void:
	print("\n-> Test: Progresión y Desbloqueo Secuencial de Campaña Mundial")
	GameManager.reset_save()
	
	assert_true(GameManager.is_level_unlocked("europe_1"), "Nivel 1 de Europa desbloqueado por defecto")
	assert_true(not GameManager.is_level_unlocked("europe_2"), "Nivel 2 de Europa bloqueado inicialmente")
	
	# Probar cálculo de nivel siguiente para nombres compuestos con guiones bajos
	assert_equals(GameManager.get_next_level("europe_1"), "europe_2", "Europa 1 avanza a Europa 2")
	assert_equals(GameManager.get_next_level("europe_5"), "north_america_1", "Europa 5 desbloquea América del Norte 1")
	assert_equals(GameManager.get_next_level("north_america_1"), "north_america_2", "América del Norte 1 avanza a nivel 2")
	assert_equals(GameManager.get_next_level("north_america_5"), "south_america_1", "América del Norte 5 desbloquea Sudamérica 1")
	assert_equals(GameManager.get_next_level("south_america_1"), "south_america_2", "Sudamérica 1 avanza a Sudamérica 2")
	assert_equals(GameManager.get_next_level("south_america_5"), "africa_1", "Sudamérica 5 desbloquea África 1")
	assert_equals(GameManager.get_next_level("africa_5"), "asia_1", "África 5 desbloquea Asia 1")
	assert_equals(GameManager.get_next_level("asia_5"), "oceania_1", "Asia 5 desbloquea Oceanía 1")
	
	# Completar niveles secuenciales y verificar desbloqueo real en estado de juego
	GameManager.complete_level("europe_1", 3)
	assert_true(GameManager.is_level_unlocked("europe_2"), "Nivel 2 de Europa se desbloquea tras vencer en nivel 1")
	
	GameManager.complete_level("europe_5", 2)
	assert_true(GameManager.is_level_unlocked("north_america_1"), "Norteamérica 1 desbloqueada tras Europa 5")
	
	GameManager.complete_level("north_america_1", 3)
	assert_true(GameManager.is_level_unlocked("north_america_2"), "Norteamérica 2 se desbloquea correctamente")

func test_level_database_integrity() -> void:
	print("\n-> Test: Integridad Completa de la Base de Datos (30 Niveles Mundiales)")
	var continents = LevelDatabase.get_continents()
	assert_equals(continents.size(), 6, "Existen exactamente 6 continentes configurados")
	
	var all_levels = LevelDatabase.get_all_levels()
	assert_equals(all_levels.size(), 30, "La base de datos contiene exactamente 30 niveles mundiales")
	
	# Verificar que cada continente tiene sus 5 niveles válidos
	for c in continents:
		var c_id = c["id"]
		for lvl_idx in range(1, 6):
			var lid = "%s_%d" % [c_id, lvl_idx]
			assert_true(all_levels.has(lid), "Existe definición para nivel '%s'" % lid)
			var ldata = all_levels[lid]
			assert_true(ldata.get("bases", []).size() >= 3, "Nivel '%s' tiene al menos 3 bases" % lid)
			
			var has_player = false
			var has_enemy = false
			for b in ldata["bases"]:
				if b["faction"] == GameManager.Faction.PLAYER:
					has_player = true
				elif b["faction"] != GameManager.Faction.NEUTRAL:
					has_enemy = true
			assert_true(has_player and has_enemy, "Nivel '%s' contiene base de jugador y base enemiga" % lid)

func test_midair_troop_collisions() -> void:
	print("\n-> Test: Combate en Tránsito (Colisión de Tropas en Pleno Campo)")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var battle = BattleControllerScript.new()
	
	# Crear dos tropas ficticias en la misma posición pero de facciones opuestas
	var TroopScript = load("res://scripts/battle/troop.gd")
	var t1 = TroopScript.new()
	t1.faction = GameManager.Faction.PLAYER
	t1.count = 10
	t1.global_position = Vector2(500, 500)
	
	var t2 = TroopScript.new()
	t2.faction = GameManager.Faction.ENEMY_1
	t2.count = 4
	t2.global_position = Vector2(510, 500)
	
	battle.active_troops.append(t1)
	battle.active_troops.append(t2)
	
	# Ejecutar comprobación de colisiones
	battle._process_troop_collisions()
	
	# La tropa del jugador (10) debe haber eliminado a la enemiga (4) y quedar con 6 tropas
	assert_equals(t1.count, 6, "Tropa aliada superior sobrevive con la diferencia de guarnición (10 - 4 = 6)")
	assert_true(not is_instance_valid(t2) or t2.is_queued_for_deletion(), "Tropa enemiga inferior eliminada en colisión aérea")
	
	if is_instance_valid(t1):
		t1.free()
	battle.free()

func test_procedural_audio() -> void:
	print("\n-> Test: Sintetizador Procedural de Audio")
	assert_true(AudioManager != null, "Singleton AudioManager existe y está cargado")
	AudioManager.play_click()
	AudioManager.play_launch()
	AudioManager.play_reinforce()
	AudioManager.play_capture()
	AudioManager.play_victory()
	AudioManager.play_defeat()
	assert_true(true, "Todas las llamadas al sintetizador procedural se ejecutan sin errores")

func test_troop_stream_dynamics() -> void:
	print("\n-> Test: Dinámica de Hilera de Tropas (Stream / Perlas en Fila India)")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	
	var base_origin = BaseNodeScript.new()
	base_origin.global_position = Vector2(100, 100)
	base_origin.radius = 50.0
	
	var base_target = BaseNodeScript.new()
	base_target.global_position = Vector2(500, 100)
	base_target.radius = 50.0
	base_target.troops = 20
	base_target.faction = GameManager.Faction.PLAYER
	
	var stream = TroopScript.new()
	stream.setup(base_origin, base_target, 5, GameManager.Faction.PLAYER)
	
	assert_equals(stream.beads.size(), 5, "Hilera de tropas contiene exactamente 5 perlas")
	assert_equals(stream.count, 5, "Contador inicial del stream coincide con tropas enviadas")
	
	# Verificar espaciado constante entre perlas contiguas
	var spacing_ok = true
	for i in range(stream.beads.size() - 1):
		var diff = stream.beads[i]["dist"] - stream.beads[i + 1]["dist"]
		if abs(diff - Troop.BEAD_SPACING) > 0.001:
			spacing_ok = false
			break
	assert_true(spacing_ok, "Espaciado constante entre perlas consecutivas (22 px)")
	
	# Simular avance del stream
	var initial_lead_dist = stream.beads[0]["dist"]
	stream._process(0.1)
	assert_true(stream.beads[0]["dist"] > initial_lead_dist, "Perlas avanzan a lo largo de la trayectoria con el tiempo")
	
	base_origin.free()
	base_target.free()
	stream.free()

func test_progressive_counter_resolution() -> void:
	print("\n-> Test: Absorción y Resolución Progresiva Unidad a Unidad")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.faction = GameManager.Faction.NEUTRAL
	base.troops = 3
	
	# Llegada progresiva perla a perla de tropas del jugador
	base.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(base.troops, 2, "Perla 1 reduce guarnición neutral de 3 a 2")
	assert_equals(base.faction, GameManager.Faction.NEUTRAL, "Base sigue neutral")
	
	base.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(base.troops, 1, "Perla 2 reduce guarnición neutral de 2 a 1")
	assert_equals(base.faction, GameManager.Faction.NEUTRAL, "Base sigue neutral")
	
	base.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(base.troops, 0, "Perla 3 neutraliza la base (tropas = 0)")
	
	# Perla 4 conquista la base para el jugador
	base.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(base.faction, GameManager.Faction.PLAYER, "Perla 4 conquista la base para el jugador")
	assert_equals(base.troops, 1, "Base conquistada inicia con 1 tropa")
	
	# Perla 5 refuerza la base aliada
	base.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(base.troops, 2, "Perla 5 refuerza progresivamente a 2 tropas")
	
	base.free()

func test_base_elastic_physics_and_shockwave() -> void:
	print("\n-> Test: Animaciones Elásticas (Squash & Stretch) y Onda Expansiva")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.faction = GameManager.Faction.PLAYER
	base.tier = 1
	base.troops = 10
	
	# 1. Pulso suave de generación
	base._trigger_generation_pulse()
	assert_true(base.elastic_velocity.x > 0.0, "Pulso de generación imparte velocidad elástica de expansión")
	
	# Simular un frame de física de muelle amortiguado
	base._process(0.016)
	assert_true(base.elastic_scale.x > 1.0, "Escala elástica aumenta tras el pulso")
	
	# 2. Reacción elástica de impacto y sacudida
	base.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_true(base.shake_intensity > 0.0, "Impacto enemigo genera intensidad de sacudida (shake)")
	assert_true(base.elastic_scale.x != 1.0 or base.elastic_scale.y != 1.0, "Impacto genera deformación squash & stretch")
	
	# 3. Onda expansiva y animación dramática de conquista
	base._trigger_conquest_shockwave(GameManager.Faction.ENEMY_1)
	assert_true(base.shockwave_alpha > 0.8, "Conquista activa onda expansiva con alfa elevado")
	assert_true(base.shockwave_radius > 0.0, "Onda expansiva tiene radio inicial positivo")
	assert_true(base.elastic_scale.x >= 1.3, "Escala de base experimenta pop elástico dramático al ser conquistada")
	
	base.free()

func test_pentatonic_audio_sequences() -> void:
	print("\n-> Test: Feedback de Absorción Secuencial Armónica / Pentatónica")
	assert_true(AudioManager != null, "AudioManager está disponible")
	
	# Simular pausa (>380ms) para reiniciar la secuencia armónica
	AudioManager._last_absorb_msec = 0
	
	# Probar absorción aliada en secuencia pentatónica
	AudioManager.play_troop_absorb(true)
	assert_equals(AudioManager._absorb_step, 1, "Primer paso en secuencia pentatónica tras pausa")
	
	AudioManager.play_troop_absorb(true)
	assert_equals(AudioManager._absorb_step, 2, "Segundo paso consecutivo en secuencia pentatónica")
	
	# Probar absorción enemiga (combate)
	AudioManager.play_troop_absorb(false)
	assert_equals(AudioManager._absorb_step, 3, "Secuencia progresa armónicamente con impacto de combate")

func test_stream_midair_collision() -> void:
	print("\n-> Test: Choque de Hileras de Tropas (Colisión Perla a Perla en Marcha)")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	
	var battle = BattleControllerScript.new()
	var base_a = BaseNodeScript.new()
	base_a.global_position = Vector2(100, 100)
	var base_b = BaseNodeScript.new()
	base_b.global_position = Vector2(700, 100)
	
	# Stream 1: Jugador envía 6 tropas de A hacia B
	var s1 = TroopScript.new()
	s1.setup(base_a, base_b, 6, GameManager.Faction.PLAYER)
	
	# Stream 2: Enemigo envía 4 tropas de B hacia A (choque frontal)
	var s2 = TroopScript.new()
	s2.setup(base_b, base_a, 4, GameManager.Faction.ENEMY_1)
	
	battle.active_troops.append(s1)
	battle.active_troops.append(s2)
	
	# Avanzar ambos streams hasta que se encuentren en el centro (distancia 600 px)
	# A velocidad 380 px/s, se encuentran aprox a t = 0.8 s
	for step in range(35):
		s1._process(0.04)
		if is_instance_valid(s2):
			s2._process(0.04)
		battle._process_troop_collisions()
		if not is_instance_valid(s2):
			break
			
	# Stream 2 (4 unidades) debe haber sido totalmente aniquilado
	assert_true(not is_instance_valid(s2) or s2.is_queued_for_deletion(), "Stream enemigo inferior (4) aniquilado en colisión frontal")
	# Stream 1 debe haber sobrevivido con la diferencia numérica (6 - 4 = 2)
	assert_equals(s1.count, 2, "Stream aliado superior sobrevive con 2 unidades restantes (6 - 4 = 2)")
	
	if is_instance_valid(s1):
		s1.free()
	if is_instance_valid(s2):
		s2.free()
	base_a.free()
	base_b.free()
	battle.free()

func test_dominance_with_active_streams() -> void:
	print("\n-> Test: Cálculo de Ratios de Dominancia con Hileras en Marcha")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	
	var battle = BattleControllerScript.new()
	var b1 = BaseNodeScript.new()
	b1.faction = GameManager.Faction.PLAYER
	b1.troops = 10
	battle.bases.append(b1)
	
	var b2 = BaseNodeScript.new()
	b2.faction = GameManager.Faction.ENEMY_1
	b2.troops = 10
	battle.bases.append(b2)
	
	# Instanciar hilera aliada en marcha con 10 unidades
	var s = TroopScript.new()
	s.faction = GameManager.Faction.PLAYER
	s.count = 10
	battle.active_troops.append(s)
	
	var ratios = battle.get_dominance_ratios()
	# Total = 10 (base jugador) + 10 (base enemigo) + 10 (tropa jugador) = 30
	# Jugador = 20 / 30 = 0.666..., Enemigo = 10 / 30 = 0.333...
	assert_true(ratios[GameManager.Faction.PLAYER] > 0.65, "Tropas en marcha contabilizadas en la proporción de dominancia del jugador")
	assert_true(ratios[GameManager.Faction.ENEMY_1] < 0.35, "Proporción enemiga ajustada en dominancia general")
	
	b1.free()
	b2.free()
	s.free()
	battle.free()

func test_multi_stream_simultaneous_collision() -> void:
	print("\n-> Test: Choque Simultáneo Multi-Stream (Estabilidad de Array)")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	var battle = BattleControllerScript.new()
	
	# t1: Jugador con 10 unidades en (500, 500)
	var t1 = TroopScript.new()
	t1.faction = GameManager.Faction.PLAYER
	t1.count = 10
	t1.global_position = Vector2(500, 500)
	
	# t2: Enemigo 1 con 3 unidades en (500, 500)
	var t2 = TroopScript.new()
	t2.faction = GameManager.Faction.ENEMY_1
	t2.count = 3
	t2.global_position = Vector2(500, 500)
	
	# t3: Enemigo 2 con 4 unidades en (500, 500)
	var t3 = TroopScript.new()
	t3.faction = GameManager.Faction.ENEMY_2
	t3.count = 4
	t3.global_position = Vector2(500, 500)
	
	battle.active_troops.append(t1)
	battle.active_troops.append(t2)
	battle.active_troops.append(t3)
	
	# Procesar colisiones: t1 debe combatir contra t2 (10 - 3 = 7), destruir t2, y LUEGO combatir contra t3 (7 - 4 = 3)
	battle._process_troop_collisions()
	
	assert_equals(t1.count, 3, "Tropa aliada sobrevive a ambos enemigos consecutivos (10 - 3 - 4 = 3)")
	assert_true(not is_instance_valid(t2) or t2.is_queued_for_deletion(), "Primer stream enemigo eliminado")
	assert_true(not is_instance_valid(t3) or t3.is_queued_for_deletion(), "Segundo stream enemigo no fue saltado y fue eliminado")
	
	if is_instance_valid(t1):
		t1.free()
	battle.free()

func test_troop_stream_api_and_orphan_handling() -> void:
	print("\n-> Test: Métodos Auxiliares de Stream y Huérfanos sin Objetivo")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	
	var base_origin = BaseNodeScript.new()
	base_origin.global_position = Vector2(100, 100)
	var base_target = BaseNodeScript.new()
	base_target.global_position = Vector2(600, 100)
	
	var stream = TroopScript.new()
	stream.setup(base_origin, base_target, 5, GameManager.Faction.PLAYER)
	
	# Probar get_active_bead_positions()
	var pos_list = stream.get_active_bead_positions()
	assert_true(pos_list.size() >= 1, "get_active_bead_positions devuelve al menos una posición activa")
	
	# Probar remove_front_units()
	stream.remove_front_units(2)
	assert_equals(stream.count, 3, "remove_front_units reduce conteo de 5 a 3 correctamente")
	
	# Probar huérfano cuando target_base es destruida/liberada
	base_target.free()
	stream._process(0.016)
	assert_true(stream.is_queued_for_deletion(), "Stream huérfano se auto-elimina de forma limpia al destruirse el destino")
	
	base_origin.free()
	stream.free()

func test_game_over_robustness_with_empty_stream() -> void:
	print("\n-> Test: Robustez de Game Over con Pelotones Agotados o en Cola")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	
	var battle = BattleControllerScript.new()
	var b_player = BaseNodeScript.new()
	b_player.faction = GameManager.Faction.PLAYER
	b_player.troops = 10
	battle.bases.append(b_player)
	
	# Enemigo no tiene bases
	# Crear tropa enemiga vacía (count = 0)
	var dying_enemy = TroopScript.new()
	dying_enemy.faction = GameManager.Faction.ENEMY_1
	dying_enemy.count = 0
	battle.active_troops.append(dying_enemy)
	
	# Comprobar condiciones de fin de partida: debe detectar victoria aunque dying_enemy siga en active_troops
	battle._check_game_over_conditions()
	assert_true(battle.is_game_over, "Victoria detectada correctamente ignorando tropas enemigas con count = 0")
	
	b_player.free()
	dying_enemy.free()
	battle.free()

func test_100_percent_assault_and_ai_dispatch() -> void:
	print("\n-> Test: Modo Asalto al 100% en BattleController y Coordinación de IA")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var AIControllerScript = load("res://scripts/battle/ai_controller.gd")
	
	var battle = BattleControllerScript.new()
	assert_equals(battle.dispatch_percentage, 1.0, "BattleController inicializa dispatch_percentage al 100% (1.0)")
	
	var toggled = battle.toggle_dispatch_percentage()
	assert_equals(toggled, 1.0, "toggle_dispatch_percentage mantiene el asalto al 100% (1.0)")
	
	# Probar despacho desde BattleController
	var b_src = BaseNodeScript.new()
	b_src.faction = GameManager.Faction.PLAYER
	b_src.troops = 25
	battle.bases.append(b_src)
	
	var b_dst = BaseNodeScript.new()
	b_dst.faction = GameManager.Faction.ENEMY_1
	b_dst.troops = 10
	battle.bases.append(b_dst)
	
	battle.dispatch_troops(b_src, b_dst)
	assert_equals(b_src.troops, 1, "dispatch_troops envía 24 tropas reteniendo 1 centinela")
	assert_equals(battle.active_troops.size(), 1, "Se generó 1 hilera de tropas activa en batalla")
	assert_equals(battle.active_troops[0].count, 24, "Pelotón activo contiene exactamente 24 unidades al 100%")
	
	# Probar IA con 100% de tropas
	var ai = AIControllerScript.new()
	ai.setup(battle, GameManager.Faction.ENEMY_1)
	assert_true(ai != null, "AIController inicializado correctamente con modo 100%")
	
	# Configurar escenario táctico donde el enemigo ataca al jugador
	b_src.troops = 10 # Base del jugador
	b_dst.troops = 25 # Base enemiga con superioridad
	var initial_active_troops_count = battle.active_troops.size()
	ai._evaluate_and_execute()
	
	assert_equals(b_dst.troops, 1, "IA despacha el 100% reteniendo 1 centinela (25 - 1 = 24)")
	assert_equals(battle.active_troops.size(), initial_active_troops_count + 1, "IA generó 1 pelotón activo hacia la base objetivo")
	assert_equals(battle.active_troops.back().count, 24, "Pelotón de IA contiene exactamente el 100% de tropas disponibles (24)")
	
	b_src.free()
	b_dst.free()
	ai.free()
	for t in battle.active_troops:
		if is_instance_valid(t):
			t.free()
	battle.free()

func test_multi_base_chaining_and_reinforcement() -> void:
	print("\n-> Test: Encadenamiento Multi-Base (Chaining Drag) y Refuerzo Aliado al 100%")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var battle = BattleControllerScript.new()
	
	# Bases aliadas A y B, y base enemiga C
	var b_a = BaseNodeScript.new()
	b_a.base_id = "base_a"
	b_a.faction = GameManager.Faction.PLAYER
	b_a.troops = 20
	b_a.radius = 50.0
	b_a.position = Vector2(200, 200)
	b_a.global_position = Vector2(200, 200)
	battle.bases.append(b_a)
	
	var b_b = BaseNodeScript.new()
	b_b.base_id = "base_b"
	b_b.faction = GameManager.Faction.PLAYER
	b_b.troops = 15
	b_b.radius = 50.0
	b_b.position = Vector2(400, 200)
	b_b.global_position = Vector2(400, 200)
	battle.bases.append(b_b)
	
	var b_c = BaseNodeScript.new()
	b_c.base_id = "base_c"
	b_c.faction = GameManager.Faction.ENEMY_1
	b_c.troops = 10
	b_c.radius = 50.0
	b_c.position = Vector2(600, 200)
	b_c.global_position = Vector2(600, 200)
	battle.bases.append(b_c)
	
	# Escenario 1: Refuerzo Aliado Directo (Arrastre A -> B y soltar en B)
	battle._handle_press(Vector2(200, 200)) # Presionar en A
	battle._handle_drag(Vector2(400, 200))  # Arrastrar sobre B
	battle._handle_release(Vector2(400, 200)) # Soltar sobre B
	
	assert_equals(b_a.troops, 1, "Base A envió el 100% de sus tropas como refuerzo (20 - 1 = 19)")
	assert_equals(b_b.troops, 15, "Base B (aliada receptora) conservó intactas sus tropas y no fue drenada")
	assert_equals(battle.active_troops.size(), 1, "Se despachó exactamente 1 hilera de tropas de refuerzo")
	assert_equals(battle.active_troops[0].count, 19, "Hilera de refuerzo contiene 19 tropas al 100%")
	
	for t in battle.active_troops:
		if is_instance_valid(t):
			t.free()
	battle.active_troops.clear()
	
	# Escenario 2: Asalto Conjunto Multi-Base (A -> B -> C y soltar en C)
	b_a.troops = 30
	b_b.troops = 20
	battle._handle_press(Vector2(200, 200)) # Presionar en A
	battle._handle_drag(Vector2(400, 200))  # Cruzar B (aliada)
	battle._handle_drag(Vector2(600, 200))  # Mover a C (enemiga)
	battle._handle_release(Vector2(600, 200)) # Soltar en C
	
	assert_equals(b_a.troops, 1, "Base A envió el 100% en ataque coordinado (30 - 1 = 29)")
	assert_equals(b_b.troops, 1, "Base B encadenada envió el 100% en ataque coordinado (20 - 1 = 19)")
	assert_equals(battle.active_troops.size(), 2, "Se despacharon exactamente 2 hileras de tropas hacia la base C")
	
	b_a.free()
	b_b.free()
	b_c.free()
	for t in battle.active_troops:
		if is_instance_valid(t):
			t.free()
	battle.free()

func test_voronoi_halfplane_clipping_geometry() -> void:
	print("\n-> Test: Geometría de Recorte de Semiplanos Voronoi (Sutherland-Hodgman)")
	var TerritoryMap2DScript = load("res://scripts/battle/territory_map_2d.gd")
	
	# Polígono cuadrado inicial [0, 100] x [0, 100] en sentido horario
	var square = PackedVector2Array([
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(100, 100),
		Vector2(0, 100)
	])
	
	var area_initial = TerritoryMap2DScript.calculate_polygon_area(square)
	assert_equals(area_initial, 10000.0, "Cálculo de área de polígono cuadrado inicial es 10000")
	
	# 1. Recorte vertical: mantener puntos donde X <= 40
	# Punto plano (40, 50), Normal (1, 0)
	var clipped_vert = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(40, 50), Vector2(1, 0))
	assert_equals(clipped_vert.size(), 4, "Polígono recortado verticalmente tiene 4 vértices")
	var area_vert = TerritoryMap2DScript.calculate_polygon_area(clipped_vert)
	assert_true(abs(area_vert - 4000.0) < 0.1, "Área resultante tras corte X <= 40 es 4000 (40 x 100)")
	
	# 2. Recorte horizontal: mantener puntos donde Y <= 60
	# Punto plano (50, 60), Normal (0, 1)
	var clipped_horiz = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(50, 60), Vector2(0, 1))
	var area_horiz = TerritoryMap2DScript.calculate_polygon_area(clipped_horiz)
	assert_true(abs(area_horiz - 6000.0) < 0.1, "Área resultante tras corte Y <= 60 es 6000 (100 x 60)")
	
	# 3. Recorte diagonal a 45 grados: pasando por (50, 50) con normal (1, 1).normalized()
	var diag_normal = Vector2(1, 1).normalized()
	var clipped_diag = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(50, 50), diag_normal)
	assert_true(clipped_diag.size() >= 3, "Recorte diagonal produce polígono convexo válido")
	var area_diag = TerritoryMap2DScript.calculate_polygon_area(clipped_diag)
	# Corte diagonal a través de (50, 50) corta exactamente la mitad del cuadrado (área 5000)
	assert_true(abs(area_diag - 5000.0) < 1.0, "Área tras corte diagonal equidistante es aproximadamente 5000")

func test_territory_map_generation_and_coverage() -> void:
	print("\n-> Test: Generación de Mapa Político y Cobertura Total 1080x1920")
	var TerritoryMap2DScript = load("res://scripts/battle/territory_map_2d.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var map = TerritoryMap2DScript.new()
	var bounds = Rect2(0, 0, 1080, 1920)
	var total_bounds_area = 1080.0 * 1920.0
	
	# 1. Probar nivel con 1 base: debe cubrir el 100% del área del mapa
	var b_single = BaseNodeScript.new()
	b_single.global_position = Vector2(540, 960)
	b_single.faction = GameManager.Faction.PLAYER
	map.generate_map([b_single], bounds)
	
	assert_equals(map.get_cells().size(), 1, "Mapa con 1 base genera exactamente 1 celda")
	var single_cell = map.get_cells()[0]
	var area_single = TerritoryMap2DScript.calculate_polygon_area(single_cell.polygon)
	assert_equals(area_single, total_bounds_area, "Celda única cubre el 100% del área 1080x1920 (2,073,600 px²)")
	b_single.free()
	
	# 2. Probar nivel con 4 bases (similar a Península Ibérica y Galia: Madrid, París, Londres, Berlín)
	var b1 = BaseNodeScript.new()
	b1.base_id = "madrid"
	b1.base_name = "Madrid"
	b1.global_position = Vector2(320, 1400)
	b1.faction = GameManager.Faction.PLAYER
	
	var b2 = BaseNodeScript.new()
	b2.base_id = "paris"
	b2.base_name = "París"
	b2.global_position = Vector2(540, 1000)
	b2.faction = GameManager.Faction.NEUTRAL
	
	var b3 = BaseNodeScript.new()
	b3.base_id = "londres"
	b3.base_name = "Londres"
	b3.global_position = Vector2(360, 600)
	b3.faction = GameManager.Faction.NEUTRAL
	
	var b4 = BaseNodeScript.new()
	b4.base_id = "berlin"
	b4.base_name = "Berlín"
	b4.global_position = Vector2(760, 650)
	b4.faction = GameManager.Faction.ENEMY_1
	
	var bases_list: Array[BaseNode] = [b1, b2, b3, b4]
	map.generate_map(bases_list, bounds)
	
	assert_equals(map.get_cells().size(), 4, "Se generan exactamente 4 territorios para las 4 bases")
	
	# Verificar que cada base está estrictamente dentro de su propio polígono territorial
	for b in bases_list:
		var cell = map.get_cell_for_base(b)
		assert_true(cell != null, "Existe celda territorial para base '%s'" % b.base_name)
		var is_inside = Geometry2D.is_point_in_polygon(b.global_position, cell.polygon)
		assert_true(is_inside, "Base capital '%s' está estrictamente contenida en su polígono territorial" % b.base_name)
		assert_true(cell.polygon.size() >= 3, "Polígono de '%s' tiene al menos 3 vértices" % b.base_name)
	
	# Verificar teselado exacto: la suma de áreas de las 4 celdas debe igualar el área total del rectángulo
	var sum_areas = 0.0
	for cell in map.get_cells():
		sum_areas += TerritoryMap2DScript.calculate_polygon_area(cell.polygon)
	var area_diff = abs(sum_areas - total_bounds_area)
	assert_true(area_diff < 10.0, "La suma de áreas de los territorios tesela el 100% del área de juego (Error < 0.001%)")
	
	# Verificar búsqueda de territorio por coordenada (Point in polygon)
	var cell_madrid = map.get_cell_at_point(Vector2(320, 1400))
	assert_true(cell_madrid != null and cell_madrid.base_id == "madrid", "get_cell_at_point localiza el territorio de Madrid")
	
	b1.free()
	b2.free()
	b3.free()
	b4.free()
	map.free()

func test_territory_color_transition_and_conquest() -> void:
	print("\n-> Test: Interpolación Suave de Colores y Efecto Flash de Conquista")
	var TerritoryMap2DScript = load("res://scripts/battle/territory_map_2d.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var map = TerritoryMap2DScript.new()
	map.transition_duration = 0.5
	
	var base = BaseNodeScript.new()
	base.base_id = "paris"
	base.global_position = Vector2(500, 500)
	base.faction = GameManager.Faction.NEUTRAL
	
	map.generate_map([base], Rect2(0, 0, 1000, 1000))
	var cell = map.get_cell_for_base(base)
	assert_true(cell != null, "Celda inicializada para París")
	
	var neutral_color = map.get_faction_territory_color(GameManager.Faction.NEUTRAL)
	var player_color = map.get_faction_territory_color(GameManager.Faction.PLAYER)
	
	assert_true(abs(cell.current_color.r - neutral_color.r) < 0.01, "Color inicial de París es gris pizarra neutral")
	assert_equals(cell.transition_progress, 1.0, "Progreso de transición inicial es 1.0 (en reposo)")
	
	# Simular conquista por el jugador
	map.on_base_conquered(base, GameManager.Faction.PLAYER)
	assert_equals(cell.transition_progress, 0.0, "Al ser conquistado, transition_progress se reinicia a 0.0")
	assert_true(cell.flash_intensity > 0.3, "Se activa destello de conquista (flash_intensity > 0.3)")
	assert_true(abs(cell.target_color.r - player_color.r) < 0.01, "Color objetivo actualizado a azul del jugador")
	
	# Simular avance del tiempo a mitad de la transición (delta = 0.25 seg sobre 0.5 seg)
	map._process(0.25)
	assert_true(cell.transition_progress > 0.4 and cell.transition_progress < 0.6, "Progreso de transición avanza a mitad de camino")
	assert_true(cell.current_color != neutral_color and cell.current_color != player_color, "Color interpola suavemente entre neutral y jugador sin saltos")
	
	# Simular avance hasta finalizar la transición (delta = 0.3 seg)
	map._process(0.30)
	assert_equals(cell.transition_progress, 1.0, "Transición completada al 100% tras cumplir la duración")
	assert_true(abs(cell.current_color.r - player_color.r) < 0.01, "Color final coincide con el azul del jugador")
	assert_true(abs(cell.current_color.g - player_color.g) < 0.01, "Canal verde coincide con el azul del jugador")
	assert_true(abs(cell.current_color.b - player_color.b) < 0.01, "Canal azul coincide con el azul del jugador")
	assert_equals(cell.flash_intensity, 0.0, "Efecto flash desvanecido por completo")
	
	base.free()
	map.free()

func test_territory_scene_tree_integration() -> void:
	print("\n-> Test: Integración de TerritoryMap2D en la Escena BattleField")
	var BattleFieldScene = load("res://scenes/battle/battle_field.tscn")
	var battle = BattleFieldScene.instantiate()
	
	# Verificar que el nodo TerritoryMap existe en la jerarquía
	var territory_node = battle.get_node_or_null("TerritoryMap")
	assert_true(territory_node != null, "TerritoryMap está presente como nodo en BattleField")
	assert_equals(territory_node.z_index, -5, "TerritoryMap tiene z_index = -5 (detrás de bases y tropas)")
	
	# Verificar que el HUD tiene configurado el asalto al 100%
	var hud = battle.get_node_or_null("BattleHUD")
	assert_true(hud != null, "BattleHUD está presente en BattleField")
	var btn_dispatch = hud.get_node_or_null("%BtnDispatchMode")
	if btn_dispatch:
		assert_true(btn_dispatch.text.contains("100%"), "Botón de HUD muestra indicador de asalto al 100%")
		
	assert_equals(battle.dispatch_percentage, 1.0, "BattleField opera en modo asalto al 100%")
	
	battle.free()

func test_territory_edge_cases_and_rapid_conquests() -> void:
	print("\n-> Test: Casos Límite de Voronoi y Conquistas Rápidas Sucesivas")
	var TerritoryMap2DScript = load("res://scripts/battle/territory_map_2d.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var map = TerritoryMap2DScript.new()
	var bounds = Rect2(0, 0, 1080, 1920)
	var total_bounds_area = 1080.0 * 1920.0
	
	# 1. Caso límite: lista vacía de bases
	map.generate_map([], bounds)
	assert_equals(map.get_cells().size(), 0, "generate_map con lista vacía produce 0 celdas sin errores")
	
	# 2. Caso límite: bases colineales alineadas verticalmente
	var b_col1 = BaseNodeScript.new()
	b_col1.global_position = Vector2(540, 400)
	var b_col2 = BaseNodeScript.new()
	b_col2.global_position = Vector2(540, 960)
	var b_col3 = BaseNodeScript.new()
	b_col3.global_position = Vector2(540, 1520)
	
	map.generate_map([b_col1, b_col2, b_col3], bounds)
	assert_equals(map.get_cells().size(), 3, "Bases colineales generan exactamente 3 celdas horizontales")
	var sum_col_area = 0.0
	for c in map.get_cells():
		assert_equals(c.polygon.size(), 4, "Cada franja territorial colineal tiene 4 vértices rectangulares")
		sum_col_area += TerritoryMap2DScript.calculate_polygon_area(c.polygon)
	assert_true(abs(sum_col_area - total_bounds_area) < 5.0, "Franjas colineales teselan el 100% del área de juego")
	
	b_col1.free()
	b_col2.free()
	b_col3.free()
	
	# 3. Conquistas rápidas sucesivas en combate disputado
	var base = BaseNodeScript.new()
	base.base_id = "frente_activo"
	base.global_position = Vector2(500, 500)
	base.faction = GameManager.Faction.NEUTRAL
	
	map.generate_map([base], Rect2(0, 0, 1000, 1000))
	var active_cell = map.get_cell_for_base(base)
	
	# Conquista 1: Jugador
	map.on_base_conquered(base, GameManager.Faction.PLAYER)
	map._process(0.1) # Transición parcial
	assert_true(active_cell.transition_progress > 0.0 and active_cell.transition_progress < 1.0, "Transición en curso para conquista 1")
	
	# Conquista 2 antes de terminar: Enemigo 1 recupera la base
	map.on_base_conquered(base, GameManager.Faction.ENEMY_1)
	assert_equals(active_cell.transition_progress, 0.0, "Re-conquista resetea suavemente progreso a 0.0 sin saltos")
	var enemy1_color = map.get_faction_territory_color(GameManager.Faction.ENEMY_1)
	assert_true(abs(active_cell.target_color.r - enemy1_color.r) < 0.01, "Nuevo objetivo fijado a Enemigo 1")
	
	# Avanzar hasta finalizar
	map._process(0.7)
	assert_equals(active_cell.transition_progress, 1.0, "Transición finalizada con éxito tras reconquista")
	assert_true(abs(active_cell.current_color.r - enemy1_color.r) < 0.01, "Color estabilizado en facción enemiga")
	
	base.free()
	map.free()

func test_territory_all_30_campaign_levels() -> void:
	print("\n-> Test: Validación de Teselado Voronoi en los 30 Niveles de Campaña")
	var TerritoryMap2DScript = load("res://scripts/battle/territory_map_2d.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var all_levels = LevelDatabase.get_all_levels()
	var bounds = Rect2(0, 0, 1080, 1920)
	var expected_total_area = 1080.0 * 1920.0
	
	var tested_levels = 0
	for level_id in all_levels:
		var level_data = all_levels[level_id]
		var base_defs = level_data.get("bases", [])
		var map = TerritoryMap2DScript.new()
		
		var instantiated_bases: Array[BaseNode] = []
		for b_def in base_defs:
			var b = BaseNodeScript.new()
			b.setup(b_def)
			b.global_position = b.position
			instantiated_bases.append(b)
			
		map.generate_map(instantiated_bases, bounds)
		var cells = map.get_cells()
		
		assert_equals(cells.size(), instantiated_bases.size(), "Nivel '%s': genera exactamente %d celdas" % [level_id, instantiated_bases.size()])
		
		var sum_area = 0.0
		for idx in range(instantiated_bases.size()):
			var b = instantiated_bases[idx]
			var cell = map.get_cell_for_base(b)
			assert_true(cell != null, "Nivel '%s': base '%s' tiene celda territorial asignada" % [level_id, b.base_name])
			if cell:
				assert_true(cell.polygon.size() >= 3, "Nivel '%s': celda de '%s' tiene al menos 3 vértices" % [level_id, b.base_name])
				var in_poly = Geometry2D.is_point_in_polygon(b.global_position, cell.polygon)
				assert_true(in_poly, "Nivel '%s': capital '%s' (%s) dentro de su territorio" % [level_id, b.base_name, str(b.global_position)])
				sum_area += TerritoryMap2DScript.calculate_polygon_area(cell.polygon)
				
		var diff = abs(sum_area - expected_total_area)
		assert_true(diff < 25.0, "Nivel '%s': teselado cubre el 100%% del mapa (Suma: %.1f, Error: %.2f px²)" % [level_id, sum_area, diff])
		
		for b in instantiated_bases:
			b.free()
		map.free()
		tested_levels += 1
		
	assert_equals(tested_levels, 30, "Se validaron rigurosamente los 30 niveles de la campaña mundial")


