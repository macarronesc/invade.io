extends Node2D
class_name BattleController

## BattleController: Gestor de la partida, entrada del jugador, IA y condiciones de fin

const BaseNodeScene = preload("res://scenes/battle/base_node.tscn")
const TroopScene = preload("res://scenes/battle/troop.tscn")
const TerritoryMap2DScript = preload("res://scripts/battle/territory_map_2d.gd")

@export var level_id: String = "europe_1"

var bases: Array[BaseNode] = []
var active_troops: Array[Troop] = []
var ai_controllers: Array[AIController] = []

var selected_sources: Array[BaseNode] = []
var hovered_target: BaseNode = null
var candidate_chained_base: BaseNode = null
var is_dragging: bool = false
var drag_current_pos: Vector2 = Vector2.ZERO

var is_game_over: bool = false
var battle_time: float = 0.0
var target_time: float = 45.0
var level_data: Dictionary = {}
var dispatch_percentage: float = 1.0

@onready var bases_container: Node2D = get_node_or_null("BasesContainer")
@onready var troops_container: Node2D = get_node_or_null("TroopsContainer")
@onready var arrow_overlay: Node2D = get_node_or_null("ArrowOverlay")
@onready var territory_map: Node2D = get_node_or_null("TerritoryMap")

func _ready() -> void:
	if GameManager.current_level_id != "":
		level_id = GameManager.current_level_id
	load_level(level_id)
	EventBus.base_captured.connect(_on_base_captured)
	EventBus.troop_arrived.connect(_on_troop_arrived)
	if arrow_overlay:
		arrow_overlay.draw.connect(_draw_drag_overlay)

func toggle_dispatch_percentage() -> float:
	dispatch_percentage = 1.0
	EventBus.dispatch_percentage_changed.emit(dispatch_percentage)
	return dispatch_percentage

func load_level(p_level_id: String) -> void:
	level_id = p_level_id
	level_data = LevelDatabase.get_level_data(level_id)
	target_time = level_data.get("target_time", 45.0)
	battle_time = 0.0
	is_game_over = false
	dispatch_percentage = 1.0
	selected_sources.clear()
	hovered_target = null
	candidate_chained_base = null
	
	# Limpiar elementos previos
	for b in bases:
		if is_instance_valid(b):
			b.queue_free()
	bases.clear()
	
	for t in active_troops:
		if is_instance_valid(t):
			t.queue_free()
	active_troops.clear()
	
	for ai in ai_controllers:
		if is_instance_valid(ai):
			ai.queue_free()
	ai_controllers.clear()
	
	# Instanciar bases según los datos del nivel
	var base_defs = level_data.get("bases", [])
	var enemy_factions_present: Array[int] = []
	
	for b_def in base_defs:
		var base_inst: BaseNode = BaseNodeScene.instantiate()
		if bases_container:
			bases_container.add_child(base_inst)
		else:
			add_child(base_inst)
		base_inst.setup(b_def)
		bases.append(base_inst)
		
		var f = base_inst.faction
		if f != GameManager.Faction.NEUTRAL and f != GameManager.Faction.PLAYER:
			if not enemy_factions_present.has(f):
				enemy_factions_present.append(f)
				
	# Generar mapa político de estados y partición territorial Voronoi
	if territory_map and is_instance_valid(territory_map):
		territory_map.generate_map(bases)
				
	# Instanciar IA para cada facción enemiga
	for ef in enemy_factions_present:
		var ai: AIController = AIController.new()
		add_child(ai)
		ai.setup(self, ef)
		ai_controllers.append(ai)
		
	EventBus.battle_started.emit(level_id)

func _process(delta: float) -> void:
	if not is_game_over:
		battle_time += delta
		_process_troop_collisions()
		_check_game_over_conditions()
	queue_redraw()
	if arrow_overlay:
		arrow_overlay.queue_redraw()

