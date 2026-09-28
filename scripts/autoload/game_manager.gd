extends Node

## GameManager: Gestor central de estado, economía, mejoras y persistencia

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
	Faction.NEUTRAL: "Gris",
	Faction.PLAYER: "Azul",
	Faction.ENEMY_1: "Rojo",
	Faction.ENEMY_2: "Ámbar",
	Faction.ENEMY_3: "Verde"
}

const UPGRADE_BASE_COSTS = {
	"starting_troops": 50,
	"production_rate": 75,
	"troop_speed": 60,
	"gold_bonus": 100
}

const MAX_UPGRADE_LEVEL = 10
const DEFAULT_COINS = 150
const SAVE_VERSION = 2

## Fracción de oro que se concede al repetir un nivel ya superado sin mejorar estrellas
const REPLAY_GOLD_FACTOR = 0.25

var coins: int = DEFAULT_COINS
var upgrades: Dictionary = _default_upgrades()
var current_continent: String = "europe"
var current_level_id: String = "europe_1"
var completed_levels: Dictionary = {} # level_id: stars (1-3)
var unlocked_levels: Array[String] = ["europe_1"]
var sound_muted: bool = false
var music_muted: bool = false
var seen_tips: Array[String] = []

## Multiplicador de producción de las facciones enemigas en la batalla actual (curva de dificultad)
var enemy_production_multiplier: float = 1.0

var save_path: String = "user://invade_save.json"

func _ready() -> void:
	load_game()

static func _default_upgrades() -> Dictionary:
	return {
		"starting_troops": 0,
		"production_rate": 0,
		"troop_speed": 0,
		"gold_bonus": 0
	}

func get_total_stars() -> int:
	var total := 0
	for lvl in completed_levels:
		total += int(completed_levels[lvl])
	return total

func get_max_possible_stars() -> int:
	return LevelDatabase.get_level_ids().size() * 3

func get_starting_troops_bonus() -> int:
	return upgrades.get("starting_troops", 0) * 5

func get_production_multiplier() -> float:
	return 1.0 + (upgrades.get("production_rate", 0) * 0.15)

func get_troop_speed_multiplier() -> float:
	return 1.0 + (upgrades.get("troop_speed", 0) * 0.10)

func get_gold_multiplier() -> float:
	return 1.0 + (upgrades.get("gold_bonus", 0) * 0.20)

## Multiplicador de producción aplicable a una facción en la batalla actual
func get_faction_production_multiplier(faction: int) -> float:
	if faction == Faction.PLAYER:
		return get_production_multiplier()
	if faction == Faction.NEUTRAL:
		return 0.0
	return enemy_production_multiplier

func get_upgrade_cost(upgrade_id: String) -> int:
	var lvl: int = upgrades.get(upgrade_id, 0)
	if lvl >= MAX_UPGRADE_LEVEL:
		return -1
	var base_cost: int = UPGRADE_BASE_COSTS.get(upgrade_id, 50)
	return int(round(base_cost * pow(1.8, lvl)))

func buy_upgrade(upgrade_id: String) -> bool:
	var lvl: int = upgrades.get(upgrade_id, 0)
	if lvl >= MAX_UPGRADE_LEVEL:
		return false
	var cost = get_upgrade_cost(upgrade_id)
	if coins >= cost and cost > 0:
		coins -= cost
		upgrades[upgrade_id] = lvl + 1
		save_game()
		EventBus.coins_updated.emit(coins)
		EventBus.upgrade_purchased.emit(upgrade_id, upgrades[upgrade_id])
		return true
	return false

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
	return int(round(base_amount * factor * get_gold_multiplier()))

func complete_level(level_id: String, stars: int) -> void:
	var current_stars: int = int(completed_levels.get(level_id, 0))
	if stars > current_stars:
		completed_levels[level_id] = stars

	# Desbloquear siguiente nivel
	var next_id = get_next_level(level_id)
	if next_id != "":
		if not unlocked_levels.has(next_id):
			unlocked_levels.append(next_id)
		current_level_id = next_id
		var next_cont = next_id.substr(0, next_id.rfind("_"))
		if next_cont != "":
			current_continent = next_cont

	save_game()

func is_level_unlocked(level_id: String) -> bool:
	return unlocked_levels.has(level_id)

func get_next_level(level_id: String) -> String:
	var last_underscore = level_id.rfind("_")
	if last_underscore != -1:
		var continent = level_id.substr(0, last_underscore)
		var index = int(level_id.substr(last_underscore + 1))
		if index < 5:
			return "%s_%d" % [continent, index + 1]
		else:
			# Desbloquear primer nivel del siguiente continente
			var continent_order = LevelDatabase.CONTINENT_ORDER
			var c_idx = continent_order.find(continent)
			if c_idx >= 0 and c_idx + 1 < continent_order.size():
				return "%s_1" % continent_order[c_idx + 1]
	return ""

func has_seen_tip(tip_id: String) -> bool:
	return seen_tips.has(tip_id)

func mark_tip_seen(tip_id: String) -> void:
	if not seen_tips.has(tip_id):
		seen_tips.append(tip_id)
		save_game()

## Vibración háptica breve en dispositivos móviles (no hace nada en escritorio)
func haptic(duration_ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func save_game() -> void:
	var data = {
		"version": SAVE_VERSION,
		"coins": coins,
		"upgrades": upgrades,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"current_continent": current_continent,
		"current_level_id": current_level_id,
		"sound_muted": sound_muted,
		"music_muted": music_muted,
		"seen_tips": seen_tips
	}
	# Escritura atómica: un cierre inesperado a mitad de escritura no corrompe la partida
	var tmp_path = save_path + ".tmp"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(tmp_path, save_path)

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var json = JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = json.data
	# JSON devuelve los números como float: convertir explícitamente a int
	coins = int(data.get("coins", DEFAULT_COINS))
	upgrades = _default_upgrades()
	var saved_upgrades = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for key in saved_upgrades:
			upgrades[key] = clampi(int(saved_upgrades[key]), 0, MAX_UPGRADE_LEVEL)
	completed_levels.clear()
	var saved_levels = data.get("completed_levels", {})
	if saved_levels is Dictionary:
		for key in saved_levels:
			completed_levels[str(key)] = clampi(int(saved_levels[key]), 0, 3)
	unlocked_levels.clear()
	for l in data.get("unlocked_levels", ["europe_1"]):
		unlocked_levels.append(str(l))
	if unlocked_levels.is_empty():
		unlocked_levels.append("europe_1")
	seen_tips.clear()
	for t in data.get("seen_tips", []):
		seen_tips.append(str(t))
	current_continent = str(data.get("current_continent", current_continent))
	current_level_id = str(data.get("current_level_id", current_level_id))
	sound_muted = bool(data.get("sound_muted", false))
	music_muted = bool(data.get("music_muted", false))

func reset_save() -> void:
	coins = DEFAULT_COINS
	upgrades = _default_upgrades()
	completed_levels = {}
	unlocked_levels = ["europe_1"]
	current_continent = "europe"
	current_level_id = "europe_1"
	seen_tips.clear()
	save_game()
