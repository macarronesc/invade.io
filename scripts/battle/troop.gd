extends Node2D
class_name Troop

## Troop: Pelotón de unidades en marcha hacia un territorio objetivo

var origin_base: BaseNode
var target_base: BaseNode
var count: int = 1
var faction: int = GameManager.Faction.PLAYER
var speed: float = 380.0

var trail_positions: Array[Vector2] = []
const MAX_TRAIL = 4

@onready var count_label: Label = $CountLabel

func setup(p_origin: BaseNode, p_target: BaseNode, p_count: int, p_faction: int) -> void:
	origin_base = p_origin
	target_base = p_target
	count = p_count
	faction = p_faction
	global_position = origin_base.global_position
	
	if faction == GameManager.Faction.PLAYER:
		speed *= GameManager.get_troop_speed_multiplier()
		
	if count_label:
		count_label.text = str(count)
	queue_redraw()

func _ready() -> void:
	if count_label:
		count_label.text = str(count)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target_base):
		queue_free()
		return
		
	# Actualizar estela visual
	trail_positions.push_front(global_position)
	if trail_positions.size() > MAX_TRAIL:
		trail_positions.pop_back()
		
	var target_pos = target_base.global_position
	var dist = global_position.distance_to(target_pos)
	
	# Llegada al objetivo
	if dist <= (target_base.radius * 0.75) or dist <= speed * delta:
		target_base.receive_troops(faction, count)
		EventBus.troop_arrived.emit(self, target_base)
		queue_free()
		return
		
	var dir = (target_pos - global_position).normalized()
	global_position += dir * speed * delta
	queue_redraw()

func _draw() -> void:
	var color = GameManager.FACTION_COLORS.get(faction, Color.GRAY)
	
	# Dibujar estela
	for i in range(trail_positions.size()):
		var t_pos = to_local(trail_positions[i])
		var alpha = 0.3 * (1.0 - float(i) / float(MAX_TRAIL))
		var r = 10.0 * (1.0 - float(i) / float(MAX_TRAIL))
		draw_circle(t_pos, r, Color(color.r, color.g, color.b, alpha))
		
	# Sombra
	draw_circle(Vector2(0, 3), 16.0, Color(0, 0, 0, 0.25))
	# Borde blanco
	draw_circle(Vector2.ZERO, 16.0, Color.WHITE)
	# Cuerpo de la unidad
	draw_circle(Vector2.ZERO, 13.0, color)
