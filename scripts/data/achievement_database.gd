extends RefCounted
class_name AchievementDatabase

## AchievementDatabase: definición de los logros.
## Cada logro se cumple cuando la estadística `stat` alcanza `goal` (ver AchievementManager.get_stat).
## La recompensa en oro se reclama a mano desde la pantalla de logros.

const BLITZ_SECONDS := 30.0

const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_victory", "icon": "🏆", "title": "Primera conquista", "desc": "Gana tu primera batalla", "stat": "victories", "goal": 1, "reward": 50},
	{"id": "veteran", "icon": "⚔️", "title": "Veterano", "desc": "Gana 25 batallas", "stat": "victories", "goal": 25, "reward": 200},
	{"id": "conqueror", "icon": "🏰", "title": "Conquistador", "desc": "Captura 50 territorios", "stat": "bases_captured", "goal": 50, "reward": 100},
	{"id": "emperor", "icon": "👑", "title": "Emperador", "desc": "Captura 500 territorios", "stat": "bases_captured", "goal": 500, "reward": 400},
	{"id": "strategist", "icon": "⭐", "title": "Estratega", "desc": "Consigue 3 estrellas en 10 niveles", "stat": "three_star_levels", "goal": 10, "reward": 200},
	{"id": "continental", "icon": "🗺️", "title": "Dominio continental", "desc": "Completa todos los niveles de un continente", "stat": "continents_completed", "goal": 1, "reward": 150},
	{"id": "world", "icon": "🌍", "title": "Conquista mundial", "desc": "Completa los 30 niveles de la campaña", "stat": "levels_completed", "goal": 30, "reward": 500},
	{"id": "coordination", "icon": "🔥", "title": "Ofensiva total", "desc": "Ataca desde 3 bases en un mismo trazo", "stat": "chain_max", "goal": 3, "reward": 75},
	{"id": "tactical_retreat", "icon": "🛡️", "title": "Retirada táctica", "desc": "Ordena 10 retiradas cortando tus tropas", "stat": "retreats", "goal": 10, "reward": 75},
	{"id": "blitz", "icon": "🚀", "title": "Guerra relámpago", "desc": "Gana una batalla en menos de 30 segundos", "stat": "fast_victories", "goal": 1, "reward": 100},
	{"id": "flawless", "icon": "💎", "title": "Sin bajas", "desc": "Gana sin perder ningún territorio", "stat": "flawless_victories", "goal": 1, "reward": 100},
	{"id": "big_army", "icon": "💪", "title": "Gran ejército", "desc": "Lanza 100 tropas en una sola hilera", "stat": "biggest_stream", "goal": 100, "reward": 100},
	{"id": "tech", "icon": "🧠", "title": "Tecnología punta", "desc": "Lleva una mejora a su nivel máximo", "stat": "max_upgrade_level", "goal": 10, "reward": 150},
	{"id": "streak", "icon": "📅", "title": "Constancia", "desc": "Recoge la recompensa diaria 7 días seguidos", "stat": "daily_streak", "goal": 7, "reward": 200},
	{"id": "daily_challenger", "icon": "🎯", "title": "Desafío superado", "desc": "Completa un desafío diario", "stat": "daily_challenges", "goal": 1, "reward": 100},
]

static func get_all() -> Array[Dictionary]:
	return ACHIEVEMENTS

static func get_by_id(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}
