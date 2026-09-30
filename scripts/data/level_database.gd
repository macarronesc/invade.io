extends RefCounted
class_name LevelDatabase

## Base de datos con los niveles de campaña organizados por continentes

const LEVELS_PER_CONTINENT := 5

## Continentes en orden de campaña; sus niveles son "<id>_1" .. "<id>_5"
const CONTINENTS: Array[Dictionary] = [
	{"id": "europe", "name": "Europa", "name_en": "Europe", "color": Color(0.2, 0.6, 0.86)},
	{"id": "north_america", "name": "América del Norte", "name_en": "North America", "color": Color(0.9, 0.4, 0.3)},
	{"id": "south_america", "name": "América del Sur", "name_en": "South America", "color": Color(0.3, 0.75, 0.4)},
	{"id": "africa", "name": "África", "name_en": "Africa", "color": Color(0.95, 0.7, 0.2)},
	{"id": "asia", "name": "Asia", "name_en": "Asia", "color": Color(0.8, 0.3, 0.7)},
	{"id": "oceania", "name": "Oceanía", "name_en": "Oceania", "color": Color(0.1, 0.7, 0.7)},
]

static func get_continents() -> Array[Dictionary]:
	return CONTINENTS

## Nombre del continente en el idioma actual
static func continent_name(continent_id: String) -> String:
	for c in CONTINENTS:
		if c["id"] == continent_id:
			return c["name_en"] if LocaleStrings.lang == "en" else c["name"]
	return continent_id

static func get_continent_level_ids(continent_id: String) -> Array[String]:
	var ids: Array[String] = []
	for i in range(1, LEVELS_PER_CONTINENT + 1):
		ids.append("%s_%d" % [continent_id, i])
	return ids

static func get_continent_of(level_id: String) -> String:
	return level_id.substr(0, level_id.rfind("_"))

## Posición del nivel dentro de su continente (1..LEVELS_PER_CONTINENT)
static func get_level_number(level_id: String) -> int:
	return int(level_id.substr(level_id.rfind("_") + 1))

static var _definitions: Dictionary = {}
static var _built: Dictionary = {}
## ponytail: FIFO de 64 mapas; usar LRU si la regeneración resulta costosa en móviles.
const MAX_CACHED_LEVELS := 64

## Nivel listo para jugar: bases con posición en pantalla y geografía proyectada.
## Se construye la primera vez que se pide y queda en caché (una entrada por idioma).
## Los desafíos diarios ("daily_<día>") y la conquista ("conquest_<n>") se generan al vuelo.
static func get_level_data(level_id: String) -> Dictionary:
	var cache_key := "%s|%s" % [level_id, LocaleStrings.lang]
	if not _built.has(cache_key):
		var def := get_level_definition(level_id)
		if def.is_empty():
			return get_level_data(GameManager.FIRST_LEVEL_ID)
		var built: Dictionary = LevelGenerator.build(def, get_difficulty(level_id))
		_localize(built, def)
		CampaignRules.apply(built)
		if _built.size() >= MAX_CACHED_LEVELS:
			_built.erase(_built.keys()[0])
		_built[cache_key] = built
	return _built[cache_key]

## En inglés, los nombres y descripciones de campaña usan una plantilla con la
## ciudad central (las 30 descripciones literarias sólo existen en español).
static func _localize(built: Dictionary, def: Dictionary) -> void:
	var level_id: String = def.get("id", "")
	if LocaleStrings.lang != "en" or not _get_definitions().has(level_id):
		return
	var n := get_level_ids().find(level_id) + 1
	var center := ""
	for b in def.get("bases", []):
		if b.get("faction") == GameManager.Faction.PLAYER:
			center = GeoDatabase.city_name(GeoDatabase.get_city(b.get("city", "")))
			break
	built["name"] = "Level %d: %s" % [n, continent_name(get_continent_of(level_id))]
	built["description"] = LocaleStrings.text("level_desc_en") % [center, built.get("target_time", 45)]

## Definición original (ciudades y facciones) sin construir
static func get_level_definition(level_id: String) -> Dictionary:
	if DailyRewards.is_challenge(level_id):
		return LevelGenerator.daily_challenge_definition(DailyRewards.challenge_day(level_id))
	if LevelGenerator.is_conquest(level_id):
		return LevelGenerator.conquest_definition(LevelGenerator.conquest_index(level_id))
	return _get_definitions().get(level_id, {})

