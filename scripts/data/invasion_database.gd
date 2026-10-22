extends RefCounted
class_name InvasionDatabase

## Invasiones: operaciones regionales de tres frentes sobre ciudades reales.
## Cada región es una entrada de datos; los niveles se generan de forma determinista y
## se cachean en LevelDatabase. La campaña de 30 niveles no se toca.

const PREFIX := "inv_"
const FRONTS := 3
const REGION_COMPLETION_GOLD := 250
const REGION_MASTERY_GOLD := 150

## Regiones de la primera temporada. "countries" documenta el ámbito real y permite
## ampliar el catálogo sin inventar geografía; "cities" está ordenada por importancia.
const REGIONS: Array[Dictionary] = [
	{
		"id": "iberia", "continent": "europe", "tier": 1, "rule": "capital",
		"name": "Iberia", "name_en": "Iberia",
		"subtitle": "España · Portugal", "subtitle_en": "Spain · Portugal",
		"countries": ["ESP", "PRT"], "capital": "madrid",
		"cities": ["madrid", "barcelona", "lisbon", "seville", "bilbao", "valencia_esp", "vigo", "cordoba_esp"]
	},
	{
		"id": "british_isles", "continent": "europe", "tier": 1, "rule": "sea_lanes",
		"name": "Reino Unido e Irlanda", "name_en": "United Kingdom & Ireland",
		"subtitle": "Londres · Dublín · Manchester", "subtitle_en": "London · Dublin · Manchester",
		"countries": ["GBR", "IRL"], "capital": "london",
		"cities": ["london", "birmingham", "manchester", "glasgow", "dublin", "belfast"]
	},
	{
		"id": "france_benelux", "continent": "europe", "tier": 2, "rule": "factory",
		"name": "Francia y Benelux", "name_en": "France & Benelux",
		"subtitle": "Francia · Bélgica · Países Bajos", "subtitle_en": "France · Belgium · Netherlands",
		"countries": ["FRA", "BEL", "NLD", "LUX"], "capital": "paris",
		"cities": ["paris", "brussels", "lyon", "the_hague", "marseille", "amsterdam", "bordeaux", "le_havre"]
	},
	{
		"id": "italy", "continent": "europe", "tier": 2, "rule": "capital",
		"name": "Italia", "name_en": "Italy",
		"subtitle": "Italia · Malta", "subtitle_en": "Italy · Malta",
		"countries": ["ITA", "MLT"], "capital": "rome",
		"cities": ["rome", "milan", "naples", "florence", "palermo", "catania", "venice", "valletta"]
	},
	{
		"id": "scandinavia", "continent": "europe", "tier": 2, "rule": "sea_lanes",
		"name": "Escandinavia", "name_en": "Scandinavia",
		"subtitle": "Suecia · Noruega · Dinamarca · Finlandia · Islandia", "subtitle_en": "Sweden · Norway · Denmark · Finland · Iceland",
		"countries": ["SWE", "NOR", "DNK", "FIN", "ISL"], "capital": "stockholm",
		"cities": ["stockholm", "helsinki", "kobenhavn", "oslo", "malmo", "tampere", "bergen", "reykjavik"]
	},
	{
		"id": "balkans", "continent": "europe", "tier": 2, "rule": "fortress",
		"name": "Balcanes", "name_en": "Balkans",
		"subtitle": "Grecia · Rumanía · Serbia · Croacia", "subtitle_en": "Greece · Romania · Serbia · Croatia",
		"countries": ["GRC", "ROU", "SRB", "HRV", "BGR", "BIH", "ALB", "MKD", "SVN", "MNE"], "capital": "athens",
		"cities": ["athens", "bucharest", "sofia", "belgrade", "tirana", "thessaloniki", "zagreb", "sarajevo"]
	},
	{
		"id": "central_europe", "continent": "europe", "tier": 2, "rule": "factory",
		"name": "Europa Central", "name_en": "Central Europe",
		"subtitle": "Alemania · Austria · Suiza · Chequia", "subtitle_en": "Germany · Austria · Switzerland · Czechia",
		"countries": ["DEU", "AUT", "CHE", "CZE", "SVK", "HUN"], "capital": "berlin",
		"cities": ["berlin", "frankfurt", "vienna", "hamburg", "budapest", "munich", "geneva", "prague"]
	},
	{
		"id": "eastern_europe", "continent": "europe", "tier": 3, "rule": "fortress",
		"name": "Europa del Este", "name_en": "Eastern Europe",
		"subtitle": "Polonia · Ucrania · Rusia occidental", "subtitle_en": "Poland · Ukraine · Western Russia",
		"countries": ["POL", "UKR", "BLR", "LTU", "LVA", "EST", "MDA", "RUS"], "capital": "moscow",
		"cities": ["moscow", "st_petersburg", "kiev", "minsk", "warsaw", "kharkiv", "nizhny_novgorod", "samara"]
	},
	{
		"id": "us_east", "continent": "north_america", "tier": 2, "rule": "capital",
		"name": "EE. UU. · Costa Este", "name_en": "USA · East Coast",
		"subtitle": "Nueva York · Washington · Chicago · Miami", "subtitle_en": "New York · Washington · Chicago · Miami",
		"countries": ["USA"], "capital": "washington_d_c",
		"cities": ["new_york", "chicago", "miami", "philadelphia", "atlanta", "boston", "washington_d_c", "detroit"]
	},
	{
		"id": "us_south", "continent": "north_america", "tier": 2, "rule": "factory",
		"name": "EE. UU. · Sur", "name_en": "USA · South",
		"subtitle": "Texas · Luisiana · Tennessee", "subtitle_en": "Texas · Louisiana · Tennessee",
		"countries": ["USA"], "capital": "atlanta",
		"cities": ["dallas", "houston", "san_antonio", "ft_worth", "austin", "memphis", "new_orleans", "atlanta"]
	},
	{
		"id": "us_west", "continent": "north_america", "tier": 3, "rule": "fortress",
		"name": "EE. UU. · Oeste", "name_en": "USA · West",
		"subtitle": "California · Costa del Pacífico · Montañas Rocosas", "subtitle_en": "California · Pacific Coast · Rocky Mountains",
		"countries": ["USA"], "capital": "los_angeles",
		"cities": ["los_angeles", "phoenix", "san_francisco", "seattle", "san_diego", "denver", "portland", "las_vegas"]
	},
	{
		"id": "canada_east", "continent": "north_america", "tier": 2, "rule": "capital",
		"name": "Canadá oriental", "name_en": "Eastern Canada",
		"subtitle": "Ontario · Quebec · Manitoba", "subtitle_en": "Ontario · Quebec · Manitoba",
		"countries": ["CAN"], "capital": "ottawa",
		"cities": ["toronto", "montreal", "ottawa", "winnipeg", "quebec", "halifax", "st_john_s", "thunder_bay"]
	},
	{
		"id": "canada_west", "continent": "north_america", "tier": 3, "rule": "sea_lanes",
		"name": "Canadá occidental", "name_en": "Western Canada",
		"subtitle": "Columbia Británica · Alberta", "subtitle_en": "British Columbia · Alberta",
		"countries": ["CAN"], "capital": "vancouver",
		"cities": ["vancouver", "calgary", "edmonton", "victoria", "saskatoon", "regina", "whitehorse", "fort_mcmurray"]
	},
	{
		"id": "mexico", "continent": "north_america", "tier": 3, "rule": "fortress",
		"name": "México", "name_en": "Mexico",
		"subtitle": "México", "subtitle_en": "Mexico",
		"countries": ["MEX"], "capital": "mexico_city",
		"cities": ["mexico_city", "guadalajara", "monterrey", "puebla", "tijuana", "leon", "torreon", "san_luis_potosi"]
	},
	{
		"id": "central_america_caribbean", "continent": "north_america", "tier": 2, "rule": "sea_lanes",
		"name": "Centroamérica y Caribe", "name_en": "Central America & Caribbean",
		"subtitle": "Guatemala · Cuba · Panamá · Caribe", "subtitle_en": "Guatemala · Cuba · Panama · Caribbean",
		"countries": ["GTM", "CUB", "DOM", "HTI", "PRI", "SLV", "CRI", "PAN"], "capital": "guatemala",
		"cities": ["guatemala", "havana", "santo_domingo", "port_au_prince", "san_juan", "san_salvador", "san_jose_cri", "panama_city"]
	},
	{
		"id": "brazil_coast", "continent": "south_america", "tier": 3, "rule": "capital",
		"name": "Costa de Brasil", "name_en": "Brazilian Coast",
		"subtitle": "São Paulo · Río de Janeiro · Brasilia · Recife", "subtitle_en": "São Paulo · Rio de Janeiro · Brasília · Recife",
		"countries": ["BRA"], "capital": "brasilia",
		"cities": ["sao_paulo", "rio_de_janeiro", "belo_horizonte", "brasilia", "recife", "fortaleza", "salvador", "curitiba"]
	},
	{
		"id": "amazon", "continent": "south_america", "tier": 3, "rule": "jungle",
		"name": "Amazonía", "name_en": "Amazon Basin",
		"subtitle": "Manaus · Belém · Guayanas", "subtitle_en": "Manaus · Belém · Guianas",
		"countries": ["BRA", "GUY", "SUR"], "capital": "manaus",
		"cities": ["manaus", "belem", "porto_velho", "rio_branco", "macapa", "boa_vista", "santarem", "maraba"]
	},
	{
		"id": "andes", "continent": "south_america", "tier": 3, "rule": "fortress",
		"name": "Andes", "name_en": "Andes",
		"subtitle": "Colombia · Perú · Ecuador · Bolivia", "subtitle_en": "Colombia · Peru · Ecuador · Bolivia",
		"countries": ["COL", "PER", "ECU", "BOL", "VEN"], "capital": "lima",
		"cities": ["lima", "bogota", "medellin", "caracas", "guayaquil", "cali", "santa_cruz", "maracaibo"]
	},
	{
		"id": "southern_cone", "continent": "south_america", "tier": 3, "rule": "factory",
		"name": "Cono Sur", "name_en": "Southern Cone",
		"subtitle": "Argentina · Chile · Uruguay · Paraguay", "subtitle_en": "Argentina · Chile · Uruguay · Paraguay",
		"countries": ["ARG", "CHL", "URY", "PRY"], "capital": "buenos_aires",
		"cities": ["buenos_aires", "santiago", "asuncion", "montevideo", "cordoba", "rosario", "mendoza", "concepcion"]
	},
	{
		"id": "maghreb", "continent": "africa", "tier": 2, "rule": "oasis",
		"name": "Magreb", "name_en": "Maghreb",
		"subtitle": "Marruecos · Argelia · Túnez · Libia", "subtitle_en": "Morocco · Algeria · Tunisia · Libya",
		"countries": ["MAR", "DZA", "TUN", "LBY"], "capital": "algiers",
		"cities": ["algiers", "casablanca", "tunis", "tripoli", "rabat", "banghazi", "fez", "marrakesh"]
	},
	{
		"id": "nile", "continent": "africa", "tier": 3, "rule": "factory",
		"name": "Valle del Nilo", "name_en": "Nile Valley",
		"subtitle": "Egipto · Sudán", "subtitle_en": "Egypt · Sudan",
		"countries": ["EGY", "SDN"], "capital": "cairo",
		"cities": ["cairo", "khartoum", "alexandria", "omdurman", "bur_said", "luxor", "suez", "port_sudan"]
	},
	{
		"id": "west_africa", "continent": "africa", "tier": 3, "rule": "capital",
		"name": "África Occidental", "name_en": "West Africa",
		"subtitle": "Nigeria · Ghana · Senegal · Costa de Marfil", "subtitle_en": "Nigeria · Ghana · Senegal · Ivory Coast",
		"countries": ["NGA", "GHA", "SEN", "CIV", "MLI", "BFA", "NER", "GIN", "BEN", "TGO", "SLE", "LBR"], "capital": "lagos",
		"cities": ["lagos", "abidjan", "kano", "ibadan", "dakar", "accra", "abuja", "bamako"]
	},
	{
		"id": "central_africa", "continent": "africa", "tier": 4, "rule": "jungle",
		"name": "África Central", "name_en": "Central Africa",
		"subtitle": "R. D. del Congo · Angola · Camerún", "subtitle_en": "DR Congo · Angola · Cameroon",
		"countries": ["COD", "COG", "CMR", "CAF", "TCD", "AGO", "GAB", "GNQ"], "capital": "kinshasa",
		"cities": ["kinshasa", "luanda", "douala", "yaounde", "brazzaville", "lubumbashi", "mbuji_mayi", "huambo"]
	},
	{
		"id": "east_africa", "continent": "africa", "tier": 4, "rule": "fortress",
		"name": "África Oriental", "name_en": "East Africa",
		"subtitle": "Etiopía · Kenia · Tanzania · Somalia", "subtitle_en": "Ethiopia · Kenya · Tanzania · Somalia",
		"countries": ["KEN", "ETH", "TZA", "UGA", "SOM", "RWA", "BDI", "ERI", "DJI"], "capital": "nairobi",
		"cities": ["addis_ababa", "nairobi", "dar_es_salaam", "kampala", "mogadishu", "djibouti", "mombasa", "kigali"]
	},
	{
		"id": "southern_africa", "continent": "africa", "tier": 4, "rule": "factory",
		"name": "África Austral", "name_en": "Southern Africa",
		"subtitle": "Sudáfrica · Mozambique · Zimbabue · Madagascar", "subtitle_en": "South Africa · Mozambique · Zimbabwe · Madagascar",
		"countries": ["ZAF", "MOZ", "ZWE", "ZMB", "BWA", "NAM", "MWI", "MDG"], "capital": "cape_town",
		"cities": ["johannesburg", "cape_town", "durban", "antananarivo", "harare", "maputo", "pretoria", "lusaka"]
	},
	{
		"id": "middle_east", "continent": "asia", "tier": 4, "rule": "fortress",
		"name": "Oriente Medio", "name_en": "Middle East",
		"subtitle": "Turquía · Irán · Irak · Arabia Saudí", "subtitle_en": "Turkey · Iran · Iraq · Saudi Arabia",
		"countries": ["TUR", "IRN", "IRQ", "SAU", "ISR", "JOR", "LBN", "SYR", "ARE", "KWT", "QAT", "OMN", "YEM", "BHR"], "capital": "riyadh",
		"cities": ["istanbul", "tehran", "baghdad", "riyadh", "ankara", "tel_aviv_yafo", "jeddah", "aleppo"]
	},
	{
		"id": "south_asia", "continent": "asia", "tier": 4, "rule": "capital",
		"name": "Asia del Sur", "name_en": "South Asia",
		"subtitle": "India · Pakistán · Bangladés · Sri Lanka", "subtitle_en": "India · Pakistan · Bangladesh · Sri Lanka",
		"countries": ["IND", "PAK", "BGD", "LKA", "NPL", "AFG"], "capital": "new_delhi",
		"cities": ["mumbai", "new_delhi", "kolkata", "dhaka", "karachi", "chennai", "bengaluru", "lahore"]
	},
	{
		"id": "china", "continent": "asia", "tier": 4, "rule": "factory",
		"name": "Costa de China", "name_en": "China Coast",
		"subtitle": "Pekín · Shanghái · Guangzhou · Hong Kong", "subtitle_en": "Beijing · Shanghai · Guangzhou · Hong Kong",
		"countries": ["CHN", "TWN", "HKG"], "capital": "beijing",
		"cities": ["shanghai", "beijing", "guangzhou", "shenzhen", "wuhan", "hong_kong", "tianjin", "taipei"]
	},
	{
		"id": "japan_korea", "continent": "asia", "tier": 4, "rule": "sea_lanes",
		"name": "Japón y Corea", "name_en": "Japan & Korea",
		"subtitle": "Japón · Corea del Sur · Corea del Norte", "subtitle_en": "Japan · South Korea · North Korea",
		"countries": ["JPN", "KOR", "PRK"], "capital": "tokyo",
		"cities": ["tokyo", "osaka", "seoul", "busan", "pyongyang", "nagoya", "fukuoka", "incheon"]
	},
	{
		"id": "southeast_asia", "continent": "asia", "tier": 4, "rule": "sea_lanes",
		"name": "Sudeste Asiático", "name_en": "Southeast Asia",
		"subtitle": "Indonesia · Filipinas · Vietnam · Tailandia", "subtitle_en": "Indonesia · Philippines · Vietnam · Thailand",
		"countries": ["IDN", "PHL", "VNM", "THA", "MYS", "SGP", "MMR", "KHM", "LAO", "BRN", "TLS"], "capital": "bangkok",
		"cities": ["manila", "jakarta", "bangkok", "ho_chi_minh_city", "singapore", "hanoi", "rangoon", "surabaya"]
	},
	{
		"id": "central_asia", "continent": "asia", "tier": 4, "rule": "fortress",
		"name": "Asia Central", "name_en": "Central Asia",
		"subtitle": "Kazajistán · Uzbekistán · Cáucaso", "subtitle_en": "Kazakhstan · Uzbekistan · Caucasus",
		"countries": ["KAZ", "UZB", "TKM", "KGZ", "TJK", "AZE", "ARM", "GEO", "MNG"], "capital": "tashkent",
		"cities": ["tashkent", "baku", "almaty", "yerevan", "tbilisi", "dushanbe", "ulaanbaatar", "bishkek"]
	},
	{
		"id": "siberia", "continent": "asia", "tier": 4, "rule": "fortress",
		"name": "Siberia", "name_en": "Siberia",
		"subtitle": "Rusia asiática", "subtitle_en": "Asian Russia",
		"countries": ["RUS"], "capital": "novosibirsk",
		"cities": ["novosibirsk", "yekaterinburg", "omsk", "chelyabinsk", "krasnoyarsk", "barnaul", "vladivostok", "irkutsk"]
	},
	{
		"id": "australia_east", "continent": "oceania", "tier": 4, "rule": "factory",
		"name": "Australia oriental", "name_en": "Eastern Australia",
		"subtitle": "Sídney · Melbourne · Brisbane", "subtitle_en": "Sydney · Melbourne · Brisbane",
		"countries": ["AUS"], "capital": "canberra",
		"cities": ["sydney", "melbourne", "brisbane", "adelaide", "newcastle", "gold_coast", "canberra", "cairns"]
	},
	{
		"id": "australia_west", "continent": "oceania", "tier": 4, "rule": "fortress",
		"name": "Australia occidental y septentrional", "name_en": "Western and Northern Australia",
		"subtitle": "Perth · Darwin · Alice Springs", "subtitle_en": "Perth · Darwin · Alice Springs",
		"countries": ["AUS"], "capital": "perth",
		"cities": ["perth", "darwin", "alice_springs", "port_hedland", "geraldton", "albany", "karratha", "broome"]
	},
	{
		"id": "new_zealand", "continent": "oceania", "tier": 5, "rule": "sea_lanes",
		"name": "Nueva Zelanda", "name_en": "New Zealand",
		"subtitle": "Nueva Zelanda", "subtitle_en": "New Zealand",
		"countries": ["NZL"], "capital": "wellington",
		"cities": ["auckland", "wellington", "manukau", "christchurch", "hamilton", "dunedin", "napier", "blenheim"]
	},
	{
		"id": "pacific", "continent": "oceania", "tier": 5, "rule": "sea_lanes",
		"name": "Pacífico", "name_en": "Pacific",
		"subtitle": "Papúa Nueva Guinea · Fiyi · Samoa", "subtitle_en": "Papua New Guinea · Fiji · Samoa",
		"countries": ["PNG", "FJI", "WSM", "TON", "VUT", "SLB", "NCL", "PYF"], "capital": "suva",
		"cities": ["port_moresby", "suva", "papeete", "lae", "honiara", "apia", "mt_hagen", "port_vila"]
	}
]

