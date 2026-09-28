extends RefCounted
class_name UIThemeHelper

## UIThemeHelper: Utilidad central de diseño y estilos visuales State.io 2.5D
## Proporciona temas, botones táctiles con relieve, feedback elástico (tween bounce) y tarjetas de interfaz.

const COLOR_BG: Color = Color(0.10, 0.12, 0.16)
const COLOR_CARD: Color = Color(0.14, 0.17, 0.22, 0.94)
const COLOR_CARD_BORDER: Color = Color(0.26, 0.34, 0.44, 0.75)
const COLOR_PRIMARY: Color = Color(0.13, 0.59, 0.95)       # Azul brillante State.io
const COLOR_ACCENT: Color = Color(1.0, 0.82, 0.18)        # Oro brillante
const COLOR_SUCCESS: Color = Color(0.22, 0.75, 0.38)       # Verde esmeralda
const COLOR_DANGER: Color = Color(0.96, 0.26, 0.21)        # Rojo carmesí
const COLOR_NEUTRAL: Color = Color(0.47, 0.56, 0.61)       # Gris pizarra
const COLOR_HEADER_PILL: Color = Color(0.08, 0.10, 0.14, 0.88)
const COLOR_PILL_BORDER: Color = Color(0.35, 0.45, 0.58, 0.60)
## Botones secundarios: volver, sonido, pausa
const COLOR_BTN_SECONDARY: Color = Color(0.18, 0.24, 0.32)

## Textos de las píldoras de la cabecera, iguales en todas las pantallas
static func coins_text(amount: int) -> String:
	return "🪙 %d" % amount

static func stars_text() -> String:
	return "⭐ %d/%d" % [GameManager.get_total_stars(), GameManager.get_max_possible_stars()]

## Valoración de 0 a 3 estrellas, p. ej. "⭐⭐☆"
static func star_rating(stars: int) -> String:
	return "⭐".repeat(stars) + "☆".repeat(3 - stars)

## Escena desde la que se llegó a la actual (para volver a ella)
static var previous_scene: String = ""

## Botón pulsado: sonido de clic y cambio de escena
static func go_to(from: Node, scene_path: String) -> void:
	AudioManager.play_click()
	var current := from.get_tree().current_scene
	previous_scene = current.scene_file_path if current else ""
	from.get_tree().change_scene_to_file(scene_path)

## Desplaza hacia abajo una cabecera anclada arriba para que no quede bajo el notch o la cámara
static func apply_safe_area_top(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var inset := get_safe_area_top(control)
	control.offset_top += inset
	control.offset_bottom += inset

## Alto de la muesca o barra de estado del móvil en coordenadas del lienzo (0 en escritorio)
static func get_safe_area_top(control: Control) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var window_h := DisplayServer.window_get_size().y
	if window_h <= 0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * control.get_viewport_rect().size.y / float(window_h)

## Tarjeta modal centrada con título, texto y un botón. Devuelve el contenedor a pantalla completa
## que hay que añadir a la escena; la tarjeta aparece con la animación de pop-in.
## Con `backdrop` oscurece el fondo y bloquea los toques (si la escena no se pausa por debajo).
static func create_modal_card(title: String, body: String, button_text: String, on_press: Callable, backdrop: bool = false) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	apply_card_style(panel, Color(0.12, 0.15, 0.20, 0.97), COLOR_ACCENT, 24, 3)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	margin.add_child(vbox)
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 52)
	lbl_title.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(lbl_title)
	var lbl_body = Label.new()
	lbl_body.text = body
	lbl_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_body.add_theme_font_size_override("font_size", 34)
	vbox.add_child(lbl_body)
	var btn = Button.new()
	btn.name = "BtnConfirm"
	btn.text = button_text
	btn.add_theme_font_size_override("font_size", 36)
	btn.custom_minimum_size = Vector2(0, 100)
	apply_stateio_button_style(btn, COLOR_SUCCESS, 18, 6)
	btn.pressed.connect(on_press)
	vbox.add_child(btn)
	# El CenterContainer centra la tarjeta una vez conocido el ancho con ajuste de línea
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var root: Control = center
	if backdrop:
		root = ColorRect.new()
		root.color = Color(0, 0, 0, 0.6)
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

## Botón de música: el icono se atenúa cuando la música está silenciada
static func update_music_button(btn: Button, muted: bool) -> void:
	btn.text = "🎵"
	btn.modulate = Color(1, 1, 1, 0.35) if muted else Color.WHITE
	btn.tooltip_text = "Música desactivada" if muted else "Música activada"

