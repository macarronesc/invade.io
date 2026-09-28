extends RefCounted
class_name UIThemeHelper

## UIThemeHelper: Utilidad central de diseño y estilos visuales State.io 2.5D
## Proporciona temas, botones táctiles con relieve, feedback elástico (tween bounce) y tarjetas de interfaz.

const COLOR_BG: Color = Color(0.10, 0.12, 0.16)
const COLOR_CARD: Color = Color(0.14, 0.17, 0.22, 0.94)
const COLOR_CARD_BORDER: Color = Color(0.26, 0.34, 0.44, 0.75)
const COLOR_PRIMARY: Color = Color(0.13, 0.59, 0.95)       # Azul brillante State.io
const COLOR_PRIMARY_DARK: Color = Color(0.08, 0.38, 0.68)
const COLOR_ACCENT: Color = Color(1.0, 0.82, 0.18)        # Oro brillante
const COLOR_ACCENT_DARK: Color = Color(0.78, 0.58, 0.08)
const COLOR_SUCCESS: Color = Color(0.22, 0.75, 0.38)       # Verde esmeralda
const COLOR_SUCCESS_DARK: Color = Color(0.12, 0.48, 0.22)
const COLOR_DANGER: Color = Color(0.96, 0.26, 0.21)        # Rojo carmesí
const COLOR_DANGER_DARK: Color = Color(0.68, 0.14, 0.12)
const COLOR_NEUTRAL: Color = Color(0.47, 0.56, 0.61)       # Gris pizarra
const COLOR_NEUTRAL_DARK: Color = Color(0.30, 0.38, 0.43)
const COLOR_HEADER_PILL: Color = Color(0.08, 0.10, 0.14, 0.88)

## Desplaza hacia abajo una cabecera anclada arriba para que no quede bajo el notch o la cámara
static func apply_safe_area_top(control: Control) -> void:
	if not is_instance_valid(control) or not OS.has_feature("mobile"):
		return
	var window_h := DisplayServer.window_get_size().y
	if window_h <= 0:
		return
	var inset := float(DisplayServer.get_display_safe_area().position.y) * control.get_viewport_rect().size.y / float(window_h)
	control.offset_top += inset
	control.offset_bottom += inset

## Aplica el estilo 2.5D State.io con relieve y sombreado proyectado a cualquier botón
static func apply_stateio_button_style(
	btn: Button,
	bg_color: Color = COLOR_PRIMARY,
	border_color: Color = Color.TRANSPARENT,
	corner_radius: int = 16,
	border_depth: int = 5
) -> void:
	if not is_instance_valid(btn):
		return
		
	var dark_border = border_color if border_color != Color.TRANSPARENT else bg_color.darkened(0.30)
	
	# Estado Normal
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.border_width_bottom = border_depth
	style_normal.border_color = dark_border
	style_normal.set_corner_radius_all(corner_radius)
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style_normal.shadow_size = 4
	style_normal.shadow_offset = Vector2(0, 3)
	style_normal.content_margin_top = 10.0
	style_normal.content_margin_bottom = 10.0 + float(border_depth)
	style_normal.content_margin_left = 18.0
	style_normal.content_margin_right = 18.0
	
	# Estado Hover (cursor encima)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = bg_color.lightened(0.09)
	style_hover.border_width_bottom = border_depth
	style_hover.border_color = dark_border.lightened(0.12)
	style_hover.set_corner_radius_all(corner_radius)
	style_hover.shadow_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.45)
	style_hover.shadow_size = 6
	style_hover.shadow_offset = Vector2(0, 3)
	style_hover.content_margin_top = 10.0
	style_hover.content_margin_bottom = 10.0 + float(border_depth)
	style_hover.content_margin_left = 18.0
	style_hover.content_margin_right = 18.0
	
	# Estado Pressed (pulsado/hundido)
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = bg_color.darkened(0.12)
	style_pressed.border_width_bottom = maxi(1, border_depth - 3)
	style_pressed.border_color = dark_border
	style_pressed.set_corner_radius_all(corner_radius)
	style_pressed.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style_pressed.shadow_size = 2
	style_pressed.shadow_offset = Vector2(0, 1)
	style_pressed.content_margin_top = 13.0
	style_pressed.content_margin_bottom = 10.0 + float(maxi(1, border_depth - 3))
	style_pressed.content_margin_left = 18.0
	style_pressed.content_margin_right = 18.0
	
	# Estado Disabled
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.20, 0.23, 0.28, 0.70)
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.15, 0.18, 0.22, 0.60)
	style_disabled.set_corner_radius_all(corner_radius)
	style_disabled.shadow_size = 0
	style_disabled.content_margin_top = 10.0
	style_disabled.content_margin_bottom = 12.0
	style_disabled.content_margin_left = 18.0
	style_disabled.content_margin_right = 18.0
	
	# Estado Focus
	var style_focus = StyleBoxEmpty.new()
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	btn.add_theme_stylebox_override("focus", style_focus)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 0.92, 0.92))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62))
	
	setup_button_bounce(btn)

