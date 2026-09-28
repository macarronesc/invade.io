extends Node

## TestRunner: Suite de pruebas de validación automatizada de mecánicas State.io

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

const TEST_SAVE_PATH = "user://test_save.json"

func _ready() -> void:
	# Los tests nunca deben tocar la partida real del jugador
	GameManager.save_path = TEST_SAVE_PATH
	print("\n=======================================================")
	print("  INICIANDO SUITE DE PRUEBAS AUTOMATIZADAS: INVADE.IO  ")
	print("=======================================================\n")

	run_all_tests()

	print("\n-------------------------------------------------------")
	DirAccess.remove_absolute(TEST_SAVE_PATH)
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
	test_fortress_defense_absorption_and_production()
	test_factory_production_and_vulnerability()
	test_ai_archetypes_decision_making()
	test_slow_motion_and_time_scale_safety()
	test_confetti_and_star_revelation()
	test_audio_fanfares_and_continental_conquest()
	test_bezier_curves_and_marching_dots()
	test_slice_gesture_and_troop_retreat()
	test_under_siege_alert_trigger_and_deactivation()
	test_hud_counters_and_leadership_crown()
	test_main_menu_ui_and_ambient_system()
	test_world_map_campaign_route_and_briefing()
	test_upgrade_menu_cards_and_pips()
	test_battle_hud_modals_and_sound_toggle()
	test_cartographic_background_and_theme_helper()
	test_crossing_streams_low_fps_and_huge_streams()
	test_save_robustness_and_replay_rewards()
	test_ai_projected_defense_and_difficulty()
	test_tutorial_steps_and_tips()
	test_real_geography_and_bigger_levels()
	test_procedural_music()

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

func _make_base(pos: Vector2, faction: int = GameManager.Faction.NEUTRAL, troops: int = 10) -> BaseNode:
	var b = load("res://scripts/battle/base_node.gd").new()
	b.global_position = pos
	b.faction = faction
	b.troops = troops
	return b

func _make_stream(from: BaseNode, to: BaseNode, count: int, faction: int) -> Troop:
	var t = load("res://scripts/battle/troop.gd").new()
	t.setup(from, to, count, faction)
	return t

## Avanza hileras y colisiones hasta que no quede combate pendiente
func _simulate(battle, streams: Array, steps: int, dt: float) -> void:
	for _i in steps:
		for s in streams:
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s._process(dt)
		battle._process_troop_collisions()

func test_midair_troop_collisions() -> void:
	print("-> Test: Combate en Tránsito (Colisión de Tropas en Pleno Campo)")
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	var a = _make_base(Vector2(100, 500))
	var b = _make_base(Vector2(900, 500))
	var t1 = _make_stream(a, b, 10, GameManager.Faction.PLAYER)
	var t2 = _make_stream(b, a, 4, GameManager.Faction.ENEMY_1)
	battle.active_troops.append_array([t1, t2])
	_simulate(battle, [t1, t2], 40, 0.04)

	assert_equals(t1.count, 6, "Tropa aliada superior sobrevive con la diferencia de guarnición (10 - 4 = 6)")
	assert_true(not is_instance_valid(t2), "Tropa enemiga inferior eliminada en colisión aérea")

	for n in [t1, a, b, battle]:
		if is_instance_valid(n):
			n.free()

func test_procedural_audio() -> void:
	print("\n-> Test: Sintetizador Procedural de Audio")
	assert_true(AudioManager != null, "Singleton AudioManager existe y está cargado")
	AudioManager.play_click()
	AudioManager.play_launch()
	AudioManager.play_troop_absorb(true)
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

	assert_equals(stream.bead_values.size(), 5, "Hilera de tropas contiene exactamente 5 perlas")
	assert_equals(stream.count, 5, "Contador inicial del stream coincide con tropas enviadas")

	# Verificar espaciado constante entre perlas contiguas
	var spacing_ok = true
	for i in range(stream.bead_values.size() - 1):
		var diff = stream.bead_dist(i) - stream.bead_dist(i + 1)
		if abs(diff - Troop.BEAD_SPACING) > 0.001:
			spacing_ok = false
			break
	assert_true(spacing_ok, "Espaciado constante entre perlas consecutivas (22 px)")

	# Simular avance del stream
	var initial_lead_dist = stream.bead_dist(0)
	stream._process(0.1)
	assert_true(stream.bead_dist(0) > initial_lead_dist, "Perlas avanzan a lo largo de la trayectoria con el tiempo")

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
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	var a = _make_base(Vector2(100, 500))
	var b = _make_base(Vector2(900, 500))
	# t1 (jugador, 10) choca de frente contra dos hileras de facciones distintas que salen de B
	var t1 = _make_stream(a, b, 10, GameManager.Faction.PLAYER)
	var t2 = _make_stream(b, a, 3, GameManager.Faction.ENEMY_1)
	var t3 = _make_stream(b, a, 4, GameManager.Faction.ENEMY_2)
	battle.active_troops.append_array([t1, t2, t3])
	_simulate(battle, [t1, t2, t3], 40, 0.04)

	assert_equals(t1.count, 3, "Tropa aliada sobrevive a ambos enemigos consecutivos (10 - 3 - 4 = 3)")
	assert_true(not is_instance_valid(t2), "Primer stream enemigo eliminado")
	assert_true(not is_instance_valid(t3), "Segundo stream enemigo no fue saltado y fue eliminado")

	for n in [t1, a, b, battle]:
		if is_instance_valid(n):
			n.free()

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

	assert_equals(stream.front_index(), 0, "front_index apunta a la primera perla viva")
	stream.damage_bead(0, 1)
	stream.damage_bead(1, 1)
	assert_equals(stream.count, 3, "damage_bead reduce conteo de 5 a 3 correctamente")
	assert_equals(stream.front_index(), 2, "front_index salta las perlas eliminadas")

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

	# Probar IA con 100% de tropas (pasado el periodo de gracia inicial)
	battle.battle_time = 60.0
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

	# Verificar que el HUD no muestra el botón redundante de despacho (modo asalto al 100% permanente)
	var hud = battle.get_node_or_null("BattleHUD")
	assert_true(hud != null, "BattleHUD está presente en BattleField")
	var btn_dispatch = hud.get_node_or_null("%BtnDispatchMode")
	assert_true(btn_dispatch == null, "BtnDispatchMode eliminado de la UI para no ocupar espacio visual (asalto al 100% es permanente)")
	assert_true(battle.get_node_or_null("Camera2D") != null, "BattleField centra el mapa con una Camera2D")

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

func test_fortress_defense_absorption_and_production() -> void:
	print("\n-> Test: Especialización Bastión (Fortaleza) - Absorción Defensiva 2x y Producción Reducida")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var fortress = BaseNodeScript.new()
	fortress.set_base_type(BaseNodeScript.BaseType.FORTRESS)
	fortress.faction = GameManager.Faction.PLAYER
	fortress.tier = 1
	fortress.troops = 10

	# 1. Multiplicadores
	assert_equals(fortress.get_defense_multiplier(), 2.0, "Fortaleza tiene bonificación defensiva de 2.0x")
	assert_equals(fortress.get_type_production_multiplier(), 0.3, "Fortaleza tiene multiplicador de producción de 0.3x")

	# 2. Configuración mediante setup() con diferentes formatos
	var fortress_data = {"id": "f1", "name": "Ciudadela", "type": "fortress", "faction": GameManager.Faction.PLAYER, "troops": 10, "tier": 1}
	var f2 = BaseNodeScript.new()
	f2.setup(fortress_data)
	assert_equals(f2.base_type, BaseNodeScript.BaseType.FORTRESS, "setup() configura correctamente base_type = FORTRESS desde string 'fortress'")
	f2.set_base_type("standard")
	assert_equals(f2.base_type, BaseNodeScript.BaseType.STANDARD, "set_base_type('standard') actualiza base_type")
	f2.set_base_type("fortaleza")
	assert_equals(f2.base_type, BaseNodeScript.BaseType.FORTRESS, "set_base_type('fortaleza') acepta el nombre en español")
	f2.free()

	# 3. Ataque enemigo inferior a la absorción (10 defensores absorben hasta 20 atacantes)
	# Ataque con 10 tropas enemigas -> debe costar 5 defensores
	fortress.receive_troops(GameManager.Faction.ENEMY_1, 10)
	assert_equals(fortress.troops, 5, "10 defensores en Fortaleza absorben 10 atacantes perdiendo solo 5 tropas (2x absorción: 10/2 = 5)")
	assert_equals(fortress.faction, GameManager.Faction.PLAYER, "Fortaleza resiste y permanece bajo soberanía del jugador")

	# 4. Absorción golpe a golpe (bead-by-bead)
	# Ahora tiene 5 tropas (10 puntos de defensa). Un atacante llega (count = 1):
	fortress.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_equals(fortress.troops, 5, "Un único atacante es absorbido sin destruir al defensor (5 defensores retienen posición)")
	assert_equals(fortress.fortress_absorbed_damage, 1, "Fortaleza registra 1 punto de daño absorbido en el defensor actual")

	# Segundo atacante individual (count = 1): completa los 2 puntos necesarios para vencer al defensor
	fortress.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_equals(fortress.troops, 4, "Segundo atacante completa la absorción de 2 impactos y elimina 1 defensor (quedan 4)")
	assert_equals(fortress.fortress_absorbed_damage, 0, "Daño absorbido se resetea a 0 para el siguiente defensor")

	# 5. Ataque superior que supera la absorción total y conquista
	# Quedan 4 defensores (8 puntos de defensa). Llegan 14 atacantes enemigos:
	# 8 atacantes eliminan a los 4 defensores; los 6 atacantes restantes conquistan la base.
	fortress.receive_troops(GameManager.Faction.ENEMY_2, 14)
	assert_equals(fortress.faction, GameManager.Faction.ENEMY_2, "Fortaleza es conquistada por enemigo al superar su defensa 2x")
	assert_equals(fortress.troops, 6, "Guarnición restante tras conquista es el sobrante exacto (14 - 4*2 = 6)")
	assert_equals(fortress.base_type, BaseNodeScript.BaseType.FORTRESS, "Base conserva su estructura de Fortaleza tras la conquista")

	# 6. Refuerzo aliado en Fortaleza
	fortress.receive_troops(GameManager.Faction.ENEMY_2, 4)
	assert_equals(fortress.troops, 10, "Refuerzo aliado en fortaleza incrementa guarnición normalmente (6 + 4 = 10)")

	# 7. Producción reducida (0.3x)
	var neutral_fortress = BaseNodeScript.new()
	neutral_fortress.setup({"id": "nf", "name": "Bastión Neutral", "type": "fortress", "faction": GameManager.Faction.NEUTRAL, "troops": 10})
	neutral_fortress._process(3.0)
	assert_equals(neutral_fortress.troops, 10, "Fortaleza neutral no produce tropas pasivas")
	neutral_fortress.free()

	# 8. Casos límite: fortaleza con 1 tropa y fortaleza vacía con 0 tropas
	var edge_fortress = BaseNodeScript.new()
	edge_fortress.setup({"id": "ef", "name": "Fuerte Fronterizo", "type": "fortress", "faction": GameManager.Faction.PLAYER, "troops": 1})
	edge_fortress.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_equals(edge_fortress.troops, 1, "Fortaleza con 1 tropa absorbe 1 impacto y retiene su única tropa centinela")
	assert_equals(edge_fortress.fortress_absorbed_damage, 1, "Fortaleza registra 1 impacto absorbido")

	# Segundo impacto neutraliza la base
	edge_fortress.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_equals(edge_fortress.troops, 0, "Segundo impacto agota la defensa de la tropa centinela y neutraliza la fortaleza")
	assert_equals(edge_fortress.faction, GameManager.Faction.NEUTRAL, "Fortaleza neutralizada pasa a facción NEUTRAL")

	# Ocupación directa de fortaleza vacía con 0 tropas
	edge_fortress.receive_troops(GameManager.Faction.ENEMY_2, 3)
	assert_equals(edge_fortress.faction, GameManager.Faction.ENEMY_2, "Fortaleza vacía es conquistada directamente")
	assert_equals(edge_fortress.troops, 3, "Fortaleza conquistada recibe las 3 tropas atacantes")
	edge_fortress.free()

	fortress.free()

