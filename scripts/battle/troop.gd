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
var is_retreating: bool = false
var retreat_dest_base: BaseNode = null

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

func abort_mission() -> void:
	if is_retreating or not is_instance_valid(origin_base):
		return
	is_retreating = true
	var dest = origin_base
	var old_target = target_base
	target_base = dest
	retreat_dest_base = dest
	origin_base = old_target
	
	if beads.is_empty():
		start_pos = global_position
		target_pos = dest.global_position
		var path_vec = target_pos - global_position
		path_length = path_vec.length()
		move_dir = path_vec.normalized() if path_length > 0.001 else Vector2.LEFT
		arrival_dist = max(10.0, path_length - (dest.radius * 0.45))
	else:
		var old_start = start_pos
		var old_dir = move_dir
		var new_dest_pos = dest.global_position
		var new_start_pos = old_target.global_position if is_instance_valid(old_target) else (old_start + old_dir * path_length)
		var new_path_vec = new_dest_pos - new_start_pos
		var new_path_len = new_path_vec.length()
		var new_dir = new_path_vec.normalized() if new_path_len > 0.001 else -old_dir
		
		start_pos = new_start_pos
		target_pos = new_dest_pos
		move_dir = new_dir
		path_length = new_path_len
		arrival_dist = max(10.0, path_length - (dest.radius * 0.45))
		
		var unemerged_count = 0
		for b in beads:
			if b["absorbed"]:
				continue
			if b["dist"] <= 0.0:
				# No había emergido de la base origen todavía, se reintegra directamente
				b["absorbed"] = true
				unemerged_count += 1
			else:
				var bead_world = old_start + old_dir * b["dist"]
				var new_dist = (bead_world - start_pos).dot(move_dir)
				b["dist"] = new_dist
				
		if unemerged_count > 0:
			dest.receive_troops(faction, unemerged_count)
			count -= unemerged_count
			
		update_count()
		if count <= 0:
			EventBus.troop_arrived.emit(self, dest)
			if is_inside_tree():
				queue_free()

func retreat() -> void:
	abort_mission()

static func point_distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var l2 = ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	var proj = a + ab * t
	return p.distance_to(proj)

static func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	var d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
	if absf(d) < 0.00001:
		return false
	var u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
	var v = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / d
	return u >= 0.0 and u <= 1.0 and v >= 0.0 and v <= 1.0

func intersects_segment(seg_a: Vector2, seg_b: Vector2) -> bool:
	if count <= 0 or not is_active or is_retreating:
		return false
		
	# 1. Comprobar intersección con la trayectoria del convoy
	var t_dest = target_pos if target_pos != Vector2.ZERO else (target_base.global_position if is_instance_valid(target_base) else (start_pos + move_dir * path_length))
	if segments_intersect(seg_a, seg_b, start_pos, t_dest):
		return true
		
	if beads.is_empty():
		return point_distance_to_segment(global_position, seg_a, seg_b) <= 24.0
	
	var min_dist = 999999.0
	var max_dist = -999999.0
	var has_active_beads = false
	
	for b in beads:
		if not b["absorbed"] and b["dist"] >= 0.0:
			has_active_beads = true
			if b["dist"] < min_dist: min_dist = b["dist"]
			if b["dist"] > max_dist: max_dist = b["dist"]
			var b_pos = start_pos + move_dir * b["dist"]
			if point_distance_to_segment(b_pos, seg_a, seg_b) <= (BEAD_RADIUS + 14.0):
				return true
				
	if has_active_beads and min_dist <= max_dist:
		var p_rear = start_pos + move_dir * min_dist
		var p_front = start_pos + move_dir * max_dist
		if segments_intersect(seg_a, seg_b, p_rear, p_front):
			return true
			
	return false

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
