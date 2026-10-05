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
## Colores del mapa: no dependen del modo claro/oscuro de la interfaz
const MARKER_GOLD := Color("ffc83d")
const FLOAT_TEXT_SECONDS := 1.6
## Radianes por segundo de órbita por cada tropa/s producida (la fábrica gira 2,5× más rápido)
const ORBIT_SPEED := 1.3
const RING_GAP := 12.0
const BADGE_RADIUS := 23.0
## Insignia de cada ventaja: icono, fondo y tinte del icono
const BADGES := {
	"boss": ["", Color("7a1f2b"), Color.WHITE],
	"capital": ["star", Color("1b2638"), Color.WHITE],
	"factory": ["bolt", MARKER_GOLD, Color("5a3c00")],
	"fortress": ["shield", Color("3d4f66"), Color.WHITE],
}

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
## Ángulo de los puntos que orbitan el anillo: giran a la velocidad de producción
var orbit_angle: float = 0.0

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
## Avance hasta los próximos refuerzos del jefe (0..1); < 0 si no aplica
var reinforce_progress: float = -1.0
## Textos flotantes breves sobre la base: {"text", "color", "t"}
var _float_texts: Array[Dictionary] = []

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

## Defensa estimada dentro de `seconds`: una base con dueño sigue reclutando hasta llenarse
func defense_after(seconds: float) -> float:
	if faction == GameManager.Faction.NEUTRAL or not is_active:
		return get_defense_power()
	var future_troops := minf(float(max_capacity), troops + get_production_rate() * maxf(0.0, seconds))
	return maxf(get_defense_power(), future_troops * get_defense_multiplier() - fortress_absorbed_damage)

func is_full() -> bool:
	return faction != GameManager.Faction.NEUTRAL and troops >= max_capacity

## Recluta ahora mismo (con dueño, en juego y con sitio libre)
func is_producing() -> bool:
	return is_active and faction != GameManager.Faction.NEUTRAL and not is_full()

## Texto breve que sube y se desvanece sobre la base (conquistas especiales, refuerzos...)
func float_text(text: String, color: Color = Color.WHITE) -> void:
	_float_texts.append({"text": text, "color": color, "t": 0.0})
	_dirty = true

## Qué aporta esta base a su dueño, en una línea (vacío si es una base normal)
func perk_text() -> String:
	var parts: PackedStringArray = []
	if is_boss:
		parts.append(LocaleStrings.text("perk_boss"))
	if is_capital:
		parts.append(LocaleStrings.text("perk_capital") % roundi((production_bonus - 1.0) * 100.0))
	match base_type:
		BaseType.FACTORY:
			parts.append(LocaleStrings.text("perk_factory"))
		BaseType.FORTRESS:
			parts.append(LocaleStrings.text("perk_fortress"))
	return " · ".join(parts)

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

## Acepta el enum o el texto de las definiciones de nivel ("fortress" / "factory")
func _set_type_from_variant(v) -> void:
	if v is int:
		base_type = v as BaseType
	else:
		base_type = {"fortress": BaseType.FORTRESS, "factory": BaseType.FACTORY}.get(v, BaseType.STANDARD)

func setup(data: Dictionary) -> void:
	is_active = true
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
		label_name.position.y = radius + 20.0
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

	var animating := _animate(delta) or reinforce_progress >= 0.0
	if animating or _dirty:
		_dirty = false
		if label_troops:
			label_troops.position = Vector2(-50.0, -25.0) + shake_offset
			label_troops.scale = elastic_scale * pulse_scale
		queue_redraw()

