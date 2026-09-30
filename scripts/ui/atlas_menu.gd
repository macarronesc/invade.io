extends Control
class_name AtlasMenuUI

## AtlasMenuUI: colección de ciudades reales conquistadas en cualquier modo.
## Nube de puntos del mundo (azul = conquistada) + contador "312/1128" + lista.

class AtlasDots extends Control:
	var points: Array = []
	func _draw() -> void:
		for p in points:
			var pos := Vector2(p[0] * size.x, p[1] * size.y)
			draw_circle(pos, 7.0, Color(0, 0, 0, 0.30))
			draw_circle(pos, 5.0, Color(0.20, 0.70, 1.0) if p[2] else Color(1, 1, 1, 0.16))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _ready() -> void:
	AudioManager.play_music("menu")
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.13, 0.18)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var dots := AtlasDots.new()
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)

	var btn_back := Button.new()
	btn_back.text = LocaleStrings.text("back")
	btn_back.custom_minimum_size = Vector2(300, 72)
	btn_back.add_theme_font_size_override("font_size", 26)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UIThemeHelper.apply_stateio_button_style(btn_back, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	btn_back.pressed.connect(_on_back_pressed)
	vbox.add_child(btn_back)

	var title := Label.new()
	title.text = LocaleStrings.text("atlas_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	vbox.add_child(title)

	var conquered := GameManager.conquered_cities
	var total := GameManager.atlas_total_count()
	var progress := Label.new()
	progress.text = "🏙️ %d/%d" % [conquered.size(), total]
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 44)
	vbox.add_child(progress)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.max_value = maxf(1.0, float(total))
	bar.value = float(conquered.size())
	for part in [["background", Color(0.08, 0.10, 0.14)], ["fill", UIThemeHelper.COLOR_PRIMARY]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = part[1]
		sb.set_corner_radius_all(11)
		bar.add_theme_stylebox_override(part[0], sb)
	vbox.add_child(bar)

	var sub := Label.new()
	sub.text = LocaleStrings.text("atlas_sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	vbox.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if conquered.is_empty():
		var empty := Label.new()
		empty.text = LocaleStrings.text("atlas_empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 26)
		list.add_child(empty)
	for key in conquered:
		var row := Label.new()
		row.text = "🔵 " + GeoDatabase.city_name(GeoDatabase.get_city(key))
		row.add_theme_font_size_override("font_size", 28)
		list.add_child(row)

	var collected := {}
	for key in conquered:
		collected[key] = true
	for city in GeoDatabase.get_cities():
		var ll: Vector2 = city["lonlat"]
		dots.points.append([(ll.x + 180.0) / 360.0, (90.0 - ll.y) / 180.0, collected.has(city["key"])])
	dots.queue_redraw()
	UIThemeHelper.apply_safe_area_top(margin)

func _on_back_pressed() -> void:
	UIThemeHelper.go_to(self, "res://scenes/ui/main_menu.tscn")
