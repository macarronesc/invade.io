extends RefCounted
class_name FilledPolygon

## FilledPolygon: polígono triangulado una sola vez para dibujarlo en cada redibujado sin coste.
## draw_colored_polygon triangula en cada llamada y falla con costas complejas o con vértices
## que se tocan; aquí se triangula al cargar y, si falla, se limpia el polígono antes.

const CLEAN_OFFSET := 0.5

var points: PackedVector2Array
var indices: PackedInt32Array

func _init(p_points: PackedVector2Array, p_indices: PackedInt32Array) -> void:
	points = p_points
	indices = p_indices

## Godot triangula mejor cerca del origen. A escala de mapa, trasladar evita que
## un borde casi colineal se considere degenerado por precisión de coma flotante.
static func _localized(poly: PackedVector2Array) -> PackedVector2Array:
	var origin := poly[0]
	var local := PackedVector2Array()
	local.resize(poly.size())
	for i in poly.size():
		local[i] = poly[i] - origin
	return local

## Una o varias piezas listas para dibujar (vacío si el polígono es degenerado)
static func build(poly: PackedVector2Array) -> Array[FilledPolygon]:
	var out: Array[FilledPolygon] = []
	if poly.size() < 3:
		return out
	# Los triángulos de borde pierden precisión con coordenadas de mapa. Los
	# polígonos mayores conservan el camino original para no cambiar su topología.
	var idx := Geometry2D.triangulate_polygon(_localized(poly) if poly.size() == 3 else poly)
	if not idx.is_empty():
		out.append(FilledPolygon.new(poly, idx))
		return out
	# Autointersecciones o vértices duplicados: Clipper los resuelve al desplazar el contorno
	for piece in Geometry2D.offset_polygon(poly, CLEAN_OFFSET):
		if piece.size() < 3:
			continue
		idx = Geometry2D.triangulate_polygon(_localized(piece))
		if not idx.is_empty():
			out.append(FilledPolygon.new(piece, idx))
	return out

static func build_all(polys: Array) -> Array[FilledPolygon]:
	var out: Array[FilledPolygon] = []
	for poly in polys:
		out.append_array(build(poly))
	if out.size() > 1:
		var points := PackedVector2Array()
		var indices := PackedInt32Array()
		for fill in out:
			var offset := points.size()
			points.append_array(fill.points)
			for index in fill.indices:
				indices.append(index + offset)
		out.assign([FilledPolygon.new(points, indices)])
	return out

func draw(canvas: CanvasItem, color: Color) -> void:
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, PackedColorArray([color]))
