extends Node

## Genera los recursos gráficos que Google Play pide para la ficha, sin editores externos:
## el gráfico destacado 1024×500 (obligatorio y sin canal alfa) y una copia ordenada de las
## capturas de 1080×1920 que ya produce el comprobador `--ui`.
##
##   godot --path . res://scenes/tests/store_assets.tscn
##   (necesita pantalla real o xvfb-run: en modo headless no se dibuja nada)

const OUT_DIR := "res://docs/store_assets"
const SHOTS_DIR := "user://"
## Capturas de la ficha, en orden: lo que explica el juego en cinco segundos
const SHOTS := ["menu", "battle", "victory", "army", "challenges", "progress"]
const LANGS := ["es", "en"]
const BANNER := Vector2i(1024, 500)

var _icon: Texture2D

func _ready() -> void:
	_icon = load("res://icon.svg") # Vectorial: conserva las esquinas redondeadas de la marca
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for lang in LANGS:
		DirAccess.make_dir_recursive_absolute("%s/screenshots_%s" % [OUT_DIR, lang])
	await _save_feature_graphic()
	_copy_screenshots()
	get_tree().quit()

## Gráfico destacado: fondo, mapa de territorios tenue y la marca (baldosa + nombre).
## Play exige 1024×500 y 24 bits, así que la imagen se guarda sin canal alfa.
func _save_feature_graphic() -> void:
	var viewport := SubViewport.new()
	viewport.size = BANNER
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var banner := Banner.new()
	banner.size = Vector2(BANNER)
	banner.custom_minimum_size = Vector2(BANNER)
	viewport.add_child(banner)
	banner.add_child(_brand_tile())
	banner.add_child(_wordmark())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw()
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8) # Sin alfa: Play rechaza un PNG con transparencia
	var path := OUT_DIR + "/feature-graphic-1024x500.png"
	var error := image.save_png(path)
	print("gráfico destacado %dx%d -> %s (%s)" % [image.get_width(), image.get_height(),
		path.get_file(), "OK" if error == OK else "ERROR %d" % error])

## Icono del juego con una sombra que lo separa del fondo, como una app instalada
func _brand_tile() -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(196, 196)
	tile.position = Vector2(72, 152)
	var shadow := UIThemeHelper.box(Color.TRANSPARENT, 24, 0)
	shadow.draw_center = false
	shadow.shadow_color = Color(0, 0, 0, 0.6)
	shadow.shadow_size = 26
	shadow.shadow_offset = Vector2(0, 12)
	tile.add_theme_stylebox_override("panel", shadow)
	var icon := TextureRect.new()
	icon.texture = _icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.add_child(icon)
	return tile

## Nombre del juego y, debajo, una ruta con tres bases: el motivo del juego sin usar texto
func _wordmark() -> Control:
	var block := UIThemeHelper.vbox(18)
	block.position = Vector2(304, 158)
	var row := UIThemeHelper.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for entry in [["invade", UIThemeHelper.colors.text], [".io", UIThemeHelper.colors.primary]]:
		var label := UIThemeHelper.label(entry[0], "", entry[1])
		label.add_theme_font_override("font", UIThemeHelper.bold_font())
		label.add_theme_font_size_override("font_size", 96)
		row.add_child(label)
	block.add_child(row)
	var route := RouteLine.new()
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.custom_minimum_size = Vector2(0, 34)
	block.add_child(route)
	return block

## Copia las capturas del comprobador con el nombre y el orden que espera la ficha
func _copy_screenshots() -> void:
	for lang in LANGS:
		for shot in SHOTS:
			var source := "%s%s_%s_false.png" % [SHOTS_DIR, shot, lang]
			if not FileAccess.file_exists(source):
				push_warning("falta la captura %s: ejecuta antes el comprobador --ui" % source)
				continue
			var target := "%s/screenshots_%s/%d_%s.png" % [OUT_DIR, lang, SHOTS.find(shot) + 1, shot]
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(source),
					ProjectSettings.globalize_path(target)) == OK:
				print("captura -> %s" % target.get_file())

## Línea de ruta con tres bases: neutral, jugador (anillo blanco) y rival
class RouteLine extends Control:
	func _draw() -> void:
		var y := size.y * 0.5
		var points := [Vector2(14, y), Vector2(size.x * 0.5, y), Vector2(size.x - 14, y)]
		draw_line(points[0], points[2], Color(1, 1, 1, 0.18), 3.0, true)
		var colors := [Color("8796a5"), Color("2f9bff"), Color("f2544d")]
		for i in points.size():
			if i == 1:
				draw_arc(points[i], 17.0, 0, TAU, 40, Color(1, 1, 1, 0.75), 3.0, true)
			draw_circle(points[i], 11.0, colors[i])

## El fondo (degradado y mapa tenue) se dibuja aquí; la marca son nodos hijos, así que va encima.
class Banner extends Control:
	const FACTION := {0: Color("8796a5"), 1: Color("2f9bff"), 2: Color("f2544d"), 3: Color("ffc83d")}

	var _bases: Array[Dictionary] = []
	var _gradient: GradientTexture2D

	func _ready() -> void:
		var gradient := Gradient.new()
		gradient.set_color(0, Color("17243c"))
		gradient.set_color(1, Color("0b1220"))
		_gradient = GradientTexture2D.new()
		_gradient.gradient = gradient
		_gradient.width = 1024
		_gradient.height = 500
		_gradient.fill_from = Vector2(0.1, 0.0)
		_gradient.fill_to = Vector2(0.9, 1.0)
		# Mapa determinista y tenue, sólo en la franja derecha: textura, nunca protagonista
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261011
		for i in 9:
			_bases.append({
				"pos": Vector2(rng.randf_range(620.0, 990.0), rng.randf_range(60.0, 440.0)),
				"radius": rng.randf_range(8.0, 17.0),
				"faction": [1, 2, 0, 3, 1, 2, 0, 3, 1][i],
			})

	func _draw() -> void:
		draw_texture_rect(_gradient, Rect2(Vector2.ZERO, size), false)
		_draw_routes()
		for base in _bases:
			var color: Color = FACTION[int(base["faction"])]
			var radius: float = base["radius"]
			var center: Vector2 = base["pos"]
			if int(base["faction"]) == 1:
				draw_arc(center, radius + 7.0, 0, TAU, 40, Color(1, 1, 1, 0.28), 2.0, true)
			draw_circle(center, radius, Color(color, 0.36))

	## Rutas entre bases cercanas, como las órdenes de la batalla
	func _draw_routes() -> void:
		for a in _bases.size():
			for b in range(a + 1, _bases.size()):
				var p1: Vector2 = _bases[a]["pos"]
				var p2: Vector2 = _bases[b]["pos"]
				var distance := p1.distance_to(p2)
				if distance > 190.0:
					continue
				draw_line(p1, p2, Color(1, 1, 1, (1.0 - distance / 190.0) * 0.17), 2.0, true)