func _process_troop_collisions() -> void:
	var i = 0
	while i < active_troops.size():
		var t1 = active_troops[i]
		if not is_instance_valid(t1) or t1.is_queued_for_deletion() or t1.count <= 0:
			i += 1
			continue
		var j = i + 1
		var t1_removed = false
		while j < active_troops.size():
			var t2 = active_troops[j]
			if not is_instance_valid(t2) or t2.is_queued_for_deletion() or t2.count <= 0:
				j += 1
				continue
			# Colisión en el mapa entre tropas enemigas enfrentadas
			if t1.faction != t2.faction and t1.faction != GameManager.Faction.NEUTRAL and t2.faction != GameManager.Faction.NEUTRAL:
				if t1.beads.is_empty() or t2.beads.is_empty():
					# Fallback para tests unitarios que configuran directamente global_position sin beads
					if t1.global_position.distance_to(t2.global_position) <= 26.0:
						if t1.count > t2.count:
							t1.count -= t2.count
							t1.update_count()
							active_troops.erase(t2)
							if t2.is_inside_tree():
								t2.queue_free()
							else:
								t2.free()
							AudioManager.play_reinforce()
							continue
						elif t2.count > t1.count:
							t2.count -= t1.count
							t2.update_count()
							active_troops.erase(t1)
							if t1.is_inside_tree():
								t1.queue_free()
							else:
								t1.free()
							AudioManager.play_reinforce()
							t1_removed = true
							break
						else:
							# Cancelación simétrica exacta
							active_troops.erase(t2)
							active_troops.erase(t1)
							if t1.is_inside_tree():
								t1.queue_free()
							else:
								t1.free()
							if t2.is_inside_tree():
								t2.queue_free()
							else:
								t2.free()
							AudioManager.play_reinforce()
							t1_removed = true
							break
				else:
					# Colisión perla a perla entre hileras de tropas
					var is_head_on = (t1.origin_base != null and t2.origin_base != null and t1.origin_base == t2.target_base and t1.target_base == t2.origin_base)
					var collided = false
					for b1 in t1.beads:
						if b1["absorbed"] or b1["dist"] < 0:
							continue
						var p1 = t1.start_pos + t1.move_dir * b1["dist"]
						for b2 in t2.beads:
							if b2["absorbed"] or b2["dist"] < 0:
								continue
							var p2 = t2.start_pos + t2.move_dir * b2["dist"]
							var should_collide = p1.distance_to(p2) <= 20.0
							if not should_collide and is_head_on:
								if (b1["dist"] + b2["dist"]) >= (t1.path_length - 8.0):
									should_collide = true
									
							if should_collide:
								b1["absorbed"] = true
								b2["absorbed"] = true
								t1.count -= 1
								t2.count -= 1
								t1.update_count()
								t2.update_count()
								AudioManager.play_troop_absorb(false)
								collided = true
								break
						if t1.count <= 0 or t2.count <= 0:
							break
							
					if collided:
						if t1.count <= 0:
							active_troops.erase(t1)
							if t1.is_inside_tree():
								t1.queue_free()
							else:
								t1.free()
							t1_removed = true
						if t2.count <= 0:
							active_troops.erase(t2)
							if t2.is_inside_tree():
								t2.queue_free()
							else:
								t2.free()
						else:
							j += 1
							
						if t1_removed:
							break
					else:
						j += 1
			else:
				j += 1
		if not t1_removed:
			i += 1

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_press(get_global_mouse_position())
			else:
				_handle_release(get_global_mouse_position())
	elif event is InputEventMouseMotion and is_dragging:
		_handle_drag(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(get_global_mouse_position())
		else:
			_handle_release(get_global_mouse_position())
	elif event is InputEventScreenDrag and is_dragging:
		_handle_drag(get_global_mouse_position())

func _handle_press(pos: Vector2) -> void:
	var base = _get_base_at(pos)
	if base and base.faction == GameManager.Faction.PLAYER:
		is_dragging = true
		selected_sources.clear()
		_add_selected_source(base)
		drag_current_pos = pos
		hovered_target = null
		candidate_chained_base = null
		AudioManager.play_click()

func _handle_drag(pos: Vector2) -> void:
	drag_current_pos = pos
	var base = _get_base_at(pos)
	
	if base != null:
		# Si teníamos una base candidata previa y ahora entramos en OTRA base distinta,
		# la candidata previa queda confirmada como nodo intermedio de encadenamiento
		if candidate_chained_base != null and is_instance_valid(candidate_chained_base) and candidate_chained_base != base:
			_add_selected_source(candidate_chained_base)
			candidate_chained_base = null
			AudioManager.play_click()
			
		if not selected_sources.has(base):
			hovered_target = base
			# Si es aliada, marcarla como candidata para encadenar si el arrastre sigue adelante
			if base.faction == GameManager.Faction.PLAYER:
				candidate_chained_base = base
		else:
			hovered_target = null
	else:
		# Cursor en espacio abierto
		if candidate_chained_base != null and is_instance_valid(candidate_chained_base):
			if not candidate_chained_base.is_point_inside(pos):
				_add_selected_source(candidate_chained_base)
				candidate_chained_base = null
				AudioManager.play_click()
		hovered_target = null

func _handle_release(pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false
	
	var target = _get_base_at(pos)
	
	# Si teníamos una base aliada candidata y soltamos sobre un objetivo distinto a ella,
	# la base candidata debe sumarse al asalto combinado
	if candidate_chained_base != null and is_instance_valid(candidate_chained_base):
		if target != candidate_chained_base:
			_add_selected_source(candidate_chained_base)
		candidate_chained_base = null
	
	if target != null:
		# Si soltamos sobre una base que estaba en selected_sources
		if selected_sources.has(target):
			if selected_sources.size() > 1 and selected_sources.back() == target:
				# El usuario arrastró de una base hacia esta base aliada para reforzarla
				selected_sources.erase(target)
				target.set_selected(false)
				for src in selected_sources:
					dispatch_troops(src, target, dispatch_percentage)
		else:
			# Objetivo exterior (neutral, enemigo o aliado que no formaba parte del origen)
			for src in selected_sources:
				dispatch_troops(src, target, dispatch_percentage)
				
	for src in selected_sources:
		if is_instance_valid(src):
			src.set_selected(false)
	selected_sources.clear()
	hovered_target = null
	candidate_chained_base = null

func _add_selected_source(base: BaseNode) -> void:
	if not selected_sources.has(base):
		selected_sources.append(base)
		base.set_selected(true)

func _get_base_at(pos: Vector2) -> BaseNode:
	for b in bases:
		if is_instance_valid(b) and b.is_point_inside(pos):
			return b
	return null

func dispatch_troops(from_base: BaseNode, to_base: BaseNode, percentage: float = 1.0) -> void:
	if not is_instance_valid(from_base) or not is_instance_valid(to_base):
		return
	if from_base == to_base:
		return
		
	var count = from_base.send_troops(percentage)
	if count <= 0:
		return
		
	var troop: Troop = TroopScene.instantiate()
	if troops_container:
		troops_container.add_child(troop)
	else:
		add_child(troop)
	troop.setup(from_base, to_base, count, from_base.faction)
	active_troops.append(troop)
	
	if from_base.faction == GameManager.Faction.PLAYER:
		AudioManager.play_launch()
		
	EventBus.troops_dispatched.emit(from_base, to_base, count, from_base.faction)

func _on_troop_arrived(troop: Troop, _target_base: BaseNode) -> void:
	if active_troops.has(troop):
		active_troops.erase(troop)

func _on_base_captured(_base: BaseNode, _prev_faction: int, _new_faction: int) -> void:
	_check_game_over_conditions()

func _check_game_over_conditions() -> void:
	if is_game_over:
		return
		
	var player_has_bases = false
	var enemy_has_bases = false
	
	for b in bases:
		if not is_instance_valid(b):
			continue
		if b.faction == GameManager.Faction.PLAYER:
			player_has_bases = true
		elif b.faction != GameManager.Faction.NEUTRAL:
			enemy_has_bases = true
			
	var player_has_troops = false
	var enemy_has_troops = false
	
	for t in active_troops:
		if not is_instance_valid(t) or t.is_queued_for_deletion() or t.count <= 0:
			continue
		if t.faction == GameManager.Faction.PLAYER:
			player_has_troops = true
		elif t.faction != GameManager.Faction.NEUTRAL:
			enemy_has_troops = true
			
	# Condición de Victoria: Cero bases enemigas y cero tropas enemigas
	if not enemy_has_bases and not enemy_has_troops:
		_trigger_victory()
	# Condición de Derrota: El jugador no tiene bases ni tropas
	elif not player_has_bases and not player_has_troops:
		_trigger_defeat()

func _trigger_victory() -> void:
	is_game_over = true
	var stars = 1
	if battle_time <= target_time:
		stars = 3
	elif battle_time <= target_time * 1.5:
		stars = 2
		
	# Cálculo de recompensas
	var base_gold = 60
	var player_bases_count = 0
	for b in bases:
		if is_instance_valid(b) and b.faction == GameManager.Faction.PLAYER:
			player_bases_count += 1
	var total_gold = int((base_gold + player_bases_count * 15) * GameManager.get_gold_multiplier())
	
	GameManager.complete_level(level_id, stars)
	GameManager.add_coins(total_gold)
	AudioManager.play_victory()
	
	var stats = {
		"level_id": level_id,
		"stars": stars,
		"time": battle_time,
		"gold_earned": total_gold,
		"bases_conquered": player_bases_count
	}
	EventBus.battle_won.emit(stats)

func _trigger_defeat() -> void:
	is_game_over = true
	AudioManager.play_defeat()
	EventBus.battle_lost.emit()

func get_dominance_ratios() -> Dictionary:
	var counts = {
		GameManager.Faction.PLAYER: 0,
		GameManager.Faction.ENEMY_1: 0,
		GameManager.Faction.ENEMY_2: 0,
		GameManager.Faction.ENEMY_3: 0,
		GameManager.Faction.NEUTRAL: 0
	}
	var total: int = 0
	for b in bases:
		if is_instance_valid(b):
			counts[b.faction] = counts.get(b.faction, 0) + b.troops
			total += b.troops
			
	for t in active_troops:
		if is_instance_valid(t) and not t.is_queued_for_deletion() and t.count > 0:
			counts[t.faction] = counts.get(t.faction, 0) + t.count
			total += t.count
			
	var ratios = {}
	for f in counts:
		ratios[f] = (float(counts[f]) / float(total)) if total > 0 else 0.0
	return ratios

func _draw() -> void:
	# Dibujar elementos cartográficos de fondo estilizados
	var continent_id = level_data.get("continent", "europe")
	_draw_cartographic_grid(continent_id)

	# Si no hay nodo overlay separado (ej. tests unitarios), dibujar flechas directamente
	if not arrow_overlay:
		_draw_drag_overlay()

func _draw_drag_overlay() -> void:
	if not is_dragging or selected_sources.is_empty():
		return
		
	var canvas: CanvasItem = arrow_overlay if (arrow_overlay and is_instance_valid(arrow_overlay)) else self
	var player_color = GameManager.FACTION_COLORS[GameManager.Faction.PLAYER]
	var end_global = hovered_target.global_position if (hovered_target and is_instance_valid(hovered_target)) else drag_current_pos
	var end_pt = canvas.to_local(end_global)
	
	for src in selected_sources:
		if not is_instance_valid(src):
			continue
		var start_pt = canvas.to_local(src.global_position)
		
		# Línea principal translúcida con brillo y borde
		canvas.draw_line(start_pt, end_pt, Color(1, 1, 1, 0.45), 8.0, true)
		canvas.draw_line(start_pt, end_pt, Color(player_color.r, player_color.g, player_color.b, 0.9), 4.5, true)
		
		# Cabeza de flecha orientada
		if start_pt.distance_to(end_pt) > 25.0:
			var dir = (end_pt - start_pt).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var arrow_size = 22.0
			var p1 = end_pt
			var p2 = end_pt - dir * arrow_size + normal * (arrow_size * 0.5)
			var p3 = end_pt - dir * arrow_size - normal * (arrow_size * 0.5)
			canvas.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color.WHITE)
			
	# Anillo de fijación sobre el objetivo actual
	if hovered_target and is_instance_valid(hovered_target):
		var h_pos = canvas.to_local(hovered_target.global_position)
		canvas.draw_arc(h_pos, hovered_target.radius + 16.0, 0, TAU, 48, Color(1, 1, 1, 0.95), 3.5, true)

func _draw_cartographic_grid(continent: String) -> void:
	# Dibujar retícula cartográfica de fondo y título del continente
	var grid_color = Color(1.0, 1.0, 1.0, 0.04)
	for x in range(120, 1080, 160):
		draw_line(Vector2(x, 200), Vector2(x, 1850), grid_color, 1.0)
	for y in range(250, 1850, 160):
		draw_line(Vector2(40, y), Vector2(1040, y), grid_color, 1.0)
		
	# Conexiones sutiles de ruta entre bases del nivel
	var route_color = Color(1.0, 1.0, 1.0, 0.07)
	for i in range(bases.size()):
		var b1 = bases[i]
		if not is_instance_valid(b1): continue
		for j in range(i + 1, bases.size()):
			var b2 = bases[j]
			if not is_instance_valid(b2): continue
			if b1.global_position.distance_to(b2.global_position) < 450.0:
				draw_dashed_line(to_local(b1.global_position), to_local(b2.global_position), route_color, 2.0, 8.0, true, true)