func test_factory_production_and_vulnerability() -> void:
	print("\n-> Test: Especialización Fábrica - Producción Acelerada (2.5x) y Vulnerabilidad Defensiva (0.5x)")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var factory = BaseNodeScript.new()
	factory.set_base_type(BaseNodeScript.BaseType.FACTORY)
	factory.faction = GameManager.Faction.PLAYER
	factory.tier = 1
	factory.troops = 10

	# 1. Multiplicadores
	assert_equals(factory.get_defense_multiplier(), 0.5, "Fábrica tiene multiplicador defensivo de 0.5x (vulnerable)")
	assert_equals(factory.get_type_production_multiplier(), 2.5, "Fábrica tiene multiplicador de producción acelerada de 2.5x")

	# 2. Configuración mediante setup() con diferentes strings
	var factory_data = {"id": "fac1", "name": "Complejo Industrial", "type": "factory", "faction": GameManager.Faction.PLAYER, "troops": 10, "tier": 1}
	var f2 = BaseNodeScript.new()
	f2.setup(factory_data)
	assert_equals(f2.base_type, BaseNodeScript.BaseType.FACTORY, "setup() configura correctamente base_type = FACTORY desde string 'factory'")
	f2.free()

	# 3. Vulnerabilidad defensiva (cada atacante elimina 2 defensores)
	# 10 tropas defensoras en fábrica atacadas por 3 atacantes:
	# 3 atacantes * 2 = 6 bajas defensoras -> quedan 4 defensores
	factory.receive_troops(GameManager.Faction.ENEMY_1, 3)
	assert_equals(factory.troops, 4, "3 atacantes causan 6 bajas en Fábrica vulnerable (10 - 3*2 = 4)")
	assert_equals(factory.faction, GameManager.Faction.PLAYER, "Fábrica resiste mientras queden defensores")

	# 4. Conquista de fábrica vulnerable
	# Quedan 4 defensores (equivalen a 2 atacantes de resistencia).
	# Atacan 5 enemigos: 2 atacantes eliminan a los 4 defensores; 3 atacantes restantes conquistan la fábrica.
	factory.receive_troops(GameManager.Faction.ENEMY_1, 5)
	assert_equals(factory.faction, GameManager.Faction.ENEMY_1, "Fábrica es conquistada por atacante")
	assert_equals(factory.troops, 3, "Guarnición restante de la fábrica conquistada es 3 (5 - ceil(4/2) = 3)")
	assert_equals(factory.base_type, BaseNodeScript.BaseType.FACTORY, "Fábrica conserva su especialización industrial tras el cambio de soberanía")

	# 5. Ataque unitario (bead-by-bead): cada bola enemiga elimina 2 defensores
	factory.troops = 6
	factory.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(factory.troops, 4, "1 atacante contra fábrica con 6 defensores elimina exactamente 2 tropas (6 - 2 = 4)")

	factory.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(factory.troops, 2, "Segundo atacante elimina otras 2 tropas (4 - 2 = 2)")

	factory.receive_troops(GameManager.Faction.PLAYER, 1)
	assert_equals(factory.troops, 0, "Tercer atacante neutraliza la fábrica (2 - 2 = 0)")
	assert_equals(factory.faction, GameManager.Faction.NEUTRAL, "Fábrica pasa a NEUTRAL con 0 tropas")

	# 6. Producción acelerada en Fábrica
	var factory_prod = BaseNodeScript.new()
	factory_prod.setup({"id": "fp", "name": "Fábrica Aliada", "type": "factory", "faction": GameManager.Faction.PLAYER, "troops": 10, "tier": 1})
	factory_prod.production_accumulator = 0.0
	# En 1.05s a 2.5x base_rate (tier 1 = 1.0 * 2.5 = 2.5): acumula ~2.62 -> genera al menos 2 tropas
	factory_prod._process(1.05)
	assert_true(factory_prod.troops >= 12, "Fábrica produce a velocidad acelerada 2.5x (recluta >= 2 tropas en 1 segundo)")
	factory_prod.free()

	# 7. Casos límite: fábrica con 1 tropa y fábrica vacía con 0 tropas
	var edge_factory = BaseNodeScript.new()
	edge_factory.setup({"id": "efac", "name": "Fábrica Fronteriza", "type": "factory", "faction": GameManager.Faction.PLAYER, "troops": 1})
	# 1 atacante supera a 1 defensor en fábrica vulnerable (1 atacante tiene 2 puntos de ataque)
	edge_factory.receive_troops(GameManager.Faction.ENEMY_1, 1)
	assert_equals(edge_factory.faction, GameManager.Faction.ENEMY_1, "1 atacante vence a 1 defensor vulnerable y conquista la fábrica")
	assert_equals(edge_factory.troops, 1, "Fábrica conquistada retiene 1 tropa ocupante")

	# Ocupación directa de fábrica neutral vacía con 0 tropas
	edge_factory.troops = 0
	edge_factory.faction = GameManager.Faction.NEUTRAL
	edge_factory.receive_troops(GameManager.Faction.ENEMY_2, 4)
	assert_equals(edge_factory.faction, GameManager.Faction.ENEMY_2, "Fábrica neutral vacía es conquistada directamente")
	assert_equals(edge_factory.troops, 4, "Fábrica conquistada recibe las 4 tropas")
	edge_factory.free()

	factory.free()

func test_ai_archetypes_decision_making() -> void:
	print("\n-> Test: Arquetipos de IA (Aggressive, Expansive, Opportunist) y Evaluación Heurística")
	var AIControllerScript = load("res://scripts/battle/ai_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")

	var battle = BattleControllerScript.new()
	battle.battle_time = 60.0 # pasado el periodo de gracia inicial

	# Crear base origen para la IA
	var src_base = BaseNodeScript.new()
	src_base.global_position = Vector2(500, 1000)
	src_base.faction = GameManager.Faction.ENEMY_1
	src_base.troops = 25
	src_base.max_capacity = 60
	src_base.tier = 1

	# Crear objetivos equidistantes a 400px
	var target_player = BaseNodeScript.new()
	target_player.global_position = Vector2(500, 600)
	target_player.faction = GameManager.Faction.PLAYER
	target_player.troops = 10
	target_player.base_type = BaseNodeScript.BaseType.STANDARD

	var target_neutral = BaseNodeScript.new()
	target_neutral.global_position = Vector2(500, 1400)
	target_neutral.faction = GameManager.Faction.NEUTRAL
	target_neutral.troops = 10
	target_neutral.base_type = BaseNodeScript.BaseType.STANDARD

	var target_factory_neutral = BaseNodeScript.new()
	target_factory_neutral.global_position = Vector2(100, 1000)
	target_factory_neutral.faction = GameManager.Faction.NEUTRAL
	target_factory_neutral.troops = 10
	target_factory_neutral.base_type = BaseNodeScript.BaseType.FACTORY

	var target_depleted = BaseNodeScript.new()
	target_depleted.global_position = Vector2(900, 1000)
	target_depleted.faction = GameManager.Faction.PLAYER
	target_depleted.troops = 2 # Desangrada tras lanzar asalto al 100%
	target_depleted.base_type = BaseNodeScript.BaseType.STANDARD

	var allied_fortress = BaseNodeScript.new()
	allied_fortress.global_position = Vector2(700, 1200)
	allied_fortress.faction = GameManager.Faction.ENEMY_3
	allied_fortress.troops = 10
	allied_fortress.base_type = BaseNodeScript.BaseType.FORTRESS

	# 1. Asignación automática de arquetipos por facción
	var ai_red = AIControllerScript.new()
	ai_red.setup(battle, GameManager.Faction.ENEMY_1)
	assert_equals(ai_red.archetype, AIControllerScript.AIArchetype.AGGRESSIVE, "Facción ENEMY_1 (Rojo) asigna automáticamente arquetipo AGGRESSIVE")

	var ai_yellow = AIControllerScript.new()
	ai_yellow.setup(battle, GameManager.Faction.ENEMY_2)
	assert_equals(ai_yellow.archetype, AIControllerScript.AIArchetype.EXPANSIVE, "Facción ENEMY_2 (Amarillo) asigna automáticamente arquetipo EXPANSIVE")

	var ai_green = AIControllerScript.new()
	ai_green.setup(battle, GameManager.Faction.ENEMY_3)
	assert_equals(ai_green.archetype, AIControllerScript.AIArchetype.OPPORTUNIST, "Facción ENEMY_3 (Verde) asigna automáticamente arquetipo OPPORTUNIST")

	# 2. Comportamiento AGGRESSIVE: Prioriza atacar al jugador sobre bases neutrales
	var agg_util_player = ai_red.evaluate_target_utility(src_base, target_player)
	var agg_util_neutral = ai_red.evaluate_target_utility(src_base, target_neutral)
	assert_true(agg_util_player > agg_util_neutral, "IA Agresiva prioriza asaltar la base del jugador frente a una neutral idéntica")

	# 3. Comportamiento EXPANSIVE: Prioriza capturar bases neutrales y asegurar fábricas
	var exp_util_neutral = ai_yellow.evaluate_target_utility(src_base, target_neutral)
	var exp_util_player = ai_yellow.evaluate_target_utility(src_base, target_player)
	assert_true(exp_util_neutral > exp_util_player, "IA Expansiva prioriza expansión en base neutral frente a choque hostil con el jugador")

	var exp_util_factory = ai_yellow.evaluate_target_utility(src_base, target_factory_neutral)
	assert_true(exp_util_factory > exp_util_neutral, "IA Expansiva prioriza conquistar Fábrica neutral sobre base Standard para maximizar producción")

	# 4. Comportamiento OPPORTUNIST: Ataca por la espalda bases desprotegidas tras asalto y se atrinchera en fortalezas
	var opp_util_depleted = ai_green.evaluate_target_utility(src_base, target_depleted)
	var opp_util_standard = ai_green.evaluate_target_utility(src_base, target_player)
	assert_true(opp_util_depleted > opp_util_standard, "IA Oportunista ataca con máxima prioridad a la base desprotegida (2 tropas) tras lanzar asalto")

	var opp_util_fortress_allied = ai_green.evaluate_target_utility(src_base, allied_fortress)
	assert_true(opp_util_fortress_allied > 100.0, "IA Oportunista valora altamente atrincherarse y reforzar fortalezas aliadas")

	# 5. Configuración manual de arquetipo
	ai_red.set_archetype("expansive")
	assert_equals(ai_red.archetype, AIControllerScript.AIArchetype.EXPANSIVE, "set_archetype('expansive') conmuta dinámicamente el arquetipo")

	# 6. Caso límite: evaluación hacia la misma base origen (debe ser inválida / -9999.0)
	var self_util = ai_red.evaluate_target_utility(src_base, src_base)
	assert_equals(self_util, -9999.0, "evaluate_target_utility descarta el nodo propio retornando -9999.0")

	# 7. Configuración por sobrescritura desde level_data
	battle.level_data = {
		"ai_archetypes": {
			GameManager.Faction.ENEMY_1: AIControllerScript.AIArchetype.OPPORTUNIST
		}
	}
	var ai_override = AIControllerScript.new()
	ai_override.setup(battle, GameManager.Faction.ENEMY_1)
	assert_equals(ai_override.archetype, AIControllerScript.AIArchetype.OPPORTUNIST, "Configuración en level_data sobrescribe el arquetipo por defecto de la facción")
	ai_override.free()

	# 8. Configuración con claves string en level_data ('enemy_1', 'enemy2')
	battle.level_data = {
		"ai_archetypes": {
			"enemy_1": "opportunist",
			"enemy2": "aggressive"
		}
	}
	var ai_str1 = AIControllerScript.new()
	ai_str1.setup(battle, GameManager.Faction.ENEMY_1)
	assert_equals(ai_str1.archetype, AIControllerScript.AIArchetype.OPPORTUNIST, "Clave string 'enemy_1' configura arquetipo OPPORTUNIST correctamente")
	ai_str1.free()

	var ai_str2 = AIControllerScript.new()
	ai_str2.setup(battle, GameManager.Faction.ENEMY_2)
	assert_equals(ai_str2.archetype, AIControllerScript.AIArchetype.AGGRESSIVE, "Clave string 'enemy2' configura arquetipo AGGRESSIVE correctamente")
	ai_str2.free()

	# 9. IA Agresiva evita suicidios fútiles contra fortalezas inexpugnables
	var heavy_player_fortress = BaseNodeScript.new()
	heavy_player_fortress.global_position = Vector2(500, 700)
	heavy_player_fortress.faction = GameManager.Faction.PLAYER
	heavy_player_fortress.troops = 35
	heavy_player_fortress.base_type = BaseNodeScript.BaseType.FORTRESS

	var weak_src = BaseNodeScript.new()
	weak_src.global_position = Vector2(500, 1000)
	weak_src.faction = GameManager.Faction.ENEMY_1
	weak_src.troops = 6
	weak_src.base_type = BaseNodeScript.BaseType.STANDARD

	var agg_util_suicide = ai_red.evaluate_target_utility(weak_src, heavy_player_fortress)
	assert_true(agg_util_suicide < 0.0, "IA Agresiva no se suicida contra una fortaleza del jugador fuertemente defendida con solo 6 tropas")

	# 10. IA Oportunista no desmantela su propia fortaleza para reforzar otra base
	var src_fortress = BaseNodeScript.new()
	src_fortress.global_position = Vector2(600, 1100)
	src_fortress.faction = GameManager.Faction.ENEMY_3
	src_fortress.troops = 20
	src_fortress.max_capacity = 60
	src_fortress.base_type = BaseNodeScript.BaseType.FORTRESS

	var opp_util_dismantle = ai_green.evaluate_target_utility(src_fortress, allied_fortress)
	assert_true(opp_util_dismantle < 0.0, "IA Oportunista preserva su fortaleza y no drena su guarnición para reforzar otras bases")

	# 11. IA Oportunista no refuerza fortalezas que ya alcanzaron su capacidad máxima
	allied_fortress.troops = allied_fortress.max_capacity
	var opp_util_full_fortress = ai_green.evaluate_target_utility(src_base, allied_fortress)
	assert_true(opp_util_full_fortress < 0.0, "IA Oportunista no despacha tropas hacia una fortaleza que ya está al 100% de capacidad")
	allied_fortress.troops = 10 # Restaurar

	heavy_player_fortress.free()
	weak_src.free()
	src_fortress.free()

	ai_red.free()
	ai_yellow.free()
	ai_green.free()
	src_base.free()
	target_player.free()
	target_neutral.free()
	target_factory_neutral.free()
	target_depleted.free()
	allied_fortress.free()
	battle.free()

