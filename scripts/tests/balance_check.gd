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

## Idiomas con captura visual. Los dos primeros cubren claro/oscuro; el resto,
## sólo el tema oscuro, para revisar expansión, RTL y alfabetos sin multiplicar el tiempo.
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
	elif "--invasions" in OS.get_cmdline_user_args():
		_check_invasions()
	elif "--invasion-ui" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_invasion_ui_test_save.json"
		OS.low_processor_usage_mode = false
		await _check_invasion_ui()
	elif "--wide-ui" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_wide_ui_test_save.json"
		OS.low_processor_usage_mode = false
		await _check_wide_ui()
	elif "--rotate-ui" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_rotate_ui_test_save.json"
		OS.low_processor_usage_mode = false
		await _check_rotate_ui()
	elif "--gestures" in OS.get_cmdline_user_args():
		GameManager.save_path = "user://balance_gestures_test_save.json"
		OS.low_processor_usage_mode = false
		await _check_gestures()
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
	_check_invasions()
	_completed = true

## Muestra de invasiones: cada nivel debe ser alcanzable con un ejército medio.
func _check_invasions() -> void:
	GameManager._apply_save({})
	GameManager.upgrades = {"production_rate": 5, "starting_troops": 5, "troop_speed": 5, "gold_bonus": 0}
	for id in ["inv_iberia_1", "inv_iberia_3", "inv_amazon_3", "inv_maghreb_3", "inv_us_east_1", "inv_us_east_3", "inv_china_1", "inv_china_3", "inv_siberia_3", "inv_pacific_3"]:
		var wins := 0
		var seconds := 0.0
		for trial in 3:
			var result := _simulate(id, 3.0 + trial * 0.3, trial)
			wins += int(result["won"])
			seconds += result["seconds"]
		print("INVASION %s: %d/3 · %.0fs" % [id, wins, seconds / 3])
		_require(wins >= 2, "Invasión alcanzable con ejército medio: " + id)
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

## Capturas de la pestaña de invasiones para comprobar mapa, ficha y tema en móvil.
func _check_invasion_ui() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1080, 1920)
		await get_tree().process_frame
	GameManager._apply_save({})
	GameManager.has_started = true
	for i in range(1, LevelDatabase.LEVELS_PER_CONTINENT + 1):
		GameManager.completed_levels["europe_%d" % i] = 3
	GameManager.invasion_stars = {"inv_iberia_1": 3, "inv_iberia_2": 2}
	GameManager.coins = 420
	GameManager.settings["reduced_motion"] = true
	for lang in _ui_langs():
		GameManager.set_language(lang)
		for light in [false, true]:
			if light and lang not in ["es", "en"]:
				continue
			GameManager.set_setting("light_mode", light)
			var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
			add_child(menu)
			menu.show_tab("invasion")
			await _snapshot("invasion_%s_%s" % [lang, str(light)])
			var page = menu._content.get_child(0)
			_require(page is InvasionPage, "La sección de invasiones monta su página")
			var map: Control = page.find_child("InvasionMap", true, false)
			_require(map != null, "La pestaña de invasiones muestra el mapa")
			_require(page.find_child("InvasionRegionCard", true, false) != null, "La pestaña de invasiones muestra la ficha de región")
			_require(page.find_child("BtnInvasionFront_1", true, false) != null, "La ficha muestra el primer frente")
			if map:
				_require(map.get_global_rect().position.x >= 0.0 and map.get_global_rect().end.x <= get_viewport().get_visible_rect().end.x,
					"El mapa de invasiones cabe en el ancho de la pantalla")
			remove_child(menu)
			menu.free()
	_completed = true

func _ui_langs() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			return [arg.substr(7)]
	return LanguageCatalog.codes()

