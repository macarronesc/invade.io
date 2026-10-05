extends Node2D
class_name TerritoryMap2D

## TerritoryMap2D: Sistema de partición territorial Voronoi y mapa político de estados (Estética State.io)
## Divide el área de juego en polígonos territoriales de influencia por cada base,
## dibuja fronteras nítidas y realiza transiciones suaves de color al ser conquistadas las bases.
## Con geografía (costas y fronteras reales de LevelGenerator) cada territorio se recorta a tierra
## firme y el mar queda sin dueño; sin ella, las celdas cubren todo el rectángulo del mapa.

class TerritoryCell extends RefCounted:
	var base_node: BaseNode = null
	var capital_pos: Vector2 = Vector2.ZERO
	## Celda Voronoi convexa completa (lógica de juego y búsqueda por punto)
	var polygon: PackedVector2Array = PackedVector2Array()
	## Partes visibles: la celda recortada a tierra firme (o la celda entera sin geografía)
	var pieces: Array[PackedVector2Array] = []
	## Las mismas partes trianguladas una vez para rellenarlas sin coste en cada redibujado
	var fills: Array[FilledPolygon] = []

	# Colores para interpolación suave
	var current_color: Color = Color.WHITE
	var target_color: Color = Color.WHITE
	var start_color: Color = Color.WHITE

	# Transición y feedback de conquista
	var transition_progress: float = 1.0 # 0.0 (inicio) a 1.0 (finalizado)
	var flash_intensity: float = 0.0

@export var map_bounds: Rect2 = Rect2(0, 0, 1080, 1920)
@export var territory_alpha: float = 0.30
@export var neutral_alpha: float = 0.14
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.40)
@export var border_width: float = 3.5
@export var transition_duration: float = 0.65
@export var land_color: Color = Color(0.19, 0.22, 0.26)
@export var coast_color: Color = Color(0.45, 0.62, 0.75, 0.35)
@export var country_border_color: Color = Color(1.0, 1.0, 1.0, 0.10)

var cells: Array[TerritoryCell] = []
## Radio del islote que se dibuja bajo una capital sin tierra propia (en radios de la base)
const ISLET_RADIUS_FACTOR := 1.9
var land: Array[PackedVector2Array] = []
var country_borders: Array[PackedVector2Array] = []
var _land_bounds: Array[Rect2] = []
var _land_fills: Array[FilledPolygon] = []

func _ready() -> void:
	EventBus.base_captured.connect(func(base, _prev, new_faction): on_base_conquered(base, new_faction))
	queue_redraw()

## `geo` = {"land": [polígonos], "borders": [polilíneas]} en coordenadas del mapa (opcional)
func generate_map(bases: Array, bounds: Rect2 = Rect2(), geo: Dictionary = {}) -> void:
	if bounds.size.x > 0 and bounds.size.y > 0:
		map_bounds = bounds
	land.assign(geo.get("land", []))
	country_borders.assign(geo.get("borders", []))
	_land_bounds.clear()
	for poly in land:
		_land_bounds.append(GeoDatabase.bounds_of(poly))
	_land_fills = FilledPolygon.build_all(land)

	cells.clear()
	var valid_bases: Array[BaseNode] = []
	for b in bases:
		if is_instance_valid(b):
			valid_bases.append(b)

	# Generación de teselado Voronoi acotado mediante recorte de semiplanos convexos
	for i in range(valid_bases.size()):
		var base_i = valid_bases[i]
		var pos_i = base_i.global_position

		# Iniciar con el polígono rectangular delimitador del mapa
		var current_poly = _get_initial_bounding_polygon(map_bounds)

		for j in range(valid_bases.size()):
			if i == j:
				continue
			var base_j = valid_bases[j]
			var pos_j = base_j.global_position

			if pos_i.distance_squared_to(pos_j) < 0.01:
				continue

			# La mediatriz equidistante entre base_i y base_j
			var midpoint = (pos_i + pos_j) * 0.5
			var normal = (pos_j - pos_i).normalized()

			# Recortar polígono con el semiplano donde (X - midpoint) . normal <= 0
			current_poly = clip_polygon_halfplane(current_poly, midpoint, normal)
			if current_poly.size() < 3:
				break

		var cell = TerritoryCell.new()
		cell.base_node = base_i
		cell.capital_pos = pos_i
		cell.polygon = current_poly
		var init_col = get_faction_territory_color(base_i.faction)
		cell.current_color = init_col
		cell.target_color = init_col
		cell.start_color = init_col
		cells.append(cell)

	_build_pieces()
	queue_redraw()

## Recorta cada celda a la tierra firme (o la deja entera si el nivel no tiene geografía)
func _build_pieces() -> void:
	for cell in cells:
		cell.pieces.clear()
		if cell.polygon.size() < 3:
			continue
		if land.is_empty():
			cell.pieces.append(cell.polygon)
			continue
		var cell_bounds := GeoDatabase.bounds_of(cell.polygon)
		for i in land.size():
			if not cell_bounds.intersects(_land_bounds[i]):
				continue
			for piece in Geometry2D.intersect_polygons(cell.polygon, land[i]):
				if piece.size() >= 3:
					cell.pieces.append(piece)
		# Capital en una isla diminuta o en el mar: un islote alrededor mantiene visible su dueño
		if not cell.pieces.any(func(p): return Geometry2D.is_point_in_polygon(cell.capital_pos, p)):
			var r = cell.base_node.radius * ISLET_RADIUS_FACTOR
			for piece in Geometry2D.intersect_polygons(_circle(cell.capital_pos, r), cell.polygon):
				cell.pieces.append(piece)
		cell.fills = FilledPolygon.build_all(cell.pieces)

