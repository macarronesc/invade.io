extends Control
class_name MainMenuUI

## Pantalla principal: cabecera (oro y ajustes), la sección activa y la barra de navegación.
## Las secciones se construyen al abrirlas; cambiar de sección no cambia de escena.

const SCENE := "res://scenes/ui/main_menu.tscn"
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
## Una entrada por sección: añadir una nueva es añadir una línea y su script
const TABS := {
	"play": {"icon": "map", "title": "tab_play", "page": preload("res://scripts/ui/play_tab.gd")},
	"invasion": {"icon": "flag", "title": "tab_invasion", "page": preload("res://scripts/ui/invasion_tab.gd")},
	"challenges": {"icon": "target", "title": "tab_challenges", "page": preload("res://scripts/ui/challenges_tab.gd")},
	"army": {"icon": "shield", "title": "tab_army", "page": preload("res://scripts/ui/army_tab.gd")},
	"progress": {"icon": "trophy", "title": "tab_progress", "page": preload("res://scripts/ui/progress_tab.gd")},
}

## Sección con la que se abrirá el menú la próxima vez (p. ej. al salir de un desafío diario)
static var next_tab := "play"
## Tras una derrota, Ejército ofrece volver directamente a la misma batalla
static var return_to_battle := false

var current_tab := ""
var coins_label: Label
var btn_settings: Button
var _content: Control
var _header_margin: MarginContainer
var _nav_margin: MarginContainer
var _nav: Dictionary = {}
var _badges: Dictionary = {}
var _utility_panel: Control = null
var _background: ColorRect
var _logo_io: Label
var _appearance := ""

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or is_instance_valid(_utility_panel):
		return # Los paneles superpuestos gestionan su propio botón atrás.
	if current_tab != "play":
		show_tab("play")
	else:
		get_tree().quit()

func _ready() -> void:
	if get_tree().current_scene == self:
		LaunchOverlay.show_once.call_deferred(get_tree())
	# Primer arranque: directo a la batalla, sin menús ni tarjetas en medio.
	# Sólo cuando el menú es la escena real (en tests se instancia como hijo).
	if not GameManager.has_started and get_tree().current_scene == self:
		GameManager.has_started = true
		GameManager.save_game()
		UIThemeHelper.start_battle.bind(self, GameManager.FIRST_LEVEL_ID).call_deferred()
		return
	_build()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	UIThemeHelper.apply_locale_direction(self)
	_appearance = _appearance_key()
	EventBus.settings_changed.connect(_refresh_appearance)
	EventBus.coins_updated.connect(_update_coins)
	# Reclamar cualquier recompensa mueve el oro, así que basta con escuchar estos avisos
	EventBus.coins_updated.connect(_refresh_badges.unbind(1))
	EventBus.achievement_unlocked.connect(_refresh_badges.unbind(1))
	AudioManager.play_music("menu")
	AchievementManager.check_all()
	_update_coins(GameManager.coins)
	var tab := next_tab
	next_tab = "play"
	show_tab(tab)

func _build() -> void:
	_background = ColorRect.new()
	_background.color = UIThemeHelper.colors.bg
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	var column := UIThemeHelper.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	var bar := UIThemeHelper.hbox(16)
	_header_margin = UIThemeHelper.page_margin(bar, 32 + UIThemeHelper.get_safe_area_top(self), 16)
	column.add_child(_header_margin)
	bar.add_child(_logo_tile())
	var wordmark := UIThemeHelper.hbox(0)
	# La marca se lee siempre "invade.io", también en RTL.
	wordmark.layout_direction = Control.LAYOUT_DIRECTION_LTR
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wordmark.alignment = BoxContainer.ALIGNMENT_BEGIN
	wordmark.add_child(UIThemeHelper.label("invade", "Title"))
	_logo_io = UIThemeHelper.label(".io", "Title", UIThemeHelper.colors.primary)
	wordmark.add_child(_logo_io)
	for l in wordmark.get_children():
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(wordmark)
	var coins := UIThemeHelper.chip("0", "coin")
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins_label = coins.find_children("*", "Label", true, false)[0]
	coins_label.theme_type_variation = "Heading"
	bar.add_child(coins)
	btn_settings = UIThemeHelper.icon_button("gear", LocaleStrings.text("settings"))
	btn_settings.pressed.connect(_open_settings)
	bar.add_child(btn_settings)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var nav := PanelContainer.new()
	nav.theme_type_variation = "NavBar"
	column.add_child(nav)
	_nav_margin = MarginContainer.new()
	nav.add_child(_nav_margin)
	var items := UIThemeHelper.hbox(0)
	_nav_margin.add_child(items)
	var group := ButtonGroup.new()
	for id in TABS:
		var btn := UIThemeHelper.button(LocaleStrings.text(TABS[id]["title"]), "NavButton")
		btn.name = "Nav_" + id
		btn.icon = Icons.texture(TABS[id]["icon"], 52)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size.y = 132
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			AudioManager.play_click()
			show_tab(id))
		items.add_child(btn)
		_nav[id] = btn
		var badge := Panel.new()
		badge.theme_type_variation = "Badge"
		badge.size = Vector2(20, 20)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		btn.add_child(badge)
		_badges[id] = badge
		btn.resized.connect(func(): badge.position = Vector2(btn.size.x * 0.5 + 18, 16))