func _check_ui() -> void:
	# La ficha de Play exige capturas de 1080×1920; el override de escritorio es 540×960.
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1080, 1920)
		await get_tree().process_frame
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.completed_levels = {"europe_1": 3, "europe_2": 3, "europe_3": 3}
	GameManager.unlocked_levels.append_array(["europe_2", "europe_3", "europe_4"])
	GameManager.play_level("europe_4")
	GameManager.coins = 420
	GameManager.settings["reduced_motion"] = true
	for lang in _ui_langs():
		GameManager.set_language(lang)
		for light in [false, true]:
			if light and lang not in ["es", "en"]:
				continue
			GameManager.set_setting("light_mode", light)
			var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
			add_child(menu)
			await _snapshot("menu_%s_%s" % [lang, str(light)])
			var play := menu._content.get_child(0)
			_require(not play.level_details.visible, "La ficha arranca sin datos secundarios")
			play.btn_details.pressed.emit()
			_require(play.level_details.visible, "Detalles revela las etiquetas secundarias")
			await _snapshot("menu_details_%s_%s" % [lang, str(light)])
			play.btn_details.pressed.emit()
			_require(not play.level_details.visible, "Detalles vuelve a plegarse")
			_require(play.btn_daily.get_global_rect().end.y <= menu._nav["play"].get_global_rect().position.y, "Accesos secundarios no quedan bajo la navegación (%s): %s / %s" % [lang, play.btn_daily.get_global_rect(), menu._nav["play"].get_global_rect()])
			for label in play.btn_daily.find_children("*", "Label", true, false):
				_require(play.btn_daily.get_global_rect().grow(6).encloses(label.get_global_rect()), "El texto del desafío diario queda dentro de su tarjeta")
			menu.show_tab("challenges")
			await _snapshot("challenges_%s_%s" % [lang, str(light)])
			var challenges: ScrollPage = menu._content.get_child(0)
			var claim: Button = challenges.find_child("BtnClaimDaily", true, false)
			var scroll_start := challenges.scroll_vertical
			var claim_day := int(GameManager.daily["last_claim_day"])
			var touch_pos := claim.get_global_rect().get_center() * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = touch_pos
			press.pressed = true
			Input.parse_input_event(press)
			await get_tree().process_frame
			var drag := InputEventMouseMotion.new()
			drag.position = touch_pos - Vector2(0, 160)
			drag.relative = Vector2(0, -160)
			drag.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(drag)
			await get_tree().process_frame
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.position = drag.position
			Input.parse_input_event(release)
			await get_tree().process_frame
			_require(challenges.scroll_vertical > scroll_start, "Un arrastre sobre un botón desplaza Retos")
			_require(int(GameManager.daily["last_claim_day"]) == claim_day, "Desplazarse sobre un botón no lo activa")
			challenges.scroll_vertical = scroll_start
			menu.show_tab("progress")
			await _snapshot("progress_%s_%s" % [lang, str(light)])
			menu.show_tab("army")
			await _snapshot("army_%s_%s" % [lang, str(light)])
			var army = menu._content.get_child(0)
			var looks_button: Button = army.find_child("Segment_looks", true, false)
			var looks_pos := looks_button.get_global_rect().get_center() * Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
			var looks_press := InputEventMouseButton.new()
			looks_press.button_index = MOUSE_BUTTON_LEFT
			looks_press.position = looks_pos
			looks_press.pressed = true
			Input.parse_input_event(looks_press)
			await get_tree().process_frame
			var looks_release := InputEventMouseButton.new()
			looks_release.button_index = MOUSE_BUTTON_LEFT
			looks_release.position = looks_pos
			Input.parse_input_event(looks_release)
			await get_tree().process_frame
			_require(army.section == "looks", "Un toque en un botón desplazable sigue activándolo")
			await _snapshot("army_looks_%s_%s" % [lang, str(light)])
			var before_completed: Dictionary = GameManager.completed_levels.duplicate()
			for i in range(1, LevelDatabase.LEVELS_PER_CONTINENT + 1):
				GameManager.completed_levels["europe_%d" % i] = 3
			GameManager.invasion_stars = {"inv_iberia_1": 3, "inv_iberia_2": 2, "inv_iberia_3": 1}
			menu.show_tab("invasion")
			await _snapshot("invasion_%s_%s" % [lang, str(light)])
			GameManager.completed_levels = before_completed
			GameManager.invasion_stars.clear()
			menu._open_settings()
			await _snapshot("settings_%s_%s" % [lang, str(light)])
			menu._utility_panel._close()
			await get_tree().process_frame
			menu.free()
			GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
			var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
			add_child(battle)
			battle.set_simulation_paused(true)
			await _snapshot("battle_%s_%s" % [lang, str(light)])
			# Columnas en marcha: un ataque propio y un contraataque enemigo
			var home: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)[0]
			var rival: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.ENEMY_1)[0]
			var neutral: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.NEUTRAL)[0]
			_require(battle.dispatch_troops(home, neutral) and battle.dispatch_troops(rival, home), "Se lanzan columnas para la captura")
			for t in battle.active_troops:
				t.advance(0.55)
			await _snapshot("march_%s_%s" % [lang, str(light)])
			var hud: BattleHUD = battle.get_node("BattleHUD")
			hud.dim_overlay.show()
			hud.pause_panel.show()
			await _snapshot("pause_%s_%s" % [lang, str(light)])
			hud.pause_panel.hide()
			hud.dim_overlay.hide()
			var help := UIThemeHelper.how_to_play_card()
			hud.add_child(help)
			await _snapshot("help_%s_%s" % [lang, str(light)])
			help.queue_free()
			battle.is_game_over = true
			battle.defeat_gold = 19
			hud._on_battle_lost()
			await _snapshot("defeat_%s_%s" % [lang, str(light)])
			_require(hud.btn_defeat_upgrade.visible and hud.btn_defeat_upgrade.theme_type_variation == "Button", "Compra útil, secundaria, visible tras perder")
			_require(hud.defeat_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y,
				"Derrota cabe en pantalla: %s / %s" % [hud.defeat_panel.get_global_rect(), get_viewport().get_visible_rect()])
			hud.defeat_panel.hide()
			hud.deploy_victory_modal({"stars": 3, "gold_earned": 170, "xp_before": 0, "xp": 60, "level_id": "europe_4"})
			await _snapshot("victory_%s_%s" % [lang, str(light)])
			_require(hud.btn_result_action.visible and hud.btn_result_action.theme_type_variation == "Button", "Mejorar y seguir visible, secundario, tras ganar")
			_require(hud.victory_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y,
				"Victoria cabe en pantalla: %s / %s" % [hud.victory_panel.get_global_rect(), get_viewport().get_visible_rect()])
			hud.deploy_victory_modal({"stars": 2, "gold_earned": 150, "is_daily_challenge": true,
				"level_id": DailyRewards.challenge_id(DailyRewards.today())})
			await _snapshot("daily_result_%s_%s" % [lang, str(light)])
			GameManager.experience = 160
			GameManager.completed_levels.merge({"europe_4": 3, "europe_5": 3})
			hud.deploy_victory_modal({"stars": 3, "gold_earned": 350, "xp_before": 80, "xp": 80,
				"level_id": "europe_5", "new_medal": true, "new_continent": true,
				"is_continent_conquest": true, "boss_gold": 150})
			await _snapshot("boss_%s_%s" % [lang, str(light)])
			_require(hud.btn_result_action.visible and hud.btn_equip_reward.visible, "Equipar el premio no queda oculto por la sugerencia de compra")
			_require(hud.victory_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y,
				"Victoria de jefe con desbloqueos cabe en pantalla: %s / %s" % [hud.victory_panel.get_global_rect(), get_viewport().get_visible_rect()])
			hud.btn_equip_reward.pressed.emit()
			_require(GameManager.cosmetics_equipped["map_theme"] == "theme_ocean", "Equipar premio desde el resultado funciona")
			GameManager.experience = 0
			GameManager.completed_levels.erase("europe_4")
			GameManager.completed_levels.erase("europe_5")
			GameManager.cosmetics_equipped = GameManager.DEFAULT_COSMETICS_EQUIPPED.duplicate()
			battle.free()
	GameManager.set_language("es")
	GameManager.set_setting("light_mode", true)
	var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
	add_child(battle)
	battle.is_game_over = true
	var hud: BattleHUD = battle.get_node("BattleHUD")
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 170, "xp": 60, "level_id": "europe_4"})
	Toasts.show_toast("trophy", LocaleStrings.text("toast_achievement"), AchievementDatabase.achievement_title(AchievementDatabase.get_by_id("first_victory")))
	await _snapshot("achievement_toast")
	var toast := Toasts.get_child(Toasts.get_child_count() - 1) as Control
	var toast_rect := toast.get_global_rect()
	_require(toast_rect.position.x >= 0 and toast_rect.end.x <= get_viewport().get_visible_rect().end.x, "El aviso de logro cabe en el ancho de pantalla")
	_require(toast_rect.position.y >= 0 and toast_rect.end.y <= get_viewport().get_visible_rect().end.y, "El aviso de logro cabe en la altura de pantalla")
	battle.free()
	_completed = true

