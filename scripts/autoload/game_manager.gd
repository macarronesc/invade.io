extends Node

## GameManager: Gestor central de estado, economía, mejoras y persistencia

signal save_status_changed()

enum Faction {
	NEUTRAL = 0,
	PLAYER = 1,
	ENEMY_1 = 2,
	ENEMY_2 = 3,
	ENEMY_3 = 4
}

const FACTION_COLORS = {
	Faction.NEUTRAL: Color(0.47, 0.56, 0.61),    # Gris pizarra
	Faction.PLAYER: Color(0.13, 0.59, 0.95),     # Azul brillante
	Faction.ENEMY_1: Color(0.96, 0.26, 0.21),    # Rojo carmesí
	Faction.ENEMY_2: Color(1.0, 0.76, 0.03),     # Amarillo ámbar
	Faction.ENEMY_3: Color(0.30, 0.69, 0.31)     # Verde esmeralda
}

const FACTION_NAMES = {
	Faction.NEUTRAL: "Neutral",
	Faction.PLAYER: "Tú",
	Faction.ENEMY_1: "Rojo",
	Faction.ENEMY_2: "Ámbar",
	Faction.ENEMY_3: "Verde"
}

const FACTION_NAMES_EN = {
	Faction.NEUTRAL: "Neutral",
	Faction.PLAYER: "You",
	Faction.ENEMY_1: "Red",
	Faction.ENEMY_2: "Amber",
	Faction.ENEMY_3: "Green"
}

const UPGRADE_BASE_COSTS = {
	"starting_troops": 50,
	"production_rate": 75,
	"troop_speed": 60,
	"gold_bonus": 100
}

## Mejora por nivel de cada tipo: tropas iniciales o puntos porcentuales
const UPGRADE_STEPS = {
	"starting_troops": 5,
	"production_rate": 15,
	"troop_speed": 10,
	"gold_bonus": 10
}
## Crecimiento del coste por nivel: base × (1 + n + n²/4). Suave para que siempre haya una
## compra a pocas victorias (nivel 9 ≈ 30× la primera, antes 200×)
const UPGRADE_COST_QUADRATIC := 0.25

const MAX_UPGRADE_LEVEL = 10
const DEFAULT_COINS = 150
const FIRST_LEVEL_ID := "europe_1"
const SAVE_VERSION = 6
const DEFAULT_SETTINGS := {"volume": 0.8, "music_volume": 0.8, "vibration": true, "speed": 1.0, "colorblind": false,
	"light_mode": false, "reduced_motion": false, "vibration_intensity": 0.55}
const MAX_SAVE_BYTES := 2_000_000
const HAPTIC_INTERVAL_MS := 80
const GAME_SPEEDS := [0.75, 1.0, 1.5, 2.0]
const ACCESSIBLE_FACTION_COLORS := [Color("8796a5"), Color("0072b2"), Color("d55e00"), Color("f0e442"), Color("cc79a7")]
const SUPPORTED_LANGUAGES := ["es", "en"]
## Cosméticos iniciales: uno gratis por categoría
const DEFAULT_COSMETICS_EQUIPPED := {"army_color": "color_blue", "troop_style": "troop_classic", "base_shape": "base_round", "map_theme": "theme_midnight"}

## Fracción de oro que se concede al repetir un nivel ya superado sin mejorar estrellas
const REPLAY_GOLD_FACTOR = 0.25
const DEFEAT_XP := 10
const MAX_DEFEAT_REWARDS := 2
const FIRST_BOSS_GOLD := 150
## Oro al completar la colección de ciudades de un continente
const COLLECTION_GOLD := 200
## Regiones por expedición en la conquista libre; la última es un jefe con premio doble
const EXPEDITION_SIZE := 5

var coins: int = DEFAULT_COINS
var upgrades: Dictionary = {}
var current_continent: String = LevelDatabase.get_continent_of(FIRST_LEVEL_ID)
var current_level_id: String = FIRST_LEVEL_ID
var completed_levels: Dictionary = {} # level_id: stars (1-3)
var unlocked_levels: Array[String] = [FIRST_LEVEL_ID]
var sound_muted: bool = false
var music_muted: bool = false
var seen_tips: Array[String] = []
## Estadísticas acumuladas para los logros (bases capturadas, victorias...)
var stats: Dictionary = {}
## Estado de cada logro: ACHIEVEMENT_UNLOCKED (recompensa pendiente) o ACHIEVEMENT_CLAIMED
var achievements: Dictionary = {}
## Recompensa diaria y desafío del día (días locales, ver DailyRewards.today)
var daily: Dictionary = {}
## Nivel diario o de conquista en juego; vacío = campaña. No se persiste.
var special_level_id: String = ""
## Idioma de la interfaz ("es" o "en")
var language: String:
	get:
		return LocaleStrings.lang
	set(value):
		LocaleStrings.lang = value
