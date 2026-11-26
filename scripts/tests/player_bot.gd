extends RefCounted
class_name PlayerBot

## ponytail: política sencilla con información visible y hasta tres orígenes;
## un estudio con personas valida intuición, errores y ergonomía reales.
static func order(battle: BattleController) -> void:
	var best_target: BaseNode
	var best_sources: Array[BaseNode] = []
	var best_score := -INF
	for dst in battle.bases:
		if dst.faction == GameManager.Faction.PLAYER: continue
		var sources: Array[BaseNode] = []
		sources.assign(battle.bases.filter(func(b):
			return b.faction == GameManager.Faction.PLAYER and b.troops >= 8 and battle.can_dispatch(b, dst)))
		sources.sort_custom(func(a, b): return a.position.distance_squared_to(dst.position) < b.position.distance_squared_to(dst.position))
		var chosen: Array[BaseNode] = []
		var available := 0
		for src in sources:
			chosen.append(src)
			available += src.troops - 1
			battle.selected_sources = chosen
			var defense := battle.estimate_target_defense(dst)
			if defense <= 0.0: break # Ya hay tropas suficientes en camino.
			if available > defense + 4:
				var distance := src.position.distance_to(dst.position)
				var score := (200.0 if dst.faction == GameManager.Faction.NEUTRAL else 140.0) - distance * 0.08 - defense * 0.4
				if dst.base_type == BaseNode.BaseType.FACTORY: score += 90.0
				if score > best_score:
					best_score = score
					best_target = dst
					best_sources = chosen.duplicate()
				break
			if chosen.size() == 3: break
	battle.selected_sources.clear()
	if best_target:
		for src in best_sources: battle.dispatch_troops(src, best_target)
