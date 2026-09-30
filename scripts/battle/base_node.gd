extends Node2D
class_name BaseNode

## BaseNode: Territorio interactivo con producción de tropas y combate

enum BaseType {
	STANDARD = 0,
	FORTRESS = 1,
	FACTORY = 2
}

const TIER_PARAMS = {
	1: {"radius": 50.0, "capacity": 45, "rate": 1.0},
	2: {"radius": 65.0, "capacity": 85, "rate": 1.7},
	3: {"radius": 80.0, "capacity": 140, "rate": 2.5},
}
const DEFAULT_TIER_PARAMS = {"radius": 60.0, "capacity": 70, "rate": 1.0}

@export var base_id: String = ""
@export var base_name: String = "Territorio"
@export var faction: int = GameManager.Faction.NEUTRAL
@export var troops: int = 20
@export var tier: int = 1
@export var base_type: BaseType = BaseType.STANDARD
## Clave de la ciudad real (para el atlas); "" en bases sin ciudad
var city_key: String = ""
var production_bonus: float = 1.0
var is_capital: bool = false
var is_boss: bool = false

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

var is_active: bool = true
var _dirty: bool = true

@onready var label_troops: Label = get_node_or_null("TroopLabel")
@onready var label_name: Label = get_node_or_null("NameLabel")

func _ready() -> void:
	EventBus.battle_won.connect(_on_battle_ended.unbind(1))
	EventBus.battle_lost.connect(_on_battle_ended)
	if label_troops:
		label_troops.pivot_offset = Vector2(50.0, 25.0)
	_update_tier_parameters()
	_update_label()

func _on_battle_ended() -> void:
	is_active = false
	is_under_siege = false
	_dirty = true

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

## Tropas generadas por segundo con los modificadores de nivel, tipo y facción
func get_production_rate() -> float:
	var rate: float = TIER_PARAMS.get(tier, DEFAULT_TIER_PARAMS)["rate"]
	return rate * production_bonus * get_type_production_multiplier() * GameManager.get_faction_production_multiplier(faction)

## Puntos de defensa restantes (fortaleza absorbe 2 impactos por tropa, fábrica 0.5)
func get_defense_power() -> float:
	return maxf(0.0, troops * get_defense_multiplier() - fortress_absorbed_damage)

## Número de atacantes necesarios para neutralizar la base
func get_effective_defense() -> int:
	return ceili(get_defense_power())

func update_siege_status(troops_list: Array) -> void:
	var was_under_siege = is_under_siege
	if not is_active or faction == GameManager.Faction.NEUTRAL:
		is_under_siege = false
	else:
		var hostile_incoming = 0
		for t in troops_list:
			if not BattleController._is_alive(t):
				continue
			if t.target_base == self and t.faction != faction and t.faction != GameManager.Faction.NEUTRAL:
				if global_position.distance_to(t.global_position) <= SIEGE_RADIUS:
					hostile_incoming += t.count
		is_under_siege = hostile_incoming > get_effective_defense()
	if was_under_siege != is_under_siege:
		_dirty = true

func set_base_type(p_type) -> void:
	_set_type_from_variant(p_type)
	_dirty = true

## Acepta el enum o el texto de las definiciones de nivel ("fortress" / "factory")
func _set_type_from_variant(v) -> void:
	if v is int:
		base_type = v as BaseType
	else:
		base_type = {"fortress": BaseType.FORTRESS, "factory": BaseType.FACTORY}.get(v, BaseType.STANDARD)

func setup(data: Dictionary) -> void:
	is_active = true
	base_id = data.get("id", base_id)
	base_name = data.get("name", base_name)
	city_key = data.get("city", city_key)
	production_bonus = data.get("production_bonus", 1.0)
	is_capital = data.get("capital", false)
	is_boss = data.get("boss", false)
	faction = data.get("faction", faction)
	troops = data.get("troops", troops)
	tier = data.get("tier", tier)
	if data.has("pos"):
		position = data["pos"]
	if data.has("type"):
		_set_type_from_variant(data["type"])
	if label_name:
		label_name.text = base_name

	# Bonus de tropas iniciales para el jugador
	if faction == GameManager.Faction.PLAYER:
		troops += GameManager.get_starting_troops_bonus()

	_update_tier_parameters()
	_update_label()