## Primer arranque: false hasta que el jugador entra en su primera batalla
var has_started: bool = false
## Siguiente región de expedición por jugar; la dificultad crece hasta su techo.
var conquest_next: int = 0
## Ciudades reales conquistadas en cualquier modo (claves de GeoDatabase)
var conquered_cities: Array[String] = []
## Estética desbloqueada y equipada (ver CosmeticsDatabase)
var cosmetics_owned: Array[String] = []
var cosmetics_equipped: Dictionary = {}
var settings: Dictionary = {}
var experience: int = 0
var missions: Dictionary = {}
var daily_best: Dictionary = {}
## Tiempo de victoria más rápido por nivel de campaña (segundos de simulación).
var campaign_best: Dictionary = {}
## Niveles de campaña ganados sin perder ninguna base (medalla de dominio)
var medals: Array[String] = []
## Continentes cuya colección del atlas ya se ha cobrado
var collections_claimed: Array[String] = []
## Intentos con recompensa de consuelo por nivel pendiente (máximo dos).
var defeat_rewards: Dictionary = {}
## Batalla en curso sin mejoras de combate (desafío diario, comparable entre jugadores)
var normalized_battle: bool = false

const ACHIEVEMENT_UNLOCKED := "unlocked"
const ACHIEVEMENT_CLAIMED := "claimed"

## Multiplicador de producción de las facciones enemigas en la batalla actual (curva de dificultad)
var enemy_production_multiplier: float = 1.0

var save_path: String = "user://invade_save.json"
var save_error: Error = OK
var save_recovered := false
var application_active := true
var _last_haptic_ms := -HAPTIC_INTERVAL_MS
var _last_haptic_duration := 0
var _save_blocked := false

func _init() -> void:
	_apply_save({})

func _ready() -> void:
	load_game()
	if save_error == OK and not FileAccess.file_exists(save_path):
		save_game()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if application_active:
				application_active = false
				save_game()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if not application_active:
				application_active = true
				if save_error != OK:
					save_status_changed.emit()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			save_game()

func get_total_stars() -> int:
	var total := 0
	for lvl in completed_levels:
		total += int(completed_levels[lvl])
	return total

func get_max_possible_stars() -> int:
	return LevelDatabase.get_level_ids().size() * 3

## Bonificación total de una mejora con su nivel actual (tropas o puntos porcentuales)
func get_upgrade_bonus(upgrade_id: String) -> int:
	if normalized_battle and upgrade_id != "gold_bonus":
		return 0
	return upgrades.get(upgrade_id, 0) * UPGRADE_STEPS[upgrade_id]

func get_starting_troops_bonus() -> int:
	return get_upgrade_bonus("starting_troops")

func get_production_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("production_rate") / 100.0

func get_troop_speed_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("troop_speed") / 100.0

func get_gold_multiplier() -> float:
	return 1.0 + get_upgrade_bonus("gold_bonus") / 100.0

## Multiplicador de producción aplicable a una facción en la batalla actual
func get_faction_production_multiplier(faction: int) -> float:
	if faction == Faction.PLAYER:
		return get_production_multiplier()
	if faction == Faction.NEUTRAL:
		return 0.0
	return enemy_production_multiplier

func get_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADE_BASE_COSTS.has(upgrade_id):
		return -1
	var lvl: int = upgrades.get(upgrade_id, 0)
	if lvl >= MAX_UPGRADE_LEVEL:
		return -1
	var base_cost: int = UPGRADE_BASE_COSTS[upgrade_id]
	return int(round(base_cost * (1.0 + lvl + lvl * lvl * UPGRADE_COST_QUADRATIC)))

## Primero reclutar y abrir territorio; marcha después. Nunca recomendar oro
## para resolver un combate. El filtro de saldo permite ofrecer una compra real.
func recommended_combat_upgrade(affordable_only: bool = false) -> String:
	var best := ""
	var best_score := INF
	for id in ["production_rate", "starting_troops", "troop_speed"]:
		var cost := get_upgrade_cost(id)
		if cost < 0 or (affordable_only and cost > coins):
			continue
		var score := float(upgrades.get(id, 0)) + (2.0 if id == "troop_speed" else 0.0)
		if score < best_score:
			best = id
			best_score = score
	return best

func can_suggest_combat_upgrade() -> bool:
	return not DailyRewards.is_challenge(get_battle_level_id()) and recommended_combat_upgrade(true) != ""

## Primera compra guiada: aún no ha mejorado nada y ya puede permitírselo
func should_suggest_first_upgrade() -> bool:
	return upgrades.values().max() == 0 and can_suggest_combat_upgrade()

