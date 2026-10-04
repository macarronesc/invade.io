extends Node

## Comprobación reproducible del balance con decisiones cada 2–4 s, sin
## modificar el guardado real. No sustituye pruebas con principiantes en móvil.
class Simulation extends BattleController:
	var won := false
	func _ready() -> void: pass
	func _trigger_victory() -> void:
		won = true
		is_game_over = true
	func _trigger_defeat() -> void:
		is_game_over = true

var _failed := false
var _completed := false

func _ready() -> void:
	GameManager.save_path = "user://balance_test_save.json"
	AudioManager.is_muted = true
	AudioManager.music_muted = true
	if "--ui" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_ui_test_save.json"
		OS.low_processor_usage_mode = false
		await _check_ui()
	elif "--flow" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_flow_test_save.json"
		await _check_flow()
	else:
		_check_campaign()
	_require(_completed, "La comprobación termina todos sus pasos sin errores de script")
	DirAccess.remove_absolute(GameManager.save_path)
	get_tree().quit(1 if _failed else 0)

func _check_campaign() -> void:
	for scenario in ["untrained", "recruitment", "garrison", "balanced"]:
		GameManager._apply_save({})
		var total := 0
		var since_purchase := 0
		var longest_wait := 0
		for i in LevelDatabase.get_level_ids().size():
			var id: String = LevelDatabase.get_level_ids()[i]
			var wins := 0
			var seconds := 0.0
			for trial in 6:
				var result := _simulate(id, 2.0 + trial * 0.4, trial)
				wins += int(result["won"])
				seconds += result["seconds"]
			print("BALANCE %s %s: %d/6 · %.0fs · upgrades=%s" % [scenario, id, wins, seconds / 6, str(GameManager.upgrades)])
			if i < 5:
				_require(wins >= 5, "Aprendizaje accesible: %s / %s" % [scenario, id])
			if scenario == "balanced":
				_require(wins >= 4, "Sin muro de progreso con mejoras: " + id)
			total += wins
			# Una victoria por nivel, sin depender de diarios, logros ni consuelo.
			GameManager.coins += GameManager.calculate_victory_gold(id, 1, 120)
			since_purchase += 1
			if scenario != "untrained":
				var upgrade := GameManager.recommended_combat_upgrade(true)
				if scenario in ["recruitment", "garrison"]:
					upgrade = "production_rate" if scenario == "recruitment" else "starting_troops"
				if upgrade != "" and GameManager.coins >= GameManager.get_upgrade_cost(upgrade) and GameManager.get_upgrade_cost(upgrade) >= 0:
					GameManager.buy_upgrade(upgrade)
					longest_wait = maxi(longest_wait, since_purchase)
					since_purchase = 0
		print("TOTAL %s: %d/180" % [scenario, total])
		if scenario == "balanced":
			_require(longest_wait <= 3, "Una mejora de combate cada 1–3 victorias")
	for i in [0, 4, 5, 9, 10, 19, 29]:
		var result := _simulate(LevelGenerator.conquest_id(i), 3.0, 0)
		print("EXPEDITION %d: %s · %.0fs" % [i, str(result["won"]), result["seconds"]])
		_require(result["won"], "Expedición alcanzable con ejército mejorado: %d" % i)
	_completed = true

func _simulate(id: String, delay: float, trial: int) -> Dictionary:
	var battle := Simulation.new()
	add_child(battle)
	battle.load_level(id)
	EventBus.base_captured.connect(battle._on_base_captured)
	EventBus.troop_arrived.connect(battle._on_troop_arrived)
	for ai in battle.ai_controllers:
		ai._rng.seed += trial
	var timer := delay + trial * 0.5 # Leer el mapa antes de dar la primera orden.
	for step in 2400:
		for base in battle.bases: base._process(0.1)
		for ai in battle.ai_controllers: ai._process(0.1)
		timer -= 0.1
		if timer <= 0.0:
			_player_order(battle)
			timer += delay
		battle._process(0.1)
		if battle.is_game_over: break
	var result := {"won": battle.won, "seconds": battle.battle_time}
	battle.free()
	return result

