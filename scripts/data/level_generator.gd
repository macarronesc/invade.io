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
## Las mismas zonas para pantallas apaisadas (tabletas, plegables, ventanas anchas)
const LANDSCAPE_MAP_RECT := Rect2(0, 0, 1920, 1080)
const LANDSCAPE_PLAY_RECT := Rect2(150, 300, 1620, 700)
const LANDSCAPE_GEO_CLIP_RECT := Rect2(-500, -400, 2920, 1880)
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

## Zonas del tablero según la orientación: {"map", "play", "clip"}
static func layout(landscape: bool) -> Dictionary:
	if landscape:
		return {"map": LANDSCAPE_MAP_RECT, "play": LANDSCAPE_PLAY_RECT, "clip": LANDSCAPE_GEO_CLIP_RECT}
	return {"map": MAP_RECT, "play": PLAY_RECT, "clip": GEO_CLIP_RECT}

static func build(def: Dictionary, difficulty: float, landscape: bool = false) -> Dictionary:
	var zones := layout(landscape)
	var play_rect: Rect2 = zones["play"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.get("id", ""))

	var bases: Array[Dictionary] = []
	for b_def in def.get("bases", []):
		var city := GeoDatabase.get_city(b_def.get("city", ""))
		if city.is_empty():
			push_error("LevelGenerator: ciudad desconocida '%s' en %s" % [b_def.get("city", ""), def.get("id", "")])
			continue
		var base: Dictionary = b_def.duplicate()
		base["name"] = GeoDatabase.city_name(city)
		base["lonlat"] = city["lonlat"]
		bases.append(base)
	if bases.is_empty():
		return def.duplicate()

	var anchors: Array[Vector2] = []
	for base in bases:
		anchors.append(base["lonlat"])
	var proj := fit_projection(anchors, play_rect)
	for base in bases:
		base["pos"] = proj.project(base["lonlat"])
	if not landscape:
		relax_positions(bases)

	var extra_count := int(def.get("extra_neutrals", roundi(difficulty * MAX_EXTRA_NEUTRALS)))
	# Pick bonus cities using the portrait projection in both modes, so rotating changes layout, not
	# the level's cast, difficulty, or rewards.
	var selection_proj := proj
	var selection_bases := bases
	if landscape:
		selection_proj = fit_projection(anchors, PLAY_RECT)
		selection_bases = bases.duplicate(true)
		for i in selection_bases.size():
			selection_bases[i]["pos"] = selection_proj.project(selection_bases[i]["lonlat"])
		relax_positions(selection_bases, PLAY_RECT)
	var extras := _pick_extra_neutrals(selection_proj, selection_bases, maxi(0, extra_count), difficulty, rng, PLAY_RECT)
	for extra in extras:
		extra["pos"] = proj.project(extra["lonlat"])
	bases.append_array(extras)
	if landscape:
		_arrange_landscape_bases(bases, play_rect)

	var level: Dictionary = def.duplicate()
	level["bases"] = bases
	level["target_time"] = def.get("target_time", 45) + extras.size() * EXTRA_TARGET_TIME
	level["geo"] = project_geography(proj, zones["clip"])
	level["map_rect"] = zones["map"]
	return level

## Definición del desafío de un día: la misma para todos los jugadores ese día.
## El jugador parte de una gran ciudad; el rival más lejano es la IA y el resto, neutrales.
static func daily_challenge_definition(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(DailyRewards.challenge_id(day))
	var region := _pick_region(rng, DAILY_CENTER_POOL)
	var center: Dictionary = region["center"]
	var near: Array[Dictionary] = region["neighbors"]

	# Rival principal: la vecina más lejana. A veces, un segundo rival lejos de ambos.
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
		"name": LocaleStrings.text("daily_name") % GeoDatabase.city_name(center),
		"description": LocaleStrings.text("daily_desc") % GeoDatabase.city_name(center),
		"target_time": DAILY_TARGET_TIME,
		"bases": bases,
	}

# =========================================================================
# Conquista libre (punto 3): regiones infinitas con dificultad creciente.
# Mismo generador que el desafío diario, pero con índice propio y enemigos
# y tropas que escalan con `index` (0.15 de dificultad inicial, +0.03/región).
# =========================================================================

