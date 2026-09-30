extends ScrollPage

## Ejército: mejoras permanentes (ventaja en combate) y aspecto (sólo estética), en dos pestañas.
## Tras una derrota ofrece volver directamente a la misma batalla.

const UPGRADES := {
	"starting_troops": {"icon": "shield", "color": UIThemeHelper.COLOR_PRIMARY, "percent": false},
	"production_rate": {"icon": "bolt", "color": UIThemeHelper.COLOR_GOLD, "percent": true},
	"troop_speed": {"icon": "speed", "color": UIThemeHelper.COLOR_SUCCESS, "percent": true},
	"gold_bonus": {"icon": "coin", "color": UIThemeHelper.COLOR_GOLD, "percent": true},
}

var return_to_battle := false
var section := "upgrades"

func _ready() -> void:
	EventBus.cosmetics_changed.connect(rebuild)
	super()

func _build() -> void:
	UIThemeHelper.section(content, LocaleStrings.text("tab_army"))
	if return_to_battle:
		var retry := UIThemeHelper.card(content)
		retry.add_child(UIThemeHelper.label(LocaleStrings.text("retry_title"), "Heading"))
		var go := UIThemeHelper.button(LocaleStrings.text("retry_battle"), "PrimaryButton", "retry")
		go.name = "BtnReturnToBattle"
		go.pressed.connect(UIThemeHelper.start_battle.bind(self))
		retry.add_child(go)
	content.add_child(_segments())
	if section == "upgrades":
		content.add_child(UIThemeHelper.paragraph(LocaleStrings.text("upgrades_sub")))
		for id in UPGRADES:
			content.add_child(_upgrade_card(id))
	else:
		content.add_child(UIThemeHelper.paragraph(LocaleStrings.text("looks_sub")))
		for category in CosmeticsDatabase.CATEGORIES:
			content.add_child(UIThemeHelper.label(LocaleStrings.text("cat_" + category), "Heading"))
			var grid := GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 16)
			grid.add_theme_constant_override("v_separation", 16)
			for item in CosmeticsDatabase.items_of(category):
				grid.add_child(_cosmetic_tile(item))
			content.add_child(grid)

func _segments() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Chip"
	var row := UIThemeHelper.hbox(8)
	panel.add_child(row)
	var group := ButtonGroup.new()
	for id in ["upgrades", "looks"]:
		var b := UIThemeHelper.button(LocaleStrings.text("segment_" + id), "SegmentButton")
		b.name = "Segment_" + id
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = section == id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			AudioManager.play_click()
			section = id
			scroll_vertical = 0
			rebuild())
		row.add_child(b)
	return panel

func _upgrade_card(id: String) -> PanelContainer:
	var cfg: Dictionary = UPGRADES[id]
	var level: int = GameManager.upgrades.get(id, 0)
	var max_level := GameManager.MAX_UPGRADE_LEVEL
	var step: int = GameManager.UPGRADE_STEPS[id]
	var fmt := "+%d%%" if cfg["percent"] else "+%d"
	var card := PanelContainer.new()
	card.name = "UpgradeCard_" + id
	var column := UIThemeHelper.vbox(18)
	card.add_child(column)

	# Efecto actual › siguiente, p. ej. "+10  ›  +15 tropas al empezar"
	var effect := fmt % (level * step)
	if level < max_level:
		effect += "  ›  " + fmt % ((level + 1) * step)
	effect += " " + LocaleStrings.text("upg_%s_unit" % id)
	column.add_child(UIThemeHelper.item_row(UIThemeHelper.round_badge(Icons.rect(cfg["icon"], 52, cfg["color"]), cfg["color"]),
		LocaleStrings.text("upg_" + id), effect, UIThemeHelper.chip(LocaleStrings.text("level_short") % [level, max_level])))

	var pips := UIThemeHelper.hbox(6)
	for i in max_level:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(0, 12)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.add_theme_stylebox_override("panel", UIThemeHelper.box(cfg["color"] if i < level else UIThemeHelper.COLOR_SURFACE_2, 999, 0))
		pips.add_child(pip)
	column.add_child(pips)

	var bottom := UIThemeHelper.hbox(16)
	var hint := UIThemeHelper.paragraph(LocaleStrings.text("upgrade_maxed"))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	var buy := UIThemeHelper.button(LocaleStrings.text("max"), "GoldButton")
	buy.custom_minimum_size.x = 240
	buy.disabled = true
	if level < max_level:
		var cost := GameManager.get_upgrade_cost(id)
		buy.text = str(cost)
		UIThemeHelper.set_icon(buy, "coin")
		buy.disabled = GameManager.coins < cost
		hint.text = LocaleStrings.text("missing_gold") % (cost - GameManager.coins) if buy.disabled else ""
		buy.pressed.connect(_buy_upgrade.bind(id))
	bottom.add_child(buy)
	column.add_child(bottom)
	return card