## Runtime layout smoke test for a 1920×1080 resizable window (not only computed positions).
func _check_wide_ui() -> void:
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	var view := get_viewport().get_visible_rect()
	_require(view.size.x > view.size.y, "La ventana de prueba está apaisada")
	UIThemeHelper.fit_canvas(get_window())
	_require(get_window().content_scale_size == UIThemeHelper.LANDSCAPE_CANVAS, "El lienzo usa la escala apaisada")
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.play_level("europe_4")
	GameManager.coins = 420
	var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var play = menu._content.get_child(0)
	_require(not play._split.vertical, "Jugar presenta mapa y ficha en dos columnas")
	_require(play._side.get_global_rect().end.x <= view.end.x + 1.0, "La ficha lateral no sale de la pantalla")
	_require(play._side.get_global_rect().end.y <= menu._nav["play"].get_global_rect().position.y + 1.0,
		"La ficha lateral termina antes de la barra inferior: %s / %s" % [play._side.get_global_rect(), menu._nav["play"].get_global_rect()])
	await _snapshot("wide_menu")
	var conquest_before: int = GameManager.conquest_next
	var touch_pos: Vector2 = play.btn_conquest.get_global_rect().get_center() * Vector2(DisplayServer.window_get_size()) / view.size
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = touch_pos
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var drag := InputEventMouseMotion.new()
	drag.position = touch_pos - Vector2(0, 160)
	drag.relative = Vector2(0, -160)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(drag)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = drag.position
	Input.parse_input_event(release)
	await get_tree().process_frame
	_require(play.btn_conquest.get_global_rect().end.y <= menu._nav["play"].get_global_rect().position.y + 1.0
		and play.btn_daily.get_global_rect().end.y <= menu._nav["play"].get_global_rect().position.y + 1.0,
		"Conquista y diario quedan visibles en la columna lateral sin desplazar")
	_require(GameManager.conquest_next == conquest_before, "Desplazarse sobre la ficha no inicia conquista")
	menu.queue_free()
	await get_tree().process_frame
	GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
	var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	_require(battle.level_data["map_rect"] == LevelGenerator.LANDSCAPE_MAP_RECT, "La batalla crea el tablero apaisado")
	_require(battle.camera.position == LevelGenerator.LANDSCAPE_MAP_RECT.get_center(), "La cámara centra el tablero apaisado")
	var shown: Vector2 = battle.map_rect.size * battle.camera.zoom.x
	_require(shown.x <= view.size.x + 1.0 and shown.y <= view.size.y + 1.0, "El tablero cabe en la ventana apaisada")
	await _snapshot("wide_battle")
	var hud: BattleHUD = battle.get_node("BattleHUD")
	battle.is_game_over = true
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 170, "xp": 60, "level_id": "europe_4"})
	await get_tree().create_timer(0.25).timeout
	var modal_rect := hud.victory_panel.get_global_rect()
	_require(modal_rect.position.x >= 0.0 and modal_rect.position.y >= 0.0
		and modal_rect.end.x <= view.end.x and modal_rect.end.y <= view.end.y,
		"La ficha de victoria apaisada cabe entera")
	await _snapshot("wide_victory")
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	await get_tree().process_frame
	view = get_viewport().get_visible_rect()
	shown = battle.map_rect.size * battle.camera.zoom.x
	_require(battle.level_data["map_rect"] == LevelGenerator.MAP_RECT, "Girar recoloca el tablero en vertical sin reiniciar")
	_require(shown.x <= view.size.x + 1.0 and shown.y <= view.size.y + 1.0, "La cámara vuelve a encajar el tablero al girar")
	modal_rect = hud.victory_panel.get_global_rect()
	_require(modal_rect.position.x >= 0.0 and modal_rect.position.y >= 0.0
		and modal_rect.end.x <= view.end.x and modal_rect.end.y <= view.end.y,
		"La ficha de victoria vuelve a caber en vertical al girar")
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	battle.free()
	var daily_id := DailyRewards.challenge_id(DailyRewards.today())
	GameManager.play_level(daily_id)
	var daily_battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
	add_child(daily_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	var canonical_daily := LevelDatabase.get_level_data(daily_id)
	_require(daily_battle.level_data["map_rect"] == LevelGenerator.MAP_RECT,
		"El desafío diario conserva el mismo tablero de simulación en apaisado")
	_require(daily_battle.level_data["bases"].map(func(base): return base["pos"])
		== canonical_daily["bases"].map(func(base): return base["pos"]),
		"El desafío diario conserva las distancias comparables en apaisado")
	daily_battle.free()
	GameManager.play_level("europe_4")
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

## Phone rotation mid-battle and mid-menu (1080×2340 ↔ 2340×1080), as reported from Android.
func _check_rotate_ui() -> void:
	const PORTRAIT := Vector2i(1080, 2340)
	const LANDSCAPE := Vector2i(2340, 1080)
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.play_level("europe_4")
	GameManager.coins = 420
	await _resize(LANDSCAPE)
	var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
	add_child(menu)
	for size in [LANDSCAPE, PORTRAIT, LANDSCAPE]:
		await _resize(size)
		await get_tree().process_frame
		var play = menu._content.get_child(0)
		var nav_top: float = menu._nav["play"].get_global_rect().position.y
		for card in [play.btn_conquest, play.btn_daily, play.btn_start_level]:
			_require(card.get_global_rect().end.y <= nav_top + 1.0 and card.size.y <= 260.0 and card.is_visible_in_tree(),
				"Visible sin desplazar y con su alto (%s): %s / nav %s" % [size, card.get_global_rect(), nav_top])
			_require(play._side.is_ancestor_of(card), "Los atajos siguen en la columna de la ficha (%s)" % size)
		if size.x > size.y:
			_require(play._side.scroll_vertical == 0 and play._side.get_child(0).get_combined_minimum_size().y <= play._side.size.y,
				"La columna lateral cabe sin desplazar (%s): min %s / alto %s, desc %s chips %s regla %s" % [size, play._side.get_child(0).get_combined_minimum_size().y, play._side.size.y, play.level_desc.visible, play.level_chips.visible, play.level_rule.visible])
			play.btn_details.pressed.emit()
			await get_tree().process_frame
			_require(play.level_desc.visible and play.level_chips.visible, "Más detalles muestra lo plegado (%s)" % size)
			play.btn_details.pressed.emit()
			await _settle()
	await _snapshot("rotate_menu")
	menu.free()
	GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
	await _resize(PORTRAIT)
	var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.set_simulation_paused(true)
	var hud: BattleHUD = battle.get_node("BattleHUD")
	var start_troops: Array = battle.bases.map(func(b): return b.troops)
	var home: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)[0]
	var far: BaseNode = battle.bases.reduce(func(a, b): return b if b.global_position.distance_to(home.global_position) > a.global_position.distance_to(home.global_position) else a)
	_require(battle.dispatch_troops(home, far), "Se puede enviar una columna antes de girar")
	var column: Troop = battle.active_troops.back()
	await _resize(LANDSCAPE)
	var on_route := Geometry2D.get_closest_point_to_segment(column.global_position, home.global_position, far.global_position)
	_require(is_instance_valid(column) and column.global_position.distance_to(on_route) < 1.0 and column.target_base == far,
		"La columna en marcha sigue su ruta tras girar: %s" % column.global_position)
	start_troops = battle.bases.map(func(b): return b.troops)
	for size in [LANDSCAPE, PORTRAIT, LANDSCAPE]:
		await _resize(size)
		var view := get_viewport().get_visible_rect()
		var landscape: bool = size.x > size.y
		_require((battle.map_rect == LevelGenerator.LANDSCAPE_MAP_RECT) == landscape, "El tablero sigue la orientación (%s)" % size)
		var hud_bottom: float = hud.top_bar.get_global_rect().end.y
		for base in battle.bases:
			var p: Vector2 = battle.get_viewport().get_canvas_transform() * base.global_position
			_require(view.grow(-8).has_point(p) and p.y - 40.0 > hud_bottom,
				"La base %s se ve bajo el HUD tras girar (%s): %s, HUD %s" % [base.name, size, p, hud_bottom])
		_require(battle.bases.map(func(b): return b.troops) == start_troops, "Girar conserva las tropas")
		await _snapshot("rotate_battle_%s" % ("l" if landscape else "p"))
	for size in [PORTRAIT, LANDSCAPE, PORTRAIT]:
		hud._on_pause_pressed()
		await _resize(size)
		await get_tree().create_timer(0.3, true, false, true).timeout
		_require_modal_fills(hud.pause_panel, "pausa %s" % size)
		await _snapshot("rotate_pause_%s" % ("l" if size.x > size.y else "p"))
		hud._on_resume_pressed()
		await get_tree().create_timer(0.3, true, false, true).timeout
	battle.is_game_over = true
	hud.deploy_victory_modal({"stars": 3, "gold_earned": 170, "xp": 60, "level_id": "europe_4"})
	for size in [PORTRAIT, LANDSCAPE, PORTRAIT]:
		await _resize(size)
		await get_tree().create_timer(0.3, true, false, true).timeout
		_require_modal_fills(hud.victory_panel, "victoria %s" % size)
		await _snapshot("rotate_victory_%s" % ("l" if size.x > size.y else "p"))
	battle.free()
	_completed = true

