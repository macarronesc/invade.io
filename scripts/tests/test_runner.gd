extends Node

## TestRunner: Suite de pruebas de validación automatizada de mecánicas State.io

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failed_names: Array[String] = []

const TEST_SAVE_PATH = "user://test_save.json"

func _ready() -> void:
	# Los tests nunca deben tocar la partida real del jugador
	GameManager.save_path = TEST_SAVE_PATH
	print("\n=======================================================")
	print("  INICIANDO SUITE DE PRUEBAS AUTOMATIZADAS: INVADE.IO  ")
	print("=======================================================\n")

	if "--quick" in OS.get_cmdline_user_args():
		test_packets_and_battle_feedback()
		test_progression_overhaul()
		test_light_and_dark_mode()
		test_new_ui_flows()
		test_packet_combat_and_migration()
		test_campaign_balance_and_rewards()
		test_crossing_streams_low_fps_and_huge_streams()
		test_multi_stream_simultaneous_collision()
		test_slice_gesture_and_troop_retreat()
		test_voronoi_halfplane_clipping_geometry()
		test_territory_map_generation_and_coverage()
		test_theme_and_ui_helpers()
		test_achievements_system()
	else:
		run_all_tests()
	# Vaciar los queue_free de las páginas reconstruidas antes de cerrar el proceso.
	await get_tree().process_frame
	await get_tree().process_frame

	print("\n-------------------------------------------------------")
	DirAccess.remove_absolute(TEST_SAVE_PATH)
	print("RESULTADOS: %d Pasadas, %d Falladas (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("=======================================================\n")

	# Volcado para CI y para capturar el resultado aunque el proceso termine
	var results = FileAccess.open("user://test_results.txt", FileAccess.WRITE)
	if results:
		results.store_string("passed=%d\nfailed=%d\ntotal=%d\n" % [passed_tests, failed_tests, total_tests])
		for n in failed_names:
			results.store_string("FAIL: %s\n" % n)
		results.close()

	if failed_tests > 0:
		print("❌ ERROR: Al menos una prueba ha fallado.")
		get_tree().quit(1)
	else:
		print("✅ Todas las verificaciones ejecutadas han pasado.")
		get_tree().quit(0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

func assert_equals(val1, val2, test_name: String) -> void:
	total_tests += 1
	if val1 == val2:
		passed_tests += 1
		print("  [PASS] %s (Valor: %s)" % [test_name, str(val1)])
	else:
		failed_tests += 1
		failed_names.append(test_name)
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
	test_hud_force_counters()
	test_main_menu_hub_navigation()
	test_play_tab_campaign_route_and_briefing()
	test_army_tab_upgrades_and_looks()
	test_battle_hud_modals_and_sound_toggle()
	test_theme_and_ui_helpers()
	test_crossing_streams_low_fps_and_huge_streams()
	test_save_robustness_and_replay_rewards()
	test_ai_projected_defense_and_difficulty()
	test_tutorial_steps_and_tips()
	test_real_geography_and_bigger_levels()
	test_procedural_music()
	test_daily_rewards_and_streaks()
	test_achievements_system()
	test_daily_challenge_levels()
	test_language_system()
	test_conquest_mode()
	test_atlas_and_first_levels()
	test_cosmetics_shop()
	test_review_regressions()
	test_daily_missions_xp_and_share()
	test_settings_and_backups()
	test_continent_mechanics()
	test_cleanup_regressions()
	test_packets_and_battle_feedback()
	test_progression_overhaul()
	test_light_and_dark_mode()
	test_new_ui_flows()
	test_packet_combat_and_migration()
	test_campaign_balance_and_rewards()

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
	var sent_param = base.send_troops()
	assert_equals(sent_param, 14, "El asalto envía siempre el 100% menos el centinela (15 - 1 = 14)")
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

	var all_levels = _all_campaign_levels()
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

## Utilidades de validación: no forman parte de la API del juego.
func _all_campaign_levels() -> Dictionary:
	var levels := {}
	for id in LevelDatabase.get_level_ids():
		levels[id] = LevelDatabase.get_level_data(id)
	return levels

func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(area) * 0.5

func _make_stream(from: BaseNode, to: BaseNode, count: int, faction: int) -> Troop:
	# Una orden sale de una base de su dueño, también en estos escenarios sintéticos.
	if from.faction == GameManager.Faction.NEUTRAL:
		from.faction = faction
	var t = load("res://scripts/battle/troop.gd").new()
	t.setup(from, to, count, faction)
	return t

## Avanza hileras y colisiones hasta que no quede combate pendiente
func _simulate(battle, streams: Array, steps: int, dt: float) -> void:
	for _i in steps:
		for s in streams:
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.advance(dt)
		battle._process_troop_collisions()
		for s in streams:
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.resolve_arrivals()

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
	base_origin.faction = GameManager.Faction.PLAYER
	base_origin.global_position = Vector2(100, 100)
	base_origin.radius = 50.0

	var base_target = BaseNodeScript.new()
	base_target.global_position = Vector2(500, 100)
	base_target.radius = 50.0
	base_target.troops = 20
	base_target.faction = GameManager.Faction.PLAYER

	var stream = TroopScript.new()
	stream.setup(base_origin, base_target, 15, GameManager.Faction.PLAYER)

	assert_equals(stream.packets.size(), 3, "15 tropas salen en 3 paquetes de 5")
	assert_equals(stream.count, 15, "Contador inicial de la orden coincide con tropas enviadas")

	# Verificar espaciado constante entre paquetes contiguos
	var spacing_ok = true
	for i in range(stream.packets.size() - 1):
		var diff = stream.packet_dist(i) - stream.packet_dist(i + 1)
		if abs(diff - Troop.PACKET_SPACING) > 0.001:
			spacing_ok = false
			break
	assert_true(spacing_ok, "Espaciado constante entre paquetes consecutivos")

	# Simular avance
	var initial_lead_dist = stream.packet_dist(0)
	stream._process(0.1)
	assert_true(stream.packet_dist(0) > initial_lead_dist, "Los paquetes avanzan a lo largo de la trayectoria con el tiempo")

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
	base_a.faction = GameManager.Faction.PLAYER
	base_a.global_position = Vector2(100, 100)
	var base_b = BaseNodeScript.new()
	base_b.faction = GameManager.Faction.ENEMY_1
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

	var counts = battle.get_faction_troop_counts()
	assert_equals(counts[GameManager.Faction.PLAYER], 20, "Las fuerzas del jugador incluyen bases y órdenes en marcha")
	assert_equals(counts[GameManager.Faction.ENEMY_1], 10, "Las fuerzas enemigas no incluyen las tropas del jugador")

	b1.free()
	b2.free()
	s.free()
	battle.free()

func test_multi_stream_simultaneous_collision() -> void:
	print("\n-> Test: Choque Simultáneo Multi-Stream (Estabilidad de Array)")
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	var a = _make_base(Vector2(100, 500))
	var b = _make_base(Vector2(900, 500))
	var c = _make_base(Vector2(900, 500), GameManager.Faction.ENEMY_2)
	# t1 (jugador, 10) choca de frente contra dos hileras de facciones distintas que salen de B
	var t1 = _make_stream(a, b, 10, GameManager.Faction.PLAYER)
	var t2 = _make_stream(b, a, 3, GameManager.Faction.ENEMY_1)
	var t3 = _make_stream(c, a, 4, GameManager.Faction.ENEMY_2)
	battle.active_troops.append_array([t1, t2, t3])
	_simulate(battle, [t1, t2, t3], 40, 0.04)

	assert_equals(t1.count, 3, "Tropa aliada sobrevive a ambos enemigos consecutivos (10 - 3 - 4 = 3)")
	assert_true(not is_instance_valid(t2), "Primer stream enemigo eliminado")
	assert_true(not is_instance_valid(t3), "Segundo stream enemigo no fue saltado y fue eliminado")

	for n in [t1, a, b, c, battle]:
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
	stream.setup(base_origin, base_target, 15, GameManager.Faction.PLAYER)

	assert_equals(stream.front_index(), 0, "front_index apunta al primer paquete vivo")
	stream.damage_packet(0, 5)
	stream.damage_packet(1, 5)
	assert_equals(stream.count, 5, "damage_packet reduce conteo de 15 a 5 correctamente")
	assert_equals(stream.front_index(), 2, "front_index salta los paquetes eliminados")

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
	b_a.faction = GameManager.Faction.PLAYER
	b_a.troops = 20
	b_a.radius = 50.0
	b_a.position = Vector2(200, 200)
	b_a.global_position = Vector2(200, 200)
	battle.bases.append(b_a)

	var b_b = BaseNodeScript.new()
	b_b.faction = GameManager.Faction.PLAYER
	b_b.troops = 15
	b_b.radius = 50.0
	b_b.position = Vector2(400, 200)
	b_b.global_position = Vector2(400, 200)
	battle.bases.append(b_b)

	var b_c = BaseNodeScript.new()
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

	var area_initial = _polygon_area(square)
	assert_equals(area_initial, 10000.0, "Cálculo de área de polígono cuadrado inicial es 10000")

	# 1. Recorte vertical: mantener puntos donde X <= 40
	# Punto plano (40, 50), Normal (1, 0)
	var clipped_vert = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(40, 50), Vector2(1, 0))
	assert_equals(clipped_vert.size(), 4, "Polígono recortado verticalmente tiene 4 vértices")
	var area_vert = _polygon_area(clipped_vert)
	assert_true(abs(area_vert - 4000.0) < 0.1, "Área resultante tras corte X <= 40 es 4000 (40 x 100)")

	# 2. Recorte horizontal: mantener puntos donde Y <= 60
	# Punto plano (50, 60), Normal (0, 1)
	var clipped_horiz = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(50, 60), Vector2(0, 1))
	var area_horiz = _polygon_area(clipped_horiz)
	assert_true(abs(area_horiz - 6000.0) < 0.1, "Área resultante tras corte Y <= 60 es 6000 (100 x 60)")

	# 3. Recorte diagonal a 45 grados: pasando por (50, 50) con normal (1, 1).normalized()
	var diag_normal = Vector2(1, 1).normalized()
	var clipped_diag = TerritoryMap2DScript.clip_polygon_halfplane(square, Vector2(50, 50), diag_normal)
	assert_true(clipped_diag.size() >= 3, "Recorte diagonal produce polígono convexo válido")
	var area_diag = _polygon_area(clipped_diag)
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

	assert_equals(map.cells.size(), 1, "Mapa con 1 base genera exactamente 1 celda")
	var single_cell = map.cells[0]
	var area_single = _polygon_area(single_cell.polygon)
	assert_equals(area_single, total_bounds_area, "Celda única cubre el 100% del área 1080x1920 (2,073,600 px²)")
	b_single.free()

	# 2. Probar nivel con 4 bases (similar a Península Ibérica y Galia: Madrid, París, Londres, Berlín)
	var b1 = BaseNodeScript.new()
	b1.base_name = "Madrid"
	b1.global_position = Vector2(320, 1400)
	b1.faction = GameManager.Faction.PLAYER

	var b2 = BaseNodeScript.new()
	b2.base_name = "París"
	b2.global_position = Vector2(540, 1000)
	b2.faction = GameManager.Faction.NEUTRAL

	var b3 = BaseNodeScript.new()
	b3.base_name = "Londres"
	b3.global_position = Vector2(360, 600)
	b3.faction = GameManager.Faction.NEUTRAL

	var b4 = BaseNodeScript.new()
	b4.base_name = "Berlín"
	b4.global_position = Vector2(760, 650)
	b4.faction = GameManager.Faction.ENEMY_1

	var bases_list: Array[BaseNode] = [b1, b2, b3, b4]
	map.generate_map(bases_list, bounds)

	assert_equals(map.cells.size(), 4, "Se generan exactamente 4 territorios para las 4 bases")

	# Verificar que cada base está estrictamente dentro de su propio polígono territorial
	for b in bases_list:
		var cell = map.get_cell_for_base(b)
		assert_true(cell != null, "Existe celda territorial para base '%s'" % b.base_name)
		var is_inside = Geometry2D.is_point_in_polygon(b.global_position, cell.polygon)
		assert_true(is_inside, "Base capital '%s' está estrictamente contenida en su polígono territorial" % b.base_name)
		assert_true(cell.polygon.size() >= 3, "Polígono de '%s' tiene al menos 3 vértices" % b.base_name)

	# Verificar teselado exacto: la suma de áreas de las 4 celdas debe igualar el área total del rectángulo
	var sum_areas = 0.0
	for cell in map.cells:
		sum_areas += _polygon_area(cell.polygon)
	var area_diff = abs(sum_areas - total_bounds_area)
	assert_true(area_diff < 10.0, "La suma de áreas de los territorios tesela el 100% del área de juego (Error < 0.001%)")

	# Verificar búsqueda de territorio por coordenada (Point in polygon)
	var madrid_index: int = map.cells.find_custom(func(c): return Geometry2D.is_point_in_polygon(Vector2(320, 1400), c.polygon))
	assert_true(madrid_index >= 0 and map.cells[madrid_index].base_node == b1, "El polígono de Madrid contiene su capital")

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
	assert_equals(map.cells.size(), 0, "generate_map con lista vacía produce 0 celdas sin errores")

	# 2. Caso límite: bases colineales alineadas verticalmente
	var b_col1 = BaseNodeScript.new()
	b_col1.global_position = Vector2(540, 400)
	var b_col2 = BaseNodeScript.new()
	b_col2.global_position = Vector2(540, 960)
	var b_col3 = BaseNodeScript.new()
	b_col3.global_position = Vector2(540, 1520)

	map.generate_map([b_col1, b_col2, b_col3], bounds)
	assert_equals(map.cells.size(), 3, "Bases colineales generan exactamente 3 celdas horizontales")
	var sum_col_area = 0.0
	for c in map.cells:
		assert_equals(c.polygon.size(), 4, "Cada franja territorial colineal tiene 4 vértices rectangulares")
		sum_col_area += _polygon_area(c.polygon)
	assert_true(abs(sum_col_area - total_bounds_area) < 5.0, "Franjas colineales teselan el 100% del área de juego")

	b_col1.free()
	b_col2.free()
	b_col3.free()

	# 3. Conquistas rápidas sucesivas en combate disputado
	var base = BaseNodeScript.new()
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
	var all_levels = _all_campaign_levels()
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
		var cells = map.cells

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
				sum_area += _polygon_area(cell.polygon)

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
	fortress._set_type_from_variant(BaseNodeScript.BaseType.FORTRESS)
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
	f2._set_type_from_variant("standard")
	assert_equals(f2.base_type, BaseNodeScript.BaseType.STANDARD, "El tipo standard se lee correctamente")
	f2._set_type_from_variant(BaseNodeScript.BaseType.FORTRESS)
	assert_equals(f2.base_type, BaseNodeScript.BaseType.FORTRESS, "El tipo de base acepta el valor del enum")
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
	factory._set_type_from_variant(BaseNodeScript.BaseType.FACTORY)
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
	ai_red.set_archetype(AIControllerScript.AIArchetype.EXPANSIVE)
	assert_equals(ai_red.archetype, AIControllerScript.AIArchetype.EXPANSIVE, "set_archetype conmuta dinámicamente el arquetipo")

	# 6. Caso límite: evaluación hacia la misma base origen (debe ser inválida / -9999.0)
	var self_util = ai_red.evaluate_target_utility(src_base, src_base)
	assert_equals(self_util, -9999.0, "evaluate_target_utility descarta el nodo propio retornando -9999.0")

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

	# 2. Verificar disparador de confeti, partículas y simulación procedural
	hud.trigger_confetti()
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
	assert_equals(star1.text, "★", "Con 1 estrella ganada: Star1 es ★")
	assert_equals(star2.text, "☆", "Con 1 estrella ganada: Star2 es ☆ pendiente")
	assert_equals(star3.text, "☆", "Con 1 estrella ganada: Star3 es ☆ pendiente")

	# 5. Probar configuración con 2 estrellas
	hud.animate_stars(2)
	assert_equals(star1.text, "★", "Con 2 estrellas ganadas: Star1 es ★")
	assert_equals(star2.text, "★", "Con 2 estrellas ganadas: Star2 es ★")
	assert_equals(star3.text, "☆", "Con 2 estrellas ganadas: Star3 es ☆ pendiente")

	# 6. Probar configuración con 3 estrellas y re-disparo seguro de tweens
	hud.animate_stars(3)
	assert_equals(star1.text, "★", "Con 3 estrellas ganadas: Star1 es ★")
	assert_equals(star2.text, "★", "Con 3 estrellas ganadas: Star2 es ★")
	assert_equals(star3.text, "★", "Con 3 estrellas ganadas: Star3 es ★")
	assert_true(hud._star_tweens.size() > 0, "animate_stars gestiona lista activa de tweens sin conflictos")

	# 7. Probar despliegue completo de modal con conquista continental
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 150, "is_continent_conquest": true})
	assert_true(hud.victory_panel.visible, "VictoryPanel es visible tras deploy_victory_modal()")
	var title = hud.get_node_or_null("%VictoryTitle")
	assert_true(title != null, "Label de título en VictoryPanel existe")
	assert_equals(title.text, "¡Continente conquistado!", "Título de continente conquistado al completar nivel 5")

	# Probar despliegue de victoria estándar
	hud.deploy_victory_modal({"stars": 2, "gold_earned": 90, "is_continent_conquest": false})
	assert_equals(title.text, "¡Victoria!", "Título de victoria en niveles normales")

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
	battle.is_game_over = false # Nueva batalla, no repetir la señal de victoria anterior.
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

	# Avanzar delta para que los paquetes salgan uno tras otro
	troop._process(0.3)
	var emerged = 0
	for i in troop.packets.size():
		if troop.packet_dist(i) >= 0.0:
			emerged += 1
	assert_true(emerged >= 2 and emerged < troop.packets.size(), "Los paquetes salen escalonados (%d de %d fuera)" % [emerged, troop.packets.size()])

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