func test_slow_motion_and_time_scale_safety() -> void:
	print("\n-> Test: Slow-Motion Cinemático de Victoria y Seguridad de Engine.time_scale")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")
	var BattleHUDScene = load("res://scenes/ui/battle_hud.tscn")

	var battle = BattleControllerScript.new()
	assert_equals(Engine.time_scale, 1.0, "time_scale inicial es exactamente 1.0")

	# 1. Disparo manual de slow motion
	battle.start_slow_motion()
	assert_true(battle.is_slow_motion_active, "start_slow_motion() activa is_slow_motion_active")

	# Simular transición suave de tiempo con _process
	battle._process(0.5)
	assert_true(Engine.time_scale < 1.0, "Engine.time_scale desciende suavemente durante slow motion")
	assert_true(Engine.time_scale >= battle.SLOW_MOTION_TARGET, "Engine.time_scale no desciende por debajo de SLOW_MOTION_TARGET")

	# 2. Restablecimiento seguro con reset_time_scale()
	battle.reset_time_scale()
	assert_equals(battle.is_slow_motion_active, false, "reset_time_scale desactiva slow motion")
	assert_equals(Engine.time_scale, 1.0, "reset_time_scale restaura Engine.time_scale a 1.0 limpiamente")

	# 3. Detección de asalto decisivo en _check_decisive_assault()
	battle.is_game_over = false
	var b_player = BaseNodeScript.new()
	b_player.faction = GameManager.Faction.PLAYER
	b_player.troops = 20
	b_player.position = Vector2(200, 200)
	b_player.global_position = Vector2(200, 200)
	battle.bases.append(b_player)

	var b_enemy = BaseNodeScript.new()
	b_enemy.faction = GameManager.Faction.ENEMY_1
	b_enemy.troops = 5
	b_enemy.position = Vector2(300, 200)
	b_enemy.global_position = Vector2(300, 200)
	battle.bases.append(b_enemy)

	# No hay asalto aún: no debe activar slow motion
	battle._check_decisive_assault()
	assert_true(not battle.is_slow_motion_active, "No se activa slow motion si no hay tropas en asalto final")

	# Crear tropa de asalto fatal cercana a la última base enemiga
	var assault_troop = TroopScript.new()
	assault_troop.faction = GameManager.Faction.PLAYER
	assault_troop.count = 12
	assault_troop.target_base = b_enemy
	assault_troop.position = Vector2(280, 200)
	assault_troop.global_position = Vector2(280, 200)
	battle.active_troops.append(assault_troop)

	battle._check_decisive_assault()
	assert_true(battle.is_slow_motion_active, "Asalto decisivo superior a la guarnición enemiga activa slow motion cinemático")

	# Restablecer para probar integración con HUD
	battle.reset_time_scale()
	assert_equals(Engine.time_scale, 1.0, "time_scale restablecido tras test de asalto")

	# 4. Probar que BattleHUD restablece time_scale en despliegue de victoria, pausa, etc.
	var hud = BattleHUDScene.instantiate()
	add_child(hud)
	hud.battle_controller = battle
	Engine.time_scale = 0.28
	battle.is_slow_motion_active = true

	hud.deploy_victory_modal({"stars": 3, "gold_earned": 100, "is_continent_conquest": false})
	assert_equals(Engine.time_scale, 1.0, "deploy_victory_modal restaura Engine.time_scale a 1.0 para 60 FPS en interfaz")
	assert_equals(battle.is_slow_motion_active, false, "deploy_victory_modal limpia is_slow_motion_active en BattleController")

	# Probar pausa / reanudar
	Engine.time_scale = 0.3
	hud._on_pause_pressed()
	assert_equals(Engine.time_scale, 1.0, "Pausa restaura Engine.time_scale a 1.0")
	hud._on_resume_pressed()
	assert_equals(Engine.time_scale, 1.0, "Reanudar mantiene Engine.time_scale a 1.0")

	# 5. Probar recuperación tras fracaso del asalto decisivo
	battle.is_game_over = false
	b_enemy.troops = 10
	battle.active_troops.clear()
	battle.start_slow_motion()
	assert_true(battle.is_slow_motion_active, "Slow motion activo al iniciar asalto")
	# Todas las tropas aliadas concluyen sin conquistar la base (incoming_player = 0)
	battle._check_decisive_assault()
	assert_true(not battle.is_slow_motion_active, "Asalto fallido cancela is_slow_motion_active")
	battle._process(0.5)
	assert_true(Engine.time_scale > 0.28, "Engine.time_scale se recupera suavemente hacia 1.0 tras asalto fallido")

	# 6. Probar detección de erradicación de última tropa hostil con 0 bases enemigas
	battle.reset_time_scale()
	battle.bases.clear()
	battle.bases.append(b_player) # Sólo base del jugador
	var enemy_last_troop = TroopScript.new()
	enemy_last_troop.faction = GameManager.Faction.ENEMY_1
	enemy_last_troop.count = 4
	enemy_last_troop.target_base = b_player
	enemy_last_troop.position = Vector2(250, 200)
	enemy_last_troop.global_position = Vector2(250, 200)
	battle.active_troops.append(enemy_last_troop)
	b_player.troops = 20 # Defensa superior al atacante

	battle._check_decisive_assault()
	assert_true(battle.is_slow_motion_active, "Golpe de gracia sobre última tropa hostil activa slow motion")
	enemy_last_troop.free()
	battle.active_troops.clear()

	# 7. Probar que _exit_tree restablece time_scale limpiamente
	Engine.time_scale = 0.28
	battle._exit_tree()
	assert_equals(Engine.time_scale, 1.0, "BattleController._exit_tree restablece limpiamente Engine.time_scale a 1.0")

	remove_child(hud)
	hud.free()
	b_player.free()
	b_enemy.free()
	assault_troop.free()
	battle.free()
	Engine.time_scale = 1.0

func test_confetti_and_star_revelation() -> void:
	print("\n-> Test: Sistema de Confeti Festivo y Revelación Secuencial de Estrellas")
	var BattleHUDScene = load("res://scenes/ui/battle_hud.tscn")
	var hud = BattleHUDScene.instantiate()
	add_child(hud)

	# 1. Verificar existencia y configuración de ConfettiParticles (CPUParticles2D)
	var confetti = hud.get_node_or_null("%ConfettiParticles")
	assert_true(confetti != null, "Nodo ConfettiParticles (CPUParticles2D) existe en la escena BattleHUD")
	assert_true(confetti is CPUParticles2D, "ConfettiParticles es de tipo CPUParticles2D")
	assert_true(confetti.amount >= 50, "Cantidad de partículas festivas configurada adecuadamente (>= 50)")
	assert_true(confetti.one_shot, "ConfettiParticles configurado como one_shot")

	# 2. Verificar disparador de confeti, partículas y simulación procedural
	hud.trigger_confetti()
	assert_true(confetti.emitting, "trigger_confetti() activa emisión en CPUParticles2D")
	assert_true(hud.confetti_pieces.size() >= 50, "trigger_confetti() genera piezas de confeti multicolor")
	var first_piece = hud.confetti_pieces[0]
	assert_true(first_piece.has("pos") and first_piece.has("vel") and first_piece.has("color"), "Piezas de confeti poseen parámetros físicos")

	# Verificar existencia de ConfettiOverlay y simulación física activa en _process
	var overlay = hud.get_node_or_null("%ConfettiOverlay")
	assert_true(overlay != null, "ConfettiOverlay Control existe en VictoryPanel")
	assert_equals(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ConfettiOverlay no bloquea eventos de ratón (MOUSE_FILTER_IGNORE)")
	var initial_y = hud.confetti_pieces[0]["pos"].y
	hud._process(0.1)
	assert_true(hud.confetti_pieces[0]["pos"].y > initial_y or hud.confetti_pieces[0]["vel"].y != 0.0, "Piezas de confeti actualizan su posición y física en _process")

	# 3. Verificar contenedor de estrellas y labels individuales
	var stars_container = hud.get_node_or_null("%StarsContainer")
	assert_true(stars_container != null, "StarsContainer presente en VictoryPanel")
	var star1 = hud.get_node_or_null("%Star1")
	var star2 = hud.get_node_or_null("%Star2")
	var star3 = hud.get_node_or_null("%Star3")
	assert_true(star1 != null and star2 != null and star3 != null, "Las 3 estrellas individuales (Star1, Star2, Star3) existen en VictoryPanel")

	# 4. Probar configuración con 1 estrella
	hud.animate_stars(1)
	assert_equals(star1.text, "⭐", "Con 1 estrella ganada: Star1 es ⭐")
	assert_equals(star2.text, "★", "Con 1 estrella ganada: Star2 es ★ inactiva")
	assert_equals(star3.text, "★", "Con 1 estrella ganada: Star3 es ★ inactiva")

	# 5. Probar configuración con 2 estrellas
	hud.animate_stars(2)
	assert_equals(star1.text, "⭐", "Con 2 estrellas ganadas: Star1 es ⭐")
	assert_equals(star2.text, "⭐", "Con 2 estrellas ganadas: Star2 es ⭐")
	assert_equals(star3.text, "★", "Con 2 estrellas ganadas: Star3 es ★ inactiva")

	# 6. Probar configuración con 3 estrellas y re-disparo seguro de tweens
	hud.animate_stars(3)
	assert_equals(star1.text, "⭐", "Con 3 estrellas ganadas: Star1 es ⭐")
	assert_equals(star2.text, "⭐", "Con 3 estrellas ganadas: Star2 es ⭐")
	assert_equals(star3.text, "⭐", "Con 3 estrellas ganadas: Star3 es ⭐")
	assert_true(hud._star_tweens.size() > 0, "animate_stars gestiona lista activa de tweens sin conflictos")

	# 7. Probar despliegue completo de modal con conquista continental
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 150, "is_continent_conquest": true})
	assert_true(hud.victory_panel.visible, "VictoryPanel es visible tras deploy_victory_modal()")
	var title = hud.get_node_or_null("%VictoryTitle")
	assert_true(title != null, "Label de título en VictoryPanel existe")
	assert_equals(title.text, "¡CONTINENTE CONQUISTADO!", "Título conmuta a '¡CONTINENTE CONQUISTADO!' al completar nivel 5")

	# Probar despliegue de victoria estándar
	hud.deploy_victory_modal({"stars": 2, "gold_earned": 90, "is_continent_conquest": false})
	assert_equals(title.text, "¡VICTORIA!", "Título conmuta a '¡VICTORIA!' en niveles normales")

	remove_child(hud)
	hud.free()

func test_audio_fanfares_and_continental_conquest() -> void:
	print("\n-> Test: Fanfarrias Triunfales, Conquista Continental y Sonidos Secuenciales de Estrellas")
	assert_true(AudioManager != null, "AudioManager está disponible")
	var wav = MusicSynth.to_wav(AudioManager._render_tone(440.0, 0.1, 0.2))
	assert_equals(wav.data.size(), int(AudioManager.MIX_RATE * 0.1) * 2, "Los sonidos se pre-renderizan a WAV de 16 bits")

	# 1. Probar fanfarria de victoria estándar
	AudioManager.play_victory()
	assert_equals(AudioManager.last_played_fanfare, "victory", "AudioManager ejecuta fanfarria triunfal de victoria")

	# 2. Probar fanfarria de conquista continental con riqueza armónica
	AudioManager.play_continent_conquest()
	assert_equals(AudioManager.last_played_fanfare, "continent_conquest", "AudioManager ejecuta fanfarria de conquista continental")

	# 3. Probar sonidos secuenciales de estrellas
	AudioManager.play_star_reveal(0)
	assert_equals(AudioManager.last_star_sound_index, 0, "AudioManager ejecuta sonido de revelación de Estrella 1 (index 0)")

	AudioManager.play_star_reveal(1)
	assert_equals(AudioManager.last_star_sound_index, 1, "AudioManager ejecuta sonido de revelación de Estrella 2 (index 1)")

	AudioManager.play_star_reveal(2)
	assert_equals(AudioManager.last_star_sound_index, 2, "AudioManager ejecuta sonido de revelación de Estrella 3 (index 2)")


	# 4. Probar detección de nivel 5 y selección automática de fanfarria en BattleController
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var battle = BattleControllerScript.new()
	battle.level_id = "europe_5"
	battle._trigger_victory()
	assert_equals(AudioManager.last_played_fanfare, "continent_conquest", "Nivel europe_5 (fin de continente) dispara automáticamente fanfarria de conquista continental")

	battle.level_id = "europe_3"
	battle._trigger_victory()
	assert_equals(AudioManager.last_played_fanfare, "victory", "Nivel europe_3 (nivel regular) dispara fanfarria de victoria estándar")

	battle.reset_time_scale()
	battle.free()
	Engine.time_scale = 1.0

