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

func test_base_production_mechanics() -> void:
	print("-> Test: Producción de Tropas en Territorios")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.faction = GameManager.Faction.PLAYER
	base.tier = 1
	base.troops = 10
	
	# Simular 1 segundo de delta
	base._process(1.05)
	assert_true(base.troops >= 11, "Base de jugador genera tropas tras transcurrir el tiempo")
	
	# Probar base neutral
	var neutral_base = BaseNodeScript.new()
	neutral_base.faction = GameManager.Faction.NEUTRAL
	neutral_base.troops = 15
	neutral_base._process(3.0)
	assert_equals(neutral_base.troops, 15, "Base neutral no genera tropas automáticamente")
	
	base.free()
	neutral_base.free()

func test_troop_dispatch_and_deduction() -> void:
	print("\n-> Test: Envío de Tropas y Deducción de Guarnición")
	var BaseNodeScript = load("res://scripts/battle/base_node.gd")
	var base = BaseNodeScript.new()
	base.troops = 20
	
	var sent = base.send_troops(0.5)
	assert_equals(sent, 10, "Envío al 50% extrae exactamente la mitad")
	assert_equals(base.troops, 10, "Base retiene las tropas restantes")
	
	# Intentar enviar desde base con 1 tropa (no debe quedar a 0)
	base.troops = 1
	var sent_empty = base.send_troops(0.5)
	assert_equals(sent_empty, 0, "Base con 1 tropa no permite envío para no quedar desprotegida")
	
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
	
	# Probar multiplicador de producción
	var prod_mult_base = GameManager.get_production_multiplier()
	assert_true(prod_mult_base >= 1.0, "Multiplicador de producción base >= 1.0")
	
	GameManager.buy_upgrade("production_rate")
	assert_true(GameManager.get_production_multiplier() > prod_mult_base, "Multiplicador de producción incrementado tras compra")

func test_progression_unlocks() -> void:
	print("\n-> Test: Progresión y Desbloqueo Secuencial de Campaña")
	GameManager.reset_save()
	
	assert_true(GameManager.is_level_unlocked("europe_1"), "Nivel 1 de Europa desbloqueado por defecto")
	assert_true(not GameManager.is_level_unlocked("europe_2"), "Nivel 2 de Europa bloqueado inicialmente")
	
	# Completar nivel 1
	GameManager.complete_level("europe_1", 3)
	assert_true(GameManager.is_level_unlocked("europe_2"), "Nivel 2 de Europa se desbloquea tras vencer en nivel 1")
	assert_equals(GameManager.completed_levels.get("europe_1", 0), 3, "Estrellas guardadas correctamente")
	
	# Completar último nivel de Europa para desbloquear América del Norte
	GameManager.complete_level("europe_5", 2)
	assert_true(GameManager.is_level_unlocked("north_america_1"), "Primer nivel de Norteamérica desbloqueado tras ganar Europa 5")

func test_level_database_integrity() -> void:
	print("\n-> Test: Integridad de la Base de Datos de Niveles")
	var continents = LevelDatabase.get_continents()
	assert_equals(continents.size(), 6, "Existen 6 continentes configurados")
	
	var lvl1 = LevelDatabase.get_level_data("europe_1")
	assert_true(lvl1.has("bases"), "Nivel 'europe_1' contiene definición de bases")
	assert_true(lvl1["bases"].size() >= 3, "Nivel 'europe_1' tiene al menos 3 bases territoriales")
	
	var has_player = false
	var has_enemy = false
	for b in lvl1["bases"]:
		if b["faction"] == GameManager.Faction.PLAYER:
			has_player = true
		elif b["faction"] == GameManager.Faction.ENEMY_1:
			has_enemy = true
			
	assert_true(has_player, "Nivel 'europe_1' incluye base inicial del jugador")
	assert_true(has_enemy, "Nivel 'europe_1' incluye base inicial enemiga")
