extends RefCounted
class_name NextGoal

## El siguiente objetivo cercano, en una sola frase, para cerrar cada batalla (y el menú) con
## algo concreto que perseguir. Se elige el primero que aplique, de más a menos inmediato.

## Oro que puede faltar para seguir sugiriendo una mejora (fracción de su precio)
const NEAR_UPGRADE := 0.6

static func text() -> String:
	if GameManager.should_suggest_first_upgrade():
		return _upgrade()
	for goal in [_boss, _mission, _upgrade, _collection, _rank]:
		var candidate: String = goal.call()
		if candidate != "":
			return candidate
	return ""

static func _upgrade() -> String:
	if DailyRewards.is_challenge(GameManager.get_battle_level_id()):
		return ""
	var id := GameManager.recommended_combat_upgrade(GameManager.can_suggest_combat_upgrade())
	if id == "":
		return ""
	var cost := GameManager.get_upgrade_cost(id)
	var name := LocaleStrings.text("upg_" + id)
	if GameManager.should_suggest_first_upgrade():
		return LocaleStrings.text("goal_first_upgrade") % name
	if GameManager.coins >= cost:
		return LocaleStrings.text("goal_upgrade_ready") % name
	if GameManager.coins >= cost * NEAR_UPGRADE:
		return LocaleStrings.text("goal_upgrade_near") % [cost - GameManager.coins, name]
	return ""

## La misión de hoy empezada y más cerca de completarse
static func _mission() -> String:
	GameManager.ensure_missions()
	var best: Dictionary = {}
	var best_ratio := 0.0
	for m in GameManager.mission_definitions(int(GameManager.missions["day"])):
		var progress := int(GameManager.missions["progress"].get(m["id"], 0))
		var ratio := progress / float(m["goal"])
		if ratio > best_ratio and ratio < 1.0:
			best = m
			best_ratio = ratio
	if best.is_empty():
		return ""
	var progress := int(GameManager.missions["progress"].get(best["id"], 0))
	return LocaleStrings.text("goal_mission") % [LocaleStrings.text(best["key"]) % best["goal"], progress, best["goal"]]

## El jefe del continente es el siguiente nivel de la campaña: anticipar su premio
static func _boss() -> String:
	var id := GameManager.current_level_id
	if GameManager.completed_levels.has(id) or LevelDatabase.get_level_number(id) != LevelDatabase.LEVELS_PER_CONTINENT:
		return ""
	var continent := LevelDatabase.get_continent_of(id)
	var reward := CosmeticsDatabase.continent_reward(continent)
	return LocaleStrings.text("goal_boss") % [LevelDatabase.continent_name(continent), CosmeticsDatabase.item_name(reward)]

static func _rank() -> String:
	var level := GameManager.player_level()
	var reward := CosmeticsDatabase.next_rank_reward(level)
	if reward.is_empty():
		return ""
	var missing := PlayerRank.level_start(int(reward["rank"])) - GameManager.experience
	return LocaleStrings.text("goal_rank") % [int(reward["rank"]), CosmeticsDatabase.item_name(reward), missing]

static func _collection() -> String:
	for c in LevelDatabase.get_continents():
		var total := LevelDatabase.collection_cities(c["id"]).size()
		var have := GameManager.collection_progress(c["id"])
		if have > 0 and have < total:
			return LocaleStrings.text("goal_collection") % [LevelDatabase.continent_name(c["id"]), have, total]
	return ""
