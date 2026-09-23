extends Area2D
class_name BaseNode

## BaseNode: Territorio interactivo con producción de tropas y combate

@export var base_id: String = ""
@export var base_name: String = "Territorio"
@export var faction: int = GameManager.Faction.NEUTRAL
@export var troops: int = 20
@export var tier: int = 1

var radius: float = 60.0
var max_capacity: int = 60
var is_selected: bool = false
var production_accumulator: float = 0.0
var pulse_scale: float = 1.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label_troops: Label = $TroopLabel
@onready var label_name: Label = $NameLabel

func _ready() -> void:
	_update_tier_parameters()
	_update_label()
	queue_redraw()

func setup(data: Dictionary) -> void:
	base_id = data.get("id", base_id)
	base_name = data.get("name", base_name)
	faction = data.get("faction", faction)
	troops = data.get("troops", troops)
	tier = data.get("tier", tier)
	if data.has("pos"):
		position = data["pos"]
	
	# Bonus de tropas iniciales para el jugador
	if faction == GameManager.Faction.PLAYER:
		troops += GameManager.get_starting_troops_bonus()
	
	_update_tier_parameters()
	_update_label()
	queue_redraw()

func _update_tier_parameters() -> void:
	match tier:
		1:
			radius = 50.0
			max_capacity = 45
		2:
			radius = 65.0
			max_capacity = 85
		3:
			radius = 80.0
			max_capacity = 140
		_:
			radius = 60.0
			max_capacity = 70
			
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius

func _process(delta: float) -> void:
	# Producción pasiva de tropas (sólo para bases capturadas)
	if faction != GameManager.Faction.NEUTRAL:
		var base_rate: float = 1.0
		match tier:
			1: base_rate = 1.0
			2: base_rate = 1.7
			3: base_rate = 2.5
			
		if faction == GameManager.Faction.PLAYER:
			base_rate *= GameManager.get_production_multiplier()
			
		production_accumulator += delta * base_rate
		if production_accumulator >= 1.0:
			var units_to_add = int(production_accumulator)
			production_accumulator -= units_to_add
			if troops < max_capacity:
				troops += units_to_add
				_update_label()
				
	# Animación suave de pulso
	if pulse_scale > 1.0:
		pulse_scale = max(1.0, pulse_scale - delta * 2.5)
		queue_redraw()

func set_selected(selected: bool) -> void:
	if is_selected != selected:
		is_selected = selected
		queue_redraw()

func is_point_inside(global_pt: Vector2) -> bool:
	return global_position.distance_to(global_pt) <= (radius + 20.0)

func send_troops(percentage: float = 0.5) -> int:
	if troops <= 1:
		return 0
	var count = int(floor(troops * percentage))
	if count < 1:
		count = 1
	troops -= count
	_update_label()
	pulse_scale = 1.15
	queue_redraw()
	return count

func receive_troops(incoming_faction: int, count: int) -> void:
	pulse_scale = 1.25
	
	if incoming_faction == faction:
		# Refuerzo aliado
		troops += count
		AudioManager.play_reinforce()
	else:
		# Combate
		if count < troops:
			troops -= count
		elif count == troops:
			troops = 0
			var prev_faction = faction
			faction = GameManager.Faction.NEUTRAL
			EventBus.base_captured.emit(self, prev_faction, faction)
		else:
			# Conquista
			var prev_faction = faction
			var remaining = count - troops
			faction = incoming_faction
			troops = remaining
			AudioManager.play_capture()
			EventBus.base_captured.emit(self, prev_faction, faction)
			
	_update_label()
	queue_redraw()

func _update_label() -> void:
	if label_troops:
		label_troops.text = str(troops)
	if label_name:
		label_name.text = base_name

func _draw() -> void:
	var color = GameManager.FACTION_COLORS.get(faction, Color.GRAY)
	var current_radius = radius * pulse_scale
	
	# Anillo de selección exterior si está seleccionada
	if is_selected:
		draw_circle(Vector2.ZERO, current_radius + 12.0, Color(1, 1, 1, 0.45))
		draw_arc(Vector2.ZERO, current_radius + 10.0, 0, TAU, 36, Color.WHITE, 4.0)
	
	# Sombra exterior suave
	draw_circle(Vector2(0, 6), current_radius + 4.0, Color(0, 0, 0, 0.25))
	
	# Borde exterior de la base
	draw_circle(Vector2.ZERO, current_radius + 4.0, Color.WHITE)
	
	# Cuerpo principal de la base
	draw_circle(Vector2.ZERO, current_radius, color)
	
	# Anillo interior decorativo
	draw_arc(Vector2.ZERO, current_radius * 0.75, 0, TAU, 32, Color(1, 1, 1, 0.35), 2.5)
	
	# Indicadores de Tier (pips en la parte superior)
	var pip_spacing = 16.0
	var start_x = -((tier - 1) * pip_spacing) / 2.0
	for i in range(tier):
		var pip_pos = Vector2(start_x + i * pip_spacing, -current_radius - 12.0)
		draw_circle(pip_pos, 4.0, Color.WHITE)