func buy_upgrade(upgrade_id: String) -> bool:
	var cost := get_upgrade_cost(upgrade_id)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	upgrades[upgrade_id] = upgrades.get(upgrade_id, 0) + 1
	save_game()
	EventBus.coins_updated.emit(coins)
	EventBus.upgrade_purchased.emit(upgrade_id, upgrades[upgrade_id])
	return true

func add_coins(amount: int) -> void:
	coins += amount
	save_game()
	EventBus.coins_updated.emit(coins)

## Oro a conceder por una victoria: completo la primera vez, la mitad si se mejoran estrellas
## y una fracción reducida al repetir (evita el farmeo del primer nivel)
func calculate_victory_gold(level_id: String, stars: int, base_amount: int) -> int:
	var previous: int = int(completed_levels.get(level_id, 0))
	var factor := 1.0
	if previous > 0:
		factor = 0.5 if stars > previous else REPLAY_GOLD_FACTOR
	var index := LevelDatabase.get_level_ids().find(level_id)
	if index >= 0:
		base_amount += index * 12
		if previous == 0 and LevelDatabase.get_level_number(level_id) == LevelDatabase.LEVELS_PER_CONTINENT:
			base_amount += FIRST_BOSS_GOLD
	return int(round(base_amount * factor * get_gold_multiplier()))

## No recompensa abandonar, perder enseguida, repetir un nivel ganado ni
## capturar la misma base varias veces. No depende de las mejoras de botín.
func award_defeat_gold(level_id: String, unique_captures: int, seconds: float) -> int:
	if not _is_campaign_level(level_id) or completed_levels.has(level_id) or unique_captures < 1 or seconds < 15.0:
		return 0
	var claims := int(defeat_rewards.get(level_id, 0))
	if claims >= MAX_DEFEAT_REWARDS:
		return 0
	var amount := roundi((60 + LevelDatabase.get_level_ids().find(level_id) * 12) * 0.2)
	defeat_rewards[level_id] = claims + 1
	add_coins(amount)
	return amount

func complete_level(level_id: String, stars: int, medal: bool = false) -> void:
	var current_stars: int = int(completed_levels.get(level_id, 0))
	if stars > current_stars:
		completed_levels[level_id] = stars
	if medal and not medals.has(level_id):
		medals.append(level_id)

	# Desbloquear siguiente nivel
	var next_id = get_next_level(level_id)
	if next_id != "":
		if not unlocked_levels.has(next_id):
			unlocked_levels.append(next_id)
		current_level_id = next_id
		current_continent = LevelDatabase.get_continent_of(next_id)

	save_game()

func is_level_unlocked(level_id: String) -> bool:
	return unlocked_levels.has(level_id)

## Siguiente nivel de la campaña ("" tras el último o si no es de campaña)
func get_next_level(level_id: String) -> String:
	var ids := LevelDatabase.get_level_ids()
	var i := ids.find(level_id)
	return ids[i + 1] if i >= 0 and i + 1 < ids.size() else ""

## Nivel que carga la batalla sin perder el punto de la campaña
func get_battle_level_id() -> String:
	return special_level_id if special_level_id != "" else current_level_id

## Elige el nivel de la próxima batalla sin perder el punto de la campaña
func play_level(level_id: String) -> void:
	if DailyRewards.is_challenge(level_id) or LevelGenerator.is_conquest(level_id):
		special_level_id = level_id
	else:
		special_level_id = ""
		current_level_id = level_id

## Juega una región de conquista libre ("conquest_<n>")
func play_conquest(index: int) -> void:
	play_level(LevelGenerator.conquest_id(index))

## Nombre de facción en el idioma actual (etiquetas de la barra de dominancia)
func faction_name(faction: int) -> String:
	return FACTION_NAMES_EN.get(faction, "?") if language == "en" else FACTION_NAMES.get(faction, "?")

## Color real de una facción en batalla (el jugador usa su color de la tienda)
func faction_color(faction: int) -> Color:
	if settings.get("colorblind", false):
		return ACCESSIBLE_FACTION_COLORS[clampi(faction, 0, 4)]
	if faction == Faction.PLAYER:
		return player_color()
	return FACTION_COLORS.get(faction, Color.GRAY)

## Color del ejército equipado en la tienda de estética
func player_color() -> Color:
	return CosmeticsDatabase.get_by_id(cosmetics_equipped.get("army_color", "")).get("color", FACTION_COLORS[Faction.PLAYER])

func player_level() -> int:
	return PlayerRank.level(experience)

func is_continent_complete(continent_id: String) -> bool:
	return LevelDatabase.get_continent_level_ids(continent_id).all(func(id): return completed_levels.has(id))

func troop_style() -> String:
	return str(cosmetics_equipped.get("troop_style", "troop_classic"))

func base_shape() -> String:
	return str(cosmetics_equipped.get("base_shape", "base_round"))

