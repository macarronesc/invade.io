extends Control
class_name UpgradeMenuUI

const UIThemeHelper = preload("res://scripts/ui/ui_theme_helper.gd")

## UpgradeMenuUI: Tienda táctica de mejoras permanentes con tarjetas 2.5D,
## barras de progresión segmentadas (10 niveles) e indicadores de economía viva.

@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var btn_back: Button = %BtnBack
@onready var stars_pill: PanelContainer = %StarsPill
@onready var coins_pill: PanelContainer = %CoinsPill

const UPGRADE_KEYS: Array[String] = ["starting_troops", "production_rate", "troop_speed", "gold_bonus"]

const UPGRADE_CONFIG: Dictionary = {
	"starting_troops": {
		"icon": "🛡️",
		"badge_color": Color(0.13, 0.59, 0.95), # Azul táctico
		"title": "Guarnición Inicial",
		"desc": "+5 tropas adicionales en tu base al iniciar la batalla",
		"unit": "tropas iniciales",
		"step": 5
	},
	"production_rate": {
		"icon": "⚡",
		"badge_color": Color(1.0, 0.76, 0.03), # Ámbar eléctrico
		"title": "Velocidad de Reclutamiento",
		"desc": "+15% velocidad de producción de tropas en todas tus bases",
		"unit": "% producción",
		"step": 15
	},
	"troop_speed": {
		"icon": "👟",
		"badge_color": Color(0.20, 0.80, 0.85), # Cyan veloz
		"title": "Velocidad de Marcha",
		"desc": "+10% velocidad de marcha de tus tropas hacia el objetivo",
		"unit": "% velocidad",
		"step": 10
	},
	"gold_bonus": {
		"icon": "💰",
		"badge_color": Color(1.0, 0.82, 0.18), # Oro botín
		"title": "Botín de Guerra",
		"desc": "+20% más oro por victoria conseguida en campaña",
		"unit": "% más oro",
		"step": 20
	}
}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _ready() -> void:
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($Header)
	
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	
	_update_coins(GameManager.coins)
	_update_stars()
	_build_cards()

func _apply_visual_styling() -> void:
	if btn_back:
		UIThemeHelper.apply_stateio_button_style(btn_back, Color(0.18, 0.24, 0.32), Color.TRANSPARENT, 16, 4)
	if stars_pill:
		UIThemeHelper.apply_pill_style(stars_pill, UIThemeHelper.COLOR_HEADER_PILL, Color(0.35, 0.45, 0.58, 0.60), 20)
	if coins_pill:
		UIThemeHelper.apply_pill_style(coins_pill, UIThemeHelper.COLOR_HEADER_PILL, Color(0.35, 0.45, 0.58, 0.60), 20)

func _update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % amount

func _update_stars() -> void:
	if stars_label:
		var total_stars = GameManager.get_total_stars()
		var max_stars = GameManager.get_max_possible_stars()
		stars_label.text = "⭐ %d/%d" % [total_stars, max_stars]

func _build_cards() -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
		
	for key in UPGRADE_KEYS:
		var card = _create_upgrade_card(key)
		cards_container.add_child(card)

