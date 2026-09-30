extends Node2D
class_name BattleController

## BattleController: Gestor de la partida, entrada del jugador, IA y condiciones de fin

const BaseNodeScene = preload("res://scenes/battle/base_node.tscn")
const TroopScene = preload("res://scenes/battle/troop.tscn")
const TutorialOverlayScript = preload("res://scripts/battle/tutorial_overlay.gd")

## Distancia máxima entre los paquetes delanteros de dos columnas enfrentadas para que combatan
const HEAD_ON_RANGE: float = Troop.PACKET_RADIUS * 2.0
const SLOW_MOTION_TARGET: float = 0.28
const SLOW_MOTION_SPEED: float = 2.5
const SLICE_WIDTH := 6.5
const CUT_FLASH_TIME := 0.35
const BOSS_INTERVAL := 18.0
const BOSS_REINFORCEMENT := 10
## Segundos que se muestra la ficha de una base tras tocarla
const INFO_SECONDS := 2.6
## Un toque que se mueve menos que esto no es un arrastre ni un corte
const TAP_SLOP := 24.0
@export var level_id: String = "europe_1"

var bases: Array[BaseNode] = []
var active_troops: Array[Troop] = []
var ai_controllers: Array[AIController] = []

var selected_sources: Array[BaseNode] = []
var hovered_target: BaseNode = null
var candidate_chained_base: BaseNode = null
var is_dragging: bool = false
var drag_current_pos: Vector2 = Vector2.ZERO
var prev_drag_pos: Vector2 = Vector2.ZERO
var drag_velocity: Vector2 = Vector2.ZERO
var marching_dots_phase: float = 0.0

var is_slicing: bool = false
var slice_points: Array[Vector2] = []
var slice_trail_segments: Array[Dictionary] = []
var slice_cut_flash_effects: Array[Dictionary] = []

var is_game_over: bool = false
var simulation_paused: bool = false
var battle_time: float = 0.0
var target_time: float = 45.0
var level_data: Dictionary = {}

var is_slow_motion_active: bool = false
## Escala de tiempo de reposo (el tutorial la reduce temporalmente para enseñar el corte)
var base_time_scale: float = 1.0

var _overlay_was_active: bool = false
var _shake: float = 0.0
var _tutorial: Node = null
var _boss_timer: float = BOSS_INTERVAL
var _max_speed: float = 1.0
var _press_pos: Vector2 = Vector2.ZERO
## Base cuya ficha (tropas, producción, ventaja) se muestra tras tocarla
var _info_base: BaseNode = null
var _info_timer: float = 0.0
## Medalla de dominio: ganar sin perder ninguna base
var lost_a_base: bool = false
var _captures: int = 0
## La última base del jugador cayó mientras tenía tropas en marcha
var _fell_with_troops_out: bool = false
var _objective_held: float = 0.0
var _remate_seconds := 0.0
var _remate_used := false

@onready var bases_container: Node2D = get_node_or_null("BasesContainer")
@onready var troops_container: Node2D = get_node_or_null("TroopsContainer")
@onready var arrow_overlay: Node2D = get_node_or_null("ArrowOverlay")
@onready var territory_map: Node2D = get_node_or_null("TerritoryMap")
@onready var camera: Camera2D = get_node_or_null("Camera2D")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_gesture()
		GameManager.save_game()

func _exit_tree() -> void:
	reset_time_scale()
	GameManager.normalized_battle = false

func _ready() -> void:
	load_level(GameManager.get_battle_level_id())
	AudioManager.play_music("battle")
	EventBus.base_captured.connect(_on_base_captured)
	EventBus.troop_arrived.connect(_on_troop_arrived)
	EventBus.settings_changed.connect(_refresh_colors)
	if arrow_overlay:
		arrow_overlay.draw.connect(_draw_drag_overlay)

func start_slow_motion() -> void:
	is_slow_motion_active = true

func reset_time_scale() -> void:
	is_slow_motion_active = false
	base_time_scale = 1.0
	Engine.time_scale = 1.0

## Congela producción e IA (lo usa el tutorial mientras enseña el primer gesto)
func set_simulation_paused(paused: bool) -> void:
	simulation_paused = paused
	for ai in ai_controllers:
		ai.set_process(not paused)
	for b in bases:
		b.is_active = not paused