func map_theme() -> Dictionary:
	var theme := CosmeticsDatabase.get_by_id(cosmetics_equipped.get("map_theme", ""))
	return theme if not theme.is_empty() else CosmeticsDatabase.get_by_id("theme_midnight")

# =========================================================================
# Estadísticas y logros (AchievementManager decide cuándo se cumplen)
# =========================================================================

func get_stat(stat: String) -> int:
	return int(stats.get(stat, 0))

func add_stat(stat: String, amount: int = 1) -> void:
	stats[stat] = get_stat(stat) + amount

## Guarda el valor sólo si supera el récord anterior
func record_stat_max(stat: String, value: int) -> void:
	stats[stat] = maxi(get_stat(stat), value)

func is_achievement_unlocked(id: String) -> bool:
	return achievements.has(id)

func is_achievement_claimed(id: String) -> bool:
	return achievements.get(id, "") == ACHIEVEMENT_CLAIMED

## Devuelve true si el logro se acaba de desbloquear
func unlock_achievement(id: String) -> bool:
	if achievements.has(id):
		return false
	achievements[id] = ACHIEVEMENT_UNLOCKED
	save_game()
	return true

## Cobra la recompensa de un logro desbloqueado; devuelve el oro concedido (0 si no procede)
func claim_achievement(id: String) -> int:
	if achievements.get(id, "") != ACHIEVEMENT_UNLOCKED:
		return 0
	achievements[id] = ACHIEVEMENT_CLAIMED
	var reward: int = AchievementDatabase.get_by_id(id).get("reward", 0)
	add_coins(reward)
	return reward

func get_claimable_achievement_count() -> int:
	return achievements.values().count(ACHIEVEMENT_UNLOCKED)

# =========================================================================
# Recompensa diaria y desafío del día
# =========================================================================

func get_daily_reward_state(day: int = DailyRewards.today()) -> Dictionary:
	return DailyRewards.evaluate(int(daily["last_claim_day"]), int(daily["streak"]), day)

## Cobra la recompensa del día; devuelve el oro concedido (0 si ya se cobró)
func claim_daily_reward(day: int = DailyRewards.today()) -> int:
	var state := get_daily_reward_state(day)
	if not state["can_claim"]:
		return 0
	daily["last_claim_day"] = day
	daily["streak"] = state["streak"]
	record_stat_max("daily_streak", state["streak"])
	add_coins(state["reward"])
	EventBus.daily_reward_claimed.emit(state["streak"], state["reward"])
	return state["reward"]

func is_daily_challenge_done(day: int = DailyRewards.today()) -> bool:
	return int(daily["challenge_day"]) == day

## Registra la victoria en un desafío diario; devuelve el oro (completo sólo la primera vez del día)
func complete_daily_challenge(level_id: String) -> int:
	var day := DailyRewards.challenge_day(level_id)
	var is_replay := is_daily_challenge_done(day)
	if not is_replay:
		daily["challenge_day"] = day
		add_stat("daily_challenges")
	var factor := REPLAY_GOLD_FACTOR if is_replay else 1.0
	return int(round(DailyRewards.DAILY_CHALLENGE_GOLD * factor * get_gold_multiplier()))

func has_seen_tip(tip_id: String) -> bool:
	return seen_tips.has(tip_id)

func mark_tip_seen(tip_id: String) -> void:
	if not seen_tips.has(tip_id):
		seen_tips.append(tip_id)
		save_game()

# =========================================================================
# Idioma, conquista libre, atlas de ciudades y tienda de estética
# =========================================================================

## Cambia y persiste el idioma; la interfaz decide cuándo recargarse.
func set_language(lang: String) -> void:
	if lang not in SUPPORTED_LANGUAGES or lang == language:
		return
	language = lang
	save_game()
	EventBus.settings_changed.emit()

## Registra la victoria en una región de conquista; devuelve el oro (siempre suma, sin repeticiones).
## Cerrar una expedición (su región final, con jefe) paga el doble.
func complete_conquest(index: int) -> int:
	conquest_next = maxi(conquest_next, index + 1)
	var finale := 2.0 if LevelGenerator.is_expedition_finale(index) else 1.0
	return int(round((100 + 15 * mini(index, 20)) * finale * get_gold_multiplier()))

## Ciudades de la colección de un continente ya en el atlas
func collection_progress(continent_id: String) -> int:
	return LevelDatabase.collection_cities(continent_id).filter(func(c): return conquered_cities.has(c)).size()

func is_collection_complete(continent_id: String) -> bool:
	var cities := LevelDatabase.collection_cities(continent_id)
	return not cities.is_empty() and collection_progress(continent_id) == cities.size()

## Cobra el premio de una colección completa; devuelve el oro (0 si no procede)
func claim_collection(continent_id: String) -> int:
	if collections_claimed.has(continent_id) or not is_collection_complete(continent_id):
		return 0
	collections_claimed.append(continent_id)
	add_coins(COLLECTION_GOLD)
	return COLLECTION_GOLD