func _update_tier_parameters() -> void:
	var params: Dictionary = TIER_PARAMS.get(tier, DEFAULT_TIER_PARAMS)
	radius = params["radius"]
	max_capacity = params["capacity"]
	if label_name:
		label_name.position.y = radius + 6.0
	_dirty = true

func _process(delta: float) -> void:
	# Producción pasiva de tropas (sólo para bases activas y capturadas)
	if is_active and faction != GameManager.Faction.NEUTRAL:
		production_accumulator += delta * get_production_rate()
		if production_accumulator >= 1.0:
			var units_to_add = int(production_accumulator)
			production_accumulator -= units_to_add
			if troops < max_capacity:
				troops = mini(max_capacity, troops + units_to_add)
				_update_label()
				_trigger_generation_pulse()

	var animating := _animate(delta)
	if animating or _dirty:
		_dirty = false
		if label_troops:
			label_troops.position = Vector2(-50.0, -25.0) + shake_offset
			label_troops.scale = elastic_scale * pulse_scale
		queue_redraw()

## Avanza las animaciones y devuelve true mientras alguna siga activa
func _animate(delta: float) -> bool:
	var animating := false
	if base_type == BaseType.FACTORY:
		factory_gear_angle += delta * 2.4
		animating = true

	# Simulación de muelle elástico (Squash & Stretch) con sim_delta acotado para estabilidad
	var displacement = elastic_scale - Vector2.ONE
	if displacement.length_squared() > 1e-6 or elastic_velocity.length_squared() > 1e-5:
		var sim_delta = minf(delta, 0.033)
		var spring_force = -SPRING_STIFFNESS * displacement - SPRING_DAMPING * elastic_velocity
		elastic_velocity += spring_force * sim_delta
		elastic_scale += elastic_velocity * sim_delta
		elastic_scale = elastic_scale.clamp(Vector2(0.35, 0.35), Vector2(2.2, 2.2))
		animating = true
	elif elastic_scale != Vector2.ONE:
		elastic_scale = Vector2.ONE
		elastic_velocity = Vector2.ZERO
		animating = true

	if pulse_scale > 1.0:
		pulse_scale = maxf(1.0, pulse_scale - delta * 2.5)
		animating = true

	if shake_intensity > 0.0:
		shake_intensity = maxf(0.0, shake_intensity - delta * 22.0)
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		animating = true
	elif shake_offset != Vector2.ZERO:
		shake_offset = Vector2.ZERO
		animating = true

	if shockwave_alpha > 0.0:
		shockwave_radius += delta * (radius * 4.5)
		shockwave_alpha = maxf(0.0, shockwave_alpha - delta * 2.6)
		animating = true

	if is_under_siege:
		siege_pulse_time += delta * 6.5
		animating = true
	return animating

func _trigger_generation_pulse() -> void:
	# Pulso elástico suave y sutil al reclutar cada unidad
	elastic_velocity += Vector2(0.9, 0.9)

func _trigger_conquest_shockwave(new_faction: int) -> void:
	# Rebote elástico dramático de conquista + onda expansiva
	is_under_siege = false
	elastic_scale = Vector2(1.32, 1.32)
	elastic_velocity = Vector2(3.5, 3.5)
	shake_intensity = 6.0
	shockwave_radius = radius * 0.7
	shockwave_alpha = 0.95
	shockwave_color = GameManager.faction_color(new_faction)

func set_selected(selected: bool) -> void:
	if is_selected != selected:
		is_selected = selected
		_dirty = true

func is_point_inside(global_pt: Vector2) -> bool:
	return global_position.distance_to(global_pt) <= (radius + 20.0)

## Envía todas las tropas menos 1 centinela (asalto al 100%, estilo State.io)
func send_troops() -> int:
	if troops <= 1:
		return 0
	var count = troops - 1
	troops = 1
	_update_label()
	pulse_scale = 1.15
	# Contracción elástica al expulsar pelotón
	elastic_scale = Vector2(0.92, 1.08)
	elastic_velocity = Vector2(-1.2, 1.2)
	return count