## Monta el nivel una sola vez, al entrar en la escena (reintentar recarga la escena)
func load_level(p_level_id: String) -> void:
	reset_time_scale()
	level_id = p_level_id
	_max_speed = float(GameManager.settings["speed"])
	# El desafío diario se compara entre jugadores: se juega sin mejoras de combate
	GameManager.normalized_battle = DailyRewards.is_challenge(level_id)
	level_data = LevelDatabase.get_level_data(level_id)
	target_time = level_data.get("target_time", 45.0)

	# Curva de dificultad: los enemigos producen más rápido a medida que avanza la campaña
	GameManager.enemy_production_multiplier = lerpf(0.9, 1.35, LevelDatabase.get_difficulty(level_id))

	# Instanciar bases según los datos del nivel
	var enemy_factions_present: Array[int] = []
	for b_def in level_data.get("bases", []):
		var base_inst: BaseNode = BaseNodeScene.instantiate()
		(bases_container if bases_container else self).add_child(base_inst)
		base_inst.setup(b_def)
		bases.append(base_inst)
		var f = base_inst.faction
		if f != GameManager.Faction.NEUTRAL and f != GameManager.Faction.PLAYER and not enemy_factions_present.has(f):
			enemy_factions_present.append(f)

	# Mapa político de estados y partición territorial Voronoi
	if territory_map:
		var geo: Dictionary = level_data.get("geo", {})
		# Con geografía, los territorios cubren toda la tierra visible (también en pantallas altas)
		territory_map.generate_map(bases, LevelGenerator.GEO_CLIP_RECT if geo else Rect2(), geo)
		_apply_map_theme()

	# IA para cada facción enemiga
	for ef in enemy_factions_present:
		var ai: AIController = AIController.new()
		add_child(ai)
		ai.setup(self, ef)
		ai_controllers.append(ai)

	# Las mejoras compradas se notan desde el primer segundo
	var bonus := GameManager.get_starting_troops_bonus()
	if bonus > 0:
		for b in bases:
			if b.faction == GameManager.Faction.PLAYER:
				b.float_text("+%d" % bonus, Color.WHITE)

	# Tutorial interactivo en los primeros niveles (sólo en la escena real de batalla, con HUD)
	if bases_container and TutorialOverlayScript.has_pending_steps(level_id, level_data):
		_tutorial = TutorialOverlayScript.new()
		add_child(_tutorial)
		_tutorial.setup(self)

	queue_redraw()
	EventBus.battle_started.emit(level_id)

## Tema de mapa equipado en la tienda: fondo y tierra firme
func _apply_map_theme() -> void:
	var theme := GameManager.map_theme()
	var bg := get_node_or_null("Background")
	if bg is ColorRect:
		(bg as ColorRect).color = theme.get("bg", Color(0.07, 0.11, 0.16))
	if territory_map and theme.has("land"):
		territory_map.land_color = theme["land"]

func _process(delta: float) -> void:
	if not is_game_over:
		_max_speed = maxf(_max_speed, float(GameManager.settings["speed"]))
		# El reloj (estrellas y periodo de gracia de la IA) no corre mientras el tutorial espera
		if not simulation_paused:
			battle_time += delta
			_process_boss(delta)
			_update_level_objective(delta)
			for t in active_troops.duplicate():
				if _is_alive(t):
					t.advance(delta)
			_process_troop_collisions()
			for t in active_troops.duplicate():
				if _is_alive(t):
					t.resolve_arrivals()
		_check_decisive_assault()
		_update_siege_alerts()
		_check_game_over_conditions()

	# Transición suave de cámara lenta
	var unscaled_dt = delta / maxf(Engine.time_scale, 0.01)
	if is_slow_motion_active and not is_game_over:
		_remate_seconds += unscaled_dt
		if _remate_seconds >= 0.65:
			is_slow_motion_active = false
			_remate_used = true
	if is_slow_motion_active:
		Engine.time_scale = move_toward(Engine.time_scale, SLOW_MOTION_TARGET, unscaled_dt * SLOW_MOTION_SPEED)
	elif not is_game_over:
		Engine.time_scale = move_toward(Engine.time_scale, base_time_scale * float(GameManager.settings["speed"]), unscaled_dt * SLOW_MOTION_SPEED)

	if _info_timer > 0.0:
		_info_timer -= unscaled_dt

	# Temblor de cámara tras conquistas importantes
	if camera:
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - unscaled_dt * 30.0)
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO

	# Animación de marcha de puntos y amortiguación de velocidad de arrastre
	marching_dots_phase = fmod(marching_dots_phase + delta * 1.6, 1.0)
	drag_velocity = drag_velocity.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))

	# Desvanecimiento de estelas y destellos de corte
	for i in range(slice_trail_segments.size() - 1, -1, -1):
		slice_trail_segments[i]["alpha"] -= delta * 3.8
		if slice_trail_segments[i]["alpha"] <= 0.0:
			slice_trail_segments.remove_at(i)
	for j in range(slice_cut_flash_effects.size() - 1, -1, -1):
		slice_cut_flash_effects[j]["timer"] -= delta
		if slice_cut_flash_effects[j]["timer"] <= 0.0:
			slice_cut_flash_effects.remove_at(j)

	# Redibujar la capa de flechas sólo mientras haya algo que mostrar (y un último frame para limpiarla)
	var overlay_active = is_dragging or is_slicing or _info_timer > 0.0 or not slice_trail_segments.is_empty() or not slice_cut_flash_effects.is_empty()
	if overlay_active or _overlay_was_active:
		if arrow_overlay:
			arrow_overlay.queue_redraw()
		else:
			queue_redraw()
	_overlay_was_active = overlay_active

func shake_camera(amount: float) -> void:
	if not GameManager.settings["reduced_motion"]:
		_shake = maxf(_shake, amount)

func _refresh_colors() -> void:
	if GameManager.settings["reduced_motion"]:
		_shake = 0.0
	for base in bases:
		base.queue_redraw()
	for troop in active_troops:
		if is_instance_valid(troop):
			troop.queue_redraw()
	if territory_map:
		for cell in territory_map.cells:
			cell.current_color = territory_map.get_faction_territory_color(cell.base_node.faction)
			cell.target_color = cell.current_color
			cell.start_color = cell.current_color
		territory_map.queue_redraw()

