extends RefCounted
class_name CampaignRules

## Reglas de continente sobre una copia del nivel construido. La campaña usa la de su
## continente (salvo los tutoriales) y el desafío diario rota por las seis según el día,
## para que cada día tenga una particularidad. Las expediciones también rotan esas reglas.
static func apply(level: Dictionary) -> void:
	var id: String = level.get("id", "")
	var continent := ""
	if DailyRewards.is_challenge(id):
		var continents := LevelDatabase.get_continents()
		continent = continents[posmod(DailyRewards.challenge_day(id), continents.size())]["id"]
	elif LevelGenerator.is_conquest(id):
		var continents := LevelDatabase.get_continents()
		var index := LevelGenerator.conquest_index(id)
		continent = continents[posmod(index + LevelGenerator.expedition_of(index) - 1, continents.size())]["id"]
	elif LevelDatabase.get_level_ids().has(id) and id not in ["europe_1", "europe_2", "europe_3"]:
		continent = LevelDatabase.get_continent_of(id)
	if continent == "":
		return
	var bases: Array = level["bases"]
	level["rule_key"] = "rule_" + continent
	match continent:
		"europe", "africa":
			var capital: Dictionary = bases[mini(1 if continent == "europe" else 2, bases.size() - 1)]
			if continent == "africa" and LevelDatabase.get_level_ids().has(id):
				for base in bases:
					if base["faction"] == GameManager.Faction.NEUTRAL:
						capital = base
						break
			capital["capital"] = true
			capital["production_bonus"] = 1.5 if continent == "europe" else 1.75
		"north_america", "asia":
			for base in bases:
				if base["faction"] == GameManager.Faction.NEUTRAL:
					base["type"] = "factory" if continent == "north_america" else "fortress"
					if continent == "asia" and LevelDatabase.get_level_ids().has(id):
						base["troops"] = mini(int(base["troops"]), 14)
					break
		"south_america":
			level["travel_multiplier"] = 0.8
		"oceania":
			level["sea_lanes"] = sea_lanes(bases)
	if DailyRewards.is_challenge(id):
		if continent in ["europe", "africa"]:
			level["objective"] = "hold_capital"
			level["hold_seconds"] = 12.0
		elif continent == "north_america":
			level["objective"] = "hold_factories"
			level["hold_seconds"] = 8.0
		elif continent == "asia":
			level["objective"] = "hold_fortresses"
			level["hold_seconds"] = 8.0
	if LevelDatabase.get_level_ids().has(id) and LevelDatabase.get_level_number(id) == LevelDatabase.LEVELS_PER_CONTINENT:
		for base in bases:
			if base["faction"] == GameManager.Faction.ENEMY_1:
				base.merge({"boss": true, "type": "fortress", "tier": 3}, true)
				level["target_time"] += 25
				break
	if bases.any(func(base): return base.get("boss", false)):
		var balance := LevelDatabase.get_balance(id)
		level["boss_interval"] = balance["boss_interval"]
		level["boss_reinforcement"] = balance["boss_reinforcement"]

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
		text += "\n" + LocaleStrings.text("boss_rule") % [level.get("boss_reinforcement", 10), roundi(level.get("boss_interval", 18.0))]
	return text