func claimable_collection_count() -> int:
	return LevelDatabase.get_continents().filter(func(c): return is_collection_complete(c["id"]) and not collections_claimed.has(c["id"])).size()

## Añade una ciudad real al atlas (devuelve true si era nueva)
func conquer_city(city_key: String) -> bool:
	if not GeoDatabase.has_city(city_key) or conquered_cities.has(city_key):
		return false
	conquered_cities.append(city_key)
	return true

func atlas_conquered_count() -> int:
	return conquered_cities.size()

## Comprado, o ganado por rango o por conquistar su continente
func is_cosmetic_owned(id: String) -> bool:
	if cosmetics_owned.has(id):
		return true
	var item := CosmeticsDatabase.get_by_id(id)
	if item.has("rank"):
		return player_level() >= int(item["rank"])
	return item.has("continent") and is_continent_complete(item["continent"])

## Compra un cosmético; devuelve true si se ha desbloqueado. Los premios no se venden.
func buy_cosmetic(id: String) -> bool:
	var item := CosmeticsDatabase.get_by_id(id)
	if item.is_empty() or CosmeticsDatabase.is_reward(item) or is_cosmetic_owned(id) or coins < int(item["cost"]):
		return false
	coins -= int(item["cost"])
	cosmetics_owned.append(id)
	equip_cosmetic(id)
	EventBus.coins_updated.emit(coins)
	return true

## Equipa un cosmético ya desbloqueado
func equip_cosmetic(id: String) -> bool:
	var item := CosmeticsDatabase.get_by_id(id)
	if item.is_empty() or not is_cosmetic_owned(id):
		return false
	cosmetics_equipped[item["category"]] = id
	save_game()
	EventBus.cosmetics_changed.emit()
	return true

## Vibración háptica breve en dispositivos móviles (no hace nada en escritorio)
func haptic(duration_ms: int) -> void:
	if OS.has_feature("mobile"):
		var effect := _haptic_parameters(duration_ms, Time.get_ticks_msec())
		if effect != Vector2.ZERO:
			Input.vibrate_handheld(int(effect.x), effect.y)

## Un pulso fuerte puede sustituir a uno corto; los repetidos no saturan el motor.
func _haptic_parameters(duration_ms: int, now_ms: int) -> Vector2:
	var intensity: float = settings["vibration_intensity"]
	if not settings["vibration"] or not application_active or intensity <= 0.0 or duration_ms <= 0:
		return Vector2.ZERO
	var duration := clampi(duration_ms, 20, 120)
	if now_ms - _last_haptic_ms < HAPTIC_INTERVAL_MS and duration <= _last_haptic_duration:
		return Vector2.ZERO
	_last_haptic_ms = now_ms
	_last_haptic_duration = duration
	return Vector2(duration, intensity)

func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	if DEFAULT_SETTINGS[key] is bool:
		settings[key] = _as_bool(value)
	else:
		settings[key] = _setting_number(key, value)
	AudioManager.apply_volumes()
	save_game()
	EventBus.settings_changed.emit()

static func _setting_number(key: String, value: Variant) -> float:
	var number := float(value) if (value is int or value is float) else float(DEFAULT_SETTINGS[key])
	if not is_finite(number):
		number = float(DEFAULT_SETTINGS[key])
	if key == "speed":
		number = clampf(number, GAME_SPEEDS[0], GAME_SPEEDS[-1])
		var closest: float = GAME_SPEEDS[0]
		for speed in GAME_SPEEDS:
			if absf(speed - number) < absf(closest - number):
				closest = speed
		return closest
	return clampf(number, 0.0, 1.0)

func ensure_missions(day: int = DailyRewards.today()) -> void:
	# Un reloj atrasado no permite volver a cobrar los objetivos de ayer.
	if day > int(missions.get("day", -1)):
		missions = {"day": day, "progress": {}, "claimed": [], "ids": DailyMissions.for_day(day).map(func(m): return m["id"])}

func mission_definitions(day: int = DailyRewards.today()) -> Array[Dictionary]:
	if day == int(missions.get("day", -1)):
		return DailyMissions.for_ids(missions["ids"])
	return DailyMissions.for_day(day)

func advance_mission(id: String, amount: int = 1, day: int = DailyRewards.today()) -> void:
	ensure_missions(day)
	for mission in mission_definitions(int(missions["day"])):
		if mission["id"] == id:
			missions["progress"][id] = clampi(int(missions["progress"].get(id, 0)) + maxi(0, amount), 0, int(mission["goal"]))

func claim_mission(id: String, day: int = DailyRewards.today()) -> bool:
	ensure_missions(day)
	for mission in mission_definitions(int(missions["day"])):
		if mission["id"] != id or missions["claimed"].has(id) or int(missions["progress"].get(id, 0)) < int(mission["goal"]):
			continue
		missions["claimed"].append(id)
		experience += int(mission["xp"])
		add_coins(int(mission["gold"]))
		return true
	return false

