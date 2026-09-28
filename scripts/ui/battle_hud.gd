extends CanvasLayer
class_name BattleHUD

## BattleHUD: Interfaz táctica durante la batalla (barra de dominancia, estados y modales animados)

const DOMINANCE_BAR_WIDTH := 800.0
const DOMINANCE_UPDATE_INTERVAL := 0.1
const ENEMY_FACTIONS = [GameManager.Faction.ENEMY_1, GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]

@export var battle_controller: BattleController

@onready var top_bar: Control = $TopBar
@onready var label_level_name: Label = %LevelNameLabel
@onready var label_coins: Label = %CoinsLabel
@onready var bar_player: ColorRect = %BarPlayer
@onready var bar_enemy: ColorRect = %BarEnemy
@onready var bar_neutral: ColorRect = %BarNeutral
@onready var leader_crown: Label = %LeaderCrown
@onready var label_count_player: Label = %LabelCountPlayer
@onready var label_count_enemy: Label = %LabelCountEnemy
@onready var label_count_neutral: Label = %LabelCountNeutral
@onready var faction_counts_container: HBoxContainer = %FactionCountsContainer
@onready var dim_overlay: ColorRect = %DimOverlay

# Modales
@onready var victory_panel: Control = %VictoryPanel
@onready var victory_title: Label = %VictoryTitle
@onready var stars_container: HBoxContainer = %StarsContainer
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var victory_reward_label: Label = %VictoryRewardLabel
@onready var confetti_overlay: Control = %ConfettiOverlay
@onready var btn_next_level: Button = %BtnNextLevel
@onready var btn_victory_map: Button = %BtnVictoryMap

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
@onready var btn_pause_map: Button = %BtnPauseMap

var crown_bob_time: float = 0.0
var target_crown_x: float = 0.0
var current_crown_x: float = 0.0
var leader_faction: int = GameManager.Faction.PLAYER

var confetti_pieces: Array = []
var _star_tweens: Array[Tween] = []
var _faction_bars: Dictionary = {}
var _dominance_timer: float = 0.0
var _tip_panel: Control = null
var _tip_on_close: Callable = Callable()

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
	_apply_visual_styling()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIThemeHelper.apply_safe_area_top(top_bar)
	confetti_overlay.draw.connect(_draw_confetti)
	_build_faction_bars()

	_update_coins(GameManager.coins)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)

	btn_pause.pressed.connect(func():
		AudioManager.play_click()
		_on_pause_pressed())
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_pause_retry.pressed.connect(_on_retry_pressed)
	btn_pause_map.pressed.connect(_on_map_pressed)
	btn_pause_sound.pressed.connect(_on_pause_sound_pressed)
	btn_pause_music.pressed.connect(_on_pause_music_pressed)
	_refresh_audio_buttons()
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	btn_defeat_map.pressed.connect(_on_map_pressed)

func _apply_visual_styling() -> void:
	UIThemeHelper.apply_stateio_button_style(btn_pause, UIThemeHelper.COLOR_BTN_SECONDARY, 14, 4)
	UIThemeHelper.apply_card_style(victory_panel, Color(0.12, 0.16, 0.22, 0.96), Color(0.25, 0.70, 0.40, 0.8), 24, 3)
	UIThemeHelper.apply_card_style(defeat_panel, Color(0.18, 0.12, 0.14, 0.96), Color(0.85, 0.25, 0.20, 0.8), 24, 3)
	UIThemeHelper.apply_card_style(pause_panel, Color(0.12, 0.15, 0.20, 0.96), Color(0.25, 0.45, 0.65, 0.8), 24, 3)
	UIThemeHelper.apply_stateio_button_style(btn_next_level, UIThemeHelper.COLOR_SUCCESS, 18, 6)
	UIThemeHelper.apply_stateio_button_style(btn_victory_map, UIThemeHelper.COLOR_PRIMARY, 16, 5)
	UIThemeHelper.apply_stateio_button_style(btn_retry, UIThemeHelper.COLOR_PRIMARY, 18, 6)
	UIThemeHelper.apply_stateio_button_style(btn_defeat_upgrade, Color(0.16, 0.50, 0.42), 16, 5)
	UIThemeHelper.apply_stateio_button_style(btn_defeat_map, Color(0.20, 0.26, 0.35), 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_resume, UIThemeHelper.COLOR_PRIMARY, 18, 6)
	UIThemeHelper.apply_stateio_button_style(btn_pause_sound, Color(0.22, 0.30, 0.40), 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_pause_music, Color(0.22, 0.30, 0.40), 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_pause_retry, Color(0.22, 0.30, 0.40), 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_pause_map, Color(0.20, 0.26, 0.35), 16, 4)