## La compra emite coins_updated, que redibuja la sección y el saldo de la cabecera
func _buy_upgrade(upgrade_id: String) -> void:
	if GameManager.buy_upgrade(upgrade_id):
		AudioManager.play_troop_absorb(true)
		GameManager.haptic(20)

func _cosmetic_tile(item: Dictionary) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "CosmeticRow_" + item["id"]
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIThemeHelper.vbox(12)
	tile.add_child(column)
	var preview := CosmeticPreview.new()
	preview.item = item
	preview.custom_minimum_size = Vector2(0, 130)
	column.add_child(preview)
	var name_label := UIThemeHelper.label(CosmeticsDatabase.item_name(item), "Caption", UIThemeHelper.COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	var btn := UIThemeHelper.button("")
	btn.add_theme_font_size_override("font_size", 26)
	if GameManager.cosmetics_equipped.get(item["category"], "") == item["id"]:
		btn.text = LocaleStrings.text("equipped")
		btn.icon = Icons.texture("check", 36)
		btn.disabled = true
		btn.add_theme_color_override("font_disabled_color", UIThemeHelper.COLOR_SUCCESS)
		btn.add_theme_color_override("icon_disabled_color", UIThemeHelper.COLOR_SUCCESS)
	elif GameManager.is_cosmetic_owned(item["id"]):
		btn.text = LocaleStrings.text("equip")
		btn.pressed.connect(func():
			if GameManager.equip_cosmetic(item["id"]):
				AudioManager.play_click())
	else:
		btn.theme_type_variation = "GoldButton"
		btn.text = str(item["cost"])
		UIThemeHelper.set_icon(btn, "coin", 36)
		btn.disabled = GameManager.coins < int(item["cost"])
		btn.pressed.connect(func():
			if GameManager.buy_cosmetic(item["id"]):
				AudioManager.play_troop_absorb(true))
	column.add_child(btn)
	return tile

## Miniatura de cada objeto de estética tal y como se verá en batalla
class CosmeticPreview extends Control:
	var item: Dictionary

	func _draw() -> void:
		var c := size * 0.5
		var player: Color = item.get("color", GameManager.player_color())
		match item["category"]:
			"map_theme":
				draw_rect(Rect2(Vector2(8, 4), size - Vector2(16, 8)), item["bg"])
				draw_colored_polygon(PackedVector2Array([c + Vector2(-90, 10), c + Vector2(-40, -40), c + Vector2(30, -30), c + Vector2(90, 20), c + Vector2(20, 45), c + Vector2(-60, 40)]), item["land"])
				_base(c + Vector2(-20, 4), 22.0, player, "base_round")
			"base_shape":
				_base(c, 38.0, player, item["id"])
			_:
				var style: String = item["id"] if item["category"] == "troop_style" else GameManager.troop_style()
				_base(c + Vector2(-60, 0), 30.0, player, GameManager.base_shape())
				for i in 3:
					Troop.draw_bead(self, c + Vector2(-5 + i * 34, 0), 8.0, player, style)

	func _base(pos: Vector2, r: float, color: Color, shape: String) -> void:
		BaseNode.draw_frame(self, pos, r, shape)
		draw_circle(pos, r, color)
