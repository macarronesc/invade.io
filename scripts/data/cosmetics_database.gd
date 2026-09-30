extends RefCounted
class_name CosmeticsDatabase

## CosmeticsDatabase: estética del ejército y del mapa. Sólo cambia el aspecto, nunca el combate.
## Cada objeto: {id, category, cost, name_es, name_en} + su valor ("color", "bg"/"land").
## Los premios no se compran: "rank" se gana al subir de rango y "continent" al conquistar
## ese continente (su jefe), para que cada hito deje algo propio y visible.

const CATEGORIES := ["army_color", "troop_style", "base_shape", "map_theme"]

const ITEMS: Array[Dictionary] = [
	{"id": "color_blue", "category": "army_color", "cost": 0, "color": Color(0.13, 0.59, 0.95), "name_es": "Azul táctico", "name_en": "Tactical blue"},
	{"id": "color_cyan", "category": "army_color", "cost": 0, "rank": 2, "color": Color(0.10, 0.75, 0.85), "name_es": "Cian veloz", "name_en": "Swift cyan"},
	{"id": "color_violet", "category": "army_color", "cost": 300, "color": Color(0.55, 0.35, 0.95), "name_es": "Violeta", "name_en": "Violet"},
	{"id": "color_orange", "category": "army_color", "cost": 300, "color": Color(1.0, 0.55, 0.10), "name_es": "Naranja", "name_en": "Orange"},
	{"id": "color_pink", "category": "army_color", "cost": 400, "color": Color(1.0, 0.35, 0.65), "name_es": "Rosa neón", "name_en": "Neon pink"},
	{"id": "color_mint", "category": "army_color", "cost": 0, "continent": "oceania", "color": Color(0.20, 0.85, 0.62), "name_es": "Menta austral", "name_en": "Austral mint"},
	{"id": "color_gold", "category": "army_color", "cost": 0, "rank": 8, "color": Color(0.95, 0.75, 0.10), "name_es": "Oro", "name_en": "Gold"},
	{"id": "troop_classic", "category": "troop_style", "cost": 0, "name_es": "Clásicas", "name_en": "Classic"},
	{"id": "troop_big", "category": "troop_style", "cost": 250, "name_es": "Grandes", "name_en": "Big"},
	{"id": "troop_halo", "category": "troop_style", "cost": 0, "rank": 4, "name_es": "Halo", "name_en": "Halo"},
	{"id": "base_round", "category": "base_shape", "cost": 0, "name_es": "Redonda", "name_en": "Round"},
	{"id": "base_square", "category": "base_shape", "cost": 200, "name_es": "Cuadrada", "name_en": "Square"},
	{"id": "base_diamond", "category": "base_shape", "cost": 0, "rank": 6, "name_es": "Diamante", "name_en": "Diamond"},
	{"id": "theme_midnight", "category": "map_theme", "cost": 0, "bg": Color(0.07, 0.11, 0.16), "land": Color(0.19, 0.22, 0.26), "name_es": "Medianoche", "name_en": "Midnight"},
	{"id": "theme_ocean", "category": "map_theme", "cost": 0, "continent": "europe", "bg": Color(0.03, 0.13, 0.25), "land": Color(0.10, 0.25, 0.38), "name_es": "Océano", "name_en": "Ocean"},
	{"id": "theme_paper", "category": "map_theme", "cost": 0, "continent": "north_america", "bg": Color(0.80, 0.84, 0.89), "land": Color(0.93, 0.94, 0.96), "name_es": "Papel", "name_en": "Paper"},
	{"id": "theme_forest", "category": "map_theme", "cost": 0, "continent": "south_america", "bg": Color(0.04, 0.10, 0.08), "land": Color(0.12, 0.22, 0.16), "name_es": "Selva", "name_en": "Jungle"},
	{"id": "theme_sand", "category": "map_theme", "cost": 0, "continent": "africa", "bg": Color(0.16, 0.14, 0.10), "land": Color(0.32, 0.28, 0.18), "name_es": "Arena", "name_en": "Sand"},
	{"id": "theme_dusk", "category": "map_theme", "cost": 0, "continent": "asia", "bg": Color(0.09, 0.06, 0.14), "land": Color(0.20, 0.15, 0.27), "name_es": "Crepúsculo", "name_en": "Dusk"},
]

static func get_by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}

static func items_of(category: String) -> Array[Dictionary]:
	return ITEMS.filter(func(item): return item["category"] == category)

## Premios de un hito: rango alcanzado o continente conquistado
static func is_reward(item: Dictionary) -> bool:
	return item.has("rank") or item.has("continent")

## Premios que concede alcanzar el rango `level`
static func rank_rewards(level: int) -> Array[Dictionary]:
	return ITEMS.filter(func(item): return int(item.get("rank", -1)) == level)

static func continent_reward(continent_id: String) -> Dictionary:
	for item in ITEMS:
		if item.get("continent", "") == continent_id:
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
	return LocaleStrings.text("unlock_continent") % LevelDatabase.continent_name(item.get("continent", ""))

## Nombre en el idioma actual
static func item_name(item: Dictionary) -> String:
	return item["name_en"] if LocaleStrings.lang == "en" else item["name_es"]
