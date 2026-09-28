extends RefCounted
class_name LevelGenerator

## LevelGenerator: convierte una definición de nivel (ciudades reales + facciones) en un nivel
## jugable sobre la geografía real:
##   1. Proyecta las ciudades con Mercator y encaja la región en la zona de juego vertical.
##   2. Separa las bases que quedarían demasiado juntas para poder tocarlas y leerlas.
##   3. Añade ciudades neutrales reales de la región según la dificultad (niveles más grandes).
##   4. Recorta costas y fronteras a la vista para dibujar el mapa político.
## Es determinista: el mismo nivel produce siempre el mismo mapa.

## Área de juego completa (coordenadas de mundo de la batalla)
const MAP_RECT := Rect2(0, 0, 1080, 1920)
## Zona donde pueden quedar los centros de las bases (deja sitio al HUD y a las etiquetas)
const PLAY_RECT := Rect2(100, 330, 880, 1400)
## Zona con geografía dibujada: más allá del mapa para pantallas más altas o anchas
const GEO_CLIP_RECT := Rect2(-400, -500, 1880, 2920)
## Separación mínima entre los bordes de dos bases
const BASE_GAP := 90.0
const MAX_EXTRA_NEUTRALS := 7
## Segundos extra de objetivo para 3 estrellas por cada neutral añadida
const EXTRA_TARGET_TIME := 4
## Margen alrededor de las ciudades del nivel y tamaño mínimo de la región (grados Mercator)
const VIEW_PADDING := 0.12
const MIN_VIEW_SPAN := 8.0
const RELAX_ITERATIONS := 80

## Desafío diario: centro entre las ciudades más pobladas y vecinas a una distancia jugable
const DAILY_CENTER_POOL := 150
const DAILY_NEIGHBOR_POOL := 600
const DAILY_MIN_DEGREES := 3.0
const DAILY_MAX_DEGREES := 16.0
const DAILY_ANCHORS := 5
const DAILY_ATTEMPTS := 40
const DAILY_TARGET_TIME := 60

static func build(def: Dictionary, difficulty: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.get("id", ""))

	var bases: Array[Dictionary] = []
	for b_def in def.get("bases", []):
		var city := GeoDatabase.get_city(b_def.get("city", ""))
		if city.is_empty():
			push_error("LevelGenerator: ciudad desconocida '%s' en %s" % [b_def.get("city", ""), def.get("id", "")])
			continue
		var base: Dictionary = b_def.duplicate()
		base["name"] = city["name_es"]
		base["lonlat"] = city["lonlat"]
		bases.append(base)
	if bases.is_empty():
		return def.duplicate()

	var anchors: Array[Vector2] = []
	for base in bases:
		anchors.append(base["lonlat"])
	var proj := fit_projection(anchors, PLAY_RECT)
	for base in bases:
		base["pos"] = proj.project(base["lonlat"])
	relax_positions(bases)

	var extra_count: int = def.get("extra_neutrals", roundi(difficulty * MAX_EXTRA_NEUTRALS))
	var extras := _pick_extra_neutrals(proj, bases, extra_count, difficulty, rng)
	bases.append_array(extras)

	var level: Dictionary = def.duplicate()
	level["bases"] = bases
	level["target_time"] = def.get("target_time", 45) + extras.size() * EXTRA_TARGET_TIME
	level["geo"] = project_geography(proj, GEO_CLIP_RECT)
	return level