## Finger gestures sent through the real window (press → moves → release), in both orientations:
## scrolling pages, dragging troops between bases, and an idle layout that stops re-sorting.
func _check_gestures() -> void:
	GameManager._apply_save({})
	GameManager.has_started = true
	GameManager.play_level("europe_4")
	GameManager.seen_tips = ["factory", "fortress", "drag", "rival_0"]
	for size in [Vector2i(1080, 2340), Vector2i(2340, 1080)]:
		await _resize(size)
		var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
		add_child(menu)
		await _settle()
		var menu_sorts := await _idle_sorts(menu)
		_require(menu_sorts == 0, "El menú en reposo no se recoloca cada fotograma (%s): %d" % [size, menu_sorts])
		menu._open_settings()
		await _settle()
		var scroll: ScrollContainer = menu._utility_panel.find_children("*", "ScrollContainer", true, false)[0]
		var center := scroll.get_global_rect().get_center()
		for touch in [true, false]:
			scroll.scroll_vertical = 0
			await _swipe(center + Vector2(0, 300), center - Vector2(0, 300), touch)
			_require(scroll.scroll_vertical > 0, "Deslizar desplaza los ajustes (%s, táctil=%s)" % [size, touch])
		menu.free()
		var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
		add_child(battle)
		await _settle()
		battle.set_simulation_paused(true)
		var hud: BattleHUD = battle.get_node("BattleHUD")
		_require(await _idle_sorts(hud) == 0, "El HUD en reposo no se recoloca cada fotograma (%s)" % size)
		var home: BaseNode = battle.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)[0]
		var target: BaseNode = battle.bases.filter(func(b): return b.faction != GameManager.Faction.PLAYER)[0]
		var to_screen := battle.get_viewport().get_canvas_transform()
		for touch in [true, false]:
			var sent := battle.active_troops.size()
			home.troops = 30
			await _swipe(to_screen * home.global_position, to_screen * target.global_position, touch)
			_require(battle.active_troops.size() > sent, "Arrastrar de una base a otra envía tropas (%s, táctil=%s)" % [size, touch])
		battle.free()
	_completed = true

