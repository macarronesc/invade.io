extends CanvasLayer
class_name BattleHUD

## BattleHUD: Interfaz en pantalla durante la batalla (barra de dominancia, estados y modales)

@export var battle_controller: BattleController

@onready var label_level_name: Label = %LevelNameLabel
@onready var label_coins: Label = %CoinsLabel
@onready var bar_player: ColorRect = %BarPlayer
@onready var bar_enemy: ColorRect = %BarEnemy
@onready var bar_neutral: ColorRect = %BarNeutral
@onready var btn_dispatch_mode: Button = %BtnDispatchMode

# Modales
@onready var victory_panel: Control = %VictoryPanel
@onready var victory_stars_label: Label = %VictoryStarsLabel
@onready var victory_reward_label: Label = %VictoryRewardLabel
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

func _ready() -> void:
	# Ocultar modales al iniciar
	victory_panel.visible = false
	defeat_panel.visible = false
	pause_panel.visible = false
	
	_update_coins(GameManager.coins)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.dispatch_percentage_changed.connect(_on_dispatch_percentage_changed)
	
	# Conexión de botones
	btn_pause.pressed.connect(_on_pause_pressed)
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_pause_retry.pressed.connect(_on_retry_pressed)
	btn_pause_map.pressed.connect(_on_map_pressed)
	
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	
	if btn_dispatch_mode:
		btn_dispatch_mode.pressed.connect(_on_dispatch_mode_pressed)
		_update_dispatch_mode_label(1.0)
	
	if battle_controller and battle_controller.level_data:
		label_level_name.text = battle_controller.level_data.get("name", "Batalla")

func _on_battle_started(level_id: String) -> void:
	var data = LevelDatabase.get_level_data(level_id)
	if label_level_name:
		label_level_name.text = data.get("name", "Batalla")
	if btn_dispatch_mode:
		btn_dispatch_mode.visible = true
		_update_dispatch_mode_label(1.0)

func _on_dispatch_mode_pressed() -> void:
	AudioManager.play_click()
	if battle_controller:
		var new_pct = battle_controller.toggle_dispatch_percentage()
		_update_dispatch_mode_label(new_pct)

func _on_dispatch_percentage_changed(pct: float) -> void:
	_update_dispatch_mode_label(pct)

func _update_dispatch_mode_label(_pct: float = 1.0) -> void:
	if btn_dispatch_mode:
		btn_dispatch_mode.text = "⚔ Asalto: 100%"

func _process(_delta: float) -> void:
	if not battle_controller:
		return
	_update_dominance_bar()

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
	if btn_dispatch_mode:
		btn_dispatch_mode.visible = false
	victory_panel.visible = true
	var stars_count = stats.get("stars", 1)
	var star_str = ""
	for i in range(stars_count):
		star_str += "⭐ "
	victory_stars_label.text = star_str.strip_edges()
	victory_reward_label.text = "+%d Monedas de Oro" % stats.get("gold_earned", 0)

func _on_battle_lost() -> void:
	if btn_dispatch_mode:
		btn_dispatch_mode.visible = false
	defeat_panel.visible = true

func _on_pause_pressed() -> void:
	AudioManager.play_click()
	pause_panel.visible = true
	get_tree().paused = true

func _on_resume_pressed() -> void:
	AudioManager.play_click()
	pause_panel.visible = false
	get_tree().paused = false

func _on_retry_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_next_level_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	var next_id = GameManager.get_next_level(battle_controller.level_id)
	if next_id != "":
		GameManager.current_level_id = next_id
		get_tree().reload_current_scene()
	else:
		_on_map_pressed()

func _on_map_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")

func _on_upgrade_pressed() -> void:
	AudioManager.play_click()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn")