## Misiones de hoy completadas y sin cobrar
func claimable_mission_count(day: int = DailyRewards.today()) -> int:
	if day != int(missions.get("day", -1)):
		return 0
	return mission_definitions(day).filter(func(m): return not missions["claimed"].has(m["id"]) \
		and int(missions["progress"].get(m["id"], 0)) >= int(m["goal"])).size()

## XP de una victoria: más por estrellas y por la medalla, poca al repetir sin mejorar
static func victory_xp(result: Dictionary) -> int:
	var stars: int = clampi(int(result.get("stars", 1)), 1, 3)
	var base := 10 if result.get("is_replay", false) else 30 + stars * 10
	return base + (20 if result.get("new_medal", false) else 0)

func record_battle_result(result: Dictionary, flawless: bool) -> void:
	var stars: int = clampi(int(result.get("stars", 1)), 1, 3)
	experience += victory_xp(result)
	advance_mission("wins")
	advance_mission("stars", stars)
	if flawless:
		advance_mission("flawless")
	if result.get("is_daily_challenge", false):
		advance_mission("daily")
		var day := DailyRewards.challenge_day(str(result["level_id"]))
		var seconds := float(result.get("time", 0.0))
		if int(daily_best.get("balance_version", 0)) != DailyRewards.BALANCE_VERSION or day > int(daily_best.get("day", -1)) or (day == int(daily_best.get("day", -1)) and (stars > int(daily_best["stars"]) or (stars == int(daily_best["stars"]) and seconds < float(daily_best["time"])))):
			result["new_record"] = true
			daily_best = {"day": day, "stars": stars, "time": seconds, "speed": result.get("speed", 1.0), "normalized": true, "balance_version": DailyRewards.BALANCE_VERSION}
	elif _is_campaign_level(result.get("level_id", "")):
		var id: String = result["level_id"]
		var seconds := float(result.get("time", INF))
		if is_finite(seconds) and seconds >= 0 and seconds < float(campaign_best.get(id, INF)):
			result["new_record"] = campaign_best.has(id)
			campaign_best[id] = seconds
	save_game()

func save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": coins,
		"upgrades": upgrades,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"current_continent": current_continent,
		"current_level_id": current_level_id,
		"sound_muted": sound_muted,
		"music_muted": music_muted,
		"seen_tips": seen_tips,
		"stats": stats,
		"achievements": achievements,
		"daily": daily,
		"language": language,
		"has_started": has_started,
		"conquest_next": conquest_next,
		"conquered_cities": conquered_cities,
		"cosmetics_owned": cosmetics_owned,
		"cosmetics_equipped": cosmetics_equipped,
		"settings": settings, "experience": experience, "missions": missions, "daily_best": daily_best,
		"medals": medals, "collections_claimed": collections_claimed,
		"campaign_best": campaign_best,
		"defeat_rewards": defeat_rewards,
	}

func save_game() -> Error:
	if _save_blocked:
		return _set_save_status(ERR_UNAVAILABLE)
	if FileAccess.file_exists(save_path):
		var previous := _read_save(save_path)
		if previous["error"] != OK:
			return _set_save_status(previous["error"])
		var error := write_save(save_path + ".previous", previous["data"])
		if error != OK:
			return _set_save_status(error)
	return _set_save_status(write_save(save_path, save_data()))

func _set_save_status(error: Error) -> Error:
	if save_error != error:
		save_error = error
		save_status_changed.emit()
	return error

## La carga local acepta campos antiguos; la importación exige además la estructura del juego.
func _read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"error": FileAccess.get_open_error()}
	if file.get_length() > MAX_SAVE_BYTES:
		return {"error": ERR_INVALID_DATA}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {"error": ERR_PARSE_ERROR}
	if json.data.has("version"):
		var version: Variant = json.data["version"]
		if not (version is int or version is float) or not is_finite(float(version)) or float(version) < 0.0 or float(version) != floorf(float(version)):
			return {"error": ERR_INVALID_DATA}
		if float(version) > SAVE_VERSION:
			return {"error": ERR_UNAVAILABLE}
	return {"error": OK, "data": json.data}

## También utilizado por la copia manual; nunca truncar el archivo de destino.
func write_save(path: String, data: Dictionary) -> Error:
	# Escritura atómica: un cierre inesperado a mitad de escritura no corrompe la partida
	var tmp_path = path + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(tmp_path, path)