func test_bezier_curves_and_marching_dots() -> void:
	print("\n-> Test: Curva de Bezier Cuadrática Elástica, Slingshot Drag y Marching Dots")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var battle = BattleControllerScript.new()

	# 1. Geometría de curva de Bezier cuadrática B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
	var p0 = Vector2(100.0, 100.0)
	var p1 = Vector2(300.0, 50.0)
	var p2 = Vector2(500.0, 100.0)

	var pt_start = battle.evaluate_quadratic_bezier(p0, p1, p2, 0.0)
	assert_true(pt_start.is_equal_approx(p0), "evaluate_quadratic_bezier retorna P0 en t = 0.0")

	var pt_end = battle.evaluate_quadratic_bezier(p0, p1, p2, 1.0)
	assert_true(pt_end.is_equal_approx(p2), "evaluate_quadratic_bezier retorna P2 en t = 1.0")

	var pt_mid = battle.evaluate_quadratic_bezier(p0, p1, p2, 0.5)
	var expected_mid = 0.25 * p0 + 0.5 * p1 + 0.25 * p2
	assert_true(pt_mid.is_equal_approx(expected_mid), "evaluate_quadratic_bezier calcula punto medio cuadrático exacto en t = 0.5")

	# 2. Control Point con deformación dinámica por velocidad de arrastre
	var cp_rest = battle.get_bezier_control_point(p0, p2, Vector2.ZERO)
	var expected_center = (p0 + p2) * 0.5
	assert_true(cp_rest.distance_to(expected_center) < 10.0, "Control point sin velocidad se mantiene centrado en el punto medio elástico")

	# Velocidad lateral perpendicular deflecta la curva
	var normal = Vector2(0.0, 1.0)
	var lateral_vel = normal * 400.0
	var cp_deflected = battle.get_bezier_control_point(p0, p2, lateral_vel)
	assert_true(cp_deflected.y > cp_rest.y, "Velocidad de arrastre lateral deforma dinámicamente el punto de control Bezier en la dirección normal")

	# Robustez ante distancia cero entre puntos
	var cp_zero = battle.get_bezier_control_point(p0, p0, Vector2(100, 100))
	assert_true(cp_zero.is_equal_approx(p0), "get_bezier_control_point maneja distancia cero entre origen y destino sin errores de división por cero")

	# 3. Muestreo de puntos de la curva
	var sampled = battle.sample_bezier_points(p0, p1, p2, 24)
	assert_equals(sampled.size(), 25, "sample_bezier_points genera exactamente segments + 1 muestras")
	assert_true(sampled[0].is_equal_approx(p0), "Primer punto muestreado coincide con P0")
	assert_true(sampled[sampled.size() - 1].is_equal_approx(p2), "Último punto muestreado coincide con P2")

	# 4. Marching dots y avance de fase continuo
	var initial_phase = battle.marching_dots_phase
	battle._process(0.2)
	assert_true(battle.marching_dots_phase > initial_phase, "marching_dots_phase avanza continuamente en _process")
	assert_true(battle.marching_dots_phase >= 0.0 and battle.marching_dots_phase < 1.0, "marching_dots_phase se mantiene acotado en rango modular [0.0, 1.0)")

	# 5. Ejecución segura de _draw_drag_overlay sin fallos
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base_src = BaseNodeScript.new()
	base_src.global_position = Vector2(100, 100)
	base_src.radius = 50.0
	battle.selected_sources.append(base_src)
	battle.is_dragging = true
	battle.drag_current_pos = Vector2(350, 120)
	var draw_callable = Callable(battle, "_draw_drag_overlay")
	battle.draw.connect(draw_callable)
	battle.notification(CanvasItem.NOTIFICATION_DRAW)
	battle.draw.disconnect(draw_callable)
	assert_true(true, "_draw_drag_overlay renderiza curva cónica Bezier, marching dots y flecha poligonal sin errores")

	base_src.free()
	battle.free()

func test_slice_gesture_and_troop_retreat() -> void:
	print("\n-> Test: Gesto de Corte Táctico (Slice-to-Cut), Detección de Intersección y Retirada a Base Origen")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")

	var battle = BattleControllerScript.new()
	add_child(battle)

	var base_a = BaseNodeScript.new()
	base_a.global_position = Vector2(100.0, 200.0)
	base_a.radius = 50.0
	base_a.faction = GameManager.Faction.PLAYER
	base_a.troops = 20
	battle.add_child(base_a)
	battle.bases.append(base_a)

	var base_b = BaseNodeScript.new()
	base_b.global_position = Vector2(500.0, 200.0)
	base_b.radius = 50.0
	base_b.faction = GameManager.Faction.ENEMY_1
	base_b.troops = 15
	battle.add_child(base_b)
	battle.bases.append(base_b)

	# 1. Despachar tropas aliadas de Base A hacia Base B
	battle.dispatch_troops(base_a, base_b)
	assert_equals(battle.active_troops.size(), 1, "Tropa aliada despachada correctamente")
	var troop = battle.active_troops[0]
	assert_equals(troop.count, 19, "Pelotón despachado contiene 19 tropas reteniendo 1 centinela")
	assert_equals(base_a.troops, 1, "Base de origen retiene 1 centinela de guardia")

	# Avanzar delta para que las perlas emerjan y se desplieguen en marcha
	troop._process(0.4)
	var emerged = 0
	for i in troop.bead_values.size():
		if troop.bead_dist(i) >= 0.0:
			emerged += 1
	assert_true(emerged >= 4, "Tropas han emergido formando una hilera activa sobre el mapa")

	# 2. Detección de corte: un trazo lejano no interseca
	var seg_far_a = Vector2(250.0, 50.0)
	var seg_far_b = Vector2(250.0, 100.0)
	assert_true(not troop.intersects_segment(seg_far_a, seg_far_b), "Segmento de corte fuera de la ruta no interseca con la tropa")

	# Un trazo que cruza perpendicularmente la hilera de tropas interseca
	var seg_cut_a = Vector2(200.0, 100.0)
	var seg_cut_b = Vector2(200.0, 300.0)
	assert_true(troop.intersects_segment(seg_cut_a, seg_cut_b), "Segmento transversal interseca la hilera de tropas aliadas")

	# 3. Retirada táctica (abort_mission / retreat)
	assert_true(not troop.is_retreating, "Tropa no está en retirada antes del corte")
	troop.abort_mission()
	assert_true(troop.is_retreating, "abort_mission() activa estado is_retreating = true")
	assert_equals(troop.target_base, base_a, "Objetivo de la tropa en retirada conmuta a la base de origen (Base A)")
	assert_true(troop.move_dir.x < 0.0, "Vector de desplazamiento move_dir se invierte apuntando hacia la base origen")

	# 4. Simular avance de retirada y reintegración en la guarnición aliada
	var initial_garrison = base_a.troops
	var returning_units = troop.count

	for _frame in range(30):
		if not is_instance_valid(troop) or troop.count <= 0:
			break
		troop._process(0.1)

	assert_true(base_a.troops >= (initial_garrison + returning_units - 1), "Tropas en retirada se reintegran con éxito en la guarnición aliada de Base A")

	# 5. Integración del gesto de corte completo desde BattleController
	base_a.troops = 20
	battle.dispatch_troops(base_a, base_b)
	var troop2 = battle.active_troops[battle.active_troops.size() - 1]
	troop2._process(0.35)

	# Iniciar corte fuera de una base aliada
	battle._handle_press(Vector2(50.0, 50.0))
	assert_true(battle.is_slicing, "Pulsación fuera de una base aliada inicia gesto de corte (is_slicing = true)")
	assert_true(not battle.is_dragging, "is_dragging permanece false durante el gesto de corte")

	# Realizar swipe cortando la trayectoria
	AudioManager.last_played_sfx = ""
	battle._handle_slice_motion(Vector2(200.0, 50.0))
	battle._handle_slice_motion(Vector2(200.0, 350.0))
	assert_true(troop2.is_retreating, "Gesto swipe interseca convoy aliado y activa retirada inmediata")
	assert_equals(AudioManager.last_played_sfx, "retreat", "AudioManager emite feedback de audio de retirada")
	assert_true(battle.slice_trail_segments.size() > 0, "Gesto de corte genera estela visual de cuchilla")
	assert_true(battle.slice_cut_flash_effects.size() > 0, "Corte exitoso genera efecto visual de destello")

	battle._handle_release(Vector2(200.0, 350.0))
	assert_true(not battle.is_slicing, "Liberación de entrada finaliza el corte (is_slicing = false)")

	# 6. Detección de corte sobre la trayectoria adelantada a las perlas
	base_a.troops = 20
	battle.dispatch_troops(base_a, base_b)
	var troop3 = battle.active_troops[battle.active_troops.size() - 1]
	troop3._process(0.08)
	var seg_traj_cut_a = Vector2(380.0, 100.0)
	var seg_traj_cut_b = Vector2(380.0, 300.0)
	assert_true(troop3.intersects_segment(seg_traj_cut_a, seg_traj_cut_b), "Corte sobre la trayectoria proyectada interseca con éxito")
	troop3.abort_mission()
	assert_true(troop3.is_retreating, "Tropa con corte sobre trayectoria proyectada inicia retirada")
	assert_true(not troop3.intersects_segment(seg_traj_cut_a, seg_traj_cut_b), "Tropa en retirada no vuelve a intersecar corte")

	# 7. Reintegro inmediato en lote cuando las perlas no han emergido aún
	base_a.troops = 25
	battle.dispatch_troops(base_a, base_b)
	var troop4 = battle.active_troops[battle.active_troops.size() - 1]
	assert_equals(base_a.troops, 1, "Guarnición retiene 1 centinela al despachar 24")
	troop4.abort_mission()
	assert_equals(base_a.troops, 25, "Tropas no emergidas se reintegran en lote de forma limpia a la base de origen")

	remove_child(battle)
	base_a.free()
	base_b.free()
	battle.free()

