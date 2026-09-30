extends CanvasLayer
class_name BattleHUD

## BattleHUD: cabecera de batalla (pausa, nivel y reloj de estrellas), fuerza de cada bando
## y las capas de pausa, victoria y derrota.

const DOMINANCE_UPDATE_INTERVAL := 0.1
const ENEMY_FACTIONS = [GameManager.Faction.ENEMY_1, GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]

@export var battle_controller: BattleController

@onready var top_bar: Control = $TopBar
@onready var label_level_name: Label = %LevelNameLabel
@onready var label_rule: Label = %RuleLabel
@onready var label_target_time: Label = %TargetTimeLabel
@onready var bar_player: ColorRect = %BarPlayer
@onready var bar_enemy: ColorRect = %BarEnemy
@onready var bar_neutral: ColorRect = %BarNeutral
@onready var label_count_player: Label = %LabelCountPlayer
@onready var label_count_enemy: Label = %LabelCountEnemy
@onready var label_count_neutral: Label = %LabelCountNeutral
@onready var faction_counts_container: HBoxContainer = %FactionCountsContainer
@onready var dim_overlay: ColorRect = %DimOverlay

@onready var victory_panel: Control = %VictoryPanel
@onready var victory_title: Label = %VictoryTitle
@onready var stars_container: HBoxContainer = %StarsContainer
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var victory_reward_label: Label = %VictoryRewardLabel
@onready var stat_time_value: Label = %StatTimeValue
@onready var stat_cities_value: Label = %StatCitiesValue
@onready var victory_note: Label = %VictoryNote
@onready var confetti_overlay: Control = %ConfettiOverlay
@onready var btn_next_level: Button = %BtnNextLevel
@onready var btn_victory_map: Button = %BtnVictoryMap
@onready var btn_share: Button = %BtnShare

@onready var defeat_panel: Control = %DefeatPanel
@onready var btn_retry: Button = %BtnRetry
@onready var btn_defeat_upgrade: Button = %BtnDefeatUpgrade
@onready var btn_defeat_map: Button = %BtnDefeatMap

@onready var pause_panel: Control = %PausePanel
@onready var btn_pause: Button = %BtnPause
@onready var btn_resume: Button = %BtnResume
@onready var btn_pause_sound: Button = %BtnPauseSound
@onready var btn_pause_music: Button = %BtnPauseMusic
@onready var btn_pause_retry: Button = %BtnPauseRetry
@onready var btn_how_to_play: Button = %BtnHowToPlay
@onready var btn_settings: Button = %BtnSettings
@onready var btn_pause_map: Button = %BtnPauseMap

var confetti_pieces: Array = []
var _star_tweens: Array[Tween] = []
var _faction_bars: Dictionary = {}
var _dominance_timer: float = 0.0
var _tip_panel: Control = null
var _tip_on_close: Callable = Callable()
## Sólo actualiza la etiqueta cuando cambia el segundo mostrado.
var _last_shown_second: int = -999
var _utility_panel: Control = null
var _share_result: Dictionary = {}

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_requested()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Pausa automática al salir de la app (llamada entrante, cambio de app...)
			if _can_pause():
				_on_pause_pressed()

func _exit_tree() -> void:
	_cleanup_time_scale()

func _cleanup_time_scale() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(battle_controller):
		battle_controller.reset_time_scale()

func _ready() -> void:
	_apply_texts()
	UIThemeHelper.apply_safe_area_top(top_bar)
	confetti_overlay.draw.connect(_draw_confetti)
	for entry in [[btn_pause, "pause"], [btn_pause_sound, "sound"], [btn_pause_music, "music"], [btn_resume, "play"],
			[btn_retry, "retry"], [btn_next_level, "play"], [btn_how_to_play, "help"], [btn_settings, "gear"], [btn_share, "share"]]:
		entry[0].icon = Icons.texture(entry[1], 44)
	_build_faction_bars()

	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.settings_changed.connect(_refresh_palette)

	btn_pause.pressed.connect(func():
		AudioManager.play_click()
		_on_pause_pressed())
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_pause_retry.pressed.connect(_on_retry_pressed)
	btn_pause_map.pressed.connect(_on_map_pressed)
	btn_pause_sound.pressed.connect(_on_pause_sound_pressed)
	btn_pause_music.pressed.connect(_on_pause_music_pressed)
	btn_how_to_play.pressed.connect(func():
		AudioManager.play_click()
		add_child(UIThemeHelper.how_to_play_card()))
	btn_settings.pressed.connect(_open_settings)
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_share.pressed.connect(_open_share)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	btn_defeat_map.pressed.connect(_on_map_pressed)
	_refresh_audio_buttons()

