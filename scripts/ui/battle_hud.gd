extends CanvasLayer
class_name BattleHUD

## BattleHUD: Interfaz en pantalla durante la batalla (barra de dominancia, estados y modales)

@export var battle_controller: BattleController

@onready var label_level_name: Label = %LevelNameLabel
@onready var label_coins: Label = %CoinsLabel
@onready var bar_player: ColorRect = %BarPlayer
@onready var bar_enemy: ColorRect = %BarEnemy
@onready var bar_neutral: ColorRect = %BarNeutral

# Modales
@onready var victory_panel: Control = %VictoryPanel
@onready var victory_title: Label = %VictoryTitle
@onready var stars_container: HBoxContainer = %StarsContainer
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var victory_stars_label: Label = %VictoryStarsLabel
@onready var victory_reward_label: Label = %VictoryRewardLabel
@onready var confetti_particles: CPUParticles2D = %ConfettiParticles
@onready var btn_next_level: Button = %BtnNextLevel
@onready var btn_victory_map: Button = %BtnVictoryMap

@onready var defeat_panel: Control = %DefeatPanel
@onready var btn_retry: Button = %BtnRetry
@onready var btn_defeat_upgrade: Button = %BtnDefeatUpgrade

@onready var pause_panel: Control = %PausePanel
@onready var btn_pause: Button = %BtnPause
@onready var btn_resume: Button = %BtnResume
@onready var btn_pause_retry: Button = %BtnPauseRetry
@onready var btn_pause_map: Button = %BtnPauseMap

var confetti_pieces: Array = []
var confetti_overlay: Control = null
var _star_tweens: Array[Tween] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_time_scale()

func _exit_tree() -> void:
	_cleanup_time_scale()

func _cleanup_time_scale() -> void:
	Engine.time_scale = 1.0
	if battle_controller and is_instance_valid(battle_controller):
		battle_controller.reset_time_scale()

func _ensure_node_references() -> void:
	if not victory_panel:
		victory_panel = get_node_or_null("%VictoryPanel") if has_node("%VictoryPanel") else get_node_or_null("VictoryPanel")
	if not victory_title:
		victory_title = get_node_or_null("%VictoryTitle") if has_node("%VictoryTitle") else get_node_or_null("VictoryPanel/VBox/VictoryTitle")
	if not victory_reward_label:
		victory_reward_label = get_node_or_null("%VictoryRewardLabel") if has_node("%VictoryRewardLabel") else get_node_or_null("VictoryPanel/VBox/VictoryRewardLabel")
	if not victory_stars_label:
		victory_stars_label = get_node_or_null("%VictoryStarsLabel") if has_node("%VictoryStarsLabel") else get_node_or_null("VictoryPanel/VBox/VictoryStarsLabel")
	if not confetti_particles:
		confetti_particles = get_node_or_null("%ConfettiParticles") if has_node("%ConfettiParticles") else get_node_or_null("VictoryPanel/ConfettiParticles")
	if not star_1:
		star_1 = get_node_or_null("%Star1") if has_node("%Star1") else get_node_or_null("VictoryPanel/VBox/StarsContainer/Star1")
	if not star_2:
		star_2 = get_node_or_null("%Star2") if has_node("%Star2") else get_node_or_null("VictoryPanel/VBox/StarsContainer/Star2")
	if not star_3:
		star_3 = get_node_or_null("%Star3") if has_node("%Star3") else get_node_or_null("VictoryPanel/VBox/StarsContainer/Star3")
	if not pause_panel:
		pause_panel = get_node_or_null("%PausePanel") if has_node("%PausePanel") else get_node_or_null("PausePanel")
	if not defeat_panel:
		defeat_panel = get_node_or_null("%DefeatPanel") if has_node("%DefeatPanel") else get_node_or_null("DefeatPanel")
	if not confetti_overlay:
		confetti_overlay = get_node_or_null("%ConfettiOverlay") if has_node("%ConfettiOverlay") else get_node_or_null("VictoryPanel/ConfettiOverlay")
		if confetti_overlay and not confetti_overlay.draw.is_connected(_draw_confetti):
			confetti_overlay.draw.connect(_draw_confetti)

