extends Node
class_name AIController

## AIController: Manejo de decisiones estratégicas autónomas para facciones enemigas con arquetipos

enum AIArchetype {
	AGGRESSIVE = 0,
	EXPANSIVE = 1,
	OPPORTUNIST = 2
}

var battle_controller: BattleController
var faction: int = GameManager.Faction.ENEMY_1
var archetype: AIArchetype = AIArchetype.AGGRESSIVE
var think_timer: float = 0.0
var think_interval: float = 1.8
## Escala del intervalo de decisión según la dificultad del nivel (<1 = piensa más rápido)
var think_scale: float = 1.0
## Tropas en marcha por base objetivo: {BaseNode: {faction: unidades}}
var _incoming: Dictionary = {}

func setup(p_battle_controller: BattleController, p_faction: int, p_archetype = null) -> void:
	battle_controller = p_battle_controller
	faction = p_faction
	if battle_controller:
		think_scale = lerpf(1.25, 0.7, LevelDatabase.get_difficulty(battle_controller.level_id))
	
	if p_archetype != null:
		set_archetype(p_archetype)
	elif battle_controller and battle_controller.level_data:
		var level_archetypes = battle_controller.level_data.get("ai_archetypes", {})
		var faction_key_str = ""
		match faction:
			GameManager.Faction.ENEMY_1: faction_key_str = "enemy_1"
			GameManager.Faction.ENEMY_2: faction_key_str = "enemy_2"
			GameManager.Faction.ENEMY_3: faction_key_str = "enemy_3"
			
		if level_archetypes.has(faction):
			set_archetype(level_archetypes[faction])
		elif level_archetypes.has(str(faction)):
			set_archetype(level_archetypes[str(faction)])
		elif faction_key_str != "" and level_archetypes.has(faction_key_str):
			set_archetype(level_archetypes[faction_key_str])
		elif faction_key_str != "" and level_archetypes.has(faction_key_str.replace("_", "")):
			set_archetype(level_archetypes[faction_key_str.replace("_", "")])
		else:
			_assign_default_archetype_by_faction()
	else:
		_assign_default_archetype_by_faction()
		
	_configure_timers_for_archetype()

func set_archetype(p_archetype) -> void:
	if p_archetype is AIArchetype or p_archetype is int:
		archetype = p_archetype as AIArchetype
	elif p_archetype is String:
		var s = (p_archetype as String).to_lower().strip_edges()
		if "aggress" in s or "agresor" in s:
			archetype = AIArchetype.AGGRESSIVE
		elif "expan" in s:
			archetype = AIArchetype.EXPANSIVE
		elif "opport" in s or "oportun" in s:
			archetype = AIArchetype.OPPORTUNIST
		else:
			archetype = AIArchetype.AGGRESSIVE
	_configure_timers_for_archetype()

func _assign_default_archetype_by_faction() -> void:
	match faction:
		GameManager.Faction.ENEMY_1:
			archetype = AIArchetype.AGGRESSIVE # El Agresor (Rojo)
		GameManager.Faction.ENEMY_2:
			archetype = AIArchetype.EXPANSIVE  # El Expansivo (Amarillo)
		GameManager.Faction.ENEMY_3:
			archetype = AIArchetype.OPPORTUNIST # El Oportunista (Verde)
		_:
			archetype = AIArchetype.AGGRESSIVE

func _configure_timers_for_archetype() -> void:
	match archetype:
		AIArchetype.AGGRESSIVE:
			think_interval = randf_range(1.1, 1.7)
		AIArchetype.EXPANSIVE:
			think_interval = randf_range(1.3, 1.9)
		AIArchetype.OPPORTUNIST:
			think_interval = randf_range(1.5, 2.3)
	think_interval *= think_scale
	think_timer = randf_range(0.2, think_interval)

func _process(delta: float) -> void:
	if not battle_controller or battle_controller.is_game_over:
		return
		
	think_timer -= delta
	if think_timer <= 0.0:
		_configure_timers_for_archetype()
		_evaluate_and_execute()