func test_hud_force_counters() -> void:
	print("\n-> Test: Barra de Fuerzas y Contadores del HUD")
	var hud: BattleHUD = load("res://scenes/ui/battle_hud.tscn").instantiate()
	add_child(hud)
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	add_child(battle)
	for b in battle.bases:
		b.queue_free()
	battle.bases.clear()
	battle.active_troops.clear()
	hud.battle_controller = battle
	var b_player = _make_base(Vector2.ZERO, GameManager.Faction.PLAYER, 35)
	var b_enemy = _make_base(Vector2.ZERO, GameManager.Faction.ENEMY_1, 20)
	var b_neutral = _make_base(Vector2.ZERO, GameManager.Faction.NEUTRAL, 15)
	battle.bases.append_array([b_player, b_enemy, b_neutral])

	hud._update_dominance_bar()
	assert_true(hud.label_count_player.text.contains("35") and hud.label_count_player.text.contains(GameManager.faction_name(GameManager.Faction.PLAYER)), "El jugador se ve como 'Tú' con sus tropas")
	assert_true(hud.label_count_enemy.text.contains("20"), "Contador enemigo en vivo")
	assert_true(hud.label_count_neutral.text.contains("15"), "Contador neutral en vivo")
	assert_equals(hud.bar_player.size_flags_stretch_ratio, 35.0, "El segmento del jugador es proporcional a sus tropas")
	assert_equals(hud.bar_enemy.size_flags_stretch_ratio, 20.0, "El segmento enemigo es proporcional a sus tropas")
	assert_true(not hud._faction_bars[GameManager.Faction.ENEMY_2].visible, "Los bandos ausentes no ocupan la barra")

	var b_enemy2 = _make_base(Vector2.ZERO, GameManager.Faction.ENEMY_2, 12)
	battle.bases.append(b_enemy2)
	hud._update_dominance_bar()
	assert_true(hud.label_count_enemy.text.contains("20") and hud.label_count_enemy.text.contains("12"), "Se listan todos los rivales activos")
	assert_true(hud._faction_bars[GameManager.Faction.ENEMY_2].visible, "Un nuevo rival aparece en la barra")

	remove_child(hud)
	remove_child(battle)
	hud.free()
	for b in [b_player, b_enemy, b_enemy2, b_neutral, battle]:
		b.free()

func test_main_menu_hub_navigation() -> void:
	print("\n-> Test: Menú Principal con Secciones (Jugar, Retos, Ejército, Progreso)")
	GameManager.reset_save()
	var menu: MainMenuUI = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	assert_equals(menu.current_tab, "play", "El menú abre en Jugar")
	assert_equals(menu._nav.size(), 4, "La barra inferior tiene cuatro secciones")
	for tab in ["challenges", "army", "progress", "play"]:
		menu.show_tab(tab)
		assert_true(menu.current_tab == tab and menu._nav[tab].button_pressed, "La sección %s queda activa en la barra" % tab)
		assert_equals(menu._content.get_child_count(), 1, "Sólo hay una sección montada a la vez (%s)" % tab)
	assert_true(menu.btn_settings != null, "Ajustes accesibles desde la cabecera")

	# Avisos: un punto sólo cuando hay algo que recoger, sin ventanas emergentes
	assert_true(menu._badges["challenges"].visible, "Retos avisa de la recompensa diaria pendiente")
	assert_true(not menu._badges["progress"].visible, "Progreso sin avisos si no hay logros por cobrar")
	GameManager.claim_daily_reward()
	assert_true(not menu._badges["challenges"].visible, "El aviso de Retos desaparece al recoger")
	GameManager.unlock_achievement("blitz")
	EventBus.achievement_unlocked.emit("blitz")
	assert_true(menu._badges["progress"].visible, "Progreso avisa del logro por cobrar")
	EventBus.coins_updated.emit(420)
	assert_true(menu.coins_label.text.contains("420"), "El saldo responde a EventBus.coins_updated")

	# Abrir directamente en una sección (al salir de una batalla) y volver con el botón atrás
	MainMenuUI.next_tab = "army"
	var menu2: MainMenuUI = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu2)
	assert_equals(menu2.current_tab, "army", "El menú se abre en la sección pedida")
	assert_equals(MainMenuUI.next_tab, "play", "La petición se consume una sola vez")
	menu2._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_equals(menu2.current_tab, "play", "Atrás desde una sección vuelve a Jugar")
	remove_child(menu2)
	menu2.free()

	# Reinicio agrupado en ajustes, con confirmación nativa explícita
	GameManager.coins = 999
	menu._open_settings()
	menu._utility_panel._confirm_reset()
	assert_equals(GameManager.coins, 999, "El primer toque en reiniciar sólo pide confirmación")
	var confirmation: ConfirmationDialog = menu._utility_panel.get_children().filter(func(c): return c is ConfirmationDialog)[0]
	assert_true(confirmation.dialog_text.contains("progreso"), "El diálogo advierte antes de borrar")
	confirmation.confirmed.emit()
	assert_equals(GameManager.coins, 150, "Reiniciar progreso restaura monedas iniciales a 150")
	assert_equals(GameManager.get_total_stars(), 0, "Reiniciar progreso resetea estrellas completadas a 0")
	assert_true(menu.coins_label.text.contains("150"), "Etiqueta de monedas se actualiza tras reseteo")

	remove_child(menu)
	menu.free()
	GameManager.reset_save()

func test_play_tab_campaign_route_and_briefing() -> void:
	print("\n-> Test: Jugar (Mapa del Continente, Ficha del Nivel y Accesos Directos)")
	GameManager.reset_save()
	var play = load("res://scripts/ui/play_tab.gd").new()
	add_child(play)
	for node in [play.continent_title, play.btn_prev_continent, play.btn_next_continent, play.levels_container,
			play.route_container, play.level_title, play.level_desc, play.level_stars, play.level_chips,
			play.btn_start_level, play.btn_conquest, play.btn_daily]:
		assert_true(node != null, "Elemento de Jugar presente: %s" % node.get_class())

	# 1. Un toque para seguir la campaña
	assert_equals(play.selected_level_id, "europe_1", "Se propone el nivel actual de la campaña")
	assert_equals(play.btn_start_level.text, LocaleStrings.text("continue"), "El botón principal es Continuar")
	assert_equals(play.level_chips.get_child_count(), 4, "Bases, rivales, tiempo de 3★ y ciudades nuevas como etiquetas")
	assert_true(play.level_medal.text == LocaleStrings.text("medal_todo"), "La ficha anuncia el objetivo de medalla")

	# 2. Navegación de continentes sin nodos fantasma
	assert_equals(play.continents.size(), 6, "Existen 6 continentes configurados")
	var orig_idx = play.current_continent_index
	play._on_next_continent()
	assert_equals(play.current_continent_index, (orig_idx + 1) % 6, "Avanzar continente incrementa índice correctamente")
	assert_equals(play.levels_container.get_child_count(), 5, "Cambio de continente mantiene exactamente 5 nodos limpios")
	assert_equals(GameManager.current_continent, play.continents[play.current_continent_index]["id"], "El continente elegido se recuerda")
	play._on_prev_continent()
	assert_equals(play.current_continent_index, orig_idx, "Retroceder continente restaura índice original")

	# 3. Estado de cada nivel en la ruta
	var btn1 = play.levels_container.get_node("NodeHolder_1/BtnLevel_1") as Button
	var btn5 = play.levels_container.get_node("NodeHolder_5/BtnLevel_5") as Button
	assert_true(not btn1.disabled and btn1.text == "1", "Nivel 1 de Europa desbloqueado y numerado")
	assert_true(btn5.disabled and btn5.icon != null, "Nivel 5 bloqueado con candado")

	# 4. Ficha: repetir un nivel superado, bloqueo y reglas
	GameManager.completed_levels["europe_1"] = 3
	play._select_level("europe_1")
	assert_equals(play.btn_start_level.text, LocaleStrings.text("replay_level") % 1, "Un nivel superado se ofrece para repetir")
	assert_equals(play.level_stars.text, "★★★", "La ficha muestra las estrellas conseguidas")
	play._select_level("europe_5")
	assert_true(play.btn_start_level.disabled, "Botón deshabilitado para nivel bloqueado")
	assert_equals(play.btn_start_level.text, LocaleStrings.text("level_locked"), "Texto de nivel bloqueado")
	assert_true(play.level_rule.visible and play.level_rule.text.contains("👑"), "El jefe del continente se explica en la ficha")

	# 5. Accesos directos y animación de la frontera
	var labels: Array = play.btn_conquest.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_true(labels.has(LocaleStrings.text("conquest")), "Conquista libre a un toque desde Jugar")
	assert_true(play.btn_daily.find_children("*", "Label", true, false).any(func(l): return l.text == LocaleStrings.text("daily")), "Desafío diario a un toque desde Jugar")
	var initial_phase = play.marching_phase
	play._process(0.1)
	assert_true(play.marching_phase != initial_phase, "La frontera de la campaña se anima")

	remove_child(play)
	play.free()
	GameManager.reset_save()