func _ready() -> void:
	_cleanup_time_scale()
	_ensure_node_references()
	# Ocultar modales al iniciar
	if victory_panel: victory_panel.visible = false
	if defeat_panel: defeat_panel.visible = false
	if pause_panel: pause_panel.visible = false
	
	_update_coins(GameManager.coins)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)
	
	# Conexión de botones
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_pause_retry.pressed.connect(_on_retry_pressed)
	btn_pause_map.pressed.connect(_on_map_pressed)
	
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	
	if battle_controller and battle_controller.level_data:
		label_level_name.text = battle_controller.level_data.get("name", "Batalla")

func _on_battle_started(level_id: String) -> void:
	var data = LevelDatabase.get_level_data(level_id)
	if label_level_name:
		label_level_name.text = data.get("name", "Batalla")

func _process(delta: float) -> void:
	if battle_controller:
		_update_dominance_bar()
	_update_confetti(delta)

func _update_confetti(delta: float) -> void:
	if confetti_pieces.is_empty():
		return
	var unscaled_dt = delta / maxf(Engine.time_scale, 0.01) if Engine.time_scale > 0.0 else delta
	var i = confetti_pieces.size() - 1
	while i >= 0:
		var p = confetti_pieces[i]
		p["vel"].y += 580.0 * unscaled_dt
		p["pos"] += p["vel"] * unscaled_dt
		p["rot"] += p["rot_speed"] * unscaled_dt
		p["wobble"] += p["wobble_speed"] * unscaled_dt
		p["alpha"] = maxf(0.0, p["alpha"] - unscaled_dt * 0.35)
		if p["alpha"] <= 0.0 or p["pos"].y > 750.0:
			confetti_pieces.remove_at(i)
		i -= 1
	if confetti_overlay and is_instance_valid(confetti_overlay):
		confetti_overlay.queue_redraw()

func _draw_confetti() -> void:
	if not confetti_overlay or confetti_pieces.is_empty():
		return
	for p in confetti_pieces:
		var col: Color = p.get("color", Color.WHITE)
		col.a = clampf(p.get("alpha", 1.0), 0.0, 1.0)
		var sz: Vector2 = p.get("size", Vector2(14, 8))
		var wobble_scale = absf(cos(p.get("wobble", 0.0)))
		var w = sz.x * 0.5
		var h = sz.y * 0.5 * wobble_scale
		var rot = p.get("rot", 0.0)
		var center = p.get("pos", Vector2.ZERO)
		
		var cos_r = cos(rot)
		var sin_r = sin(rot)
		var p1 = center + Vector2(-w * cos_r - -h * sin_r, -w * sin_r + -h * cos_r)
		var p2 = center + Vector2(w * cos_r - -h * sin_r, w * sin_r + -h * cos_r)
		var p3 = center + Vector2(w * cos_r - h * sin_r, w * sin_r + h * cos_r)
		var p4 = center + Vector2(-w * cos_r - h * sin_r, -w * sin_r + h * cos_r)
		
		confetti_overlay.draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), col)

func _update_dominance_bar() -> void:
	var ratios = battle_controller.get_dominance_ratios()
	var player_ratio = ratios.get(GameManager.Faction.PLAYER, 0.0)
	var neutral_ratio = ratios.get(GameManager.Faction.NEUTRAL, 0.0)
	var enemy_ratio = 1.0 - player_ratio - neutral_ratio
	if enemy_ratio < 0.0: enemy_ratio = 0.0
	
	var total_width = 800.0
	bar_player.custom_minimum_size.x = total_width * player_ratio
	bar_neutral.custom_minimum_size.x = total_width * neutral_ratio
	bar_enemy.custom_minimum_size.x = total_width * enemy_ratio

func _update_coins(amount: int) -> void:
	if label_coins:
		label_coins.text = "🪙 %d" % amount

func _on_battle_won(stats: Dictionary) -> void:
	var slow_motion_on = false
	if battle_controller and is_instance_valid(battle_controller):
		slow_motion_on = battle_controller.is_slow_motion_active
	# Si está activa la cámara lenta cinemática del asalto decisivo, permitir que concluya suavemente
	if is_inside_tree() and (slow_motion_on or Engine.time_scale < 0.95):
		var timer = get_tree().create_timer(0.65, true, false, true)
		timer.timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				deploy_victory_modal(stats)
		)
	else:
		deploy_victory_modal(stats)