## Ids de la campaña en orden de juego
static func get_level_ids() -> Array:
	return _get_definitions().keys()

static func _get_definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = _build_levels()
	return _definitions

## Dificultad normalizada 0.0 (primer nivel) .. 1.0 (último nivel de la campaña)
static func get_difficulty(level_id: String) -> float:
	if DailyRewards.is_challenge(level_id):
		return DailyRewards.CHALLENGE_DIFFICULTY
	if LevelGenerator.is_conquest(level_id):
		return LevelGenerator.conquest_difficulty(LevelGenerator.conquest_index(level_id))
	var ids := get_level_ids()
	return maxf(0.0, ids.find(level_id)) / float(ids.size() - 1)

## Coordenadas de las ciudades de un nivel (sin construirlo), para situarlo en el mapa del mundo
static func get_level_lonlats(level_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for b in get_level_definition(level_id).get("bases", []):
		var city := GeoDatabase.get_city(b.get("city", ""))
		if not city.is_empty():
			result.append(city["lonlat"])
	return result

## Todos los niveles construidos (costoso: sólo para validaciones y tests)
static func get_all_levels() -> Dictionary:
	var result := {}
	for level_id in get_level_ids():
		result[level_id] = get_level_data(level_id)
	return result

## Definiciones de campaña: cada base apunta a una ciudad real de GeoDatabase. LevelGenerator
## las sitúa en el mapa, añade neutrales según la dificultad y recorta costas y fronteras.
static func _build_levels() -> Dictionary:
	return {
		# ===================== EUROPA =====================
		"europe_1": {
			"id": "europe_1",
			"name": "Nivel 1: Península Ibérica y Galia",
			"description": "Aprende los conceptos básicos: captura las bases neutrales y vence al enemigo rojo.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "city": "madrid", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 1},
				{"id": "b2", "city": "paris", "faction": GameManager.Faction.NEUTRAL, "troops": 8, "tier": 1},
				{"id": "b3", "city": "london", "faction": GameManager.Faction.NEUTRAL, "troops": 10, "tier": 1},
				{"id": "b4", "city": "berlin", "faction": GameManager.Faction.ENEMY_1, "troops": 18, "tier": 1}
			]
		},
		"europe_2": {
			"id": "europe_2",
			"name": "Nivel 2: Europa Central",
			"description": "Una red más densa de bases neutrales separa tu avance de Berlín y Roma.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "city": "lisbon", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 1},
				{"id": "b2", "city": "marseille", "faction": GameManager.Faction.NEUTRAL, "troops": 10, "tier": 1},
				{"id": "b3", "city": "rome", "faction": GameManager.Faction.NEUTRAL, "troops": 14, "tier": 1},
				{"id": "b4", "city": "prague", "faction": GameManager.Faction.NEUTRAL, "troops": 16, "tier": 1},
				{"id": "b5", "city": "warsaw", "faction": GameManager.Faction.ENEMY_1, "troops": 28, "tier": 1}
			]
		},
		"europe_3": {
			"id": "europe_3",
			"name": "Nivel 3: Países Nórdicos",
			"description": "Bases costeras con conexiones estratégicas.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "amsterdam", "faction": GameManager.Faction.PLAYER, "troops": 32, "tier": 1},
				{"id": "b2", "city": "kobenhavn", "faction": GameManager.Faction.NEUTRAL, "troops": 10, "tier": 1},
				{"id": "b3", "city": "oslo", "faction": GameManager.Faction.NEUTRAL, "troops": 14, "tier": 1},
				{"id": "b4", "city": "stockholm", "faction": GameManager.Faction.ENEMY_1, "troops": 24, "tier": 1},
				{"id": "b5", "city": "helsinki", "faction": GameManager.Faction.NEUTRAL, "troops": 12, "tier": 1}
			]
		},
		"europe_4": {
			"id": "europe_4",
			"name": "Nivel 4: Balcanes y Mediterráneo",
			"description": "Dos frentes hostiles: Facciones Roja y Amarilla te rodean.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "city": "athens", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "belgrade", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2, "type": "fortress"},
				{"id": "b3", "city": "vienna", "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b4", "city": "bucharest", "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2},
				{"id": "b5", "city": "istanbul", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1, "type": "factory"}
			]
		},
		"europe_5": {
			"id": "europe_5",
			"name": "Nivel 5: Capital Continental",
			"description": "La gran batalla por el control absoluto de Europa.",
			"target_time": 75,
			"bases": [
				{"id": "b1", "city": "madrid", "faction": GameManager.Faction.PLAYER, "troops": 40, "tier": 3},
				{"id": "b2", "city": "berlin", "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "city": "stockholm", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "factory"},
				{"id": "b4", "city": "moscow", "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "city": "istanbul", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "city": "london", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},

		# ===================== AMÉRICA DEL NORTE =====================
		"north_america_1": {
			"id": "north_america_1",
			"name": "Nivel 1: Costa Este",
			"description": "Inicia la campaña americana asegurando Nueva York y Boston.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "city": "miami", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "atlanta", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 2},
				{"id": "b3", "city": "new_york", "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"north_america_2": {
			"id": "north_america_2",
			"name": "Nivel 2: Grandes Llanuras",
			"description": "Territorios amplios donde la velocidad de marcha es vital.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "city": "dallas", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "kansas_city", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 2},
				{"id": "b3", "city": "chicago", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "factory"},
				{"id": "b4", "city": "denver", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},
		"north_america_3": {
			"id": "north_america_3",
			"name": "Nivel 3: Costa Oeste",
			"description": "Batalla a tres facciones entre California y el Pacífico.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "san_diego", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "los_angeles", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "city": "san_francisco", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "city": "seattle", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "las_vegas", "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 1}
			]
		},
		"north_america_4": {
			"id": "north_america_4",
			"name": "Nivel 4: Gran Norte (Canadá)",
			"description": "Grandes distancias y bases de alto nivel.",
			"target_time": 70,
			"bases": [
				{"id": "b1", "city": "toronto", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "city": "montreal", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "city": "calgary", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b4", "city": "vancouver", "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"north_america_5": {
			"id": "north_america_5",
			"name": "Nivel 5: Megalópolis Continental",
			"description": "Conquista final de Norteamérica frente a tres ejércitos simultáneos.",
			"target_time": 80,
			"bases": [
				{"id": "b1", "city": "mexico_city", "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "city": "denver", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 3, "type": "fortress"},
				{"id": "b3", "city": "new_york", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "factory"},
				{"id": "b4", "city": "winnipeg", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 2},
				{"id": "b5", "city": "vancouver", "faction": GameManager.Faction.ENEMY_3, "troops": 35, "tier": 2}
			]
		},

		# ===================== SUDAMÉRICA =====================
		"south_america_1": {
			"id": "south_america_1",
			"name": "Nivel 1: Cono Sur",
			"description": "Incursión en Sudamérica comenzando en Buenos Aires y Santiago.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "city": "buenos_aires", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "santiago", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "city": "sao_paulo", "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"south_america_2": {
			"id": "south_america_2",
			"name": "Nivel 2: Cordillera de los Andes",
			"description": "Avance montañoso a través de bases estratégicas de altura.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "city": "santiago", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "la_paz", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 2, "type": "fortress"},
				{"id": "b3", "city": "lima", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "city": "bogota", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "quito", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1}
			]
		},
		"south_america_3": {
			"id": "south_america_3",
			"name": "Nivel 3: Cuenca del Amazonas",
			"description": "Dos frentes rivales convergen hacia el control del gran río.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "brasilia", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "belem", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "city": "manaus", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "city": "caracas", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "georgetown", "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2}
			]
		},
		"south_america_4": {
			"id": "south_america_4",
			"name": "Nivel 4: Frentes Cruzados",
			"description": "Batalla intensa a tres ejércitos por la costa atlántica.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "city": "montevideo", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "city": "asuncion", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b3", "city": "cordoba", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b4", "city": "salvador", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "fortaleza", "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"south_america_5": {
			"id": "south_america_5",
			"name": "Nivel 5: Dominio Continental",
			"description": "Gran batalla final por el control de toda América del Sur frente a 3 facciones.",
			"target_time": 80,
			"bases": [
				{"id": "b1", "city": "buenos_aires", "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "city": "la_paz", "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "city": "georgetown", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "city": "rio_de_janeiro", "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3, "type": "factory"},
				{"id": "b5", "city": "bogota", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "city": "lima", "faction": GameManager.Faction.ENEMY_3, "troops": 35, "tier": 2}
			]
		},

		# ===================== ÁFRICA =====================
		"africa_1": {
			"id": "africa_1",
			"name": "Nivel 1: Delta del Nilo",
			"description": "Desierto del Sáhara y el valle del Nilo.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "city": "alexandria", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "cairo", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "city": "aswan", "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2}
			]
		},
		"africa_2": {
			"id": "africa_2",
			"name": "Nivel 2: Magreb y Desierto",
			"description": "Bases costeras del norte de África y pasos caravaneros.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "city": "marrakesh", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "fez", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "city": "algiers", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b4", "city": "tripoli", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2, "type": "fortress"},
				{"id": "b5", "city": "tunis", "faction": GameManager.Faction.NEUTRAL, "troops": 16, "tier": 1}
			]
		},
		"africa_3": {
			"id": "africa_3",
			"name": "Nivel 3: Golfo de Guinea",
			"description": "Alta densidad de bases y frentes convergentes en África Occidental.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "accra", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "abidjan", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1},
				{"id": "b3", "city": "lagos", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "city": "yaounde", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "ndjamena", "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 2}
			]
		},
		"africa_4": {
			"id": "africa_4",
			"name": "Nivel 4: Valle del Rift y Cuerno",
			"description": "Lucha por los Grandes Lagos y el este del continente.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "city": "mombasa", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "nairobi", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2, "type": "factory"},
				{"id": "b3", "city": "kampala", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "city": "addis_ababa", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "mogadishu", "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"africa_5": {
			"id": "africa_5",
			"name": "Nivel 5: Unión Panafricana",
			"description": "Asedio total a cuatro frentes desde el Cabo hasta el Mediterráneo.",
			"target_time": 85,
			"bases": [
				{"id": "b1", "city": "cape_town", "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "city": "kinshasa", "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "factory"},
				{"id": "b3", "city": "tamanrasset", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "fortress"},
				{"id": "b4", "city": "cairo", "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "city": "lagos", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "city": "dar_es_salaam", "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		},

		# ===================== ASIA =====================
		"asia_1": {
			"id": "asia_1",
			"name": "Nivel 1: Ruta de la Seda",
			"description": "Un vasto continente con alta densidad militar.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "city": "samarqand", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "beijing", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "city": "tokyo", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2}
			]
		},
		"asia_2": {
			"id": "asia_2",
			"name": "Nivel 2: Subcontinente Indio",
			"description": "Rápida expansión en una península populosa y disputada.",
			"target_time": 55,
			"bases": [
				{"id": "b1", "city": "bengaluru", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "mumbai", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2},
				{"id": "b3", "city": "kolkata", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2, "type": "factory"},
				{"id": "b4", "city": "new_delhi", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "karachi", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1}
			]
		},
		"asia_3": {
			"id": "asia_3",
			"name": "Nivel 3: Oriente Medio",
			"description": "Encrucijada petrolífera y fortalezas desérticas.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "muscat", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "dubai", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b3", "city": "riyadh", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "city": "baghdad", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "tehran", "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"asia_4": {
			"id": "asia_4",
			"name": "Nivel 4: Dragones de Asia",
			"description": "Guerra insular y costera de alta velocidad de marcha.",
			"target_time": 70,
			"bases": [
				{"id": "b1", "city": "singapore", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "city": "bangkok", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b3", "city": "jakarta", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 1},
				{"id": "b4", "city": "taipei", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "seoul", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 2}
			]
		},
		"asia_5": {
			"id": "asia_5",
			"name": "Nivel 5: Emperadores de Oriente",
			"description": "El mayor enfrentamiento táctico del planeta: megabases imperiales.",
			"target_time": 90,
			"bases": [
				{"id": "b1", "city": "kolkata", "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "city": "chengdu", "faction": GameManager.Faction.NEUTRAL, "troops": 35, "tier": 3, "type": "fortress"},
				{"id": "b3", "city": "novosibirsk", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1},
				{"id": "b4", "city": "beijing", "faction": GameManager.Faction.ENEMY_1, "troops": 45, "tier": 3},
				{"id": "b5", "city": "guangzhou", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3, "type": "factory"},
				{"id": "b6", "city": "tokyo", "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		},

		# ===================== OCEANÍA =====================
		"oceania_1": {
			"id": "oceania_1",
			"name": "Nivel 1: Arrecife de Coral",
			"description": "Bases insulares en el Pacífico.",
			"target_time": 45,
			"bases": [
				{"id": "b1", "city": "sydney", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "melbourne", "faction": GameManager.Faction.NEUTRAL, "troops": 15, "tier": 1},
				{"id": "b3", "city": "auckland", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2}
			]
		},
		"oceania_2": {
			"id": "oceania_2",
			"name": "Nivel 2: Outback Australiano",
			"description": "Inmensas extensiones desérticas donde cada movimiento cuenta.",
			"target_time": 50,
			"bases": [
				{"id": "b1", "city": "adelaide", "faction": GameManager.Faction.PLAYER, "troops": 25, "tier": 1},
				{"id": "b2", "city": "alice_springs", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1, "type": "factory"},
				{"id": "b3", "city": "darwin", "faction": GameManager.Faction.ENEMY_1, "troops": 30, "tier": 2},
				{"id": "b4", "city": "perth", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 2}
			]
		},
		"oceania_3": {
			"id": "oceania_3",
			"name": "Nivel 3: Polinesia y Mares del Sur",
			"description": "Guerra de islas que requiere coordinación de múltiples orígenes.",
			"target_time": 60,
			"bases": [
				{"id": "b1", "city": "wellington", "faction": GameManager.Faction.PLAYER, "troops": 30, "tier": 2},
				{"id": "b2", "city": "christchurch", "faction": GameManager.Faction.NEUTRAL, "troops": 18, "tier": 1},
				{"id": "b3", "city": "auckland", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b4", "city": "suva", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "apia", "faction": GameManager.Faction.ENEMY_2, "troops": 30, "tier": 1}
			]
		},
		"oceania_4": {
			"id": "oceania_4",
			"name": "Nivel 4: Archipiélago Austral",
			"description": "Doble frente agresivo en las grandes costas oceánicas.",
			"target_time": 65,
			"bases": [
				{"id": "b1", "city": "hobart", "faction": GameManager.Faction.PLAYER, "troops": 35, "tier": 2},
				{"id": "b2", "city": "melbourne", "faction": GameManager.Faction.NEUTRAL, "troops": 22, "tier": 2},
				{"id": "b3", "city": "canberra", "faction": GameManager.Faction.NEUTRAL, "troops": 25, "tier": 2},
				{"id": "b4", "city": "sydney", "faction": GameManager.Faction.ENEMY_1, "troops": 35, "tier": 2},
				{"id": "b5", "city": "brisbane", "faction": GameManager.Faction.ENEMY_2, "troops": 35, "tier": 2}
			]
		},
		"oceania_5": {
			"id": "oceania_5",
			"name": "Nivel 5: Soberanía del Pacífico",
			"description": "La culminación de la campaña mundial: vence a tres imperios insulares.",
			"target_time": 85,
			"bases": [
				{"id": "b1", "city": "perth", "faction": GameManager.Faction.PLAYER, "troops": 45, "tier": 3},
				{"id": "b2", "city": "alice_springs", "faction": GameManager.Faction.NEUTRAL, "troops": 30, "tier": 3, "type": "fortress"},
				{"id": "b3", "city": "cairns", "faction": GameManager.Faction.NEUTRAL, "troops": 20, "tier": 1, "type": "factory"},
				{"id": "b4", "city": "auckland", "faction": GameManager.Faction.ENEMY_1, "troops": 40, "tier": 3},
				{"id": "b5", "city": "port_moresby", "faction": GameManager.Faction.ENEMY_2, "troops": 40, "tier": 3},
				{"id": "b6", "city": "suva", "faction": GameManager.Faction.ENEMY_3, "troops": 40, "tier": 3}
			]
		}
	}
