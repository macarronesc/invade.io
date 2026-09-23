extends Control
class_name WorldMapUI

## WorldMapUI: Selección de continentes y niveles de campaña

@onready var continent_title: Label = %ContinentTitle
@onready var coins_label: Label = %CoinsLabel
@onready var levels_container: VBoxContainer = %LevelsContainer
@onready var btn_back: Button = %BtnBack
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_prev_continent: Button = %BtnPrevContinent
@onready var btn_next_continent: Button = %BtnNextContinent

var continents: Array[Dictionary] = []
var current_continent_index: int = 0

func _ready() -> void:
	continents = LevelDatabase.get_continents()
	for i in range(continents.size()):
		if continents[i]["id"] == GameManager.current_continent:
			current_continent_index = i
			break
			
	btn_back.pressed.connect(_on_back_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_prev_continent.pressed.connect(_on_prev_continent)
	btn_next_continent.pressed.connect(_on_next_continent)
	
	_update_coins(GameManager.coins)
	EventBus.coins_updated.connect(_update_coins)
	
	_refresh_display()

func _update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % amount

func _refresh_display() -> void:
	var cont = continents[current_continent_index]
	GameManager.current_continent = cont["id"]
	GameManager.save_game()
	
	# Calcular estrellas del continente
	var earned_stars = 0
	for lvl in range(1, 6):
		earned_stars += GameManager.completed_levels.get("%s_%d" % [cont["id"], lvl], 0)
	continent_title.text = "%s (%d/15 ⭐)" % [cont["name"], earned_stars]
	
	# Limpiar niveles anteriores
	for child in levels_container.get_children():
		child.queue_free()
		
	# Generar botones para los 5 niveles del continente
	for lvl_num in range(1, 6):
		var level_id = "%s_%d" % [cont["id"], lvl_num]
		var level_data = LevelDatabase.get_level_data(level_id)
		var is_unlocked = GameManager.is_level_unlocked(level_id)
		var stars = GameManager.completed_levels.get(level_id, 0)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 100)
		
		var title_text = level_data.get("name", "Nivel %d" % lvl_num)
		var desc_text = level_data.get("description", "")
		if is_unlocked:
			var stars_text = ""
			for s in range(3):
				stars_text += "⭐" if s < stars else "☆"
			btn.text = "%s  [%s]\n%s" % [title_text, stars_text, desc_text]
			btn.pressed.connect(_start_level.bind(level_id))
		else:
			btn.text = "🔒 %s (Bloqueado)" % title_text
			btn.disabled = true
			
		btn.add_theme_font_size_override("font_size", 22)
		levels_container.add_child(btn)

func _on_prev_continent() -> void:
	AudioManager.play_click()
	current_continent_index = (current_continent_index - 1 + continents.size()) % continents.size()
	_refresh_display()

func _on_next_continent() -> void:
	AudioManager.play_click()
	current_continent_index = (current_continent_index + 1) % continents.size()
	_refresh_display()

func _start_level(level_id: String) -> void:
	AudioManager.play_click()
	GameManager.current_level_id = level_id
	get_tree().change_scene_to_file("res://scenes/battle/battle_field.tscn")

func _on_back_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_upgrades_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn")
