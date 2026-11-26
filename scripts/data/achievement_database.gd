extends RefCounted
class_name AchievementDatabase

## AchievementDatabase: definición de los logros.
## Cada logro se cumple cuando la estadística `stat` alcanza `goal` (ver AchievementManager.get_stat).
## La recompensa en oro se reclama a mano desde la pantalla de logros.
## Un logro con `"hidden": true` oculta su título y descripción (sólo una pista) hasta desbloquearse.

const BLITZ_SECONDS := 30.0

const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_victory", "icon": "🏆", "stat": "victories", "goal": 1, "reward": 50},
	{"id": "veteran", "icon": "⚔️", "stat": "victories", "goal": 25, "reward": 200},
	{"id": "conqueror", "icon": "🏰", "stat": "bases_captured", "goal": 50, "reward": 100},
	{"id": "emperor", "icon": "🥇", "stat": "bases_captured", "goal": 500, "reward": 400},
	{"id": "strategist", "icon": "⭐", "stat": "three_star_levels", "goal": 10, "reward": 200},
	{"id": "continental", "icon": "🌐", "stat": "continents_completed", "goal": 1, "reward": 150},
	{"id": "world", "icon": "🌍", "stat": "levels_completed", "goal": 30, "reward": 500},
	{"id": "coordination", "icon": "🔥", "stat": "chain_max", "goal": 3, "reward": 75},
	{"id": "tactical_retreat", "icon": "🛡️", "stat": "retreats", "goal": 10, "reward": 75},
	{"id": "blitz", "icon": "🚀", "stat": "fast_victories", "goal": 1, "reward": 100},
	{"id": "flawless", "icon": "💎", "stat": "flawless_victories", "goal": 1, "reward": 100},
	{"id": "big_army", "icon": "💪", "stat": "biggest_stream", "goal": 100, "reward": 100},
	{"id": "tech", "icon": "🧠", "stat": "max_upgrade_level", "goal": 10, "reward": 150},
	{"id": "streak", "icon": "📅", "stat": "daily_streak", "goal": 7, "reward": 200},
	{"id": "daily_challenger", "icon": "🎯", "stat": "daily_challenges", "goal": 1, "reward": 100},
	{"id": "first_invasion", "icon": "🗡️", "stat": "invasion_regions", "goal": 1, "reward": 100},
	{"id": "explorer", "icon": "👟", "stat": "invasion_regions", "goal": 5, "reward": 200},
	{"id": "cartographer", "icon": "🗺️", "stat": "invasion_regions", "goal": 15, "reward": 350},
	{"id": "world_invader", "icon": "🌊", "stat": "invasion_regions", "goal": 36, "reward": 750},
	{"id": "regional_master", "icon": "🎁", "stat": "invasion_mastery", "goal": 1, "reward": 150},
	{"id": "ascended", "icon": "⚡", "stat": "ascension_tiers", "goal": 1, "reward": 300},
	{"id": "ascended_4", "icon": "💥", "stat": "ascension_tiers", "goal": 4, "reward": 600},
	{"id": "ascended_max", "icon": "👑", "stat": "ascension_tiers", "goal": 9, "reward": 1000, "hidden": true},
	{"id": "perfect_promotion", "icon": "✨", "stat": "perfect_ascension_tiers", "goal": 1, "reward": 1000, "hidden": true},
	{"id": "perfectionist", "icon": "🏅", "stat": "medals", "goal": 30, "reward": 600, "hidden": true},
	{"id": "devoted", "icon": "⏳", "stat": "daily_streak", "goal": 30, "reward": 500, "hidden": true},
	{"id": "untouchable_ascension", "icon": "🔒", "stat": "flawless_ascensions", "goal": 5, "reward": 500, "hidden": true},
	{"id": "last_stand", "icon": "⚠️", "stat": "last_stand_wins", "goal": 1, "reward": 300, "hidden": true},
]

static func achievement_title(a: Dictionary) -> String:
	return LocaleStrings.text("ach_%s_title" % a["id"])

static func achievement_desc(a: Dictionary) -> String:
	return LocaleStrings.text("ach_%s_desc" % a["id"])

static func achievement_hint(a: Dictionary) -> String:
	return LocaleStrings.text("ach_%s_hint" % a["id"])

static func is_hidden(a: Dictionary) -> bool:
	return a.get("hidden", false)

static func get_all() -> Array[Dictionary]:
	return ACHIEVEMENTS

static func get_by_id(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}
