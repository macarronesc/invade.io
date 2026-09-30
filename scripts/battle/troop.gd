extends Node2D
class_name Troop

## Troop: una orden de ataque en marcha. Las tropas salen de la base en paquetes pequeños,
## uno tras otro, y avanzan en línea recta hacia el objetivo. Todos los paquetes llevan la
## misma velocidad, así que el paquete i está siempre a `head_dist - i * PACKET_SPACING` del
## origen. Los que aún no han salido (distancia <= 0) esperan en la base de origen: se pierden
## si esa base cae y vuelven a la guarnición si se ordena la retirada.

const PACKET_SPACING: float = 64.0
const PACKET_RADIUS: float = 18.0
## Unidades por paquete antes de repartir la orden en más paquetes
const PACKET_UNITS: int = 5
const MAX_PACKETS: int = 8
const BASE_SPEED: float = 380.0
const DOT_RADIUS: float = 5.5
## Puntos de un paquete: centro y un anillo algo irregular (se llenan en este orden)
const DOT_LAYOUT: Array[Vector2] = [Vector2(0, 0), Vector2(11, -2), Vector2(3, 10), Vector2(-9, 6),
	Vector2(-10, -5), Vector2(-2, -11), Vector2(9, -10)]

var origin_base: BaseNode
var target_base: BaseNode
var count: int = 1
var faction: int = GameManager.Faction.PLAYER
var speed: float = BASE_SPEED
var is_active: bool = true
var is_retreating: bool = false

## Unidades de cada paquete (0 = paquete eliminado o ya absorbido)
var packets: PackedInt32Array = PackedInt32Array()
## Distancia recorrida por el paquete 0 desde start_pos
var head_dist: float = 0.0
## Avance del último paso de simulación (para no perder cruces a pocos fps)
var last_advance: float = 0.0
var start_pos: Vector2 = Vector2.ZERO
var move_dir: Vector2 = Vector2.RIGHT
var path_length: float = 0.0
var arrival_dist: float = 0.0

var _front: int = 0
var _launched: int = 1

func setup(p_origin: BaseNode, p_target: BaseNode, p_count: int, p_faction: int) -> void:
	origin_base = p_origin
	target_base = p_target
	count = p_count
	_launched = maxi(p_count, 1)
	faction = p_faction
	is_active = true
	speed = BASE_SPEED
	if faction == GameManager.Faction.PLAYER:
		speed *= GameManager.get_troop_speed_multiplier()

	_set_path(origin_base.global_position, target_base.global_position, target_base.radius)
	global_position = start_pos

	var n := packet_count_for(p_count)
	packets.resize(n)
	@warning_ignore("integer_division")
	var per_packet := p_count / n
	var remainder := p_count % n
	for i in n:
		packets[i] = per_packet + (1 if i < remainder else 0)
	head_dist = 0.0
	_front = 0
	queue_redraw()

static func packet_count_for(units: int) -> int:
	return clampi(ceili(units / float(PACKET_UNITS)), 1, MAX_PACKETS)

## Segundos desde la orden hasta que el último paquete sale de la base
static func emission_seconds(units: int, p_speed: float = BASE_SPEED) -> float:
	return (packet_count_for(units) - 1) * PACKET_SPACING / p_speed

func _set_path(from: Vector2, to: Vector2, target_radius: float) -> void:
	start_pos = from
	var path_vec := to - from
	path_length = path_vec.length()
	move_dir = path_vec / path_length if path_length > 0.001 else Vector2.RIGHT
	arrival_dist = maxf(10.0, path_length - target_radius * 0.45)

func _ready() -> void:
	EventBus.battle_won.connect(_on_battle_ended.unbind(1))
	EventBus.battle_lost.connect(_on_battle_ended)
	EventBus.base_captured.connect(_on_origin_captured)

func _on_origin_captured(base: Node, _previous: int, new_faction: int) -> void:
	if base == origin_base and not is_retreating and new_faction != faction:
		_drop_pending()
		if count <= 0:
			_finish()

func _on_battle_ended() -> void:
	is_active = false

func packet_dist(i: int) -> float:
	return head_dist - i * PACKET_SPACING

