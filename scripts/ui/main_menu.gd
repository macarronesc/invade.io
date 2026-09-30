extends Control
class_name MainMenuUI

## Pantalla principal: cabecera (oro y ajustes), la sección activa y la barra de navegación.
## Las secciones se construyen al abrirlas; cambiar de sección no cambia de escena.

const SCENE := "res://scenes/ui/main_menu.tscn"
## Una entrada por sección: añadir una nueva es añadir una línea y su script
const TABS := {
	"play": {"icon": "map", "title": "tab_play", "page": preload("res://scripts/ui/play_tab.gd")},
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
var _nav: Dictionary = {}
var _badges: Dictionary = {}
var _utility_panel: Control = null

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or is_instance_valid(_utility_panel):
		return # Los paneles superpuestos gestionan su propio botón atrás.
	if current_tab != "play":
		show_tab("play")
	else:
		get_tree().quit()

func _ready() -> void:
	# Primer arranque: directo a la batalla, sin menús ni tarjetas en medio.
	# Sólo cuando el menú es la escena real (en tests se instancia como hijo).
	if not GameManager.has_started and get_tree().current_scene == self:
		GameManager.has_started = true
		GameManager.save_game()
		UIThemeHelper.start_battle.bind(self, GameManager.FIRST_LEVEL_ID).call_deferred()
		return
	_build()
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
	var background := ColorRect.new()
	background.color = UIThemeHelper.COLOR_BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := UIThemeHelper.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	var bar := UIThemeHelper.hbox(16)
	column.add_child(UIThemeHelper.page_margin(bar, 32 + UIThemeHelper.get_safe_area_top(self), 16))
	var logo := UIThemeHelper.label("invade.io", "Title")
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(logo)
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
	var nav_margin := MarginContainer.new()
	nav_margin.add_theme_constant_override("margin_bottom", UIThemeHelper.get_safe_area_bottom(self))
	nav.add_child(nav_margin)
	var items := UIThemeHelper.hbox(0)
	nav_margin.add_child(items)
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

func show_tab(id: String) -> void:
	if not TABS.has(id):
		id = "play"
	current_tab = id
	_nav[id].set_pressed_no_signal(true)
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
	_badges["progress"].visible = GameManager.get_claimable_achievement_count() > 0

func _update_coins(amount: int) -> void:
	coins_label.text = str(amount)

func _open_settings() -> void:
	if is_instance_valid(_utility_panel):
		return
	AudioManager.play_click()
	_utility_panel = load("res://scripts/ui/settings_panel.gd").new()
	_utility_panel.closed.connect(func():
		next_tab = current_tab
		get_tree().reload_current_scene())
	add_child(_utility_panel)