## Segundos iniciales en los que la IA no ataca al jugador (12 s en el primer nivel, 0 en el último)
func get_player_grace_period() -> float:
	return lerpf(12.0, 0.0, LevelDatabase.get_difficulty(battle_controller.level_id)) if battle_controller else 0.0

func _rebuild_incoming() -> void:
	_incoming.clear()
	for t in battle_controller.active_troops:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.count > 0 and is_instance_valid(t.target_base):
			_add_incoming(t.target_base, t.faction, t.count)

func _add_incoming(dst: BaseNode, f: int, amount: int) -> void:
	var per_faction: Dictionary = _incoming.get_or_add(dst, {})
	per_faction[f] = per_faction.get(f, 0) + amount

## Atacantes que harían falta al llegar: defensa actual + producción durante el viaje,
## descontando los ataques ya en camino y sumando los refuerzos que va a recibir
func get_projected_defense(src: BaseNode, dst: BaseNode) -> float:
	var def := float(dst.get_effective_defense())
	var m := dst.get_defense_multiplier()
	if dst.faction != GameManager.Faction.NEUTRAL and dst.faction != faction:
		var travel_time := src.global_position.distance_to(dst.global_position) / Troop.BASE_SPEED
		def += dst.get_production_rate() * travel_time * m
	var per_faction: Dictionary = _incoming.get(dst, {})
	for f in per_faction:
		def += per_faction[f] * m if f == dst.faction else -per_faction[f]
	return def