const CONQUEST_PREFIX := "conquest_"
const CONQUEST_CENTER_POOL := 200

static func conquest_id(index: int) -> String:
	return "%s%d" % [CONQUEST_PREFIX, index]

static func is_conquest(level_id: String) -> bool:
	return level_id.begins_with(CONQUEST_PREFIX)

static func conquest_index(level_id: String) -> int:
	return maxi(0, int(level_id.substr(CONQUEST_PREFIX.length())))

static func conquest_difficulty(index: int) -> float:
	return minf(0.15 + 0.03 * index, 1.0)

## Expediciones: bloques de GameManager.EXPEDITION_SIZE regiones; la última de cada una es un jefe
static func expedition_of(index: int) -> int:
	@warning_ignore("integer_division")
	return index / GameManager.EXPEDITION_SIZE + 1

static func expedition_step(index: int) -> int:
	return index % GameManager.EXPEDITION_SIZE + 1

static func is_expedition_finale(index: int) -> bool:
	return expedition_step(index) == GameManager.EXPEDITION_SIZE

## Definición de la región `index`: determinista, igual para todos los jugadores.
static func conquest_definition(index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(conquest_id(index))
	var region := _pick_region(rng, CONQUEST_CENTER_POOL)
	var center: Dictionary = region["center"]
	var near: Array[Dictionary] = region["neighbors"]
	var enemy_troops := mini(24 + index, 55)
	var bases: Array[Dictionary] = [
		{"id": "b1", "city": center["key"], "faction": GameManager.Faction.PLAYER, "troops": 36, "tier": 2 if index < 4 else 3},
		{"id": "b2", "city": near[0]["key"], "faction": GameManager.Faction.ENEMY_1, "troops": enemy_troops, "tier": 2 if index < 5 else 3},
	]
	if is_expedition_finale(index):
		bases[1].merge({"boss": true, "type": "fortress", "tier": 3, "troops": enemy_troops + 8}, true)
	for i in range(1, near.size()):
		var neutral := {"id": "b%d" % (i + 2), "city": near[i]["key"], "faction": GameManager.Faction.NEUTRAL,
			"troops": rng.randi_range(10, 18), "tier": 1}
		# Segundo rival tras la primera expedición; tercero a partir de la cuarta.
		if i == 1 and index >= 5 and index % 2 == 0:
			neutral.merge({"faction": GameManager.Faction.ENEMY_2, "troops": enemy_troops - 5, "tier": 2}, true)
		elif i == 2 and index >= 15 and index % 3 == 0:
			neutral.merge({"faction": GameManager.Faction.ENEMY_3, "troops": enemy_troops - 5, "tier": 2}, true)
		bases.append(neutral)
	return {
		"id": conquest_id(index),
		"name": LocaleStrings.text("conquest_title") % [expedition_of(index), expedition_step(index), GameManager.EXPEDITION_SIZE, GeoDatabase.city_name(center)],
		"description": LocaleStrings.text("conquest_desc") % [GeoDatabase.city_name(center), index + 1],
		"target_time": DAILY_TARGET_TIME + (25 if is_expedition_finale(index) else 0),
		"bases": bases,
	}

## Selección geográfica común; conserva el RNG para no cambiar mapas ya publicados.
static func _pick_region(rng: RandomNumberGenerator, center_pool: int) -> Dictionary:
	var cities := GeoDatabase.get_cities()
	var center: Dictionary = {}
	var near: Array[Dictionary] = []
	for attempt in DAILY_ATTEMPTS:
		center = cities[rng.randi() % mini(center_pool, cities.size())]
		# Regiones aisladas: ampliar el radio en los últimos intentos.
		var max_deg := DAILY_MAX_DEGREES * (1.0 if attempt < DAILY_ATTEMPTS - 5 else 3.0)
		near = _spread_neighbors(center, cities, max_deg)
		if near.size() >= DAILY_ANCHORS - 1:
			break
	if near.is_empty():
		near = _spread_neighbors(center, cities, 360.0)
	near.sort_custom(func(a, b): return _geo_distance(center, a) > _geo_distance(center, b))
	return {"center": center, "neighbors": near}

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

## Landscape is much shallower than portrait. The slot matching minimizes pin movement while
## guaranteeing room for taps; the projected geography, city names and battle rules stay unchanged.
static func _arrange_landscape_bases(bases: Array[Dictionary], bounds: Rect2) -> void:
	if bases.size() < 2:
		return
	# shortcut: current content fits a max-radius grid; use tier-aware disk packing if a future level exceeds its capacity.
	var margin := 0.0
	var spacing := 0.0
	for i in bases.size():
		margin = maxf(margin, _radius(bases[i].get("tier", 1)))
		for j in range(i + 1, bases.size()):
			spacing = maxf(spacing, min_distance(bases[i].get("tier", 1), bases[j].get("tier", 1)))
	var area := bounds.grow(-margin)
	var max_cols := floori(area.size.x / spacing) + 1
	var max_rows := floori(area.size.y / spacing) + 1
	if max_cols < 1 or max_rows < 1:
		push_error("LevelGenerator: el área apaisada es demasiado pequeña para las bases")
		return
	if bases.size() > max_cols * max_rows:
		push_error("LevelGenerator: demasiadas bases para el tablero apaisado (%d)" % bases.size())
		return
	var cols := max_cols
	var rows := max_rows

	var slots: Array[Vector2] = []
	var pitch_x := area.size.x / float(cols - 1) if cols > 1 else 0.0
	for row in rows:
		var y := area.get_center().y if rows == 1 else area.position.y + float(row) * area.size.y / float(rows - 1)
		for col in cols:
			var x := area.get_center().x if cols == 1 else area.position.x + float(col) * pitch_x
			slots.append(Vector2(x, y))
	_assign_bases_to_slots(bases, slots)

## Minimum-total-distance matching keeps pins closest to their projected cities while respecting spacing.
static func _assign_bases_to_slots(bases: Array[Dictionary], slots: Array[Vector2]) -> void:
	var n := bases.size()
	var m := slots.size()
	var u := PackedFloat64Array()
	var v := PackedFloat64Array()
	var p := PackedInt32Array()
	var way := PackedInt32Array()
	u.resize(n + 1)
	v.resize(m + 1)
	p.resize(m + 1)
	way.resize(m + 1)
	for i in range(1, n + 1):
		p[0] = i
		var j0 := 0
		var minv := PackedFloat64Array()
		var used := PackedByteArray()
		minv.resize(m + 1)
		minv.fill(INF)
		used.resize(m + 1)
		while true:
			used[j0] = 1
			var i0: int = p[j0]
			var delta := INF
			var j1 := 0
			for j in range(1, m + 1):
				if used[j] != 0:
					continue
				var base_pos: Vector2 = bases[i0 - 1]["pos"]
				var cost: float = base_pos.distance_squared_to(slots[j - 1]) - u[i0] - v[j]
				if cost < minv[j]:
					minv[j] = cost
					way[j] = j0
				if minv[j] < delta:
					delta = minv[j]
					j1 = j
			for j in range(m + 1):
				if used[j] != 0:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while j0 != 0:
			var j1 := way[j0]
			p[j0] = p[j1]
			j0 = j1
	for j in range(1, m + 1):
		if p[j] > 0:
			bases[p[j] - 1]["pos"] = slots[j - 1]

## Aparta las bases solapadas lo mínimo necesario y las mantiene dentro de `play_rect`
static func relax_positions(bases: Array[Dictionary], play_rect: Rect2 = PLAY_RECT) -> void:
	var points := PackedVector2Array()
	for base in bases:
		points.append(base["pos"])
	points = separate_points(points, func(i, j): return min_distance(bases[i].get("tier", 1), bases[j].get("tier", 1)), play_rect)
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
static func _pick_extra_neutrals(proj: MapProjection, bases: Array[Dictionary], count: int, difficulty: float, rng: RandomNumberGenerator, play_rect: Rect2) -> Array[Dictionary]:
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
		if not play_rect.has_point(pos):
			continue
		var tier := 2 if city["population"] >= 5000000 else 1
		if placed.any(func(b): return b["pos"].distance_to(pos) < min_distance(tier, b.get("tier", 1))):
			continue
		var extra := {
			"id": "x%d" % (extras.size() + 1),
			"city": city["key"],
			"name": GeoDatabase.city_name(city),
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
		var sb := GeoDatabase.bounds_of(pts)
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