func _apply_safe_area() -> void:
	if not is_instance_valid(_header_margin) or not is_instance_valid(_nav_margin):
		return
	_header_margin.add_theme_constant_override("margin_left", UIThemeHelper.PAGE_MARGIN + UIThemeHelper.get_safe_area_left(self))
	_header_margin.add_theme_constant_override("margin_top", 32 + UIThemeHelper.get_safe_area_top(self))
	_header_margin.add_theme_constant_override("margin_right", UIThemeHelper.PAGE_MARGIN + UIThemeHelper.get_safe_area_right(self))
	_header_margin.add_theme_constant_override("margin_bottom", 16)
	_nav_margin.add_theme_constant_override("margin_left", UIThemeHelper.get_safe_area_left(self))
	_nav_margin.add_theme_constant_override("margin_right", UIThemeHelper.get_safe_area_right(self))
	_nav_margin.add_theme_constant_override("margin_bottom", UIThemeHelper.get_safe_area_bottom(self))

func show_tab(id: String) -> void:
	if not TABS.has(id):
		id = "play"
	current_tab = id
	Telemetry.tab_opened(id)
	for tab in _nav:
		_nav[tab].set_pressed_no_signal(tab == id)
	UIThemeHelper.clear(_content)
	var page: Control = TABS[id]["page"].new()
	if id == "army" and return_to_battle:
		page.return_to_battle = true
		return_to_battle = false
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(page)
	_refresh_badges()

## Punto dorado sólo cuando hay algo que recoger
func _refresh_badges() -> void:
	_badges["challenges"].visible = GameManager.get_daily_reward_state()["can_claim"] or GameManager.claimable_mission_count() > 0
	_badges["progress"].visible = GameManager.get_claimable_achievement_count() + GameManager.claimable_collection_count() > 0
	_badges["army"].visible = GameManager.can_suggest_combat_upgrade()

func _update_coins(amount: int) -> void:
	coins_label.text = str(amount)

## Icono del juego como baldosa redondeada junto al nombre
func _logo_tile() -> Control:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = preload("res://assets/brand/menu_logo.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _open_settings() -> void:
	if is_instance_valid(_utility_panel):
		return
	AudioManager.play_click()
	Telemetry.screen_opened("settings")
	_utility_panel = SettingsPanel.new()
	_content.process_mode = Node.PROCESS_MODE_DISABLED
	_utility_panel.closed.connect(func(): _content.process_mode = Node.PROCESS_MODE_INHERIT)
	_utility_panel.closed.connect(_refresh_appearance)
	_utility_panel.closed.connect(func(): Telemetry.screen_opened("menu"))
	_utility_panel.closed.connect(func(): btn_settings.grab_focus.call_deferred())
	add_child(_utility_panel)

func _appearance_key() -> String:
	return "%s|%s" % [UIThemeHelper.palette_name, GameManager.language]

## Refresca colores y textos conservando la pestaña, su selección y su scroll.
func _refresh_appearance() -> void:
	if _appearance == _appearance_key():
		return
	_appearance = _appearance_key()
	UIThemeHelper.apply_locale_direction(self)
	_background.color = UIThemeHelper.colors.bg
	_logo_io.add_theme_color_override("font_color", UIThemeHelper.colors.primary)
	coins_label.add_theme_color_override("font_color", UIThemeHelper.colors.text)
	btn_settings.tooltip_text = LocaleStrings.text("settings")
	btn_settings.accessibility_name = LocaleStrings.text("settings")
	for id in TABS:
		_nav[id].text = LocaleStrings.text(TABS[id]["title"])
	if _content.get_child_count() > 0:
		var page := _content.get_child(0)
		if page.has_method("refresh_appearance"):
			page.refresh_appearance()
		elif page.has_method("rebuild"):
			page.rebuild()
