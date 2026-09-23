extends Node2D
class_name BattleController

## BattleController: Gestor de la partida, entrada del jugador, IA y condiciones de fin

const BaseNodeScene = preload("res://scenes/battle/base_node.tscn")
const TroopScene = preload("res://scenes/battle/troop.tscn")

@export var level_id: String = "europe_1"

var bases: Array[BaseNode] = []
var active_troops: Array[Troop] = []
var ai_controllers: Array[AIController] = []

var selected_sources: Array[BaseNode] = []
var hovered_target: BaseNode = null
var is_dragging: bool = false
var drag_current_pos: Vector2 = Vector2.ZERO

var is_game_over: bool = false
var battle_time: float = 0.0
var target_time: float = 45.0
var level_data: Dictionary = {}

@onready var bases_container: Node2D = $BasesContainer
@onready var troops_container: Node2D = $TroopsContainer

func _ready() -> void:
	if GameManager.current_level_id != "":
		level_id = GameManager.current_level_id
	load_level(level_id)
	EventBus.base_captured.connect(_on_base_captured)
	EventBus.troop_arrived.connect(_on_troop_arrived)

func load_level(p_level_id: String) -> void:
	level_id = p_level_id
	level_data = LevelDatabase.get_level_data(level_id)
	target_time = level_data.get("target_time", 45.0)
	battle_time = 0.0
	is_game_over = false
	
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
		bases_container.add_child(base_inst)
		base_inst.setup(b_def)
		bases.append(base_inst)
		
		var f = base_inst.faction
		if f != GameManager.Faction.NEUTRAL and f != GameManager.Faction.PLAYER:
			if not enemy_factions_present.has(f):
				enemy_factions_present.append(f)
				
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
		_check_game_over_conditions()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_press(event.position)
			else:
				_handle_release(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		_handle_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventScreenDrag and is_dragging:
		_handle_drag(event.position)

func _handle_press(pos: Vector2) -> void:
	var base = _get_base_at(pos)
	if base and base.faction == GameManager.Faction.PLAYER:
		is_dragging = true
		selected_sources.clear()
		_add_selected_source(base)
		drag_current_pos = pos
		hovered_target = null
		AudioManager.play_click()

func _handle_drag(pos: Vector2) -> void:
	drag_current_pos = pos
	var base = _get_base_at(pos)
	
	# Soporte para encadenar múltiples bases aliadas (multi-select drag)
	if base and base.faction == GameManager.Faction.PLAYER and not selected_sources.has(base):
		_add_selected_source(base)
		AudioManager.play_click()
		
	if base and not selected_sources.has(base):
		hovered_target = base
	else:
		hovered_target = null

func _handle_release(pos: Vector2) -> void:
	if not is_dragging:
		return
	is_dragging = false
	
	var target = _get_base_at(pos)
	if target and not selected_sources.has(target):
		for src in selected_sources:
			dispatch_troops(src, target, 0.5)
			
	for src in selected_sources:
		src.set_selected(false)
	selected_sources.clear()
	hovered_target = null

func _add_selected_source(base: BaseNode) -> void:
	if not selected_sources.has(base):
		selected_sources.append(base)
		base.set_selected(true)

func _get_base_at(pos: Vector2) -> BaseNode:
	for b in bases:
		if is_instance_valid(b) and b.is_point_inside(pos):
			return b
	return null

func dispatch_troops(from_base: BaseNode, to_base: BaseNode, percentage: float = 0.5) -> void:
	if not is_instance_valid(from_base) or not is_instance_valid(to_base):
		return
		
	var count = from_base.send_troops(percentage)
	if count <= 0:
		return
		
	var troop: Troop = TroopScene.instantiate()
	troops_container.add_child(troop)
	troop.setup(from_base, to_base, count, from_base.faction)
	active_troops.append(troop)
	
	if from_base.faction == GameManager.Faction.PLAYER:
		AudioManager.play_launch()
		
	EventBus.troops_dispatched.emit(from_base, to_base, count, from_base.faction)

func _on_troop_arrived(troop: Troop, _target_base: BaseNode) -> void:
	active_troops.erase(troop)

func _on_base_captured(_base: BaseNode, _prev_faction: int, _new_faction: int) -> void:
	# Comprobar condiciones tras conquista
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
		if not is_instance_valid(t):
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
	# Retorna el porcentaje de tropas y bases por facción
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
		if is_instance_valid(t):
			counts[t.faction] = counts.get(t.faction, 0) + t.count
			total += t.count
			
	var ratios = {}
	for f in counts:
		ratios[f] = (float(counts[f]) / float(total)) if total > 0 else 0.0
	return ratios

func _draw() -> void:
	if not is_dragging or selected_sources.is_empty():
		return
		
	var player_color = GameManager.FACTION_COLORS[GameManager.Faction.PLAYER]
	
	# Dibujar flechas dinámicas desde cada base seleccionada hacia la posición actual
	for src in selected_sources:
		if not is_instance_valid(src):
			continue
		var start_pt = src.global_position
		var end_pt = hovered_target.global_position if hovered_target else drag_current_pos
		
		# Línea principal translúcida con brillo
		draw_line(start_pt, end_pt, Color(1, 1, 1, 0.4), 8.0, true)
		draw_line(start_pt, end_pt, Color(player_color.r, player_color.g, player_color.b, 0.85), 4.0, true)
		
		# Cabeza de flecha
		var dir = (end_pt - start_pt).normalized()
		if start_pt.distance_to(end_pt) > 30.0:
			var normal = Vector2(-dir.y, dir.x)
			var arrow_size = 20.0
			var p1 = end_pt
			var p2 = end_pt - dir * arrow_size + normal * (arrow_size * 0.5)
			var p3 = end_pt - dir * arrow_size - normal * (arrow_size * 0.5)
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color.WHITE)
			
	# Anillo de fijación en el objetivo
	if hovered_target:
		draw_arc(hovered_target.global_position, hovered_target.radius + 15.0, 0, TAU, 36, Color(1, 1, 1, 0.9), 3.0)
