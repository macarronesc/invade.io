extends CanvasLayer

## Toasts: avisos breves por encima de cualquier escena (logros desbloqueados, copiado...).
## Se encolan y se muestran de uno en uno; también funcionan con el juego en pausa.
## Como primer autoload de interfaz, instala también el tema visual global.

const SHOW_SECONDS := 2.6
const SLIDE_SECONDS := 0.25
const TOP_MARGIN := 36.0
const WIDTH := 680.0

var _queue: Array[Dictionary] = []
var _showing: bool = false

func _ready() -> void:
	UIThemeHelper.install(get_tree(), GameManager.settings["light_mode"])
	EventBus.settings_changed.connect(func(): UIThemeHelper.apply_palette(get_tree(), GameManager.settings["light_mode"]))
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.battle_won.connect(flush.unbind(1), CONNECT_DEFERRED)
	EventBus.battle_lost.connect(flush, CONNECT_DEFERRED)
	GameManager.save_status_changed.connect(_on_save_status_changed)
	if GameManager.save_error != OK or GameManager.save_recovered:
		_on_save_status_changed.call_deferred()

func _on_save_status_changed() -> void:
	if GameManager.save_error != OK:
		var key := "save_newer_version" if GameManager.save_error == ERR_UNAVAILABLE else "save_local_error"
		show_toast("⚠", LocaleStrings.text("save_auto"), LocaleStrings.text(key), true)
	elif GameManager.save_recovered:
		show_toast("✓", LocaleStrings.text("save_auto"), LocaleStrings.text("save_recovered"), true)

func _on_achievement_unlocked(id: String) -> void:
	var a := AchievementDatabase.get_by_id(id)
	show_toast("trophy", LocaleStrings.text("toast_achievement"), AchievementDatabase.achievement_title(a))

func show_toast(icon: String, title: String, body: String, during_battle: bool = false) -> void:
	_queue.append({"icon": icon, "title": title, "body": body})
	var scene := get_tree().current_scene
	if not during_battle and scene is BattleController and not scene.is_game_over:
		return # Los logros se celebran al terminar, sin tapar decisiones tácticas.
	if not _showing:
		_show_next()

func flush() -> void:
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var data: Dictionary = _queue.pop_front()
	var view_w := get_viewport().get_visible_rect().size.x
	var width := minf(WIDTH, view_w - UIThemeHelper.PAGE_MARGIN * 2)
	var card := _build_card(data, width)
	add_child(card)
	if DisplayServer.get_name() == "headless":
		card.queue_free()
		_show_next.call_deferred()
		return
	AudioManager.play_star_reveal(2)
	card.custom_minimum_size.x = width
	card.size = card.get_combined_minimum_size()
	var top := TOP_MARGIN + UIThemeHelper.get_safe_area_top(card)
	card.position = Vector2((view_w - width) * 0.5, -220.0)
	if GameManager.settings["reduced_motion"]:
		card.position.y = top
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not GameManager.settings["reduced_motion"]:
		t.tween_property(card, "position:y", top, SLIDE_SECONDS)
	t.tween_interval(SHOW_SECONDS)
	if not GameManager.settings["reduced_motion"]:
		t.tween_property(card, "position:y", -220.0, SLIDE_SECONDS).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		card.queue_free()
		_show_next()
	)

func _build_card(data: Dictionary, width: float = WIDTH) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Tile"
	card.custom_minimum_size = Vector2(width, 0)
	var row := UIThemeHelper.hbox(28)
	card.add_child(row)
	var icon: Control = Icons.rect("trophy", 48, UIThemeHelper.colors.gold) if data["icon"] == "trophy" else UIThemeHelper.label(data["icon"], "Heading")
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := UIThemeHelper.vbox(4)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(UIThemeHelper.label(data["title"], "Caption", UIThemeHelper.colors.gold))
	var body := UIThemeHelper.paragraph(data["body"], "Heading")
	body.custom_minimum_size.x = width - 116
	texts.add_child(body)
	# El aviso nunca debe tapar botones (p. ej. la pausa, justo debajo)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in card.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card