static var _by_id: Dictionary = {}
static var _definitions: Dictionary = {}

static func _ensure_index() -> void:
	if not _by_id.is_empty():
		return
	for region in REGIONS:
		_by_id[region["id"]] = region

static func get_regions() -> Array[Dictionary]:
	return REGIONS

static func get_region(region_id: String) -> Dictionary:
	_ensure_index()
	return _by_id.get(region_id, {})

static func get_region_count() -> int:
	return REGIONS.size()

static func get_total_fronts() -> int:
	return REGIONS.size() * FRONTS

static func get_regions_by_continent(continent_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region in REGIONS:
		if region["continent"] == continent_id:
			result.append(region)
	return result

static func region_name(region: Dictionary) -> String:
	return LocaleStrings.text("invregion_%s_name" % region["id"])

static func region_subtitle(region: Dictionary) -> String:
	return LocaleStrings.text("invregion_%s_subtitle" % region["id"])

static func level_id(region_id: String, step: int) -> String:
	return "%s%s_%d" % [PREFIX, region_id, step]

static func parse_level(level_id_value: String) -> Dictionary:
	if not level_id_value.begins_with(PREFIX):
		return {}
	var split := level_id_value.rfind("_")
	if split <= PREFIX.length():
		return {}
	var region_id := level_id_value.substr(PREFIX.length(), split - PREFIX.length())
	var step := int(level_id_value.substr(split + 1))
	if step < 1 or step > FRONTS:
		return {}
	var region := get_region(region_id)
	if region.is_empty():
		return {}
	return {"region": region, "region_id": region_id, "step": step}

static func is_invasion(level_id_value: String) -> bool:
	return not parse_level(level_id_value).is_empty()

static func get_region_of_level(level_id_value: String) -> String:
	return str(parse_level(level_id_value).get("region_id", ""))

static func get_front_of_level(level_id_value: String) -> int:
	return int(parse_level(level_id_value).get("step", 0))

static func get_region_level_ids(region_id: String) -> Array[String]:
	var ids: Array[String] = []
	for step in range(1, FRONTS + 1):
		ids.append(level_id(region_id, step))
	return ids

static func get_front_title(step: int) -> String:
	return LocaleStrings.text("inv_front_%d" % clampi(step, 1, FRONTS))

static func rule_key(rule: String) -> String:
	match rule:
		"capital": return "rule_inv_capital"
		"oasis": return "rule_inv_oasis"
		"factory": return "rule_inv_factory"
		"fortress": return "rule_inv_fortress"
		"jungle": return "rule_inv_jungle"
		"sea_lanes": return "rule_inv_sea_lanes"
	return ""

static func rule_text(rule: String) -> String:
	var key := rule_key(rule)
	return LocaleStrings.text(key) if key != "" else ""

## Definición del frente. No incluye geografía ni posiciones: eso lo hace LevelGenerator.
static func get_level_definition(level_id_value: String) -> Dictionary:
	var parsed := parse_level(level_id_value)
	if parsed.is_empty():
		return {}
	var cache_key := "%s|%s" % [level_id_value, LocaleStrings.lang]
	if _definitions.has(cache_key):
		return _definitions[cache_key]
	var region: Dictionary = parsed["region"]
	var definition := _build_definition(region, int(parsed["step"]))
	_definitions[cache_key] = definition
	return definition

static func get_region_lonlats(region_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var region := get_region(region_id)
	for city_key in region.get("cities", []):
		var city := GeoDatabase.get_city(city_key)
		if not city.is_empty():
			result.append(city["lonlat"])
	return result

static func get_front_lonlats(level_id_value: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for base in get_level_definition(level_id_value).get("bases", []):
		var city := GeoDatabase.get_city(base.get("city", ""))
		if not city.is_empty():
			result.append(city["lonlat"])
	return result

static func _build_definition(region: Dictionary, step: int) -> Dictionary:
	var tier := int(region["tier"])
	var capital := str(region["capital"])
	var others: Array[String] = []
	for city_key in region["cities"]:
		if str(city_key) != capital:
			others.append(str(city_key))
	if others.is_empty():
		others.append(capital)

	var bases: Array[Dictionary] = []
	var used := {}
	var player_troops := 34 + (tier - 1) * 2 + (step - 1) * 2
	var enemy_troops := 18 + (tier - 1) * 3 + step * 3
	var neutral_troops := 8 + (tier - 1) * 2 + (step - 1)
	var player_tier := 2 if tier >= 3 else 1
	var neutral_tier := 2 if tier >= 3 or step >= 2 else 1

	if step == 1:
		_add_base(bases, used, others[0], GameManager.Faction.PLAYER, player_troops, player_tier)
		_add_base(bases, used, others[1], GameManager.Faction.ENEMY_1, enemy_troops, neutral_tier)
		for i in range(2, mini(others.size(), 5)):
			_add_base(bases, used, others[i], GameManager.Faction.NEUTRAL, neutral_troops, neutral_tier)
	elif step == 2:
		_add_base(bases, used, others[2 % others.size()], GameManager.Faction.PLAYER, player_troops + 2, player_tier)
		_add_base(bases, used, others[0], GameManager.Faction.ENEMY_1, enemy_troops, neutral_tier)
		if others.size() > 3:
			_add_base(bases, used, others[3], GameManager.Faction.ENEMY_2, maxi(8, enemy_troops - 4), neutral_tier)
		for i in others.size():
			if bases.size() >= 7:
				break
			_add_base(bases, used, others[i], GameManager.Faction.NEUTRAL, neutral_troops, neutral_tier)
	else:
		_add_base(bases, used, others[1 % others.size()], GameManager.Faction.PLAYER, player_troops + 4, player_tier)
		_add_base(bases, used, capital, GameManager.Faction.ENEMY_1, enemy_troops + 6, 3, "fortress", true)
		for i in others.size():
			if bases.size() >= 9:
				break
			_add_base(bases, used, others[i], GameManager.Faction.NEUTRAL, neutral_troops + 2, neutral_tier)

	if step < 3 and str(region["rule"]) in ["capital", "oasis"]:
		_add_base(bases, used, capital, GameManager.Faction.NEUTRAL, neutral_troops + 12, 3)
	_mark_special_base(bases, region)
	var front_title := get_front_title(step)
	return {
		"id": level_id(region["id"], step),
		"name": LocaleStrings.text("inv_level_name") % [region_name(region), front_title],
		"description": LocaleStrings.text("inv_level_desc") % [region_name(region), step, front_title],
		"target_time": 55 + tier * 4 + step * 7,
		"bases": bases,
		"extra_neutrals": 0,
		"continent": region["continent"],
		"invasion_region": region["id"],
		"invasion_rule": region["rule"],
		"invasion_front": step,
	}

static func _add_base(bases: Array[Dictionary], used: Dictionary, city_key: String,
		faction: int, troops: int, tier: int, type: String = "", boss: bool = false) -> void:
	if city_key == "" or used.has(city_key):
		return
	used[city_key] = true
	var base := {
		"id": "b%d" % (bases.size() + 1),
		"city": city_key,
		"faction": faction,
		"troops": maxi(1, troops),
		"tier": clampi(tier, 1, 3),
	}
	if type != "":
		base["type"] = type
	if boss:
		base["boss"] = true
	bases.append(base)

## Un frente intermedio siempre enseña fábricas o fortalezas; el tercero combina
## la regla de la región con el jefe. Evita que las tres batallas se sientan iguales.
static func _mark_special_base(bases: Array[Dictionary], region: Dictionary) -> void:
	var rule := str(region["rule"])
	var special := rule if rule in ["factory", "fortress"] else ("factory" if int(region["tier"]) % 2 == 0 else "fortress")
	for base in bases:
		if base["faction"] != GameManager.Faction.NEUTRAL:
			continue
		base["type"] = special
		if special == "fortress":
			base["troops"] = clampi(int(base["troops"]), 10, 14)
		return
