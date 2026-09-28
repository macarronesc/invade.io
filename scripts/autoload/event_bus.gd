extends Node

## EventBus: Bus de eventos desacoplado para comunicación entre sistemas

signal base_captured(base: Node, previous_faction: int, new_faction: int)
signal troops_dispatched(from_base: Node, to_base: Node, count: int, faction: int)
signal troop_arrived(troop: Node, target_base: Node)
signal troops_retreated(faction: int)

signal battle_started(level_id: String)
signal battle_won(stats: Dictionary)
signal battle_lost()

signal coins_updated(total_coins: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal sound_toggled(is_muted: bool)