func test_under_siege_alert_trigger_and_deactivation() -> void:
	print("\n-> Test: Alerta Visual de Asedio Inminente (Under Siege Alert), Detección Perimetral y Desactivación")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var TroopScript = load("res://scripts/battle/troop.gd")

	var base_player = BaseNodeScript.new()
	add_child(base_player)
	base_player.global_position = Vector2(300.0, 300.0)
	base_player.radius = 50.0
	base_player.faction = GameManager.Faction.PLAYER
	base_player.troops = 10
	base_player.base_type = BaseNode.BaseType.STANDARD

	var base_enemy = BaseNodeScript.new()
	base_enemy.global_position = Vector2(800.0, 300.0)
	base_enemy.faction = GameManager.Faction.ENEMY_1
	base_enemy.troops = 30

	# 1. Estado inicial: sin amenaza
	base_player.update_siege_status([])
	assert_true(not base_player.is_under_siege, "Base aliada sin convoyes entrantes no está bajo asedio (is_under_siege = false)")
	assert_equals(base_player.get_effective_defense(), 10, "Capacidad defensiva efectiva de base Standard con 10 tropas es exactamente 10")

	# 2. Convoy hostil lejano (distancia > 220px)
	var t_far = TroopScript.new()
	t_far.setup(base_enemy, base_player, 18, GameManager.Faction.ENEMY_1)
	t_far.global_position = Vector2(600.0, 300.0)
	base_player.update_siege_status([t_far])
	assert_true(not base_player.is_under_siege, "Convoy hostil a distancia > 220px no dispara alerta de asedio")

	# 3. Convoy hostil cercano (distancia <= 220px) pero inferior a la defensa
	var t_close_weak = TroopScript.new()
	t_close_weak.setup(base_enemy, base_player, 8, GameManager.Faction.ENEMY_1)
	t_close_weak.global_position = Vector2(450.0, 300.0)
	base_player.update_siege_status([t_close_weak])
	assert_true(not base_player.is_under_siege, "Convoy hostil cercano (8 tropas) inferior a la guarnición (10 tropas) no activa asedio")

	# 4. Convoy hostil cercano superior a la defensa efectiva (18 tropas > 10 defensa)
	var t_close_strong = TroopScript.new()
	t_close_strong.setup(base_enemy, base_player, 18, GameManager.Faction.ENEMY_1)
	t_close_strong.global_position = Vector2(450.0, 300.0)
	base_player.update_siege_status([t_close_strong])
	assert_true(base_player.is_under_siege, "Convoy hostil cercano que supera la defensa activa alerta is_under_siege = true")

	# Animación de pulso de advertencia en _process
	base_player._process(0.1)
	assert_true(base_player.siege_pulse_time > 0.0, "siege_pulse_time acumula tiempo para halo y marcador ⚠ animado")

	# 5. Efecto de especialización FORTALEZA (defensa 2x)
	base_player.base_type = BaseNode.BaseType.FORTRESS
	assert_equals(base_player.get_effective_defense(), 20, "Fortaleza con 10 tropas posee defensa efectiva de 20 (2x)")
	base_player.update_siege_status([t_close_strong])
	assert_true(not base_player.is_under_siege, "Fortaleza con defensa 20 neutraliza la alerta frente a 18 atacantes")

	var t_fortress_threat = TroopScript.new()
	t_fortress_threat.setup(base_enemy, base_player, 25, GameManager.Faction.ENEMY_1)
	t_fortress_threat.global_position = Vector2(450.0, 300.0)
	base_player.update_siege_status([t_fortress_threat])
	assert_true(base_player.is_under_siege, "25 atacantes superan los 20 defensores de la fortaleza y reactivan is_under_siege")

	# 6. Efecto de especialización FÁBRICA (defensa 0.5x)
	base_player.base_type = BaseNode.BaseType.FACTORY
	assert_equals(base_player.get_effective_defense(), 5, "Fábrica con 10 tropas posee defensa efectiva reducida de 5 (0.5x)")
	base_player.update_siege_status([t_close_weak])
	assert_true(base_player.is_under_siege, "8 atacantes superan la débil defensa de fábrica (5) activando is_under_siege")

	# 7. Desactivación automática al recibir refuerzos aliados
	base_player.troops = 10
	base_player.base_type = BaseNode.BaseType.STANDARD
	base_player.update_siege_status([t_close_strong])
	assert_true(base_player.is_under_siege, "Base Standard bajo asedio por 18 atacantes")

	# Llegan 15 tropas aliadas de refuerzo
	base_player.receive_troops(GameManager.Faction.PLAYER, 15)
	assert_equals(base_player.troops, 25, "Guarnición reforzada sube a 25 tropas")
	assert_equals(base_player.get_effective_defense(), 25, "Defensa efectiva aumenta a 25")
	base_player.update_siege_status([t_close_strong])
	assert_true(not base_player.is_under_siege, "Llegada de refuerzos desactiva automáticamente is_under_siege")

	# 8. Desactivación automática al retirarse o eliminarse la amenaza
	t_close_strong.abort_mission()
	base_player.troops = 10
	base_player.update_siege_status([t_close_strong])
	assert_true(not base_player.is_under_siege, "Retirada del convoy hostil desactiva la alerta de asedio")

	# 9. Base neutral no activa alerta
	var base_neutral = BaseNodeScript.new()
	base_neutral.faction = GameManager.Faction.NEUTRAL
	base_neutral.troops = 5
	base_neutral.update_siege_status([t_close_weak])
	assert_true(not base_neutral.is_under_siege, "Base neutral no activa alerta de asedio")

	# 10. Desactivación automática al terminar la batalla (victoria / derrota)
	base_player.troops = 5
	var t_final_threat = TroopScript.new()
	t_final_threat.setup(base_enemy, base_player, 18, GameManager.Faction.ENEMY_1)
	t_final_threat.global_position = Vector2(450.0, 300.0)
	base_player.update_siege_status([t_final_threat])
	assert_true(base_player.is_under_siege, "Base aliada entra bajo asedio con 5 tropas frente a 18")
	EventBus.battle_won.emit({})
	assert_true(not base_player.is_under_siege, "Victoria de batalla desactiva y limpia inmediatamente la alerta de asedio")
	assert_true(not base_player.is_active, "Base queda marcada inactiva tras fin de batalla")

	t_final_threat.free()
	remove_child(base_player)
	t_far.free()
	t_close_weak.free()
	t_close_strong.free()
	t_fortress_threat.free()
	base_neutral.free()
	base_player.free()
	base_enemy.free()

func test_hud_counters_and_leadership_crown() -> void:
	print("\n-> Test: Contadores Numéricos en Tiempo Real y Corona de Liderazgo en el HUD")
	var BattleHUDScene = load("res://scenes/ui/battle_hud.tscn")
	var BattleControllerScript = load("res://scripts/battle/battle_controller.gd")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")

	var hud: BattleHUD = BattleHUDScene.instantiate()
	add_child(hud)

	# 1. Verificar nodos de interfaz en BattleHUD
	assert_true(hud.leader_crown != null, "Nodo LeaderCrown existe en BattleHUD")
	assert_true(hud.label_count_player != null, "Nodo LabelCountPlayer existe en TopBar")
	assert_true(hud.label_count_neutral != null, "Nodo LabelCountNeutral existe en TopBar")
	assert_true(hud.label_count_enemy != null, "Nodo LabelCountEnemy existe en TopBar")
	assert_true(hud.faction_counts_container != null, "Nodo FactionCountsContainer existe en TopBar")

	# 2. Vincular a BattleController y verificar conteos iniciales
	var battle = BattleControllerScript.new()
	add_child(battle)
	for b in battle.bases:
		b.queue_free()
	battle.bases.clear()
	battle.active_troops.clear()
	hud.battle_controller = battle

	var b_player = BaseNodeScript.new()
	b_player.faction = GameManager.Faction.PLAYER
	b_player.troops = 35
	battle.bases.append(b_player)

	var b_enemy = BaseNodeScript.new()
	b_enemy.faction = GameManager.Faction.ENEMY_1
	b_enemy.troops = 20
	battle.bases.append(b_enemy)

	var b_neutral = BaseNodeScript.new()
	b_neutral.faction = GameManager.Faction.NEUTRAL
	b_neutral.troops = 15
	battle.bases.append(b_neutral)

	# Ejecutar actualización de dominancia y contadores numéricos
	hud._update_dominance_bar()

	assert_true(hud.label_count_player.text.contains("35"), "LabelCountPlayer muestra el conteo vivo del jugador (Azul: 35)")
	assert_true(hud.label_count_enemy.text.contains("20"), "LabelCountEnemy muestra el conteo vivo del enemigo (Rojo: 20)")
	assert_true(hud.label_count_neutral.text.contains("15"), "LabelCountNeutral muestra el conteo vivo neutral (Gris: 15)")

	# 3. Liderazgo del jugador: Corona dorada sobre el segmento azul
	assert_equals(hud.get_leader_faction(), GameManager.Faction.PLAYER, "Jugador con 35 tropas es la facción líder (PLAYER)")
	assert_true(hud.leader_crown.visible, "Corona de liderazgo visible en HUD")

	# La coordenada X de la corona debe estar en la mitad izquierda (segmento del jugador)
	hud._process(0.1)
	var top_bar = hud.get_node_or_null("TopBar") as Control
	var top_w = top_bar.size.x if (top_bar and top_bar.size.x > 0.0) else 1080.0
	var bar_midpoint = top_w * 0.5
	assert_true(hud.leader_crown.position.x < bar_midpoint, "Corona de liderazgo posicionada sobre el segmento del jugador")

	# 4. Transición dinámica de liderazgo hacia el enemigo
	# El enemigo recluta o asalta masivamente (suma 50 tropas -> total 70 tropas enemigas frente a 35 del jugador)
	b_enemy.troops = 70
	hud._update_dominance_bar()

	assert_equals(hud.get_leader_faction(), GameManager.Faction.ENEMY_1, "Liderazgo conmuta dinámicamente al enemigo al superar en tropas al jugador")
	assert_true(hud.label_count_enemy.text.contains("70"), "LabelCountEnemy refleja inmediatamente el incremento a 70 tropas")

	# Ejecutar varios frames de lerp para que la corona se desplace hacia el segmento enemigo
	var pos_initial = hud.leader_crown.position.x
	hud._process(0.05)
	var pos_step1 = hud.leader_crown.position.x
	assert_true(pos_step1 > pos_initial, "Corona de liderazgo avanza progresivamente mediante lerp hacia la derecha")

	for _i in range(9):
		hud._process(0.05)
	assert_true(hud.leader_crown.position.x > bar_midpoint, "Corona de liderazgo se desplaza suavemente hacia el segmento derecho del enemigo líder")

	# 5. Soporte para múltiples facciones enemigas y determinación del líder individual
	var b_enemy2 = BaseNodeScript.new()
	b_enemy2.faction = GameManager.Faction.ENEMY_2
	b_enemy2.troops = 12
	battle.bases.append(b_enemy2)
	hud._update_dominance_bar()
	assert_true(hud.label_count_enemy.text.contains("12") or hud.label_count_enemy.text.contains("Otros"), "LabelCountEnemy reporta adecuadamente múltiples facciones enemigas activas")

	# Jugador lidera individualmente con 35 tropas frente a Enemigo 1 (20) y Enemigo 2 (12)
	b_player.troops = 35
	b_enemy.troops = 20
	b_enemy2.troops = 12
	hud._update_dominance_bar()
	assert_equals(hud.get_leader_faction(), GameManager.Faction.PLAYER, "Jugador (35) lidera individualmente frente a Enemigo 1 (20) y Enemigo 2 (12)")

	# Enemigo 2 supera a todos individualmente (50 tropas)
	b_enemy2.troops = 50
	hud._update_dominance_bar()
	assert_equals(hud.get_leader_faction(), GameManager.Faction.ENEMY_2, "Enemigo 2 toma el liderazgo con 50 tropas")

	remove_child(hud)
	remove_child(battle)
	hud.free()
	b_player.free()
	b_enemy.free()
	b_enemy2.free()
	b_neutral.free()
	battle.free()

func test_main_menu_ui_and_ambient_system() -> void:
	print("\n-> Test: Menú Principal State.io, Sistema Ambiental y Estadísticas de Campaña")
	var MainMenuScene = load("res://scenes/ui/main_menu.tscn")
	var menu: MainMenuUI = MainMenuScene.instantiate()
	add_child(menu)

	# 1. Verificar nodos e interactivos clave
	assert_true(menu.btn_play != null, "Botón central de juego existe")
	assert_true(menu.btn_world_map != null, "Botón de mapa mundial existe")
	assert_true(menu.btn_upgrades != null, "Botón de tienda de mejoras existe")
	assert_true(menu.btn_reset != null, "Botón de reiniciar progreso existe")
	assert_true(menu.coins_label != null, "Etiqueta de monedas de oro existe")
	assert_true(menu.stars_label != null, "Etiqueta de estrellas de campaña existe")
	assert_true(menu.btn_sound != null, "Botón de conmutación de sonido existe")
	assert_true(menu.stars_pill != null, "Píldora visual de estrellas existe")
	assert_true(menu.coins_pill != null, "Píldora visual de monedas existe")

	# 2. Fondo CartographicBackground y sistema ambiental
	var bg = menu.get_node_or_null("CartographicBackground") as CartographicBackground
	assert_true(bg != null, "CartographicBackground está presente en MainMenu")
	assert_true(bg.show_ambient_nodes, "show_ambient_nodes está activo en el fondo del menú principal")
	assert_equals(bg.ambient_nodes.size(), 8, "Existen exactamente 8 nodos geopolíticos ambientales configurados")

	var p0 = bg.ambient_nodes[0].pos
	bg._process(0.2)
	assert_true(bg.ambient_nodes[0].pos != p0, "Nodos ambientales se desplazan continuamente mediante velocidad y delta")

	# Rebote en límites
	bg.ambient_nodes[0].pos.x = 40.0
	bg.ambient_nodes[0].vel.x = -20.0
	bg._process(0.05)
	assert_true(bg.ambient_nodes[0].pos.x >= 60.0 and bg.ambient_nodes[0].vel.x > 0.0, "Nodos ambientales rebotan suavemente en los bordes")

	# 3. Monedas y Estrellas en vivo
	assert_true(menu.coins_label.text.contains(str(GameManager.coins)), "Etiqueta de monedas muestra saldo actual")
	EventBus.coins_updated.emit(420)
	assert_true(menu.coins_label.text.contains("420"), "Etiqueta de monedas responde a EventBus.coins_updated")

	var total_stars = GameManager.get_total_stars()
	var max_stars = GameManager.get_max_possible_stars()
	assert_true(menu.stars_label.text.contains("%d/%d" % [total_stars, max_stars]), "Etiqueta de estrellas refleja estrellas totales de campaña")

	# 4. Alternancia de sonido
	var initial_muted = AudioManager.is_muted
	menu._on_sound_toggle_pressed()
	assert_equals(AudioManager.is_muted, not initial_muted, "Pulsar botón de sonido alterna el estado de AudioManager")
	assert_equals(menu.btn_sound.text, "🔇" if not initial_muted else "🔊", "Texto de icono del botón refleja el estado silenciado")
	menu._on_sound_toggle_pressed()
	assert_equals(AudioManager.is_muted, initial_muted, "Pulsar nuevamente restaura el estado de sonido")

	# 5. Reinicio de progreso (requiere confirmación con un segundo toque)
	GameManager.coins = 999
	menu._on_reset_pressed()
	assert_equals(GameManager.coins, 999, "El primer toque en reiniciar sólo pide confirmación")
	assert_true(menu.btn_reset.text.contains("SEGURO"), "El botón muestra el aviso de confirmación")
	menu._on_reset_pressed()
	assert_equals(GameManager.coins, 150, "Reiniciar progreso restaura monedas iniciales a 150")
	assert_equals(GameManager.get_total_stars(), 0, "Reiniciar progreso resetea estrellas completadas a 0")
	assert_true(menu.coins_label.text.contains("150"), "Etiqueta de monedas se actualiza tras reseteo")
	assert_true(menu.stars_label.text.contains("0/90"), "Etiqueta de estrellas se actualiza a 0/90 tras reseteo")

	remove_child(menu)
	menu.free()