## ponytail: política sencilla con información visible y hasta tres orígenes;
## un estudio con personas valida intuición, errores y ergonomía reales.
func _player_order(battle: BattleController) -> void:
	var best_target: BaseNode
	var best_sources: Array[BaseNode] = []
	var best_score := -INF
	for dst in battle.bases:
		if dst.faction == GameManager.Faction.PLAYER: continue
		var sources: Array[BaseNode] = []
		sources.assign(battle.bases.filter(func(b):
			return b.faction == GameManager.Faction.PLAYER and b.troops >= 8 and battle.can_dispatch(b, dst)))
		sources.sort_custom(func(a, b): return a.position.distance_squared_to(dst.position) < b.position.distance_squared_to(dst.position))
		var chosen: Array[BaseNode] = []
		var available := 0
		for src in sources:
			chosen.append(src)
			available += src.troops - 1
			battle.selected_sources = chosen
			var defense := battle.estimate_target_defense(dst)
			if defense <= 0.0: break # Ya hay tropas suficientes en camino.
			if available > defense + 4:
				var distance := src.position.distance_to(dst.position)
				var score := (200.0 if dst.faction == GameManager.Faction.NEUTRAL else 140.0) - distance * 0.08 - defense * 0.4
				if dst.base_type == BaseNode.BaseType.FACTORY: score += 90.0
				if score > best_score:
					best_score = score
					best_target = dst
					best_sources = chosen.duplicate()
				break
			if chosen.size() == 3: break
	battle.selected_sources.clear()
	if best_target:
		for src in best_sources: battle.dispatch_troops(src, best_target)

func _check_ui() -> void:
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.completed_levels = {"europe_1": 3, "europe_2": 3, "europe_3": 3}
	GameManager.unlocked_levels.append_array(["europe_2", "europe_3", "europe_4"])
	GameManager.play_level("europe_4")
	GameManager.coins = 420
	GameManager.settings["reduced_motion"] = true
	for lang in ["es", "en"]:
		GameManager.set_language(lang)
		for light in [false, true]:
			GameManager.set_setting("light_mode", light)
			var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
			add_child(menu)
			await _snapshot("menu_%s_%s" % [lang, str(light)])
			var play := menu._content.get_child(0)
			_require(play.btn_daily.get_global_rect().end.y <= menu._nav["play"].get_global_rect().position.y, "Accesos secundarios no quedan bajo la navegación")
			menu.show_tab("army")
			await _snapshot("army_%s_%s" % [lang, str(light)])
			menu.free()
			GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
			var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
			add_child(battle)
			battle.set_simulation_paused(true)
			await _snapshot("battle_%s_%s" % [lang, str(light)])
			battle.is_game_over = true
			battle.defeat_gold = 19
			var hud: BattleHUD = battle.get_node("BattleHUD")
			hud._on_battle_lost()
			await _snapshot("defeat_%s_%s" % [lang, str(light)])
			_require(hud.btn_defeat_upgrade.visible and hud.btn_defeat_upgrade.theme_type_variation == "GoldButton", "Compra útil visible tras perder")
			_require(hud.defeat_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "Derrota cabe en pantalla")
			hud.defeat_panel.hide()
			hud.deploy_victory_modal({"stars": 3, "gold_earned": 170, "xp_before": 0, "xp": 60, "level_id": "europe_4"})
			await _snapshot("victory_%s_%s" % [lang, str(light)])
			_require(hud.btn_result_action.visible and hud.btn_result_action.theme_type_variation == "GoldButton", "Mejorar y seguir visible tras ganar")
			_require(hud.victory_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "Victoria cabe en pantalla")
			GameManager.experience = 160
			GameManager.completed_levels.merge({"europe_4": 3, "europe_5": 3})
			hud.deploy_victory_modal({"stars": 3, "gold_earned": 350, "xp_before": 80, "xp": 80,
				"level_id": "europe_5", "new_medal": true, "new_continent": true,
				"is_continent_conquest": true, "boss_gold": 150})
			await _snapshot("boss_%s_%s" % [lang, str(light)])
			_require(hud.btn_result_action.visible and hud.btn_equip_reward.visible, "Equipar el premio no queda oculto por la sugerencia de compra")
			_require(hud.victory_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "Victoria de jefe con desbloqueos cabe en pantalla")
			hud.btn_equip_reward.pressed.emit()
			_require(GameManager.cosmetics_equipped["map_theme"] == "theme_ocean", "Equipar premio desde el resultado funciona")
			GameManager.experience = 0
			GameManager.completed_levels.erase("europe_4")
			GameManager.completed_levels.erase("europe_5")
			GameManager.cosmetics_equipped = GameManager.DEFAULT_COSMETICS_EQUIPPED.duplicate()
			battle.free()
	_completed = true

