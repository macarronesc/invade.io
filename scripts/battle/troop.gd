extends Node2D
class_name Troop

## Troop: Hilera fluida de unidades ("perlas") en marcha hacia un territorio objetivo.
## Todas las perlas avanzan a la misma velocidad en línea recta, así que la perla i está siempre
## a `head_dist - i * BEAD_SPACING` del origen. Cada perla puede agrupar varias unidades para
## limitar el coste de dibujo y colisión en hileras enormes (MAX_BEADS).

const BEAD_SPACING: float = 22.0
const BEAD_RADIUS: float = 7.0
const MAX_BEADS: int = 40
const BASE_SPEED: float = 380.0

var origin_base: BaseNode
var target_base: BaseNode
var count: int = 1
var total_units: int = 1
var faction: int = GameManager.Faction.PLAYER
var speed: float = BASE_SPEED
var is_active: bool = true
var is_retreating: bool = false
var retreat_dest_base: BaseNode = null

## Unidades que representa cada perla (0 = perla eliminada o ya absorbida)
var bead_values: PackedInt32Array = PackedInt32Array()
## Distancia recorrida por la perla 0 desde start_pos
var head_dist: float = 0.0
## Avance del último paso de simulación (para no perder cruces a pocos fps)
var last_advance: float = 0.0
var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.RIGHT
var path_length: float = 0.0
var arrival_dist: float = 0.0

var _front: int = 0

func setup(p_origin: BaseNode, p_target: BaseNode, p_count: int, p_faction: int) -> void:
	origin_base = p_origin
	target_base = p_target
	count = p_count
	total_units = p_count
	faction = p_faction
	is_active = true
	speed = BASE_SPEED
	if faction == GameManager.Faction.PLAYER:
		speed *= GameManager.get_troop_speed_multiplier()

	start_pos = origin_base.global_position
	global_position = start_pos
	_set_path(start_pos, target_base.global_position, target_base.radius)

	var n := mini(maxi(p_count, 1), MAX_BEADS)
	bead_values.resize(n)
	var per_bead := p_count / n
	var remainder := p_count % n
	for i in n:
		bead_values[i] = per_bead + (1 if i < remainder else 0)
	head_dist = 0.0
	_front = 0
	queue_redraw()

func _set_path(from: Vector2, to: Vector2, target_radius: float) -> void:
	start_pos = from
	target_pos = to
	var path_vec := to - from
	path_length = path_vec.length()
	move_dir = path_vec / path_length if path_length > 0.001 else Vector2.RIGHT
	arrival_dist = maxf(10.0, path_length - target_radius * 0.45)

func _ready() -> void:
	EventBus.battle_won.connect(_on_battle_ended.unbind(1))
	EventBus.battle_lost.connect(_on_battle_ended)

func _on_battle_ended() -> void:
	is_active = false

func bead_dist(i: int) -> float:
	return head_dist - i * BEAD_SPACING

func bead_position(i: int) -> Vector2:
	return start_pos + move_dir * bead_dist(i)

## Índice de la perla viva más adelantada, o -1 si no queda ninguna
func front_index() -> int:
	while _front < bead_values.size() and bead_values[_front] <= 0:
		_front += 1
	return _front if _front < bead_values.size() else -1

