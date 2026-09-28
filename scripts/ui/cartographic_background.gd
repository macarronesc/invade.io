extends Control
class_name CartographicBackground

## CartographicBackground: Fondo cartográfico táctico State.io con cuadrícula geopolítica
## y nodos flotantes animados que simulan pequeñas batallas ambientales en segundo plano.

@export var grid_spacing: float = 75.0
@export var show_ambient_nodes: bool = false
@export var bg_color: Color = UIThemeHelper.COLOR_BG
@export var grid_line_color: Color = Color(0.22, 0.30, 0.40, 0.16)
@export var major_line_color: Color = Color(0.30, 0.42, 0.55, 0.22)
@export var crosshair_color: Color = Color(0.40, 0.55, 0.70, 0.35)

# Nodos ambientales para el menú principal
class AmbientNode:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var radius: float = 24.0
	var color: Color = Color.WHITE
	var pulse: float = 0.0

class AmbientTroop:
	var from_pos: Vector2
	var to_pos: Vector2
	var progress: float = 0.0
	var speed: float = 0.3
	var color: Color = Color.WHITE

var ambient_nodes: Array[AmbientNode] = []
var ambient_troops: Array[AmbientTroop] = []
var spawn_timer: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if show_ambient_nodes:
		_setup_ambient_nodes()

func _setup_ambient_nodes() -> void:
	ambient_nodes.clear()
	var colors = [
		UIThemeHelper.COLOR_PRIMARY, UIThemeHelper.COLOR_DANGER, UIThemeHelper.COLOR_ACCENT,
		UIThemeHelper.COLOR_SUCCESS, UIThemeHelper.COLOR_NEUTRAL, UIThemeHelper.COLOR_PRIMARY,
		UIThemeHelper.COLOR_DANGER, UIThemeHelper.COLOR_NEUTRAL,
	]

	var w = size.x if size.x > 0 else 1080.0
	var h = size.y if size.y > 0 else 1920.0

	for color in colors:
		var node = AmbientNode.new()
		node.pos = Vector2(randf_range(80, w - 80), randf_range(120, h - 120))
		var angle = randf_range(0, TAU)
		var spd = randf_range(12.0, 24.0)
		node.vel = Vector2(cos(angle) * spd, sin(angle) * spd)
		node.radius = randf_range(22.0, 32.0)
		node.color = color
		node.pulse = randf_range(0, TAU)
		ambient_nodes.append(node)

func _process(delta: float) -> void:
	if not show_ambient_nodes:
		return

	var w = size.x if size.x > 0 else 1080.0
	var h = size.y if size.y > 0 else 1920.0

	for n in ambient_nodes:
		n.pos += n.vel * delta
		n.pulse += delta * 2.5

		# Rebote suave en los bordes
		if n.pos.x < 60.0:
			n.pos.x = 60.0
			n.vel.x = absf(n.vel.x)
		elif n.pos.x > w - 60.0:
			n.pos.x = w - 60.0
			n.vel.x = -absf(n.vel.x)

		if n.pos.y < 100.0:
			n.pos.y = 100.0
			n.vel.y = absf(n.vel.y)
		elif n.pos.y > h - 100.0:
			n.pos.y = h - 100.0
			n.vel.y = -absf(n.vel.y)

	# Actualizar tropas ambientales
	spawn_timer += delta
	if spawn_timer >= 1.6 and ambient_nodes.size() >= 2:
		spawn_timer = 0.0
		for _attempt in range(6):
			var n1 = ambient_nodes[randi() % ambient_nodes.size()]
			var n2 = ambient_nodes[randi() % ambient_nodes.size()]
			if n1 != n2 and n1.pos.distance_to(n2.pos) < 420.0:
				var t = AmbientTroop.new()
				t.from_pos = n1.pos
				t.to_pos = n2.pos
				t.progress = 0.0
				t.speed = randf_range(0.25, 0.45)
				t.color = n1.color
				ambient_troops.append(t)
				break

	var i = ambient_troops.size() - 1
	while i >= 0:
		var tr = ambient_troops[i]
		tr.progress += delta * tr.speed
		if tr.progress >= 1.0:
			ambient_troops.remove_at(i)
		i -= 1

	queue_redraw()

