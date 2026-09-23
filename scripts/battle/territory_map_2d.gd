extends Node2D
class_name TerritoryMap2D

## TerritoryMap2D: Sistema de partición territorial Voronoi y mapa político de estados (Estética State.io)
## Divide el área de juego 1080x1920 en polígonos territoriales de influencia por cada base,
## dibuja fronteras nítidas y realiza transiciones suaves de color al ser conquistadas las bases.

class TerritoryCell extends RefCounted:
	var base_node: BaseNode = null
	var base_id: String = ""
	var base_name: String = ""
	var capital_pos: Vector2 = Vector2.ZERO
	var polygon: PackedVector2Array = PackedVector2Array()
	var faction: int = GameManager.Faction.NEUTRAL
	
	# Colores para interpolación suave
	var current_color: Color = Color.WHITE
	var target_color: Color = Color.WHITE
	var start_color: Color = Color.WHITE
	
	# Transición y feedback de conquista
	var transition_progress: float = 1.0 # 0.0 (inicio) a 1.0 (finalizado)
	var transition_duration: float = 0.65
	var flash_intensity: float = 0.0

@export var map_bounds: Rect2 = Rect2(0, 0, 1080, 1920)
@export var territory_alpha: float = 0.22
@export var neutral_alpha: float = 0.14
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.40)
@export var border_width: float = 3.5
@export var transition_duration: float = 0.65

var cells: Array[TerritoryCell] = []
var _is_transitioning: bool = false

func _ready() -> void:
	EventBus.base_captured.connect(_on_base_captured)
	queue_redraw()

func setup(bases: Array, bounds: Rect2 = Rect2()) -> void:
	generate_map(bases, bounds)

func generate_map(bases: Array, bounds: Rect2 = Rect2()) -> void:
	if bounds.size.x > 0 and bounds.size.y > 0:
		map_bounds = bounds
		
	cells.clear()
	
	var valid_bases: Array[BaseNode] = []
	for b in bases:
		if is_instance_valid(b):
			valid_bases.append(b)
			
	if valid_bases.is_empty():
		queue_redraw()
		return
		
	# Caso base: 1 sola base ocupa todo el territorio acotado
	if valid_bases.size() == 1:
		var single_base = valid_bases[0]
		var cell = TerritoryCell.new()
		cell.base_node = single_base
		cell.base_id = single_base.base_id
		cell.base_name = single_base.base_name
		cell.capital_pos = single_base.global_position
		cell.polygon = _get_initial_bounding_polygon(map_bounds)
		cell.faction = single_base.faction
		cell.transition_duration = transition_duration
		
		var init_col = get_faction_territory_color(cell.faction)
		cell.current_color = init_col
		cell.target_color = init_col
		cell.start_color = init_col
		cell.transition_progress = 1.0
		cells.append(cell)
		queue_redraw()
		return

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
		cell.base_id = base_i.base_id
		cell.base_name = base_i.base_name
		cell.capital_pos = pos_i
		cell.polygon = current_poly
		cell.faction = base_i.faction
		cell.transition_duration = transition_duration
		
		var init_col = get_faction_territory_color(cell.faction)
		cell.current_color = init_col
		cell.target_color = init_col
		cell.start_color = init_col
		cell.transition_progress = 1.0
		cell.flash_intensity = 0.0
		cells.append(cell)
		
	queue_redraw()

func _process(delta: float) -> void:
	var has_active_animation = false
	
	for cell in cells:
		if cell.transition_progress < 1.0:
			cell.transition_progress = minf(1.0, cell.transition_progress + (delta / cell.transition_duration))
			var t = smoothstep(0.0, 1.0, cell.transition_progress)
			cell.current_color = cell.start_color.lerp(cell.target_color, t)
			has_active_animation = true
			
		if cell.flash_intensity > 0.0:
			cell.flash_intensity = maxf(0.0, cell.flash_intensity - delta * 2.2)
			has_active_animation = true
			
	if has_active_animation or _is_transitioning:
		_is_transitioning = has_active_animation
		queue_redraw()

func _on_base_captured(base: BaseNode, _prev_faction: int, new_faction: int) -> void:
	on_base_conquered(base, new_faction)

func on_base_conquered(base: BaseNode, new_faction: int) -> void:
	var cell = get_cell_for_base(base)
	if cell:
		cell.faction = new_faction
		cell.start_color = cell.current_color
		cell.target_color = get_faction_territory_color(new_faction)
		cell.transition_progress = 0.0
		cell.flash_intensity = 0.45
		_is_transitioning = true
		queue_redraw()

