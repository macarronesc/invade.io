extends RefCounted
class_name CosmeticsDatabase

## Cosmetics change appearance, never combat. Display names live in locale/strings.csv.
## Rewards are earned by rank, campaign continent or invasion continent, never sold.

const CATEGORIES := ["army_color", "troop_style", "base_shape", "map_theme"]

## Light maps need dark labels and borders to keep their contrast over the land.
const MAP_DARK_STYLE := {
	"border_color": Color(1, 1, 1, 0.40), "coast_color": Color(0.45, 0.62, 0.75, 0.35),
	"country_border_color": Color(1, 1, 1, 0.10), "label_color": Color(0.92, 0.95, 0.98, 0.9),
	"label_outline": Color(0, 0, 0, 0.9), "territory_alpha": 0.30, "neutral_alpha": 0.14,
}
const MAP_LIGHT_STYLE := {
	"border_color": Color(0.06, 0.15, 0.22, 0.55), "coast_color": Color(0.20, 0.38, 0.52, 0.60),
	"country_border_color": Color(0.08, 0.15, 0.22, 0.11), "label_color": Color(0.05, 0.14, 0.21, 0.94),
	"label_outline": Color(0.97, 0.99, 1.0, 0.92), "territory_alpha": 0.34, "neutral_alpha": 0.18,
}

const ITEMS: Array[Dictionary] = [
	{"id": "color_blue", "category": "army_color", "cost": 0, "color": Color(0.13, 0.59, 0.95)},
	{"id": "color_cyan", "category": "army_color", "cost": 0, "rank": 2, "color": Color(0.10, 0.75, 0.85)},
	{"id": "color_violet", "category": "army_color", "cost": 300, "color": Color(0.55, 0.35, 0.95)},
	{"id": "color_orange", "category": "army_color", "cost": 300, "color": Color(1.0, 0.55, 0.10)},
	{"id": "color_pink", "category": "army_color", "cost": 400, "color": Color(1.0, 0.35, 0.65)},
	{"id": "color_mint", "category": "army_color", "cost": 0, "continent": "oceania", "color": Color(0.20, 0.85, 0.62)},
	{"id": "color_gold", "category": "army_color", "cost": 0, "rank": 8, "color": Color(0.95, 0.75, 0.10)},
	{"id": "troop_classic", "category": "troop_style", "cost": 0},
	{"id": "troop_big", "category": "troop_style", "cost": 250},
	{"id": "troop_halo", "category": "troop_style", "cost": 0, "rank": 4},
	{"id": "base_round", "category": "base_shape", "cost": 0},
	{"id": "base_square", "category": "base_shape", "cost": 200},
	{"id": "base_diamond", "category": "base_shape", "cost": 0, "rank": 6},
	{"id": "theme_daylight", "category": "map_theme", "cost": 0, "light": true, "bg": Color(0.72, 0.83, 0.91), "land": Color(0.64, 0.73, 0.80)},
	{"id": "theme_midnight", "category": "map_theme", "cost": 0, "bg": Color(0.07, 0.11, 0.16), "land": Color(0.19, 0.22, 0.26)},
	{"id": "theme_ocean", "category": "map_theme", "cost": 0, "continent": "europe", "bg": Color(0.03, 0.13, 0.25), "land": Color(0.10, 0.25, 0.38)},
	{"id": "theme_paper", "category": "map_theme", "cost": 0, "light": true, "continent": "north_america", "bg": Color(0.80, 0.84, 0.89), "land": Color(0.93, 0.94, 0.96)},
	{"id": "theme_forest", "category": "map_theme", "cost": 0, "continent": "south_america", "bg": Color(0.04, 0.10, 0.08), "land": Color(0.12, 0.22, 0.16)},
	{"id": "theme_sand", "category": "map_theme", "cost": 0, "continent": "africa", "bg": Color(0.16, 0.14, 0.10), "land": Color(0.32, 0.28, 0.18)},
	{"id": "theme_dusk", "category": "map_theme", "cost": 0, "continent": "asia", "bg": Color(0.09, 0.06, 0.14), "land": Color(0.20, 0.15, 0.27)},
	{"id": "color_invasion_europe", "category": "army_color", "cost": 0, "invasion": "europe", "color": Color(0.85, 0.45, 0.25)},
	{"id": "color_invasion_north_america", "category": "army_color", "cost": 0, "invasion": "north_america", "color": Color(0.35, 0.75, 0.95)},
	{"id": "color_invasion_south_america", "category": "army_color", "cost": 0, "invasion": "south_america", "color": Color(0.15, 0.75, 0.45)},
	{"id": "color_invasion_africa", "category": "army_color", "cost": 0, "invasion": "africa", "color": Color(0.95, 0.65, 0.15)},
	{"id": "color_invasion_asia", "category": "army_color", "cost": 0, "invasion": "asia", "color": Color(0.85, 0.20, 0.25)},
	{"id": "color_invasion_oceania", "category": "army_color", "cost": 0, "invasion": "oceania", "color": Color(0.10, 0.80, 0.75)},
]

static func get_by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}

## Tema de mapa con sus colores de campo completos (texto, costa y fronteras incluidos).
static func get_map_theme(id: String) -> Dictionary:
	var item := get_by_id(id)
	if item.is_empty():
		return {}
	var theme := item.duplicate(true)
	theme.merge(MAP_LIGHT_STYLE if item.get("light", false) else MAP_DARK_STYLE)
	return theme

static func items_of(category: String) -> Array[Dictionary]:
	return ITEMS.filter(func(item): return item["category"] == category)

## Premios de un hito: rango, continente conquistado o todas sus invasiones
static func is_reward(item: Dictionary) -> bool:
	return item.has("rank") or item.has("continent") or item.has("invasion")

## Premios que concede alcanzar el rango `level`
static func rank_rewards(level: int) -> Array[Dictionary]:
	return ITEMS.filter(func(item): return int(item.get("rank", -1)) == level)

static func continent_reward(continent_id: String) -> Dictionary:
	for item in ITEMS:
		if item.get("continent", "") == continent_id:
			return item
	return {}

static func invasion_reward(continent_id: String) -> Dictionary:
	for item in ITEMS:
		if item.get("invasion", "") == continent_id:
			return item
	return {}

## Primer premio de rango por encima de `level` (vacío si ya no quedan)
static func next_rank_reward(level: int) -> Dictionary:
	var best: Dictionary = {}
	for item in ITEMS:
		var r := int(item.get("rank", -1))
		if r > level and (best.is_empty() or r < int(best["rank"])):
			best = item
	return best

## Cómo se consigue un premio, p. ej. "Rango 4" o "Conquista Asia"
static func unlock_text(item: Dictionary) -> String:
	if item.has("rank"):
		return LocaleStrings.text("unlock_rank") % int(item["rank"])
	if item.has("invasion"):
		return LocaleStrings.text("unlock_invasion") % LevelDatabase.continent_name(item["invasion"])
	return LocaleStrings.text("unlock_continent") % LevelDatabase.continent_name(item.get("continent", ""))

## Nombre en el idioma actual
static func item_name(item: Dictionary) -> String:
	return LocaleStrings.text("cosmetic_%s" % item["id"])
