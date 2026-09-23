extends Area2D
class_name BaseNode

## BaseNode: Territorio interactivo con producción de tropas y combate

enum BaseType {
	STANDARD = 0,
	FORTRESS = 1,
	FACTORY = 2
}

@export var base_id: String = ""
@export var base_name: String = "Territorio"
@export var faction: int = GameManager.Faction.NEUTRAL
@export var troops: int = 20
@export var tier: int = 1
@export var base_type: BaseType = BaseType.STANDARD

var structure_type:
	get:
		return base_type
	set(val):
		_set_type_from_variant(val)
		queue_redraw()

var fortress_absorbed_damage: int = 0
var factory_gear_angle: float = 0.0

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

var is_under_siege: bool = false
const SIEGE_RADIUS: float = 220.0
var siege_pulse_time: float = 0.0
var siege_incoming_hostile_count: int = 0

var is_active: bool = true

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var label_troops: Label = get_node_or_null("TroopLabel")
@onready var label_name: Label = get_node_or_null("NameLabel")

func _ready() -> void:
	EventBus.battle_won.connect(func(_stats): is_active = false; is_under_siege = false; siege_incoming_hostile_count = 0; queue_redraw())
	EventBus.battle_lost.connect(func(): is_active = false; is_under_siege = false; siege_incoming_hostile_count = 0; queue_redraw())
	_update_tier_parameters()
	_update_label()
	queue_redraw()

func get_type_production_multiplier() -> float:
	match base_type:
		BaseType.FORTRESS:
			return 0.3
		BaseType.FACTORY:
			return 2.5
		_:
			return 1.0

func get_defense_multiplier() -> float:
	match base_type:
		BaseType.FORTRESS:
			return 2.0
		BaseType.FACTORY:
			return 0.5
		_:
			return 1.0

func get_effective_defense() -> int:
	match base_type:
		BaseType.FORTRESS:
			return maxi(0, troops * 2 - fortress_absorbed_damage)
		BaseType.FACTORY:
			return int(ceil(float(troops) / 2.0))
		_:
			return troops

func update_siege_status(troops_list: Array) -> void:
	if not is_active or faction == GameManager.Faction.NEUTRAL:
		is_under_siege = false
		siege_incoming_hostile_count = 0
		return
		
	var effective_def = get_effective_defense()
	var hostile_incoming = 0
	var has_close_hostile = false
	
	for t in troops_list:
		if not is_instance_valid(t) or t.is_queued_for_deletion() or t.count <= 0:
			continue
		if t.target_base == self and t.faction != faction and t.faction != GameManager.Faction.NEUTRAL:
			var d = global_position.distance_to(t.global_position)
			if d <= SIEGE_RADIUS:
				hostile_incoming += t.count
				has_close_hostile = true
				
	siege_incoming_hostile_count = hostile_incoming
	
	if has_close_hostile and hostile_incoming > effective_def:
		is_under_siege = true
	else:
		is_under_siege = false

func evaluate_siege(troops_list: Array) -> bool:
	update_siege_status(troops_list)
	return is_under_siege

func set_base_type(p_type) -> void:
	_set_type_from_variant(p_type)
	queue_redraw()

func set_structure_type(p_type) -> void:
	_set_type_from_variant(p_type)
	queue_redraw()

func _set_type_from_variant(v) -> void:
	if v is BaseType or v is int:
		base_type = v as BaseType
	elif v is String:
		var s = (v as String).to_lower().strip_edges()
		if s in ["fortress", "bastion", "fortaleza", "bastion_defensivo"]:
			base_type = BaseType.FORTRESS
		elif s in ["factory", "fabrica", "fábrica", "recruitment_factory"]:
			base_type = BaseType.FACTORY
		else:
			base_type = BaseType.STANDARD

func setup(data: Dictionary) -> void:
	is_active = true
	base_id = data.get("id", base_id)
	base_name = data.get("name", base_name)
	faction = data.get("faction", faction)
	troops = data.get("troops", troops)
	tier = data.get("tier", tier)
	if data.has("pos"):
		position = data["pos"]
		
	if data.has("base_type"):
		_set_type_from_variant(data["base_type"])
	elif data.has("structure_type"):
		_set_type_from_variant(data["structure_type"])
	elif data.has("type"):
		_set_type_from_variant(data["type"])
	
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
	# Producción pasiva de tropas (sólo para bases activas y capturadas)
	if is_active and faction != GameManager.Faction.NEUTRAL:
		var base_rate: float = 1.0
		match tier:
			1: base_rate = 1.0
			2: base_rate = 1.7
			3: base_rate = 2.5
			
		base_rate *= get_type_production_multiplier()
		
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
				
	if base_type == BaseType.FACTORY:
		factory_gear_angle += delta * 2.4
				
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
		
	if is_under_siege:
		siege_pulse_time += delta * 6.5
		
	queue_redraw()