## El jefe recibe refuerzos cada BOSS_INTERVAL s mientras siga en manos de su dueño original;
## un arco sobre la base anuncia la próxima oleada
func _process_boss(delta: float) -> void:
	_boss_timer -= delta
	var wave := _boss_timer <= 0.0
	if wave:
		_boss_timer += BOSS_INTERVAL
	for base in bases:
		var active := base.is_boss and base.faction == GameManager.Faction.ENEMY_1
		base.reinforce_progress = 1.0 - _boss_timer / BOSS_INTERVAL if active else -1.0
		if wave and active and base.troops < base.max_capacity:
			base.troops = mini(base.max_capacity, base.troops + BOSS_REINFORCEMENT)
			base._update_label()
			base.float_text("+%d" % BOSS_REINFORCEMENT, BaseNode.MARKER_GOLD)
			base.queue_redraw()

func can_dispatch(from_base: BaseNode, to_base: BaseNode) -> bool:
	if from_base == to_base:
		return false
	if not level_data.has("sea_lanes"):
		return true
	var a := bases.find(from_base)
	var b := bases.find(to_base)
	return level_data["sea_lanes"].has(Vector2i(a, b)) or level_data["sea_lanes"].has(Vector2i(b, a))

func _update_siege_alerts() -> void:
	for b in bases:
		b.update_siege_status(active_troops)

## Tropa en juego: no liberada, no pendiente de borrar y con unidades
static func _is_alive(t) -> bool:
	return is_instance_valid(t) and not t.is_queued_for_deletion() and t.count > 0

func _incoming_player_troops(target: BaseNode) -> Array:
	var total := 0
	var is_close := false
	for t in active_troops:
		if _is_alive(t) and t.faction == GameManager.Faction.PLAYER and t.target_base == target:
			total += t.count
			if t.global_position.distance_to(target.global_position) <= target.radius + 200.0:
				is_close = true
	return [total, is_close]

func _check_decisive_assault() -> void:
	if _remate_used or GameManager.settings["reduced_motion"]:
		return
	var enemy_bases: Array[BaseNode] = []
	for b in bases:
		if b.faction != GameManager.Faction.PLAYER and b.faction != GameManager.Faction.NEUTRAL:
			enemy_bases.append(b)

	# Si la cámara lenta ya está activa, verificar si el asalto decisivo ha concluido o fracasado
	if is_slow_motion_active:
		if enemy_bases.size() > 1 or (enemy_bases.size() == 1 and _incoming_player_troops(enemy_bases[0])[0] == 0):
			is_slow_motion_active = false
		return

	# Caso 1: Asalto decisivo sobre la última base enemiga
	if enemy_bases.size() == 1:
		var incoming = _incoming_player_troops(enemy_bases[0])
		if incoming[0] > enemy_bases[0].get_effective_defense() and incoming[1]:
			start_slow_motion()
	# Caso 2: Golpe de gracia sobre la última tropa hostil (0 bases enemigas)
	elif enemy_bases.is_empty():
		var any_enemy := false
		var any_close := false
		for et in active_troops:
			if not _is_alive(et) or et.faction == GameManager.Faction.PLAYER or et.faction == GameManager.Faction.NEUTRAL:
				continue
			any_enemy = true
			var pb = et.target_base
			if not is_instance_valid(pb) or pb.faction != GameManager.Faction.PLAYER or et.count > pb.get_effective_defense():
				return
			if et.global_position.distance_to(pb.global_position) <= pb.radius + 200.0:
				any_close = true
		if any_enemy and any_close:
			start_slow_motion()

## ponytail: compara pares de órdenes, hasta 8 paquetes por orden; usar una rejilla espacial
## si se añaden mapas con cientos de órdenes simultáneas.
func _process_troop_collisions() -> void:
	var n = active_troops.size()
	for i in n:
		var t1 = active_troops[i]
		if not _is_alive(t1) or t1.packets.is_empty():
			continue
		for j in range(i + 1, n):
			var t2 = active_troops[j]
			if not _is_alive(t2) or t2.packets.is_empty():
				continue
			if t1.faction == t2.faction or t1.faction == GameManager.Faction.NEUTRAL or t2.faction == GameManager.Faction.NEUTRAL:
				continue
			if t1.origin_base == t2.target_base and t1.target_base == t2.origin_base:
				_resolve_head_on(t1, t2)
			else:
				_resolve_crossing(t1, t2)
			if not _is_alive(t1):
				break

	for t in active_troops.duplicate():
		if is_instance_valid(t) and t.count <= 0 and not t.packets.is_empty():
			_destroy_troop(t)

func _resolve_head_on(t1: Troop, t2: Troop) -> void:
	var separation := (t2.start_pos - t1.start_pos).dot(t1.move_dir)
	if separation <= 0.0:
		return
	while true:
		var f1 = t1.front_index()
		var f2 = t2.front_index()
		if f1 < 0 or f2 < 0:
			return
		var d1 = t1.packet_dist(f1)
		var d2 = t2.packet_dist(f2)
		if d1 < 0.0 or d2 < 0.0 or separation - d1 - d2 > HEAD_ON_RANGE:
			return
		_clash(t1, f1, t2, f2)

func _resolve_crossing(t1: Troop, t2: Troop) -> void:
	var r = t1.move_dir * t1.path_length
	var s = t2.move_dir * t2.path_length
	var denom = r.cross(s)
	if absf(denom) < 0.0001:
		if t1.move_dir.dot(t2.move_dir) < -0.999 and absf((t2.start_pos - t1.start_pos).cross(t1.move_dir)) < 1.0:
			_resolve_head_on(t1, t2)
		return
	var qp = t2.start_pos - t1.start_pos
	var k1 = qp.cross(s) / denom
	var k2 = qp.cross(r) / denom
	if k1 < 0.0 or k1 > 1.0 or k2 < 0.0 or k2 > 1.0:
		return
	var near1 = t1.packets_near(k1 * t1.path_length)
	var near2 = t2.packets_near(k2 * t2.path_length)
	var a := 0
	var b := 0
	while a < near1.size() and b < near2.size():
		_clash(t1, near1[a], t2, near2[b])
		if t1.packets[near1[a]] <= 0:
			a += 1
		if t2.packets[near2[b]] <= 0:
			b += 1