static func _circle(center: Vector2, r: float, segments: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(center + Vector2.from_angle(TAU * i / segments) * r)
	return pts

func _process(delta: float) -> void:
	var has_active_animation = false

	for cell in cells:
		if cell.transition_progress < 1.0:
			cell.transition_progress = minf(1.0, cell.transition_progress + (delta / transition_duration))
			var t = smoothstep(0.0, 1.0, cell.transition_progress)
			cell.current_color = cell.start_color.lerp(cell.target_color, t)
			has_active_animation = true

		if cell.flash_intensity > 0.0:
			cell.flash_intensity = maxf(0.0, cell.flash_intensity - delta * 2.2)
			has_active_animation = true

	if has_active_animation:
		queue_redraw()

func on_base_conquered(base: BaseNode, new_faction: int) -> void:
	var cell = get_cell_for_base(base)
	if cell:
		cell.start_color = cell.current_color
		cell.target_color = get_faction_territory_color(new_faction)
		cell.transition_progress = 1.0 if GameManager.settings["reduced_motion"] else 0.0
		cell.flash_intensity = 0.0 if GameManager.settings["reduced_motion"] else 0.45
		if GameManager.settings["reduced_motion"]:
			cell.current_color = cell.target_color
		queue_redraw()

func get_cell_for_base(base: BaseNode) -> TerritoryCell:
	for cell in cells:
		if cell.base_node == base:
			return cell
	return null

func get_faction_territory_color(faction: int) -> Color:
	var base_col = GameManager.faction_color(faction)
	var alpha = neutral_alpha if faction == GameManager.Faction.NEUTRAL else territory_alpha
	return Color(base_col, alpha)

func _draw() -> void:
	if cells.is_empty() and land.is_empty():
		return

	# 1. Tierra firme sin dueño (también fuera del mapa, para pantallas más altas o anchas)
	for fill in _land_fills:
		fill.draw(self, land_color)

	# 2. Relleno territorial con destello de conquista
	for cell in cells:
		var fill_col = cell.current_color
		if cell.flash_intensity > 0.0:
			fill_col = fill_col.lerp(Color.WHITE, cell.flash_intensity * 0.65)
			fill_col.a = clampf(fill_col.a + cell.flash_intensity * 0.25, 0.05, 0.6)
		for fill in cell.fills:
			fill.draw(self, fill_col)

	# 3. Fronteras reales entre países y línea de costa (referencia cartográfica sutil)
	for line in country_borders:
		draw_polyline(line, country_border_color, 1.5, true)
	for poly in land:
		draw_polyline(_closed(poly), coast_color, 2.0, true)

	# 4. Fronteras territoriales por pasadas (sombra, trazo nítido y acento de facción) para que
	#    la sombra de una celda no tape el borde de su vecina
	for cell in cells:
		for piece in cell.pieces:
			draw_polyline(_closed(piece), Color(0.04, 0.06, 0.08, 0.40), border_width + 1.8, true)
	for cell in cells:
		for piece in cell.pieces:
			draw_polyline(_closed(piece), border_color, border_width, true)
	for cell in cells:
		var accent_col = Color(cell.current_color, 0.55)
		for piece in cell.pieces:
			draw_polyline(_closed(piece), accent_col, 1.4, true)

	# 5. Marco perimetral (sólo en el mapa abstracto sin geografía)
	if land.is_empty():
		draw_rect(map_bounds, Color(1.0, 1.0, 1.0, 0.15), false, 2.5)

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := pts.duplicate()
	closed.append(pts[0])
	return closed

# =========================================================================
# Utilidades Geométricas (Voronoi & Polygons)
# =========================================================================

static func _get_initial_bounding_polygon(bounds: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(bounds.position.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.position.y),
		Vector2(bounds.end.x, bounds.end.y),
		Vector2(bounds.position.x, bounds.end.y)
	])

## Recorte de polígono convexo contra semiplano (Sutherland-Hodgman)
## Conserva los puntos X tales que (X - plane_point) . plane_normal <= 0
static func clip_polygon_halfplane(polygon: PackedVector2Array, plane_point: Vector2, plane_normal: Vector2) -> PackedVector2Array:
	var n = polygon.size()
	if n < 3:
		return PackedVector2Array()

	var clipped = PackedVector2Array()
	for i in range(n):
		var a = polygon[i]
		var b = polygon[(i + 1) % n]

		var dist_a = (a - plane_point).dot(plane_normal)
		var dist_b = (b - plane_point).dot(plane_normal)

		var in_a = dist_a <= 0.0001
		var in_b = dist_b <= 0.0001

		# Arista que cruza el plano: añadir el punto de corte
		if in_a != in_b and absf(dist_a - dist_b) > 0.00001:
			clipped.append(a + (b - a) * clampf(dist_a / (dist_a - dist_b), 0.0, 1.0))
		if in_b:
			clipped.append(b)

	return _clean_polygon(clipped)

static func _clean_polygon(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var res = PackedVector2Array()
	var count = poly.size()
	for i in range(count):
		var pt = poly[i]
		if res.is_empty():
			res.append(pt)
		elif res[res.size() - 1].distance_squared_to(pt) > 0.04:
			res.append(pt)
	if res.size() > 1 and res[0].distance_squared_to(res[res.size() - 1]) <= 0.04:
		res.remove_at(res.size() - 1)
	if res.size() < 3:
		return PackedVector2Array()
	return res