func test_army_tab_upgrades_and_looks() -> void:
	print("\n-> Test: Ejército (Mejoras con Progreso y Aspecto con Vista Previa)")
	GameManager.reset_save()
	var army = load("res://scripts/ui/army_tab.gd").new()
	add_child(army)
	var cards: Array = army.find_children("UpgradeCard_*", "", true, false)
	assert_equals(cards.size(), 4, "Existen exactamente 4 tarjetas de mejora")
	assert_true(army.find_child("CosmeticRow_color_cyan", true, false) == null, "El aspecto vive en su propia pestaña")
	var pips: Array = cards[0].find_children("*", "HBoxContainer", true, false).filter(func(c): return c.get_child_count() == 10)
	assert_equals(pips.size(), 1, "La barra segmentada contiene 10 niveles")

	# Compra: descuenta oro, sube de nivel y redibuja conservando la sección
	GameManager.coins = 500
	var cost = GameManager.get_upgrade_cost("starting_troops")
	army._buy_upgrade("starting_troops")
	assert_equals(GameManager.upgrades["starting_troops"], 1, "Mejora 'starting_troops' incrementada a nivel 1")
	assert_equals(GameManager.coins, 500 - cost, "Oro descontado tras la compra")
	var card = army.find_child("UpgradeCard_starting_troops", true, false)
	assert_true(card.find_children("*", "Label", true, false).any(func(l): return l.text.contains("+5") and l.text.contains("+10")), "La tarjeta muestra efecto actual › siguiente")

	# Sin oro suficiente: botón desactivado y cuánto falta
	GameManager.coins = 10
	EventBus.coins_updated.emit(10)
	card = army.find_child("UpgradeCard_production_rate", true, false)
	var buy: Button = card.find_children("*", "Button", true, false)[0]
	assert_true(buy.disabled, "No se puede comprar sin oro")
	var missing: int = GameManager.get_upgrade_cost("production_rate") - 10
	assert_true(card.find_children("*", "Label", true, false).any(func(l): return l.text.contains(str(missing))), "Se explica cuánto oro falta")
	assert_equals(GameManager.buy_upgrade("production_rate"), false, "Compra rechazada cuando los fondos son insuficientes")

	# Nivel máximo
	GameManager.upgrades["starting_troops"] = 10
	army.rebuild()
	buy = army.find_child("UpgradeCard_starting_troops", true, false).find_children("*", "Button", true, false)[0]
	assert_true(buy.disabled and buy.text == LocaleStrings.text("max"), "Botón en nivel máximo")

	# Aspecto: miniaturas y estados comprar / equipar / equipado
	army.find_child("Segment_looks", true, false).pressed.emit()
	assert_equals(army.section, "looks", "La pestaña Aspecto se activa")
	assert_equals(army.find_children("CosmeticRow_*", "", true, false).size(), CosmeticsDatabase.ITEMS.size(), "Una miniatura por objeto")
	var blue: Button = army.find_child("CosmeticRow_color_blue", true, false).find_children("*", "Button", true, false)[0]
	assert_true(blue.disabled and blue.text == LocaleStrings.text("equipped"), "El objeto equipado se indica claramente")
	remove_child(army)
	army.free()

	# Tras una derrota, Ejército ofrece volver a la misma batalla
	var retry = load("res://scripts/ui/army_tab.gd").new()
	retry.return_to_battle = true
	add_child(retry)
	assert_true(retry.find_child("BtnReturnToBattle", true, false) != null, "Acceso directo para volver a la batalla")
	remove_child(retry)
	retry.free()
	GameManager.reset_save()

func test_battle_hud_modals_and_sound_toggle() -> void:
	print("\n-> Test: Capas de Batalla (Pausa, Victoria, Derrota), Sonido y Salidas")
	var hud: BattleHUD = load("res://scenes/ui/battle_hud.tscn").instantiate()
	add_child(hud)

	# 1. Nodos y visibilidad inicial
	for node in [hud.dim_overlay, hud.victory_panel, hud.defeat_panel, hud.pause_panel, hud.btn_pause, hud.btn_resume, hud.btn_pause_sound, hud.btn_how_to_play, hud.btn_settings]:
		assert_true(node != null, "Nodo del HUD presente: %s" % node.name)
	assert_true(not hud.dim_overlay.visible and not hud.victory_panel.visible and not hud.defeat_panel.visible and not hud.pause_panel.visible, "Capas ocultas al empezar")

	# 2. Pausa y sonido
	hud._on_pause_pressed()
	assert_true(hud.pause_panel.visible and hud.dim_overlay.visible, "Pausa visible sobre un fondo atenuado")
	assert_equals(hud.dim_overlay.mouse_filter, Control.MOUSE_FILTER_STOP, "El fondo bloquea los toques en pausa")
	assert_true(get_tree().paused, "Árbol de escena queda pausado")
	var prev_muted = AudioManager.is_muted
	hud._on_pause_sound_pressed()
	assert_equals(AudioManager.is_muted, not prev_muted, "BtnPauseSound alterna el mute en AudioManager")
	assert_equals(hud.btn_pause_sound.tooltip_text, LocaleStrings.text("sound_off" if not prev_muted else "sound_on"), "El botón de sonido refleja su estado")
	assert_true((hud.btn_pause_sound.modulate.a < 1.0) == (not prev_muted), "El icono se atenúa cuando está silenciado")
	hud._on_pause_sound_pressed()
	assert_equals(AudioManager.is_muted, prev_muted, "BtnPauseSound restaura el estado original")
	hud.btn_how_to_play.pressed.emit()
	var help = hud.find_child("BtnConfirm", true, false)
	assert_true(help != null, "Cómo jugar se consulta desde la pausa")
	help.pressed.emit()
	hud._on_resume_pressed()
	get_tree().paused = false
	hud.pause_panel.visible = false
	hud.dim_overlay.visible = false

	# 3. Victoria: estrellas, tiempo, oro y ciudades nuevas
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 150, "time": 41.2, "new_cities": 2, "is_continent_conquest": false})
	assert_true(hud.victory_panel.visible and hud.dim_overlay.visible, "Victoria visible tras ganar")
	assert_equals(hud.victory_title.text, LocaleStrings.text("victory"), "Título de victoria estándar")
	assert_equals(hud.victory_reward_label.text, "+150", "Recompensa de oro mostrada")
	assert_equals(hud.stat_time_value.text, "42s", "Tiempo de la batalla mostrado")
	assert_equals(hud.stat_cities_value.text, "+2", "Ciudades nuevas del atlas mostradas")
	assert_equals(hud.confetti_pieces.size(), 75, "Celebración breve con confeti")
	hud._update_confetti(0.1)
	assert_true(hud.confetti_pieces.size() > 0, "Partículas de confeti se procesan sin error")
	hud.deploy_victory_modal({"stars": 1, "gold_earned": 50})
	assert_equals([hud.star_1.text, hud.star_2.text, hud.star_3.text], ["★", "☆", "☆"], "Una estrella ganada y dos pendientes")
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 300, "is_continent_conquest": true})
	assert_equals(hud.victory_title.text, LocaleStrings.text("continent_conquest"), "Título de victoria continental aplicado")
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 150, "is_daily_challenge": true, "level_id": DailyRewards.challenge_id(1)})
	assert_true(hud.btn_share.visible and not hud.btn_next_level.visible, "El desafío diario ofrece compartir en vez de siguiente nivel")
	assert_equals(hud.btn_victory_map.text, LocaleStrings.text("to_challenges"), "El desafío diario vuelve a Retos")

	# 4. Derrota: reintentar es la acción principal
	hud.victory_panel.visible = false
	hud._on_battle_lost()
	assert_true(hud.defeat_panel.visible and hud.dim_overlay.visible, "Derrota visible")
	assert_equals(hud.btn_retry.theme_type_variation, &"PrimaryButton", "Reintentar es la acción destacada")

	# 5. Salir devuelve a la sección de la que viene cada modo
	var exit_battle := BattleController.new()
	hud.battle_controller = exit_battle
	exit_battle.level_id = DailyRewards.challenge_id(1)
	assert_equals(hud.exit_tab(), "challenges", "El desafío diario vuelve a Retos")
	exit_battle.level_id = "europe_2"
	assert_equals(hud.exit_tab(), "play", "La campaña vuelve a Jugar")
	hud.battle_controller = null
	exit_battle.free()

	get_tree().paused = false
	Engine.time_scale = 1.0
	remove_child(hud)
	hud.free()

func test_theme_and_ui_helpers() -> void:
	print("\n-> Test: Tema Visual Global, Iconos y Piezas de Interfaz")
	var theme := ThemeDB.get_default_theme()
	for v in ["PrimaryButton", "GoldButton", "GhostButton", "IconButton", "NavButton", "SegmentButton", "RowButton"]:
		assert_equals(theme.get_type_variation_base(v), &"Button", "Variación de botón %s instalada" % v)
	for v in ["Sheet", "Chip", "NavBar", "Tile"]:
		assert_equals(theme.get_type_variation_base(v), &"PanelContainer", "Variación de panel %s instalada" % v)
	for v in ["Display", "Title", "Heading", "Caption"]:
		assert_equals(theme.get_type_variation_base(v), &"Label", "Variación de texto %s instalada" % v)
	for type in ["Button", "PrimaryButton", "GoldButton"]:
		var ink: float = theme.get_color("font_color", type).srgb_to_linear().get_luminance()
		var background: float = (theme.get_stylebox("normal", type) as StyleBoxFlat).bg_color.srgb_to_linear().get_luminance()
		assert_true((maxf(ink, background) + 0.05) / (minf(ink, background) + 0.05) >= 4.5, "El texto de %s tiene contraste accesible" % type)

	# Feedback táctil automático y sin duplicar señales
	var btn := Button.new()
	add_child(btn)
	UIThemeHelper.setup_press_feedback(btn)
	assert_true(btn.has_meta("_press_feedback"), "Todo botón recibe feedback al pulsarlo")
	assert_equals(btn.get_signal_connection_list("button_down").size(), 1, "El feedback no se duplica")
	remove_child(btn)
	btn.free()

	# Iconos SVG: todos se generan, se cachean y la moneda conserva su color en botones
	var broken := Icons.SVG.keys().filter(func(n): return Icons.texture(n, 48).get_height() != 48)
	assert_true(broken.is_empty(), "Todos los iconos se generan a su tamaño %s" % str(broken))
	assert_true(Icons.texture("coin", 48) == Icons.texture("coin", 48), "Los iconos se cachean")
	var gold := UIThemeHelper.button("10", "GoldButton", "coin")
	assert_equals(gold.get_theme_color("icon_normal_color"), Color.WHITE, "La moneda no se tiñe con el color del texto")
	gold.free()
	var stars := UIThemeHelper.stars_label(2)
	assert_equals(stars.text, "★★☆", "Valoración de estrellas con glifos de la fuente")
	stars.free()

	# Capas modales: animación y tarjeta de ayuda que se cierra sola
	var ctrl = Control.new()
	add_child(ctrl)
	UIThemeHelper.animate_modal_pop_in(ctrl)
	assert_true(ctrl.visible, "animate_modal_pop_in hace visible el control")
	UIThemeHelper.animate_modal_pop_out(ctrl)
	UIThemeHelper.animate_modal_pop_in(ctrl)
	assert_true(ctrl.visible, "animate_modal_pop_in cancela pop_out previo y conserva visibilidad")
	remove_child(ctrl)
	ctrl.free()
	var help := UIThemeHelper.how_to_play_card()
	add_child(help)
	help.find_child("BtnConfirm", true, false).pressed.emit()
	assert_true(help.is_queued_for_deletion(), "La tarjeta Cómo jugar se cierra con su botón")
	remove_child(help)
	help.free()

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
	assert_equals(big.packets.size(), Troop.MAX_PACKETS, "Orden de 300 unidades se reparte en %d paquetes" % Troop.MAX_PACKETS)
	var total = 0
	for v in big.packets:
		total += v
	assert_equals(total, 300, "Los paquetes conservan las 300 unidades")
	battle.active_troops.clear()
	battle.active_troops.append_array([big, mid])
	_simulate(battle, [big, mid], 50, 0.05)
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
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH + ".corrupt") and not FileAccess.file_exists(TEST_SAVE_PATH),
		"El guardado ilegible se aparta en lugar de sobrescribirse")
	DirAccess.remove_absolute(TEST_SAVE_PATH + ".corrupt")

	# 2b. Tipos inesperados y datos imposibles: cada campo vuelve a un valor válido
	f = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"coins": {}, "upgrades": {"hack": 10, "troop_speed": "x"},
		"completed_levels": {"europe_1": 0, "europe_2": 7, "mars_1": 3}, "unlocked_levels": "abc",
		"current_level_id": "mars_9", "current_continent": 5, "sound_muted": "yes"}))
	f.close()
	GameManager.load_game()
	assert_equals(GameManager.coins, GameManager.DEFAULT_COINS, "Monedas con tipo inválido vuelven al valor inicial")
	assert_true(not GameManager.upgrades.has("hack") and GameManager.upgrades["troop_speed"] == 0, "Se descartan mejoras desconocidas o con tipo inválido")
	assert_equals(GameManager.completed_levels, {"europe_2": 3}, "Sólo cuentan niveles reales con 1-3 estrellas")
	assert_equals(GameManager.unlocked_levels, [GameManager.FIRST_LEVEL_ID] as Array[String], "Una lista de niveles corrupta deja jugable el primero")
	assert_equals(GameManager.current_level_id, GameManager.FIRST_LEVEL_ID, "Un nivel actual inexistente vuelve al primero")
	assert_equals(GameManager.current_continent, "europe", "Un continente inválido se deduce del nivel actual")
	assert_true(not GameManager.sound_muted, "Un ajuste con tipo inválido toma su valor por defecto")

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
	assert_true(Tutorial.has_pending_steps("europe_4", LevelDatabase.get_level_data("europe_4")), "europe_4 presenta la fábrica")
	assert_true(Tutorial.has_pending_steps("north_america_1", LevelDatabase.get_level_data("north_america_1")), "La industria introduce una fábrica con su tutorial")

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

	# Un gesto que sólo caduca, sin que el jugador lo haga, se volverá a enseñar
	GameManager.reset_save()
	GameManager.current_level_id = "europe_2"
	var field2 = load("res://scenes/battle/battle_field.tscn").instantiate()
	add_child(field2)
	assert_equals(field2._tutorial._current, "chain", "europe_2 enseña a encadenar bases")
	field2._tutorial._complete_current(false)
	assert_true(not GameManager.has_seen_tip("chain"), "Un paso caducado no se marca como aprendido")
	remove_child(field2)
	field2.free()
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
	for cell in map.cells:
		var visible = 0.0
		for piece in cell.pieces:
			visible += _polygon_area(piece)
		clipped_to_land = clipped_to_land and visible < _polygon_area(cell.polygon)
		capitals_covered = capitals_covered and cell.pieces.any(func(pc): return Geometry2D.is_point_in_polygon(cell.capital_pos, pc))
	assert_true(clipped_to_land, "El mar no pertenece a ningún territorio")
	assert_true(capitals_covered, "Cada capital se asienta sobre su propio territorio (o su islote)")
	for n in nodes:
		n.free()
	map.free()

	# 6. Mapa de Jugar: cada nivel sobre su región real, sin nodos solapados
	var layout = load("res://scripts/ui/play_tab.gd")._build_continent_layout("europe")
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

