extends Node2D

## TutorialOverlay: enseña cada gesto una sola vez con una mano animada sobre el mapa.
## - europe_1: arrastrar para atacar (la simulación espera al primer envío)
## - europe_2: encadenar varias bases en un mismo trazo
## - europe_3: cortar una hilera propia para que se retire (con cámara lenta)
## - Primer nivel con fortaleza / fábrica: tarjeta explicativa de cada tipo de base

const GESTURE_STEPS = {
	"europe_1": ["drag"],
	"europe_2": ["chain"],
	"europe_3": ["slice"],
}

const HINTS = {
	"drag": "Arrastra desde tu base azul hasta una base gris para conquistarla",
	"chain": "Pasa por varias bases azules en un solo trazo para sumar sus tropas",
	"slice": "Traza una línea sobre tus tropas en marcha para que vuelvan a casa",
	"goal": "¡Bien! Conquista todas las bases enemigas para ganar",
}

const TIP_CARDS = {
	BaseNode.BaseType.FORTRESS: {
		"id": "fortress",
		"title": "🛡️ Fortaleza",
		"body": "Cada defensor aguanta 2 ataques, pero produce tropas muy despacio.\nIdeal para resistir en primera línea."
	},
	BaseNode.BaseType.FACTORY: {
		"id": "factory",
		"title": "🏭 Fábrica",
		"body": "Produce tropas 2,5 veces más rápido, pero cada atacante elimina 2 defensores.\n¡Protégela bien!"
	},
}

const HAND_CYCLE := 1.8
const CHAIN_TIMEOUT := 14.0
const SLICE_TIMEOUT := 6.0
const SLICE_TIME_SCALE := 0.3

var battle: BattleController
var _queue: Array[String] = []
var _current: String = ""
var _hint: String = ""
var _hint_timer: float = 0.0
var _step_time: float = 0.0
var _hand_path: PackedVector2Array = PackedVector2Array()
var _banner_style: StyleBoxFlat

static func _pending_cards(level_data: Dictionary) -> Array:
	var cards := []
	for b in level_data.get("bases", []):
		var t = b.get("type", "")
		var type_id = BaseNode.BaseType.FORTRESS if t == "fortress" else (BaseNode.BaseType.FACTORY if t == "factory" else -1)
		if type_id != -1 and not GameManager.has_seen_tip(TIP_CARDS[type_id]["id"]) and not cards.has(type_id):
			cards.append(type_id)
	return cards

static func _pending_gestures(level_id: String) -> Array[String]:
	var steps: Array[String] = []
	for s in GESTURE_STEPS.get(level_id, []):
		if not GameManager.has_seen_tip(s):
			steps.append(s)
	return steps

static func has_pending_steps(level_id: String, level_data: Dictionary) -> bool:
	return not _pending_cards(level_data).is_empty() or not _pending_gestures(level_id).is_empty()

func setup(p_battle: BattleController) -> void:
	battle = p_battle
	z_index = 20
	_banner_style = StyleBoxFlat.new()
	_banner_style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	_banner_style.border_color = Color(1.0, 0.82, 0.18, 0.85)
	_banner_style.set_border_width_all(3)
	_banner_style.set_corner_radius_all(22)
	for type_id in _pending_cards(battle.level_data):
		_queue.append("card_%d" % type_id)
	_queue.append_array(_pending_gestures(battle.level_id))
	EventBus.troops_dispatched.connect(_on_troops_dispatched)
	EventBus.player_assault.connect(_on_player_assault)
	EventBus.troops_retreated.connect(_on_troops_retreated)
	EventBus.battle_won.connect(_finish_all.unbind(1))
	EventBus.battle_lost.connect(_finish_all)
	_next_step()

func _next_step() -> void:
	_current = "" if _queue.is_empty() else _queue.pop_front()
	_step_time = 0.0
	_hand_path.clear()
	if _current.begins_with("card_"):
		var card: Dictionary = TIP_CARDS[int(_current.substr(5))]
		GameManager.mark_tip_seen(card["id"])
		battle.get_node("BattleHUD").show_tip_card(card["title"], card["body"], _next_step)
	elif _current == "drag":
		battle.set_simulation_paused(true)
		_show_hint(HINTS["drag"], INF)
	queue_redraw()

func _complete_current() -> void:
	GameManager.mark_tip_seen(_current)
	if _current == "drag":
		battle.set_simulation_paused(false)
		_show_hint(HINTS["goal"], 3.5)
	else:
		_show_hint("", 0.0)
	if _current == "slice":
		battle.base_time_scale = 1.0
	_next_step()

func _finish_all() -> void:
	if _current == "slice":
		battle.base_time_scale = 1.0
	_queue.clear()
	_current = ""
	_show_hint("", 0.0)
	_hand_path.clear()
	queue_redraw()

func _show_hint(text: String, duration: float) -> void:
	_hint = text
	_hint_timer = duration

func _on_troops_dispatched(_from_base, _to_base, _count, faction) -> void:
	if faction == GameManager.Faction.PLAYER and _current == "drag":
		_complete_current()

func _on_player_assault(source_count: int) -> void:
	if _current == "chain" and not _hand_path.is_empty() and source_count >= 2:
		_complete_current()

func _on_troops_retreated(faction: int) -> void:
	if faction == GameManager.Faction.PLAYER and _current == "slice":
		_complete_current()

