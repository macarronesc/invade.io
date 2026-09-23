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

var elastic_scale: Vector2 = Vector2.ONE
var elastic_velocity: Vector2 = Vector2.ZERO
const SPRING_STIFFNESS: float = 240.0
const SPRING_DAMPING: float = 16.0

var shake_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0

var shockwave_radius: float = 0.0
var shockwave_alpha: float = 0.0
var shockwave_color: Color = Color.WHITE

var is_active: bool = true

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label_troops: Label = $TroopLabel
@onready var label_name: Label = $NameLabel

func _ready() -> void:
	EventBus.battle_won.connect(func(_stats): is_active = false)
	EventBus.battle_lost.connect(func(): is_active = false)
	_update_tier_parameters()
	_update_label()
	queue_redraw()

func setup(data: Dictionary) -> void:
	is_active = true
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
	if label_name:
		label_name.position.y = radius + 6.0

func _process(delta: float) -> void:
	if not is_active:
		return
		
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
				troops = mini(max_capacity, troops + units_to_add)
				_update_label()
				_trigger_generation_pulse()
				
	# Simulación de muelle elástico (Squash & Stretch) con sim_delta acotado para estabilidad
	var sim_delta = minf(delta, 0.033)
	var displacement = elastic_scale - Vector2.ONE
	var spring_force = -SPRING_STIFFNESS * displacement - SPRING_DAMPING * elastic_velocity
	elastic_velocity += spring_force * sim_delta
	elastic_scale += elastic_velocity * sim_delta
	elastic_scale.x = clampf(elastic_scale.x, 0.35, 2.2)
	elastic_scale.y = clampf(elastic_scale.y, 0.35, 2.2)
	
	# Animación suave de pulso
	if pulse_scale > 1.0:
		pulse_scale = max(1.0, pulse_scale - delta * 2.5)
		
	# Sacudida elástica (Shake)
	if shake_intensity > 0.0:
		shake_intensity = max(0.0, shake_intensity - delta * 22.0)
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
	else:
		shake_offset = Vector2.ZERO
		
	# Expansión y desvanecimiento de onda expansiva
	if shockwave_alpha > 0.0:
		shockwave_radius += delta * (radius * 4.5)
		shockwave_alpha = max(0.0, shockwave_alpha - delta * 2.6)
		
	# Sincronizar etiqueta de tropas con escala elástica y sacudida
	if label_troops:
		label_troops.position = Vector2(-50.0, -25.0) + shake_offset
		label_troops.scale = elastic_scale * pulse_scale
		label_troops.pivot_offset = Vector2(50.0, 25.0)
		
	queue_redraw()

func _trigger_generation_pulse() -> void:
	# Pulso elástico suave y sutil al reclutar cada unidad
	elastic_velocity += Vector2(0.9, 0.9)

func _trigger_conquest_shockwave(new_faction: int) -> void:
	# Rebote elástico dramático de conquista + onda expansiva State.io
	elastic_scale = Vector2(1.32, 1.32)
	elastic_velocity = Vector2(3.5, 3.5)
	shake_intensity = 6.0
	shockwave_radius = radius * 0.7
	shockwave_alpha = 0.95
	shockwave_color = GameManager.FACTION_COLORS.get(new_faction, Color.WHITE)

func set_selected(selected: bool) -> void:
	if is_selected != selected:
		is_selected = selected
		queue_redraw()

func is_point_inside(global_pt: Vector2) -> bool:
	return global_position.distance_to(global_pt) <= (radius + 20.0)

func send_troops(_percentage: float = 1.0) -> int:
	if troops <= 1:
		return 0
	# En State.io el modo de asalto es al 100% constante:
	# se envían todas las tropas disponibles reteniendo 1 centinela de guardia para conservar la soberanía territorial
	var count = troops - 1
	troops -= count
	_update_label()
	pulse_scale = 1.15
	# Contracción elástica al expulsar pelotón
	elastic_scale = Vector2(0.92, 1.08)
	elastic_velocity = Vector2(-1.2, 1.2)
	queue_redraw()
	return count

