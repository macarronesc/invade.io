extends CanvasLayer
class_name BattleHUD

const UIThemeHelper = preload("res://scripts/ui/ui_theme_helper.gd")

## BattleHUD: Interfaz táctica State.io durante la batalla (barra de dominancia, estados y modales animados)

@export var battle_controller: BattleController

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

var crown_bob_time: float = 0.0
var target_crown_x: float = 0.0
var current_crown_x: float = 0.0
var leader_faction: int = GameManager.Faction.PLAYER

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
@onready var btn_defeat_map: Button = %BtnDefeatMap

@onready var pause_panel: Control = %PausePanel
@onready var btn_pause: Button = %BtnPause
@onready var btn_resume: Button = %BtnResume
@onready var btn_pause_sound: Button = %BtnPauseSound
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
	if not dim_overlay:
		dim_overlay = get_node_or_null("%DimOverlay") if has_node("%DimOverlay") else get_node_or_null("DimOverlay")
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
	if not leader_crown:
		leader_crown = get_node_or_null("%LeaderCrown") if has_node("%LeaderCrown") else get_node_or_null("TopBar/LeaderCrown")
		if not leader_crown:
			leader_crown = Label.new()
			leader_crown.name = "LeaderCrown"
			leader_crown.text = "👑"
			var top = get_node_or_null("TopBar")
			if top: top.add_child(leader_crown)
			else: add_child(leader_crown)
	if not label_count_player:
		label_count_player = get_node_or_null("%LabelCountPlayer") if has_node("%LabelCountPlayer") else get_node_or_null("TopBar/FactionCountsContainer/LabelCountPlayer")
	if not label_count_neutral:
		label_count_neutral = get_node_or_null("%LabelCountNeutral") if has_node("%LabelCountNeutral") else get_node_or_null("TopBar/FactionCountsContainer/LabelCountNeutral")
	if not label_count_enemy:
		label_count_enemy = get_node_or_null("%LabelCountEnemy") if has_node("%LabelCountEnemy") else get_node_or_null("TopBar/FactionCountsContainer/LabelCountEnemy")
	if not faction_counts_container:
		faction_counts_container = get_node_or_null("%FactionCountsContainer") if has_node("%FactionCountsContainer") else get_node_or_null("TopBar/FactionCountsContainer")
	if not btn_defeat_map:
		btn_defeat_map = get_node_or_null("%BtnDefeatMap") if has_node("%BtnDefeatMap") else get_node_or_null("DefeatPanel/VBox/BtnDefeatMap")
	if not btn_pause_sound:
		btn_pause_sound = get_node_or_null("%BtnPauseSound") if has_node("%BtnPauseSound") else get_node_or_null("PausePanel/VBox/BtnPauseSound")

func _ready() -> void:
	_cleanup_time_scale()
	_ensure_node_references()
	_apply_visual_styling()
	
	# Ocultar modales al iniciar
	if dim_overlay: dim_overlay.visible = false
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
	if btn_pause_sound:
		btn_pause_sound.pressed.connect(_on_pause_sound_pressed)
		_update_pause_sound_label(AudioManager.is_muted)
	
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	if btn_defeat_map:
		btn_defeat_map.pressed.connect(_on_map_pressed)
	
	if battle_controller and battle_controller.level_data:
		label_level_name.text = battle_controller.level_data.get("name", "Batalla")