func _create_upgrade_card(upgrade_id: String) -> PanelContainer:
	var cfg = UPGRADE_CONFIG.get(upgrade_id, {
		"icon": "⭐",
		"badge_color": UIThemeHelper.COLOR_PRIMARY,
		"title": upgrade_id,
		"desc": "",
		"unit": "bonus",
		"step": 1
	})
	
	var lvl = GameManager.upgrades.get(upgrade_id, 0)
	var max_lvl = GameManager.MAX_UPGRADE_LEVEL
	var badge_col: Color = cfg["badge_color"]
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 200)
	UIThemeHelper.apply_card_style(panel, UIThemeHelper.COLOR_CARD, UIThemeHelper.COLOR_CARD_BORDER, 20, 2)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)
	
	# 1. Columna Izquierda: Insignia e icono visual temático
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(95, 95)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(badge_col.r, badge_col.g, badge_col.b, 0.20)
	icon_style.border_color = Color(badge_col.r, badge_col.g, badge_col.b, 0.70)
	icon_style.border_width_bottom = 3
	icon_style.border_width_top = 2
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.set_corner_radius_all(18)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	
	var icon_lbl = Label.new()
	icon_lbl.text = cfg["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 46)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)
	
	# 2. Columna Central: Información, estadísticas y barra segmentada
	var vbox_info = VBoxContainer.new()
	vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_info.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox_info)
	
	# Cabecera de la tarjeta: Título + Nivel
	var header_hbox = HBoxContainer.new()
	vbox_info.add_child(header_hbox)
	
	var lbl_title = Label.new()
	lbl_title.text = cfg["title"]
	lbl_title.add_theme_font_size_override("font_size", 26)
	lbl_title.add_theme_color_override("font_color", Color.WHITE)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(lbl_title)
	
	var lbl_level = Label.new()
	lbl_level.text = "Nivel %d/%d" % [lvl, max_lvl]
	lbl_level.add_theme_font_size_override("font_size", 22)
	lbl_level.add_theme_color_override("font_color", badge_col.lightened(0.20))
	header_hbox.add_child(lbl_level)
	
	# Descripción del efecto
	var lbl_desc = Label.new()
	lbl_desc.text = cfg["desc"]
	lbl_desc.add_theme_font_size_override("font_size", 18)
	lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_info.add_child(lbl_desc)
	
	# Estadísticas comparativas (Actual vs Siguiente)
	var current_bonus = lvl * cfg["step"]
	var next_bonus = (lvl + 1) * cfg["step"]
	var lbl_stats = Label.new()
	if lvl >= max_lvl:
		lbl_stats.text = "Efecto Máximo: +%d %s" % [current_bonus, cfg["unit"]]
		lbl_stats.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	else:
		lbl_stats.text = "Actual: +%d %s  ▶  Siguiente: +%d %s" % [current_bonus, cfg["unit"], next_bonus, cfg["unit"]]
		lbl_stats.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
	lbl_stats.add_theme_font_size_override("font_size", 17)
	vbox_info.add_child(lbl_stats)
	
	# Barra de progreso segmentada en 10 pips visuales
	var pips_container = HBoxContainer.new()
	pips_container.custom_minimum_size = Vector2(0, 14)
	pips_container.add_theme_constant_override("separation", 6)
	vbox_info.add_child(pips_container)
	
	for pip_idx in range(max_lvl):
		var pip = Panel.new()
		pip.custom_minimum_size = Vector2(0, 12)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pip_style = StyleBoxFlat.new()
		pip_style.set_corner_radius_all(4)
		if pip_idx < lvl:
			pip_style.bg_color = badge_col
			pip_style.border_color = badge_col.lightened(0.20)
			pip_style.border_width_bottom = 2
		else:
			pip_style.bg_color = Color(0.22, 0.27, 0.35, 0.55)
			pip_style.border_color = Color(0.18, 0.22, 0.28, 0.40)
			pip_style.border_width_bottom = 1
		pip.add_theme_stylebox_override("panel", pip_style)
		pips_container.add_child(pip)
		
	# 3. Columna Derecha: Botón táctil de compra 2.5D
	var btn_buy = Button.new()
	btn_buy.custom_minimum_size = Vector2(210, 85)
	btn_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_buy.add_theme_font_size_override("font_size", 28)
	
	var cost = GameManager.get_upgrade_cost(upgrade_id)
	if lvl >= max_lvl:
		btn_buy.text = "MÁXIMO"
		btn_buy.disabled = true
		UIThemeHelper.apply_stateio_button_style(btn_buy, Color(0.40, 0.35, 0.15, 0.8), UIThemeHelper.COLOR_ACCENT, 16, 2)
		btn_buy.add_theme_color_override("font_disabled_color", UIThemeHelper.COLOR_ACCENT)
	else:
		btn_buy.text = "🪙 %d" % cost
		var can_afford = (GameManager.coins >= cost)
		btn_buy.disabled = not can_afford
		if can_afford:
			UIThemeHelper.apply_stateio_button_style(btn_buy, UIThemeHelper.COLOR_SUCCESS, Color.TRANSPARENT, 16, 6)
		else:
			UIThemeHelper.apply_stateio_button_style(btn_buy, Color(0.25, 0.28, 0.35, 0.70), Color.TRANSPARENT, 16, 3)
			
	btn_buy.pressed.connect(_buy_upgrade.bind(upgrade_id))
	hbox.add_child(btn_buy)
	
	return panel

func _buy_upgrade(upgrade_id: String) -> void:
	if GameManager.buy_upgrade(upgrade_id):
		AudioManager.play_troop_absorb(true)
		_animate_coin_spend()
		_build_cards()

func _animate_coin_spend() -> void:
	if not coins_label or not is_inside_tree():
		return
	coins_label.pivot_offset = coins_label.size * 0.5
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(coins_label, "scale", Vector2(1.25, 1.25), 0.14)
	tw.tween_property(coins_label, "scale", Vector2.ONE, 0.16)

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_update_coins(GameManager.coins)
	_build_cards()

func _on_back_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")