## Textos estáticos de capas y botones en el idioma actual
func _apply_texts() -> void:
	btn_share.text = LocaleStrings.text("share")
	btn_victory_map.text = LocaleStrings.text("exit")
	%StatTimeCaption.text = LocaleStrings.text("stat_time")
	%StatGoldCaption.text = LocaleStrings.text("stat_gold")
	%StatCitiesCaption.text = LocaleStrings.text("stat_new_cities")
	defeat_panel.get_node("VBox/Title").text = LocaleStrings.text("defeat_title")
	defeat_panel.get_node("VBox/Subtitle").text = LocaleStrings.text("defeat_sub")
	btn_retry.text = LocaleStrings.text("retry")
	btn_defeat_upgrade.text = LocaleStrings.text("improve")
	btn_defeat_map.text = LocaleStrings.text("exit")
	pause_panel.get_node("VBox/Title").text = LocaleStrings.text("pause")
	btn_resume.text = LocaleStrings.text("resume")
	btn_pause_retry.text = LocaleStrings.text("restart_battle")
	btn_how_to_play.text = LocaleStrings.text("how_to_play")
	btn_settings.text = LocaleStrings.text("settings")
	btn_pause_map.text = LocaleStrings.text("exit")
	btn_pause.tooltip_text = LocaleStrings.text("pause")

## Un segmento de la barra de fuerzas por facción (las enemigas 2 y 3 se crean aquí).
## Cada segmento ocupa una parte del ancho proporcional a sus tropas (stretch ratio).
func _build_faction_bars() -> void:
	_faction_bars = {
		GameManager.Faction.PLAYER: bar_player,
		GameManager.Faction.NEUTRAL: bar_neutral,
		GameManager.Faction.ENEMY_1: bar_enemy,
	}
	for f in [GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]:
		var bar := ColorRect.new()
		bar.name = "BarEnemy%d" % f
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.visible = false
		bar_enemy.get_parent().add_child(bar)
		_faction_bars[f] = bar
	_refresh_palette()

func _refresh_palette() -> void:
	for faction in _faction_bars:
		_faction_bars[faction].color = GameManager.faction_color(faction)
	label_count_player.add_theme_color_override("font_color", GameManager.faction_color(GameManager.Faction.PLAYER).lightened(0.25))
	label_count_enemy.add_theme_color_override("font_color", GameManager.faction_color(GameManager.Faction.ENEMY_1).lightened(0.25))

func _refresh_audio_buttons() -> void:
	btn_pause_sound.modulate.a = 0.4 if AudioManager.is_muted else 1.0
	btn_pause_sound.tooltip_text = LocaleStrings.text("sound_off" if AudioManager.is_muted else "sound_on")
	btn_pause_music.modulate.a = 0.4 if AudioManager.music_muted else 1.0
	btn_pause_music.tooltip_text = LocaleStrings.text("music_off" if AudioManager.music_muted else "music_on")

func _on_pause_music_pressed() -> void:
	AudioManager.play_click()
	AudioManager.toggle_music()
	_refresh_audio_buttons()

func _on_pause_sound_pressed() -> void:
	if not AudioManager.toggle_mute():
		AudioManager.play_click()
	_refresh_audio_buttons()

func _open_settings() -> void:
	if is_instance_valid(_utility_panel):
		return
	_utility_panel = load("res://scripts/ui/settings_panel.gd").new()
	_utility_panel.allow_backups = false # No reemplazar una partida mientras su batalla vive.
	_utility_panel.closed.connect(func():
		_apply_texts()
		_refresh_audio_buttons()
		if is_instance_valid(battle_controller):
			_on_battle_started(battle_controller.level_id)
			for base in battle_controller.bases:
				if base.label_name:
					base.label_name.text = GeoDatabase.city_name(GeoDatabase.get_city(base.city_key)))
	add_child(_utility_panel)