func deploy_victory_modal(stats: Dictionary) -> void:
	# Garantizar que al desplegarse el modal de victoria, Engine.time_scale se restablezca limpiamente a 1.0
	_cleanup_time_scale()
	_ensure_node_references()
	if victory_panel:
		victory_panel.visible = true
	var stars_count = stats.get("stars", 1)
	var is_continent_conquest = stats.get("is_continent_conquest", false)
	
	if victory_title:
		if is_continent_conquest:
			victory_title.text = "¡CONTINENTE CONQUISTADO!"
			victory_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			victory_title.text = "¡VICTORIA!"
			victory_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			
	if victory_reward_label:
		victory_reward_label.text = "+%d Monedas de Oro" % stats.get("gold_earned", 0)
	
	# Disparar sistema de confeti festivo
	trigger_confetti()
	
	# Revelación animada y secuencial de estrellas
	animate_stars(stars_count)

func trigger_confetti() -> void:
	_ensure_node_references()
	if confetti_particles:
		confetti_particles.restart()
		confetti_particles.emitting = true
		
	confetti_pieces.clear()
	var colors = [
		Color(1.0, 0.84, 0.0),   # Oro brillante
		Color(0.13, 0.59, 0.95),  # Azul celeste
		Color(0.96, 0.26, 0.21),  # Rojo carmesí
		Color(0.30, 0.69, 0.31),  # Verde esmeralda
		Color(1.0, 0.40, 0.80),   # Rosa neón
		Color(1.0, 1.0, 1.0)      # Blanco puro
	]
	
	for i in range(75):
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		var spd = randf_range(320.0, 780.0)
		confetti_pieces.append({
			"pos": Vector2(randf_range(40, 800), randf_range(120, 260)),
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd),
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-7.0, 7.0),
			"wobble": randf_range(0.0, TAU),
			"wobble_speed": randf_range(5.0, 12.0),
			"size": Vector2(randf_range(12, 18), randf_range(6, 10)),
			"color": colors[i % colors.size()],
			"alpha": 1.0
		})

func animate_stars(stars_count: int) -> void:
	_ensure_node_references()
	for t in _star_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_star_tweens.clear()
	
	var stars: Array[Label] = [star_1, star_2, star_3]
	
	for i in range(stars.size()):
		var s = stars[i]
		if not is_instance_valid(s):
			continue
		if i < stars_count:
			s.text = "⭐"
			s.modulate = Color(1, 1, 1, 0.0)
			s.scale = Vector2.ZERO
		else:
			s.text = "★"
			s.modulate = Color(0.4, 0.4, 0.4, 0.35)
			s.scale = Vector2.ONE
			
	var star_str = ""
	for i in range(stars_count):
		star_str += "⭐ "
	if victory_stars_label:
		victory_stars_label.text = star_str.strip_edges()
		
	if not is_inside_tree():
		for i in range(mini(stars_count, stars.size())):
			var s = stars[i]
			if is_instance_valid(s):
				s.text = "⭐"
				s.modulate = Color.WHITE
				s.scale = Vector2.ONE
		return
		
	for i in range(mini(stars_count, stars.size())):
		var s = stars[i]
		if not is_instance_valid(s):
			continue
		var delay = 0.25 + (i * 0.35)
		var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_star_tweens.append(t)
		t.tween_interval(delay)
		var star_idx = i
		t.tween_callback(func():
			AudioManager.play_star_reveal(star_idx)
		)
		t.tween_property(s, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(s, "scale", Vector2(1.35, 1.35), 0.22)
		t.tween_property(s, "scale", Vector2.ONE, 0.15)

func _on_battle_lost() -> void:
	_cleanup_time_scale()
	_ensure_node_references()
	if defeat_panel: defeat_panel.visible = true

func _on_pause_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	_ensure_node_references()
	if pause_panel: pause_panel.visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	_ensure_node_references()
	if pause_panel: pause_panel.visible = false
	get_tree().paused = false

func _on_retry_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_next_level_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	get_tree().paused = false
	var next_id = GameManager.get_next_level(battle_controller.level_id)
	if next_id != "":
		GameManager.current_level_id = next_id
		get_tree().reload_current_scene()
	else:
		_on_map_pressed()

func _on_map_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")

func _on_upgrade_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn")