func packet_position(i: int) -> Vector2:
	return start_pos + move_dir * packet_dist(i)

func remaining_seconds() -> float:
	var seconds := 0.0
	for i in packets.size():
		if packets[i] > 0:
			seconds = maxf(seconds, (arrival_dist - packet_dist(i)) / speed)
	return maxf(0.0, seconds)

## Unidades que aún esperan en la base de origen
func pending_units() -> int:
	var total := 0
	for i in range(packets.size() - 1, -1, -1):
		if packet_dist(i) > 0.0:
			break
		total += packets[i]
	return total

## Índice del paquete vivo más adelantado, o -1 si no queda ninguno
func front_index() -> int:
	while _front < packets.size() and packets[_front] <= 0:
		_front += 1
	return _front if _front < packets.size() else -1

## Paquetes vivos que ocupan el punto `u` de la trayectoria o lo han cruzado durante el último
## paso de simulación, de delante hacia atrás. Así el combate en cruces no depende de los fps.
func packets_near(u: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var n := packets.size()
	var first := maxi(0, ceili((head_dist - (u + PACKET_RADIUS + last_advance)) / PACKET_SPACING))
	var last := mini(n - 1, floori((head_dist - (u - PACKET_RADIUS)) / PACKET_SPACING))
	for i in range(first, last + 1):
		var d := packet_dist(i)
		if packets[i] > 0 and d >= 0.0 and d - last_advance < arrival_dist:
			result.append(i)
	return result

## Resta `amount` unidades al paquete i y devuelve las que le quedan
func damage_packet(i: int, amount: int) -> int:
	var dealt := mini(amount, packets[i])
	packets[i] -= dealt
	count -= dealt
	queue_redraw()
	return packets[i]

func _process(delta: float) -> void:
	advance(delta)
	resolve_arrivals()

## En la escena real BattleController mueve todas las órdenes, resuelve los choques y
## sólo después las llegadas: un salto de FPS no permite atravesar un combate.
func advance(delta: float) -> void:
	if not is_active or is_queued_for_deletion():
		return
	if not is_instance_valid(target_base):
		_finish()
		return
	if packets.is_empty():
		return

	# La base de origen ha caído: los paquetes que no habían salido se pierden con ella
	if not is_retreating and is_instance_valid(origin_base) and origin_base.faction != faction:
		_drop_pending()

	head_dist += speed * delta
	last_advance = speed * delta
	var f := front_index()
	if f >= 0:
		global_position = start_pos + move_dir * maxf(0.0, packet_dist(f))
	queue_redraw()

func resolve_arrivals() -> void:
	if not is_active or is_queued_for_deletion() or not is_instance_valid(target_base):
		return
	# Llegada y absorción progresiva de los paquetes delanteros en la base objetivo
	var f := front_index()
	while is_active and f >= 0 and packet_dist(f) >= arrival_dist:
		var v := packets[f]
		packets[f] = 0
		count -= v
		target_base.receive_troops(faction, v)
		f = front_index()

	if f < 0 or count <= 0:
		_finish()

func _drop_pending() -> void:
	for i in range(packets.size() - 1, -1, -1):
		if packet_dist(i) > 0.0:
			break
		count -= packets[i]
		packets[i] = 0

func _finish() -> void:
	is_active = false
	count = 0
	EventBus.troop_arrived.emit(self)
	queue_free()

func abort_mission() -> void:
	if is_retreating or not is_active or not is_instance_valid(origin_base):
		return
	is_retreating = true
	var dest := origin_base
	origin_base = target_base
	target_base = dest

	# Los paquetes que aún no habían salido vuelven directamente a la guarnición
	var unemerged := pending_units()
	_drop_pending()
	if unemerged > 0 and dest.faction == faction:
		dest.receive_troops(faction, unemerged)

	# Invertir la columna: el paquete más retrasado pasa a ser la cabeza del regreso
	var n := packets.size()
	var old_tail_world := packet_position(n - 1)
	_set_path(start_pos + move_dir * path_length, dest.global_position, dest.radius)
	packets.reverse()
	head_dist = (old_tail_world - start_pos).dot(move_dir)
	_front = 0
	queue_redraw()

	if count <= 0:
		_finish()

## ¿Un trazo de corte (seg_a -> seg_b) atraviesa la trayectoria o algún paquete de esta orden?
func intersects_segment(seg_a: Vector2, seg_b: Vector2) -> bool:
	if count <= 0 or not is_active or is_retreating or packets.is_empty():
		return false
	# 1. Cortar cualquier punto de la trayectoria restante (más permisivo con el dedo)
	if Geometry2D.segment_intersects_segment(seg_a, seg_b, start_pos, start_pos + move_dir * path_length) != null:
		return true
	# 2. Proximidad al tramo ocupado por los paquetes que ya han salido
	var f := front_index()
	if f < 0 or packet_dist(f) < 0.0:
		return false
	var tail := f
	for i in range(packets.size() - 1, f, -1):
		if packets[i] > 0 and packet_dist(i) >= 0.0:
			tail = i
			break
	var pts := Geometry2D.get_closest_points_between_segments(seg_a, seg_b, packet_position(tail), packet_position(f))
	return pts[0].distance_to(pts[1]) <= PACKET_RADIUS + 10.0

func _draw() -> void:
	var f := front_index()
	if f < 0:
		return
	var color: Color = GameManager.faction_color(faction)
	var style := GameManager.troop_style()
	var origin_local := to_local(start_pos)
	# Tropas que aún esperan para salir: arco que se vacía sobre la base de origen
	var pending := pending_units()
	if pending > 0 and not is_retreating and is_instance_valid(origin_base):
		var r := origin_base.radius + 10.0
		draw_arc(origin_local, r, -PI * 0.5, -PI * 0.5 + TAU * pending / float(_launched), 40, Color(color, 0.9), 5.0, true)
	for i in range(f, packets.size()):
		var v := packets[i]
		if v <= 0:
			continue
		var dist := packet_dist(i)
		if dist < 0.0:
			break
		# Aparece al salir y se encoge al llegar
		var s := 1.0
		if dist < 25.0:
			s = clampf(dist / 25.0, 0.3, 1.0)
		elif dist > arrival_dist - 15.0:
			s = clampf((arrival_dist - dist) / 15.0, 0.2, 1.0)
		var center := origin_local + move_dir * dist
		draw_packet(self, center, v, color, style, s, i * 1.1)
		BaseNode.draw_faction_symbol(self, center, 3.5 * s, faction)
		# Las cantidades grandes se representan con pocos puntos y su cantidad real.
		if v > DOT_LAYOUT.size():
			var pos := center + Vector2(-24, -26)
			var font := UIThemeHelper.bold_font()
			draw_string_outline(font, pos, str(v), HORIZONTAL_ALIGNMENT_CENTER, 48, 22, 5, Color(0, 0, 0, 0.85))
			draw_string(font, pos, str(v), HORIZONTAL_ALIGNMENT_CENTER, 48, 22, Color.WHITE)

## Paquete con el estilo de la tienda (también lo usa la vista previa de Ejército).
## Hasta 7 puntos; los paquetes con más unidades tienen puntos algo más grandes.
static func draw_packet(canvas: CanvasItem, pos: Vector2, units: int, color: Color, style: String, s: float = 1.0, angle: float = 0.0) -> void:
	var r := DOT_RADIUS * s * (1.0 + 0.06 * clampi(units - DOT_LAYOUT.size(), 0, 10))
	var spread := s * (1.2 if style == "troop_big" else 1.0)
	if style == "troop_big":
		r *= 1.3
	if style == "troop_halo":
		canvas.draw_circle(pos, (PACKET_RADIUS + 4.0) * s, Color(color, 0.22))
	var dots := mini(units, DOT_LAYOUT.size())
	for i in dots:
		var p := pos + DOT_LAYOUT[i].rotated(angle) * spread
		canvas.draw_circle(p + Vector2(0, 2.0), r, Color(0, 0, 0, 0.25))
		canvas.draw_circle(p, r + 1.4, Color.WHITE)
		canvas.draw_circle(p, r, color)
