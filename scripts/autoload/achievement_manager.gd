extends Node

## AchievementManager: convierte eventos en estadísticas, misiones, XP y logros.
## Sólo lógica: el estado se guarda en GameManager y los avisos los muestra Toasts.
## Los logros se comprueban en cuanto cambia una estadística (el aviso sale en plena batalla),
## pero las estadísticas sólo se escriben en disco al terminar la batalla o al desbloquear.

var _lost_base_this_battle: bool = false

func _ready() -> void:
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.base_captured.connect(_on_base_captured)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.troops_dispatched.connect(_on_troops_dispatched)
	EventBus.troops_retreated.connect(_on_troops_retreated)
	EventBus.player_assault.connect(_on_player_assault)
	EventBus.upgrade_purchased.connect(check_all.unbind(2))
	EventBus.daily_reward_claimed.connect(check_all.unbind(2))

## Valor actual de la estadística de un logro (guardada o derivada del progreso)
func get_stat(stat: String) -> int:
	match stat:
		"three_star_levels":
			return GameManager.completed_levels.values().count(3)
		"levels_completed":
			return GameManager.completed_levels.size()
		"continents_completed":
			var done := 0
			for c in LevelDatabase.get_continents():
				if LevelDatabase.get_continent_level_ids(c["id"]).all(func(id): return GameManager.completed_levels.has(id)):
					done += 1
			return done
		"max_upgrade_level":
			return GameManager.upgrades.values().max()
	return GameManager.get_stat(stat)

## Progreso de un logro en [0, 1]
func get_progress(achievement: Dictionary) -> float:
	return clampf(float(get_stat(achievement["stat"])) / achievement["goal"], 0.0, 1.0)

## Desbloquea los logros cumplidos; devuelve los ids recién desbloqueados
func check_all() -> Array[String]:
	var unlocked: Array[String] = []
	for a in AchievementDatabase.get_all():
		if not GameManager.is_achievement_unlocked(a["id"]) and get_stat(a["stat"]) >= a["goal"]:
			GameManager.unlock_achievement(a["id"])
			unlocked.append(a["id"])
			EventBus.achievement_unlocked.emit(a["id"])
	return unlocked

func _on_battle_started(_level_id: String) -> void:
	_lost_base_this_battle = false

func _on_base_captured(_base: Node, previous_faction: int, new_faction: int) -> void:
	if new_faction == GameManager.Faction.PLAYER:
		GameManager.add_stat("bases_captured")
		GameManager.advance_mission("captures")
		check_all()
	elif previous_faction == GameManager.Faction.PLAYER:
		_lost_base_this_battle = true

func _on_battle_won(battle_stats: Dictionary) -> void:
	GameManager.record_battle_result(battle_stats, not _lost_base_this_battle)
	GameManager.add_stat("victories")
	if battle_stats.get("time", INF) < AchievementDatabase.BLITZ_SECONDS:
		GameManager.add_stat("fast_victories")
	if not _lost_base_this_battle:
		GameManager.add_stat("flawless_victories")
	check_all()
	GameManager.save_game()

func _on_battle_lost() -> void:
	GameManager.experience += 10
	GameManager.save_game()

func _on_troops_dispatched(_from: Node, _to: Node, count: int, faction: int) -> void:
	if faction == GameManager.Faction.PLAYER:
		GameManager.record_stat_max("biggest_stream", count)
		check_all()

func _on_player_assault(source_count: int) -> void:
	GameManager.record_stat_max("chain_max", source_count)
	check_all()

func _on_troops_retreated(faction: int) -> void:
	if faction == GameManager.Faction.PLAYER:
		GameManager.add_stat("retreats")
		check_all()