func _clash(t1: Troop, i1: int, t2: Troop, i2: int) -> void:
	var dmg = mini(t1.packets[i1], t2.packets[i2])
	t1.damage_packet(i1, dmg)
	t2.damage_packet(i2, dmg)
	AudioManager.play_troop_absorb(false)

func _destroy_troop(t: Troop) -> void:
	active_troops.erase(t)
	if t.is_inside_tree():
		t.queue_free()
	else:
		t.free()

# =========================================================================
# Entrada táctil (un solo dedo; el ratón de escritorio se emula como toque)
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.canceled:
			_cancel_gesture()
			return
		var pos = _screen_to_world(event.position)
		if event.pressed:
			_handle_press(pos)
		else:
			_handle_release(pos)
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		var pos = _screen_to_world(event.position)
		if is_dragging:
			_handle_drag(pos)
		elif is_slicing:
			_handle_slice_motion(pos)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos

func _cancel_gesture() -> void:
	for src in selected_sources:
		if is_instance_valid(src):
			src.set_selected(false)
	selected_sources.clear()
	hovered_target = null
	candidate_chained_base = null
	is_dragging = false
	is_slicing = false
	slice_points.clear()

func _handle_press(pos: Vector2) -> void:
	var base = _get_base_at(pos)
	_cancel_gesture()
	_press_pos = pos
	if base and base.faction == GameManager.Faction.PLAYER:
		is_dragging = true
		_add_selected_source(base)
		drag_current_pos = pos
		prev_drag_pos = pos
		drag_velocity = Vector2.ZERO
		AudioManager.play_click()
	else:
		is_slicing = true
		slice_points.append(pos)

func _handle_slice_motion(pos: Vector2) -> void:
	if slice_points.back().distance_to(pos) >= 5.0:
		_add_slice_segment(pos)

func _add_slice_segment(pos: Vector2) -> void:
	var prev_pt: Vector2 = slice_points.back()
	slice_points.append(pos)
	slice_trail_segments.append({"p1": prev_pt, "p2": pos, "alpha": 1.0})
	_check_slice_intersections(prev_pt, pos)

func _check_slice_intersections(p1: Vector2, p2: Vector2) -> void:
	var any_cut = false
	# Copia: una retirada que se reintegra al instante sale de active_troops durante el bucle
	for t in active_troops.duplicate():
		if _is_alive(t) and t.faction == GameManager.Faction.PLAYER and t.intersects_segment(p1, p2):
			t.abort_mission()
			any_cut = true
			slice_cut_flash_effects.append({"pos": (p1 + p2) * 0.5, "timer": CUT_FLASH_TIME})
	if any_cut:
		AudioManager.play_troop_retreat()
		GameManager.haptic(15)
		EventBus.troops_retreated.emit(GameManager.Faction.PLAYER)

func _handle_drag(pos: Vector2) -> void:
	drag_velocity = drag_velocity.lerp((pos - prev_drag_pos) * 30.0, 0.4)
	prev_drag_pos = pos
	drag_current_pos = pos
	var base = _get_base_at(pos)

	if base != null:
		# Entrar en otra base confirma la candidata previa como nodo intermedio de encadenamiento
		if candidate_chained_base and candidate_chained_base != base:
			_confirm_chained_candidate()
		if not selected_sources.has(base):
			hovered_target = base
			# Si es aliada, marcarla como candidata para encadenar si el arrastre sigue adelante
			if base.faction == GameManager.Faction.PLAYER:
				candidate_chained_base = base
		else:
			hovered_target = null
	else:
		# Cursor en espacio abierto: la candidata que hemos atravesado se suma al asalto
		if candidate_chained_base:
			_confirm_chained_candidate()
		hovered_target = null

func _confirm_chained_candidate() -> void:
	_add_selected_source(candidate_chained_base)
	candidate_chained_base = null
	AudioManager.play_click()
	GameManager.haptic(8)

func _handle_release(pos: Vector2) -> void:
	var is_tap := pos.distance_to(_press_pos) < TAP_SLOP
	if is_slicing:
		if not slice_points.is_empty() and slice_points.back().distance_to(pos) >= 4.0:
			_add_slice_segment(pos)
		is_slicing = false
		slice_points.clear()
		if is_tap:
			show_base_info(_get_base_at(pos))
		return

	if not is_dragging:
		return
	is_dragging = false

	var target = _get_base_at(pos)
	# Una base aliada candidata se suma al asalto combinado si soltamos sobre otro objetivo
	if candidate_chained_base and target != candidate_chained_base:
		_add_selected_source(candidate_chained_base)
	candidate_chained_base = null

	if target != null:
		var sources: Array[BaseNode] = []
		if selected_sources.has(target):
			if is_tap and selected_sources.size() == 1:
				show_base_info(target)
			# Arrastre desde otras bases hacia esta base aliada para reforzarla
			elif selected_sources.size() > 1 and selected_sources.back() == target:
				selected_sources.erase(target)
				target.set_selected(false)
				sources = selected_sources
		else:
			sources = selected_sources
		var launched := 0
		for src in sources:
			# Una base seleccionada puede haber caído durante el arrastre
			if src.faction == GameManager.Faction.PLAYER and dispatch_troops(src, target):
				launched += 1
		if launched > 0:
			EventBus.player_assault.emit(launched)

	_cancel_gesture()