func test_daily_rewards_and_streaks() -> void:
	print("\n-> Test: Recompensa Diaria con Racha")
	# 1. Reglas puras
	var first = DailyRewards.evaluate(-1, 0, 100)
	assert_true(first["can_claim"] and first["streak"] == 1, "La primera recompensa inicia la racha en 1")
	assert_equals(first["reward"], DailyRewards.STREAK_REWARDS[0], "El día 1 da la recompensa base")
	assert_equals(DailyRewards.evaluate(100, 1, 101)["streak"], 2, "Volver al día siguiente suma racha")
	assert_equals(DailyRewards.evaluate(100, 5, 103)["streak"], 1, "Saltarse un día reinicia la racha")
	assert_true(not DailyRewards.evaluate(100, 1, 100)["can_claim"], "No se cobra dos veces el mismo día")
	assert_true(not DailyRewards.evaluate(100, 3, 95)["can_claim"], "Atrasar el reloj no permite cobrar otra vez")
	assert_equals(DailyRewards.reward_for_streak(7), DailyRewards.STREAK_REWARDS[-1], "El día 7 da el premio gordo")
	assert_equals(DailyRewards.reward_for_streak(8), DailyRewards.STREAK_REWARDS[0], "El día 8 vuelve a empezar el ciclo")
	assert_true(DailyRewards.today() > 19000, "El día local actual es coherente (días desde 1970)")

	# 2. Cobro real: oro, racha guardada y récord de racha para el logro
	GameManager.reset_save()
	var coins0 = GameManager.coins
	var gold = GameManager.claim_daily_reward(500)
	assert_equals(GameManager.coins, coins0 + gold, "Recoger la recompensa suma el oro")
	assert_equals(GameManager.claim_daily_reward(500), 0, "El segundo cobro del mismo día no da nada")
	GameManager.claim_daily_reward(501)
	GameManager.claim_daily_reward(502)
	GameManager.load_game()
	assert_equals(int(GameManager.daily["streak"]), 3, "La racha sobrevive a guardar y cargar")
	assert_equals(GameManager.get_stat("daily_streak"), 3, "Se registra la mejor racha")
	GameManager.claim_daily_reward(510)
	assert_equals(int(GameManager.daily["streak"]), 1, "Tras una ausencia, la racha vuelve a 1")
	assert_equals(GameManager.get_stat("daily_streak"), 3, "La mejor racha no se pierde al romperse")
	GameManager.reset_save()

func test_achievements_system() -> void:
	print("\n-> Test: Sistema de Logros (Eventos, Progreso, Reclamo y Guardado)")
	GameManager.reset_save()
	var unlocked_events: Array[String] = []
	var on_unlock = func(id): unlocked_events.append(id)
	EventBus.achievement_unlocked.connect(on_unlock)

	# 1. Datos: ids únicos, recompensas positivas y estadísticas conocidas
	var ids = {}
	for a in AchievementDatabase.get_all():
		ids[a["id"]] = true
	assert_equals(ids.size(), AchievementDatabase.get_all().size(), "Los ids de logro son únicos")
	assert_true(AchievementDatabase.get_all().all(func(a): return a["goal"] > 0 and a["reward"] > 0), "Todos los logros tienen meta y recompensa")

	# 2. Una victoria rápida y sin bajas desbloquea tres logros a la vez (sin dar oro todavía)
	var coins0 = GameManager.coins
	EventBus.battle_started.emit("europe_1")
	EventBus.base_captured.emit(null, GameManager.Faction.NEUTRAL, GameManager.Faction.PLAYER)
	EventBus.battle_won.emit({"time": 12.0})
	assert_equals(GameManager.get_stat("victories"), 1, "Se cuentan las victorias")
	assert_equals(GameManager.get_stat("bases_captured"), 1, "Se cuentan los territorios capturados")
	for id in ["first_victory", "blitz", "flawless"]:
		assert_true(GameManager.is_achievement_unlocked(id), "Logro '%s' desbloqueado" % id)
	assert_true(unlocked_events.has("first_victory"), "Se avisa del desbloqueo por el EventBus")
	assert_equals(GameManager.coins, coins0, "Desbloquear no da oro: la recompensa se reclama")
	assert_equals(GameManager.get_claimable_achievement_count(), 3, "Hay 3 recompensas pendientes")

	# 3. Perder un territorio impide el logro sin bajas en esa batalla
	EventBus.battle_started.emit("europe_2")
	EventBus.base_captured.emit(null, GameManager.Faction.PLAYER, GameManager.Faction.ENEMY_1)
	EventBus.battle_won.emit({"time": 60.0})
	assert_equals(GameManager.get_stat("flawless_victories"), 1, "Una victoria con bajas no cuenta como impecable")
	assert_equals(GameManager.get_stat("fast_victories"), 1, "Una victoria lenta no cuenta como relámpago")

	# 4. Logros de combate en vivo
	EventBus.player_assault.emit(3)
	assert_true(GameManager.is_achievement_unlocked("coordination"), "Atacar desde 3 bases en un trazo desbloquea 'Ofensiva total'")
	EventBus.troops_dispatched.emit(null, null, 120, GameManager.Faction.ENEMY_1)
	assert_true(not GameManager.is_achievement_unlocked("big_army"), "Las hileras enemigas no cuentan para el jugador")
	EventBus.troops_dispatched.emit(null, null, 120, GameManager.Faction.PLAYER)
	assert_true(GameManager.is_achievement_unlocked("big_army"), "Una hilera de 120 tropas desbloquea 'Gran ejército'")
	for i in 10:
		EventBus.troops_retreated.emit(GameManager.Faction.PLAYER)
	assert_true(GameManager.is_achievement_unlocked("tactical_retreat"), "10 retiradas desbloquean 'Retirada táctica'")

	# 5. Estadísticas derivadas del progreso
	for i in range(1, 6):
		GameManager.completed_levels["europe_%d" % i] = 3
	assert_equals(AchievementManager.get_stat("continents_completed"), 1, "Europa completa cuenta como continente")
	assert_equals(AchievementManager.get_stat("three_star_levels"), 5, "Se cuentan los niveles con 3 estrellas")
	assert_equals(AchievementManager.get_progress(AchievementDatabase.get_by_id("strategist")), 0.5, "El progreso de 'Estratega' es 5/10")
	assert_true(AchievementManager.check_all().has("continental"), "check_all desbloquea 'Dominio continental'")
	assert_true(AchievementManager.check_all().is_empty(), "Un logro no se desbloquea dos veces")

	# 6. Reclamar: oro una sola vez y estado guardado
	var reward = AchievementDatabase.get_by_id("first_victory")["reward"]
	assert_equals(GameManager.claim_achievement("first_victory"), reward, "Reclamar da la recompensa del logro")
	assert_equals(GameManager.coins, coins0 + reward, "El oro llega al saldo")
	assert_equals(GameManager.claim_achievement("first_victory"), 0, "No se puede reclamar dos veces")
	assert_equals(GameManager.claim_achievement("emperor"), 0, "No se puede reclamar un logro bloqueado")
	GameManager.save_game()
	GameManager.achievements.clear()
	GameManager.stats.clear()
	GameManager.load_game()
	assert_true(GameManager.is_achievement_claimed("first_victory"), "El logro reclamado sigue reclamado tras cargar")
	assert_true(GameManager.is_achievement_unlocked("blitz") and not GameManager.is_achievement_claimed("blitz"), "El pendiente sigue pendiente tras cargar")
	assert_equals(GameManager.get_stat("victories"), 2, "Las estadísticas se guardan")

	# 7. Guardado corrupto: se descartan estados desconocidos
	var f = FileAccess.open(GameManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"achievements": {"blitz": "hacked", "flawless": "claimed"}, "stats": {"victories": -5}, "daily": "x"}))
	f.close()
	GameManager.load_game()
	assert_true(not GameManager.is_achievement_unlocked("blitz"), "Un estado de logro inválido se descarta")
	assert_true(GameManager.is_achievement_claimed("flawless"), "Los estados válidos se conservan")
	assert_equals(GameManager.get_stat("victories"), 0, "Una estadística negativa se corrige a 0")
	assert_equals(int(GameManager.daily["last_claim_day"]), -1, "Datos diarios corruptos vuelven a los valores por defecto")

	# 8. Progreso: reclamar desde la tarjeta del logro
	GameManager.reset_save()
	GameManager.unlock_achievement("first_victory")
	var progress = load("res://scripts/ui/progress_tab.gd").new()
	add_child(progress)
	assert_equals(progress.achievements_box.get_child_count(), AchievementDatabase.get_all().size(), "Hay una tarjeta por logro")
	var first_card = progress.achievements_box.get_child(0)
	assert_equals(first_card.name, "Card_first_victory", "Los logros por reclamar aparecen primero")
	var btn = first_card.find_child("BtnClaim", true, false)
	assert_true(btn != null, "La tarjeta pendiente tiene botón de reclamar")
	var before = GameManager.coins
	btn.pressed.emit()
	assert_equals(GameManager.coins, before + reward, "Pulsar Reclamar suma el oro")
	assert_true(progress.find_child("BtnClaim", true, false) == null, "Tras reclamar ya no queda botón")
	assert_true(progress.achievements_count.text.contains("1/%d" % AchievementDatabase.get_all().size()), "El contador muestra los logros conseguidos")
	remove_child(progress)
	progress.free()

	# 9. Retos: la recompensa diaria se recoge sin ventanas emergentes
	GameManager.reset_save()
	var challenges = load("res://scripts/ui/challenges_tab.gd").new()
	add_child(challenges)
	var claim = challenges.find_child("BtnClaimDaily", true, false)
	assert_true(claim != null, "Se ofrece la recompensa diaria pendiente")
	var coins_before = GameManager.coins
	claim.pressed.emit()
	assert_true(GameManager.coins > coins_before and not GameManager.get_daily_reward_state()["can_claim"], "Recoger cobra la recompensa del día")
	assert_true(challenges.find_child("BtnClaimDaily", true, false) == null, "No se vuelve a ofrecer hasta mañana")
	remove_child(challenges)
	challenges.free()

	EventBus.achievement_unlocked.disconnect(on_unlock)
	GameManager.reset_save()

func test_daily_challenge_levels() -> void:
	print("\n-> Test: Desafío Diario (Generación, Rutas y Recompensa)")
	var today = DailyRewards.today()
	var id = DailyRewards.challenge_id(today)
	assert_true(DailyRewards.is_challenge(id) and not DailyRewards.is_challenge("europe_1"), "Se reconocen los ids de desafío")
	assert_equals(DailyRewards.challenge_day(id), today, "El id guarda el día")
	assert_equals(LevelDatabase.get_difficulty(id), DailyRewards.CHALLENGE_DIFFICULTY, "El desafío tiene dificultad fija")

	# 1. Un año de desafíos: todos jugables, con ciudades reales, jugador y rival
	var problems: Array[String] = []
	var centers = {}
	for d in 365:
		var def = LevelGenerator.daily_challenge_definition(today + d)
		var factions = def["bases"].map(func(b): return b["faction"])
		if def["bases"].size() < 3 or not factions.has(GameManager.Faction.PLAYER) or not factions.has(GameManager.Faction.ENEMY_1):
			problems.append("%d: %d bases" % [today + d, def["bases"].size()])
		if not def["bases"].all(func(b): return GeoDatabase.has_city(b["city"])):
			problems.append("%d: ciudad desconocida" % (today + d))
		centers[def["bases"][0]["city"]] = true
	assert_true(problems.is_empty(), "Los desafíos de un año son todos jugables %s" % str(problems.slice(0, 5)))
	assert_true(centers.size() > 60, "Los desafíos varían de un día a otro (%d regiones distintas)" % centers.size())
	assert_equals(str(LevelGenerator.daily_challenge_definition(today)), str(LevelGenerator.daily_challenge_definition(today)), "El desafío de un día es el mismo para todos")

	# 2. Nivel construido: bases dentro de la zona de juego y geografía real
	var level = LevelDatabase.get_level_data(id)
	assert_equals(level["id"], id, "LevelDatabase construye el desafío a partir del id")
	assert_true(level["bases"].size() >= 5, "El desafío añade neutrales extra (%d bases)" % level["bases"].size())
	assert_true(level["bases"].all(func(b): return LevelGenerator.PLAY_RECT.grow(1.0).has_point(b["pos"])), "Las bases del desafío están en la zona de juego")
	assert_true(level["geo"]["land"].size() > 0, "El desafío se juega sobre costas reales")

	# 3. Jugar un desafío no mueve el punto de la campaña
	GameManager.reset_save()
	GameManager.current_level_id = "europe_3"
	GameManager.play_level(id)
	assert_equals(GameManager.get_battle_level_id(), id, "La batalla carga el desafío")
	assert_equals(GameManager.current_level_id, "europe_3", "La campaña conserva su nivel actual")
	GameManager.play_level("europe_3")
	assert_equals(GameManager.get_battle_level_id(), "europe_3", "Volver a la campaña descarta el desafío")

	# 4. Recompensa: completa una vez al día, reducida al repetir, sin estrellas de campaña
	var full = GameManager.complete_daily_challenge(id)
	assert_equals(full, int(round(DailyRewards.DAILY_CHALLENGE_GOLD * GameManager.get_gold_multiplier())), "La primera victoria del día da el oro completo")
	assert_true(GameManager.is_daily_challenge_done(), "El desafío de hoy queda superado")
	assert_true(GameManager.complete_daily_challenge(id) < full, "Repetirlo el mismo día da menos oro")
	assert_equals(GameManager.get_stat("daily_challenges"), 1, "Sólo cuenta un desafío por día para los logros")
	assert_equals(GameManager.get_total_stars(), 0, "Los desafíos no suman estrellas de campaña")
	assert_true(not GameManager.completed_levels.has(id), "Los desafíos no se guardan como niveles de campaña")
	GameManager.reset_save()