## Aplica el estilo 2.5D State.io con relieve y sombreado proyectado a cualquier botón.
## El borde inferior (relieve) es el fondo oscurecido salvo que se indique `border_color`.
static func apply_stateio_button_style(
	btn: Button,
	bg_color: Color = COLOR_PRIMARY,
	corner_radius: int = 16,
	border_depth: int = 5,
	border_color: Color = Color.TRANSPARENT
) -> void:
	var dark_border = border_color if border_color != Color.TRANSPARENT else bg_color.darkened(0.30)
	var pressed_depth := maxi(1, border_depth - 3)
	btn.add_theme_stylebox_override("normal", _button_box(bg_color, dark_border, corner_radius, border_depth,
		Color(0, 0, 0, 0.35), 4, 3.0, 10.0))
	btn.add_theme_stylebox_override("hover", _button_box(bg_color.lightened(0.09), dark_border.lightened(0.12),
		corner_radius, border_depth, Color(bg_color, 0.45), 6, 3.0, 10.0))
	btn.add_theme_stylebox_override("pressed", _button_box(bg_color.darkened(0.12), dark_border, corner_radius,
		pressed_depth, Color(0, 0, 0, 0.20), 2, 1.0, 13.0))
	btn.add_theme_stylebox_override("disabled", _button_box(Color(0.20, 0.23, 0.28, 0.70), Color(0.15, 0.18, 0.22, 0.60),
		corner_radius, 2, Color.TRANSPARENT, 0, 0.0, 10.0))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62))
	setup_button_bounce(btn)

static func _button_box(bg: Color, border: Color, radius: int, depth: int, shadow: Color, shadow_size: int,
		shadow_y: float, margin_top: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_bottom = depth
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, shadow_y)
	box.content_margin_top = margin_top
	box.content_margin_bottom = 10.0 + depth
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	return box

## Animación táctil de escala al pasar por encima, pulsar y soltar (una sola vez por botón)
static func setup_button_bounce(btn: Button) -> void:
	if btn.has_meta("_bounce_setup"):
		return
	btn.set_meta("_bounce_setup", true)
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)
	btn.pivot_offset = btn.size * 0.5
	var bounce = func(target: Vector2, duration: float, trans: Tween.TransitionType, only_enabled: bool):
		if not btn.is_inside_tree() or (only_enabled and btn.disabled):
			return
		_kill_meta_tween(btn, "_bounce_tween")
		var tw = btn.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_bounce_tween", tw)
		tw.tween_property(btn, "scale", target, duration)
	btn.mouse_entered.connect(bounce.bind(Vector2(1.035, 1.035), 0.12, Tween.TRANS_BACK, true))
	btn.mouse_exited.connect(bounce.bind(Vector2.ONE, 0.10, Tween.TRANS_CUBIC, false))
	btn.button_down.connect(bounce.bind(Vector2(0.95, 0.95), 0.08, Tween.TRANS_BACK, true))
	btn.button_up.connect(bounce.bind(Vector2.ONE, 0.18, Tween.TRANS_ELASTIC, false))

static func _kill_meta_tween(node: Node, key: String) -> void:
	if node.has_meta(key) and node.get_meta(key).is_valid():
		node.get_meta(key).kill()

## Aplica estilo de tarjeta/panel moderno a paneles o contenedores
static func apply_card_style(
	panel: Control,
	bg_color: Color = COLOR_CARD,
	border_color: Color = COLOR_CARD_BORDER,
	corner_radius: int = 18,
	border_width: int = 2
) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_bottom = border_width + 1
	style.border_width_top = border_width
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_color = border_color
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

## Aplica estilo tipo píldora/badge para indicadores de recursos (oro, estrellas, etc.)
static func apply_pill_style(
	control: Control,
	bg_color: Color = COLOR_HEADER_PILL,
	border_color: Color = COLOR_PILL_BORDER,
	corner_radius: int = 20
) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = border_color
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	control.add_theme_stylebox_override("panel", style)

## Aplica animación elástica de entrada (Pop-in) a un panel modal
static func animate_modal_pop_in(modal: Control) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	_kill_meta_tween(modal, "_modal_tween")
	modal.visible = true
	modal.pivot_offset = modal.size * 0.5
	modal.scale = Vector2(0.70, 0.70)
	modal.modulate = Color(1, 1, 1, 0.0)

	var tw = modal.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal.set_meta("_modal_tween", tw)
	tw.tween_property(modal, "scale", Vector2.ONE, 0.28)
	tw.parallel().tween_property(modal, "modulate:a", 1.0, 0.18)

## Aplica animación de salida (Pop-out) antes de ocultar
## `on_complete` se llama siempre (también sin animación), porque suele reanudar la partida.
static func animate_modal_pop_out(modal: Control, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		if is_instance_valid(modal):
			modal.visible = false
		if on_complete.is_valid():
			on_complete.call()
		return
	_kill_meta_tween(modal, "_modal_tween")
	modal.pivot_offset = modal.size * 0.5
	var tw = modal.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	modal.set_meta("_modal_tween", tw)
	tw.tween_property(modal, "scale", Vector2(0.75, 0.75), 0.18)
	tw.parallel().tween_property(modal, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		if is_instance_valid(modal):
			modal.visible = false
			modal.scale = Vector2.ONE
			modal.modulate = Color.WHITE
		if on_complete.is_valid():
			on_complete.call()
	)