func _apply_visual_styling() -> void:
	if btn_pause:
		UIThemeHelper.apply_stateio_button_style(btn_pause, Color(0.18, 0.24, 0.32), Color.TRANSPARENT, 14, 4)
	if victory_panel:
		UIThemeHelper.apply_card_style(victory_panel, Color(0.12, 0.16, 0.22, 0.96), Color(0.25, 0.70, 0.40, 0.8), 24, 3)
	if defeat_panel:
		UIThemeHelper.apply_card_style(defeat_panel, Color(0.18, 0.12, 0.14, 0.96), Color(0.85, 0.25, 0.20, 0.8), 24, 3)
	if pause_panel:
		UIThemeHelper.apply_card_style(pause_panel, Color(0.12, 0.15, 0.20, 0.96), Color(0.25, 0.45, 0.65, 0.8), 24, 3)
		
	# Botones de modales
	if btn_next_level:
		UIThemeHelper.apply_stateio_button_style(btn_next_level, UIThemeHelper.COLOR_SUCCESS, Color.TRANSPARENT, 18, 6)
	if btn_victory_map:
		UIThemeHelper.apply_stateio_button_style(btn_victory_map, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 16, 5)
	if btn_retry:
		UIThemeHelper.apply_stateio_button_style(btn_retry, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 18, 6)
	if btn_defeat_upgrade:
		UIThemeHelper.apply_stateio_button_style(btn_defeat_upgrade, Color(0.16, 0.50, 0.42), Color.TRANSPARENT, 16, 5)
	if btn_defeat_map:
		UIThemeHelper.apply_stateio_button_style(btn_defeat_map, Color(0.20, 0.26, 0.35), Color.TRANSPARENT, 16, 4)
	if btn_resume:
		UIThemeHelper.apply_stateio_button_style(btn_resume, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 18, 6)
	if btn_pause_sound:
		UIThemeHelper.apply_stateio_button_style(btn_pause_sound, Color(0.22, 0.30, 0.40), Color.TRANSPARENT, 16, 4)
	if btn_pause_retry:
		UIThemeHelper.apply_stateio_button_style(btn_pause_retry, Color(0.22, 0.30, 0.40), Color.TRANSPARENT, 16, 4)
	if btn_pause_map:
		UIThemeHelper.apply_stateio_button_style(btn_pause_map, Color(0.20, 0.26, 0.35), Color.TRANSPARENT, 16, 4)

func _update_pause_sound_label(muted: bool) -> void:
	if btn_pause_sound:
		btn_pause_sound.text = "🔇 SONIDO: SILENCIADO" if muted else "🔊 SONIDO: ACTIVADO"

func _on_pause_sound_pressed() -> void:
	var new_muted = AudioManager.toggle_mute()
	_update_pause_sound_label(new_muted)
	if not new_muted:
		AudioManager.play_click()

func _on_battle_started(level_id: String) -> void:
	var data = LevelDatabase.get_level_data(level_id)
	if label_level_name:
		label_level_name.text = data.get("name", "Batalla")

func _process(delta: float) -> void:
	crown_bob_time += delta
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
	_ensure_node_references()
	if not battle_controller:
		return
		
	var counts = battle_controller.get_faction_troop_counts() if battle_controller.has_method("get_faction_troop_counts") else {}
	var player_count = counts.get(GameManager.Faction.PLAYER, 0)
	var neutral_count = counts.get(GameManager.Faction.NEUTRAL, 0)
	var enemy_1_count = counts.get(GameManager.Faction.ENEMY_1, 0)
	var enemy_2_count = counts.get(GameManager.Faction.ENEMY_2, 0)
	var enemy_3_count = counts.get(GameManager.Faction.ENEMY_3, 0)
	var total_enemy_count = enemy_1_count + enemy_2_count + enemy_3_count
	
	var total = player_count + neutral_count + total_enemy_count
	var player_ratio = (float(player_count) / float(total)) if total > 0 else 0.0
	var neutral_ratio = (float(neutral_count) / float(total)) if total > 0 else 0.0
	var enemy_ratio = (float(total_enemy_count) / float(total)) if total > 0 else 0.0
	
	var total_width = 800.0
	if bar_player: bar_player.custom_minimum_size.x = total_width * player_ratio
	if bar_neutral: bar_neutral.custom_minimum_size.x = total_width * neutral_ratio
	if bar_enemy: bar_enemy.custom_minimum_size.x = total_width * enemy_ratio
	
	# Actualizar etiquetas numéricas con el conteo vivo de tropas por facción
	if label_count_player:
		label_count_player.text = "Azul: %d" % player_count
	if label_count_neutral:
		label_count_neutral.text = "Gris: %d" % neutral_count
	if label_count_enemy:
		if enemy_2_count > 0 or enemy_3_count > 0:
			label_count_enemy.text = "Rojo: %d  Otros: %d" % [enemy_1_count, enemy_2_count + enemy_3_count]
		else:
			label_count_enemy.text = "Rojo: %d" % enemy_1_count
			
	# Actualizar corona dorada de liderazgo
	_update_leader_crown(player_count, enemy_1_count, enemy_2_count, enemy_3_count, neutral_count)

