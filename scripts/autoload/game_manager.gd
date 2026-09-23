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

const UPGRADE_BASE_COSTS = {
	"starting_troops": 50,
	"production_rate": 75,
	"troop_speed": 60,
	"gold_bonus": 100
}

const UPGRADE_DESCRIPTIONS = {
	"starting_troops": "+5 tropas adicionales en tu base al iniciar la batalla",
	"production_rate": "+15% velocidad de generación de tropas en todas tus bases",
	"troop_speed": "+10% velocidad de marcha de tus tropas hacia el objetivo",
	"gold_bonus": "+20% más oro por victoria conseguida en campaña"
}

const UPGRADE_TITLES = {
	"starting_troops": "Guarnición Inicial",
	"production_rate": "Velocidad de Reclutamiento",
	"troop_speed": "Velocidad de Marcha",
	"gold_bonus": "Botín de Guerra"
}

const MAX_UPGRADE_LEVEL = 10

var coins: int = 150
var upgrades: Dictionary = {
	"starting_troops": 0,
	"production_rate": 0,
	"troop_speed": 0,
	"gold_bonus": 0
}

var current_continent: String = "europe"
var current_level_id: String = "europe_1"
var completed_levels: Dictionary = {} # level_id: stars (1-3)
var unlocked_levels: Array[String] = ["europe_1"]

const SAVE_PATH = "user://invade_save.json"

func _ready() -> void:
	load_game()

func get_starting_troops_bonus() -> int:
	return upgrades.get("starting_troops", 0) * 5

func get_production_multiplier() -> float:
	return 1.0 + (upgrades.get("production_rate", 0) * 0.15)

func get_troop_speed_multiplier() -> float:
	return 1.0 + (upgrades.get("troop_speed", 0) * 0.10)

func get_gold_multiplier() -> float:
	return 1.0 + (upgrades.get("gold_bonus", 0) * 0.20)

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

func complete_level(level_id: String, stars: int) -> void:
	var current_stars = completed_levels.get(level_id, 0)
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

func _calculate_next_level(level_id: String) -> String:
	return get_next_level(level_id)

func get_next_level(level_id: String) -> String:
	var last_underscore = level_id.rfind("_")
	if last_underscore != -1:
		var continent = level_id.substr(0, last_underscore)
		var index = int(level_id.substr(last_underscore + 1))
		if index < 5:
			return "%s_%d" % [continent, index + 1]
		else:
			# Desbloquear primer nivel del siguiente continente
			var continent_order = ["europe", "north_america", "south_america", "africa", "asia", "oceania"]
			var c_idx = continent_order.find(continent)
			if c_idx >= 0 and c_idx + 1 < continent_order.size():
				return "%s_1" % continent_order[c_idx + 1]
	return ""

func save_game() -> void:
	var data = {
		"coins": coins,
		"upgrades": upgrades,
		"completed_levels": completed_levels,
		"unlocked_levels": unlocked_levels,
		"current_continent": current_continent,
		"current_level_id": current_level_id
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
			var data = json.data
			coins = data.get("coins", 150)
			upgrades = data.get("upgrades", upgrades)
			completed_levels = data.get("completed_levels", completed_levels)
			var ul = data.get("unlocked_levels", unlocked_levels)
			unlocked_levels.clear()
			for l in ul:
				unlocked_levels.append(str(l))
			current_continent = data.get("current_continent", current_continent)
			current_level_id = data.get("current_level_id", current_level_id)

func reset_save() -> void:
	coins = 150
	upgrades = {
		"starting_troops": 0,
		"production_rate": 0,
		"troop_speed": 0,
		"gold_bonus": 0
	}
	completed_levels = {}
	unlocked_levels = ["europe_1"]
	current_continent = "europe"
	save_game()
