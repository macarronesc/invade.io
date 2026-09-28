extends CanvasLayer

## Toasts: avisos breves por encima de cualquier escena (logros desbloqueados).
## Se encolan y se muestran de uno en uno; también funcionan con el juego en pausa.

const SHOW_SECONDS := 2.6
const SLIDE_SECONDS := 0.3
const TOP_MARGIN := 40.0
const WIDTH := 820.0

var _queue: Array[Dictionary] = []
var _showing: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(id: String) -> void:
	var a := AchievementDatabase.get_by_id(id)
	show_toast(a.get("icon", "🏆"), "¡Logro desbloqueado!", a.get("title", id))

func show_toast(icon: String, title: String, body: String) -> void:
	_queue.append({"icon": icon, "title": title, "body": body})
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var data: Dictionary = _queue.pop_front()
	var card := _build_card(data)
	add_child(card)
	if DisplayServer.get_name() == "headless":
		card.queue_free()
		_show_next.call_deferred()
		return
	AudioManager.play_star_reveal(2)
	var view_w := card.get_viewport_rect().size.x
	var top := TOP_MARGIN + UIThemeHelper.get_safe_area_top(card)
	card.position = Vector2((view_w - WIDTH) * 0.5, -200.0)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:y", top, SLIDE_SECONDS)
	t.tween_interval(SHOW_SECONDS)
	t.tween_property(card, "position:y", -200.0, SLIDE_SECONDS).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		card.queue_free()
		_show_next()
	)

func _build_card(data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIThemeHelper.apply_card_style(card, Color(0.10, 0.13, 0.18, 0.97), UIThemeHelper.COLOR_ACCENT, 20, 3)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)
	var icon := Label.new()
	icon.text = data["icon"]
	icon.add_theme_font_size_override("font_size", 64)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var title := Label.new()
	title.text = data["title"]
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT)
	texts.add_child(title)
	var body := Label.new()
	body.text = data["body"]
	body.add_theme_font_size_override("font_size", 36)
	texts.add_child(body)
	# El aviso nunca debe tapar botones (p. ej. la pausa, justo debajo)
	for c in card.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