func _open_share() -> void:
	if is_instance_valid(_utility_panel):
		return
	var text := DailyShare.text(_share_result)
	_utility_panel = UIThemeHelper.create_modal_card("invade.io", text, LocaleStrings.text("copy"), func():
		DisplayServer.clipboard_set(text)
		Toasts.show_toast("✅", "invade.io", LocaleStrings.text("copied")), true)
	_utility_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_utility_panel)
	var confirm: Button = _utility_panel.find_child("BtnConfirm", true, false)
	var back := UIThemeHelper.button(LocaleStrings.text("back"), "GhostButton")
	back.pressed.connect(_utility_panel.queue_free)
	confirm.get_parent().add_child(back)

func _on_battle_started(level_id: String) -> void:
	var data := LevelDatabase.get_level_data(level_id)
	label_level_name.text = data["name"]
	label_rule.text = CampaignRules.description(data).strip_edges()
	label_rule.visible = label_rule.text != ""
	_last_shown_second = -999
	_update_target_time()

func _process(delta: float) -> void:
	if battle_controller:
		_dominance_timer -= delta
		if _dominance_timer <= 0.0:
			_dominance_timer = DOMINANCE_UPDATE_INTERVAL
			_update_dominance_bar()
		if not battle_controller.is_game_over:
			_update_target_time()
	_update_confetti(delta)

## Estrellas que aún se consiguen y segundos que quedan para conservarlas (3★ → 2★ → 1★)
func _update_target_time() -> void:
	if not is_instance_valid(battle_controller):
		return
	var target := battle_controller.target_time
	var elapsed := battle_controller.battle_time
	var stars := 3 if elapsed <= target else (2 if elapsed <= target * 1.5 else 1)
	var limit := target if stars == 3 else target * 1.5
	var remaining := roundi(limit - elapsed) if stars > 1 else -1
	var key := stars * 10000 + remaining
	if key == _last_shown_second:
		return
	_last_shown_second = key
	label_target_time.text = "★".repeat(stars) + (" %ds" % remaining if remaining >= 0 else "")
	label_target_time.add_theme_color_override("font_color", UIThemeHelper.COLOR_GOLD if stars == 3 else UIThemeHelper.COLOR_GOLD.lerp(UIThemeHelper.COLOR_MUTED, 0.5 if stars == 2 else 1.0))

## Reparto de tropas en juego (bases + hileras) de cada bando
func _update_dominance_bar() -> void:
	var counts: Dictionary = battle_controller.get_faction_troop_counts()
	for f in _faction_bars:
		var n: int = counts.get(f, 0)
		_faction_bars[f].visible = n > 0
		_faction_bars[f].size_flags_stretch_ratio = maxf(n, 0.001)
	var player_count: int = counts.get(GameManager.Faction.PLAYER, 0)
	label_count_player.text = "%s %d" % [GameManager.faction_name(GameManager.Faction.PLAYER), player_count]
	label_count_neutral.text = "%s %d" % [GameManager.faction_name(GameManager.Faction.NEUTRAL), counts.get(GameManager.Faction.NEUTRAL, 0)]
	var enemy_parts: PackedStringArray = []
	for f in ENEMY_FACTIONS:
		if counts.get(f, 0) > 0 or f == GameManager.Faction.ENEMY_1:
			enemy_parts.append("%s %d" % [GameManager.faction_name(f), counts.get(f, 0)])
	label_count_enemy.text = " · ".join(enemy_parts)

func _update_confetti(delta: float) -> void:
	if confetti_pieces.is_empty():
		return
	var unscaled_dt = delta / maxf(Engine.time_scale, 0.01)
	for i in range(confetti_pieces.size() - 1, -1, -1):
		var p = confetti_pieces[i]
		p["vel"].y += 580.0 * unscaled_dt
		p["pos"] += p["vel"] * unscaled_dt
		p["rot"] += p["rot_speed"] * unscaled_dt
		p["wobble"] += p["wobble_speed"] * unscaled_dt
		p["alpha"] = maxf(0.0, p["alpha"] - unscaled_dt * 0.5)
		if p["alpha"] <= 0.0 or p["pos"].y > 900.0:
			confetti_pieces.remove_at(i)
	confetti_overlay.queue_redraw()