func _settle() -> void:
	for i in 6:
		await get_tree().process_frame

## Controls re-sorted during 20 idle frames: a layout feedback loop keeps this above zero.
func _idle_sorts(root: Node) -> int:
	var count := [0]
	var bump := func(): count[0] += 1
	var containers := root.find_children("*", "Container", true, false)
	for c in containers:
		c.sort_children.connect(bump)
	for i in 20:
		await get_tree().process_frame
	for c in containers:
		if is_instance_valid(c):
			c.sort_children.disconnect(bump)
	return count[0]

## Press, move in steps and release, in canvas coordinates. `touch` sends what Android sends
## (screen touch/drag; Godot derives mouse events from them); otherwise a desktop mouse.
func _swipe(from: Vector2, to: Vector2, touch := true) -> void:
	var to_window := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
	_send_point(from * to_window, true, touch)
	await get_tree().process_frame
	var last := from
	for i in range(1, 9):
		var p := from.lerp(to, i / 8.0)
		if touch:
			var drag := InputEventScreenDrag.new()
			drag.position = p * to_window
			drag.relative = (p - last) * to_window
			drag.screen_relative = drag.relative
			Input.parse_input_event(drag)
		else:
			var motion := InputEventMouseMotion.new()
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			motion.position = p * to_window
			motion.global_position = motion.position
			motion.relative = (p - last) * to_window
			Input.parse_input_event(motion)
		last = p
		if touch:
			# Android re-emits size changes (system bars, insets) while a finger is down.
			get_viewport().size_changed.emit()
		await get_tree().process_frame
	_send_point(to * to_window, false, touch)
	await get_tree().process_frame
	await get_tree().process_frame

