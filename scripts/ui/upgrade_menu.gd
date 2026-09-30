extends Control
class_name UpgradeMenuUI

## UpgradeMenuUI: Tienda táctica de mejoras permanentes con tarjetas 2.5D,
## barras de progresión segmentadas (10 niveles) e indicadores de economía viva.

@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var btn_back: Button = %BtnBack
@onready var stars_pill: PanelContainer = %StarsPill
@onready var coins_pill: PanelContainer = %CoinsPill
@onready var title_label: Label = $Header/Title
@onready var subtitle_label: Label = $Subtitle

const UPGRADE_CONFIG: Dictionary = {
	"starting_troops": {
		"icon": "🛡️",
		"badge_color": Color(0.13, 0.59, 0.95), # Azul táctico
		"title": "Guarnición Inicial",
		"title_en": "Starting Garrison",
		"desc": "+%d tropas adicionales en tu base al iniciar la batalla",
		"desc_en": "+%d extra troops on your base when the battle starts",
		"unit": "tropas iniciales",
		"unit_en": "starting troops"
	},
	"production_rate": {
		"icon": "⚡",
		"badge_color": Color(1.0, 0.76, 0.03), # Ámbar eléctrico
		"title": "Velocidad de Reclutamiento",
		"title_en": "Recruitment Speed",
		"desc": "+%d%% velocidad de producción de tropas en todas tus bases",
		"desc_en": "+%d%% troop production speed on all your bases",
		"unit": "% producción",
		"unit_en": "% production"
	},
	"troop_speed": {
		"icon": "👟",
		"badge_color": Color(0.20, 0.80, 0.85), # Cyan veloz
		"title": "Velocidad de Marcha",
		"title_en": "March Speed",
		"desc": "+%d%% velocidad de marcha de tus tropas hacia el objetivo",
		"desc_en": "+%d%% march speed of your troops toward the target",
		"unit": "% velocidad",
		"unit_en": "% speed"
	},
	"gold_bonus": {
		"icon": "💰",
		"badge_color": Color(1.0, 0.82, 0.18), # Oro botín
		"title": "Botín de Guerra",
		"title_en": "Spoils of War",
		"desc": "+%d%% más oro por victoria conseguida en campaña",
		"desc_en": "+%d%% more gold per campaign victory",
		"unit": "% más oro",
		"unit_en": "% more gold"
	}
}

## Título/descripción/unidad de mejora en el idioma actual
static func _cfg_text(cfg: Dictionary, key: String) -> String:
	return cfg[key + "_en"] if GameManager.language == "en" else cfg[key]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _ready() -> void:
	AudioManager.play_music("menu")
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($Header)

	btn_back.text = LocaleStrings.text("back")
	title_label.text = LocaleStrings.text("upgrades_title")
	subtitle_label.text = LocaleStrings.text("upgrades_sub")
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.coins_updated.connect(_update_coins)
	EventBus.upgrade_purchased.connect(_build_cards.unbind(2))
	EventBus.cosmetics_changed.connect(_build_cards)

	_update_coins(GameManager.coins)
	_update_stars()
	_build_cards()

