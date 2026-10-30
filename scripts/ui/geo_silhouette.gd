extends Control
class_name GeoSilhouette

## GeoSilhouette: dibuja una región real (costas y fronteras) como fondo decorativo.
## Sólo se redibuja al cambiar la geografía, así que no cuesta nada en reposo.

var _outlines: Array[PackedVector2Array] = []
var _fills: Array[FilledPolygon] = []
var _borders: Array[PackedVector2Array] = []
var _color: Color = Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## `geo` = {"land": [polígonos], "borders": [polilíneas]} en coordenadas locales del control.
## La triangulación se guarda en el propio diccionario para reutilizarla si se vuelve a mostrar.
func set_geography(geo: Dictionary, color: Color) -> void:
	if not geo.has("fills"):
		geo["fills"] = FilledPolygon.build_all(geo.get("land", []))
	_fills = geo["fills"]
	_outlines.clear()
	for poly in geo.get("land", []):
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		_outlines.append(closed)
	_borders.assign(geo.get("borders", []))
	_color = color
	queue_redraw()

func _draw() -> void:
	var fill := Color(_color, 0.10)
	var coast := Color(_color.lightened(0.2), 0.35)
	for f in _fills:
		f.draw(self, fill)
	for line in _borders:
		draw_polyline(line, Color(1, 1, 1, 0.05), 1.2, true)
	for outline in _outlines:
		draw_polyline(outline, coast, 2.0, true)