## Perlas vivas que ocupan el punto `u` de la trayectoria o lo han cruzado durante el último
## paso de simulación, de delante hacia atrás. Así el combate en cruces no depende de los fps.
func beads_near(u: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var n := bead_values.size()
	if n == 0:
		return result
	var half := BEAD_SPACING * 0.5
	var first := maxi(0, ceili((head_dist - (u + half + last_advance)) / BEAD_SPACING))
	var last := mini(n - 1, floori((head_dist - (u - half)) / BEAD_SPACING))
	for i in range(first, last + 1):
		var d := bead_dist(i)
		if bead_values[i] > 0 and d >= 0.0 and d < arrival_dist:
			result.append(i)
	return result

## Resta `amount` unidades a la perla i y devuelve las que le quedan
func damage_bead(i: int, amount: int) -> int:
	var dealt := mini(amount, bead_values[i])
	bead_values[i] -= dealt
	count -= dealt
	queue_redraw()
	return bead_values[i]

func _process(delta: float) -> void:
	if not is_active:
		return
	if not is_instance_valid(target_base):
		EventBus.troop_arrived.emit(self, null)
		queue_free()
		return
	if bead_values.is_empty():
		return

	head_dist += speed * delta
	last_advance = speed * delta

	# Llegada y absorción progresiva de las perlas delanteras en la base objetivo
	var f := front_index()
	while f >= 0 and bead_dist(f) >= arrival_dist:
		var v := bead_values[f]
		bead_values[f] = 0
		count -= v
		target_base.receive_troops(faction, v)
		f = front_index()

	if f < 0 or count <= 0:
		EventBus.troop_arrived.emit(self, target_base)
		queue_free()
		return

	global_position = start_pos + move_dir * maxf(0.0, bead_dist(f))
	queue_redraw()

func abort_mission() -> void:
	if is_retreating or not is_instance_valid(origin_base):
		return
	is_retreating = true
	var dest := origin_base
	var old_target := target_base
	target_base = dest
	retreat_dest_base = dest
	origin_base = old_target

	var n := bead_values.size()
	# Las perlas que aún no habían salido de la base se reintegran directamente
	var unemerged := 0
	for i in range(n - 1, -1, -1):
		if bead_dist(i) > 0.0:
			break
		unemerged += bead_values[i]
		bead_values[i] = 0
	if unemerged > 0:
		dest.receive_troops(faction, unemerged)
		count -= unemerged

	# Invertir la hilera: la perla más retrasada pasa a ser la cabeza del regreso
	var old_start := start_pos
	var old_dir := move_dir
	var old_tail_world := old_start + old_dir * bead_dist(n - 1)
	var new_start := old_target.global_position if is_instance_valid(old_target) else old_start + old_dir * path_length
	_set_path(new_start, dest.global_position, dest.radius)
	bead_values.reverse()
	head_dist = (old_tail_world - start_pos).dot(move_dir)
	_front = 0
	queue_redraw()

	if count <= 0:
		EventBus.troop_arrived.emit(self, dest)
		if is_inside_tree():
			queue_free()

static func segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	return Geometry2D.segment_intersects_segment(p1, p2, p3, p4) != null

## ¿Un trazo de corte (seg_a -> seg_b) atraviesa la trayectoria o la hilera de esta tropa?
func intersects_segment(seg_a: Vector2, seg_b: Vector2) -> bool:
	if count <= 0 or not is_active or is_retreating or bead_values.is_empty():
		return false
	# 1. Cortar cualquier punto de la trayectoria restante (más permisivo con el dedo)
	if segments_intersect(seg_a, seg_b, start_pos, start_pos + move_dir * path_length):
		return true
	# 2. Proximidad al tramo ocupado por las perlas emergidas
	var f := front_index()
	if f < 0 or bead_dist(f) < 0.0:
		return false
	var tail := f
	for i in range(bead_values.size() - 1, f, -1):
		if bead_values[i] > 0 and bead_dist(i) >= 0.0:
			tail = i
			break
	var pts := Geometry2D.get_closest_points_between_segments(seg_a, seg_b, bead_position(tail), bead_position(f))
	return pts[0].distance_to(pts[1]) <= BEAD_RADIUS + 14.0

func _draw() -> void:
	var f := front_index()
	if f < 0:
		return
	var color: Color = GameManager.FACTION_COLORS.get(faction, Color.GRAY)
	var origin_local := to_local(start_pos)
	for i in range(f, bead_values.size()):
		var v := bead_values[i]
		if v <= 0:
			continue
		var dist := bead_dist(i)
		# Las perlas siguientes siguen dentro de la base de origen
		if dist < 0.0:
			break
		# Animación elástica de escala al emerger y al ser absorbida
		var cur_scale := 1.0
		if dist < 25.0:
			cur_scale = clampf(dist / 25.0, 0.25, 1.0)
		elif dist > arrival_dist - 15.0:
			cur_scale = clampf((arrival_dist - dist) / 15.0, 0.2, 1.0)
		# Las perlas que agrupan varias unidades son ligeramente más grandes
		var r := BEAD_RADIUS * (1.0 + 0.1 * mini(v - 1, 5)) * cur_scale
		_draw_single_bead(origin_local + move_dir * dist, r, color)

func _draw_single_bead(pos: Vector2, r: float, color: Color) -> void:
	# Sombra 2.5D difusa debajo de la perla
	draw_circle(pos + Vector2(0, 3.0), r * 0.95, Color(0, 0, 0, 0.28))
	# Borde exterior blanco puro
	draw_circle(pos, r + 1.5, Color.WHITE)
	# Núcleo de la perla con el color de la facción
	draw_circle(pos, r, color)
	# Reflejo especular esférico
	draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.32, Color(1, 1, 1, 0.65))
