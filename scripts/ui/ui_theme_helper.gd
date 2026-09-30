extends RefCounted
class_name UIThemeHelper

## Sistema visual de invade.io: paleta, tipografía, tema global y piezas de interfaz comunes.
## `install()` fusiona el tema con el de Godot, así que cualquier Control (también en capas,
## diálogos y listas desplegables) hereda el mismo aspecto sin estilos sueltos por pantalla.
## Variaciones: Label → Display, Title, Heading, Caption · Button → PrimaryButton, GoldButton,
## GhostButton, IconButton, NavButton, SegmentButton, RowButton · PanelContainer → Sheet, Chip,
## Tile, NavBar · Panel → Badge · ProgressBar → GoldBar.

const BATTLE_SCENE := "res://scenes/battle/battle_field.tscn"

## Paletas de interfaz. El mapa de batalla no cambia con ellas: tiene su propio tema (tienda).
## "ink" es el texto sobre los botones de color primario y dorado.
const PALETTES := {
	"dark": {"bg": Color("0e1624"), "surface": Color("172234"), "surface_2": Color("22314a"), "line": Color("2c3d59"),
		"text": Color("eaf1fa"), "muted": Color("8fa3bd"), "ink": Color("0b1a2e"),
		"primary": Color("2f9bff"), "gold": Color("ffc83d"), "success": Color("3dd68c"), "danger": Color("ff5a5f"), "neutral": Color("8fa3bd")},
	"light": {"bg": Color("f2f4f8"), "surface": Color("ffffff"), "surface_2": Color("e5eaf1"), "line": Color("d3dbe6"),
		"text": Color("15202f"), "muted": Color("5d6c80"), "ink": Color("ffffff"),
		"primary": Color("1668c8"), "gold": Color("865700"), "success": Color("087747"), "danger": Color("d63c43"), "neutral": Color("64748b")},
}
## Velo bajo las capas modales (igual en ambos modos)
const COLOR_SCRIM := Color(0.02, 0.04, 0.08, 0.6)

static var palette_name := "dark"
static var colors: Dictionary = PALETTES.dark

const RADIUS := 28
const SPACE := 24
const PAGE_MARGIN := 40
const FONT_BODY := 30
const FONT_WEIGHT_TAG := 2003265652 # 'wght'

static var _bold: FontVariation

static func bold_font() -> FontVariation:
	if _bold == null:
		var base: FontVariation = load("res://assets/fonts/game_font.tres")
		_bold = FontVariation.new()
		_bold.base_font = base.base_font
		_bold.fallbacks = base.fallbacks
		_bold.variation_opentype = {FONT_WEIGHT_TAG: 700}
	return _bold

## Aplica el tema y el feedback táctil a toda la aplicación (una vez, desde un autoload)
static func install(tree: SceneTree, light: bool) -> void:
	apply_palette(tree, light)
	tree.node_added.connect(func(node: Node):
		if node is BaseButton:
			setup_press_feedback(node))

