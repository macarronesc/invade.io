extends RefCounted
class_name MapProjection

## MapProjection: Mercator ajustada a un rectángulo de pantalla.
## Las longitudes se miden respecto a `ref_lon`, así que una región que cruza el antimeridiano
## (Fiyi, Samoa, Chukotka) se proyecta de forma continua.

const MAX_LAT := 82.0

var ref_lon: float = 0.0
var scale: float = 1.0
var _merc_center: Vector2 = Vector2.ZERO
var _screen_center: Vector2 = Vector2.ZERO

func _init(p_ref_lon: float = 0.0) -> void:
	ref_lon = p_ref_lon

static func mercator_y(lat: float) -> float:
	var phi := deg_to_rad(clampf(lat, -MAX_LAT, MAX_LAT))
	# Negativo: en pantalla el norte queda arriba (Y crece hacia abajo)
	return -rad_to_deg(log(tan(PI * 0.25 + phi * 0.5)))

## Coordenadas Mercator en grados, con la longitud relativa a ref_lon en [-180, 180)
func to_mercator(lonlat: Vector2) -> Vector2:
	return Vector2(wrapf(lonlat.x - ref_lon, -180.0, 180.0), mercator_y(lonlat.y))

## Encaja `merc_rect` centrado dentro de `screen_rect` con escala uniforme
func fit(merc_rect: Rect2, screen_rect: Rect2) -> void:
	scale = minf(screen_rect.size.x / merc_rect.size.x, screen_rect.size.y / merc_rect.size.y)
	_merc_center = merc_rect.get_center()
	_screen_center = screen_rect.get_center()

func mercator_to_screen(m: Vector2) -> Vector2:
	return _screen_center + (m - _merc_center) * scale

func screen_to_mercator(s: Vector2) -> Vector2:
	return _merc_center + (s - _screen_center) / scale

func project(lonlat: Vector2) -> Vector2:
	return mercator_to_screen(to_mercator(lonlat))

## Proyecta un polígono o polilínea desenrollando la longitud vértice a vértice
func project_points(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	var prev_x := 0.0
	for i in pts.size():
		var x := wrapf(pts[i].x - ref_lon, -180.0, 180.0)
		if i > 0:
			x = prev_x + wrapf(x - prev_x, -180.0, 180.0)
		prev_x = x
		out[i] = mercator_to_screen(Vector2(x, mercator_y(pts[i].y)))
	return out

## ¿Puede un rectángulo lon/lat verse dentro del rectángulo Mercator `view`? (descarte rápido)
func may_overlap(lonlat_bounds: Rect2, view: Rect2) -> bool:
	var lat_top := mercator_y(lonlat_bounds.end.y)
	var lat_bottom := mercator_y(lonlat_bounds.position.y)
	if lat_bottom < view.position.y or lat_top > view.end.y:
		return false
	if lonlat_bounds.size.x >= 180.0:
		return true
	var x0 := wrapf(lonlat_bounds.position.x - ref_lon, -180.0, 180.0)
	for shift in [-360.0, 0.0, 360.0]:
		var a: float = x0 + shift
		if a <= view.end.x and a + lonlat_bounds.size.x >= view.position.x:
			return true
	return false