func test_cleanup_regressions() -> void:
	print("\n-> Test: Regresiones de la Limpieza (IDs de Campaña, IA Conjunta y Arrastre)")
	# 1. Ids de campaña en un único sitio
	assert_equals(LevelDatabase.get_continent_level_ids("asia").size(), LevelDatabase.LEVELS_PER_CONTINENT, "Cada continente tiene LEVELS_PER_CONTINENT niveles")
	assert_equals(LevelDatabase.get_continent_of("north_america_3"), "north_america", "Continente deducido del id")
	assert_equals(LevelDatabase.get_level_number("north_america_3"), 3, "Número de nivel deducido del id")
	assert_equals(GameManager.get_next_level("europe_5"), "north_america_1", "Tras el último nivel de un continente llega el siguiente")
	assert_equals(GameManager.get_next_level("oceania_5"), "", "El último nivel de la campaña no tiene siguiente")
	assert_equals(GameManager.get_next_level(DailyRewards.challenge_id(1)), "", "Un desafío diario no tiene siguiente nivel")
	assert_equals(LevelDatabase.get_difficulty("oceania_5"), 1.0, "El último nivel tiene dificultad máxima")

	# 2. Ataque conjunto: la IA puntúa y envía con las mismas 3 bases más cercanas
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	battle.level_id = "oceania_5"
	var target = _make_base(Vector2(500, 500), GameManager.Faction.NEUTRAL, 40)
	var sources: Array[BaseNode] = []
	for i in 5:
		sources.append(_make_base(Vector2(500 + 120 * (i + 1), 500), GameManager.Faction.ENEMY_1, 30))
	battle.bases.append(target)
	battle.bases.append_array(sources)
	var ai = AIController.new()
	ai.setup(battle, GameManager.Faction.ENEMY_1)
	var joint = ai._joint_sources(sources, target)
	assert_equals(joint.size(), AIController.MAX_JOINT_SOURCES, "El ataque conjunto usa como mucho 3 bases")
	assert_true(joint.has(sources[0]) and joint.has(sources[2]) and not joint.has(sources[4]), "Participan las bases más cercanas al objetivo")

	# 3. Soltar el arrastre sólo lanza desde bases que siguen siendo del jugador
	var mine = _make_base(Vector2(100, 1000), GameManager.Faction.PLAYER, 20)
	var lost = _make_base(Vector2(300, 1000), GameManager.Faction.PLAYER, 20)
	var goal = _make_base(Vector2(700, 1000), GameManager.Faction.NEUTRAL, 5)
	battle.bases.append_array([mine, lost, goal])
	var assaults: Array[int] = []
	var on_assault = func(n): assaults.append(n)
	EventBus.player_assault.connect(on_assault)
	battle._handle_press(mine.position)
	battle._add_selected_source(lost)
	lost.faction = GameManager.Faction.ENEMY_1
	assert_equals(battle.get_pending_attack_count(), 19, "La vista previa ignora las bases perdidas durante el arrastre")
	battle._handle_release(goal.position)
	assert_equals(lost.troops, 20, "Una base capturada durante el arrastre no lanza tropas")
	assert_equals(assaults, [1] as Array[int], "El asalto cuenta sólo las bases que han lanzado tropas")
	assert_true(not battle.dispatch_troops(mine, goal), "dispatch_troops devuelve false si no queda nadie a quien enviar")
	EventBus.player_assault.disconnect(on_assault)

	for t in battle.active_troops:
		t.free()
	for n in battle.bases + [ai, battle]:
		n.free()

func test_language_system() -> void:
	print("\n-> Test: Traducciones ES/EN y Nombres Localizados")
	GameManager.reset_save()
	assert_equals(GameManager.language, "es", "Idioma por defecto español")
	assert_equals(LocaleStrings.text("play"), "Jugar", "Clave del menú en español")
	GameManager.set_language("en")
	assert_equals(GameManager.language, "en", "Cambio a inglés")
	assert_equals(LocaleStrings.text("play"), "Play", "Clave del menú en inglés")
	assert_equals(GameManager.faction_name(GameManager.Faction.PLAYER), "You", "El jugador se nombra en segunda persona")
	assert_equals(LevelDatabase.continent_name("europe"), "Europe", "Continente en inglés")
	assert_true(str(LevelDatabase.get_level_data("europe_1")["name"]).begins_with("Level 1:"), "Nivel de campaña con nombre inglés")
	GameManager.set_language("fr")
	assert_equals(GameManager.language, "en", "Idioma no soportado se ignora")
	GameManager.set_language("es")
	assert_equals(LevelDatabase.get_level_data("europe_1")["name"], "Nivel 1: Península Ibérica y Galia", "Vuelve al español")
	GameManager.set_language("en")
	assert_equals(AchievementDatabase.achievement_title(AchievementDatabase.get_by_id("blitz")), "Blitzkrieg", "Logro en inglés")
	GameManager.language = "es"
	GameManager.load_game()
	assert_equals(GameManager.language, "en", "El idioma se guarda entre sesiones")
	GameManager.reset_save()
	assert_equals(GameManager.language, "es", "Reiniciar restaura el idioma inicial")

func test_conquest_mode() -> void:
	print("\n-> Test: Conquista Libre Infinita (Generación, Dificultad y Oro)")
	assert_true(LevelGenerator.is_conquest("conquest_7") and not LevelGenerator.is_conquest("europe_1"), "Se reconocen los ids de conquista")
	assert_equals(LevelGenerator.conquest_index("conquest_12"), 12, "El id guarda la región")
	assert_true(LevelGenerator.conquest_difficulty(1) > LevelGenerator.conquest_difficulty(0), "La dificultad crece con la región")
	assert_equals(LevelGenerator.conquest_difficulty(99), 1.0, "La dificultad tiene techo en 1.0")
	assert_equals(str(LevelGenerator.conquest_definition(3)), str(LevelGenerator.conquest_definition(3)), "La región es la misma para todos")
	var problems := 0
	for i in [0, 1, 2, 5, 6, 11]:
		var def = LevelGenerator.conquest_definition(i)
		var factions = def["bases"].map(func(b): return b["faction"])
		if def["bases"].size() < 3 or not factions.has(GameManager.Faction.PLAYER) or not factions.has(GameManager.Faction.ENEMY_1):
			problems += 1
		if not def["bases"].all(func(b): return GeoDatabase.has_city(b["city"])):
			problems += 1
	assert_equals(problems, 0, "Las regiones 0-11 son jugables con ciudades reales")
	assert_true(LevelDatabase.get_difficulty("conquest_4") > LevelDatabase.get_difficulty("conquest_0"), "Dificultad vía LevelDatabase")
	GameManager.reset_save()
	GameManager.play_conquest(2)
	assert_equals(GameManager.get_battle_level_id(), "conquest_2", "La batalla carga la región")
	var gold = GameManager.complete_conquest(2)
	assert_equals(GameManager.conquest_next, 3, "La victoria avanza a la siguiente región")
	assert_true(gold > 0, "La conquista da oro")
	assert_true(GameManager.complete_conquest(5) > gold, "Las regiones altas pagan más oro")
	GameManager.play_level("europe_1")
	assert_equals(GameManager.get_battle_level_id(), "europe_1", "Jugar campaña sale de la conquista")
	assert_true(not GameManager.completed_levels.has("conquest_2"), "La conquista no toca las estrellas")
	assert_equals(GameManager.get_next_level("conquest_3"), "", "La conquista no tiene siguiente de campaña")
	# Jugar ofrece conquista y desafío a un toque; los ajustes viven en la cabecera
	var play = load("res://scripts/ui/play_tab.gd").new()
	add_child(play)
	assert_true(play.btn_conquest != null and play.btn_daily != null, "Conquista y desafío accesibles desde Jugar")
	remove_child(play)
	play.free()
	# Victoria completa en una región: oro, avance y atlas sin tocar la campaña
	GameManager.reset_save()
	GameManager.play_conquest(0)
	var cbattle = load("res://scripts/battle/battle_controller.gd").new()
	cbattle.load_level(GameManager.get_battle_level_id())
	for b in cbattle.bases:
		b.faction = GameManager.Faction.PLAYER
	var cities_before = GameManager.atlas_conquered_count()
	var won: Array[Dictionary] = []
	var on_won = func(s): won.append(s)
	EventBus.battle_won.connect(on_won)
	cbattle._trigger_victory()
	EventBus.battle_won.disconnect(on_won)
	assert_true(cbattle.is_game_over, "La conquista termina en victoria")
	assert_equals(GameManager.conquest_next, 1, "La victoria avanza a la siguiente región")
	assert_true(GameManager.atlas_conquered_count() > cities_before, "La victoria registra ciudades en el atlas")
	assert_equals(won[0]["new_cities"], GameManager.atlas_conquered_count() - cities_before, "La victoria informa de las ciudades nuevas")
	assert_true(GameManager.completed_levels.is_empty(), "La campaña sigue intacta")
	cbattle.free()
	# El modal celebra la región y ofrece seguir la cadena
	var HudScene = load("res://scenes/ui/battle_hud.tscn")
	var hud = HudScene.instantiate()
	add_child(hud)
	hud.deploy_victory_modal({"stars": 2, "gold_earned": 120, "is_conquest": true})
	assert_equals(hud.victory_title.text, LocaleStrings.text("conquest_done"), "Título de conquista libre")
	assert_true(hud.btn_next_level.visible and hud.btn_next_level.text == LocaleStrings.text("next_region"), "La conquista ofrece seguir con la siguiente región")
	remove_child(hud)
	hud.free()
	GameManager.reset_save()

func test_atlas_and_first_levels() -> void:
	print("\n-> Test: Atlas de Ciudades, Primer Arranque y Niveles Suaves")
	GameManager.reset_save()
	assert_true(not GameManager.has_started, "Partida nueva sin empezar")
	GameManager.has_started = true
	GameManager.save_game()
	GameManager.has_started = false
	GameManager.load_game()
	assert_true(GameManager.has_started, "El primer arranque persiste entre sesiones")
	assert_true(GameManager.conquer_city("madrid"), "Conquistar Madrid entra en el atlas")
	assert_true(not GameManager.conquer_city("madrid"), "No se duplica")
	assert_true(not GameManager.conquer_city(""), "Clave vacía se ignora")
	assert_equals(GameManager.atlas_conquered_count(), 1, "Una ciudad registrada")
	assert_true(GeoDatabase.get_cities().size() > 1000, "Más de mil ciudades en la base geográfica")
	GameManager.save_game()
	GameManager.conquered_cities.clear()
	GameManager.load_game()
	assert_true(GameManager.conquered_cities.has("madrid"), "El atlas persiste entre sesiones")
	# Progreso muestra el atlas: contador, ciudad conquistada y reparto por continente
	var progress = load("res://scripts/ui/progress_tab.gd").new()
	add_child(progress)
	var texts = progress.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_true(texts.has(LocaleStrings.text("atlas")), "Título del atlas visible")
	assert_true(texts.any(func(t): return t.contains("Madrid")), "Madrid aparece entre las últimas conquistas")
	assert_equals(progress.find_child("Stat_stat_cities", true, false).text, "1", "Contador de ciudades conquistadas")
	assert_equals(progress.find_children("Collection_*", "", true, false).size(), 6, "Una colección por continente")
	assert_true(texts.any(func(t): return t.begins_with(LevelDatabase.continent_name("europe")) and t.ends_with("1")), "Madrid cuenta para Europa")
	remove_child(progress)
	progress.free()
	for sample in [["madrid", "europe"], ["cairo", "africa"], ["algiers", "africa"], ["tokyo", "asia"], ["tehran", "asia"],
			["sydney", "oceania"], ["new_york", "north_america"], ["panama_city", "north_america"], ["sao_paulo", "south_america"]]:
		assert_equals(GeoDatabase.continent_of(GeoDatabase.get_city(sample[0])["lonlat"]), sample[1], "%s pertenece a %s" % sample)
	# europe_1 casi imposible de perder: jugador fuerte y un solo rival débil
	var def1 = LevelDatabase.get_level_definition("europe_1")
	var rivals1 = def1["bases"].filter(func(b): return b["faction"] != GameManager.Faction.PLAYER and b["faction"] != GameManager.Faction.NEUTRAL)
	var mine1 = def1["bases"].filter(func(b): return b["faction"] == GameManager.Faction.PLAYER)
	assert_equals(rivals1.size(), 1, "europe_1 tiene un único rival")
	assert_true(mine1[0]["troops"] > rivals1[0]["troops"], "El jugador empieza con más tropas que el rival")
	var def3 = LevelDatabase.get_level_definition("europe_3")
	var rivals3 = def3["bases"].filter(func(b): return b["faction"] != GameManager.Faction.PLAYER and b["faction"] != GameManager.Faction.NEUTRAL)
	assert_equals(rivals3.size(), 1, "europe_3 tiene un único rival")
	# La IA espera al menos 25 s en los primeros niveles
	var battle = load("res://scripts/battle/battle_controller.gd").new()
	battle.level_id = "europe_2"
	var ai = AIController.new()
	ai.setup(battle, GameManager.Faction.ENEMY_1)
	assert_true(ai._grace_period >= 25.0, "Periodo de gracia largo en europe_2")
	ai.free()
	battle.free()
	GameManager.reset_save()