func _draw_confetti() -> void:
	for p in confetti_pieces:
		var half = p["size"] * 0.5 * Vector2(1.0, absf(cos(p["wobble"])))
		var xf = Transform2D(p["rot"], p["pos"])
		var quad = PackedVector2Array([
			xf * Vector2(-half.x, -half.y), xf * Vector2(half.x, -half.y),
			xf * Vector2(half.x, half.y), xf * Vector2(-half.x, half.y)
		])
		confetti_overlay.draw_colored_polygon(quad, Color(p["color"], clampf(p["alpha"], 0.0, 1.0)))

func _on_battle_won(stats: Dictionary) -> void:
	var slow_motion_on = is_instance_valid(battle_controller) and battle_controller.is_slow_motion_active
	if is_inside_tree() and (slow_motion_on or Engine.time_scale < 0.95):
		get_tree().create_timer(0.65, true, false, true).timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				deploy_victory_modal(stats)
		)
	else:
		deploy_victory_modal(stats)

func deploy_victory_modal(stats: Dictionary) -> void:
	_cleanup_time_scale()
	dim_overlay.visible = true
	UIThemeHelper.animate_modal_pop_in(victory_panel)
	var daily: bool = stats.get("is_daily_challenge", false)
	var conquest: bool = stats.get("is_conquest", false)
	btn_share.visible = daily
	if daily:
		_share_result = {"day": DailyRewards.challenge_day(str(stats.get("level_id", GameManager.get_battle_level_id()))),
			"stars": stats.get("stars", 1), "time": stats.get("time", 0.0), "speed": stats.get("speed", 1.0)}
	btn_next_level.visible = not daily
	btn_next_level.text = LocaleStrings.text("next_region" if conquest else "next_level")
	btn_victory_map.text = LocaleStrings.text("to_challenges" if daily else "exit")

	var title := ["victory", UIThemeHelper.COLOR_SUCCESS]
	if daily:
		title = ["daily_done", UIThemeHelper.COLOR_GOLD]
	elif conquest:
		title = ["conquest_done", UIThemeHelper.COLOR_PRIMARY]
	elif stats.get("is_continent_conquest", false):
		title = ["continent_conquest", UIThemeHelper.COLOR_GOLD]
	victory_title.text = LocaleStrings.text(title[0])
	victory_title.add_theme_color_override("font_color", title[1])

	stat_time_value.text = "%ds" % ceili(float(stats.get("time", 0.0)))
	victory_reward_label.text = "+%d" % stats.get("gold_earned", 0)
	stat_cities_value.text = "+%d" % stats.get("new_cities", 0)
	var note := UIThemeHelper.xp_text()
	if stats.get("is_replay", false):
		note = LocaleStrings.text("replay_note") + "\n" + note
	victory_note.text = note

	trigger_confetti()
	animate_stars(stats.get("stars", 1))

func trigger_confetti() -> void:
	confetti_pieces.clear()
	var colors := [UIThemeHelper.COLOR_GOLD, UIThemeHelper.COLOR_PRIMARY, UIThemeHelper.COLOR_SUCCESS, UIThemeHelper.COLOR_TEXT]
	for i in 75:
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		var spd = randf_range(320.0, 780.0)
		confetti_pieces.append({
			"pos": Vector2(randf_range(60, 840), randf_range(120, 260)),
			"vel": Vector2.from_angle(angle) * spd,
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-7.0, 7.0),
			"wobble": randf_range(0.0, TAU),
			"wobble_speed": randf_range(5.0, 12.0),
			"size": Vector2(randf_range(12, 18), randf_range(6, 10)),
			"color": colors[i % colors.size()],
			"alpha": 1.0
		})

