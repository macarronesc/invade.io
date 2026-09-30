extends RefCounted
class_name AchievementDatabase

## AchievementDatabase: definición de los logros.
## Cada logro se cumple cuando la estadística `stat` alcanza `goal` (ver AchievementManager.get_stat).
## La recompensa en oro se reclama a mano desde la pantalla de logros.

const BLITZ_SECONDS := 30.0

const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": "first_victory", "icon": "🏆", "title": "Primera conquista", "title_en": "First conquest", "desc": "Gana tu primera batalla", "desc_en": "Win your first battle", "stat": "victories", "goal": 1, "reward": 50},
	{"id": "veteran", "icon": "⚔️", "title": "Veterano", "title_en": "Veteran", "desc": "Gana 25 batallas", "desc_en": "Win 25 battles", "stat": "victories", "goal": 25, "reward": 200},
	{"id": "conqueror", "icon": "🏰", "title": "Conquistador", "title_en": "Conqueror", "desc": "Captura 50 territorios", "desc_en": "Capture 50 territories", "stat": "bases_captured", "goal": 50, "reward": 100},
	{"id": "emperor", "icon": "👑", "title": "Emperador", "title_en": "Emperor", "desc": "Captura 500 territorios", "desc_en": "Capture 500 territories", "stat": "bases_captured", "goal": 500, "reward": 400},
	{"id": "strategist", "icon": "⭐", "title": "Estratega", "title_en": "Strategist", "desc": "Consigue 3 estrellas en 10 niveles", "desc_en": "Earn 3 stars in 10 levels", "stat": "three_star_levels", "goal": 10, "reward": 200},
	{"id": "continental", "icon": "🗺️", "title": "Dominio continental", "title_en": "Continental domain", "desc": "Completa todos los niveles de un continente", "desc_en": "Complete every level on one continent", "stat": "continents_completed", "goal": 1, "reward": 150},
	{"id": "world", "icon": "🌍", "title": "Conquista mundial", "title_en": "World conquest", "desc": "Completa los 30 niveles de la campaña", "desc_en": "Complete all 30 campaign levels", "stat": "levels_completed", "goal": 30, "reward": 500},
	{"id": "coordination", "icon": "🔥", "title": "Ofensiva total", "title_en": "Total offensive", "desc": "Ataca desde 3 bases en un mismo trazo", "desc_en": "Attack from 3 bases in a single stroke", "stat": "chain_max", "goal": 3, "reward": 75},
	{"id": "tactical_retreat", "icon": "🛡️", "title": "Retirada táctica", "title_en": "Tactical retreat", "desc": "Ordena 10 retiradas cortando tus tropas", "desc_en": "Order 10 retreats by slicing your troops", "stat": "retreats", "goal": 10, "reward": 75},
	{"id": "blitz", "icon": "🚀", "title": "Guerra relámpago", "title_en": "Blitzkrieg", "desc": "Gana una batalla en menos de 30 segundos", "desc_en": "Win a battle in under 30 seconds", "stat": "fast_victories", "goal": 1, "reward": 100},
	{"id": "flawless", "icon": "💎", "title": "Sin bajas", "title_en": "Flawless", "desc": "Gana sin perder ningún territorio", "desc_en": "Win without losing any territory", "stat": "flawless_victories", "goal": 1, "reward": 100},
	{"id": "big_army", "icon": "💪", "title": "Gran ejército", "title_en": "Grand army", "desc": "Envía 100 tropas en una sola orden", "desc_en": "Send 100 troops in a single order", "stat": "biggest_stream", "goal": 100, "reward": 100},
	{"id": "tech", "icon": "🧠", "title": "Tecnología punta", "title_en": "Cutting edge", "desc": "Lleva una mejora a su nivel máximo", "desc_en": "Take one upgrade to max level", "stat": "max_upgrade_level", "goal": 10, "reward": 150},
	{"id": "streak", "icon": "📅", "title": "Constancia", "title_en": "Consistency", "desc": "Recoge la recompensa diaria 7 días seguidos", "desc_en": "Claim the daily reward 7 days in a row", "stat": "daily_streak", "goal": 7, "reward": 200},
	{"id": "daily_challenger", "icon": "🎯", "title": "Desafío superado", "title_en": "Challenge beaten", "desc": "Completa un desafío diario", "desc_en": "Complete a daily challenge", "stat": "daily_challenges", "goal": 1, "reward": 100},
]

static func achievement_title(a: Dictionary) -> String:
	return a.get("title_en", a.get("title", "?")) if LocaleStrings.lang == "en" else a.get("title", "?")

static func achievement_desc(a: Dictionary) -> String:
	return a.get("desc_en", a.get("desc", "")) if LocaleStrings.lang == "en" else a.get("desc", "")

static func get_all() -> Array[Dictionary]:
	return ACHIEVEMENTS

static func get_by_id(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}