## Ficha breve de una base tocada: tropas, producción y ventaja especial
func show_base_info(base: BaseNode) -> void:
	_info_base = base
	_info_timer = INFO_SECONDS if base else 0.0

func _add_selected_source(base: BaseNode) -> void:
	if not selected_sources.has(base):
		selected_sources.append(base)
		base.set_selected(true)

func _get_base_at(pos: Vector2) -> BaseNode:
	for b in bases:
		if b.is_point_inside(pos):
			return b
	return null

## Lanza todas las tropas de `from_base` (menos una) hacia `to_base`; false si no había a quién enviar
func dispatch_troops(from_base: BaseNode, to_base: BaseNode) -> bool:
	if not can_dispatch(from_base, to_base):
		return false
	var count = from_base.send_troops()
	if count <= 0:
		return false
	var troop: Troop = TroopScene.instantiate()
	(troops_container if troops_container else self).add_child(troop)
	troop.setup(from_base, to_base, count, from_base.faction)
	troop.set_process(false) # La batalla simula movimiento → choques → llegadas.
	troop.speed *= float(level_data.get("travel_multiplier", 1.0))
	active_troops.append(troop)

	if from_base.faction == GameManager.Faction.PLAYER:
		AudioManager.play_launch()
		GameManager.haptic(10)
	EventBus.troops_dispatched.emit(from_base, to_base, count, from_base.faction)
	return true

func _on_troop_arrived(troop: Troop) -> void:
	active_troops.erase(troop)

func _on_base_captured(base: BaseNode, prev_faction: int, new_faction: int) -> void:
	var player_involved = prev_faction == GameManager.Faction.PLAYER or new_faction == GameManager.Faction.PLAYER
	if player_involved:
		GameManager.haptic(60 if prev_faction == GameManager.Faction.PLAYER else 25)
		if base.tier >= 3 or base.perk_text() != "":
			shake_camera(9.0)
	if new_faction == GameManager.Faction.PLAYER:
		_captures += 1
	if prev_faction == GameManager.Faction.PLAYER:
		lost_a_base = true
		if not bases.any(func(b): return b.faction == GameManager.Faction.PLAYER):
			_fell_with_troops_out = active_troops.any(func(t): return _is_alive(t) and t.faction == GameManager.Faction.PLAYER)
	_update_level_objective(0.0)
	_check_game_over_conditions()

func _check_game_over_conditions() -> void:
	if is_game_over:
		return
	var player_alive = false
	var enemy_alive = false
	for b in bases:
		if b.faction == GameManager.Faction.PLAYER:
			player_alive = true
		elif b.faction != GameManager.Faction.NEUTRAL:
			enemy_alive = true
	for t in active_troops:
		if not _is_alive(t):
			continue
		if t.faction == GameManager.Faction.PLAYER:
			player_alive = true
		elif t.faction != GameManager.Faction.NEUTRAL:
			enemy_alive = true

	# Victoria: cero bases y cero tropas enemigas. Derrota: el jugador no tiene bases ni tropas
	if not enemy_alive or _level_objective_complete():
		_trigger_victory()
	elif not player_alive:
		_trigger_defeat()

func _trigger_victory() -> void:
	if is_game_over:
		return
	is_game_over = true
	start_slow_motion()

	var stars = 1
	if battle_time <= target_time:
		stars = 3
	elif battle_time <= target_time * 1.5:
		stars = 2

	var player_bases_count = 0
	var city_names: Array[String] = []
	for b in bases:
		if b.faction == GameManager.Faction.PLAYER:
			player_bases_count += 1
			# Atlas: ciudades en manos del jugador al ganar, en cualquier modo.
			if GameManager.conquer_city(b.city_key):
				city_names.append(b.base_name)

	var is_challenge = DailyRewards.is_challenge(level_id)
	var is_conquest = LevelGenerator.is_conquest(level_id)
	var is_replay: bool
	var total_gold: int
	var new_medal := false
	var new_continent := false
	if is_challenge:
		# Los desafíos diarios no cuentan para la campaña ni para las estrellas
		is_replay = GameManager.is_daily_challenge_done(DailyRewards.challenge_day(level_id))
		total_gold = GameManager.complete_daily_challenge(level_id)
	elif is_conquest:
		# La conquista libre avanza sola de región en región, sin repeticiones
		is_replay = false
		total_gold = GameManager.complete_conquest(LevelGenerator.conquest_index(level_id))
	else:
		var continent := LevelDatabase.get_continent_of(level_id)
		new_continent = not GameManager.is_continent_complete(continent)
		var previous_stars: int = int(GameManager.completed_levels.get(level_id, 0))
		is_replay = previous_stars > 0 and stars <= previous_stars
		total_gold = GameManager.calculate_victory_gold(level_id, stars, 60 + player_bases_count * 15)
		new_medal = not lost_a_base and not GameManager.medals.has(level_id)
		GameManager.complete_level(level_id, stars, not lost_a_base)
		new_continent = new_continent and GameManager.is_continent_complete(continent)
	GameManager.add_coins(total_gold)
	GameManager.haptic(80)

	var is_continent_conquest = not is_challenge and not is_conquest and LevelDatabase.get_level_number(level_id) == LevelDatabase.LEVELS_PER_CONTINENT
	# La fanfarria suena sola: la música se retira y vuelve la del menú al salir
	AudioManager.stop_music()
	if is_continent_conquest:
		AudioManager.play_continent_conquest()
	else:
		AudioManager.play_victory()

	var result := {
		"level_id": level_id,
		"stars": stars,
		"time": battle_time,
		"speed": _max_speed,
		"gold_earned": total_gold,
		"new_cities": city_names.size(),
		"city_names": city_names,
		"is_continent_conquest": is_continent_conquest,
		"is_replay": is_replay,
		"is_daily_challenge": is_challenge,
		"is_conquest": is_conquest,
		"new_medal": new_medal,
		"new_continent": new_continent,
		"expedition_finale": is_conquest and LevelGenerator.is_expedition_finale(LevelGenerator.conquest_index(level_id)),
		"xp_before": GameManager.experience,
	}
	result["xp"] = GameManager.victory_xp(result)
	EventBus.battle_won.emit(result)