## Cambia entre modo claro y oscuro al instante, sin recargar escenas. Los colores fijados
## con overrides los refresca cada pantalla al recibir EventBus.settings_changed.
static func apply_palette(tree: SceneTree, light: bool) -> void:
	var name := "light" if light else "dark"
	if name == palette_name and tree.has_meta("_theme_installed"):
		return
	tree.set_meta("_theme_installed", true)
	palette_name = name
	colors = PALETTES[name]
	ThemeDB.get_default_theme().merge_with(build_theme())
	if tree.root:
		tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	# Texto
	t.set_color("font_color", "Label", colors.text)
	for v in [["Display", 76, true], ["Title", 46, true], ["Heading", 34, true], ["Caption", 24, false]]:
		t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], v[1])
		if v[2]:
			t.set_font("font", v[0], bold_font())
	t.set_color("font_color", "Caption", colors.muted)

	# Botones: secundario por defecto y variaciones por énfasis
	_button_type(t, "Button", colors.surface_2, colors.text)
	_button_type(t, "OptionButton", colors.surface_2, colors.text)
	for b in [["PrimaryButton", colors.primary, colors.ink], ["GoldButton", colors.gold, colors.ink]]:
		t.set_type_variation(b[0], "Button")
		_button_type(t, b[0], b[1], b[2])
		t.set_font_size("font_size", b[0], 34)
		t.set_font("font", b[0], bold_font())
	t.set_type_variation("GhostButton", "Button")
	_flat_button(t, "GhostButton", Color.TRANSPARENT, colors.surface, colors.muted, colors.text)
	t.set_type_variation("SegmentButton", "Button")
	_flat_button(t, "SegmentButton", Color.TRANSPARENT, colors.surface_2, colors.muted, colors.text)
	t.set_type_variation("NavButton", "Button")
	_flat_button(t, "NavButton", Color.TRANSPARENT, Color.TRANSPARENT, colors.muted, colors.primary)
	t.set_font_size("font_size", "NavButton", 22)
	t.set_constant("h_separation", "NavButton", 4)
	t.set_type_variation("RowButton", "Button")
	_flat_button(t, "RowButton", colors.surface, colors.surface_2, colors.text, colors.text)
	t.set_type_variation("IconButton", "Button")
	_flat_button(t, "IconButton", colors.surface, colors.surface_2, colors.text, colors.text)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBoxFlat = t.get_stylebox(state, "IconButton")
		box.set_corner_radius_all(999)
		box.set_content_margin_all(22)

	# Paneles
	t.set_stylebox("panel", "PanelContainer", box(colors.surface, RADIUS, 32))
	t.set_type_variation("Sheet", "PanelContainer")
	var sheet := box(colors.surface, 40, 48)
	sheet.set_border_width_all(2)
	sheet.border_color = colors.line
	sheet.shadow_color = Color(0, 0, 0, 0.45 if palette_name == "dark" else 0.12)
	sheet.shadow_size = 24
	t.set_stylebox("panel", "Sheet", sheet)
	t.set_type_variation("Chip", "PanelContainer")
	var chip := box(colors.surface_2, 999, 10)
	chip.content_margin_left = 22
	chip.content_margin_right = 22
	t.set_stylebox("panel", "Chip", chip)
	t.set_type_variation("Tile", "PanelContainer")
	t.set_stylebox("panel", "Tile", box(colors.surface_2, 24, 20))
	t.set_type_variation("NavBar", "PanelContainer")
	var nav := box(colors.surface, 0, 8)
	nav.border_width_top = 2
	nav.border_color = colors.line
	t.set_stylebox("panel", "NavBar", nav)
	t.set_type_variation("Badge", "Panel")
	t.set_stylebox("panel", "Badge", box(colors.gold, 999, 0))
	# Cabecera de batalla: superficie translúcida para leerse sobre cualquier tema de mapa
	t.set_type_variation("HudBar", "PanelContainer")
	var hud := box(Color(colors.surface, 0.92), 32, 20)
	hud.set_border_width_all(2)
	hud.border_color = Color(colors.line, 0.8)
	t.set_stylebox("panel", "HudBar", hud)

	# Progreso, desplazamiento, interruptores y deslizadores
	t.set_stylebox("background", "ProgressBar", box(colors.surface_2, 999, 0))
	t.set_stylebox("fill", "ProgressBar", box(colors.primary, 999, 0))
	t.set_type_variation("GoldBar", "ProgressBar")
	t.set_stylebox("fill", "GoldBar", box(colors.gold, 999, 0))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var grabber := box(colors.line, 999, 0)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(s, "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_top = 14
		empty.content_margin_bottom = 14
		t.set_stylebox(s, "CheckButton", empty)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", colors.text)
	t.set_icon("checked", "CheckButton", Icons.texture("toggle_on", 64))
	t.set_icon("unchecked", "CheckButton", Icons.texture("toggle_off", 64))
	var track := box(colors.surface_2, 999, 0)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	t.set_stylebox("slider", "HSlider", track)
	var filled := box(colors.primary, 999, 0)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", Icons.texture("knob", 44))
	t.set_icon("grabber_highlight", "HSlider", Icons.texture("knob", 44))
	t.set_icon("arrow", "OptionButton", Icons.texture("chevron_down", 36))

	# Listas desplegables y diálogos nativos de Godot
	var popup := box(colors.surface, 24, 16)
	popup.set_border_width_all(2)
	popup.border_color = colors.line
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", box(colors.surface_2, 16, 0))
	t.set_font_size("font_size", "PopupMenu", FONT_BODY)
	t.set_constant("v_separation", "PopupMenu", 28)
	t.set_color("font_color", "PopupMenu", colors.text)
	t.set_color("font_hover_color", "PopupMenu", colors.text)
	t.set_stylebox("panel", "AcceptDialog", box(colors.surface, 0, 32))
	var border := box(colors.surface, 28, 0)
	border.set_expand_margin_all(8)
	border.expand_margin_top = 80
	t.set_stylebox("embedded_border", "Window", border)
	t.set_stylebox("embedded_unfocused_border", "Window", border)
	t.set_font_size("title_font_size", "Window", FONT_BODY)
	t.set_constant("title_height", "Window", 72)
	t.set_color("title_color", "Window", colors.text)
	return t

static func box(color: Color, radius: int, padding: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(padding)
	b.anti_aliasing = true
	return b

## Botón macizo con un leve canto inferior; al pulsar se hunde
static func _button_type(t: Theme, type: String, color: Color, ink: Color) -> void:
	var edge := color.darkened(0.35)
	var states := {
		"normal": [color, 4], "hover": [color.lightened(0.08), 4],
		"pressed": [color.darkened(0.1), 1], "hover_pressed": [color.darkened(0.1), 1],
		"disabled": [Color(colors.surface_2, 0.55), 0],
	}
	for state in states:
		var b := box(states[state][0], 24, 0)
		b.border_width_bottom = states[state][1]
		b.border_color = edge
		b.content_margin_left = 32
		b.content_margin_right = 32
		b.content_margin_top = 18 + (4 - states[state][1])
		b.content_margin_bottom = 18
		t.set_stylebox(state, type, b)
	var focus := box(Color.TRANSPARENT, 26, 0)
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = colors.primary.lightened(0.3)
	t.set_stylebox("focus", type, focus)
	_button_colors(t, type, ink, ink, colors.muted)

## Botón plano: fondo sólo al pulsarlo o al estar activo (toggle)
static func _flat_button(t: Theme, type: String, normal: Color, active: Color, ink: Color, active_ink: Color) -> void:
	for state in ["normal", "disabled"]:
		t.set_stylebox(state, type, box(normal, 24, 18))
	for state in ["hover", "pressed", "hover_pressed"]:
		t.set_stylebox(state, type, box(active if state != "hover" else normal.lerp(active, 0.5), 24, 18))
	_button_colors(t, type, ink, active_ink, colors.muted)

static func _button_colors(t: Theme, type: String, ink: Color, active_ink: Color, disabled: Color) -> void:
	var state_colors := {"normal": ink, "hover": ink, "focus": ink, "pressed": active_ink, "hover_pressed": active_ink, "disabled": disabled}
	for state in state_colors:
		t.set_color("font_color" if state == "normal" else "font_%s_color" % state, type, state_colors[state])
		t.set_color("icon_%s_color" % state, type, state_colors[state])
	t.set_constant("h_separation", type, 14)
	t.set_constant("icon_max_width", type, 48)

# =========================================================================
# Piezas de interfaz
# =========================================================================

static func label(text: String, variation: String = "", color: Color = Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if color != Color.TRANSPARENT:
		l.add_theme_color_override("font_color", color)
	return l

## Texto que ocupa el ancho disponible y salta de línea
static func paragraph(text: String, variation: String = "Caption") -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func button(text: String, variation: String = "", icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	if icon != "":
		set_icon(b, icon)
	return b

## Icono de botón: los de trazo toman el color del texto; los de color propio (moneda) no se tiñen
static func set_icon(b: Button, icon: String, size: int = 44) -> void:
	b.icon = Icons.texture(icon, size)
	if icon in Icons.COLORED:
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_color_override("icon_%s_color" % state, Color.WHITE)
		b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.45))

static func icon_button(icon: String, tooltip: String) -> Button:
	var b := button("", "IconButton", icon)
	b.tooltip_text = tooltip
	return b

static func vbox(separation: int = SPACE) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b

static func hbox(separation: int = SPACE) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b

## Márgenes laterales de página alrededor de `content`
static func page_margin(content: Control, top: int = 0, bottom: int = 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", PAGE_MARGIN)
	m.add_theme_constant_override("margin_right", PAGE_MARGIN)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(content)
	return m

## Tarjeta con una columna dentro; devuelve la columna para ir añadiendo contenido
static func card(parent: Control, variation: String = "", separation: int = 20) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	parent.add_child(panel)
	var column := vbox(separation)
	panel.add_child(column)
	return column

## Fila de lista: elemento a la izquierda, título y subtítulo, y un elemento opcional a la derecha
static func item_row(leading: Control, title: String, subtitle: String, trailing: Control = null) -> HBoxContainer:
	var row := hbox(24)
	leading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(leading)
	var texts := vbox(4)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(label(title, "Heading"))
	texts.add_child(paragraph(subtitle))
	row.add_child(texts)
	if trailing:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(trailing)
	return row

## Círculo teñido con un icono o texto centrado
static func round_badge(content: Control, tint: Color, diameter: float = 96.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(diameter, diameter)
	panel.add_theme_stylebox_override("panel", box(Color(tint, 0.16), 999, 0))
	var center := CenterContainer.new()
	center.add_child(content)
	panel.add_child(center)
	return panel

static func chip(text: String, icon: String = "", color: Color = Color.TRANSPARENT) -> PanelContainer:
	if color == Color.TRANSPARENT:
		color = colors.text
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Chip"
	var row := hbox(10)
	panel.add_child(row)
	if icon != "":
		row.add_child(Icons.rect(icon, 32, color))
	var l := label(text, "Caption", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return panel

static func progress(value: float, max_value: float, variation: String = "") -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.max_value = maxf(max_value, 0.001)
	bar.value = value
	bar.custom_minimum_size.y = 16
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar

## Fila tocable de lista: icono, título, subtítulo y un indicador a la derecha
static func row_button(icon: String, title: String, subtitle: String, trailing: String, tint: Color = Color.TRANSPARENT) -> Button:
	if tint == Color.TRANSPARENT:
		tint = colors.primary
	var b := button("", "RowButton")
	b.custom_minimum_size.y = 128
	var row := item_row(round_badge(Icons.rect(icon, 52, tint), tint, 80), title, subtitle, Icons.rect(trailing, 40, colors.muted))
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -28
	b.add_child(row)
	for c in b.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

## Estrellas ★ doradas y ☆ pendientes
static func set_stars(l: Label, stars: int) -> void:
	l.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	l.add_theme_color_override("font_color", colors.gold if stars > 0 else colors.muted)

static func stars_label(stars: int, variation: String = "Heading") -> Label:
	var l := label("", variation)
	set_stars(l, stars)
	return l

## Título de sección con una línea explicativa opcional
static func section(parent: Control, title: String, subtitle: String = "", variation: String = "Title") -> void:
	var head := vbox(4)
	head.add_child(label(title, variation))
	if subtitle != "":
		head.add_child(paragraph(subtitle))
	parent.add_child(head)

## Vacía un contenedor al instante (los nodos se liberan al final del fotograma)
static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

# =========================================================================
# Navegación, zonas seguras y capas
# =========================================================================

## Botón pulsado: sonido de clic y cambio de escena
static func go_to(from: Node, scene_path: String) -> void:
	AudioManager.play_click()
	from.get_tree().change_scene_to_file(scene_path)

## Empieza una batalla; sin `level_id` repite la última elegida
static func start_battle(from: Node, level_id: String = "") -> void:
	if level_id != "":
		GameManager.play_level(level_id)
	go_to(from, BATTLE_SCENE)

## Desplaza hacia abajo una cabecera anclada arriba para que no quede bajo el notch o la cámara
static func apply_safe_area_top(control: Control) -> void:
	var inset := get_safe_area_top(control)
	control.offset_top += inset
	control.offset_bottom += inset

## Alto de la muesca o barra de estado del móvil en coordenadas del lienzo (0 en escritorio)
static func get_safe_area_top(control: Control) -> int:
	return _safe_insets(control).x

## Alto de la barra de gestos inferior en coordenadas del lienzo (0 en escritorio)
static func get_safe_area_bottom(control: Control) -> int:
	return _safe_insets(control).y

static func _safe_insets(control: Control) -> Vector2i:
	if not OS.has_feature("mobile"):
		return Vector2i.ZERO
	var window_h := DisplayServer.window_get_size().y
	if window_h <= 0:
		return Vector2i.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var to_canvas := control.get_viewport_rect().size.y / float(window_h)
	return Vector2i(Vector2(safe.position.y, maxi(0, window_h - safe.end.y)) * to_canvas)

## Página a pantalla completa (ajustes): cabecera con volver y título, y contenido desplazable.
static func overlay_page(root: Control, title: String, close: Callable) -> VBoxContainer:
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = colors.bg
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column := vbox(32)
	var margin := page_margin(column, 36 + get_safe_area_top(root), 24 + get_safe_area_bottom(root))
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(margin)
	var header := hbox(24)
	var back := icon_button("back", LocaleStrings.text("back"))
	back.pressed.connect(close)
	header.add_child(back)
	var heading := label(title, "Title")
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := vbox(SPACE)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

## Tarjeta modal centrada con título, texto (nodo "Body") y un botón ("BtnConfirm"). Devuelve el
## contenedor a pantalla completa que hay que añadir a la escena; la tarjeta aparece animada.
## Con `backdrop` oscurece el fondo y bloquea los toques (si la escena no se pausa por debajo).
static func create_modal_card(title: String, body: String, button_text: String, on_press: Callable, backdrop: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Sheet"
	panel.custom_minimum_size = Vector2(880, 0)
	var column := vbox(28)
	panel.add_child(column)
	var heading := label(title, "Title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var text := paragraph(body, "")
	text.name = "Body"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(text)
	var confirm := button(button_text, "PrimaryButton")
	confirm.name = "BtnConfirm"
	confirm.pressed.connect(on_press)
	column.add_child(confirm)
	# El CenterContainer centra la tarjeta una vez conocido el ancho con ajuste de línea
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var root: Control = center
	if backdrop:
		root = ColorRect.new()
		root.color = COLOR_SCRIM
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(center)
	root.tree_entered.connect(func():
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Diferido para conocer el tamaño final; la tarjeta puede cerrarse antes
		var panel_ref = weakref(panel)
		(func(): if panel_ref.get_ref(): animate_modal_pop_in(panel_ref.get_ref())).call_deferred()
	, CONNECT_ONE_SHOT)
	return root

## Tarjeta con los gestos del juego (se consulta en cualquier momento); se cierra sola
static func how_to_play_card() -> Control:
	var card := create_modal_card(LocaleStrings.text("how_to_play"), LocaleStrings.text("how_to_play_body"), LocaleStrings.text("tip_ok"), AudioManager.play_click, true)
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	(card.find_child("Body", true, false) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.find_child("BtnConfirm", true, false).pressed.connect(card.queue_free)
	return card

# =========================================================================
# Movimiento: sólo feedback de pulsación y entrada/salida de capas
# =========================================================================

static func setup_press_feedback(btn: BaseButton) -> void:
	if btn.has_meta("_press_feedback"):
		return
	btn.set_meta("_press_feedback", true)
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	var squeeze = func(target: float, duration: float):
		if not btn.is_inside_tree() or btn.disabled and target < 1.0:
			return
		_kill_meta_tween(btn, "_press_tween")
		if GameManager.settings["reduced_motion"]:
			btn.scale = Vector2.ONE
			return
		var tw := btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_press_tween", tw)
		tw.tween_property(btn, "scale", Vector2.ONE * target, duration)
	btn.button_down.connect(squeeze.bind(0.96, 0.06))
	btn.button_up.connect(squeeze.bind(1.0, 0.12))

static func _kill_meta_tween(node: Node, key: String) -> void:
	if node.has_meta(key) and node.get_meta(key).is_valid():
		node.get_meta(key).kill()

static func animate_modal_pop_in(modal: Control) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	_kill_meta_tween(modal, "_modal_tween")
	modal.visible = true
	if GameManager.settings["reduced_motion"]:
		modal.scale = Vector2.ONE
		modal.modulate = Color.WHITE
		return
	modal.pivot_offset = modal.size * 0.5
	modal.scale = Vector2(0.94, 0.94)
	modal.modulate = Color(1, 1, 1, 0.0)
	var tw := modal.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal.set_meta("_modal_tween", tw)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.2)
	tw.parallel().tween_property(modal, "modulate:a", 1.0, 0.16)

## `on_complete` se llama siempre (también sin animación), porque suele reanudar la partida.
static func animate_modal_pop_out(modal: Control, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		if is_instance_valid(modal):
			modal.visible = false
		if on_complete.is_valid():
			on_complete.call()
		return
	_kill_meta_tween(modal, "_modal_tween")
	if GameManager.settings["reduced_motion"]:
		modal.visible = false
		modal.scale = Vector2.ONE
		modal.modulate = Color.WHITE
		if on_complete.is_valid():
			on_complete.call()
		return
	modal.pivot_offset = modal.size * 0.5
	var tw := modal.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal.set_meta("_modal_tween", tw)
	tw.tween_property(modal, "scale", Vector2(0.96, 0.96), 0.12)
	tw.parallel().tween_property(modal, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		if is_instance_valid(modal):
			modal.visible = false
			modal.scale = Vector2.ONE
			modal.modulate = Color.WHITE
		if on_complete.is_valid():
			on_complete.call()
	)