## Estrellas ganadas en oro (aparecen una a una) y las pendientes como contorno apagado
func animate_stars(stars_count: int) -> void:
	for t in _star_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_star_tweens.clear()

	var stars: Array[Label] = [star_1, star_2, star_3]
	for i in stars.size():
		var s := stars[i]
		var earned := i < stars_count
		s.text = "★" if earned else "☆"
		s.add_theme_color_override("font_color", UIThemeHelper.COLOR_GOLD if earned else UIThemeHelper.COLOR_LINE)
		s.modulate = Color(1, 1, 1, 0.0 if earned else 1.0)
		s.scale = Vector2.ZERO if earned else Vector2.ONE

	if not is_inside_tree():
		for i in mini(stars_count, stars.size()):
			stars[i].modulate = Color.WHITE
			stars[i].scale = Vector2.ONE
		return

	for i in mini(stars_count, stars.size()):
		var s = stars[i]
		s.pivot_offset = s.size * 0.5
		var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_star_tweens.append(t)
		t.tween_interval(0.2 + i * 0.25)
		t.tween_callback(AudioManager.play_star_reveal.bind(i))
		t.tween_property(s, "modulate:a", 1.0, 0.1)
		t.parallel().tween_property(s, "scale", Vector2.ONE, 0.25)

func _on_battle_lost() -> void:
	_cleanup_time_scale()
	dim_overlay.visible = true
	UIThemeHelper.animate_modal_pop_in(defeat_panel)

# =========================================================================
# Pausa, botón "atrás" de Android y tarjetas de ayuda
# =========================================================================

func _can_pause() -> bool:
	return is_inside_tree() and not get_tree().paused and not victory_panel.visible and not defeat_panel.visible \
		and not (is_instance_valid(battle_controller) and battle_controller.is_game_over)

func _on_back_requested() -> void:
	if is_instance_valid(_utility_panel):
		if _utility_panel.has_method("_close"):
			_utility_panel._close()
		else:
			_utility_panel.queue_free()
	elif is_instance_valid(_tip_panel):
		_close_tip_card()
	elif pause_panel.visible:
		_on_resume_pressed()
	elif victory_panel.visible or defeat_panel.visible:
		_on_map_pressed()
	elif _can_pause():
		_on_pause_pressed()

## También se llama al perder el foco la app, sin clic
func _on_pause_pressed() -> void:
	_cleanup_time_scale()
	_refresh_audio_buttons()
	dim_overlay.visible = true
	UIThemeHelper.animate_modal_pop_in(pause_panel)
	get_tree().paused = true

func _on_resume_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	UIThemeHelper.animate_modal_pop_out(pause_panel, func():
		dim_overlay.visible = false
		get_tree().paused = false
	)

## Tarjeta modal explicativa (pausa la batalla hasta que el jugador la cierra)
func show_tip_card(title: String, body: String, on_close: Callable = Callable()) -> void:
	if is_instance_valid(_tip_panel):
		_tip_panel.queue_free()
	_tip_on_close = on_close
	_tip_panel = UIThemeHelper.create_modal_card(title, body, LocaleStrings.text("tip_ok"), _close_tip_card)
	add_child(_tip_panel)
	dim_overlay.visible = true
	get_tree().paused = true

func _close_tip_card() -> void:
	AudioManager.play_click()
	if is_instance_valid(_tip_panel):
		_tip_panel.queue_free()
	_tip_panel = null
	dim_overlay.visible = false
	get_tree().paused = false
	var cb = _tip_on_close
	_tip_on_close = Callable()
	if cb.is_valid():
		cb.call()

func _leave_battle(scene_path: String = "") -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	get_tree().paused = false
	if scene_path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)

func _on_retry_pressed() -> void:
	_leave_battle()

func _on_next_level_pressed() -> void:
	if LevelGenerator.is_conquest(battle_controller.level_id):
		GameManager.play_conquest(LevelGenerator.conquest_index(battle_controller.level_id) + 1)
		_leave_battle()
		return
	var next_id = GameManager.get_next_level(battle_controller.level_id)
	if next_id == "":
		_on_map_pressed()
		return
	GameManager.play_level(next_id)
	_leave_battle()

## Sección del menú a la que se vuelve: el desafío diario vive en Retos, el resto en Jugar
func exit_tab() -> String:
	var daily := is_instance_valid(battle_controller) and DailyRewards.is_challenge(battle_controller.level_id)
	return "challenges" if daily else "play"

func _on_map_pressed() -> void:
	MainMenuUI.next_tab = exit_tab()
	_leave_battle(MainMenuUI.SCENE)

## Tras una derrota, Ejército muestra un acceso directo para volver a esta misma batalla
func _on_upgrade_pressed() -> void:
	MainMenuUI.next_tab = "army"
	MainMenuUI.return_to_battle = true
	_leave_battle(MainMenuUI.SCENE)
