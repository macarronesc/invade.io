extends CanvasLayer
class_name LaunchOverlay

## Una conquista breve sobre la escena inicial, sin retrasar su carga ni repetirse al volver al menú.

static var _shown := false

class Artwork extends Control:
	const BRAND := preload("res://assets/brand/boot_splash.png")
	const BLUE := Color("2196f2")
	const BASES := [Vector2(-160, -160), Vector2(0, -212), Vector2(160, -160)]
	const BASE_COLORS := [BLUE, Color("8796a5"), Color("f54236")]
	const ARRIVAL := [0.0, 0.44, 0.82]
	var elapsed := -1.0
	var background: Color = UIThemeHelper.colors.bg
	var surface: Color = UIThemeHelper.colors.surface
	var line: Color = UIThemeHelper.colors.line

	func advance(value: float) -> void:
		elapsed = value
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), background)
		if elapsed < 0.0:
			return
		var fit := minf(size.x * 0.78 / 512.0, size.y * 0.72 / 512.0)
		draw_set_transform(size * 0.5, 0.0, Vector2.ONE * fit)
		var settle: float = Tween.interpolate_value(0.96, 0.04, minf(elapsed, 0.4), 0.4, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		draw_texture_rect(BRAND, Rect2(Vector2.ONE * -256.0 * settle, Vector2.ONE * 512.0 * settle), false)

		var reveal := clampf(elapsed / 0.18, 0.0, 1.0)
		draw_set_transform(size * 0.5 + Vector2(0, 12.0 * (1.0 - reveal) * fit), 0.0, Vector2.ONE * fit)
		for leg in 2:
			draw_line(BASES[leg], BASES[leg + 1], Color(line, reveal), 2.0, true)
			for troop in 6:
				var travel := (elapsed - 0.10 - leg * 0.38 - troop * 0.035) / 0.34
				if travel > 0.0 and travel < 1.0:
					var point: Vector2 = BASES[leg].lerp(BASES[leg + 1], travel)
					draw_circle(point, 4.0, Color(BLUE, reveal), true, -1.0, true)
		for i in 3:
			var capture := 1.0 if i == 0 else clampf((elapsed - ARRIVAL[i]) / 0.12, 0.0, 1.0)
			var color: Color = BASE_COLORS[i].lerp(BLUE, capture)
			draw_circle(BASES[i], 37.0, Color(color, 0.09 * reveal), true, -1.0, true)
			draw_circle(BASES[i], 25.0, Color(surface, reveal), true, -1.0, true)
			draw_circle(BASES[i], 19.0, Color(color, reveal), true, -1.0, true)
			if capture > 0.0:
				var pulse := clampf((elapsed - ARRIVAL[i]) / 0.28, 0.0, 1.0)
				draw_arc(BASES[i], 27.0 + pulse * 22.0, 0.0, TAU, 48, Color(BLUE, (1.0 - pulse) * reveal * 0.5), 2.0, true)

var _artwork: Artwork
var _tween: Tween
var _startup_frames := 0
var _last_frame_usec := 0

static func show_once(tree: SceneTree) -> void:
	if _shown:
		return
	_shown = true
	if GameManager.settings["reduced_motion"]:
		return
	# La capa pertenece a la raíz: el primer arranque cambia del menú al tutorial debajo de ella.
	tree.root.add_child(LaunchOverlay.new())

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_artwork = Artwork.new()
	_artwork.mouse_filter = Control.MOUSE_FILTER_STOP
	_artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_artwork)
	_tween = create_tween()
	_tween.tween_method(_artwork.advance, 0.0, 1.05, 1.05)
	_tween.tween_property(_artwork, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(queue_free)
	_tween.pause()
	RenderingServer.frame_post_draw.connect(_on_startup_frame)

func _on_startup_frame() -> void:
	_startup_frames += 1
	# El delta del segundo frame aún puede incluir toda la carga del primero (Android).
	if _startup_frames == 2:
		RenderingServer.frame_post_draw.disconnect(_on_startup_frame)
		_last_frame_usec = Time.get_ticks_usec()
		set_process(true)
	else:
		_artwork.queue_redraw() # También en un menú quieto con low_processor_mode.

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# Reloj propio: la velocidad de batalla no cambia la intro y un atasco no la salta.
	var step := minf((now - _last_frame_usec) / 1_000_000.0, 0.1)
	_last_frame_usec = now
	_tween.custom_step(step)

func _input(event: InputEvent) -> void:
	# Bloquea también _unhandled_input del mapa; el toque que salta la intro no envía tropas.
	get_viewport().set_input_as_handled()
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		queue_free()
