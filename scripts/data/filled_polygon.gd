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

## Una o varias piezas listas para dibujar (vacío si el polígono es degenerado)
static func build(poly: PackedVector2Array) -> Array[FilledPolygon]:
	var out: Array[FilledPolygon] = []
	if poly.size() < 3:
		return out
	var idx := Geometry2D.triangulate_polygon(poly)
	if not idx.is_empty():
		out.append(FilledPolygon.new(poly, idx))
		return out
	# Autointersecciones o vértices duplicados: Clipper los resuelve al desplazar el contorno
	for piece in Geometry2D.offset_polygon(poly, CLEAN_OFFSET):
		idx = Geometry2D.triangulate_polygon(piece)
		if not idx.is_empty():
			out.append(FilledPolygon.new(piece, idx))
	return out

static func build_all(polys: Array) -> Array[FilledPolygon]:
	var out: Array[FilledPolygon] = []
	for poly in polys:
		out.append_array(build(poly))
	return out

func draw(canvas: CanvasItem, color: Color) -> void:
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(), indices, points, PackedColorArray([color]))