## Algunos diarios admiten una victoria estratégica: asegurar los objetivos y mantenerlos.
func _objective_targets() -> Array[BaseNode]:
	var objective: String = level_data.get("objective", "")
	return bases.filter(func(b):
		return (objective == "hold_capital" and b.is_capital) \
			or (objective == "hold_factories" and b.base_type == BaseNode.BaseType.FACTORY) \
			or (objective == "hold_fortresses" and b.base_type == BaseNode.BaseType.FORTRESS))

func _update_level_objective(delta: float) -> void:
	if not level_data.has("objective"):
		return
	var targets := _objective_targets()
	if not targets.is_empty() and targets.all(func(b): return b.faction == GameManager.Faction.PLAYER):
		_objective_held += delta
	else:
		_objective_held = 0.0

func _level_objective_complete() -> bool:
	return level_data.has("objective") and _objective_held >= float(level_data.get("hold_seconds", INF))

func objective_text() -> String:
	if not level_data.has("objective"):
		return ""
	var seconds := ceili(float(level_data["hold_seconds"]) - _objective_held)
	return LocaleStrings.text(level_data["objective"]) % maxi(0, seconds)

func _trigger_defeat() -> void:
	if is_game_over:
		return
	reset_time_scale()
	is_game_over = true
	AudioManager.stop_music()
	AudioManager.play_defeat()
	GameManager.haptic(120)
	EventBus.battle_lost.emit()

## Consejo tras una derrota, a partir de un hecho observado en la batalla
func defeat_tip() -> String:
	if _fell_with_troops_out:
		return LocaleStrings.text("tip_left_empty")
	if _captures == 0:
		return LocaleStrings.text("tip_expand")
	if bases.any(func(b): return b.is_boss):
		return LocaleStrings.text("tip_boss")
	return LocaleStrings.text("tip_chain")

func get_faction_troop_counts() -> Dictionary:
	var counts = {}
	for f in GameManager.FACTION_COLORS:
		counts[f] = 0
	for b in bases:
		counts[b.faction] += b.troops
	for t in active_troops:
		if _is_alive(t):
			counts[t.faction] += t.count
	return counts

# =========================================================================
# Flecha elástica de arrastre y vista previa del resultado
# =========================================================================

func get_bezier_control_point(p0: Vector2, p2: Vector2, vel: Vector2 = Vector2.ZERO) -> Vector2:
	var mid = (p0 + p2) * 0.5
	var diff = p2 - p0
	var dist = diff.length()
	if dist < 2.0:
		return mid
	var normal = Vector2(-diff.y, diff.x) / dist
	# Deformación lateral elástica basada en la velocidad de arrastre (recta en reposo)
	var vel_offset = normal * clampf(vel.dot(normal) * 0.12, -50.0, 50.0)
	var bow_amount = sin(marching_dots_phase * TAU) * 2.5
	return mid + vel_offset + normal * bow_amount

func evaluate_quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func sample_bezier_points(p0: Vector2, p1: Vector2, p2: Vector2, segments: int = 24) -> PackedVector2Array:
	var pts = PackedVector2Array()
	pts.resize(segments + 1)
	for i in range(segments + 1):
		pts[i] = evaluate_quadratic_bezier(p0, p1, p2, float(i) / float(segments))
	return pts

## Tropas que se lanzarían al soltar ahora mismo desde las bases seleccionadas que siguen siendo nuestras
func get_pending_attack_count(target: BaseNode = null) -> int:
	var total := 0
	for src in selected_sources:
		if src.faction == GameManager.Faction.PLAYER and (target == null or can_dispatch(src, target)):
			total += maxi(0, src.troops - 1)
	return total

func _draw_slice_overlay(canvas: CanvasItem) -> void:
	for seg in slice_trail_segments:
		var alpha = clampf(seg["alpha"], 0.0, 1.0)
		var p1 = canvas.to_local(seg["p1"])
		var p2 = canvas.to_local(seg["p2"])
		canvas.draw_line(p1, p2, Color(0.2, 0.85, 1.0, alpha * 0.4), SLICE_WIDTH * 1.8, true)
		canvas.draw_line(p1, p2, Color(1.0, 1.0, 1.0, alpha * 0.95), SLICE_WIDTH, true)

	for flash in slice_cut_flash_effects:
		var f_pos = canvas.to_local(flash["pos"])
		var ratio = flash["timer"] / CUT_FLASH_TIME
		var f_r = 22.0 * (1.0 - ratio) + 6.0
		canvas.draw_circle(f_pos, f_r, Color(1.0, 1.0, 1.0, ratio * 0.6))
		canvas.draw_circle(f_pos, f_r * 0.5, Color(0.2, 0.85, 1.0, ratio * 0.9))
		canvas.draw_line(f_pos - Vector2(f_r * 1.3, 0), f_pos + Vector2(f_r * 1.3, 0), Color.WHITE, 2.0, true)
		canvas.draw_line(f_pos - Vector2(0, f_r * 1.3), f_pos + Vector2(0, f_r * 1.3), Color.WHITE, 2.0, true)