## Pulsar los botones reales recorre victoria → compra → siguiente batalla
## y derrota → compra → mismo nivel, sin sustituir las rutas de navegación.
func _check_flow() -> void:
	await get_tree().process_frame
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.play_level("europe_4")
	GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
	# El comprobador permanece en root al cambiar la escena que está probando.
	get_tree().current_scene = null
	var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
	get_tree().root.add_child(battle)
	get_tree().current_scene = battle
	battle.set_simulation_paused(true)
	battle.battle_time = 48.0
	for base in battle.bases: base.faction = GameManager.Faction.PLAYER
	battle._trigger_victory()
	await get_tree().create_timer(0.8, true, false, true).timeout
	var hud: BattleHUD = battle.get_node("BattleHUD")
	_require(hud.btn_result_action.visible, "Victoria ofrece mejorar antes de seguir")
	hud.btn_result_action.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var menu: MainMenuUI = get_tree().current_scene
	_require(menu.current_tab == "army" and GameManager.current_level_id == "europe_5", "Victoria abre Ejército para el siguiente nivel")
	var army := menu._content.get_child(0)
	var cost := GameManager.get_upgrade_cost("production_rate")
	var before := GameManager.coins
	var card := army.find_child("UpgradeCard_production_rate", true, false)
	var buy: Button = card.find_children("*", "Button", true, false)[0]
	buy.pressed.emit()
	_require(GameManager.upgrades["production_rate"] == 1 and GameManager.coins == before - cost, "Compra real aplica y descuenta una sola vez")
	var back: Button = army.find_child("BtnReturnToBattle", true, false)
	back.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	battle = get_tree().current_scene
	_require(battle.level_id == "europe_5", "Mejorar y seguir carga el siguiente nivel")
	battle.set_simulation_paused(true)
	var home: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)[0]
	_require(is_equal_approx(home.get_production_rate(), 2.5 * 1.15), "La compra se nota desde el inicio de la nueva batalla")
	var target: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.NEUTRAL)[0]
	battle.battle_time = 30.0
	target.receive_troops(GameManager.Faction.PLAYER, 50)
	before = GameManager.coins
	battle._trigger_defeat()
	hud = battle.get_node("BattleHUD")
	_require(battle.defeat_gold > 0 and GameManager.coins == before + battle.defeat_gold, "Derrota con avance cobra el consuelo real")
	_require(hud.defeat_xp_label.text.contains(str(battle.defeat_gold)), "El resultado muestra el premio cobrado")
	hud.btn_defeat_upgrade.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	menu = get_tree().current_scene
	_require(menu.current_tab == "army" and GameManager.current_level_id == "europe_5", "Derrota abre Ejército sin saltar el nivel pendiente")
	army = menu._content.get_child(0)
	back = army.find_child("BtnReturnToBattle", true, false)
	back.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	battle = get_tree().current_scene
	_require(battle.level_id == "europe_5", "Volver tras perder reintenta la misma batalla")
	print("FLOW: victoria → mejora → siguiente; derrota → mejora → reintento verificados")
	_completed = true

func _snapshot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()
	var path := "user://%s.png" % name
	_require(get_viewport().get_texture().get_image().save_png(path) == OK, "Guardar captura: " + name)
	print("SCREENSHOT ", ProjectSettings.globalize_path(path))

func _require(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