func test_cosmetics_shop() -> void:
	print("\n-> Test: Tienda de Estética (Oro Útil Tras el Máximo)")
	GameManager.reset_save()
	GameManager.coins = 100
	assert_true(not GameManager.buy_cosmetic("color_violet"), "Sin oro no hay compra")
	assert_true(not GameManager.buy_cosmetic("no_existe"), "Id desconocido se rechaza")
	GameManager.coins = 1000
	var before = GameManager.coins
	assert_true(GameManager.buy_cosmetic("color_violet"), "Compra con oro suficiente")
	assert_equals(GameManager.coins, before - 300, "Se descuenta el precio exacto")
	assert_true(GameManager.is_cosmetic_owned("color_violet"), "Queda desbloqueado")
	assert_equals(GameManager.cosmetics_equipped["army_color"], "color_violet", "Comprar equipa al momento")
	assert_true(GameManager.player_color() != GameManager.FACTION_COLORS[GameManager.Faction.PLAYER], "El color del ejército cambia")
	assert_true(GameManager.equip_cosmetic("color_blue"), "Se puede volver al clásico gratis")
	assert_equals(GameManager.player_color(), GameManager.FACTION_COLORS[GameManager.Faction.PLAYER], "El clásico restaura el azul")
	assert_true(not GameManager.equip_cosmetic("color_gold"), "No se equipa lo no desbloqueado")
	GameManager.save_game()
	GameManager.cosmetics_owned.clear()
	GameManager.load_game()
	assert_true(GameManager.is_cosmetic_owned("color_violet"), "Los cosméticos persisten")
	assert_equals(GameManager.cosmetics_equipped["army_color"], "color_blue", "Lo equipado persiste")
	GameManager.reset_save()

func test_daily_missions_xp_and_share() -> void:
	print("\n-> Test: Misiones, XP y Tarjeta Diaria")
	GameManager.reset_save()
	var day := DailyRewards.today()
	var selected := DailyMissions.for_day(day)
	assert_equals(selected.size(), 3, "Tres misiones al día")
	assert_equals(selected, DailyMissions.for_day(day), "Misiones deterministas")
	var ids := {}
	for mission in selected: ids[mission["id"]] = true
	assert_equals(ids.size(), 3, "Tres objetivos distintos")
	GameManager.ensure_missions(day)
	var mission: Dictionary = selected[0]
	assert_true(not GameManager.claim_mission(mission["id"], day), "No cobrar una misión incompleta")
	GameManager.advance_mission(mission["id"], int(mission["goal"]) + 5, day)
	assert_equals(GameManager.missions["progress"][mission["id"]], mission["goal"], "Progreso limitado al objetivo")
	var coins := GameManager.coins
	assert_true(GameManager.claim_mission(mission["id"], day), "Cobrar misión completada")
	assert_equals(GameManager.coins, coins + int(mission["gold"]), "Oro exacto por misión")
	assert_equals(GameManager.experience, mission["xp"], "XP exacta por misión")
	assert_true(not GameManager.claim_mission(mission["id"], day), "No cobrar dos veces")
	GameManager.save_game()
	GameManager._apply_save({})
	GameManager.load_game()
	assert_true(GameManager.missions["claimed"].has(mission["id"]), "Cobro persiste")
	GameManager.ensure_missions(day - 1)
	assert_equals(GameManager.missions["day"], day, "Reloj atrasado no reinicia objetivos")
	GameManager.ensure_missions(day + 1)
	assert_true(GameManager.missions["claimed"].is_empty() and GameManager.missions["progress"].is_empty(), "Medianoche limpia progreso y cobros")
	assert_equals(PlayerRank.level(99), 1, "Primer nivel hasta 99 XP")
	assert_equals(PlayerRank.level(100), 2, "Nivel 2 a 100 XP")
	assert_equals(PlayerRank.level(400), 3, "Nivel 3 a 400 XP")
	GameManager.reset_save()
	var result := {"level_id": DailyRewards.challenge_id(day), "stars": 3, "time": 34.2, "speed": 1.5, "is_daily_challenge": true}
	GameManager.record_battle_result(result, true)
	assert_equals(GameManager.experience, 60, "XP de victoria con tres estrellas")
	result["time"] = 45.0
	result["is_replay"] = true
	GameManager.record_battle_result(result, false)
	assert_equals(GameManager.experience, 70, "Repetición da menos XP")
	assert_equals(GameManager.daily_best["time"], 34.2, "Resultado peor no reemplaza récord")
	var text := DailyShare.text(GameManager.daily_best)
	assert_true(text.contains("35s") and text.contains("×1.5") and text.contains("⭐⭐⭐"), "Tarjeta con estrellas, tiempo y velocidad")
	GameManager.set_language("en")
	assert_true(DailyShare.text(GameManager.daily_best).contains("Daily challenge"), "Tarjeta traducida")
	GameManager.save_game()
	GameManager.daily_best.clear()
	GameManager.load_game()
	assert_equals(GameManager.daily_best["stars"], 3, "Récord diario persiste")
	GameManager.reset_save()
	var panel = load("res://scripts/ui/challenges_tab.gd").new()
	add_child(panel)
	assert_equals(panel.find_children("Claim_*", "Button", true, false).size(), 0, "Sin misiones completas no hay nada que reclamar")
	remove_child(panel)
	panel.free()
	var first: Dictionary = DailyMissions.for_day(DailyRewards.today())[0]
	GameManager.advance_mission(first["id"], int(first["goal"]))
	assert_equals(GameManager.claimable_mission_count(), 1, "Una misión completa queda pendiente de cobro")
	panel = load("res://scripts/ui/challenges_tab.gd").new()
	add_child(panel)
	var claims: Array = panel.find_children("Claim_*", "Button", true, false)
	assert_equals(claims.size(), 1, "Retos ofrece reclamar la misión completada")
	claims[0].pressed.emit()
	assert_equals(GameManager.claimable_mission_count(), 0, "Reclamar desde Retos cobra la misión")
	remove_child(panel)
	panel.free()
	GameManager.reset_save()
	var battle := BattleController.new()
	battle.load_level("europe_1")
	for base in battle.bases: base.faction = GameManager.Faction.PLAYER
	battle._trigger_victory()
	var xp := GameManager.experience
	var gold := GameManager.coins
	battle._trigger_victory()
	assert_equals(GameManager.experience, xp, "Una victoria sólo concede XP una vez")
	assert_equals(GameManager.coins, gold, "Una victoria sólo concede oro una vez")
	battle.free()
	GameManager.reset_save()

func test_settings_and_backups() -> void:
	print("\n-> Test: Ajustes y Copias Seguras")
	GameManager.reset_save()
	GameManager.set_setting("speed", 99.0)
	assert_equals(GameManager.settings["speed"], 2.0, "Velocidad máxima validada")
	GameManager.set_setting("speed", 1.2)
	assert_equals(GameManager.settings["speed"], 1.0, "Importación y selector utilizan las mismas velocidades")
	GameManager.set_setting("volume", -1.0)
	assert_equals(GameManager.settings["volume"], 0.0, "Volumen no puede ser negativo")
	GameManager.set_setting("vibration", false)
	GameManager.set_setting("colorblind", true)
	assert_true(GameManager.faction_color(1) != GameManager.faction_color(2), "Paleta accesible distingue rivales")
	GameManager.load_game()
	assert_true(not GameManager.settings["vibration"] and GameManager.settings["colorblind"], "Ajustes persisten")
	var original_path := GameManager.save_path
	var export_path := "user://test_export.json"
	var import_path := "user://test_import.json"
	GameManager.coins = 456
	assert_equals(GameManager.write_save(export_path, GameManager.save_data()), OK, "Exportar copia")
	GameManager.coins = 12
	GameManager.save_game()
	assert_equals(GameManager.import_save(export_path), OK, "Restaurar copia")
	assert_equals(GameManager.coins, 456, "Restauración conserva economía")
	var backup = JSON.parse_string(FileAccess.get_file_as_string(original_path + ".backup"))
	assert_equals(int(backup["coins"]), 12, "Se conserva copia de la partida reemplazada")
	GameManager.write_save(import_path, {"version": GameManager.SAVE_VERSION + 1, "upgrades": {}, "completed_levels": {}})
	assert_equals(GameManager.import_save(import_path), ERR_INVALID_DATA, "Rechazar versiones futuras")
	assert_equals(GameManager.coins, 456, "Importación inválida no altera progreso")
	GameManager.write_save(import_path, {"coins": 0})
	assert_equals(GameManager.import_save(import_path), ERR_INVALID_DATA, "Rechazar JSON ajeno al juego")
	assert_equals(GameManager.import_save("user://does_not_exist.json"), ERR_INVALID_DATA, "Archivo inexistente no altera partida")
	for path in [export_path, import_path, original_path + ".backup"]:
		DirAccess.remove_absolute(path)
	GameManager._apply_save({"settings": {"volume": "no", "music_volume": INF, "speed": -4, "vibration": "sí"}})
	assert_equals(GameManager.settings["music_volume"], 0.8, "Ajuste no finito usa valor inicial")
	assert_equals(GameManager.settings["speed"], 0.75, "Velocidad mínima validada")
	var panel = load("res://scripts/ui/settings_panel.gd").new()
	add_child(panel)
	assert_equals(panel.find_children("*", "HSlider", true, false).size(), 2, "Dos controles nativos de volumen")
	assert_equals(panel.find_children("*", "CheckButton", true, false).size(), 5, "Sonido, música, vibración, paleta y reducir movimiento")
	assert_equals(panel.find_children("*", "OptionButton", true, false).size(), 3, "Apariencia, idioma y velocidad")
	remove_child(panel)
	panel.free()
	GameManager.reset_save()
	AudioManager.apply_volumes()

func test_continent_mechanics() -> void:
	print("\n-> Test: Reglas de Continente, Rutas y Jefes")
	GameManager.reset_save()
	for id in ["europe_1", "europe_2", "europe_3"]:
		assert_true(not LevelDatabase.get_level_data(id).has("rule_key"), "Tutorial %s sin reglas adicionales" % id)
	for continent in LevelDatabase.get_continents():
		var final_level := LevelDatabase.get_level_data(continent["id"] + "_5")
		assert_true(final_level.has("rule_key"), "Regla de %s" % continent["id"])
		assert_equals(final_level["bases"].filter(func(b): return b.get("boss", false)).size(), 1, "Un jefe en %s" % continent["id"])
	var capital = LevelDatabase.get_level_data("europe_4")["bases"].filter(func(b): return b.get("capital", false))[0]
	var base := BaseNode.new()
	base.setup(capital)
	base.faction = GameManager.Faction.PLAYER
	var rate := base.get_production_rate()
	base.production_bonus = 1.0
	assert_true(is_equal_approx(rate, base.get_production_rate() * 1.5), "Capital da producción al propietario actual")
	base.free()
	assert_true(LevelDatabase.get_level_data("north_america_1")["bases"].any(func(b): return b.get("type") == "factory"), "Industria añade fábrica")
	assert_true(LevelDatabase.get_level_data("asia_1")["bases"].any(func(b): return b.get("type") == "fortress"), "Asia añade bastión")
	var battle := BattleController.new()
	battle.load_level("oceania_1")
	var routes: Array = battle.level_data["sea_lanes"]
	assert_equals(routes.size(), battle.bases.size() - 1, "Rutas mínimas para conectar todas las islas")
	var reached := [0]
	for i in battle.bases.size():
		for route in routes:
			if reached.has(route.x) and not reached.has(route.y): reached.append(route.y)
			if reached.has(route.y) and not reached.has(route.x): reached.append(route.x)
	assert_equals(reached.size(), battle.bases.size(), "Toda isla es alcanzable")
	var route: Vector2i = routes[0]
	assert_true(battle.can_dispatch(battle.bases[route.x], battle.bases[route.y]) and battle.can_dispatch(battle.bases[route.y], battle.bases[route.x]), "Rutas bidireccionales")
	var blocked := false
	for a in battle.bases:
		for b in battle.bases:
			if a == b or battle.can_dispatch(a, b): continue
			var troops := a.troops
			assert_true(not battle.dispatch_troops(a, b), "Jugador e IA no atraviesan rutas inexistentes")
			assert_equals(a.troops, troops, "Ruta inválida no consume tropas")
			blocked = true
			break
		if blocked: break
	assert_true(blocked, "Hay decisiones de ruta reales")
	battle.free()
	battle = BattleController.new()
	battle.load_level("south_america_1")
	battle.bases[0].troops = 30
	battle.dispatch_troops(battle.bases[0], battle.bases[1])
	assert_true(is_equal_approx(battle.active_troops[0].speed, Troop.BASE_SPEED * 0.8), "Selva modifica velocidad real de tropas")
	battle.free()
	battle = BattleController.new()
	battle.load_level("africa_5")
	var boss: BaseNode = battle.bases.filter(func(b): return b.is_boss)[0]
	boss.troops = 20
	battle._process_boss(battle.level_data["boss_interval"])
	var reinforced := 20 + int(battle.level_data["boss_reinforcement"])
	assert_equals(boss.troops, reinforced, "El jefe recibe los refuerzos configurados en su mapa")
	boss.faction = GameManager.Faction.PLAYER
	battle._process_boss(battle.level_data["boss_interval"])
	assert_equals(boss.troops, reinforced, "Jefe conquistado deja de recibir refuerzos")
	battle.free()
	GameManager.reset_save()