func receive_troops(incoming_faction: int, count: int) -> void:
	pulse_scale = 1.25
	if incoming_faction == faction:
		# Refuerzo aliado
		troops += count
		fortress_absorbed_damage = 0
		_bump(Vector2(1.08, 0.94), Vector2(1.2, -1.2), 2.2)
		AudioManager.play_troop_absorb(true)
	else:
		var m := get_defense_multiplier()
		var power := get_defense_power()
		if count < power:
			# Resistencia: la fortaleza puede absorber impactos parciales en un defensor
			var remaining := power - count
			troops = ceili(remaining / m)
			fortress_absorbed_damage = int(round(troops * m - remaining))
			_bump(Vector2(1.14, 0.88), Vector2(2.0, -2.0), 3.8)
			AudioManager.play_troop_absorb(false)
		elif float(count) == power:
			troops = 0
			fortress_absorbed_damage = 0
			if faction != GameManager.Faction.NEUTRAL:
				_change_faction(GameManager.Faction.NEUTRAL)
			else:
				# Agotamiento de guarnición neutral previa a conquista
				_bump(Vector2(1.15, 0.85), Vector2(2.5, -2.5), 4.0)
				AudioManager.play_troop_absorb(false)
		else:
			# Conquista
			troops = maxi(1, count - ceili(power))
			fortress_absorbed_damage = 0
			_change_faction(incoming_faction)
	_update_label()
	_dirty = true

func _bump(squash: Vector2, velocity: Vector2, shake: float) -> void:
	elastic_scale = squash
	elastic_velocity += velocity
	shake_intensity = shake

func _change_faction(new_faction: int) -> void:
	var prev_faction = faction
	faction = new_faction
	_trigger_conquest_shockwave(new_faction)
	AudioManager.play_capture()
	EventBus.base_captured.emit(self, prev_faction, new_faction)

func _update_label() -> void:
	if label_troops:
		label_troops.text = str(troops)

func _draw() -> void:
	var color = GameManager.faction_color(faction)
	var current_radius = radius * pulse_scale
	if is_capital or is_boss:
		var marker := "👑" if is_boss else "★"
		draw_string(ThemeDB.fallback_font, Vector2(-30, -current_radius - 30), marker, HORIZONTAL_ALIGNMENT_CENTER, 60, 34, UIThemeHelper.COLOR_GOLD)

	# 1. Onda expansiva de impacto y conquista
	if shockwave_alpha > 0.0:
		var sw_col = Color(shockwave_color, shockwave_alpha * 0.85)
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 48, sw_col, maxf(1.0, 5.0 * shockwave_alpha), true)
		draw_circle(Vector2.ZERO, shockwave_radius, Color(shockwave_color, shockwave_alpha * 0.18))

	# Aplicar transformación de sacudida y escala elástica
	draw_set_transform(shake_offset, 0.0, elastic_scale)

	# 2. Sombra suave (una sola capa)
	draw_circle(Vector2(0, 6), current_radius + 5.0, Color(0, 0, 0, 0.22))

	# 3. Anillo de selección exterior si está seleccionada
	if is_selected:
		draw_circle(Vector2.ZERO, current_radius + 14.0, Color(1, 1, 1, 0.22))
		draw_arc(Vector2.ZERO, current_radius + 11.0, 0, TAU, 48, Color.WHITE, 4.0, true)

	# 4. Borde exterior y elementos tácticos distintivos según BaseType
	if base_type == BaseType.FORTRESS:
		# Borde reforzado con almenas de bastión defensivo
		draw_circle(Vector2.ZERO, current_radius + 6.5, Color(0.2, 0.22, 0.26))
		draw_circle(Vector2.ZERO, current_radius + 5.0, Color.WHITE)
		for i in 8:
			var c_pos = Vector2.from_angle(i * TAU / 8.0) * (current_radius + 5.0)
			draw_circle(c_pos, 4.8, Color.WHITE)
			draw_circle(c_pos, 3.0, Color(0.3, 0.35, 0.4))
	elif base_type == BaseType.FACTORY:
		# Engranaje industrial perimetral giratorio
		draw_circle(Vector2.ZERO, current_radius + 5.0, Color.WHITE)
		for i in 8:
			var t_pos = Vector2.from_angle(i * TAU / 8.0 + factory_gear_angle) * (current_radius + 4.5)
			draw_circle(t_pos, 4.8, Color(1.0, 0.8, 0.2, 0.95))
			draw_circle(t_pos, 2.5, Color(0.25, 0.2, 0.1))
	else:
		draw_frame(self, Vector2.ZERO, current_radius, GameManager.base_shape())

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

	# 7. Símbolo de facción (accesibilidad para daltonismo: no depender sólo del color)
	_draw_faction_symbol(Vector2(0, -current_radius * 0.62), 5.5)

	# 8. Indicadores de Tier (pips redondeados en la parte superior)
	var pip_spacing = 16.0
	var start_x = -((tier - 1) * pip_spacing) / 2.0
	for i in tier:
		draw_circle(Vector2(start_x + i * pip_spacing, -current_radius - 12.0), 4.5, Color.WHITE)

	# 9. Alerta Visual de Asedio Inminente
	if is_under_siege:
		_draw_siege_alert(current_radius)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_faction_symbol(center: Vector2, s: float) -> void:
	var col = Color(1, 1, 1, 0.85)
	match faction:
		GameManager.Faction.PLAYER:
			draw_circle(center, s * 0.8, col)
		GameManager.Faction.ENEMY_1:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, s * 0.8), center + Vector2(-s, s * 0.8)]), col)
		GameManager.Faction.ENEMY_2:
			draw_rect(Rect2(center - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col)
		GameManager.Faction.ENEMY_3:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(0, s), center + Vector2(-s, 0)]), col)