func evaluate_target_utility(src: BaseNode, dst: BaseNode) -> float:
	if not is_instance_valid(src) or not is_instance_valid(dst) or src == dst:
		return -9999.0
		
	var dist = src.global_position.distance_to(dst.global_position)
	var potential_send = src.troops - 1
	var projected = get_projected_defense(src, dst)
	# Objetivo ya cubierto por nuestras tropas en marcha: no malgastar otro envío
	if dst.faction != faction and projected < -2.0 and _incoming.get(dst, {}).get(faction, 0) > 0:
		return -500.0
	var effective_def = ceili(maxf(projected, 0.0))
	var is_near_cap = src.troops >= (src.max_capacity - 5)
	if dst.faction != faction:
		# Periodo de gracia al inicio de los niveles fáciles antes de atacar al jugador
		if dst.faction == GameManager.Faction.PLAYER and battle_controller and battle_controller.battle_time < get_player_grace_period():
			return -9999.0
		# Sin goteos inútiles: sólo atacar si se puede ganar, salvo que la base esté a punto de llenarse
		if potential_send <= effective_def and not is_near_cap:
			return -100.0
	var utility: float = 0.0
	
	match archetype:
		AIArchetype.AGGRESSIVE:
			# El Agresor (Rojo): Prioriza asaltar bases vulnerables del jugador y rivales cercanos
			if dst.faction == GameManager.Faction.PLAYER or (dst.faction != faction and dst.faction != GameManager.Faction.NEUTRAL):
				utility = 220.0
				if dst.faction == GameManager.Faction.PLAYER:
					utility += 80.0 # Fijación prioritaria en eliminar al jugador
				if potential_send > effective_def:
					utility += (potential_send - effective_def) * 6.0
					if dst.troops <= 8:
						utility += 50.0 + (8 - dst.troops) * 4.0 # Asalto relámpago a bases vulnerables
				else:
					var deficit = effective_def - potential_send
					utility -= deficit * 8.5 # Fuerte desincentivo a suicidarse contra bases inexpugnables
					if is_near_cap:
						utility += 40.0
				if dst.base_type == BaseNode.BaseType.FACTORY:
					utility += 40.0 # Fábricas enemigas son presas fáciles
				elif dst.base_type == BaseNode.BaseType.FORTRESS and potential_send < effective_def:
					utility -= 60.0
				utility -= dist * 0.10
			elif dst.faction == GameManager.Faction.NEUTRAL:
				utility = 100.0 # Neutrales son de menor prioridad para el agresor
				if potential_send >= effective_def:
					utility += (potential_send - effective_def) * 3.0
				else:
					utility -= (effective_def - potential_send) * 5.0
				utility -= dist * 0.07
			else:
				# Refuerzo aliado: baja prioridad para el agresor
				if dst.troops >= dst.max_capacity:
					utility = -50.0
				elif dst.troops < 8 and (src.troops > 16 or is_near_cap):
					utility = 60.0 + (8 - dst.troops) * 2.0 - dist * 0.05
				else:
					utility = -50.0

		AIArchetype.EXPANSIVE:
			# El Expansivo (Amarillo): Prioriza expandirse capturando neutrales y asegurando fábricas
			if dst.faction == GameManager.Faction.NEUTRAL:
				utility = 260.0 # Prioridad máxima: expansión territorial
				if dst.base_type == BaseNode.BaseType.FACTORY:
					utility += 120.0 # Asegurar fábricas para ventaja de producción masiva
				if potential_send >= effective_def:
					utility += (potential_send - effective_def) * 5.0
				else:
					utility -= (effective_def - potential_send) * 4.0
					if is_near_cap:
						utility += 50.0
				utility -= dist * 0.06
			elif dst.faction != faction:
				utility = 150.0 # Hostiles secundarios frente a neutrales
				if dst.base_type == BaseNode.BaseType.FACTORY:
					utility += 110.0 # Conquistar fábricas enemigas para acumular producción
				if potential_send > effective_def:
					utility += (potential_send - effective_def) * 5.0
				else:
					utility -= (effective_def - potential_send) * 7.5
				utility -= dist * 0.07
			else:
				# Refuerzo a bases aliadas, especialmente fábricas propias vulnerables
				if dst.troops >= dst.max_capacity:
					utility = -40.0
				elif dst.base_type == BaseNode.BaseType.FACTORY and dst.troops < 15:
					utility = 140.0 + (15 - dst.troops) * 4.0 - dist * 0.05
				elif dst.troops < 10 and (src.troops > 16 or is_near_cap):
					utility = 85.0 + (10 - dst.troops) * 3.0 - dist * 0.05
				else:
					utility = -30.0

		AIArchetype.OPPORTUNIST:
			# El Oportunista (Verde): Espera a que las bases queden desprotegidas tras emitir asalto o se atrinchera
			if dst.faction == faction:
				# Si el origen es una fortaleza, retener posición defensiva y no desmantelar guarnición
				if src.base_type == BaseNode.BaseType.FORTRESS and src.troops < (src.max_capacity - 5):
					return -80.0
				# Atrincherarse en fortalezas aliadas desde otras bases
				if dst.base_type == BaseNode.BaseType.FORTRESS:
					if dst.troops >= dst.max_capacity:
						utility = -30.0 # Ya se encuentra al máximo de guarnición
					elif dst.troops < (dst.max_capacity - 10):
						utility = 240.0 + (dst.max_capacity - dst.troops) * 2.0 - dist * 0.04
					else:
						utility = 20.0 # Casi al máximo, por debajo del umbral de disparo
				elif dst.troops < 8 and (src.troops > 15 or is_near_cap):
					utility = 90.0 + (8 - dst.troops) * 3.0 - dist * 0.05
				else:
					utility = -40.0
			elif dst.faction != faction and dst.faction != GameManager.Faction.NEUTRAL:
				# Hostil: buscar bases desprotegidas ("atacar por la espalda")
				utility = 130.0
				if dst.troops <= 4:
					# Gran bonificación de oportunidad ante base desangrada tras despachar asalto
					utility += 180.0 + (5 - dst.troops) * 25.0
				if potential_send > effective_def:
					utility += (potential_send - effective_def) * 6.0
				else:
					# Muy conservador atacando bases con fuerte guarnición
					utility -= (effective_def - potential_send) * 6.0
				if dst.base_type == BaseNode.BaseType.FORTRESS:
					if potential_send > effective_def:
						utility += 90.0
					else:
						utility -= 80.0
				utility -= dist * 0.06
			else:
				# Neutral: capturar sólo si es muy barato o es fortaleza
				if dst.troops <= 5:
					utility = 190.0 + (potential_send - effective_def) * 4.0 - dist * 0.06
					if dst.base_type == BaseNode.BaseType.FORTRESS:
						utility += 80.0
				elif potential_send >= (effective_def + 3):
					utility = 140.0 + (potential_send - effective_def) * 3.0 - dist * 0.06
				else:
					utility = 20.0 - (effective_def - potential_send) * 5.0 - dist * 0.06

	return utility

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
	_rebuild_incoming()
		
	# 1. Evaluar si podemos coordinar un ataque conjunto multi-base sobre un objetivo clave
	if my_bases.size() >= 2:
		var target_candidate: BaseNode = null
		var highest_target_score: float = -100.0
		
		for dst in other_bases:
			if not is_instance_valid(dst):
				continue
			if dst.faction == GameManager.Faction.PLAYER and battle_controller.battle_time < get_player_grace_period():
				continue
			var combined_send = 0
			var avg_dist = 0.0
			var participating_bases: Array[BaseNode] = []
			for src in my_bases:
				if src.troops > 2:
					var dist = src.global_position.distance_to(dst.global_position)
					if dist < 900.0:
						combined_send += (src.troops - 1)
						avg_dist += dist
						participating_bases.append(src)
						
			if participating_bases.size() < 2:
				continue
				
			avg_dist /= max(1, participating_bases.size())
			var effective_def = get_projected_defense(participating_bases[0], dst)
			
			if combined_send > (effective_def + 3):
				var score = (combined_send - effective_def) * 3.5 - (avg_dist * 0.05)
				match archetype:
					AIArchetype.AGGRESSIVE:
						if dst.faction == GameManager.Faction.PLAYER:
							score += 60.0
						score += 30.0
					AIArchetype.EXPANSIVE:
						if dst.faction == GameManager.Faction.NEUTRAL:
							score += 50.0
						if dst.base_type == BaseNode.BaseType.FACTORY:
							score += 45.0
					AIArchetype.OPPORTUNIST:
						if dst.troops <= 4:
							score += 70.0
						if dst.base_type == BaseNode.BaseType.FORTRESS:
							score += 40.0
							
				if score > highest_target_score:
					highest_target_score = score
					target_candidate = dst
					
		if target_candidate and highest_target_score > 30.0:
			var sent_count = 0
			for src in my_bases:
				if src.troops > 2 and src.global_position.distance_to(target_candidate.global_position) < 900.0:
					_add_incoming(target_candidate, faction, src.troops - 1)
					battle_controller.dispatch_troops(src, target_candidate)
					sent_count += 1
					if sent_count >= 3:
						break
			if sent_count >= 2:
				return
				
	# 2. Evaluación táctica individual por base
	var actions_executed = 0
	for src in my_bases:
		if src.troops < 2:
			continue
		if archetype == AIArchetype.OPPORTUNIST and src.troops < 3:
			continue
			
		var best_target: BaseNode = null
		var highest_utility: float = -9999.0
		
		for dst in all_bases:
			if dst == src or not is_instance_valid(dst):
				continue
				
			var utility = evaluate_target_utility(src, dst)
			if utility > highest_utility:
				highest_utility = utility
				best_target = dst
				
		var threshold = 35.0
		if archetype == AIArchetype.AGGRESSIVE:
			threshold = 25.0
		elif archetype == AIArchetype.OPPORTUNIST:
			threshold = 40.0
			
		if best_target != null and highest_utility > threshold:
			_add_incoming(best_target, faction, src.troops - 1)
			battle_controller.dispatch_troops(src, best_target)
			actions_executed += 1
			if actions_executed >= 2:
				break