func import_save(path: String) -> Error:
	if _save_blocked:
		return ERR_UNAVAILABLE
	var loaded := _read_save(path)
	if loaded["error"] != OK:
		return ERR_INVALID_DATA
	var data: Dictionary = loaded["data"]
	if not data.get("upgrades") is Dictionary or not data.get("completed_levels") is Dictionary:
		return ERR_INVALID_DATA
	var error := write_save(save_path + ".backup", save_data())
	if error != OK:
		return error
	var previous := save_data().duplicate(true)
	_apply_save(data)
	error = save_game()
	if error != OK:
		_apply_save(previous)
	EventBus.settings_changed.emit()
	return error

func load_game() -> Error:
	_save_blocked = false
	save_recovered = false
	var loaded := _read_save(save_path)
	if loaded["error"] == OK:
		_apply_save(loaded["data"])
		return _set_save_status(OK)
	if loaded["error"] == ERR_UNAVAILABLE:
		_save_blocked = true # Una versión antigua nunca sobrescribe una partida más nueva.
		return _set_save_status(ERR_UNAVAILABLE)
	if loaded["error"] in [ERR_PARSE_ERROR, ERR_INVALID_DATA]:
		var corrupt_path := save_path + ".corrupt"
		if FileAccess.file_exists(corrupt_path):
			corrupt_path += ".%d" % Time.get_ticks_usec()
		var error := DirAccess.rename_absolute(save_path, corrupt_path)
		if error != OK:
			return _set_save_status(error)
	elif loaded["error"] != ERR_FILE_NOT_FOUND:
		return _set_save_status(loaded["error"])
	var previous := _read_save(save_path + ".previous")
	if previous["error"] == OK:
		_apply_save(previous["data"])
		save_recovered = true
		var error := write_save(save_path, save_data())
		save_error = error
		save_status_changed.emit()
		return error
	if previous["error"] == ERR_UNAVAILABLE:
		_save_blocked = true
		return _set_save_status(ERR_UNAVAILABLE)
	if loaded["error"] == ERR_FILE_NOT_FOUND:
		return _set_save_status(OK if previous["error"] == ERR_FILE_NOT_FOUND else previous["error"])
	return _set_save_status(loaded["error"])

func reset_save() -> Error:
	if _save_blocked:
		return ERR_UNAVAILABLE
	var previous := save_data().duplicate(true)
	_apply_save({})
	var error := save_game()
	if error != OK:
		_apply_save(previous)
		return error
	special_level_id = ""
	normalized_battle = false
	save_recovered = false
	# Tras reiniciar, la recuperación tampoco debe resucitar el progreso borrado.
	if FileAccess.file_exists(save_path + ".previous"):
		DirAccess.remove_absolute(save_path + ".previous")
	EventBus.coins_updated.emit(coins)
	EventBus.settings_changed.emit()
	return OK