## Configura animación reactiva táctil de escala (Tween bounce) al interactuar con el botón
static func setup_button_bounce(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	if btn.has_meta("_bounce_setup"):
		return
	btn.set_meta("_bounce_setup", true)
	
	var update_pivot = func():
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size * 0.5
			
	if not btn.resized.is_connected(update_pivot):
		btn.resized.connect(update_pivot)
	update_pivot.call()
	
	var kill_bounce_tween = func():
		if is_instance_valid(btn) and btn.has_meta("_bounce_tween"):
			var old_tw = btn.get_meta("_bounce_tween") as Tween
			if old_tw and old_tw.is_valid():
				old_tw.kill()
	
	var on_enter = func():
		if not is_instance_valid(btn) or btn.disabled or not btn.is_inside_tree():
			return
		update_pivot.call()
		kill_bounce_tween.call()
		var tw = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_bounce_tween", tw)
		tw.tween_property(btn, "scale", Vector2(1.035, 1.035), 0.12)
		
	var on_exit = func():
		if not is_instance_valid(btn) or not btn.is_inside_tree():
			return
		update_pivot.call()
		kill_bounce_tween.call()
		var tw = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_bounce_tween", tw)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.10)
		
	var on_down = func():
		if not is_instance_valid(btn) or btn.disabled or not btn.is_inside_tree():
			return
		update_pivot.call()
		kill_bounce_tween.call()
		var tw = btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_bounce_tween", tw)
		tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08)
		
	var on_up = func():
		if not is_instance_valid(btn) or not btn.is_inside_tree():
			return
		update_pivot.call()
		kill_bounce_tween.call()
		var tw = btn.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		btn.set_meta("_bounce_tween", tw)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.18)
		
	btn.mouse_entered.connect(on_enter)
	btn.mouse_exited.connect(on_exit)
	btn.button_down.connect(on_down)
	btn.button_up.connect(on_up)

## Aplica estilo de tarjeta/panel moderno a paneles o contenedores
static func apply_card_style(
	panel: Control,
	bg_color: Color = COLOR_CARD,
	border_color: Color = COLOR_CARD_BORDER,
	corner_radius: int = 18,
	border_width: int = 2
) -> void:
	if not is_instance_valid(panel):
		return
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
	
	if panel is Panel:
		panel.add_theme_stylebox_override("panel", style)
	elif panel is PanelContainer:
		panel.add_theme_stylebox_override("panel", style)

## Aplica estilo tipo píldora/badge para indicadores de recursos (oro, estrellas, etc.)
static func apply_pill_style(
	control: Control,
	bg_color: Color = COLOR_HEADER_PILL,
	border_color: Color = Color(0.30, 0.40, 0.52, 0.65),
	corner_radius: int = 22
) -> void:
	if not is_instance_valid(control):
		return
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
	
	if control is Panel:
		control.add_theme_stylebox_override("panel", style)
	elif control is PanelContainer:
		control.add_theme_stylebox_override("panel", style)

## Aplica animación elástica de entrada (Pop-in) a un panel modal
static func animate_modal_pop_in(modal: Control) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	if modal.has_meta("_modal_tween"):
		var old_tw = modal.get_meta("_modal_tween") as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
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
static func animate_modal_pop_out(modal: Control, on_complete: Callable = Callable()) -> void:
	if not is_instance_valid(modal) or not modal.is_inside_tree():
		return
	if modal.has_meta("_modal_tween"):
		var old_tw = modal.get_meta("_modal_tween") as Tween
		if old_tw and old_tw.is_valid():
			old_tw.kill()
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
