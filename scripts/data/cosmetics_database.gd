extends RefCounted
class_name CosmeticsDatabase

## CosmeticsDatabase: tienda de estética (punto 5). Da un destino permanente al oro
## cuando las 4 mejoras ya están al máximo: colores, estelas, formas de base y temas.
## Cada objeto: {id, category, cost, name_es, name_en} + su valor ("color", "bg"/"land").

const CATEGORIES := ["army_color", "troop_style", "base_shape", "map_theme"]

const ITEMS: Array[Dictionary] = [
	{"id": "color_blue", "category": "army_color", "cost": 0, "color": Color(0.13, 0.59, 0.95), "name_es": "Azul táctico", "name_en": "Tactical blue"},
	{"id": "color_cyan", "category": "army_color", "cost": 250, "color": Color(0.10, 0.75, 0.85), "name_es": "Cian veloz", "name_en": "Swift cyan"},
	{"id": "color_violet", "category": "army_color", "cost": 300, "color": Color(0.55, 0.35, 0.95), "name_es": "Violeta", "name_en": "Violet"},
	{"id": "color_orange", "category": "army_color", "cost": 300, "color": Color(1.0, 0.55, 0.10), "name_es": "Naranja", "name_en": "Orange"},
	{"id": "color_pink", "category": "army_color", "cost": 400, "color": Color(1.0, 0.35, 0.65), "name_es": "Rosa neón", "name_en": "Neon pink"},
	{"id": "color_gold", "category": "army_color", "cost": 500, "color": Color(0.95, 0.75, 0.10), "name_es": "Oro", "name_en": "Gold"},
	{"id": "troop_classic", "category": "troop_style", "cost": 0, "name_es": "Clásicas", "name_en": "Classic"},
	{"id": "troop_big", "category": "troop_style", "cost": 250, "name_es": "Maxi-perlas", "name_en": "Big beads"},
	{"id": "troop_halo", "category": "troop_style", "cost": 350, "name_es": "Halo", "name_en": "Halo"},
	{"id": "base_round", "category": "base_shape", "cost": 0, "name_es": "Redonda", "name_en": "Round"},
	{"id": "base_square", "category": "base_shape", "cost": 200, "name_es": "Cuadrada", "name_en": "Square"},
	{"id": "base_diamond", "category": "base_shape", "cost": 300, "name_es": "Diamante", "name_en": "Diamond"},
	{"id": "theme_midnight", "category": "map_theme", "cost": 0, "bg": Color(0.07, 0.11, 0.16), "land": Color(0.19, 0.22, 0.26), "name_es": "Medianoche", "name_en": "Midnight"},
	{"id": "theme_ocean", "category": "map_theme", "cost": 300, "bg": Color(0.03, 0.13, 0.25), "land": Color(0.10, 0.25, 0.38), "name_es": "Océano", "name_en": "Ocean"},
	{"id": "theme_sand", "category": "map_theme", "cost": 400, "bg": Color(0.16, 0.14, 0.10), "land": Color(0.32, 0.28, 0.18), "name_es": "Arena", "name_en": "Sand"},
]

static func get_by_id(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}

static func items_of(category: String) -> Array[Dictionary]:
	return ITEMS.filter(func(item): return item["category"] == category)

## Nombre en el idioma actual
static func item_name(item: Dictionary) -> String:
	return item["name_en"] if LocaleStrings.lang == "en" else item["name_es"]