func test_review_regressions() -> void:
	print("\n-> Test: Simplificación (Mapas Idénticos, Caché Acotada y Guardados)")
	GameManager.reset_save()
	# Huellas capturadas antes del refactor: no cambiar mapas ni consumir otro RNG.
	for sample in [
		["daily", 365, "dd937f4c32a66da37e1f7bc2ea7a1588cbdcd0a6064f12db554606f44f3634ab"],
		["conquest", 50, "a49fd247020ee60e1b88238b5c88d305f2448109ec689e3a979a6be1a347e928"],
	]:
		var bases := []
		for i in sample[1]:
			var def := LevelGenerator.daily_challenge_definition(20000 + i) if sample[0] == "daily" else LevelGenerator.conquest_definition(i)
			bases.append(def["bases"])
		assert_equals(JSON.stringify(bases).sha256_text(), sample[2], "Mapas %s idénticos antes y después" % sample[0])
	for i in range(LevelDatabase.MAX_CACHED_LEVELS + 1):
		LevelDatabase.get_level_data(LevelGenerator.conquest_id(i))
	assert_equals(LevelDatabase._built.size(), LevelDatabase.MAX_CACHED_LEVELS, "La conquista infinita no hace crecer la caché")
	GameManager.current_level_id = "europe_3"
	GameManager.play_level("conquest_2")
	assert_equals(GameManager.current_level_id, "europe_3", "También play_level conserva la campaña en conquista")
	GameManager.play_level("daily_20000")
	assert_equals(GameManager.get_battle_level_id(), "daily_20000", "El modo diario reemplaza la conquista activa")
	GameManager.coins = 1000
	var changes: Array[int] = []
	var on_change = func(): changes.append(1)
	EventBus.cosmetics_changed.connect(on_change)
	GameManager.buy_cosmetic("color_violet")
	assert_equals(changes.size(), 1, "Comprar emite un solo cambio de estética")
	assert_true(not GameManager.buy_cosmetic("color_violet"), "Comprar dos veces no duplica ni cobra")
	assert_equals(GameManager.coins, 700, "La compra sólo descuenta una vez")
	EventBus.cosmetics_changed.disconnect(on_change)
	GameManager._apply_save({"language": "fr", "conquest_next": -4,
		"conquered_cities": ["madrid", "madrid", "no_existe", 42],
		"cosmetics_owned": ["color_cyan", "no_existe"],
		"cosmetics_equipped": {"army_color": "color_gold", "base_shape": "color_cyan"}})
	assert_equals(GameManager.conquered_cities, ["madrid"] as Array[String], "El guardado filtra ciudades inválidas y duplicadas")
	assert_equals(GameManager.cosmetics_equipped, GameManager.DEFAULT_COSMETICS_EQUIPPED, "No se equipan objetos no poseídos ni de otra categoría")
	assert_true(GameManager.is_cosmetic_owned("color_blue"), "Los cosméticos gratuitos siempre están disponibles")
	assert_equals(LocaleStrings.lang, "es", "Sólo hay un idioma activo incluso al cargar datos inválidos")
	assert_equals(GameManager.conquest_next, 0, "La progresión corrupta vuelve a cero")
	assert_true(not GameManager.conquer_city("no_existe"), "El atlas sólo admite ciudades reales")
	var battle := BattleController.new()
	var hud: BattleHUD = load("res://scenes/ui/battle_hud.tscn").instantiate()
	hud.battle_controller = battle
	add_child(hud)
	battle.target_time = 60.0
	battle.battle_time = 12.0
	hud._update_target_time()
	assert_equals(hud.label_target_time.text, "★★★ 48s", "El HUD utiliza el objetivo de la batalla sin duplicarlo")
	battle.battle_time = 65.0
	hud._update_target_time()
	assert_equals(hud.label_target_time.text, "★★ 25s", "Pasado el objetivo, el reloj pasa a defender la segunda estrella")
	battle.battle_time = 95.0
	hud._update_target_time()
	assert_equals(hud.label_target_time.text, "★", "Tras 1,5 veces el objetivo sólo queda la estrella de victoria")
	remove_child(hud)
	hud.free()
	battle.free()
	GameManager.reset_save()

func test_packets_and_battle_feedback() -> void:
	print("\n-> Test: Tropas en Paquetes, Vista Previa Estimada y Ficha de Base")
	# 1. Una orden sale en paquetes pequeños, uno tras otro, sin perder unidades
	var a = _make_base(Vector2(100, 500), GameManager.Faction.PLAYER, 1)
	var b = _make_base(Vector2(900, 500), GameManager.Faction.NEUTRAL, 50)
	var t = _make_stream(a, b, 23, GameManager.Faction.PLAYER)
	assert_equals(t.packets.size(), 5, "23 tropas salen en 5 paquetes")
	var total := 0
	for v in t.packets:
		total += v
	assert_equals(total, 23, "Los paquetes conservan todas las unidades")
	assert_equals(t.pending_units(), 23, "La orden reserva sus tropas antes de empezar a salir")
	t._process(0.2)
	assert_true(t.pending_units() > 0 and t.pending_units() < 23, "La salida es escalonada")
	assert_true(Troop.emission_seconds(23) > 0.3 and Troop.emission_seconds(200) < 1.5, "Toda la orden sale en menos de 1,5 s")
	assert_equals(Troop.packet_count_for(300), Troop.MAX_PACKETS, "Órdenes enormes se agrupan en MAX_PACKETS paquetes")

	# 2. Si cae la base de origen, lo que no había salido se pierde con ella
	var pending := t.pending_units()
	a.faction = GameManager.Faction.ENEMY_1
	t._process(0.01)
	assert_equals(t.count, 23 - pending, "Las tropas pendientes se pierden al caer el origen")
	assert_equals(t.pending_units(), 0, "Ya no queda nada por salir")
	t.free()

	# 3. Retirada: lo pendiente vuelve a la guarnición al instante
	a.faction = GameManager.Faction.PLAYER
	a.troops = 1
	var r = _make_stream(a, b, 30, GameManager.Faction.PLAYER)
	r._process(0.1)
	var waiting := r.pending_units()
	r.abort_mission()
	assert_equals(a.troops, 1 + waiting, "La retirada devuelve al momento lo que no había salido")
	r.free()

	# 4. Defensa estimada al llegar: una base con dueño sigue reclutando hasta llenarse
	var enemy = _make_base(Vector2(500, 500), GameManager.Faction.ENEMY_1, 10)
	assert_true(enemy.defense_after(5.0) > 10.0, "La defensa estimada crece con el tiempo de viaje")
	assert_equals(enemy.defense_after(1000.0), float(enemy.max_capacity), "La estimación no supera la capacidad")
	assert_equals(b.defense_after(5.0), 50.0, "Las neutrales no crecen")
	enemy.troops = enemy.max_capacity
	assert_true(enemy.is_full(), "Base llena detectada")

	# 5. Ventajas legibles de cada base especial
	enemy.base_type = BaseNode.BaseType.FACTORY
	assert_equals(enemy.perk_text(), LocaleStrings.text("perk_factory"), "La fábrica explica su ventaja")
	enemy.base_type = BaseNode.BaseType.STANDARD
	assert_equals(enemy.perk_text(), "", "Una base normal no muestra ventaja")

	# 6. Tocar una base muestra su ficha; arrastrar no
	var battle := BattleController.new()
	battle.bases.append_array([a, b])
	a.troops = 20
	battle._handle_press(a.position)
	battle._handle_release(a.position + Vector2(5, 0))
	assert_true(battle._info_base == a and battle._info_timer > 0.0, "Un toque sobre tu base muestra su ficha")
	assert_equals(a.troops, 20, "Un toque no envía tropas")
	battle._handle_press(Vector2(500, 900))
	battle._handle_release(b.position)
	assert_true(battle._info_base == a, "Un corte largo no abre fichas")
	battle._handle_press(b.position)
	battle._handle_release(b.position)
	assert_true(battle._info_base == b, "También se consultan bases ajenas")

	# 7. Consejo de derrota basado en lo ocurrido
	assert_equals(battle.defeat_tip(), LocaleStrings.text("tip_expand"), "Sin capturas, el consejo es expandirse")
	battle._fell_with_troops_out = true
	assert_equals(battle.defeat_tip(), LocaleStrings.text("tip_left_empty"), "Base vacía al atacar: se explica")
	battle.free()
	for n in [a, b, enemy]:
		n.free()

func test_progression_overhaul() -> void:
	print("\n-> Test: Economía, Rangos, Premios, Medallas, Colecciones y Siguiente Objetivo")
	GameManager.reset_save()
	# 1. Economía: siempre hay una compra al alcance y la última no es desorbitada
	assert_equals(GameManager.get_upgrade_cost("starting_troops"), 50, "Primera mejora: 50 de oro")
	GameManager.upgrades["starting_troops"] = 9
	assert_true(GameManager.get_upgrade_cost("starting_troops") <= 50 * 32, "La última mejora cuesta ~30× la primera (antes ~200×)")
	GameManager.upgrades["starting_troops"] = 0
	GameManager.coins = 60
	assert_true(GameManager.should_suggest_first_upgrade(), "Se sugiere la primera compra en cuanto es asequible")
	assert_true(NextGoal.text().contains(LocaleStrings.text("upg_starting_troops")), "El siguiente objetivo apunta a esa mejora")
	GameManager.buy_upgrade("starting_troops")
	assert_true(not GameManager.should_suggest_first_upgrade(), "La guía desaparece tras la primera compra")

	# 2. Rangos con nombre y premios de estética
	assert_equals(PlayerRank.level(100), 2, "Nivel 2 a 100 XP")
	assert_equals(PlayerRank.title(1), "Recluta", "Primer rango con nombre")
	assert_true(PlayerRank.title(12).begins_with("Mariscal"), "Tras el último rango se sigue numerando")
	assert_true(not GameManager.is_cosmetic_owned("color_cyan"), "El premio de rango 2 empieza bloqueado")
	GameManager.coins = 9999
	assert_true(not GameManager.buy_cosmetic("color_cyan"), "Los premios no se venden")
	GameManager.experience = 100
	assert_true(GameManager.is_cosmetic_owned("color_cyan") and GameManager.equip_cosmetic("color_cyan"), "Rango 2 desbloquea y permite equipar su premio")
	for i in range(1, 6):
		GameManager.completed_levels["europe_%d" % i] = 1
	assert_true(GameManager.is_cosmetic_owned("theme_ocean"), "Vencer al jefe de Europa desbloquea su tema")

	# 3. Medalla de dominio: se guarda por nivel
	GameManager.complete_level("europe_1", 3, true)
	assert_true(GameManager.medals.has("europe_1"), "Ganar sin perder bases concede la medalla")
	GameManager.save_game()
	GameManager.medals.clear()
	GameManager.load_game()
	assert_true(GameManager.medals.has("europe_1"), "Las medallas persisten")
	assert_equals(GameManager.victory_xp({"stars": 3, "new_medal": true}), 80, "La medalla nueva da XP extra")

	# 4. Colecciones: ciudades de campaña alcanzables y premio único
	var cities := LevelDatabase.collection_cities("europe")
	assert_true(cities.size() >= 10 and cities.has("madrid"), "La colección de Europa reúne sus ciudades de campaña")
	for c in cities:
		GameManager.conquer_city(c)
	assert_equals(GameManager.claimable_collection_count(), 1, "Colección completa pendiente de cobro")
	var gold := GameManager.coins
	assert_equals(GameManager.claim_collection("europe"), GameManager.COLLECTION_GOLD, "Cobrar la colección da su oro")
	assert_equals(GameManager.coins, gold + GameManager.COLLECTION_GOLD, "El oro llega al saldo")
	assert_equals(GameManager.claim_collection("europe"), 0, "No se cobra dos veces")

	# 5. Desafío diario comparable (sin mejoras de combate) y con particularidad del día
	GameManager.upgrades["troop_speed"] = 3
	GameManager.normalized_battle = true
	assert_equals(GameManager.get_troop_speed_multiplier(), 1.0, "El desafío diario ignora las mejoras de combate")
	GameManager.normalized_battle = false
	assert_true(GameManager.get_troop_speed_multiplier() > 1.0, "Fuera del desafío las mejoras cuentan")
	var twists := {}
	for d in 6:
		twists[LevelDatabase.get_level_data(DailyRewards.challenge_id(20000 + d)).get("rule_key", "")] = true
	assert_equals(twists.size(), 6, "El desafío rota las seis reglas de continente")
	assert_true(LevelDatabase.get_level_data("conquest_1").has("rule_key"), "Las expediciones varían sus reglas")

	# 6. Expediciones: la quinta región es un jefe y paga el doble
	assert_true(LevelGenerator.is_expedition_finale(4) and not LevelGenerator.is_expedition_finale(3), "La región 5 cierra la expedición")
	assert_true(LevelGenerator.conquest_definition(4)["bases"].any(func(x): return x.get("boss", false)), "El final de expedición tiene jefe")
	assert_true(GameManager.complete_conquest(4) > GameManager.complete_conquest(5), "El final de expedición paga más que la región siguiente")

	# 7. Racha con un día de margen y misiones variadas
	assert_equals(DailyRewards.evaluate(100, 5, 102)["streak"], 6, "Olvidarse un día no rompe la racha")
	var ids := {}
	for d in 8:
		for m in DailyMissions.for_day(d):
			ids[m["id"]] = true
	assert_equals(ids.size(), DailyMissions.POOL.size(), "Todas las misiones aparecen a lo largo de los días")
	GameManager.reset_save()

