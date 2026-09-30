extends CanvasLayer

## Toasts: avisos breves por encima de cualquier escena (logros desbloqueados, copiado...).
## Se encolan y se muestran de uno en uno; también funcionan con el juego en pausa.
## Como primer autoload de interfaz, instala también el tema visual global.

const SHOW_SECONDS := 2.6
const SLIDE_SECONDS := 0.25
const TOP_MARGIN := 36.0
const WIDTH := 880.0

var _queue: Array[Dictionary] = []
var _showing: bool = false

func _ready() -> void:
	UIThemeHelper.install(get_tree())
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(id: String) -> void:
	var a := AchievementDatabase.get_by_id(id)
	show_toast(a.get("icon", "🏆"), LocaleStrings.text("toast_achievement"), AchievementDatabase.achievement_title(a))

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
	card.position = Vector2((view_w - WIDTH) * 0.5, -220.0)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:y", top, SLIDE_SECONDS)
	t.tween_interval(SHOW_SECONDS)
	t.tween_property(card, "position:y", -220.0, SLIDE_SECONDS).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		card.queue_free()
		_show_next()
	)

func _build_card(data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Sheet"
	card.custom_minimum_size = Vector2(WIDTH, 0)
	var row := UIThemeHelper.hbox(28)
	card.add_child(row)
	var icon := UIThemeHelper.label(data["icon"], "Title")
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var texts := UIThemeHelper.vbox(4)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(UIThemeHelper.label(data["title"], "Caption", UIThemeHelper.COLOR_GOLD))
	texts.add_child(UIThemeHelper.label(data["body"], "Heading"))
	# El aviso nunca debe tapar botones (p. ej. la pausa, justo debajo)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in card.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