func _trigger_generation_pulse() -> void:
	# Pulso elástico suave y sutil al reclutar cada unidad
	elastic_velocity += Vector2(0.9, 0.9)

func _trigger_conquest_shockwave(new_faction: int) -> void:
	# Rebote elástico dramático de conquista + onda expansiva State.io
	is_under_siege = false
	siege_incoming_hostile_count = 0
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
		fortress_absorbed_damage = 0
		elastic_scale = Vector2(1.08, 0.94)
		elastic_velocity += Vector2(1.2, -1.2)
		shake_intensity = 2.2
		AudioManager.play_troop_absorb(true)
	else:
		# Combate
		match base_type:
			BaseType.FORTRESS:
				# Bonificación defensiva 2x: cada tropa defensora absorbe 2 unidades enemigas antes de caer
				var total_defense_power = troops * 2 - fortress_absorbed_damage
				if count < total_defense_power:
					total_defense_power -= count
					troops = int(ceil(float(total_defense_power) / 2.0))
					fortress_absorbed_damage = (troops * 2) - total_defense_power
					elastic_scale = Vector2(1.14, 0.88)
					elastic_velocity += Vector2(2.0, -2.0)
					shake_intensity = 3.8
					AudioManager.play_troop_absorb(false)
				elif count == total_defense_power:
					troops = 0
					fortress_absorbed_damage = 0
					var prev_faction = faction
					faction = GameManager.Faction.NEUTRAL
					if prev_faction != GameManager.Faction.NEUTRAL:
						_trigger_conquest_shockwave(faction)
						AudioManager.play_capture()
						EventBus.base_captured.emit(self, prev_faction, faction)
					else:
						elastic_scale = Vector2(1.15, 0.85)
						elastic_velocity += Vector2(2.5, -2.5)
						shake_intensity = 4.0
						AudioManager.play_troop_absorb(false)
				else:
					# Conquista de Fortaleza
					var prev_faction = faction
					var surplus = count - total_defense_power
					faction = incoming_faction
					troops = surplus
					fortress_absorbed_damage = 0
					_trigger_conquest_shockwave(faction)
					AudioManager.play_capture()
					EventBus.base_captured.emit(self, prev_faction, faction)
					
			BaseType.FACTORY:
				# Vulnerable en defensa 0.5x: las tropas defensoras caen con el doble de facilidad
				var effective_defense = troops
				var effective_attack = count * 2
				if effective_attack < effective_defense:
					troops = effective_defense - effective_attack
					elastic_scale = Vector2(1.14, 0.88)
					elastic_velocity += Vector2(2.0, -2.0)
					shake_intensity = 3.8
					AudioManager.play_troop_absorb(false)
				elif effective_attack == effective_defense:
					troops = 0
					var prev_faction = faction
					faction = GameManager.Faction.NEUTRAL
					if prev_faction != GameManager.Faction.NEUTRAL:
						_trigger_conquest_shockwave(faction)
						AudioManager.play_capture()
						EventBus.base_captured.emit(self, prev_faction, faction)
					else:
						elastic_scale = Vector2(1.15, 0.85)
						elastic_velocity += Vector2(2.5, -2.5)
						shake_intensity = 4.0
						AudioManager.play_troop_absorb(false)
				else:
					# Conquista de Fábrica
					var prev_faction = faction
					var attackers_used = int(ceil(float(effective_defense) / 2.0))
					var surplus = maxi(1, count - attackers_used)
					faction = incoming_faction
					troops = surplus
					_trigger_conquest_shockwave(faction)
					AudioManager.play_capture()
					EventBus.base_captured.emit(self, prev_faction, faction)
					
			_:
				# Base STANDARD (regular 1.0x defensa)
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
		
	# 4. Borde exterior y elementos tácticos distintivos según BaseType
	if base_type == BaseType.FORTRESS:
		# Borde reforzado con almenas de bastión defensivo
		draw_circle(Vector2.ZERO, current_radius + 6.5, Color(0.2, 0.22, 0.26))
		draw_circle(Vector2.ZERO, current_radius + 5.0, Color.WHITE)
		var num_crenels = 8
		for i in range(num_crenels):
			var angle = i * (TAU / num_crenels)
			var c_dir = Vector2(cos(angle), sin(angle))
			var c_pos = c_dir * (current_radius + 5.0)
			draw_circle(c_pos, 4.8, Color.WHITE)
			draw_circle(c_pos, 3.0, Color(0.3, 0.35, 0.4))
	elif base_type == BaseType.FACTORY:
		# Engranaje industrial perimetral con pulsación
		draw_circle(Vector2.ZERO, current_radius + 5.0, Color.WHITE)
		var num_teeth = 8
		for i in range(num_teeth):
			var angle = i * (TAU / num_teeth) + factory_gear_angle
			var t_dir = Vector2(cos(angle), sin(angle))
			var t_pos = t_dir * (current_radius + 4.5)
			draw_circle(t_pos, 4.8, Color(1.0, 0.8, 0.2, 0.95))
			draw_circle(t_pos, 2.5, Color(0.25, 0.2, 0.1))
	else:
		# Base regular STANDARD
		draw_circle(Vector2.ZERO, current_radius + 4.5, Color.WHITE)
	
	# 5. Cuerpo principal con color de la facción
	draw_circle(Vector2.ZERO, current_radius, color)
	
	# 6. Emblema distintivo procedural
	if base_type == BaseType.FORTRESS:
		var shield_y = current_radius * 0.44
		var s_pts = PackedVector2Array([
			Vector2(-8, shield_y - 6),
			Vector2(8, shield_y - 6),
			Vector2(8, shield_y + 1),
			Vector2(0, shield_y + 8),
			Vector2(-8, shield_y + 1)
		])
		draw_colored_polygon(s_pts, Color(1, 1, 1, 0.35))
		draw_polyline(s_pts, Color.WHITE, 1.6, true)
	elif base_type == BaseType.FACTORY:
		var gear_y = current_radius * 0.44
		draw_arc(Vector2(0, gear_y), 6.0, 0, TAU, 16, Color(1, 1, 1, 0.45), 2.0, true)
		draw_circle(Vector2(0, gear_y), 2.2, Color(1, 1, 1, 0.55))
	
	# 7. Iluminación domo / reflejo redondeado 2.5D superior
	var dome_highlight = Color(1.0, 1.0, 1.0, 0.28)
	draw_arc(Vector2(0, -current_radius * 0.12), current_radius * 0.72, PI * 1.15, PI * 1.85, 32, dome_highlight, 3.5, true)
	
	# 8. Anillo interior decorativo sutil
	draw_arc(Vector2.ZERO, current_radius * 0.82, 0, TAU, 40, Color(1, 1, 1, 0.18), 1.8, true)
	
	# 9. Indicadores de Tier (pips redondeados elegantes en la parte superior)
	var pip_spacing = 16.0
	var start_x = -((tier - 1) * pip_spacing) / 2.0
	for i in range(tier):
		var pip_pos = Vector2(start_x + i * pip_spacing, -current_radius - 12.0)
		draw_circle(pip_pos + Vector2(0, 2), 4.5, Color(0, 0, 0, 0.35))
		draw_circle(pip_pos, 4.5, Color.WHITE)
		draw_circle(pip_pos, 3.0, Color(0.92, 0.92, 0.96))
		
	# 10. Alerta Visual de Asedio Inminente (Under Siege Alert)
	if is_under_siege and is_active:
		var p = (sin(siege_pulse_time) + 1.0) * 0.5
		var halo_r = current_radius + 12.0 + p * 8.0
		var halo_col = Color(1.0, 0.15, 0.15, 0.45 + p * 0.45)
		draw_arc(Vector2.ZERO, halo_r, 0, TAU, 48, halo_col, 4.0, true)
		draw_circle(Vector2.ZERO, halo_r, Color(1.0, 0.1, 0.1, 0.07 + p * 0.08))
		
		# Marcador de exclamación ⚠ animado sobre el territorio
		var badge_y = -current_radius - 32.0 + sin(siege_pulse_time * 1.5) * 4.0
		var badge_center = Vector2(0, badge_y)
		
		# Glow exterior del marcador
		draw_circle(badge_center, 18.0 + p * 3.0, Color(1.0, 0.2, 0.2, 0.35 * p))
		
		# Triángulo de advertencia estilizado
		var tri_size = 17.0
		var p_top = badge_center + Vector2(0, -tri_size * 0.95)
		var p_right = badge_center + Vector2(tri_size * 0.95, tri_size * 0.65)
		var p_left = badge_center + Vector2(-tri_size * 0.95, tri_size * 0.65)
		var tri_pts = PackedVector2Array([p_top, p_right, p_left])
		
		# Sombra del marcador
		var shadow_pts = PackedVector2Array([p_top + Vector2(0, 3), p_right + Vector2(0, 3), p_left + Vector2(0, 3)])
		draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.35))
		
		# Relleno del triángulo amarillo de advertencia
		draw_colored_polygon(tri_pts, Color(1.0, 0.82, 0.1))
		# Borde rojo de contraste
		draw_polyline(PackedVector2Array([p_top, p_right, p_left, p_top]), Color(0.9, 0.15, 0.1), 2.2, true)
		
		# Signo de exclamación ! en negro en el centro
		draw_line(badge_center + Vector2(0, -tri_size * 0.28), badge_center + Vector2(0, tri_size * 0.16), Color(0.12, 0.12, 0.12), 2.8, true)
		draw_circle(badge_center + Vector2(0, tri_size * 0.38), 1.7, Color(0.12, 0.12, 0.12))
		
	# Restablecer transformación
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