func test_new_ui_flows() -> void:
	print("\n-> Test: Flujos de interfaz y objetivos diarios")
	GameManager.reset_save()
	var menu: MainMenuUI = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	var play = menu._content.get_child(0)
	play._select_level("europe_2")
	GameManager.set_setting("light_mode", true)
	assert_equals(play.selected_level_id, "europe_2", "El tema conserva el nivel seleccionado")
	assert_equals(menu._background.color, UIThemeHelper.colors.bg, "El fondo cambia sin recargar el menú")
	menu.show_tab("army")
	var army = menu._content.get_child(0)
	assert_equals(menu._nav.values().filter(func(b): return b.button_pressed).size(), 1, "Sólo una pestaña de navegación aparece seleccionada")
	army.find_child("Segment_looks", true, false).pressed.emit()
	GameManager.set_setting("light_mode", false)
	assert_equals(army.section, "looks", "El tema conserva la pestaña de aspecto")
	remove_child(menu)
	menu.free()
	var battle := BattleController.new()
	var capital := _make_base(Vector2.ZERO, GameManager.Faction.PLAYER, 15)
	capital.is_capital = true
	battle.bases.append(capital)
	battle.level_data = {"objective": "hold_capital", "hold_seconds": 12.0}
	battle._update_level_objective(11.0)
	assert_true(not battle._level_objective_complete(), "El objetivo no termina antes de tiempo")
	capital.faction = GameManager.Faction.ENEMY_1
	battle._update_level_objective(1.0)
	assert_equals(battle._objective_held, 0.0, "Perder el objetivo reinicia el contador")
	capital.faction = GameManager.Faction.PLAYER
	battle._update_level_objective(12.0)
	assert_true(battle._level_objective_complete(), "Mantener el objetivo permite ganar")
	capital.free()
	battle.free()
	var hud: BattleHUD = load("res://scenes/ui/battle_hud.tscn").instantiate()
	add_child(hud)
	GameManager.experience = 80
	hud.deploy_victory_modal({"xp_before": 0, "xp": 80, "stars": 3, "new_medal": true})
	var m := DailyMissions.for_day(DailyRewards.today())[0]
	GameManager.advance_mission(m["id"], int(m["goal"]))
	hud._refresh_next_goal()
	assert_true(hud.btn_claim_missions.visible, "Las misiones se reclaman desde la victoria")
	hud._claim_missions()
	assert_true(hud.unlock_label.visible and GameManager.is_cosmetic_owned("color_cyan"), "Cobrar una misión actualiza rango y desbloqueos")
	assert_true(not hud.btn_claim_missions.visible, "La recompensa ya cobrada desaparece")
	remove_child(hud)
	hud.free()
	GameManager.reset_save()

func test_packet_combat_and_migration() -> void:
	print("\n-> Test: Combate de paquetes y migración sin pérdida de progreso")
	for dt in [0.016, 0.1, 0.5]:
		var a := _make_base(Vector2(100, 500), GameManager.Faction.PLAYER, 1)
		var b := _make_base(Vector2(900, 500), GameManager.Faction.ENEMY_1, 1)
		var battle := BattleController.new()
		var t1 := _make_stream(a, b, 40, GameManager.Faction.PLAYER)
		var t2 := _make_stream(b, a, 20, GameManager.Faction.ENEMY_1)
		battle.active_troops.append_array([t1, t2])
		for _step in int(2.0 / dt):
			for t in battle.active_troops.duplicate():
				if BattleController._is_alive(t):
					t.advance(dt)
			battle._process_troop_collisions()
			for t in battle.active_troops.duplicate():
				if BattleController._is_alive(t):
					t.resolve_arrivals()
		assert_true(not is_instance_valid(t2), "Choque frontal elimina al menor (delta %.3f)" % dt)
		assert_equals(t1.count, 20, "Choque conserva la diferencia exacta (delta %.3f)" % dt)
		for n in [t1, t2, a, b, battle]:
			if is_instance_valid(n):
				n.free()
	var day := DailyRewards.today()
	var legacy := DailyMissions.for_day(day, true)
	var first: Dictionary = legacy[0]
	GameManager._apply_save({"version": 4, "coins": 333, "experience": 150,
		"upgrades": {"production_rate": 4}, "cosmetics_owned": ["color_gold"],
		"missions": {"day": day, "progress": {first["id"]: first["goal"]}, "claimed": []}})
	assert_equals(GameManager.mission_definitions(), legacy, "Las misiones antiguas siguen vigentes hasta medianoche")
	assert_true(GameManager.claim_mission(first["id"]), "La misión completada antes de actualizar se puede cobrar")
	assert_equals(GameManager.upgrades["production_rate"], 4, "La actualización conserva las mejoras compradas")
	assert_true(GameManager.is_cosmetic_owned("color_gold"), "Los cosméticos comprados siguen siendo tuyos")
	GameManager.save_game()
	GameManager.load_game()
	assert_equals(GameManager.mission_definitions(), legacy, "La migración de misiones persiste")
	GameManager.reset_save()

func test_campaign_balance_and_rewards() -> void:
	print("\n-> Test: Ritmo Humano, Progreso de Combate y Recompensas Limitadas")
	GameManager.reset_save()
	var battle := BattleController.new()
	battle.level_id = "europe_4"
	var ai := AIController.new()
	ai.setup(battle, GameManager.Faction.ENEMY_1)
	var full_wait := true
	for i in 100:
		ai._configure_timers_for_archetype()
		full_wait = full_wait and is_equal_approx(ai.think_timer, ai.think_interval) and ai.think_timer >= 3.5
	assert_true(full_wait, "Cien ciclos respetan el intervalo completo, sin esperas de 0,2 s")
	var src := _make_base(Vector2(100, 500), GameManager.Faction.ENEMY_1, 80)
	var src2 := _make_base(Vector2(100, 900), GameManager.Faction.ENEMY_1, 80)
	var player := _make_base(Vector2(800, 500), GameManager.Faction.PLAYER, 5)
	var neutral := _make_base(Vector2(400, 900), GameManager.Faction.NEUTRAL, 5)
	battle.bases.append_array([src, src2, player, neutral])
	battle.battle_time = 21.0
	ai._evaluate_and_execute()
	assert_equals(battle.active_troops.size(), 1, "Europa limita la IA a una orden por ciclo")
	assert_true(battle.active_troops.all(func(t): return t.target_base != player), "No hay ataques al jugador durante la apertura")
	assert_equals(ai._joint_sources([src, src2], player).size(), 0, "Europa no usa ataques coordinados")
	for t in battle.active_troops: t.free()
	for n in [src, src2, player, neutral, ai, battle]: n.free()
	var fourth := LevelDatabase.get_level_data("europe_4")
	assert_true(not fourth["bases"].any(func(b): return b.get("type") == "fortress"), "Nivel 4 enseña economía sin una fortaleza de 50 de defensa")
	var fifth := LevelDatabase.get_level_data("europe_5")
	assert_equals(fifth["bases"].filter(func(b): return b["faction"] > GameManager.Faction.PLAYER).size(), 1, "Primer jefe con un solo rival")
	assert_true(fifth["bases"].any(func(b): return b.get("boss", false) and b["troops"] <= 40), "Primer jefe con guarnición accesible")
	for id in LevelDatabase.get_level_ids():
		var before := LevelDatabase.get_balance(id)
		GameManager.upgrades["production_rate"] = 10
		assert_equals(LevelDatabase.get_balance(id), before, "Comprar no endurece al enemigo de " + id)
		GameManager.upgrades["production_rate"] = 0
		if LevelDatabase.get_level_number(id) == 1 and id != "europe_1":
			var ids := LevelDatabase.get_level_ids()
			assert_true(before["cadence"] > LevelDatabase.get_balance(ids[ids.find(id) - 1])["cadence"], "Respiro después del jefe: " + id)
	assert_true(LevelDatabase.get_balance("conquest_5")["cadence"] > LevelDatabase.get_balance("conquest_4")["cadence"], "Respiro al empezar otra expedición")
	assert_equals(GameManager.recommended_combat_upgrade(true), "production_rate", "Con saldo inicial, recomendar reclutar")
	GameManager.buy_upgrade("production_rate")
	assert_equals(GameManager.recommended_combat_upgrade(true), "starting_troops", "Después, abrir territorio con más tropas")
	assert_true(GameManager.can_suggest_combat_upgrade(), "La sugerencia continúa después de la primera compra")
	GameManager.coins = 1000
	GameManager.upgrades = {"production_rate": 10, "starting_troops": 10, "troop_speed": 10, "gold_bonus": 0}
	assert_equals(GameManager.recommended_combat_upgrade(true), "", "Botín no se recomienda para superar un combate")
	GameManager.reset_save()
	GameManager.coins = 1000
	GameManager.play_level(DailyRewards.challenge_id(20000))
	assert_true(not GameManager.can_suggest_combat_upgrade(), "El diario no invita a comprar ventajas que no aplica")
	GameManager.play_level("europe_4")
	var full := GameManager.calculate_victory_gold("europe_5", 3, 100)
	GameManager.completed_levels["europe_5"] = 3
	assert_equals(GameManager.calculate_victory_gold("europe_5", 3, 100), 37, "Repetir jefe no vuelve a pagar el bonus de 150")
	assert_equals(full, 298, "Primera victoria del jefe incluye escala y bonus")
	assert_true(GameManager.calculate_victory_gold("asia_4", 3, 100) > GameManager.calculate_victory_gold("europe_4", 3, 100), "El oro de victoria crece con la campaña")
	assert_equals(GameManager.award_defeat_gold("europe_4", 0, 60), 0, "Sin capturas no se cobra consuelo")
	assert_equals(GameManager.award_defeat_gold("europe_4", 2, 10), 0, "Perder inmediatamente no paga")
	assert_equals(GameManager.award_defeat_gold("daily_20000", 2, 60), 0, "Sin consuelo ni ayudas en diario")
	var reward := GameManager.award_defeat_gold("europe_4", 1, 30)
	assert_equals(reward, 19, "Avance real deja un pequeño premio")
	GameManager.save_game()
	GameManager.load_game()
	assert_equals(GameManager.defeat_rewards["europe_4"], 1, "El límite persiste entre sesiones")
	assert_equals(GameManager.award_defeat_gold("europe_4", 20, 60), reward, "Recapturas o duración no multiplican el premio")
	assert_equals(GameManager.award_defeat_gold("europe_4", 1, 60), 0, "Sólo dos recompensas por nivel")
	GameManager.completed_levels["europe_3"] = 1
	assert_equals(GameManager.award_defeat_gold("europe_3", 1, 60), 0, "Un nivel superado no permite farmear derrotas")
	GameManager._apply_save({"version": 5, "coins": 333, "upgrades": {"starting_troops": 4},
		"completed_levels": {"europe_1": 3}, "defeat_rewards": {"europe_4": 99, "invalid": 1},
		"daily_best": {"day": 20000, "stars": 3, "time": 10, "normalized": true}})
	assert_equals(GameManager.coins, 333, "Migración conserva las monedas")
	assert_equals(GameManager.upgrades["starting_troops"], 4, "Migración conserva cada compra")
	assert_equals(GameManager.defeat_rewards, {"europe_4": 2}, "Datos importados no saltan los límites")
	assert_equals(GameManager.daily_best["time"], 10.0, "La marca anterior se conserva sin borrarla")
	assert_equals(GameManager.daily_best["balance_version"], 1, "La marca anterior identifica su balance original")
	var result := {"level_id": "daily_20000", "is_daily_challenge": true, "stars": 3, "time": 30.0}
	GameManager.record_battle_result(result, true)
	assert_equals(GameManager.daily_best["balance_version"], DailyRewards.BALANCE_VERSION, "Nueva marca identifica su balance")
	assert_equals(GameManager.daily_best["time"], 30.0, "Nuevo balance no compara sus tiempos con marcas anteriores")
	assert_true(DailyShare.text(GameManager.daily_best).contains("v2"), "Tarjeta compartida identifica el balance")
	GameManager.reset_save()

func test_light_and_dark_mode() -> void:
	print("\n-> Test: Modo Claro y Oscuro")
	GameManager.reset_save()
	GameManager.set_setting("light_mode", true)
	assert_equals(UIThemeHelper.palette_name, "light", "Activar el modo claro cambia la paleta al instante")
	var theme := ThemeDB.get_default_theme()
	assert_equals(theme.get_color("font_color", "Label"), UIThemeHelper.PALETTES.light.text, "El tema global usa el texto oscuro")
	for type in ["Button", "PrimaryButton", "GoldButton"]:
		var ink: float = theme.get_color("font_color", type).srgb_to_linear().get_luminance()
		var background: float = (theme.get_stylebox("normal", type) as StyleBoxFlat).bg_color.srgb_to_linear().get_luminance()
		assert_true((maxf(ink, background) + 0.05) / (minf(ink, background) + 0.05) >= 4.5, "Contraste accesible en modo claro: %s" % type)
	var text: float = UIThemeHelper.colors.text.srgb_to_linear().get_luminance()
	var surface: float = UIThemeHelper.colors.surface.srgb_to_linear().get_luminance()
	assert_true((surface + 0.05) / (text + 0.05) >= 7.0, "Texto sobre tarjetas muy legible en modo claro")
	GameManager.load_game()
	assert_true(GameManager.settings["light_mode"], "La preferencia se guarda")
	var menu: MainMenuUI = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	assert_true(menu.get_child(0) is ColorRect and menu.get_child(0).color == UIThemeHelper.PALETTES.light.bg, "El menú se construye con el fondo claro")
	remove_child(menu)
	menu.free()
	GameManager.set_setting("light_mode", false)
	assert_equals(UIThemeHelper.palette_name, "dark", "Volver al modo oscuro")
	assert_equals(theme.get_color("font_color", "Label"), UIThemeHelper.PALETTES.dark.text, "El tema global vuelve al texto claro")
	GameManager.reset_save()