## Definición del desafío de un día: la misma para todos los jugadores ese día.
## El jugador parte de una gran ciudad; el rival más lejano es la IA y el resto, neutrales.
static func daily_challenge_definition(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(DailyRewards.challenge_id(day))
	var cities := GeoDatabase.get_cities()
	var center: Dictionary = {}
	var near: Array[Dictionary] = []
	for attempt in DAILY_ATTEMPTS:
		center = cities[rng.randi() % mini(DAILY_CENTER_POOL, cities.size())]
		# Tras muchos intentos (regiones aisladas) se admiten vecinas más lejanas
		var max_deg := DAILY_MAX_DEGREES * (1.0 if attempt < DAILY_ATTEMPTS - 5 else 3.0)
		near = _spread_neighbors(center, cities, max_deg)
		if near.size() >= DAILY_ANCHORS - 1:
			break

	# Rival principal: la vecina más lejana. A veces, un segundo rival lejos de ambos.
	near.sort_custom(func(a, b): return _geo_distance(center, a) > _geo_distance(center, b))
	var bases: Array[Dictionary] = [
		{"id": "b1", "city": center["key"], "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
		{"id": "b2", "city": near[0]["key"], "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
	]
	var second_enemy := rng.randf() < 0.5
	for i in range(1, near.size()):
		var neutral := {"id": "b%d" % (i + 2), "city": near[i]["key"], "faction": GameManager.Faction.NEUTRAL,
			"troops": rng.randi_range(10, 18), "tier": 1}
		if second_enemy and i == 1:
			neutral.merge({"faction": GameManager.Faction.ENEMY_2, "troops": 25, "tier": 2}, true)
		bases.append(neutral)
	return {
		"id": DailyRewards.challenge_id(day),
		"name": "Desafío diario: %s" % center["name_es"],
		"continent": "daily",
		"description": "Un frente nuevo cada día. Conquista la región de %s antes de medianoche." % center["name_es"],
		"target_time": DAILY_TARGET_TIME,
		"bases": bases,
	}

## Distancia aproximada en grados (longitud corregida por la latitud y el antimeridiano)
static func _geo_distance(a: Dictionary, b: Dictionary) -> float:
	var la: Vector2 = a["lonlat"]
	var lb: Vector2 = b["lonlat"]
	var dlon := wrapf(lb.x - la.x, -180.0, 180.0) * cos(deg_to_rad((la.y + lb.y) * 0.5))
	return Vector2(dlon, lb.y - la.y).length()

## Hasta DAILY_ANCHORS - 1 vecinas a distancia jugable y no amontonadas entre sí
static func _spread_neighbors(center: Dictionary, cities: Array[Dictionary], max_deg: float) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for i in mini(DAILY_NEIGHBOR_POOL, cities.size()):
		var d := _geo_distance(center, cities[i])
		if d >= DAILY_MIN_DEGREES and d <= max_deg:
			candidates.append(cities[i])
	candidates.sort_custom(func(a, b): return _geo_distance(center, a) < _geo_distance(center, b))
	var chosen: Array[Dictionary] = []
	for c in candidates:
		if chosen.size() >= DAILY_ANCHORS - 1:
			break
		if chosen.all(func(o): return _geo_distance(o, c) >= DAILY_MIN_DEGREES):
			chosen.append(c)
	return chosen

## Costas y fronteras visibles con esta proyección, recortadas a `clip_rect`
static func project_geography(proj: MapProjection, clip_rect: Rect2) -> Dictionary:
	return {
		"land": _clip_shapes(proj, GeoDatabase.get_land(), GeoDatabase.get_land_bounds(), true, clip_rect),
		"borders": _clip_shapes(proj, GeoDatabase.get_borders(), GeoDatabase.get_border_bounds(), false, clip_rect),
	}

## Proyección que encaja los puntos (con margen) en `screen_rect`, respetando su proporción
static func fit_projection(lonlats: Array[Vector2], screen_rect: Rect2) -> MapProjection:
	var proj := MapProjection.new(lonlats[0].x)
	var merc := Rect2(proj.to_mercator(lonlats[0]), Vector2.ZERO)
	for ll in lonlats:
		merc = merc.expand(proj.to_mercator(ll))
	merc = merc.grow_individual(merc.size.x * VIEW_PADDING, merc.size.y * VIEW_PADDING, merc.size.x * VIEW_PADDING, merc.size.y * VIEW_PADDING)

	# Ampliar el lado corto hasta la proporción del destino (y un tamaño mínimo)
	var aspect := screen_rect.size.x / screen_rect.size.y
	var size := merc.size.max(Vector2(MIN_VIEW_SPAN * aspect, MIN_VIEW_SPAN))
	if size.x / size.y > aspect:
		size.y = size.x / aspect
	else:
		size.x = size.y * aspect
	proj.fit(Rect2(merc.get_center() - size * 0.5, size), screen_rect)
	return proj

static func min_distance(tier_a: int, tier_b: int) -> float:
	return _radius(tier_a) + _radius(tier_b) + BASE_GAP

static func _radius(tier: int) -> float:
	return BaseNode.TIER_PARAMS.get(tier, BaseNode.DEFAULT_TIER_PARAMS)["radius"]

## Aparta las bases solapadas lo mínimo necesario y las mantiene dentro de PLAY_RECT
static func relax_positions(bases: Array[Dictionary]) -> void:
	var points := PackedVector2Array()
	for base in bases:
		points.append(base["pos"])
	points = separate_points(points, func(i, j): return min_distance(bases[i].get("tier", 1), bases[j].get("tier", 1)), PLAY_RECT)
	for i in bases.size():
		bases[i]["pos"] = points[i]

## Separa los puntos que estén más cerca que `min_dist.call(i, j)` moviéndolos lo mínimo posible,
## sin salir de `bounds`. Determinista: mismos puntos, mismo resultado.
static func separate_points(points: PackedVector2Array, min_dist: Callable, bounds: Rect2) -> PackedVector2Array:
	var pts := points.duplicate()
	for _iter in RELAX_ITERATIONS:
		var moved := false
		for i in pts.size():
			for j in range(i + 1, pts.size()):
				var delta := pts[j] - pts[i]
				var need: float = min_dist.call(i, j)
				var dist := delta.length()
				if dist >= need:
					continue
				var dir := delta / dist if dist > 0.01 else Vector2.RIGHT.rotated(i + j)
				var push := dir * (need - dist) * 0.5
				pts[i] -= push
				pts[j] += push
				moved = true
		for i in pts.size():
			pts[i] = pts[i].clamp(bounds.position, bounds.end)
		if not moved:
			break
	return pts

## Ciudades reales de la región, de más a menos pobladas, que caben sin solaparse
static func _pick_extra_neutrals(proj: MapProjection, bases: Array[Dictionary], count: int, difficulty: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var extras: Array[Dictionary] = []
	if count <= 0:
		return extras
	var used := {}
	for base in bases:
		used[base.get("city", "")] = true
	var placed: Array[Dictionary] = bases.duplicate()
	for city in GeoDatabase.get_cities():
		if extras.size() >= count:
			break
		if used.has(city["key"]):
			continue
		var pos := proj.project(city["lonlat"])
		if not PLAY_RECT.has_point(pos):
			continue
		var tier := 2 if city["population"] >= 5000000 else 1
		if placed.any(func(b): return b["pos"].distance_to(pos) < min_distance(tier, b.get("tier", 1))):
			continue
		var extra := {
			"id": "x%d" % (extras.size() + 1),
			"city": city["key"],
			"name": city["name_es"],
			"lonlat": city["lonlat"],
			"pos": pos,
			"faction": GameManager.Faction.NEUTRAL,
			"tier": tier,
			"troops": (rng.randi_range(8, 14) if tier == 1 else rng.randi_range(15, 22)) + roundi(difficulty * 8.0),
		}
		# Variedad táctica en la segunda mitad de la campaña
		if difficulty >= 0.3 and rng.randf() < 0.2:
			extra["type"] = "fortress" if rng.randf() < 0.5 else "factory"
		extras.append(extra)
		placed.append(extra)
		used[city["key"]] = true
	return extras

## Rectángulo Mercator que corresponde a un rectángulo de pantalla
static func _mercator_rect(proj: MapProjection, screen: Rect2) -> Rect2:
	return Rect2(proj.screen_to_mercator(screen.position), screen.size / proj.scale)

static func _rect_polygon(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

static func _screen_bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r

## Proyecta las formas que caen en `clip_rect` y recorta las que lo atraviesan
static func _clip_shapes(proj: MapProjection, shapes: Array[PackedVector2Array], bounds: Array[Rect2], closed: bool, clip_rect: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var view := _mercator_rect(proj, clip_rect)
	var clip := _rect_polygon(clip_rect)
	var min_points := 3 if closed else 2
	for i in shapes.size():
		if not proj.may_overlap(bounds[i], view):
			continue
		var pts := proj.project_points(shapes[i])
		var sb := _screen_bounds(pts)
		if not sb.intersects(clip_rect):
			continue
		if clip_rect.encloses(sb):
			out.append(pts)
			continue
		var pieces := Geometry2D.intersect_polygons(pts, clip) if closed else Geometry2D.intersect_polyline_with_polygon(pts, clip)
		for piece in pieces:
			if piece.size() >= min_points:
				out.append(piece)
	return out