func _update_leader_crown(player_count: int, enemy_1_count: int, enemy_2_count: int = 0, enemy_3_count: int = 0, _neutral_count: int = 0) -> void:
	if not leader_crown:
		return
		
	var target_segment: Control = null
	var max_enemy = maxi(enemy_1_count, maxi(enemy_2_count, enemy_3_count))
	
	if player_count >= max_enemy and player_count > 0:
		leader_faction = GameManager.Faction.PLAYER
		target_segment = bar_player
	elif max_enemy > player_count:
		if max_enemy == enemy_1_count:
			leader_faction = GameManager.Faction.ENEMY_1
		elif max_enemy == enemy_2_count:
			leader_faction = GameManager.Faction.ENEMY_2
		else:
			leader_faction = GameManager.Faction.ENEMY_3
		target_segment = bar_enemy
	else:
		leader_faction = GameManager.Faction.PLAYER
		target_segment = bar_player
		
	var total_active = player_count + enemy_1_count + enemy_2_count + enemy_3_count
	if not is_instance_valid(target_segment) or total_active == 0:
		leader_crown.visible = false
		return
		
	leader_crown.visible = true
	
	var w_p = bar_player.custom_minimum_size.x if is_instance_valid(bar_player) else 266.0
	var w_n = bar_neutral.custom_minimum_size.x if is_instance_valid(bar_neutral) else 266.0
	var w_e = bar_enemy.custom_minimum_size.x if is_instance_valid(bar_enemy) else 268.0
	
	var container = bar_player.get_parent() as Control if is_instance_valid(bar_player) else null
	var top_bar = container.get_parent() as Control if is_instance_valid(container) else null
	var top_w = top_bar.size.x if (top_bar and top_bar.size.x > 0.0) else 1080.0
	var base_x = container.position.x if (container and container.position.x > 0.0) else ((top_w * 0.5) - 400.0)
	var crown_w = maxf(leader_crown.size.x, 32.0)
	
	if target_segment == bar_player:
		target_crown_x = base_x + (w_p * 0.5) - (crown_w * 0.5)
	elif target_segment == bar_neutral:
		target_crown_x = base_x + w_p + (w_n * 0.5) - (crown_w * 0.5)
	else:
		target_crown_x = base_x + w_p + w_n + (w_e * 0.5) - (crown_w * 0.5)
		
	if current_crown_x == 0.0:
		current_crown_x = target_crown_x
	else:
		current_crown_x = lerpf(current_crown_x, target_crown_x, 0.25)
		
	leader_crown.position.x = current_crown_x
	var base_y = 12.0
	leader_crown.position.y = base_y + sin(crown_bob_time * 4.0) * 2.5

func get_leader_faction() -> int:
	return leader_faction

func _update_coins(amount: int) -> void:
	if label_coins:
		label_coins.text = "🪙 %d" % amount

func _on_battle_won(stats: Dictionary) -> void:
	var slow_motion_on = false
	if battle_controller and is_instance_valid(battle_controller):
		slow_motion_on = battle_controller.is_slow_motion_active
	if is_inside_tree() and (slow_motion_on or Engine.time_scale < 0.95):
		var timer = get_tree().create_timer(0.65, true, false, true)
		timer.timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				deploy_victory_modal(stats)
		)
	else:
		deploy_victory_modal(stats)

func deploy_victory_modal(stats: Dictionary) -> void:
	_cleanup_time_scale()
	_ensure_node_references()
	if dim_overlay:
		dim_overlay.visible = true
	if victory_panel:
		UIThemeHelper.animate_modal_pop_in(victory_panel)
		
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
	if dim_overlay:
		dim_overlay.visible = true
	if defeat_panel:
		UIThemeHelper.animate_modal_pop_in(defeat_panel)

func _on_pause_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	_ensure_node_references()
	_update_pause_sound_label(AudioManager.is_muted)
	if dim_overlay:
		dim_overlay.visible = true
	if pause_panel:
		UIThemeHelper.animate_modal_pop_in(pause_panel)
	get_tree().paused = true

func _on_resume_pressed() -> void:
	AudioManager.play_click()
	_cleanup_time_scale()
	_ensure_node_references()
	if pause_panel:
		UIThemeHelper.animate_modal_pop_out(pause_panel, func():
			if dim_overlay: dim_overlay.visible = false
			get_tree().paused = false
		)
	else:
		if dim_overlay: dim_overlay.visible = false
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
