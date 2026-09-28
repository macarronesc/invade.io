extends RefCounted
class_name GeoDatabase

## GeoDatabase: costas, fronteras y ciudades reales (Natural Earth, dominio público).
## Los datos se generan con tools/build_geo_data.py y se cargan una única vez bajo demanda.
## Todas las coordenadas se guardan como Vector2(longitud, latitud) en grados.

const DATA_PATH = "res://assets/data/geo.json"

static var _land: Array[PackedVector2Array] = []
static var _land_bounds: Array[Rect2] = []
static var _borders: Array[PackedVector2Array] = []
static var _border_bounds: Array[Rect2] = []
static var _cities: Dictionary = {}
static var _cities_by_pop: Array[Dictionary] = []
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var res = load(DATA_PATH)
	var data: Dictionary = res.data if res is JSON else {}
	for flat in data.get("land", []):
		var poly := _to_points(flat)
		_land.append(poly)
		_land_bounds.append(bounds_of(poly))
	for flat in data.get("borders", []):
		var line := _to_points(flat)
		_borders.append(line)
		_border_bounds.append(bounds_of(line))
	for row in data.get("cities", []):
		var city := {
			"key": row[0], "name_es": row[1], "name_en": row[2],
			"lonlat": Vector2(row[3], row[4]), "population": int(row[5])
		}
		_cities[city["key"]] = city
		_cities_by_pop.append(city)

static func _to_points(flat: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(flat.size() / 2)
	for i in pts.size():
		pts[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
	return pts

## Rectángulo que envuelve los puntos
static func bounds_of(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r

static func has_city(key: String) -> bool:
	_ensure_loaded()
	return _cities.has(key)

## {key, name_es, name_en, lonlat, population} o un diccionario vacío si no existe
static func get_city(key: String) -> Dictionary:
	_ensure_loaded()
	return _cities.get(key, {})

## Ciudades ordenadas de mayor a menor población
static func get_cities() -> Array[Dictionary]:
	_ensure_loaded()
	return _cities_by_pop

static func get_land() -> Array[PackedVector2Array]:
	_ensure_loaded()
	return _land

static func get_land_bounds() -> Array[Rect2]:
	_ensure_loaded()
	return _land_bounds

static func get_borders() -> Array[PackedVector2Array]:
	_ensure_loaded()
	return _borders

static func get_border_bounds() -> Array[Rect2]:
	_ensure_loaded()
	return _border_bounds