## Avanza las animaciones y devuelve true mientras alguna siga activa
func _animate(delta: float) -> bool:
	var animating := false
	if is_producing() and not GameManager.settings["reduced_motion"]:
		orbit_angle = fmod(orbit_angle + delta * get_production_rate() * ORBIT_SPEED, TAU)
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

	for i in range(_float_texts.size() - 1, -1, -1):
		animating = true
		_float_texts[i]["t"] += delta
		if _float_texts[i]["t"] >= FLOAT_TEXT_SECONDS:
			_float_texts.remove_at(i)

	if shake_intensity > 0.0:
		shake_intensity = 0.0 if GameManager.settings["reduced_motion"] else maxf(0.0, shake_intensity - delta * 22.0)
		shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		animating = true
	elif shake_offset != Vector2.ZERO:
		shake_offset = Vector2.ZERO
		animating = true

	if shockwave_alpha > 0.0:
		shockwave_radius += delta * (radius * 4.5)
		shockwave_alpha = maxf(0.0, shockwave_alpha - delta * 2.6)
		animating = true

	if is_under_siege and not GameManager.settings["reduced_motion"]:
		siege_pulse_time += delta * 6.5
		animating = true
	if GameManager.settings["reduced_motion"]:
		elastic_scale = Vector2.ONE
		elastic_velocity = Vector2.ZERO
		pulse_scale = 1.0
		shockwave_alpha = 0.0
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
	var perk := perk_text()
	if new_faction == GameManager.Faction.PLAYER and perk != "":
		# Las bases especiales explican lo que acabas de ganar y celebran algo más fuerte
		float_text(perk, MARKER_GOLD)
		shockwave_alpha = 1.0
		elastic_scale = Vector2(1.45, 1.45)
	elif prev_faction == GameManager.Faction.PLAYER:
		float_text(LocaleStrings.text("base_lost"), UIThemeHelper.colors.danger.lightened(0.2))
	EventBus.base_captured.emit(self, prev_faction, new_faction)

func _update_label() -> void:
	if label_troops:
		label_troops.text = str(troops)

func _draw() -> void:
	var color = GameManager.faction_color(faction)
	var current_radius = radius * pulse_scale
	# Refuerzos del jefe: el arco se llena hasta la próxima oleada
	if reinforce_progress >= 0.0:
		draw_arc(Vector2.ZERO, current_radius + RING_GAP + 10.0, -PI * 0.5, -PI * 0.5 + TAU * reinforce_progress, 48, Color(MARKER_GOLD, 0.85), 4.0, true)

	# 1. Onda expansiva de impacto y conquista
	if shockwave_alpha > 0.0:
		var sw_col = Color(shockwave_color, shockwave_alpha * 0.85)
		draw_arc(Vector2.ZERO, shockwave_radius, 0, TAU, 48, sw_col, maxf(1.0, 5.0 * shockwave_alpha), true)
		draw_circle(Vector2.ZERO, shockwave_radius, Color(shockwave_color, shockwave_alpha * 0.18))

	# Aplicar transformación de sacudida y escala elástica
	draw_set_transform(shake_offset, 0.0, elastic_scale)

	# 2. Sombra suave (una sola capa)
	draw_circle(Vector2(0, 6), current_radius + 5.0, Color(0, 0, 0, 0.22))

	# 3. Halo de selección por fuera del anillo de capacidad
	if is_selected:
		draw_circle(Vector2.ZERO, current_radius + RING_GAP + 12.0, Color(1, 1, 1, 0.18))
		draw_arc(Vector2.ZERO, current_radius + RING_GAP + 9.0, 0, TAU, 48, Color.WHITE, 4.0, true)

	# 4. Marco y cuerpo: el tamaño ya indica el nivel; las ventajas van en insignias
	draw_frame(self, Vector2.ZERO, current_radius, GameManager.base_shape())
	draw_circle(Vector2.ZERO, current_radius, color)

	# 5. Símbolo de facción sólo en modo daltónico (el color ya distingue los bandos)
	if GameManager.settings.get("colorblind", false):
		draw_faction_symbol(self, Vector2(0, -current_radius * 0.62), 5.5, faction)

	# 6. Anillo de capacidad (se cierra al llenarse) y producción en órbita
	if faction != GameManager.Faction.NEUTRAL:
		_draw_capacity_ring(current_radius + RING_GAP)

	# 7. Insignias de ventaja en el borde superior derecho
	var badge_angle := -PI * 0.25
	var badge_step: float = (BADGE_RADIUS * 2.0 + 10.0) / (current_radius + 4.0)
	for key in _badge_keys():
		_draw_badge(Vector2.from_angle(badge_angle) * (current_radius + 4.0), key)
		badge_angle += badge_step

	# 8. Alerta Visual de Asedio Inminente
	if is_under_siege:
		_draw_siege_alert(current_radius)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_float_texts()