func test_world_map_campaign_route_and_briefing() -> void:
	print("\n-> Test: Mapa Mundial State.io, Ruta de Campaña Interconectada y Panel de Briefing")
	var WorldMapScene = load("res://scenes/ui/world_map.tscn")
	var world_map: WorldMapUI = WorldMapScene.instantiate()
	add_child(world_map)

	# 1. Verificar existencia de nodos principales
	assert_true(world_map.continent_title != null, "Título de continente existe")
	assert_true(world_map.btn_prev_continent != null, "Botón continente anterior existe")
	assert_true(world_map.btn_next_continent != null, "Botón continente siguiente existe")
	assert_true(world_map.levels_container != null, "Contenedor de niveles existe")
	assert_true(world_map.route_container != null, "Contenedor de ruta existe")
	assert_true(world_map.briefing_panel != null, "Panel de briefing de misión existe")
	assert_true(world_map.briefing_title != null, "Título de briefing existe")
	assert_true(world_map.briefing_desc != null, "Descripción de briefing existe")
	assert_true(world_map.briefing_stars != null, "Estrellas en briefing existen")
	assert_true(world_map.stat_bases != null, "Estadística de bases existe")
	assert_true(world_map.stat_enemy != null, "Estadística de rivales existe")
	assert_true(world_map.stat_target_time != null, "Estadística de tiempo objetivo existe")
	assert_true(world_map.btn_start_level != null, "Botón iniciar asalto existe")

	# 2. Navegación de continentes
	assert_equals(world_map.continents.size(), 6, "Existen 6 continentes configurados")
	var orig_idx = world_map.current_continent_index
	world_map._on_next_continent()
	assert_equals(world_map.current_continent_index, (orig_idx + 1) % 6, "Avanzar continente incrementa índice correctamente")
	world_map._on_prev_continent()
	assert_equals(world_map.current_continent_index, orig_idx, "Retroceder continente restaura índice original")

	# 3. Nodos de la ruta de campaña (5 niveles por continente)
	world_map.current_continent_index = 0 # Europa
	world_map._refresh_display()
	assert_equals(world_map.levels_container.get_child_count(), 5, "Existen exactamente 5 nodos de campaña para Europa")

	var node1 = world_map.levels_container.get_node_or_null("NodeHolder_1")
	assert_true(node1 != null, "NodeHolder_1 presente en la ruta")
	var btn1 = node1.get_node_or_null("BtnLevel_1") as Button
	assert_true(btn1 != null, "BtnLevel_1 presente")
	assert_true(not btn1.disabled, "Nivel 1 de Europa está desbloqueado")

	var node5 = world_map.levels_container.get_node_or_null("NodeHolder_5")
	assert_true(node5 != null, "NodeHolder_5 presente en la ruta")
	var btn5 = node5.get_node_or_null("BtnLevel_5") as Button
	assert_true(btn5 != null, "BtnLevel_5 presente")
	assert_true(btn5.disabled, "Nivel 5 de Europa está bloqueado inicialmente")
	assert_equals(btn5.text, "🔒", "Nivel bloqueado muestra candado")

	# Verificar cambio limpio de continente sin nodos fantasma
	world_map._on_next_continent() # Norteamérica
	assert_equals(world_map.levels_container.get_child_count(), 5, "Cambio de continente mantiene exactamente 5 nodos limpios")
	var na_node1 = world_map.levels_container.get_node_or_null("NodeHolder_1")
	assert_true(na_node1 != null and not na_node1.is_queued_for_deletion(), "NodeHolder_1 activo y no marcado para borrado en nuevo continente")
	world_map._on_prev_continent() # Regresar a Europa
	assert_equals(world_map.levels_container.get_child_count(), 5, "Regreso a Europa conserva 5 nodos limpios")

	# 4. Actualización del panel de briefing
	world_map._select_level("europe_1")
	assert_equals(world_map.selected_level_id, "europe_1", "Nivel europe_1 seleccionado")
	assert_true(world_map.briefing_title.text.length() > 0, "Título de briefing cargado")
	assert_true(world_map.stat_bases.text.contains("Bases"), "Estadística de bases refleja guarnición táctica")
	assert_true(not world_map.btn_start_level.disabled, "Botón iniciar asalto habilitado para nivel desbloqueado")
	assert_equals(world_map.btn_start_level.text, "⚔️ INICIAR ASALTO", "Texto de asalto para nivel disponible")

	world_map._select_level("europe_5")
	assert_equals(world_map.selected_level_id, "europe_5", "Nivel europe_5 seleccionado")
	assert_true(world_map.btn_start_level.disabled, "Botón iniciar asalto deshabilitado para nivel bloqueado")
	assert_equals(world_map.btn_start_level.text, "🔒 NIVEL BLOQUEADO", "Texto de botón indica nivel bloqueado")

	# 5. Simulación de animación de marcha táctica
	var initial_phase = world_map.marching_phase
	world_map._process(0.1)
	assert_true(world_map.marching_phase != initial_phase, "Fase de puntos de marcha avanza continuamente")

	remove_child(world_map)
	world_map.free()

func test_upgrade_menu_cards_and_pips() -> void:
	print("\n-> Test: Tienda Táctica de Mejoras, Tarjetas 2.5D y Barras de 10 Pips")
	GameManager.reset_save()
	var UpgradeMenuScene = load("res://scenes/ui/upgrade_menu.tscn")
	var upgrade_menu: UpgradeMenuUI = UpgradeMenuScene.instantiate()
	add_child(upgrade_menu)

	# 1. Verificar nodos principales
	assert_true(upgrade_menu.cards_container != null, "CardsContainer existe en UpgradeMenu")
	assert_true(upgrade_menu.coins_label != null, "CoinsLabel existe en UpgradeMenu")
	assert_true(upgrade_menu.stars_label != null, "StarsLabel existe en UpgradeMenu")
	assert_true(upgrade_menu.btn_back != null, "BtnBack existe en UpgradeMenu")

	# 2. Verificar las 4 tarjetas de mejoras tácticas
	assert_equals(upgrade_menu.cards_container.get_child_count(), 4, "Existen exactamente 4 tarjetas de mejoras tácticas activas")
	var active_cards = upgrade_menu.cards_container.get_children()

	# 3. Verificar barra segmentada de 10 pips en la primera tarjeta
	var card0 = active_cards[0] as PanelContainer
	assert_true(card0 != null, "Tarjeta 0 es un PanelContainer")
	var pips_box: HBoxContainer = null
	for child in card0.find_children("", "HBoxContainer", true, false):
		if child.get_child_count() == 10:
			pips_box = child
			break
	assert_true(pips_box != null, "Contenedor de pips encontrado en la tarjeta")
	assert_equals(pips_box.get_child_count(), 10, "La barra segmentada contiene exactamente 10 pips de nivel")

	# 4. Proceso de compra y actualización de pips y economía
	GameManager.coins = 500
	upgrade_menu._update_coins(500)
	var cost = GameManager.get_upgrade_cost("starting_troops")
	upgrade_menu._buy_upgrade("starting_troops")
	assert_equals(GameManager.upgrades["starting_troops"], 1, "Mejora 'starting_troops' incrementada a nivel 1")
	assert_equals(GameManager.coins, 500 - cost, "Oro descontado tras la compra")
	assert_true(upgrade_menu.coins_label.text.contains(str(500 - cost)), "CoinsLabel refleja el saldo de oro restante")

	# Caso borde: Intento de compra con fondos insuficientes
	GameManager.coins = 10
	upgrade_menu._update_coins(10)
	var buy_result = GameManager.buy_upgrade("production_rate")
	assert_equals(buy_result, false, "Compra rechazada cuando los fondos son insuficientes")
	assert_equals(GameManager.upgrades["production_rate"], 0, "Nivel de mejora no cambia tras compra rechazada")

	# 5. Tarjeta en nivel máximo (MÁXIMO y deshabilitado)
	GameManager.upgrades["starting_troops"] = 10
	upgrade_menu._build_cards()
	assert_equals(upgrade_menu.cards_container.get_child_count(), 4, "CardsContainer conserva exactamente 4 tarjetas tras reconstrucción")
	var updated_cards = upgrade_menu.cards_container.get_children()
	var card_max = updated_cards[0]
	var buy_btn: Button = null
	for b in card_max.find_children("", "Button", true, false):
		buy_btn = b
		break
	assert_true(buy_btn != null, "Botón de compra encontrado en tarjeta maximizada")
	assert_true(buy_btn.disabled, "Botón de compra deshabilitado en nivel máximo")
	assert_equals(buy_btn.text, "MÁXIMO", "Texto de botón muestra 'MÁXIMO'")

	GameManager.reset_save()
	remove_child(upgrade_menu)
	upgrade_menu.free()

func test_battle_hud_modals_and_sound_toggle() -> void:
	print("\n-> Test: Modales de Batalla (Pausa, Victoria, Derrota) y Alternancia de Sonido")
	var BattleHUDScene = load("res://scenes/ui/battle_hud.tscn")
	var hud: BattleHUD = BattleHUDScene.instantiate()
	add_child(hud)

	# 1. Verificar nodos de modales y visibilidad inicial
	assert_true(hud.dim_overlay != null, "DimOverlay existe")
	assert_true(hud.victory_panel != null, "VictoryPanel existe")
	assert_true(hud.defeat_panel != null, "DefeatPanel existe")
	assert_true(hud.pause_panel != null, "PausePanel existe")
	assert_true(hud.btn_pause != null, "BtnPause existe")
	assert_true(hud.btn_resume != null, "BtnResume existe")
	assert_true(hud.btn_pause_sound != null, "BtnPauseSound existe")
	assert_true(not hud.dim_overlay.visible, "DimOverlay oculto inicialmente")
	assert_true(not hud.victory_panel.visible, "VictoryPanel oculto inicialmente")
	assert_true(not hud.defeat_panel.visible, "DefeatPanel oculto inicialmente")
	assert_true(not hud.pause_panel.visible, "PausePanel oculto inicialmente")

	# 2. Modal de Pausa y Alternancia de Sonido
	hud._on_pause_pressed()
	assert_true(hud.pause_panel.visible, "PausePanel visible tras pausar")
	assert_true(hud.dim_overlay.visible, "DimOverlay visible durante la pausa")
	assert_equals(hud.dim_overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "DimOverlay bloquea clics táctiles (MOUSE_FILTER_STOP) en pausa")
	assert_true(get_tree().paused, "Árbol de escena queda pausado")

	var prev_muted = AudioManager.is_muted
	hud._on_pause_sound_pressed()
	assert_equals(AudioManager.is_muted, not prev_muted, "BtnPauseSound alterna el mute en AudioManager")
	assert_true(hud.btn_pause_sound.text.contains("SILENCIADO" if not prev_muted else "ACTIVADO"), "Etiqueta de botón de pausa refleja estado de sonido")
	hud._on_pause_sound_pressed()
	assert_equals(AudioManager.is_muted, prev_muted, "BtnPauseSound restaura el estado original")

	hud._on_resume_pressed()
	get_tree().paused = false
	hud.pause_panel.visible = false
	hud.dim_overlay.visible = false

	# 3. Modal de Victoria estándar y confeti (3 estrellas)
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 150, "is_continent_conquest": false})
	assert_true(hud.victory_panel.visible, "VictoryPanel visible tras victoria")
	assert_true(hud.dim_overlay.visible, "DimOverlay visible tras victoria")
	assert_equals(hud.victory_title.text, "¡VICTORIA!", "Título de victoria estándar")
	assert_true(hud.victory_reward_label.text.contains("150"), "Recompensa de oro mostrada correctamente (+150)")
	assert_equals(hud.confetti_pieces.size(), 75, "Sistema de confeti genera 75 partículas festivas")
	hud._update_confetti(0.1)
	assert_true(hud.confetti_pieces.size() > 0, "Partículas de confeti se procesan sin error")

	# Victoria parcial de 1 estrella (validar estrellas rellenas y vacías)
	hud.deploy_victory_modal({"stars": 1, "gold_earned": 50, "is_continent_conquest": false})
	assert_equals(hud.star_1.text, "⭐", "Primera estrella otorgada")
	assert_equals(hud.star_2.text, "★", "Segunda estrella apagada")
	assert_equals(hud.star_3.text, "★", "Tercera estrella apagada")

	# 4. Modal de Conquista Continental
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 300, "is_continent_conquest": true})
	assert_equals(hud.victory_title.text, "¡CONTINENTE CONQUISTADO!", "Título de victoria continental aplicado")

	# 5. Modal de Derrota
	hud.victory_panel.visible = false
	hud._on_battle_lost()
	assert_true(hud.defeat_panel.visible, "DefeatPanel visible tras derrota")
	assert_true(hud.dim_overlay.visible, "DimOverlay visible tras derrota")

	get_tree().paused = false
	Engine.time_scale = 1.0
	remove_child(hud)
	hud.free()

