extends RefCounted
class_name DailyMissions

## Tres objetivos deterministas por día; sin servidor ni reloj durante la batalla.
const POOL: Array[Dictionary] = [
	{"id": "captures", "goal": 20, "gold": 80, "xp": 40, "key": "mission_captures"},
	{"id": "wins", "goal": 3, "gold": 100, "xp": 60, "key": "mission_wins"},
	{"id": "flawless", "goal": 1, "gold": 90, "xp": 50, "key": "mission_flawless"},
	{"id": "stars", "goal": 6, "gold": 100, "xp": 60, "key": "mission_stars"},
	{"id": "daily", "goal": 1, "gold": 120, "xp": 60, "key": "mission_daily"},
]

static func for_day(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in 3:
		result.append(POOL[posmod(day + i, POOL.size())])
	return result

static func player_level(xp: int) -> int:
	return 1 + floori(sqrt(maxi(0, xp) / 100.0))

static func level_start(level: int) -> int:
	return 100 * (level - 1) * (level - 1)