func _draw() -> void:
	_draw_sea_lanes()
	# Sin nodo overlay separado (tests unitarios): dibujar flechas y cortes directamente
	if not arrow_overlay:
		_draw_drag_overlay()

func _draw_drag_overlay() -> void:
	var canvas: CanvasItem = arrow_overlay if is_instance_valid(arrow_overlay) else self
	_draw_marching_routes(canvas)
	_draw_slice_overlay(canvas)
	_draw_base_info(canvas)

	if not is_dragging or selected_sources.is_empty():
		return

	var player_color = GameManager.faction_color(GameManager.Faction.PLAYER)
	var end_global = hovered_target.global_position if hovered_target else drag_current_pos
	var end_pt = canvas.to_local(end_global)

	for src in selected_sources:
		if hovered_target and not can_dispatch(src, hovered_target):
			continue
		_draw_arrow(canvas, canvas.to_local(src.global_position), end_pt, player_color)

	if hovered_target:
		_draw_target_preview(canvas, hovered_target)

func _draw_arrow(canvas: CanvasItem, start_pt: Vector2, end_pt: Vector2, player_color: Color) -> void:
	var dist = start_pt.distance_to(end_pt)
	if dist < 10.0:
		return
	var p1 = get_bezier_control_point(start_pt, end_pt, drag_velocity)
	var curve_pts = sample_bezier_points(start_pt, p1, end_pt, clampi(int(dist / 14.0), 16, 36))

	# 1. Geometría de grosor cónico adaptativo (halo + núcleo)
	var n = curve_pts.size()
	var glow_poly = PackedVector2Array()
	var core_poly = PackedVector2Array()
	glow_poly.resize(n * 2)
	core_poly.resize(n * 2)
	for i in n:
		var t = float(i) / float(n - 1)
		var pt = curve_pts[i]
		var tangent = ((curve_pts[i + 1] - pt) if i < n - 1 else (pt - curve_pts[i - 1])).normalized()
		var normal = Vector2(-tangent.y, tangent.x)
		var w_core = lerpf(13.0, 3.5, t) * 0.5
		var w_glow = lerpf(20.0, 6.5, t) * 0.5
		core_poly[i] = pt + normal * w_core
		core_poly[n * 2 - 1 - i] = pt - normal * w_core
		glow_poly[i] = pt + normal * w_glow
		glow_poly[n * 2 - 1 - i] = pt - normal * w_glow
	canvas.draw_colored_polygon(glow_poly, Color(1.0, 1.0, 1.0, 0.28))
	canvas.draw_colored_polygon(core_poly, Color(player_color, 0.92))

	# 2. Puntos animados fluidos (Marching Dots)
	var num_dots = clampi(int(dist / 38.0), 6, 14)
	for d in num_dots:
		var t_dot = fmod(marching_dots_phase + float(d) / float(num_dots), 1.0)
		if t_dot < 0.05 or t_dot > 0.93:
			continue
		var dot_pos = evaluate_quadratic_bezier(start_pt, p1, end_pt, t_dot)
		var dot_r = lerpf(4.5, 2.4, t_dot)
		canvas.draw_circle(dot_pos, dot_r + 1.5, Color(1.0, 1.0, 1.0, 0.35))
		canvas.draw_circle(dot_pos, dot_r, Color.WHITE)

	# 3. Cabeza de flecha poligonal orientada
	if dist > 20.0:
		var arrow_dir = (end_pt - evaluate_quadratic_bezier(start_pt, p1, end_pt, 0.92)).normalized()
		if arrow_dir.length_squared() < 0.01:
			arrow_dir = (end_pt - start_pt).normalized()
		var arrow_normal = Vector2(-arrow_dir.y, arrow_dir.x)
		var size = 22.0
		var p_wing1 = end_pt - arrow_dir * size + arrow_normal * (size * 0.52)
		var p_notch = end_pt - arrow_dir * (size * 0.72)
		var p_wing2 = end_pt - arrow_dir * size - arrow_normal * (size * 0.52)
		canvas.draw_polyline(PackedVector2Array([end_pt, p_wing1, p_notch, p_wing2, end_pt]), Color.WHITE, 2.0, true)
		canvas.draw_colored_polygon(PackedVector2Array([end_pt, p_wing1, p_notch, p_wing2]), Color(player_color, 0.98))
		canvas.draw_colored_polygon(PackedVector2Array([end_pt, p_wing1, p_notch]), Color(1.0, 1.0, 1.0, 0.3))

## Segundos hasta que el grueso del ataque llega al objetivo desde la base más lejana
## seleccionada (incluye la salida escalonada de los paquetes)
func estimate_arrival_seconds(target: BaseNode) -> float:
	var seconds := 0.0
	var travel_mult := float(level_data.get("travel_multiplier", 1.0))
	for src in selected_sources:
		if src.faction != GameManager.Faction.PLAYER or not can_dispatch(src, target):
			continue
		var speed := Troop.BASE_SPEED * travel_mult * GameManager.get_troop_speed_multiplier()
		var travel := maxf(10.0, src.global_position.distance_to(target.global_position) - target.radius * 0.45) / speed
		seconds = maxf(seconds, travel + Troop.emission_seconds(src.troops - 1, speed))
	return seconds

