extends Control
class_name UpgradeMenuUI

## UpgradeMenuUI: Interfaz de compra y visualización de mejoras permanentes

@onready var coins_label: Label = %CoinsLabel
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var btn_back: Button = %BtnBack

const UPGRADE_KEYS = ["starting_troops", "production_rate", "troop_speed", "gold_bonus"]

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	_update_coins(GameManager.coins)
	_build_cards()

func _update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % amount

func _build_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
		
	for key in UPGRADE_KEYS:
		var card = _create_upgrade_card(key)
		cards_container.add_child(card)

func _create_upgrade_card(upgrade_id: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 160)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	# Columna izquierda con info
	var vbox_info = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox_info)
	
	var title = GameManager.UPGRADE_TITLES.get(upgrade_id, upgrade_id)
	var lvl = GameManager.upgrades.get(upgrade_id, 0)
	
	var lbl_title = Label.new()
	lbl_title.text = "%s  (Nivel %d/%d)" % [title, lvl, GameManager.MAX_UPGRADE_LEVEL]
	lbl_title.add_theme_font_size_override("font_size", 26)
	vbox_info.add_child(lbl_title)
	
	var lbl_desc = Label.new()
	lbl_desc.text = GameManager.UPGRADE_DESCRIPTIONS.get(upgrade_id, "")
	lbl_desc.add_theme_font_size_override("font_size", 20)
	lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_info.add_child(lbl_desc)
	
	# Botón de compra
	var btn_buy = Button.new()
	btn_buy.custom_minimum_size = Vector2(200, 75)
	btn_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var cost = GameManager.get_upgrade_cost(upgrade_id)
	if lvl >= GameManager.MAX_UPGRADE_LEVEL:
		btn_buy.text = "MÁXIMO"
		btn_buy.disabled = true
	else:
		btn_buy.text = "🪙 %d" % cost
		btn_buy.disabled = (GameManager.coins < cost)
		
	btn_buy.add_theme_font_size_override("font_size", 26)
	btn_buy.pressed.connect(func(): _buy_upgrade(upgrade_id))
	hbox.add_child(btn_buy)
	
	return panel

func _buy_upgrade(upgrade_id: String) -> void:
	if GameManager.buy_upgrade(upgrade_id):
		AudioManager.play_reinforce()
		_build_cards()

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_build_cards()

func _on_back_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")