## Marco exterior de la base estándar según la forma de la tienda (también en la vista previa de Ejército)
static func draw_frame(canvas: CanvasItem, center: Vector2, r: float, shape: String) -> void:
	match shape:
		"base_square":
			var half := r + 4.5
			canvas.draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), Color.WHITE, true)
		"base_diamond":
			var d := r + 6.0
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -d), center + Vector2(d, 0), center + Vector2(0, d), center + Vector2(-d, 0)]), Color.WHITE)
		_:
			canvas.draw_circle(center, r + 4.5, Color.WHITE)

func _draw_siege_alert(current_radius: float) -> void:
	var p = (sin(siege_pulse_time) + 1.0) * 0.5
	var halo_r = current_radius + 12.0 + p * 8.0
	draw_arc(Vector2.ZERO, halo_r, 0, TAU, 48, Color(1.0, 0.15, 0.15, 0.45 + p * 0.45), 4.0, true)
	draw_circle(Vector2.ZERO, halo_r, Color(1.0, 0.1, 0.1, 0.07 + p * 0.08))

	# Marcador de advertencia animado sobre el territorio
	var badge_center = Vector2(0, -current_radius - 32.0 + sin(siege_pulse_time * 1.5) * 4.0)
	draw_circle(badge_center, 18.0 + p * 3.0, Color(1.0, 0.2, 0.2, 0.35 * p))

	var tri_size = 17.0
	var p_top = badge_center + Vector2(0, -tri_size * 0.95)
	var p_right = badge_center + Vector2(tri_size * 0.95, tri_size * 0.65)
	var p_left = badge_center + Vector2(-tri_size * 0.95, tri_size * 0.65)
	var shadow = Vector2(0, 3)
	draw_colored_polygon(PackedVector2Array([p_top + shadow, p_right + shadow, p_left + shadow]), Color(0, 0, 0, 0.35))
	draw_colored_polygon(PackedVector2Array([p_top, p_right, p_left]), Color(1.0, 0.82, 0.1))
	draw_polyline(PackedVector2Array([p_top, p_right, p_left, p_top]), Color(0.9, 0.15, 0.1), 2.2, true)

	var ink = Color(0.12, 0.12, 0.12)
	draw_line(badge_center + Vector2(0, -tri_size * 0.28), badge_center + Vector2(0, tri_size * 0.16), ink, 2.8, true)
	draw_circle(badge_center + Vector2(0, tri_size * 0.38), 1.7, ink)
