extends Node

## EventBus: Bus de eventos desacoplado para comunicación entre sistemas

signal base_captured(base: Node, previous_faction: int, new_faction: int)
signal troops_dispatched(from_base: Node, to_base: Node, count: int, faction: int)
signal troop_arrived(troop: Node)
signal troops_retreated(faction: int)
## El jugador lanza un ataque desde `source_count` bases en un mismo trazo
signal player_assault(source_count: int)

signal battle_started(level_id: String)
signal battle_won(stats: Dictionary)
signal battle_lost()

signal coins_updated(total_coins: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal sound_toggled(is_muted: bool)

signal achievement_unlocked(achievement_id: String)
signal daily_reward_claimed(streak: int, reward: int)
signal cosmetics_changed()