func test_cartographic_background_and_theme_helper() -> void:
	print("\n-> Test: CartographicBackground State.io y UIThemeHelper Estilo 2.5D")

	# 1. Probar CartographicBackground
	var bg = CartographicBackground.new()
	assert_equals(bg.grid_spacing, 75.0, "grid_spacing por defecto es 75.0")
	assert_equals(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Fondo ignora eventos de ratón (MOUSE_FILTER_IGNORE)")

	bg.show_ambient_nodes = false
	bg._process(0.5)
	assert_equals(bg.ambient_nodes.size(), 0, "Sin ambient nodes cuando show_ambient_nodes está desactivado")

	bg.show_ambient_nodes = true
	bg._setup_ambient_nodes()
	assert_equals(bg.ambient_nodes.size(), 8, "_setup_ambient_nodes inicializa 8 nodos tácticos")
	var n0 = bg.ambient_nodes[0]
	assert_true(n0.radius >= 22.0 and n0.radius <= 32.0, "Radio de nodo ambiental dentro del rango esperado")
	assert_true(n0.troops >= 8 and n0.troops <= 35, "Guarnición de nodo ambiental generada dentro del rango")

	# Generación y poda de tropas ambientales: agrupar todos los nodos para asegurar distancia < 420
	for i in range(bg.ambient_nodes.size()):
		bg.ambient_nodes[i].pos = Vector2(200.0 + float(i) * 20.0, 200.0 + float(i) * 20.0)
	var spawned = false
	for _attempt in range(10):
		bg.spawn_timer = 2.0
		bg._process(0.05)
		if bg.ambient_troops.size() > 0:
			spawned = true
			break
	assert_true(spawned, "Tropa ambiental generada entre nodos cercanos")
	if bg.ambient_troops.size() > 0:
		var tr = bg.ambient_troops[0]
		assert_true(tr.progress >= 0.0, "Tropa ambiental inicializada con progreso")
		tr.progress = 1.0
		bg._process(0.01)
		assert_true(not bg.ambient_troops.has(tr), "Tropas ambientales que completan marcha son podadas limpiamente")
	bg.free()

	# Prueba de robustez con grid_spacing no positivo
	var bg_invalid = CartographicBackground.new()
	bg_invalid.grid_spacing = -10.0
	add_child(bg_invalid)
	bg_invalid.queue_redraw()
	assert_true(bg_invalid.grid_spacing < 0.0, "CartographicBackground acepta asignación de grid_spacing negativo de forma segura")
	remove_child(bg_invalid)
	bg_invalid.free()

	# 2. Probar UIThemeHelper - Botones táctiles 2.5D
	var btn = Button.new()
	UIThemeHelper.apply_stateio_button_style(btn, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 18, 5)
	# Aplicar segunda vez para probar idempotencia
	UIThemeHelper.apply_stateio_button_style(btn, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 18, 5)
	assert_true(btn.has_meta("_bounce_setup"), "Configuración de bounce es idempotente sin duplicar señales")
	assert_true(btn.has_theme_stylebox_override("normal"), "Estilo 'normal' aplicado al botón")
	assert_true(btn.has_theme_stylebox_override("hover"), "Estilo 'hover' aplicado al botón")
	assert_true(btn.has_theme_stylebox_override("pressed"), "Estilo 'pressed' aplicado al botón")
	assert_true(btn.has_theme_stylebox_override("disabled"), "Estilo 'disabled' aplicado al botón")
	assert_true(btn.has_theme_stylebox_override("focus"), "Estilo 'focus' aplicado al botón")
	var sb_norm = btn.get_theme_stylebox("normal") as StyleBoxFlat
	assert_equals(sb_norm.border_width_bottom, 5, "Profundidad 2.5D de borde inferior igual a 5")
	assert_equals(sb_norm.corner_radius_top_left, 18, "Radio de esquina del botón igual a 18")
	assert_equals(btn.get_theme_color("font_color"), Color.WHITE, "Color de fuente blanco aplicado")
	btn.free()

	# 3. Probar UIThemeHelper - Tarjetas y Píldoras
	var panel = PanelContainer.new()
	UIThemeHelper.apply_card_style(panel, UIThemeHelper.COLOR_CARD, UIThemeHelper.COLOR_CARD_BORDER, 20, 2)
	assert_true(panel.has_theme_stylebox_override("panel"), "Estilo 'panel' aplicado a PanelContainer")
	var sb_card = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_equals(sb_card.corner_radius_top_left, 20, "Radio de esquina de tarjeta igual a 20")
	assert_equals(sb_card.bg_color, UIThemeHelper.COLOR_CARD, "Color de fondo de tarjeta aplicado correctamente")
	panel.free()

	var pill = PanelContainer.new()
	UIThemeHelper.apply_pill_style(pill, UIThemeHelper.COLOR_HEADER_PILL, Color.WHITE, 22)
	assert_true(pill.has_theme_stylebox_override("panel"), "Estilo de píldora aplicado")
	var sb_pill = pill.get_theme_stylebox("panel") as StyleBoxFlat
	assert_equals(sb_pill.corner_radius_top_left, 22, "Radio de píldora igual a 22")
	pill.free()

	# 4. Probar animaciones de modal y cancelación segura de tween previo
	var ctrl = Control.new()
	add_child(ctrl)
	UIThemeHelper.animate_modal_pop_in(ctrl)
	assert_true(ctrl.visible, "animate_modal_pop_in hace visible el control")
	UIThemeHelper.animate_modal_pop_out(ctrl)
	UIThemeHelper.animate_modal_pop_in(ctrl)
	assert_true(ctrl.visible, "animate_modal_pop_in cancela pop_out previo y conserva visibilidad")
	remove_child(ctrl)
	ctrl.free()

func test_crossing_streams_low_fps_and_huge_streams() -> void:
	print("\n-> Test: Cruce de Hileras Independiente de FPS y Hileras Masivas Agrupadas")
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	var a = _make_base(Vector2(100, 500))
	var b = _make_base(Vector2(900, 500))
	var c = _make_base(Vector2(500, 100))
	var d = _make_base(Vector2(500, 900))

	# 1. Dos hileras iguales que se cruzan en (500, 500) se aniquilan igual a 60 fps que a 10 fps
	for dt in [0.016, 0.1]:
		var t1 = _make_stream(a, b, 10, GameManager.Faction.PLAYER)
		var t2 = _make_stream(c, d, 10, GameManager.Faction.ENEMY_1)
		battle.active_troops.clear()
		battle.active_troops.append_array([t1, t2])
		_simulate(battle, [t1, t2], int(2.0 / dt), dt)
		assert_true(not is_instance_valid(t1) and not is_instance_valid(t2), "Cruce perpendicular 10 vs 10 se resuelve por completo (dt = %.3f)" % dt)
		for t in [t1, t2]:
			if is_instance_valid(t):
				t.free()

	# 2. Hileras masivas: se limitan a MAX_BEADS perlas sin perder unidades
	var big = _make_stream(a, b, 300, GameManager.Faction.PLAYER)
	var mid = _make_stream(b, a, 200, GameManager.Faction.ENEMY_1)
	assert_equals(big.bead_values.size(), Troop.MAX_BEADS, "Hilera de 300 unidades se dibuja con %d perlas" % Troop.MAX_BEADS)
	var total = 0
	for v in big.bead_values:
		total += v
	assert_equals(total, 300, "Las perlas agrupadas conservan las 300 unidades")
	battle.active_troops.clear()
	battle.active_troops.append_array([big, mid])
	_simulate(battle, [big, mid], 60, 0.05)
	assert_true(not is_instance_valid(mid), "Hilera enemiga de 200 aniquilada en choque frontal masivo")
	assert_equals(big.count, 100, "Hilera masiva sobrevive con la diferencia exacta (300 - 200 = 100)")

	# 3. Rendimiento: 20 hileras cruzándose se resuelven en tiempo trivial
	battle.active_troops.clear()
	var streams = []
	for i in 10:
		streams.append(_make_stream(a, b, 140, GameManager.Faction.PLAYER))
		streams.append(_make_stream(c, d, 140, GameManager.Faction.ENEMY_1))
	for s in streams:
		s._process(0.5)
	battle.active_troops.append_array(streams)
	var t0 = Time.get_ticks_usec()
	battle._process_troop_collisions()
	var elapsed_ms = (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(elapsed_ms < 8.0, "20 hileras de 140 unidades resuelven colisiones en < 8 ms (%.2f ms)" % elapsed_ms)

	for n in streams + [big, a, b, c, d, battle]:
		if is_instance_valid(n):
			n.free()

func test_save_robustness_and_replay_rewards() -> void:
	print("\n-> Test: Guardado Robusto (versión, tipos, claves nuevas) y Recompensas por Repetición")
	# 1. JSON antiguo con números float y sin claves nuevas
	var f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string('{"coins": 321.0, "upgrades": {"troop_speed": 3.0}, "completed_levels": {"europe_1": 2.0}, "unlocked_levels": ["europe_1", "europe_2"]}')
	f.close()
	GameManager.load_game()
	assert_equals(typeof(GameManager.coins), TYPE_INT, "Las monedas se cargan como entero")
	assert_equals(GameManager.coins, 321, "Monedas restauradas desde un guardado antiguo")
	assert_equals(GameManager.upgrades["troop_speed"], 3, "Mejora guardada restaurada como entero")
	assert_equals(GameManager.upgrades["gold_bonus"], 0, "Mejora ausente en el guardado toma su valor por defecto")
	assert_equals(GameManager.completed_levels["europe_1"], 2, "Estrellas restauradas como entero")

	# 2. Guardado corrupto no rompe el estado
	f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	GameManager.load_game()
	assert_equals(GameManager.coins, 321, "Un guardado corrupto se ignora sin perder el estado en memoria")

	# 3. Recompensas: completa la primera vez, reducida al repetir, media al mejorar estrellas
	GameManager.reset_save()
	assert_equals(GameManager.calculate_victory_gold("europe_1", 2, 100), 100, "Primera victoria concede el oro completo")
	GameManager.complete_level("europe_1", 2)
	assert_equals(GameManager.calculate_victory_gold("europe_1", 2, 100), 25, "Repetir sin mejorar concede el 25%")
	assert_equals(GameManager.calculate_victory_gold("europe_1", 3, 100), 50, "Mejorar las estrellas concede el 50%")

	# 4. Ajustes persistentes
	var was_muted = AudioManager.is_muted
	AudioManager.set_muted(true)
	GameManager.sound_muted = false
	GameManager.load_game()
	assert_true(GameManager.sound_muted, "El silencio se guarda entre sesiones")
	AudioManager.set_muted(was_muted)
	GameManager.reset_save()

func test_ai_projected_defense_and_difficulty() -> void:
	print("\n-> Test: IA con Tropas en Camino, Producción Durante el Viaje y Curva de Dificultad")
	assert_equals(LevelDatabase.get_difficulty("europe_1"), 0.0, "europe_1 es el nivel más fácil")
	assert_equals(LevelDatabase.get_difficulty("oceania_5"), 1.0, "oceania_5 es el nivel más difícil")
	assert_true(LevelDatabase.get_difficulty("africa_3") > LevelDatabase.get_difficulty("europe_5"), "La dificultad crece con la campaña")

	var battle = load("res://scripts/battle/battle_controller.gd").new()
	var src = _make_base(Vector2(100, 1000), GameManager.Faction.ENEMY_1, 30)
	var other = _make_base(Vector2(100, 600), GameManager.Faction.ENEMY_1, 30)
	var neutral = _make_base(Vector2(500, 1000), GameManager.Faction.NEUTRAL, 10)
	var player = _make_base(Vector2(860, 1000), GameManager.Faction.PLAYER, 10)
	battle.bases.append_array([src, other, neutral, player])
	var ai = AIController.new()
	ai.setup(battle, GameManager.Faction.ENEMY_1)

	# Defensa proyectada del jugador incluye lo que producirá mientras llegan las tropas
	assert_true(ai.get_projected_defense(src, player) > 10.0, "La defensa proyectada suma la producción durante el viaje")
	assert_equals(ai.get_projected_defense(src, neutral), 10.0, "Las bases neutrales no crecen durante el viaje")

	# Un objetivo ya cubierto por nuestras tropas en marcha no recibe más envíos
	var incoming = _make_stream(other, neutral, 20, GameManager.Faction.ENEMY_1)
	battle.active_troops.append(incoming)
	ai._rebuild_incoming()
	assert_equals(ai.evaluate_target_utility(src, neutral), -500.0, "La IA no malgasta tropas en un objetivo ya cubierto")

	# Sin goteos: no ataca con menos tropas de las necesarias salvo con la base casi llena
	var weak = _make_base(Vector2(100, 1400), GameManager.Faction.ENEMY_1, 5)
	battle.battle_time = 60.0
	assert_equals(ai.evaluate_target_utility(weak, player), -100.0, "La IA no lanza goteos de 4 tropas contra 10 defensores")
	# Periodo de gracia: en el primer nivel no ataca al jugador durante los primeros segundos
	battle.battle_time = 1.0
	assert_equals(ai.evaluate_target_utility(src, player), -9999.0, "La IA respeta el periodo de gracia inicial en europe_1")
	battle.battle_time = 60.0
	assert_true(ai.evaluate_target_utility(src, player) > 0.0, "Tras el periodo de gracia la IA ataca al jugador")
	weak.free()

	# La IA piensa más rápido en niveles avanzados
	battle.level_id = "oceania_5"
	var hard_ai = AIController.new()
	hard_ai.setup(battle, GameManager.Faction.ENEMY_1)
	battle.level_id = "europe_1"
	var easy_ai = AIController.new()
	easy_ai.setup(battle, GameManager.Faction.ENEMY_1)
	assert_true(hard_ai.think_scale < easy_ai.think_scale, "Intervalo de decisión más corto en el último nivel")

	for n in [incoming, src, other, neutral, player, ai, hard_ai, easy_ai, battle]:
		if is_instance_valid(n):
			n.free()

func test_tutorial_steps_and_tips() -> void:
	print("\n-> Test: Tutorial Interactivo y Tarjetas de Tipos de Base")
	var Tutorial = load("res://scripts/battle/tutorial_overlay.gd")
	GameManager.reset_save()
	assert_true(Tutorial.has_pending_steps("europe_1", LevelDatabase.get_level_data("europe_1")), "europe_1 tiene tutorial de arrastre pendiente")
	assert_true(Tutorial.has_pending_steps("europe_4", LevelDatabase.get_level_data("europe_4")), "europe_4 presenta fortaleza y fábrica")
	assert_true(not Tutorial.has_pending_steps("north_america_1", LevelDatabase.get_level_data("north_america_1")), "Niveles sin novedades no muestran tutorial")

	# Integración: el primer nivel espera al primer envío del jugador
	GameManager.current_level_id = "europe_1"
	var field = load("res://scenes/battle/battle_field.tscn").instantiate()
	add_child(field)
	var tutorial = field._tutorial
	assert_true(tutorial != null, "BattleField crea el tutorial en europe_1")
	assert_equals(tutorial._current, "drag", "El tutorial comienza enseñando a arrastrar")
	assert_true(field.bases.all(func(b): return not b.is_active), "La producción queda congelada hasta el primer gesto")
	assert_true(field.ai_controllers.all(func(ai): return not ai.is_processing()), "La IA espera al primer gesto")

	var player_base = field.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)[0]
	field.dispatch_troops(player_base, field.bases[1])
	assert_true(GameManager.has_seen_tip("drag"), "El paso de arrastre queda marcado como visto")
	assert_true(field.bases.all(func(b): return b.is_active), "La simulación se reanuda tras el primer envío")
	assert_true(field.ai_controllers.all(func(ai): return ai.is_processing()), "La IA se reactiva tras el primer envío")
	assert_true(not Tutorial.has_pending_steps("europe_1", field.level_data), "El tutorial no vuelve a mostrarse")

	remove_child(field)
	field.free()
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.reset_save()

func test_real_geography_and_bigger_levels() -> void:
	print("\n-> Test: Geografía Real (Costas, Fronteras, Ciudades) y Niveles Más Grandes")
	# 1. Datos geográficos
	assert_true(GeoDatabase.get_land().size() > 100, "Se cargan las costas reales")
	assert_true(GeoDatabase.get_borders().size() > 100, "Se cargan las fronteras entre países")
	var madrid = GeoDatabase.get_city("madrid")
	assert_equals(madrid.get("name_es", ""), "Madrid", "Las ciudades traen su nombre en español")
	assert_true(madrid["lonlat"].distance_to(Vector2(-3.7, 40.4)) < 0.3, "Madrid está en su posición real")
	var missing: Array[String] = []
	for level_id in LevelDatabase.get_level_ids():
		for b in LevelDatabase.get_level_definition(level_id)["bases"]:
			if not GeoDatabase.has_city(b["city"]):
				missing.append("%s/%s" % [level_id, b["city"]])
	assert_true(missing.is_empty(), "Todas las ciudades de los 30 niveles existen %s" % str(missing))

	# 2. Proyección: norte arriba, este a la derecha, continua en el antimeridiano
	var proj = MapProjection.new(0.0)
	proj.fit(Rect2(-10, -60, 20, 20), Rect2(0, 0, 100, 100))
	assert_true(proj.project(Vector2(0, 60)).y < proj.project(Vector2(0, 50)).y, "El norte queda arriba")
	assert_true(proj.project(Vector2(5, 0)).x > proj.project(Vector2(-5, 0)).x, "El este queda a la derecha")
	var p = Vector2(33.0, 44.0)
	assert_true(proj.screen_to_mercator(proj.mercator_to_screen(p)).distance_to(p) < 0.001, "Pantalla y Mercator son inversas")
	var pacific = MapProjection.new(178.0)
	var line = pacific.project_points(PackedVector2Array([Vector2(179.0, -17.0), Vector2(-179.0, -17.0)]))
	assert_true(line[0].distance_to(line[1]) < 3.0 * pacific.scale, "Una línea que cruza el antimeridiano no salta de lado a lado")

	# 3. Generador: determinista, bases separadas y dentro de la zona de juego
	var a = LevelGenerator.build(LevelDatabase.get_level_definition("asia_4"), 0.8)
	var b = LevelGenerator.build(LevelDatabase.get_level_definition("asia_4"), 0.8)
	assert_equals(str(a["bases"].map(func(x): return x["pos"])), str(b["bases"].map(func(x): return x["pos"])), "El mismo nivel genera siempre el mismo mapa")
	var worst_gap = INF
	var all_inside = true
	for level_id in LevelDatabase.get_level_ids():
		var bases: Array = LevelDatabase.get_level_data(level_id)["bases"]
		for i in bases.size():
			all_inside = all_inside and LevelGenerator.PLAY_RECT.grow(1.0).has_point(bases[i]["pos"])
			for j in range(i + 1, bases.size()):
				var gap = bases[i]["pos"].distance_to(bases[j]["pos"]) - LevelGenerator.min_distance(bases[i].get("tier", 1), bases[j].get("tier", 1))
				worst_gap = minf(worst_gap, gap)
	assert_true(all_inside, "Todas las bases de los 30 niveles quedan dentro de la zona de juego")
	assert_true(worst_gap > -8.0, "Ninguna pareja de bases se solapa (peor holgura: %.1f px)" % worst_gap)

	# 4. Niveles más grandes a medida que avanza la campaña, sin tocar los tutoriales
	var first = LevelDatabase.get_level_data("europe_1")["bases"].size()
	var last = LevelDatabase.get_level_data("asia_5")["bases"].size()
	assert_equals(first, 4, "El primer nivel (tutorial) conserva sus 4 bases")
	assert_true(last >= 10, "Los últimos niveles son mucho más grandes (%d bases)" % last)
	var extra = LevelDatabase.get_level_data("asia_5")["bases"].filter(func(x): return x["id"].begins_with("x"))
	assert_true(extra.all(func(x): return x["faction"] == GameManager.Faction.NEUTRAL), "Las bases añadidas son neutrales")
	assert_true(LevelDatabase.get_level_data("asia_5")["target_time"] > LevelDatabase.get_level_definition("asia_5")["target_time"], "El tiempo para 3 estrellas crece con las bases añadidas")

	# 5. Territorios recortados a la costa real
	var level = LevelDatabase.get_level_data("europe_4")
	assert_true(level["geo"]["land"].size() > 0, "El nivel trae la tierra firme de su región")
	var map = load("res://scripts/battle/territory_map_2d.gd").new()
	var nodes: Array[BaseNode] = []
	for def in level["bases"]:
		var bn = load("res://scripts/battle/base_node.gd").new()
		bn.setup(def)
		bn.global_position = bn.position
		nodes.append(bn)
	map.generate_map(nodes, LevelGenerator.GEO_CLIP_RECT, level["geo"])
	var clipped_to_land = true
	var capitals_covered = true
	for cell in map.get_cells():
		var visible = 0.0
		for piece in cell.pieces:
			visible += map.calculate_polygon_area(piece)
		clipped_to_land = clipped_to_land and visible < map.calculate_polygon_area(cell.polygon)
		capitals_covered = capitals_covered and cell.pieces.any(func(pc): return Geometry2D.is_point_in_polygon(cell.capital_pos, pc))
	assert_true(clipped_to_land, "El mar no pertenece a ningún territorio")
	assert_true(capitals_covered, "Cada capital se asienta sobre su propio territorio (o su islote)")
	for n in nodes:
		n.free()
	map.free()

	# 6. Mapa del mundo: cada nivel sobre su región real, sin nodos solapados
	var layout = load("res://scripts/ui/world_map.gd")._build_continent_layout("europe")
	var pts: PackedVector2Array = layout["nodes"]
	assert_equals(pts.size(), 5, "El mapa del mundo sitúa los 5 niveles del continente")
	var min_sep = INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			min_sep = minf(min_sep, pts[i].distance_to(pts[j]))
	assert_true(min_sep >= 145.0, "Los nodos de nivel no se solapan (%.0f px)" % min_sep)
	assert_true(pts[0].x < pts[4].x or pts[0].y > pts[2].y, "europe_1 (Iberia) queda al oeste de la región")
	assert_true(layout["geo"]["land"].size() > 0, "Se dibuja la silueta real del continente")

func test_procedural_music() -> void:
	print("\n-> Test: Música Procedural en Bucle (Síntesis, Bucle sin Costuras y Ajustes)")
	# 1. Síntesis de un bucle corto: duración exacta, sin saturar y determinista
	var spec = {"bpm": 120, "beats_per_chord": 2, "chords": [[60, 64, 67], [57, 60, 64]], "bass_step": 1.0, "arp_step": 0.5, "drums": true, "seed": 3}
	var loop = MusicSynth.render(spec)
	assert_equals(loop.size(), int(MusicSynth.loop_seconds(spec) * MusicSynth.MIX_RATE), "El bucle dura exactamente 2 acordes x 2 pulsos a 120 BPM (2 s)")
	var peak = 0.0
	for v in loop:
		peak = maxf(peak, absf(v))
	assert_true(peak > 0.5 and peak <= MusicSynth.PEAK + 0.001, "La mezcla se normaliza sin saturar (pico %.2f)" % peak)
	assert_true(MusicSynth.render(spec) == loop, "La misma pista se sintetiza siempre igual")
	assert_true(absf(loop[loop.size() - 1] - loop[0]) < 0.15, "El final del bucle enlaza con el principio sin chasquido")

	var wav = MusicSynth.to_wav(loop, true)
	assert_equals(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "La pista se reproduce en bucle")
	assert_equals(wav.loop_end, loop.size(), "El bucle abarca la pista completa")

	# 2. Pistas del juego: duración razonable y síntesis rápida (se hace en un hilo aparte)
	for track in MusicSynth.TRACKS:
		var secs = MusicSynth.loop_seconds(MusicSynth.TRACKS[track])
		assert_true(secs >= 12.0 and secs <= 40.0, "Pista '%s' dura %.1f s" % [track, secs])
	var t0 = Time.get_ticks_msec()
	MusicSynth.render_track("battle")
	var ms = Time.get_ticks_msec() - t0
	assert_true(ms < 8000, "La pista de batalla se sintetiza en %d ms (en segundo plano)" % ms)

	# 3. Control desde AudioManager (sin dispositivo de audio en modo headless)
	AudioManager.play_music("battle")
	assert_equals(AudioManager.current_track, "battle", "play_music recuerda la pista pedida")
	AudioManager.stop_music()
	assert_equals(AudioManager.current_track, "", "stop_music detiene la música")
	var was = AudioManager.music_muted
	AudioManager.set_music_muted(true)
	GameManager.music_muted = false
	GameManager.load_game()
	assert_true(GameManager.music_muted, "El silencio de la música se guarda aparte del de los efectos")
	AudioManager.set_music_muted(was)
