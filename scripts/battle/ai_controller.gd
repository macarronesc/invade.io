extends Node
class_name AIController

## AIController: Manejo de decisiones estratégicas autónomas para facciones enemigas

var battle_controller: BattleController
var faction: int = GameManager.Faction.ENEMY_1
var think_timer: float = 0.0
var think_interval: float = 1.8

func setup(p_battle_controller: BattleController, p_faction: int) -> void:
	battle_controller = p_battle_controller
	faction = p_faction
	think_interval = randf_range(1.4, 2.2)
	think_timer = randf_range(0.2, think_interval)

func _process(delta: float) -> void:
	if not battle_controller or battle_controller.is_game_over:
		return
		
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = randf_range(1.3, 2.1)
		_evaluate_and_execute()

func _evaluate_and_execute() -> void:
	if not battle_controller or battle_controller.is_game_over:
		return
		
	var all_bases: Array[BaseNode] = battle_controller.bases
	var my_bases: Array[BaseNode] = []
	var other_bases: Array[BaseNode] = []
	
	for b in all_bases:
		if not is_instance_valid(b):
			continue
		if b.faction == faction:
			my_bases.append(b)
		else:
			other_bases.append(b)
			
	if my_bases.is_empty():
		return
		
	# 1. Evaluar si podemos coordinar un ataque conjunto multi-base sobre un objetivo clave
	if my_bases.size() >= 2:
		var target_candidate: BaseNode = null
		var highest_target_score: float = -100.0
		
		for dst in other_bases:
			if not is_instance_valid(dst):
				continue
			var combined_send = 0
			var avg_dist = 0.0
			for src in my_bases:
				if src.troops > 2:
					combined_send += (src.troops - 1)
					avg_dist += src.global_position.distance_to(dst.global_position)
			avg_dist /= max(1, my_bases.size())
			
			if combined_send > (dst.troops + 4):
				var score = (combined_send - dst.troops) * 3.0 - (avg_dist * 0.05)
				if dst.faction == GameManager.Faction.PLAYER:
					score += 40.0 # Priorizar frenar al jugador
				if score > highest_target_score:
					highest_target_score = score
					target_candidate = dst
					
		if target_candidate and highest_target_score > 25.0:
			# Ejecutar ataque coordinado desde 2 o más bases
			var sent_count = 0
			for src in my_bases:
				if src.troops > 3 and src.global_position.distance_to(target_candidate.global_position) < 850.0:
					battle_controller.dispatch_troops(src, target_candidate, 1.0)
					sent_count += 1
					if sent_count >= 2:
						break
			if sent_count > 0:
				return
				
	# 2. Evaluación táctica individual por base
	var actions_executed = 0
	for src in my_bases:
		if src.troops < 3:
			continue
			
		var is_near_cap = src.troops >= (src.max_capacity - 5)
		var best_target: BaseNode = null
		var highest_utility: float = -9999.0
		var potential_send = src.troops - 1
		
		for dst in all_bases:
			if dst == src or not is_instance_valid(dst):
				continue
				
			var dist = src.global_position.distance_to(dst.global_position)
			var utility: float = 0.0
			
			if dst.faction == GameManager.Faction.NEUTRAL:
				if potential_send >= dst.troops:
					utility = 200.0 + (potential_send - dst.troops) * 5.0 - (dist * 0.07)
				else:
					# Si está al límite de capacidad, conviene desgastar la base neutral
					utility = (80.0 if is_near_cap else 30.0) - (dst.troops - potential_send) * 2.5 - (dist * 0.07)
			elif dst.faction == faction:
				# Refuerzo a base propia si está débil
				if dst.troops < 12 and (src.troops > 20 or is_near_cap):
					utility = 90.0 + (15 - dst.troops) * 3.0 - (dist * 0.05)
			else:
				# Ataque a rival o jugador
				if potential_send > (dst.troops + 1):
					utility = 170.0 + (potential_send - dst.troops) * 6.0 - (dist * 0.06)
					if dst.faction == GameManager.Faction.PLAYER:
						utility += 25.0
				else:
					utility = (60.0 if is_near_cap else 20.0) - (dst.troops - potential_send) * 3.0 - (dist * 0.06)
					
			if utility > highest_utility:
				highest_utility = utility
				best_target = dst
				
		if best_target != null and highest_utility > 35.0:
			battle_controller.dispatch_troops(src, best_target, 1.0)
			actions_executed += 1
			if actions_executed >= 2:
				break
