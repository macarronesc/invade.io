extends Control
class_name MainMenuUI

## MainMenuUI: Menú principal de inicio del juego

@onready var btn_play: Button = %BtnPlay
@onready var btn_world_map: Button = %BtnWorldMap
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_reset: Button = %BtnReset
@onready var coins_label: Label = %CoinsLabel

func _ready() -> void:
	btn_play.pressed.connect(_on_play_pressed)
	btn_world_map.pressed.connect(_on_world_map_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	
	_update_coins(GameManager.coins)
	EventBus.coins_updated.connect(_update_coins)

func _update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % amount

func _on_play_pressed() -> void:
	AudioManager.play_click()
	# Continuar con el nivel actual
	get_tree().change_scene_to_file("res://scenes/battle/battle_field.tscn")

func _on_world_map_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")

func _on_upgrades_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn")

func _on_reset_pressed() -> void:
	AudioManager.play_click()
	GameManager.reset_save()
	_update_coins(GameManager.coins)
