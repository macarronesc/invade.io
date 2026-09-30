extends RefCounted
class_name DailyMissions

## Tres objetivos deterministas por día; sin servidor ni reloj durante la batalla.
## Mezclan objetivos de volumen (ganar, capturar) con otros que invitan a jugar distinto.
const POOL: Array[Dictionary] = [
	{"id": "captures", "goal": 20, "gold": 80, "xp": 40, "key": "mission_captures"},
	{"id": "chain", "goal": 2, "gold": 90, "xp": 50, "key": "mission_chain"},
	{"id": "wins", "goal": 3, "gold": 100, "xp": 60, "key": "mission_wins"},
	{"id": "special", "goal": 2, "gold": 90, "xp": 50, "key": "mission_special"},
	{"id": "flawless", "goal": 1, "gold": 90, "xp": 50, "key": "mission_flawless"},
	{"id": "retreat", "goal": 1, "gold": 70, "xp": 40, "key": "mission_retreat"},
	{"id": "stars", "goal": 6, "gold": 100, "xp": 60, "key": "mission_stars"},
	{"id": "daily", "goal": 1, "gold": 120, "xp": 60, "key": "mission_daily"},
]

const LEGACY_IDS := ["captures", "wins", "flawless", "stars", "daily"]

static func for_day(day: int, legacy: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in 3:
		if legacy:
			result.append(for_ids([LEGACY_IDS[posmod(day + i, LEGACY_IDS.size())]])[0])
		else:
			result.append(POOL[posmod(day * 3 + i, POOL.size())])
	return result

## Sólo acepta ids conocidos; los importes y objetivos siempre vienen de nuestros datos.
static func for_ids(ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ids:
		for mission in POOL:
			if mission["id"] == id and not result.has(mission):
				result.append(mission)
	return result
