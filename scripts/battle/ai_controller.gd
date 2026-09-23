extends Node
class_name AIController

## AIController: Manejo de decisiones estratégicas autónomas para facciones enemigas

var battle_controller: Node
var faction: int = GameManager.Faction.ENEMY_1
var think_timer: float = 0.0
var think_interval: float = 1.8

func setup(p_battle_controller: Node, p_faction: int) -> void:
	battle_controller = p_battle_controller
	faction = p_faction
	think_interval = randf_range(1.5, 2.3)
	think_timer = randf_range(0.2, think_interval)

func _process(delta: float) -> void:
	if not battle_controller or battle_controller.is_game_over:
		return
		
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = randf_range(1.4, 2.2)
		_evaluate_and_execute()

func _evaluate_and_execute() -> void:
	if not battle_controller:
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
		return # Facción sin territorios
		
	# Para cada base propia con suficientes tropas, evaluar la mejor jugada
	for src in my_bases:
		if src.troops < 6:
			continue
			
		var best_target: BaseNode = null
		var highest_utility: float = -9999.0
		var potential_send = int(floor(src.troops * 0.5))
		
		for dst in all_bases:
			if dst == src:
				continue
				
			var dist = src.global_position.distance_to(dst.global_position)
			var utility: float = 0.0
			
			if dst.faction == GameManager.Faction.NEUTRAL:
				# Prioridad alta para bases neutrales que podamos capturar
				if potential_send >= dst.troops:
					utility = 200.0 + (potential_send - dst.troops) * 4.0 - (dist * 0.08)
				else:
					utility = 50.0 - (dst.troops - potential_send) * 3.0 - (dist * 0.08)
			elif dst.faction == faction:
				# Refuerzo a base propia si está débil
				if dst.troops < 10 and src.troops > 25:
					utility = 80.0 + (15 - dst.troops) * 3.0 - (dist * 0.06)
			else:
				# Ataque a rival o jugador
				if potential_send > (dst.troops + 2):
					utility = 160.0 + (potential_send - dst.troops) * 5.0 - (dist * 0.07)
				else:
					utility = 20.0 - (dst.troops - potential_send) * 4.0 - (dist * 0.07)
					
			if utility > highest_utility:
				highest_utility = utility
				best_target = dst
				
		# Si la mejor oportunidad supera el umbral, ejecutar el envío
		if best_target != null and highest_utility > 40.0:
			battle_controller.dispatch_troops(src, best_target, 0.5)
			# Un solo envío por ciclo para no vaciar todas las bases a la vez
			break