func _send_point(pos: Vector2, pressed: bool, touch: bool) -> void:
	if touch:
		var t := InputEventScreenTouch.new()
		t.position = pos
		t.pressed = pressed
		Input.parse_input_event(t)
		return
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.position = pos
	b.global_position = pos
	Input.parse_input_event(b)

func _resize(size: Vector2i) -> void:
	get_window().size = size
	UIThemeHelper.fit_canvas(get_window())
	for i in 4:
		await get_tree().process_frame

## A modal fits the screen, its content spans its width and it has no empty tail below the content.
func _require_modal_fills(panel: Control, label: String) -> void:
	var view := get_viewport().get_visible_rect()
	var rect := panel.get_global_rect()
	var content := (panel.find_child("PanelScroll", true, false) as ScrollContainer).get_child(0) as Control
	var inner := content.get_global_rect()
	_require(view.encloses(rect), "La ficha cabe (%s): %s / %s" % [label, rect, view])
	_require(inner.size.x >= rect.size.x - 160.0, "El contenido ocupa el ancho (%s): %s / %s" % [label, inner, rect])
	_require(rect.end.y - inner.end.y <= 120.0 or inner.end.y > rect.end.y, "Sin hueco bajo el contenido (%s): %s / %s" % [label, inner, rect])

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