## Estimación conservadora: producción y fuerzas que ya llegarán antes de nuestra orden.
## ponytail: no predice choques ni cambios de dueño; por eso la interfaz dice «estimado».
func estimate_target_defense(target: BaseNode) -> float:
	var seconds := estimate_arrival_seconds(target)
	var defense := target.defense_after(seconds)
	for t in active_troops:
		if _is_alive(t) and t.target_base == target and t.remaining_seconds() <= seconds:
			defense += t.count * target.get_defense_multiplier() if t.faction == target.faction else -t.count
	return maxf(0.0, defense)

## Anillo sobre el objetivo que anticipa el resultado con la defensa estimada al llegar:
## verde si sobra fuerza, dorado si es ajustado, rojo con lo que falta, gris si no hay ruta
func _draw_target_preview(canvas: CanvasItem, target: BaseNode) -> void:
	var map_colors: Dictionary = UIThemeHelper.PALETTES.dark
	var h_pos = canvas.to_local(target.global_position)
	var ring_r = (target.radius + 16.0) * (1.0 + sin(marching_dots_phase * TAU * 2.0) * 0.04)
	var attack := get_pending_attack_count(target)
	var ring_color: Color
	var text: String
	if not selected_sources.any(func(source): return can_dispatch(source, target)):
		ring_color = map_colors.neutral
		text = LocaleStrings.text("no_route")
	elif target.faction == GameManager.Faction.PLAYER:
		ring_color = Color(0.55, 0.85, 1.0)
		text = "+%d" % attack
	else:
		# Misma regla que BaseNode.receive_troops: se conquista al superar la defensa (puede ser x.5)
		var defense := estimate_target_defense(target)
		var margin := attack - ceili(defense)
		if attack <= defense:
			ring_color = map_colors.danger
			text = LocaleStrings.text("troops_missing") % maxi(1, -margin)
		elif margin < maxi(3, ceili(defense * 0.15)):
			ring_color = map_colors.gold
			text = LocaleStrings.text("attack_tight") % maxi(1, margin)
		else:
			ring_color = map_colors.success
			text = LocaleStrings.text("attack_estimated") % margin
	canvas.draw_circle(h_pos, ring_r, Color(ring_color, 0.10))
	canvas.draw_arc(h_pos, ring_r, 0, TAU, 48, Color(ring_color, 0.95), 4.0, true)
	_draw_map_text(canvas, h_pos + Vector2(0, -ring_r - 16.0), text, 34, ring_color)

static func _draw_map_text(canvas: CanvasItem, center: Vector2, text: String, size: int, color: Color) -> void:
	var font := UIThemeHelper.bold_font()
	var pos := center - Vector2(200.0, 0.0)
	canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, size, 8, Color(0, 0, 0, 0.75))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, size, color)

## Ficha de la base tocada: nombre, tropas / capacidad, producción y ventaja especial
func _draw_base_info(canvas: CanvasItem) -> void:
	if _info_timer <= 0.0 or not is_instance_valid(_info_base):
		return
	var b := _info_base
	var alpha := clampf(_info_timer / 0.3, 0.0, 1.0)
	var lines: PackedStringArray = [b.base_name, LocaleStrings.text("info_troops") % [b.troops, b.max_capacity]]
	if b.faction != GameManager.Faction.NEUTRAL:
		lines[1] += "  ·  " + (LocaleStrings.text("info_full") if b.is_full() else LocaleStrings.text("info_rate") % b.get_production_rate())
	var perk := b.perk_text()
	if perk != "":
		lines.append(perk)
	var font := UIThemeHelper.bold_font()
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x)
	var size := Vector2(width + 48.0, 20.0 + lines.size() * 38.0)
	var top := b.global_position + Vector2(-size.x * 0.5, -b.radius - 40.0 - size.y)
	if top.y < 260.0:
		top.y = b.global_position.y + b.radius + 40.0
	top.x = clampf(top.x, 16.0, LevelGenerator.MAP_RECT.size.x - 16.0 - size.x)
	var rect := Rect2(canvas.to_local(top), size)
	var box := UIThemeHelper.box(Color(0.06, 0.09, 0.14, 0.92 * alpha), 20, 0)
	canvas.draw_style_box(box, rect)
	for i in lines.size():
		var color := BaseNode.MARKER_GOLD if i == 2 else Color(1, 1, 1, 1.0 if i == 0 else 0.8)
		canvas.draw_string(font, rect.position + Vector2(24.0, 44.0 + i * 38.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(color, alpha))

## Mientras se traza un corte, las rutas de tus tropas en marcha se ven tenues
func _draw_marching_routes(canvas: CanvasItem) -> void:
	if not is_slicing:
		return
	var color := Color(GameManager.faction_color(GameManager.Faction.PLAYER), 0.35)
	for t in active_troops:
		if _is_alive(t) and t.faction == GameManager.Faction.PLAYER and not t.is_retreating:
			canvas.draw_dashed_line(canvas.to_local(t.global_position), canvas.to_local(t.start_pos + t.move_dir * t.path_length), color, 3.0, 10.0, true)

## Sólo las rutas marítimas obligatorias: el resto del mapa queda limpio
func _draw_sea_lanes() -> void:
	for route in level_data.get("sea_lanes", []):
		draw_dashed_line(bases[route.x].position, bases[route.y].position, Color("62cbf2"), 3.0, 12.0, true)