## Un segmento de la barra de dominancia por facción (las enemigas 2 y 3 se crean aquí)
func _build_faction_bars() -> void:
	_faction_bars = {
		GameManager.Faction.PLAYER: bar_player,
		GameManager.Faction.NEUTRAL: bar_neutral,
		GameManager.Faction.ENEMY_1: bar_enemy,
	}
	for f in [GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]:
		var bar = ColorRect.new()
		bar.name = "BarEnemy%d" % f
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_enemy.get_parent().add_child(bar)
		_faction_bars[f] = bar
	for f in _faction_bars:
		_faction_bars[f].color = GameManager.FACTION_COLORS[f]
		_faction_bars[f].custom_minimum_size.y = bar_player.custom_minimum_size.y

func _refresh_audio_buttons() -> void:
	btn_pause_sound.text = "🔇 SONIDO: SILENCIADO" if AudioManager.is_muted else "🔊 SONIDO: ACTIVADO"
	btn_pause_music.text = "🎵 MÚSICA: DESACTIVADA" if AudioManager.music_muted else "🎵 MÚSICA: ACTIVADA"

func _on_pause_music_pressed() -> void:
	AudioManager.play_click()
	AudioManager.toggle_music()
	_refresh_audio_buttons()

func _on_pause_sound_pressed() -> void:
	if not AudioManager.toggle_mute():
		AudioManager.play_click()
	_refresh_audio_buttons()

func _on_battle_started(level_id: String) -> void:
	label_level_name.text = LevelDatabase.get_level_data(level_id)["name"]

func _process(delta: float) -> void:
	crown_bob_time += delta
	if battle_controller:
		_dominance_timer -= delta
		if _dominance_timer <= 0.0:
			_dominance_timer = DOMINANCE_UPDATE_INTERVAL
			_update_dominance_bar()
		_animate_leader_crown()
	_update_confetti(delta)

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
		p["alpha"] = maxf(0.0, p["alpha"] - unscaled_dt * 0.35)
		if p["alpha"] <= 0.0 or p["pos"].y > 750.0:
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

func _update_dominance_bar() -> void:
	var counts: Dictionary = battle_controller.get_faction_troop_counts()
	var total := 0
	for f in counts:
		total += counts[f]
	for f in _faction_bars:
		_faction_bars[f].custom_minimum_size.x = DOMINANCE_BAR_WIDTH * (float(counts.get(f, 0)) / float(total) if total > 0 else 0.0)

	# Etiquetas numéricas con el conteo vivo de tropas por facción
	var player_count: int = counts.get(GameManager.Faction.PLAYER, 0)
	label_count_player.text = "%s: %d" % [GameManager.FACTION_NAMES[GameManager.Faction.PLAYER], player_count]
	label_count_neutral.text = "%s: %d" % [GameManager.FACTION_NAMES[GameManager.Faction.NEUTRAL], counts.get(GameManager.Faction.NEUTRAL, 0)]
	var enemy_parts: PackedStringArray = []
	for f in ENEMY_FACTIONS:
		if counts.get(f, 0) > 0 or f == GameManager.Faction.ENEMY_1:
			enemy_parts.append("%s: %d" % [GameManager.FACTION_NAMES[f], counts.get(f, 0)])
	label_count_enemy.text = "  ".join(enemy_parts)

	# Facción líder (jugador gana los empates)
	leader_faction = GameManager.Faction.PLAYER
	var best := player_count
	for f in ENEMY_FACTIONS:
		if counts.get(f, 0) > best:
			best = counts[f]
			leader_faction = f
	if best <= 0:
		leader_crown.visible = false
		return
	leader_crown.visible = true

	# Centro del segmento líder dentro de la barra
	var container = bar_player.get_parent() as Control
	var base_x = container.position.x if container.position.x > 0.0 else top_bar.size.x * 0.5 - DOMINANCE_BAR_WIDTH * 0.5
	var x = base_x
	for bar in container.get_children():
		var w = (bar as Control).custom_minimum_size.x
		if bar == _faction_bars[leader_faction]:
			x += w * 0.5
			break
		x += w
	target_crown_x = x - maxf(leader_crown.size.x, 32.0) * 0.5
	if current_crown_x == 0.0:
		current_crown_x = target_crown_x

