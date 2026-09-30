extends RefCounted
class_name CampaignRules

## Reglas de campaña sobre una copia del nivel construido; diario y conquista no cambian.
static func apply(level: Dictionary) -> void:
	var id: String = level.get("id", "")
	if not LevelDatabase.get_level_ids().has(id) or id in ["europe_1", "europe_2", "europe_3"]:
		return
	var continent := LevelDatabase.get_continent_of(id)
	var bases: Array = level["bases"]
	level["rule_key"] = "rule_" + continent
	match continent:
		"europe", "africa":
			var capital: Dictionary = bases[1] if continent == "europe" else bases[2]
			capital["capital"] = true
			capital["production_bonus"] = 1.5 if continent == "europe" else 1.75
		"north_america", "asia":
			for base in bases:
				if base["faction"] == GameManager.Faction.NEUTRAL:
					base["type"] = "factory" if continent == "north_america" else "fortress"
					break
		"south_america":
			level["travel_multiplier"] = 0.8
		"oceania":
			level["sea_lanes"] = sea_lanes(bases)
	if LevelDatabase.get_level_number(id) == LevelDatabase.LEVELS_PER_CONTINENT:
		for base in bases:
			if base["faction"] == GameManager.Faction.ENEMY_1:
				base.merge({"boss": true, "type": "fortress", "tier": 3, "troops": int(base["troops"]) + 25}, true)
				level["target_time"] += 25
				break

## ponytail: árbol de rutas O(n³), n≤16; Prim con heap si se añaden mapas masivos.
## Siempre conectado: ninguna isla ni facción queda aislada.
static func sea_lanes(bases: Array) -> Array[Vector2i]:
	var routes: Array[Vector2i] = []
	if bases.is_empty():
		return routes
	var reached := [0]
	while reached.size() < bases.size():
		var best := Vector2i(-1, -1)
		var distance := INF
		for i in reached:
			for j in bases.size():
				if reached.has(j):
					continue
				var d: float = bases[i]["pos"].distance_squared_to(bases[j]["pos"])
				if d < distance:
					distance = d
					best = Vector2i(i, j)
		routes.append(best)
		reached.append(best.y)
	return routes

static func description(level: Dictionary) -> String:
	var text := LocaleStrings.text(level["rule_key"]) if level.has("rule_key") else ""
	if level.get("bases", []).any(func(base): return base.get("boss", false)):
		text += "\n" + LocaleStrings.text("boss_rule")
	return text
