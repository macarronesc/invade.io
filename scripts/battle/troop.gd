extends Node2D
class_name Troop

## Troop: Hilera fluida de unidades ("stream / perlas") en marcha hacia un territorio objetivo

var origin_base: BaseNode
var target_base: BaseNode
var count: int = 1
var total_units: int = 1
var faction: int = GameManager.Faction.PLAYER
var speed: float = 380.0
var is_active: bool = true

const BEAD_SPACING: float = 22.0
const BEAD_RADIUS: float = 7.0

var beads: Array = []
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.RIGHT
var path_length: float = 0.0
var arrival_dist: float = 0.0

@onready var count_label: Label = get_node_or_null("CountLabel")

func setup(p_origin: BaseNode, p_target: BaseNode, p_count: int, p_faction: int) -> void:
	origin_base = p_origin
	target_base = p_target
	count = p_count
	total_units = p_count
	faction = p_faction
	is_active = true
	
	if origin_base:
		start_pos = origin_base.global_position
		global_position = start_pos
	if target_base:
		target_pos = target_base.global_position
		
	var path_vec = target_pos - start_pos
	path_length = path_vec.length()
	move_dir = path_vec.normalized() if path_length > 0.001 else Vector2.RIGHT
	
	var target_radius = target_base.radius if target_base else 50.0
	arrival_dist = max(10.0, path_length - (target_radius * 0.45))
	
	if faction == GameManager.Faction.PLAYER:
		speed *= GameManager.get_troop_speed_multiplier()
		
	beads.clear()
	for i in range(count):
		beads.append({
			"id": i,
			"dist": -float(i) * BEAD_SPACING,
			"absorbed": false
		})
		
	update_count()

func _ready() -> void:
	EventBus.battle_won.connect(func(_s): is_active = false)
	EventBus.battle_lost.connect(func(): is_active = false)
	if count_label:
		count_label.visible = false
	update_count()

func update_count() -> void:
	if count_label:
		count_label.text = str(count)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		return
		
	if not is_instance_valid(target_base):
		EventBus.troop_arrived.emit(self, null)
		queue_free()
		return
		
	# Actualizar posición objetivo por si la base se mueve o sacude
	target_pos = target_base.global_position
	
	var any_alive = false
	var front_dist = -999999.0
	
	for b in beads:
		if b["absorbed"]:
			continue
			
		b["dist"] += speed * delta
		
		# Llegada y absorción individual a la base objetivo
		if b["dist"] >= arrival_dist:
			b["absorbed"] = true
			count -= 1
			target_base.receive_troops(faction, 1)
			update_count()
		else:
			any_alive = true
			if b["dist"] > front_dist:
				front_dist = b["dist"]
			
	if beads.is_empty():
		# Compatibilidad para instancias directas sin setup()
		var dist = global_position.distance_to(target_pos)
		if dist <= (target_base.radius * 0.75) or dist <= speed * delta:
			target_base.receive_troops(faction, count)
			EventBus.troop_arrived.emit(self, target_base)
			queue_free()
			return
		var dir = (target_pos - global_position).normalized()
		global_position += dir * speed * delta
	else:
		if not any_alive or count <= 0:
			# Todas las tropas han sido absorbidas o eliminadas
			EventBus.troop_arrived.emit(self, target_base)
			queue_free()
			return
		elif front_dist > -900000.0:
			global_position = start_pos + move_dir * max(0.0, front_dist)
			
	queue_redraw()

func remove_front_units(amount: int) -> void:
	var left = amount
	for b in beads:
		if not b["absorbed"]:
			b["absorbed"] = true
			count -= 1
			left -= 1
			if left <= 0 or count <= 0:
				break
	if count < 0:
		count = 0
	update_count()
	if count <= 0:
		if is_inside_tree():
			queue_free()

func get_active_bead_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if beads.is_empty():
		positions.append(global_position)
		return positions
	for b in beads:
		if not b["absorbed"] and b["dist"] >= 0.0:
			positions.append(start_pos + move_dir * b["dist"])
	return positions

func _draw() -> void:
	var color = GameManager.FACTION_COLORS.get(faction, Color.GRAY)
	
	if beads.is_empty():
		# Fallback para tests unitarios que instancian Troop directamente
		_draw_single_bead(Vector2.ZERO, BEAD_RADIUS, color)
		return
		
	for b in beads:
		if b["absorbed"]:
			continue
		var dist = b["dist"]
		# Solo renderizar una vez que empieza a emerger de la base origen
		if dist < 0.0:
			continue
			
		var b_global = start_pos + move_dir * dist
		var b_local = to_local(b_global)
		
		# Animación elástica de escala al emerger y al ser absorbida
		var cur_scale = 1.0
		if dist < 25.0:
			cur_scale = clampf(dist / 25.0, 0.25, 1.0)
		elif dist > (arrival_dist - 15.0):
			cur_scale = clampf((arrival_dist - dist) / 15.0, 0.2, 1.0)
			
		_draw_single_bead(b_local, BEAD_RADIUS * cur_scale, color)

func _draw_single_bead(pos: Vector2, r: float, color: Color) -> void:
	# Sombra 2.5D difusa debajo de la perla
	draw_circle(pos + Vector2(0, 3.0), r * 0.95, Color(0, 0, 0, 0.28))
	# Borde exterior blanco puro
	draw_circle(pos, r + 1.5, Color.WHITE)
	# Núcleo de la perla con el color de la facción
	draw_circle(pos, r, color)
	# Reflejo especular esférico 3D (brillo State.io)
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.32, Color(1, 1, 1, 0.65))