func _animate_leader_crown() -> void:
	current_crown_x = lerpf(current_crown_x, target_crown_x, 0.25)
	leader_crown.position = Vector2(current_crown_x, 12.0 + sin(crown_bob_time * 4.0) * 2.5)

func get_leader_faction() -> int:
	return leader_faction

func _update_coins(amount: int) -> void:
	label_coins.text = UIThemeHelper.coins_text(amount)

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

	btn_next_level.visible = not stats.get("is_daily_challenge", false)
	if stats.get("is_daily_challenge", false):
		victory_title.text = "¡DESAFÍO SUPERADO!"
		victory_title.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	elif stats.get("is_continent_conquest", false):
		victory_title.text = "¡CONTINENTE CONQUISTADO!"
		victory_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		victory_title.text = "¡VICTORIA!"
		victory_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))

	var reward_text = "+%d Monedas de Oro" % stats.get("gold_earned", 0)
	if stats.get("is_replay", false):
		reward_text += "\n(recompensa reducida al repetir)"
	victory_reward_label.text = reward_text

	trigger_confetti()
	animate_stars(stats.get("stars", 1))

func trigger_confetti() -> void:
	confetti_pieces.clear()
	var colors = [
		Color(1.0, 0.84, 0.0),   # Oro brillante
		Color(0.13, 0.59, 0.95), # Azul celeste
		Color(0.96, 0.26, 0.21), # Rojo carmesí
		Color(0.30, 0.69, 0.31), # Verde esmeralda
		Color(1.0, 0.40, 0.80),  # Rosa neón
		Color(1.0, 1.0, 1.0)     # Blanco puro
	]
	for i in 75:
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		var spd = randf_range(320.0, 780.0)
		confetti_pieces.append({
			"pos": Vector2(randf_range(40, 800), randf_range(120, 260)),
			"vel": Vector2.from_angle(angle) * spd,
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-7.0, 7.0),
			"wobble": randf_range(0.0, TAU),
			"wobble_speed": randf_range(5.0, 12.0),
			"size": Vector2(randf_range(12, 18), randf_range(6, 10)),
			"color": colors[i % colors.size()],
			"alpha": 1.0
		})

func animate_stars(stars_count: int) -> void:
	for t in _star_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_star_tweens.clear()

	var stars: Array[Label] = [star_1, star_2, star_3]
	for i in stars.size():
		var s = stars[i]
		if i < stars_count:
			s.text = "⭐"
			s.modulate = Color(1, 1, 1, 0.0)
			s.scale = Vector2.ZERO
		else:
			s.text = "★"
			s.modulate = Color(0.4, 0.4, 0.4, 0.35)
			s.scale = Vector2.ONE

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
		t.tween_interval(0.25 + i * 0.35)
		t.tween_callback(AudioManager.play_star_reveal.bind(i))
		t.tween_property(s, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(s, "scale", Vector2(1.35, 1.35), 0.22)
		t.tween_property(s, "scale", Vector2.ONE, 0.15)

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
	if is_instance_valid(_tip_panel):
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
	_tip_panel = UIThemeHelper.create_modal_card(title, body, "¡ENTENDIDO!", _close_tip_card)
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
	var next_id = GameManager.get_next_level(battle_controller.level_id)
	if next_id == "":
		_on_map_pressed()
		return
	GameManager.play_level(next_id)
	_leave_battle()

func _on_map_pressed() -> void:
	_leave_battle("res://scenes/ui/world_map.tscn")

func _on_upgrade_pressed() -> void:
	_leave_battle("res://scenes/ui/upgrade_menu.tscn")