func receive_troops(incoming_faction: int, count: int) -> void:
	pulse_scale = 1.25
	
	if incoming_faction == faction:
		# Refuerzo aliado
		troops += count
		elastic_scale = Vector2(1.08, 0.94)
		elastic_velocity += Vector2(1.2, -1.2)
		shake_intensity = 2.2
		AudioManager.play_troop_absorb(true)
	else:
		# Combate
		if count < troops:
			troops -= count
			elastic_scale = Vector2(1.14, 0.88)
			elastic_velocity += Vector2(2.0, -2.0)
			shake_intensity = 3.8
			AudioManager.play_troop_absorb(false)
		elif count == troops:
			troops = 0
			var prev_faction = faction
			faction = GameManager.Faction.NEUTRAL
			if prev_faction != GameManager.Faction.NEUTRAL:
				_trigger_conquest_shockwave(faction)
				AudioManager.play_capture()
				EventBus.base_captured.emit(self, prev_faction, faction)
			else:
				# Agotamiento de guarnición neutral previa a conquista
				elastic_scale = Vector2(1.15, 0.85)
				elastic_velocity += Vector2(2.5, -2.5)
				shake_intensity = 4.0
				AudioManager.play_troop_absorb(false)
		else:
			# Conquista
			var prev_faction = faction
			var remaining = count - troops
			faction = incoming_faction
			troops = remaining
			_trigger_conquest_shockwave(faction)
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
	
	# 1. Onda expansiva de impacto y conquista
	if shockwave_alpha > 0.0:
		var sw_col = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, shockwave_alpha * 0.85)
		var sw_width = maxf(1.0, 5.0 * shockwave_alpha)
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 48, sw_col, sw_width, true)
		var fill_col = Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, shockwave_alpha * 0.18)
		draw_circle(Vector2.ZERO, shockwave_radius, fill_col)
		
	# Aplicar transformación de sacudida y escala elástica
	draw_set_transform(shake_offset, 0.0, elastic_scale)
	
	# 2. Sombra 2.5D difusa multicapa State.io (+Y hacia abajo)
	draw_circle(Vector2(0, 14), current_radius + 12.0, Color(0, 0, 0, 0.05))
	draw_circle(Vector2(0, 10), current_radius + 8.0, Color(0, 0, 0, 0.09))
	draw_circle(Vector2(0, 7), current_radius + 4.0, Color(0, 0, 0, 0.15))
	draw_circle(Vector2(0, 4), current_radius + 1.0, Color(0, 0, 0, 0.22))
	
	# 3. Anillo de selección exterior si está seleccionada
	if is_selected:
		draw_circle(Vector2.ZERO, current_radius + 14.0, Color(1, 1, 1, 0.25))
		draw_arc(Vector2.ZERO, current_radius + 11.0, 0, TAU, 48, Color.WHITE, 4.0, true)
		
	# 4. Borde exterior blanco limpio y nítido
	draw_circle(Vector2.ZERO, current_radius + 4.5, Color.WHITE)
	
	# 5. Cuerpo principal con color de la facción
	draw_circle(Vector2.ZERO, current_radius, color)
	
	# 6. Iluminación domo / reflejo redondeado 2.5D superior
	var dome_highlight = Color(1.0, 1.0, 1.0, 0.28)
	draw_arc(Vector2(0, -current_radius * 0.12), current_radius * 0.72, PI * 1.15, PI * 1.85, 32, dome_highlight, 3.5, true)
	
	# 7. Anillo interior decorativo sutil
	draw_arc(Vector2.ZERO, current_radius * 0.82, 0, TAU, 40, Color(1, 1, 1, 0.18), 1.8, true)
	
	# 8. Indicadores de Tier (pips redondeados elegantes en la parte superior)
	var pip_spacing = 16.0
	var start_x = -((tier - 1) * pip_spacing) / 2.0
	for i in range(tier):
		var pip_pos = Vector2(start_x + i * pip_spacing, -current_radius - 12.0)
		draw_circle(pip_pos + Vector2(0, 2), 4.5, Color(0, 0, 0, 0.35))
		draw_circle(pip_pos, 4.5, Color.WHITE)
		draw_circle(pip_pos, 3.0, Color(0.92, 0.92, 0.96))
		
	# Restablecer transformación
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