func get_cell_for_base(base: BaseNode) -> TerritoryCell:
	if not is_instance_valid(base):
		return null
	for cell in cells:
		if (is_instance_valid(cell.base_node) and cell.base_node == base) or (cell.base_id != "" and cell.base_id == base.base_id):
			return cell
		if cell.capital_pos.distance_squared_to(base.global_position) < 4.0:
			return cell
	return null

func get_cell_at_point(point: Vector2) -> TerritoryCell:
	for cell in cells:
		if cell.polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, cell.polygon):
			return cell
	return null

func get_cells() -> Array[TerritoryCell]:
	return cells

func get_faction_territory_color(faction: int) -> Color:
	var base_col = GameManager.FACTION_COLORS.get(faction, Color(0.47, 0.56, 0.61))
	var alpha = neutral_alpha if faction == GameManager.Faction.NEUTRAL else territory_alpha
	return Color(base_col.r, base_col.g, base_col.b, alpha)

func _draw() -> void:
	if cells.is_empty():
		return
		
	# 1. Pase de Relleno: Polígonos territoriales con efecto destello (flash) de conquista
	for cell in cells:
		if cell.polygon.size() < 3:
			continue
			
		var fill_col = cell.current_color
		if cell.flash_intensity > 0.0:
			fill_col = fill_col.lerp(Color.WHITE, cell.flash_intensity * 0.65)
			fill_col.a = clampf(fill_col.a + cell.flash_intensity * 0.25, 0.05, 0.6)
			
		draw_colored_polygon(cell.polygon, fill_col)
		
	# 2. Pase de Auras: Áreas de influencia de las capitales territoriales
	for cell in cells:
		if cell.polygon.size() < 3:
			continue
		var fill_col = cell.current_color
		var r = 50.0
		if is_instance_valid(cell.base_node):
			r = cell.base_node.radius
		draw_circle(cell.capital_pos, r * 2.1, Color(fill_col.r, fill_col.g, fill_col.b, 0.08))
		draw_arc(cell.capital_pos, r * 1.6, 0, TAU, 32, Color(1, 1, 1, 0.10), 1.5, true)
		
	# 3. Pase de Sombras: Relieve cartográfico debajo de las fronteras (dibujado antes para no tapar bordes)
	for cell in cells:
		var pts = cell.polygon
		if pts.size() < 3:
			continue
		var closed_pts = pts.duplicate()
		closed_pts.append(pts[0])
		draw_polyline(closed_pts, Color(0.04, 0.06, 0.08, 0.40), border_width + 1.8, true)
		
	# 4. Pase de Fronteras Nítidas: Líneas principales divisorias entre estados
	for cell in cells:
		var pts = cell.polygon
		if pts.size() < 3:
			continue
		var closed_pts = pts.duplicate()
		closed_pts.append(pts[0])
		draw_polyline(closed_pts, border_color, border_width, true)
		
	# 5. Pase de Acentos: Trazo sutil con el color de la facción sobre el perímetro del estado
	for cell in cells:
		var pts = cell.polygon
		if pts.size() < 3:
			continue
		var closed_pts = pts.duplicate()
		closed_pts.append(pts[0])
		var accent_col = Color(cell.current_color.r, cell.current_color.g, cell.current_color.b, 0.55)
		draw_polyline(closed_pts, accent_col, 1.4, true)
		
	# 6. Pase de Perímetro: Marco perimetral del mapa geopolítico
	draw_rect(map_bounds, Color(1.0, 1.0, 1.0, 0.15), false, 2.5)

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
		
		if in_a and in_b:
			clipped.append(b)
		elif in_a and not in_b:
			var diff = dist_a - dist_b
			if absf(diff) > 0.00001:
				var t = clampf(dist_a / diff, 0.0, 1.0)
				clipped.append(a + (b - a) * t)
		elif not in_a and in_b:
			var diff = dist_a - dist_b
			if absf(diff) > 0.00001:
				var t = clampf(dist_a / diff, 0.0, 1.0)
				clipped.append(a + (b - a) * t)
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
		else:
			if res[res.size() - 1].distance_squared_to(pt) > 0.04:
				res.append(pt)
	if res.size() > 1 and res[0].distance_squared_to(res[res.size() - 1]) <= 0.04:
		res.remove_at(res.size() - 1)
	if res.size() < 3:
		return PackedVector2Array()
	return res

static func calculate_polygon_area(poly: PackedVector2Array) -> float:
	var n = poly.size()
	if n < 3:
		return 0.0
	var area: float = 0.0
	for i in range(n):
		var j = (i + 1) % n
		area += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return absf(area) * 0.5