func _apply_visual_styling() -> void:
	UIThemeHelper.apply_stateio_button_style(btn_back, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_pill_style(stars_pill)
	UIThemeHelper.apply_pill_style(coins_pill)

func _update_coins(amount: int) -> void:
	coins_label.text = UIThemeHelper.coins_text(amount)

func _update_stars() -> void:
	stars_label.text = UIThemeHelper.stars_text()

func _build_cards() -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	cards_container.add_child(_make_section_label(LocaleStrings.text("section_upgrades")))
	for key in UPGRADE_CONFIG:
		cards_container.add_child(_create_upgrade_card(key))
	cards_container.add_child(_make_section_label(LocaleStrings.text("section_style")))
	for category in CosmeticsDatabase.CATEGORIES:
		cards_container.add_child(_make_section_label(LocaleStrings.text("cat_" + category), 24))
		for item in CosmeticsDatabase.items_of(category):
			cards_container.add_child(_create_cosmetic_row(item))

func _make_section_label(text: String, font_size: int = 30) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

## Fila compacta de cosmético: muestra de color, nombre y botón comprar/equipar
func _create_cosmetic_row(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "CosmeticRow_%s" % item["id"]
	UIThemeHelper.apply_card_style(panel, UIThemeHelper.COLOR_CARD, UIThemeHelper.COLOR_CARD_BORDER, 16, 2)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(64, 64)
	swatch.color = item.get("color", item.get("bg", Color(0.5, 0.5, 0.5)))
	row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = CosmeticsDatabase.item_name(item)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(240, 80)
	btn.add_theme_font_size_override("font_size", 26)
	var owned := GameManager.is_cosmetic_owned(item["id"])
	var equipped: bool = GameManager.cosmetics_equipped.get(item["category"], "") == item["id"]
	if equipped:
		btn.text = LocaleStrings.text("equipped")
		btn.disabled = true
		UIThemeHelper.apply_stateio_button_style(btn, Color(0.40, 0.35, 0.15, 0.8), 14, 2, UIThemeHelper.COLOR_ACCENT)
		btn.add_theme_stylebox_override("disabled", btn.get_theme_stylebox("normal"))
		btn.add_theme_color_override("font_disabled_color", UIThemeHelper.COLOR_ACCENT)
	elif owned:
		btn.text = LocaleStrings.text("equip")
		UIThemeHelper.apply_stateio_button_style(btn, UIThemeHelper.COLOR_PRIMARY, 14, 5)
		btn.pressed.connect(_on_equip_cosmetic.bind(item["id"]))
	else:
		btn.text = UIThemeHelper.coins_text(int(item["cost"]))
		btn.disabled = GameManager.coins < int(item["cost"])
		UIThemeHelper.apply_stateio_button_style(btn, UIThemeHelper.COLOR_SUCCESS, 14, 5)
		btn.pressed.connect(_on_buy_cosmetic.bind(item["id"]))
	row.add_child(btn)
	return panel

func _on_buy_cosmetic(id: String) -> void:
	if GameManager.buy_cosmetic(id):
		AudioManager.play_troop_absorb(true)

func _on_equip_cosmetic(id: String) -> void:
	if GameManager.equip_cosmetic(id):
		AudioManager.play_click()

func _create_upgrade_card(upgrade_id: String) -> PanelContainer:
	var cfg: Dictionary = UPGRADE_CONFIG[upgrade_id]
	var step: int = GameManager.UPGRADE_STEPS[upgrade_id]
	var lvl = GameManager.upgrades.get(upgrade_id, 0)
	var max_lvl = GameManager.MAX_UPGRADE_LEVEL
	var badge_col: Color = cfg["badge_color"]

	var panel = PanelContainer.new()
	panel.name = "UpgradeCard_%s" % upgrade_id
	panel.custom_minimum_size = Vector2(0, 200)
	UIThemeHelper.apply_card_style(panel, UIThemeHelper.COLOR_CARD, UIThemeHelper.COLOR_CARD_BORDER, 20, 2)

	var margin = MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
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
	icon_style.bg_color = Color(badge_col, 0.20)
	icon_style.border_color = Color(badge_col, 0.70)
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
	lbl_title.text = _cfg_text(cfg, "title")
	lbl_title.add_theme_font_size_override("font_size", 26)
	lbl_title.add_theme_color_override("font_color", Color.WHITE)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(lbl_title)

	var lbl_level = Label.new()
	lbl_level.text = LocaleStrings.text("level") % [lvl, max_lvl]
	lbl_level.add_theme_font_size_override("font_size", 22)
	lbl_level.add_theme_color_override("font_color", badge_col.lightened(0.20))
	header_hbox.add_child(lbl_level)

	# Descripción del efecto
	var lbl_desc = Label.new()
	lbl_desc.text = _cfg_text(cfg, "desc") % step
	lbl_desc.add_theme_font_size_override("font_size", 18)
	lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox_info.add_child(lbl_desc)

	# Estadísticas comparativas (Actual vs Siguiente)
	var current_bonus = lvl * step
	var next_bonus = (lvl + 1) * step
	var unit := _cfg_text(cfg, "unit")
	var lbl_stats = Label.new()
	if lvl >= max_lvl:
		lbl_stats.text = LocaleStrings.text("effect_max") % [current_bonus, unit]
		lbl_stats.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	else:
		lbl_stats.text = LocaleStrings.text("current_next") % [current_bonus, unit, next_bonus, unit]
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
		btn_buy.text = LocaleStrings.text("max")
		btn_buy.disabled = true
		UIThemeHelper.apply_stateio_button_style(btn_buy, Color(0.40, 0.35, 0.15, 0.8), 16, 2, UIThemeHelper.COLOR_ACCENT)
		# Deshabilitado pero con el aspecto dorado de "completado", no el gris genérico
		btn_buy.add_theme_stylebox_override("disabled", btn_buy.get_theme_stylebox("normal"))
		btn_buy.add_theme_color_override("font_disabled_color", UIThemeHelper.COLOR_ACCENT)
	else:
		btn_buy.text = UIThemeHelper.coins_text(cost)
		btn_buy.disabled = GameManager.coins < cost
		UIThemeHelper.apply_stateio_button_style(btn_buy, UIThemeHelper.COLOR_SUCCESS, 16, 6)

	btn_buy.pressed.connect(_buy_upgrade.bind(upgrade_id))
	hbox.add_child(btn_buy)

	return panel

## La compra emite upgrade_purchased y coins_updated, que reconstruyen tarjetas y saldo
func _buy_upgrade(upgrade_id: String) -> void:
	if GameManager.buy_upgrade(upgrade_id):
		AudioManager.play_troop_absorb(true)
		_animate_coin_spend()

func _animate_coin_spend() -> void:
	if not is_inside_tree():
		return
	coins_label.pivot_offset = coins_label.size * 0.5
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(coins_label, "scale", Vector2(1.25, 1.25), 0.14)
	tw.tween_property(coins_label, "scale", Vector2.ONE, 0.16)

## Vuelve al menú principal si se entró desde él; si no (mapa, derrota), al mapa del mundo
func _on_back_pressed() -> void:
	var main_menu := "res://scenes/ui/main_menu.tscn"
	UIThemeHelper.go_to(self, main_menu if UIThemeHelper.previous_scene == main_menu else "res://scenes/ui/world_map.tscn")