func _process(delta: float) -> void:
	# Tutorial terminado y último aviso retirado: ya no hay nada que dibujar
	if _current == "" and _hint == "":
		queue_free()
		return
	var real_delta = delta / maxf(Engine.time_scale, 0.01)
	_step_time += real_delta
	if _hint_timer > 0.0:
		_hint_timer -= real_delta
		if _hint_timer <= 0.0:
			_hint = ""

	match _current:
		"drag":
			if _hand_path.is_empty():
				_hand_path = _build_drag_path()
		"chain":
			if _hand_path.is_empty():
				_hand_path = _build_chain_path()
				if not _hand_path.is_empty():
					_step_time = 0.0
					_show_hint(HINTS["chain"], INF)
			elif _step_time > CHAIN_TIMEOUT:
				_complete_current()
		"slice":
			if _hand_path.is_empty():
				_hand_path = _build_slice_path()
				if not _hand_path.is_empty():
					_step_time = 0.0
					_show_hint(HINTS["slice"], INF)
			elif _step_time > SLICE_TIMEOUT:
				_complete_current()
			else:
				# Cada fotograma: la pausa del HUD restablece la escala de tiempo al reanudar
				battle.base_time_scale = SLICE_TIME_SCALE
	queue_redraw()

func _player_bases() -> Array[BaseNode]:
	var result: Array[BaseNode] = []
	for b in battle.bases:
		if b.faction == GameManager.Faction.PLAYER:
			result.append(b)
	return result

func _nearest_non_player(from: Vector2) -> BaseNode:
	var best: BaseNode = null
	var best_d := INF
	for b in battle.bases:
		if b.faction != GameManager.Faction.PLAYER:
			# Preferir neutrales: son el objetivo natural de un jugador que empieza
			var d = from.distance_to(b.position) + (0.0 if b.faction == GameManager.Faction.NEUTRAL else 400.0)
			if d < best_d:
				best = b
				best_d = d
	return best

func _build_drag_path() -> PackedVector2Array:
	var mine = _player_bases()
	if mine.is_empty():
		return PackedVector2Array()
	var target = _nearest_non_player(mine[0].position)
	return PackedVector2Array([mine[0].position, target.position]) if target else PackedVector2Array()

func _build_chain_path() -> PackedVector2Array:
	var mine = _player_bases()
	if mine.size() < 2:
		return PackedVector2Array()
	var target = _nearest_non_player(mine[1].position)
	if not target:
		return PackedVector2Array()
	return PackedVector2Array([mine[0].position, mine[1].position, target.position])

func _build_slice_path() -> PackedVector2Array:
	for t in battle.active_troops:
		if is_instance_valid(t) and t.faction == GameManager.Faction.PLAYER and not t.is_retreating and t.count >= 3:
			var f = t.front_index()
			if f < 0 or t.bead_dist(f) < 120.0 or t.bead_dist(f) > t.path_length * 0.6:
				continue
			var mid = battle.to_local(t.bead_position(f)) - t.move_dir * 30.0
			var n = Vector2(-t.move_dir.y, t.move_dir.x) * 110.0
			return PackedVector2Array([mid - n, mid + n])
	return PackedVector2Array()

## Posición a lo largo de la polilínea para una fracción 0..1 de su longitud total
static func _point_on_path(path: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var remaining := total * t
	for i in range(1, path.size()):
		var seg := path[i - 1].distance_to(path[i])
		if remaining <= seg:
			return path[i - 1].lerp(path[i], remaining / maxf(seg, 0.001))
		remaining -= seg
	return path[path.size() - 1]

func _draw() -> void:
	if _hand_path.size() >= 2:
		_draw_hand()
	if _hint != "":
		_draw_banner()

func _draw_hand() -> void:
	var cycle = fmod(_step_time, HAND_CYCLE) / HAND_CYCLE
	var move_t = smoothstep(0.15, 0.75, cycle)
	var alpha = clampf(cycle / 0.1, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, cycle))
	var pos = _point_on_path(_hand_path, move_t)
	var accent = Color(1.0, 0.82, 0.18)

	# Estela del gesto
	var trail := PackedVector2Array()
	for k in 17:
		trail.append(_point_on_path(_hand_path, move_t * k / 16.0))
	if move_t > 0.01:
		draw_polyline(trail, Color(accent, 0.55 * alpha), 10.0 if _current == "slice" else 7.0, true)

	# Pulsación en el punto de contacto
	var press = 1.0 - smoothstep(0.0, 0.15, cycle)
	draw_arc(pos, 26.0 + press * 18.0, 0, TAU, 32, Color(1, 1, 1, 0.8 * alpha), 4.0, true)
	draw_circle(pos, 12.0, Color(accent, 0.8 * alpha))

	# Mano (el dedo apunta al punto de contacto)
	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(-38, 72), "👆", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(1, 1, 1, alpha))

func _draw_banner() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 38
	var width = 900.0
	var text_size = font.get_multiline_string_size(_hint, HORIZONTAL_ALIGNMENT_CENTER, width, font_size)
	var rect = Rect2(Vector2(540.0 - width * 0.5 - 30.0, 1700.0), Vector2(width + 60.0, text_size.y + 40.0))
	draw_style_box(_banner_style, rect)
	draw_multiline_string(font, rect.position + Vector2(30.0, 20.0 + font.get_ascent(font_size)), _hint, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, -1, Color.WHITE)