func _draw_capacity_ring(r: float) -> void:
	var fill := clampf(troops / float(max_capacity), 0.0, 1.0)
	draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(1, 1, 1, 0.16), 4.0, true)
	if fill >= 1.0:
		draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color(1, 1, 1, 0.22), 10.0, true)
		draw_arc(Vector2.ZERO, r, 0, TAU, 56, Color.WHITE, 4.0, true)
	elif fill > 0.0:
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * fill, 56, Color(1, 1, 1, 0.85), 4.0, true)
	if is_producing():
		var color := GameManager.faction_color(faction)
		for k in 2:
			var p := Vector2.from_angle(orbit_angle + k * PI) * r
			draw_circle(p, 9.0, Color(0, 0, 0, 0.35))
			draw_circle(p, 7.5, Color.WHITE)
			draw_circle(p, 4.0, color)

func _badge_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	if is_boss:
		keys.append("boss")
	if is_capital:
		keys.append("capital")
	match base_type:
		BaseType.FACTORY:
			keys.append("factory")
		BaseType.FORTRESS:
			keys.append("fortress")
	return keys

func _draw_badge(c: Vector2, key: String) -> void:
	var style: Array = BADGES[key]
	draw_circle(c + Vector2(0, 3), BADGE_RADIUS + 3.0, Color(0, 0, 0, 0.3))
	draw_circle(c, BADGE_RADIUS + 3.0, Color.WHITE)
	draw_circle(c, BADGE_RADIUS, style[1])
	if key == "boss":
		_draw_crown(c + Vector2(0, 2), 13.0)
	else:
		var size := BADGE_RADIUS * 1.35
		draw_texture_rect(Icons.texture(style[0], 32), Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false, style[2])

func _draw_float_texts() -> void:
	var font := UIThemeHelper.bold_font()
	for ft in _float_texts:
		var k: float = ft["t"] / FLOAT_TEXT_SECONDS
		var pos := Vector2(-200, -radius - 60.0 - (0.0 if GameManager.settings["reduced_motion"] else k * 50.0))
		var alpha := 1.0 - smoothstep(0.6, 1.0, k)
		draw_string_outline(font, pos, ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 28, 8, Color(0, 0, 0, 0.75 * alpha))
		draw_string(font, pos, ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(ft["color"], alpha))

func _draw_crown(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(-r, -r * 0.5), c + Vector2(-r * 0.5, 0),
		c + Vector2(0, -r * 0.8), c + Vector2(r * 0.5, 0), c + Vector2(r, -r * 0.5), c + Vector2(r, r * 0.6)])
	draw_colored_polygon(pts, MARKER_GOLD)

static func draw_faction_symbol(canvas: CanvasItem, center: Vector2, s: float, owner: int) -> void:
	var col = Color(1, 1, 1, 0.85)
	match owner:
		GameManager.Faction.PLAYER:
			canvas.draw_circle(center, s * 0.8, col)
		GameManager.Faction.ENEMY_1:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, s * 0.8), center + Vector2(-s, s * 0.8)]), col)
		GameManager.Faction.ENEMY_2:
			canvas.draw_rect(Rect2(center - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col)
		GameManager.Faction.ENEMY_3:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s), center + Vector2(s, 0), center + Vector2(0, s), center + Vector2(-s, 0)]), col)

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