func _draw() -> void:
	var w = size.x if size.x > 0 else 1080.0
	var h = size.y if size.y > 0 else 1920.0

	# 1. Relleno cartográfico base
	draw_rect(Rect2(0, 0, w, h), bg_color)

	# 2. Cuadrícula técnica (líneas finas y mayores)
	var spacing = maxf(grid_spacing, 20.0)
	var major_interval = spacing * 4.0

	var x = 0.0
	while x <= w:
		var is_major = int(round(x / spacing)) % 4 == 0
		var col = major_line_color if is_major else grid_line_color
		var width = 1.6 if is_major else 1.0
		draw_line(Vector2(x, 0), Vector2(x, h), col, width)
		x += spacing

	var y = 0.0
	while y <= h:
		var is_major = int(round(y / spacing)) % 4 == 0
		var col = major_line_color if is_major else grid_line_color
		var width = 1.6 if is_major else 1.0
		draw_line(Vector2(0, y), Vector2(w, y), col, width)
		y += spacing

	# 3. Marcas cruciformes (+) en intersecciones mayores
	x = major_interval
	while x < w:
		y = major_interval
		while y < h:
			var center = Vector2(x, y)
			var cross_size = 5.0
			draw_line(center - Vector2(cross_size, 0), center + Vector2(cross_size, 0), crosshair_color, 1.2)
			draw_line(center - Vector2(0, cross_size), center + Vector2(0, cross_size), crosshair_color, 1.2)
			y += major_interval
		x += major_interval

	# 4. Elementos cartográficos técnicos (círculos de alcance y meridianos sutiles)
	var center_pt = Vector2(w * 0.5, h * 0.45)
	draw_arc(center_pt, 280.0, 0, TAU, 48, Color(0.28, 0.40, 0.55, 0.08), 1.5, true)
	draw_arc(center_pt, 460.0, 0, TAU, 64, Color(0.28, 0.40, 0.55, 0.06), 1.5, true)

	# 5. Dibujar nodos ambientales y conexiones activas si está habilitado
	if show_ambient_nodes:
		# Conexiones entre nodos cercanos
		for a in range(ambient_nodes.size()):
			for b in range(a + 1, ambient_nodes.size()):
				var na = ambient_nodes[a]
				var nb = ambient_nodes[b]
				var d = na.pos.distance_to(nb.pos)
				if d < 380.0:
					var line_alpha = (1.0 - (d / 380.0)) * 0.22
					draw_dashed_line(na.pos, nb.pos, Color(1, 1, 1, line_alpha), 2.0, 8.0)

		# Tropas ambientales en marcha
		for tr in ambient_troops:
			var t_pos = tr.from_pos.lerp(tr.to_pos, tr.progress)
			draw_circle(t_pos, 4.5, tr.color)
			draw_circle(t_pos, 7.0, Color(tr.color, 0.30))

		# Nodos circulares geopolíticos
		for n in ambient_nodes:
			var pulse_scale = 1.0 + sin(n.pulse) * 0.06
			var r = n.radius * pulse_scale
			# Halo exterior
			draw_circle(n.pos, r * 1.5, Color(n.color, 0.12))
			# Sombra 2.5D
			draw_circle(n.pos + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
			# Círculo principal
			draw_circle(n.pos, r, n.color)
			# Borde blanco fino
			draw_arc(n.pos, r, 0, TAU, 28, Color(1, 1, 1, 0.55), 2.0, true)
			# Anillo interno
			draw_arc(n.pos, r * 0.65, 0, TAU, 20, Color(1, 1, 1, 0.25), 1.2, true)