## Aplica un guardado validando cada campo: lo que falta o no es válido toma su valor inicial.
## Con un diccionario vacío deja la partida nueva.
func _apply_save(data: Dictionary) -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var saved_settings := _as_dict(data.get("settings"))
	for key in settings:
		if saved_settings.has(key):
			if settings[key] is bool:
				settings[key] = _as_bool(saved_settings[key])
			else:
				settings[key] = _setting_number(key, saved_settings[key])
	experience = maxi(0, _as_int(data.get("experience"), 0))
	var saved_missions := _as_dict(data.get("missions"))
	var mission_day := _as_int(saved_missions.get("day"), -1)
	var definitions := DailyMissions.for_ids(_as_array(saved_missions.get("ids")))
	if definitions.size() != 3:
		definitions = DailyMissions.for_day(mission_day, not data.is_empty() and _as_int(data.get("version"), 0) < 5)
	missions = {"day": mission_day, "progress": {}, "claimed": [], "ids": definitions.map(func(m): return m["id"])}
	var progress := _as_dict(saved_missions.get("progress"))
	for mission in definitions:
		var id: String = mission["id"]
		missions["progress"][id] = clampi(_as_int(progress.get(id), 0), 0, int(mission["goal"]))
		if _as_array(saved_missions.get("claimed")).has(id):
			missions["claimed"].append(id)
	daily_best = {}
	var best := _as_dict(data.get("daily_best"))
	if best.get("normalized", false) == true and (best.get("time") is float or best.get("time") is int):
		var seconds := float(best["time"])
		if is_finite(seconds) and seconds >= 0 and _as_int(best.get("day"), -1) >= 0:
			daily_best = {"day": int(best["day"]), "stars": clampi(_as_int(best.get("stars"), 1), 1, 3), "time": seconds, "speed": _setting_number("speed", best.get("speed", 1.0)), "normalized": true, "balance_version": maxi(1, _as_int(best.get("balance_version"), 1))}
	campaign_best = {}
	var times := _as_dict(data.get("campaign_best"))
	for id in times:
		var seconds = times[id]
		if _is_campaign_level(id) and (seconds is float or seconds is int) and is_finite(float(seconds)) and seconds >= 0:
			campaign_best[id] = float(seconds)
	coins = maxi(0, _as_int(data.get("coins"), DEFAULT_COINS))
	var saved_upgrades := _as_dict(data.get("upgrades"))
	upgrades = {}
	for key in UPGRADE_BASE_COSTS:
		upgrades[key] = clampi(_as_int(saved_upgrades.get(key), 0), 0, MAX_UPGRADE_LEVEL)
	completed_levels = {}
	var saved_levels := _as_dict(data.get("completed_levels"))
	for key in saved_levels:
		var stars := _as_int(saved_levels[key], 0)
		if stars > 0 and _is_campaign_level(key):
			completed_levels[key] = mini(stars, 3)
	defeat_rewards = {}
	var saved_defeats := _as_dict(data.get("defeat_rewards"))
	for id in saved_defeats:
		if _is_campaign_level(id):
			defeat_rewards[id] = clampi(_as_int(saved_defeats[id], 0), 0, MAX_DEFEAT_REWARDS)
	unlocked_levels = [FIRST_LEVEL_ID]
	for l in _as_array(data.get("unlocked_levels")):
		if _is_campaign_level(l) and not unlocked_levels.has(l):
			unlocked_levels.append(l)
	seen_tips.clear()
	for t in _as_array(data.get("seen_tips")):
		seen_tips.append(str(t))
	current_level_id = str(data.get("current_level_id", ""))
	if not _is_campaign_level(current_level_id):
		current_level_id = FIRST_LEVEL_ID
	current_continent = str(data.get("current_continent", ""))
	if not LevelDatabase.get_continents().any(func(c): return c["id"] == current_continent):
		current_continent = LevelDatabase.get_continent_of(current_level_id)
	sound_muted = _as_bool(data.get("sound_muted"))
	music_muted = _as_bool(data.get("music_muted"))
	stats = {}
	var saved_stats := _as_dict(data.get("stats"))
	for key in saved_stats:
		stats[key] = maxi(0, _as_int(saved_stats[key], 0))
	achievements = {}
	var saved_achievements := _as_dict(data.get("achievements"))
	for key in saved_achievements:
		if saved_achievements[key] in [ACHIEVEMENT_UNLOCKED, ACHIEVEMENT_CLAIMED]:
			achievements[key] = saved_achievements[key]
	var saved_daily := _as_dict(data.get("daily"))
	daily = {"last_claim_day": -1, "streak": 0, "challenge_day": -1}
	for key in daily:
		daily[key] = _as_int(saved_daily.get(key), daily[key])
	var lang := str(data.get("language", "es"))
	language = lang if lang in SUPPORTED_LANGUAGES else "es"
	has_started = _as_bool(data.get("has_started"))
	conquest_next = maxi(0, _as_int(data.get("conquest_next"), 0))
	var saved_cities := {}
	for c in _as_array(data.get("conquered_cities")):
		if c is String and GeoDatabase.has_city(c):
			saved_cities[c] = true
	conquered_cities.assign(saved_cities.keys())
	cosmetics_owned.clear()
	for c in _as_array(data.get("cosmetics_owned")):
		if c is String and not CosmeticsDatabase.get_by_id(c).is_empty() and not cosmetics_owned.has(c):
			cosmetics_owned.append(c)
	for free_id in DEFAULT_COSMETICS_EQUIPPED.values():
		if not cosmetics_owned.has(free_id):
			cosmetics_owned.append(free_id)
	medals.clear()
	for id in _as_array(data.get("medals")):
		if _is_campaign_level(id) and completed_levels.has(id) and not medals.has(id):
			medals.append(id)
	collections_claimed.clear()
	for id in _as_array(data.get("collections_claimed")):
		if id is String and is_collection_complete(id) and not collections_claimed.has(id):
			collections_claimed.append(id)
	cosmetics_equipped = DEFAULT_COSMETICS_EQUIPPED.duplicate()
	var saved_cosmetics := _as_dict(data.get("cosmetics_equipped"))
	for key in saved_cosmetics:
		var item := CosmeticsDatabase.get_by_id(str(saved_cosmetics[key]))
		if not item.is_empty() and item["category"] == key and is_cosmetic_owned(item["id"]):
			cosmetics_equipped[key] = item["id"]

static func _is_campaign_level(level_id: Variant) -> bool:
	return level_id is String and not DailyRewards.is_challenge(level_id) \
		and not LevelGenerator.is_conquest(level_id) \
		and not LevelDatabase.get_level_definition(level_id).is_empty()

## JSON devuelve los números como float y un guardado dañado puede traer cualquier tipo
static func _as_int(value: Variant, default: int) -> int:
	return int(value) if (value is int or value is float) and is_finite(float(value)) else default

static func _as_bool(value: Variant) -> bool:
	return value is bool and value

static func _as_dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _as_array(value: Variant) -> Array:
	return value if value is Array else []
