extends RefCounted
class_name Ascension

## Ascension: the 30 campaign maps replayed at a higher tier ("asc<tier>_<campaign id>").
## Tier 1 is the plain campaign. Tiers 2..MAX_TIER keep the maps, cities and geography and
## raise only the threat: stronger garrisons, faster AI, extra rival armies and a second
## continent rule. Every tier is a derived overlay on the cached campaign level, so it
## costs no extra geography and no saved state besides the stars.

const PREFIX := "asc"
const MIN_TIER := 2
const MAX_TIER := 10
## Gold bonus per tier above 1, and extra enemy garrison per tier above 1
const GOLD_PER_TIER := 0.35
const TROOPS_PER_TIER := 0.15
## Neutral garrisons grow by this share of the rivals' growth: expanding gets costlier too
const NEUTRAL_SHARE := 0.5
## Threat of the first ascension tier and growth per tier; the level's position adds up to LEVEL_SPAN
const FIRST_THREAT := 2.0
const TIER_SPAN := 0.5
const LEVEL_SPAN := 0.4
## Rival armies recruited from neutral bases: one at tier 2, two from tier 3
const MAX_RECRUITS := 2
const SECOND_RULE_TIER := 3
## Oceania's sea lanes need canonical positions, so only the other five rules can be stacked
const RULE_POOL := ["europe", "north_america", "south_america", "africa", "asia"]

static func level_id(tier: int, base_id: String) -> String:
	return "%s%d_%s" % [PREFIX, tier, base_id]

## {"tier", "base"} for a valid ascension id, {} otherwise
static func parse(id: String) -> Dictionary:
	if not id.begins_with(PREFIX):
		return {}
	var split := id.find("_")
	if split <= PREFIX.length():
		return {}
	var digits := id.substr(PREFIX.length(), split - PREFIX.length())
	var tier := int(digits)
	var base := id.substr(split + 1)
	if not digits.is_valid_int() or str(tier) != digits or tier < MIN_TIER or tier > MAX_TIER:
		return {}
	if not LevelDatabase.get_level_ids().has(base):
		return {}
	return {"tier": tier, "base": base}

static func is_ascension(id: String) -> bool:
	return not parse(id).is_empty()

## Campaign id behind an ascension id; any other id is returned unchanged
static func base_of(id: String) -> String:
	return str(parse(id).get("base", id))

static func tier_of(id: String) -> int:
	return int(parse(id).get("tier", 1))

static func tier_level_ids(tier: int) -> Array[String]:
	var ids: Array[String] = []
	for base in LevelDatabase.get_level_ids():
		ids.append(level_id(tier, base))
	return ids

static func gold_scale(tier: int) -> float:
	return 1.0 + GOLD_PER_TIER * (tier - 1)

## Three-star time relative to the campaign level: tighter every tier, since players arrive stronger
static func time_scale(tier: int) -> float:
	return clampf(0.75 - 0.05 * (tier - MIN_TIER), 0.4, 0.75)

static func threat(tier: int, base_id: String) -> float:
	return FIRST_THREAT + TIER_SPAN * (tier - MIN_TIER) + LEVEL_SPAN * LevelDatabase.get_difficulty(base_id)

## The playable level: the cached campaign map with this tier's threat applied to a copy.
static func build(id: String, landscape: bool) -> Dictionary:
	var parsed := parse(id)
	var tier: int = parsed["tier"]
	var level: Dictionary = LevelDatabase.get_level_data(parsed["base"], landscape).duplicate()
	var level_threat := threat(tier, parsed["base"])
	var bases: Array = level["bases"].duplicate(true)
	var multiplier := Threat.troops(level_threat) * (1.0 + TROOPS_PER_TIER * (tier - 1))
	for base in bases:
		if base["faction"] == GameManager.Faction.NEUTRAL:
			_scale_troops(base, 1.0 + (multiplier - 1.0) * NEUTRAL_SHARE)
		elif base["faction"] > GameManager.Faction.PLAYER:
			_scale_troops(base, multiplier)
	_recruit_rivals(bases, mini(tier - 1, MAX_RECRUITS), multiplier)
	level["bases"] = bases
	level["id"] = id
	level["tier"] = tier
	level["target_time"] = roundi(level["target_time"] * time_scale(tier))
	level["name"] = LocaleStrings.text("asc_level_name") % [level["name"], tier]
	if tier >= SECOND_RULE_TIER:
		_stack_rule(level, parsed["base"], tier)
	if bases.any(func(b): return b.get("boss", false)):
		var balance := LevelDatabase.get_balance(id)
		level["boss_interval"] = balance["boss_interval"]
		level["boss_reinforcement"] = balance["boss_reinforcement"]
	return level

static func _scale_troops(base: Dictionary, multiplier: float) -> void:
	var capacity: int = BaseNode.TIER_PARAMS.get(base.get("tier", 1), BaseNode.DEFAULT_TIER_PARAMS)["capacity"]
	base["troops"] = mini(roundi(base["troops"] * multiplier), capacity)

## Turns the strongest neutral bases into rivals of unused factions, always leaving one neutral.
## Chosen by order and garrison only, so portrait and landscape boards stay identical in content.
static func _recruit_rivals(bases: Array, count: int, multiplier: float) -> void:
	var used := {}
	for base in bases:
		used[base["faction"]] = true
	for faction in [GameManager.Faction.ENEMY_1, GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]:
		if count <= 0:
			return
		if used.has(faction):
			continue
		var pick := -1
		var neutrals := 0
		for i in bases.size():
			if bases[i]["faction"] != GameManager.Faction.NEUTRAL:
				continue
			neutrals += 1
			if pick < 0 or bases[i]["troops"] >= bases[pick]["troops"]:
				pick = i
		if neutrals < 2:
			return
		bases[pick]["faction"] = faction
		bases[pick]["troops"] = maxi(bases[pick]["troops"], 18)
		_scale_troops(bases[pick], multiplier)
		count -= 1

static func _stack_rule(level: Dictionary, base_id: String, tier: int) -> void:
	var own := LevelDatabase.get_continent_of(base_id)
	var index := (LevelDatabase.get_continents().map(func(c): return c["id"]).find(own) + tier) % RULE_POOL.size()
	if RULE_POOL[index] == own:
		index = (index + 1) % RULE_POOL.size()
	level["rule_key_2"] = "rule_" + RULE_POOL[index]
	CampaignRules.apply_continent(level, RULE_POOL[index], "")
