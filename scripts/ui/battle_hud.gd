extends CanvasLayer
class_name BattleHUD

## BattleHUD: cabecera de batalla en dos filas (pausa, nivel con una línea de contexto y reloj de
## estrellas; debajo, la barra de fuerzas con las tropas de cada bando) y las capas de pausa, victoria y derrota. La victoria
## cierra con el progreso ganado y un único siguiente objetivo.

const DOMINANCE_UPDATE_INTERVAL := 0.1
const XP_BAR_SECONDS := 0.8
## Segundos iniciales en los que la regla del nivel tiene prioridad sobre la cuenta atrás de apertura
const RULE_INTRO_SECONDS := 8.0
## Un segmento más estrecho que esta fracción de la barra no muestra su número
const MIN_LABEL_SHARE := 0.08

@export var battle_controller: BattleController

@onready var top_bar: Control = $TopBar
@onready var label_level_name: Label = %LevelNameLabel
@onready var label_target_time: Label = %TargetTimeLabel
@onready var bar_player: ColorRect = %BarPlayer
@onready var bar_enemy: ColorRect = %BarEnemy
@onready var bar_neutral: ColorRect = %BarNeutral
@onready var label_count_player: Label = %LabelCountPlayer
@onready var label_count_enemy: Label = %LabelCountEnemy
@onready var label_count_neutral: Label = %LabelCountNeutral
@onready var objective_label: Label = %ObjectiveLabel
@onready var dim_overlay: ColorRect = %DimOverlay

@onready var victory_panel: Control = %VictoryPanel
@onready var victory_title: Label = %VictoryTitle
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var victory_reward_label: Label = %VictoryRewardLabel
@onready var stat_time_value: Label = %StatTimeValue
@onready var stat_cities_value: Label = %StatCitiesValue
@onready var victory_note: Label = %VictoryNote
@onready var cities_label: Label = %CitiesLabel
@onready var record_label: Label = %RecordLabel
@onready var btn_result_action: Button = %BtnResultAction
@onready var btn_equip_reward: Button = %BtnEquipReward
@onready var medal_label: Label = %MedalLabel
@onready var rank_label: Label = %RankLabel
@onready var xp_label: Label = %XpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var unlock_label: Label = %UnlockLabel
@onready var next_goal_label: Label = %NextGoalLabel
@onready var btn_claim_missions: Button = %BtnClaimMissions
@onready var reward_card: Control = %RewardCard
@onready var gold_chip: Control = %GoldChip
@onready var cities_chip: Control = %CitiesChip
@onready var gold_icon: TextureRect = %GoldIcon
@onready var time_icon: TextureRect = %TimeIcon
@onready var cities_icon: TextureRect = %CitiesIcon
@onready var confetti_overlay: Control = %ConfettiOverlay
@onready var btn_next_level: Button = %BtnNextLevel
@onready var btn_victory_map: Button = %BtnVictoryMap
@onready var btn_share: Button = %BtnShare

@onready var defeat_panel: Control = %DefeatPanel
@onready var btn_retry: Button = %BtnRetry
@onready var defeat_xp_label: Label = %DefeatXpLabel
@onready var defeat_tip: Label = %DefeatTip
@onready var btn_defeat_upgrade: Button = %BtnDefeatUpgrade
@onready var btn_defeat_map: Button = %BtnDefeatMap

@onready var pause_panel: Control = %PausePanel
@onready var btn_pause: Button = %BtnPause
@onready var btn_resume: Button = %BtnResume
@onready var btn_pause_sound: Button = %BtnPauseSound
@onready var btn_pause_music: Button = %BtnPauseMusic
@onready var btn_pause_retry: Button = %BtnPauseRetry
@onready var btn_how_to_play: Button = %BtnHowToPlay
@onready var btn_accessibility: Button = %BtnAccessibility
@onready var btn_accessible_controls: Button = %BtnAccessibleControls
@onready var btn_settings: Button = %BtnSettings
@onready var btn_pause_map: Button = %BtnPauseMap
@onready var pause_rule: Label = %PauseRule
@onready var pause_hint: Label = %PauseHint

var confetti_pieces: Array = []
var _star_tweens: Array[Tween] = []
var _faction_bars: Dictionary = {}
var _faction_labels: Dictionary = {}
## Regla o pista del nivel (se muestra en la línea de contexto y en la pausa)
var _rule_text := ""
var _dominance_timer: float = 0.0
var _tip_panel: Control = null
var _tip_on_close: Callable = Callable()
## Sólo actualiza la etiqueta cuando cambia el segundo mostrado.
var _last_shown_second: int = -999
var _last_dominance_accessibility := ""
var _utility_panel: Control = null
var _accessible_panel: Control = null
var _accessible_status: Label
var _accessible_send_button: Button
var _accessible_orders_list: VBoxContainer
var _accessible_source_buttons: Dictionary = {}
var _accessible_target_buttons: Dictionary = {}
var _accessible_sources: Array[BaseNode] = []
var _accessible_target: BaseNode
var _share_result: Dictionary = {}
## La medalla de este nivel sigue en juego (campaña, aún no conseguida y sin bases perdidas)
var _medal_tracked: bool = false
var _result: Dictionary = {}
var _xp_tween: Tween
var _reward_to_equip := ""
var _opening_grace := 0.0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_requested()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Pausa automática al salir de la app (llamada entrante, cambio de app...)
			_on_pause_pressed(true)

func _exit_tree() -> void:
	_cleanup_time_scale()

func _cleanup_time_scale() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(battle_controller):
		battle_controller.reset_time_scale()

func _ready() -> void:
	_wrap_modal_contents()
	_apply_texts()
	UIThemeHelper.apply_locale_direction_children(self)
	_apply_safe_area()
	confetti_overlay.draw.connect(_draw_confetti)
	for entry in [[btn_pause, "pause"], [btn_pause_sound, "sound"], [btn_pause_music, "music"], [btn_resume, "play"],
			[btn_retry, "retry"], [btn_next_level, "play"], [btn_how_to_play, "help"], [btn_settings, "gear"], [btn_share, "share"]]:
		entry[0].icon = Icons.texture(entry[1], 44)
	for entry in [[gold_icon, "coin", 52], [time_icon, "clock", 40], [cities_icon, "globe", 40]]:
		entry[0].texture = Icons.texture(entry[1], entry[2])
	_build_faction_bars()
	for panel in [victory_panel, defeat_panel, pause_panel]:
		panel.resized.connect(_fit_panel.bind(panel))
	get_viewport().size_changed.connect(_fit_panels)
	get_viewport().size_changed.connect(_apply_safe_area)

	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_won.connect(_on_battle_won)
	EventBus.battle_lost.connect(_on_battle_lost)
	EventBus.settings_changed.connect(_refresh_palette)

	btn_pause.pressed.connect(func():
		AudioManager.play_click()
		_on_pause_pressed())
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_pause_retry.pressed.connect(_on_retry_pressed)
	btn_pause_map.pressed.connect(_on_map_pressed)
	btn_pause_sound.pressed.connect(_on_pause_sound_pressed)
	btn_pause_music.pressed.connect(_on_pause_music_pressed)
	btn_how_to_play.pressed.connect(func():
		AudioManager.play_click()
		# `_tip_panel`: el botón atrás de Android y Reanudar deben respetar la tarjeta abierta
		_tip_panel = UIThemeHelper.how_to_play_card()
		add_child(_tip_panel))
	btn_settings.pressed.connect(_open_settings)
	btn_accessibility.pressed.connect(_open_settings.bind(true))
	btn_accessible_controls.pressed.connect(_open_accessible_controls)
	btn_accessible_controls.disabled = not is_instance_valid(battle_controller)
	btn_next_level.pressed.connect(_on_next_level_pressed)
	btn_victory_map.pressed.connect(_on_map_pressed)
	btn_share.pressed.connect(_open_share)
	btn_retry.pressed.connect(_on_retry_pressed)
	btn_defeat_upgrade.pressed.connect(_on_upgrade_pressed)
	btn_defeat_map.pressed.connect(_on_map_pressed)
	btn_claim_missions.pressed.connect(_claim_missions)
	btn_result_action.pressed.connect(_on_result_action)
	btn_equip_reward.pressed.connect(_on_equip_reward)
	_refresh_audio_buttons()

func _wrap_modal_contents() -> void:
	for panel in [victory_panel, defeat_panel, pause_panel]:
		var content := panel.get_node_or_null("VBox") as Control
		if content == null:
			continue
		panel.remove_child(content)
		var scroll := ScrollContainer.new()
		scroll.name = "PanelScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(scroll)
		scroll.owner = panel.owner
		scroll.add_child(content)
		# ScrollContainer only widens children that expand; otherwise text wraps into a narrow, tall column.
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Wrapped text re-measures after layout; refit then so the card hugs its content.
		content.minimum_size_changed.connect(_fit_panel.bind(panel), CONNECT_DEFERRED)

## Textos estáticos de capas y botones en el idioma actual
func _apply_texts() -> void:
	_last_dominance_accessibility = ""
	for faction in _faction_labels:
		_faction_labels[faction].accessibility_name = GameManager.faction_name(faction)
	btn_share.text = LocaleStrings.text("share")
	btn_victory_map.text = LocaleStrings.text("exit")
	(defeat_panel.find_child("Title", true, false) as Label).text = LocaleStrings.text("defeat_title")
	UIThemeHelper.set_icon(btn_claim_missions, "coin", 40)
	defeat_tip.text = LocaleStrings.text("defeat_sub")
	btn_retry.text = LocaleStrings.text("retry")
	btn_defeat_upgrade.text = LocaleStrings.text("improve")
	btn_defeat_map.text = LocaleStrings.text("exit")
	(pause_panel.find_child("Title", true, false) as Label).text = LocaleStrings.text("pause")
	pause_hint.text = LocaleStrings.text("pause_auto_hint")
	btn_resume.text = LocaleStrings.text("resume")
	btn_pause_retry.text = LocaleStrings.text("restart_battle")
	btn_how_to_play.text = LocaleStrings.text("how_to_play")
	btn_accessibility.text = LocaleStrings.text("section_access")
	btn_settings.text = LocaleStrings.text("settings")
	btn_accessible_controls.text = LocaleStrings.text("accessible_battle_controls")
	btn_accessible_controls.accessibility_name = btn_accessible_controls.text
	btn_pause_map.text = LocaleStrings.text("exit")
	btn_pause.tooltip_text = LocaleStrings.text("pause")
	btn_pause.accessibility_name = LocaleStrings.text("pause")

## Un segmento de la barra de fuerzas por facción con sus tropas dentro (las enemigas 2 y 3 se
## crean aquí). Cada segmento ocupa una parte del ancho proporcional a sus tropas (stretch ratio).
func _build_faction_bars() -> void:
	_faction_bars = {
		GameManager.Faction.PLAYER: bar_player,
		GameManager.Faction.NEUTRAL: bar_neutral,
		GameManager.Faction.ENEMY_1: bar_enemy,
	}
	_faction_labels = {
		GameManager.Faction.PLAYER: label_count_player,
		GameManager.Faction.NEUTRAL: label_count_neutral,
		GameManager.Faction.ENEMY_1: label_count_enemy,
	}
	for f in [GameManager.Faction.ENEMY_2, GameManager.Faction.ENEMY_3]:
		var bar := bar_enemy.duplicate() as ColorRect
		bar.name = "BarEnemy%d" % f
		bar.unique_name_in_owner = false
		bar.get_child(0).unique_name_in_owner = false
		bar.visible = false
		bar_enemy.get_parent().add_child(bar)
		_faction_bars[f] = bar
		_faction_labels[f] = bar.get_child(0)
	for faction in _faction_labels:
		_faction_labels[faction].accessibility_name = GameManager.faction_name(faction)
	_refresh_palette()

## Colores que no vienen del tema (se repite al cambiar a modo claro u oscuro)
func _refresh_palette() -> void:
	for faction in _faction_bars:
		_faction_bars[faction].color = GameManager.faction_color(faction)
	victory_reward_label.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	stat_cities_value.add_theme_color_override("font_color", UIThemeHelper.colors.primary)
	time_icon.modulate = UIThemeHelper.colors.muted
	cities_icon.modulate = UIThemeHelper.colors.primary
	var reward_box := UIThemeHelper.box(Color.TRANSPARENT, 24, 20)
	reward_box.set_border_width_all(3)
	reward_box.border_color = Color(UIThemeHelper.colors.gold, 0.6)
	reward_card.add_theme_stylebox_override("panel", reward_box)
	medal_label.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	unlock_label.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	xp_label.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	(defeat_panel.find_child("Title", true, false) as Label).add_theme_color_override("font_color", UIThemeHelper.colors.danger)
	defeat_xp_label.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	for star in [star_1, star_2, star_3]:
		star.add_theme_color_override("font_color", UIThemeHelper.colors.gold if star.text == "★" else UIThemeHelper.colors.line)
	_last_shown_second = -999
	_update_objective()
	if not _result.is_empty():
		_refresh_result_title()
	call_deferred("_fit_panels")

func _refresh_audio_buttons() -> void:
	btn_pause_sound.modulate.a = 0.4 if AudioManager.is_muted else 1.0
	btn_pause_sound.tooltip_text = LocaleStrings.text("sound_off" if AudioManager.is_muted else "sound_on")
	btn_pause_sound.accessibility_name = btn_pause_sound.tooltip_text
	btn_pause_music.modulate.a = 0.4 if AudioManager.music_muted else 1.0
	btn_pause_music.tooltip_text = LocaleStrings.text("music_off" if AudioManager.music_muted else "music_on")
	btn_pause_music.accessibility_name = btn_pause_music.tooltip_text

func _on_pause_music_pressed() -> void:
	AudioManager.play_click()
	AudioManager.toggle_music()
	_refresh_audio_buttons()

func _on_pause_sound_pressed() -> void:
	if not AudioManager.toggle_mute():
		AudioManager.play_click()
	_refresh_audio_buttons()

## Lista accesible para inspeccionar bases y emitir las mismas órdenes que el gesto del mapa.
func _open_accessible_controls() -> void:
	if not is_instance_valid(battle_controller) or is_instance_valid(_accessible_panel):
		return
	_accessible_sources.clear()
	_accessible_target = null
	_accessible_source_buttons.clear()
	_accessible_target_buttons.clear()
	pause_panel.visible = false
	_accessible_panel = Control.new()
	_accessible_panel.name = "AccessibleBattleControlsPanel"
	_accessible_panel.accessibility_name = LocaleStrings.text("accessible_battle_controls")
	_accessible_panel.accessibility_description = LocaleStrings.text("accessible_battle_help")
	# In the tree first: overlay_page reads the viewport for safe-area insets.
	add_child(_accessible_panel)
	var content := UIThemeHelper.overlay_page(_accessible_panel, LocaleStrings.text("accessible_battle_controls"), _close_accessible_controls)
	UIThemeHelper.apply_locale_direction(_accessible_panel)
	content.add_child(UIThemeHelper.paragraph(LocaleStrings.text("accessible_battle_help")))
	UIThemeHelper.section(content, LocaleStrings.text("accessible_sources"), "", "Heading")
	var sources := UIThemeHelper.vbox(8)
	content.add_child(sources)
	for base in battle_controller.bases:
		if base.faction != GameManager.Faction.PLAYER:
			continue
		var button := _accessible_base_button(base)
		button.toggle_mode = true
		button.toggled.connect(_on_accessible_source_toggled.bind(base))
		sources.add_child(button)
		_accessible_source_buttons[base] = button
	UIThemeHelper.section(content, LocaleStrings.text("accessible_targets"), "", "Heading")
	var targets := UIThemeHelper.vbox(8)
	content.add_child(targets)
	var target_group := ButtonGroup.new()
	for base in battle_controller.bases:
		var button := _accessible_base_button(base)
		button.toggle_mode = true
		button.button_group = target_group
		button.pressed.connect(_select_accessible_target.bind(base))
		targets.add_child(button)
		_accessible_target_buttons[base] = button
	_accessible_status = UIThemeHelper.paragraph("")
	_accessible_status.name = "AccessibleBattleStatus"
	_accessible_status.accessibility_name = LocaleStrings.text("accessible_battle_controls")
	_accessible_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	content.add_child(_accessible_status)
	_accessible_send_button = UIThemeHelper.button(LocaleStrings.text("accessible_send"), "PrimaryButton", "play")
	_accessible_send_button.name = "AccessibleSend"
	_accessible_send_button.custom_minimum_size.y = 112
	_accessible_send_button.disabled = true
	_accessible_send_button.pressed.connect(_send_accessible_order)
	content.add_child(_accessible_send_button)
	var zoom := UIThemeHelper.hbox(12)
	var zoom_out := UIThemeHelper.button(LocaleStrings.text("accessible_zoom_out"))
	var zoom_in := UIThemeHelper.button(LocaleStrings.text("accessible_zoom_in"))
	zoom_out.pressed.connect(_zoom_accessible_map.bind(-0.25))
	zoom_in.pressed.connect(_zoom_accessible_map.bind(0.25))
	zoom.add_child(zoom_out)
	zoom.add_child(zoom_in)
	content.add_child(zoom)
	UIThemeHelper.section(content, LocaleStrings.text("accessible_orders_in_transit"), "", "Heading")
	_accessible_orders_list = UIThemeHelper.vbox(8)
	content.add_child(_accessible_orders_list)
	_refresh_accessible_orders()
	_update_accessible_send_state()
	UIThemeHelper.pass_scroll_events(content)
	_focus_accessible_control()

func _focus_accessible_control() -> void:
	var control: Control
	if is_instance_valid(_accessible_send_button) and not _accessible_send_button.disabled:
		control = _accessible_send_button
	elif not _accessible_source_buttons.is_empty():
		control = _accessible_source_buttons.values()[0] as Control
	else:
		control = _accessible_panel.find_child("BtnBack", true, false) as Control
	call_deferred("_grab_focus_if_available", control)

func _grab_focus_if_available(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion():
		control.grab_focus()

func _close_accessible_controls() -> void:
	if not is_instance_valid(_accessible_panel):
		return
	_accessible_panel.visible = false
	_accessible_panel.queue_free()
	_accessible_panel = null
	_accessible_status = null
	_accessible_send_button = null
	_accessible_orders_list = null
	_accessible_source_buttons.clear()
	_accessible_target_buttons.clear()
	_accessible_sources.clear()
	_accessible_target = null
	pause_panel.visible = true
	dim_overlay.visible = true
	call_deferred("_grab_focus_if_available", btn_accessible_controls)

func _accessible_base_button(base: BaseNode) -> Button:
	var description := base.accessibility_summary()
	var button := UIThemeHelper.button("%s · %s" % [base.base_name, description])
	button.name = "AccessibleBase_%d" % base.get_instance_id()
	button.custom_minimum_size.y = 92
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.accessibility_name = base.base_name
	button.accessibility_description = description
	return button

func _on_accessible_source_toggled(pressed: bool, base: BaseNode) -> void:
	if pressed:
		if not _accessible_sources.has(base):
			_accessible_sources.append(base)
		battle_controller.center_camera_on(base)
	else:
		_accessible_sources.erase(base)
	_update_accessible_send_state()

func _select_accessible_target(base: BaseNode) -> void:
	_accessible_target = base
	battle_controller.center_camera_on(base)
	_update_accessible_send_state()

func _update_accessible_send_state() -> void:
	if not is_instance_valid(_accessible_send_button):
		return
	var can_send := false
	if is_instance_valid(_accessible_target):
		for source in _accessible_sources:
			if is_instance_valid(source) and source.faction == GameManager.Faction.PLAYER \
					and source.troops > 1 and battle_controller.can_dispatch(source, _accessible_target):
				can_send = true
				break
	_accessible_send_button.disabled = not can_send
	if not is_instance_valid(_accessible_status):
		return
	if _accessible_sources.is_empty():
		_accessible_status.text = LocaleStrings.text("accessible_no_sources")
		return
	if not is_instance_valid(_accessible_target):
		_accessible_status.text = ""
		return
	if can_send:
		_accessible_status.text = ""
	elif _accessible_sources.any(func(source): return is_instance_valid(source) and source.troops > 1):
		_accessible_status.text = LocaleStrings.text("no_route")
	else:
		_accessible_status.text = LocaleStrings.text("accessible_no_troops")

func _send_accessible_order() -> void:
	if not is_instance_valid(_accessible_target):
		return
	var target_name := _accessible_target.base_name
	var sent_troops := 0
	var sent_sources := 0
	for source in _accessible_sources.duplicate():
		if not is_instance_valid(source) or source.faction != GameManager.Faction.PLAYER:
			continue
		var count := maxi(0, source.troops - 1)
		if count > 0 and battle_controller.dispatch_troops(source, _accessible_target):
			sent_troops += count
			sent_sources += 1
	if sent_sources == 0:
		_accessible_status.text = LocaleStrings.text("no_route") if _accessible_sources.any(func(source): return is_instance_valid(source) and source.troops > 1) else LocaleStrings.text("accessible_no_troops")
		return
	EventBus.player_assault.emit(sent_sources)
	GameManager.haptic(25)
	_accessible_status.text = LocaleStrings.text("accessible_order_sent") % [sent_troops, target_name]
	_accessible_sources.clear()
	for button in _accessible_source_buttons.values():
		(button as Button).set_pressed_no_signal(false)
	_refresh_accessible_base_summaries()
	_refresh_accessible_orders()
	_accessible_send_button.disabled = true
	_focus_accessible_control()

func _refresh_accessible_base_summaries() -> void:
	for buttons in [_accessible_source_buttons, _accessible_target_buttons]:
		for base in buttons:
			if not is_instance_valid(base) or not is_instance_valid(buttons[base]):
				continue
			var button: Button = buttons[base]
			var description: String = base.accessibility_summary()
			button.text = "%s · %s" % [base.base_name, description]
			button.accessibility_description = description

func _refresh_accessible_orders() -> void:
	if not is_instance_valid(_accessible_orders_list):
		return
	UIThemeHelper.clear(_accessible_orders_list)
	var count := 0
	for troop in battle_controller.active_troops:
		if not BattleController._is_alive(troop) or troop.faction != GameManager.Faction.PLAYER or troop.is_retreating:
			continue
		if not is_instance_valid(troop.origin_base) or not is_instance_valid(troop.target_base):
			continue
		var route := LocaleStrings.text("accessible_moving_order") % [troop.origin_base.base_name, troop.target_base.base_name, troop.count]
		var button := UIThemeHelper.button("%s · %s" % [LocaleStrings.text("accessible_retreat"), route], "GhostButton")
		button.name = "AccessibleRetreat_%d" % troop.get_instance_id()
		button.custom_minimum_size.y = 88
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.accessibility_name = LocaleStrings.text("accessible_retreat")
		button.accessibility_description = route
		button.pressed.connect(_retreat_accessible_order.bind(troop))
		_accessible_orders_list.add_child(button)
		count += 1
	if count == 0:
		_accessible_orders_list.add_child(UIThemeHelper.paragraph(LocaleStrings.text("accessible_no_orders")))

func _retreat_accessible_order(troop: Troop) -> void:
	if not BattleController._is_alive(troop) or troop.faction != GameManager.Faction.PLAYER:
		return
	troop.abort_mission()
	AudioManager.play_troop_retreat()
	GameManager.haptic(15)
	EventBus.troops_retreated.emit(GameManager.Faction.PLAYER)
	_refresh_accessible_base_summaries()
	_update_accessible_send_state()
	_accessible_status.text = LocaleStrings.text("accessible_retreat_done")
	_refresh_accessible_orders()
	_focus_accessible_control()

func _zoom_accessible_map(step: float) -> void:
	if is_instance_valid(battle_controller):
		battle_controller.adjust_camera_zoom(step)

func _open_settings(accessibility: bool = false) -> void:
	if is_instance_valid(_utility_panel):
		return
	Telemetry.screen_opened("settings")
	_utility_panel = load("res://scripts/ui/settings_panel.gd").new()
	_utility_panel.allow_backups = false # No reemplazar una partida mientras su batalla vive.
	_utility_panel.focus_accessibility_on_open = accessibility
	var return_focus: Control = btn_accessibility if accessibility else btn_settings
	_utility_panel.closed.connect(func():
		Telemetry.screen_opened("battle")
		_apply_texts()
		UIThemeHelper.apply_locale_direction_children(self)
		_refresh_audio_buttons()
		_refresh_palette()
		if is_instance_valid(battle_controller):
			_on_battle_started(battle_controller.level_id)
			for base in battle_controller.bases:
				base.base_name = GeoDatabase.city_name(GeoDatabase.get_city(base.city_key))
				if base.label_name:
					base.label_name.text = base.base_name
				base.refresh_accessible_labels()
		if is_instance_valid(return_focus):
			call_deferred("_grab_focus_if_available", return_focus))
	add_child(_utility_panel)
	UIThemeHelper.apply_locale_direction(_utility_panel)

func _open_share() -> void:
	if is_instance_valid(_utility_panel):
		return
	var text := DailyShare.text(_share_result)
	_utility_panel = UIThemeHelper.create_modal_card("invade.io", text, LocaleStrings.text("copy"), func():
		DisplayServer.clipboard_set(text)
		Toasts.show_toast("✅", "invade.io", LocaleStrings.text("copied")), true)
	_utility_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_utility_panel)
	var confirm: Button = _utility_panel.find_child("BtnConfirm", true, false)
	var back := UIThemeHelper.button(LocaleStrings.text("back"), "GhostButton")
	back.pressed.connect(_utility_panel.queue_free)
	confirm.get_parent().add_child(back)

func _fit_panels() -> void:
	for panel in [victory_panel, defeat_panel, pause_panel]:
		_fit_panel(panel)

func _apply_safe_area() -> void:
	UIThemeHelper.apply_safe_area_top(top_bar)
	UIThemeHelper.apply_safe_area_horizontal(top_bar)

## Result panels scroll when their text no longer fits; never shrink their text or touch targets.
func _fit_panel(panel: Control) -> void:
	var room := (get_viewport().get_visible_rect().size - Vector2(48, 48)).max(Vector2.ONE)
	var target := panel.size.min(room)
	var scroll := panel.find_child("PanelScroll", true, false) as ScrollContainer
	if scroll and scroll.get_child_count() > 0:
		var content := scroll.get_child(0) as Control
		var frame_height := maxf(0.0, panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y)
		var content_size := content.get_combined_minimum_size()
		target = Vector2(minf(maxf(panel.custom_minimum_size.x, content_size.x), room.x),
			minf(content_size.y + frame_height, room.y))
	if not panel.size.is_equal_approx(target):
		panel.size = target
	panel.position = (get_viewport().get_visible_rect().size - target) * 0.5
	panel.pivot_offset = target * 0.5
	panel.scale = Vector2.ONE

func _on_battle_started(level_id: String) -> void:
	var data: Dictionary = battle_controller.level_data if battle_controller and battle_controller.level_id == level_id else LevelDatabase.get_level_data(level_id)
	_opening_grace = LevelDatabase.get_balance(level_id)["grace"]
	label_level_name.text = data["name"]
	_rule_text = CampaignRules.description(data).strip_edges().get_slice("\n", 0)
	if level_id == "europe_4":
		_rule_text = LocaleStrings.text("hint_factory_short")
	pause_rule.text = CampaignRules.description(data).strip_edges()
	if data.has("objective"):
		pause_rule.text += "\n" + LocaleStrings.text("daily_objective") % (LocaleStrings.text(data["objective"]) % int(data["hold_seconds"]))
	pause_rule.visible = pause_rule.text != ""
	_medal_tracked = LevelDatabase.get_level_ids().has(level_id) and not GameManager.medals.has(level_id)
	_last_shown_second = -999
	_update_target_time()
	_update_objective()
	_introduce_rivals()

## La primera vez que aparece cada personalidad de IA, un aviso breve explica cómo juega
func _introduce_rivals() -> void:
	if not is_instance_valid(battle_controller) or not GameManager.has_seen_tip("drag"):
		return
	for ai in battle_controller.ai_controllers:
		var tip := "rival_%d" % ai.archetype
		if not GameManager.has_seen_tip(tip):
			GameManager.mark_tip_seen(tip)
			Toasts.show_toast("⚔️", "%s · %s" % [GameManager.faction_name(ai.faction), LocaleStrings.text(tip + "_t")], LocaleStrings.text(tip + "_b"), true)

## Una sola línea de contexto bajo el nombre del nivel, por prioridad: objetivo del diario,
## regla del nivel al empezar, ventana de apertura, regla y, por último, la medalla de dominio
func _update_objective() -> void:
	var valid := is_instance_valid(battle_controller)
	var elapsed := battle_controller.battle_time if valid else 0.0
	var remaining := 0
	if valid and not battle_controller.is_game_over and not battle_controller.ai_controllers.is_empty():
		remaining = ceili(_opening_grace - elapsed)
	var text := ""
	var color: Color = UIThemeHelper.colors.gold
	if valid and battle_controller.level_data.has("objective"):
		text = battle_controller.objective_text()
	elif _rule_text != "" and (elapsed < RULE_INTRO_SECONDS or remaining <= 0):
		text = _rule_text
	elif remaining > 0:
		text = LocaleStrings.text("opening_window") % remaining
		color = UIThemeHelper.colors.success
	elif _medal_tracked:
		var lost := valid and battle_controller.lost_a_base
		text = LocaleStrings.text("medal_lost" if lost else "medal_goal")
		color = UIThemeHelper.colors.muted if lost else UIThemeHelper.colors.gold
	objective_label.visible = text != ""
	objective_label.text = text
	objective_label.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	if battle_controller:
		_dominance_timer -= delta
		if _dominance_timer <= 0.0:
			_dominance_timer = DOMINANCE_UPDATE_INTERVAL
			_update_dominance_bar()
			_update_objective()
		if not battle_controller.is_game_over:
			_update_target_time()
	_update_confetti(delta)

## Estrellas que aún se consiguen y segundos que quedan para conservarlas (3★ → 2★ → 1★)
func _update_target_time() -> void:
	if not is_instance_valid(battle_controller):
		return
	var target := battle_controller.target_time
	var elapsed := battle_controller.battle_time
	var stars := 3 if elapsed <= target else (2 if elapsed <= target * 1.5 else 1)
	var limit := target if stars == 3 else target * 1.5
	var remaining := roundi(limit - elapsed) if stars > 1 else -1
	var key := stars * 10000 + remaining
	if key == _last_shown_second:
		return
	_last_shown_second = key
	var star_text := "★".repeat(stars)
	label_target_time.text = LocaleStrings.text("star_goal") % [star_text, remaining] if remaining >= 0 else LocaleStrings.text("star_goal_only") % star_text
	label_target_time.add_theme_color_override("font_color", UIThemeHelper.colors.gold if stars == 3 else UIThemeHelper.colors.gold.lerp(UIThemeHelper.colors.muted, 0.5 if stars == 2 else 1.0))

## Reparto de tropas en juego de cada bando, con el número dentro de su segmento
func _update_dominance_bar() -> void:
	var counts: Dictionary = battle_controller.get_faction_troop_counts()
	var total := 0
	var accessible_counts: PackedStringArray = []
	for f in _faction_bars:
		var count: int = counts.get(f, 0)
		total += count
		if count > 0:
			accessible_counts.append("%s: %d" % [GameManager.faction_name(f), count])
	var summary := ", ".join(accessible_counts)
	if summary != _last_dominance_accessibility:
		%DominanceBarContainer.accessibility_name = LocaleStrings.text("tab_army")
		%DominanceBarContainer.accessibility_description = summary
		_last_dominance_accessibility = summary
	for f in _faction_bars:
		var n: int = counts.get(f, 0)
		_faction_bars[f].visible = n > 0
		_faction_bars[f].size_flags_stretch_ratio = maxf(n, 0.001)
		_faction_labels[f].text = str(n)
		_faction_labels[f].visible = n >= total * MIN_LABEL_SHARE

func _update_confetti(delta: float) -> void:
	if confetti_pieces.is_empty():
		return
	var unscaled_dt = delta / maxf(Engine.time_scale, 0.01)
	for i in range(confetti_pieces.size() - 1, -1, -1):
		var p = confetti_pieces[i]
		p["vel"].y += 580.0 * unscaled_dt
		p["pos"] += p["vel"] * unscaled_dt
		p["rot"] += p["rot_speed"] * unscaled_dt
		p["wobble"] += p["wobble_speed"] * unscaled_dt
		p["alpha"] = maxf(0.0, p["alpha"] - unscaled_dt * 0.5)
		if p["alpha"] <= 0.0 or p["pos"].y > 900.0:
			confetti_pieces.remove_at(i)
	confetti_overlay.queue_redraw()

static func _confetti_half_size(size: Vector2, wobble: float) -> Vector2:
	var half := size * 0.5 * Vector2(1.0, absf(cos(wobble)))
	half.y = maxf(half.y, 0.5)
	return half

func _draw_confetti() -> void:
	for p in confetti_pieces:
		var half := BattleHUD._confetti_half_size(p["size"], p["wobble"])
		var xf := Transform2D(p["rot"], p["pos"])
		var quad := PackedVector2Array([
			xf * Vector2(-half.x, -half.y), xf * Vector2(half.x, -half.y),
			xf * Vector2(half.x, half.y), xf * Vector2(-half.x, half.y)
		])
		confetti_overlay.draw_colored_polygon(quad, Color(p["color"], clampf(p["alpha"], 0.0, 1.0)))

func _on_battle_won(stats: Dictionary) -> void:
	var slow_motion_on = is_instance_valid(battle_controller) and battle_controller.is_slow_motion_active
	if is_inside_tree() and (slow_motion_on or Engine.time_scale < 0.95):
		get_tree().create_timer(0.65, true, false, true).timeout.connect(func():
			if is_instance_valid(self) and is_inside_tree():
				deploy_victory_modal(stats)
		)
	else:
		deploy_victory_modal(stats)

func deploy_victory_modal(stats: Dictionary) -> void:
	_cleanup_time_scale()
	_result = stats.duplicate(true)
	defeat_panel.visible = false
	dim_overlay.visible = true
	var daily: bool = stats.get("is_daily_challenge", false)
	var conquest: bool = stats.get("is_conquest", false)
	var invasion: bool = stats.get("is_invasion", false)
	btn_share.visible = daily
	if daily:
		_share_result = {"day": DailyRewards.challenge_day(str(stats.get("level_id", GameManager.get_battle_level_id()))),
			"stars": stats.get("stars", 1), "time": stats.get("time", 0.0), "speed": stats.get("speed", 1.0), "balance_version": DailyRewards.BALANCE_VERSION}
	btn_next_level.visible = not daily
	if invasion:
		btn_next_level.text = LocaleStrings.text("next_region" if stats.get("region_complete", false) else "next_front")
	elif conquest:
		btn_next_level.text = LocaleStrings.text("next_region")
	else:
		btn_next_level.text = LocaleStrings.text("next_level")
	btn_victory_map.text = LocaleStrings.text("to_challenges" if daily else ("to_invasions" if invasion else "exit"))

	_refresh_result_title()

	stat_time_value.text = "%ds" % ceili(float(stats.get("time", 0.0)))
	victory_reward_label.text = "+%d" % stats.get("gold_earned", 0)
	stat_cities_value.text = "+%d" % stats.get("new_cities", 0)
	cities_chip.visible = int(stats.get("new_cities", 0)) > 0
	var city_names: Array = stats.get("city_names", [])
	cities_label.text = " · ".join(city_names.slice(0, 3)) + (" +%d" % (city_names.size() - 3) if city_names.size() > 3 else "")
	cities_label.visible = not city_names.is_empty()
	record_label.text = LocaleStrings.text("new_record")
	record_label.visible = stats.get("new_record", false)
	victory_note.text = LocaleStrings.text("replay_note")
	victory_note.visible = stats.get("is_replay", false)
	if int(stats.get("boss_gold", 0)) > 0:
		victory_note.text = LocaleStrings.text("boss_gold_earned") % stats["boss_gold"]
		victory_note.visible = true
	if int(stats.get("region_bonus", 0)) + int(stats.get("mastery_bonus", 0)) > 0:
		var notes: PackedStringArray = []
		if int(stats.get("region_bonus", 0)) > 0:
			notes.append(LocaleStrings.text("invasion_reward_gold") % stats["region_bonus"])
		if int(stats.get("mastery_bonus", 0)) > 0:
			notes.append(LocaleStrings.text("invasion_mastery_reward") % stats["mastery_bonus"])
		victory_note.text = "\n".join(notes)
		victory_note.visible = true
	medal_label.text = LocaleStrings.text("medal_won")
	medal_label.visible = stats.get("new_medal", false)
	_show_progress(stats)

	_fit_panel(victory_panel)
	UIThemeHelper.animate_modal_pop_in(victory_panel)
	trigger_confetti()
	animate_stars(stats.get("stars", 1))
	_pop_gold(stats.get("stars", 1))
	call_deferred("_grab_focus_if_available", btn_next_level if btn_next_level.visible else btn_victory_map)

## El oro ganado aparece de un salto justo después de la última estrella
func _pop_gold(stars_count: int) -> void:
	gold_chip.scale = Vector2.ONE
	if not is_inside_tree() or GameManager.settings["reduced_motion"]:
		return
	gold_chip.pivot_offset = gold_chip.size * 0.5
	gold_chip.scale = Vector2.ZERO
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_star_tweens.append(t)
	t.tween_interval(0.3 + mini(stars_count, 3) * 0.25)
	t.tween_property(gold_chip, "scale", Vector2(1.15, 1.15), 0.22)
	t.tween_property(gold_chip, "scale", Vector2.ONE, 0.12)

func _refresh_result_title() -> void:
	var title := ["victory", UIThemeHelper.colors.success]
	if _result.get("is_daily_challenge", false):
		title = ["daily_done", UIThemeHelper.colors.gold]
	elif _result.get("is_invasion", false):
		if int(_result.get("mastery_bonus", 0)) > 0:
			title = ["invasion_mastered", UIThemeHelper.colors.gold]
		elif int(_result.get("region_bonus", 0)) > 0:
			title = ["invasion_region_done", UIThemeHelper.colors.gold]
		else:
			title = ["invasion_front_done", UIThemeHelper.colors.primary]
	elif _result.get("expedition_finale", false):
		title = ["expedition_done", UIThemeHelper.colors.gold]
	elif _result.get("is_conquest", false):
		title = ["conquest_done", UIThemeHelper.colors.primary]
	elif _result.get("is_continent_conquest", false):
		title = ["continent_conquest", UIThemeHelper.colors.gold]
	victory_title.text = LocaleStrings.text(title[0])
	victory_title.add_theme_color_override("font_color", title[1])

## Progreso de la partida: XP ganada sobre la barra de rango, lo desbloqueado y un siguiente
## objetivo. Las misiones completadas se cobran aquí mismo, sin cambiar de pantalla.
func _show_progress(stats: Dictionary) -> void:
	var xp: int = stats.get("xp", 0)
	var before: int = stats.get("xp_before", GameManager.experience - xp)
	var level_before := PlayerRank.level(before)
	var level_now := GameManager.player_level()
	rank_label.text = LocaleStrings.text("rank_line") % [PlayerRank.title(level_now), level_now]
	xp_label.text = "+%d XP" % xp
	# Los signos + y las cifras se leen en LTR también en árabe.
	for numeric in [victory_reward_label, stat_cities_value, xp_label]:
		numeric.text_direction = Control.TEXT_DIRECTION_LTR
	xp_bar.value = PlayerRank.progress(before) if level_now == level_before else 0.0
	if is_instance_valid(_xp_tween):
		_xp_tween.kill()
	if is_inside_tree() and not GameManager.settings["reduced_motion"]:
		_xp_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_xp_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_xp_tween.tween_property(xp_bar, "value", PlayerRank.progress(GameManager.experience), XP_BAR_SECONDS).set_delay(0.3)
	else:
		xp_bar.value = PlayerRank.progress(GameManager.experience)

	var unlocks: PackedStringArray = []
	_reward_to_equip = ""
	for level in range(level_before + 1, level_now + 1):
		unlocks.append(LocaleStrings.text("rank_up") % PlayerRank.title(level))
		for item in CosmeticsDatabase.rank_rewards(level):
			unlocks.append(LocaleStrings.text("unlocked") % CosmeticsDatabase.item_name(item))
			_reward_to_equip = item["id"]
	if stats.get("new_continent", false):
		var reward := CosmeticsDatabase.continent_reward(LevelDatabase.get_continent_of(str(stats.get("level_id", ""))))
		if not reward.is_empty():
			unlocks.append(LocaleStrings.text("unlocked") % CosmeticsDatabase.item_name(reward))
			_reward_to_equip = reward["id"]
	if str(stats.get("invasions_unlocked", "")) != "":
		unlocks.append(LocaleStrings.text("invasions_unlocked") % LevelDatabase.continent_name(str(stats["invasions_unlocked"])))
		InvasionPage.last_continent = str(stats["invasions_unlocked"])
		InvasionPage.last_region = ""
	if str(stats.get("continent_reward", "")) != "":
		var invasion_reward := CosmeticsDatabase.get_by_id(str(stats["continent_reward"]))
		if not invasion_reward.is_empty():
			unlocks.append(LocaleStrings.text("unlocked") % CosmeticsDatabase.item_name(invasion_reward))
			_reward_to_equip = invasion_reward["id"]
	unlock_label.text = "\n".join(unlocks)
	unlock_label.visible = not unlocks.is_empty()
	_refresh_next_goal()

func _refresh_next_goal() -> void:
	var goal := NextGoal.text()
	next_goal_label.text = LocaleStrings.text("next_goal") % goal
	var claimable := GameManager.claimable_mission_count()
	btn_claim_missions.visible = claimable > 0
	btn_claim_missions.text = LocaleStrings.text("claim_missions") % claimable
	var guide: bool = GameManager.can_suggest_combat_upgrade() and not _result.get("is_daily_challenge", false)
	btn_result_action.visible = guide
	# La mejora propone un desvío: nunca compite en peso con «Siguiente nivel».
	btn_result_action.theme_type_variation = "Button"
	UIThemeHelper.set_icon(btn_result_action, "bolt", 36)
	btn_result_action.text = LocaleStrings.text("improve_continue")
	# El botón de mejora ya dice lo mismo que el siguiente objetivo
	next_goal_label.visible = goal != "" and not guide
	btn_equip_reward.visible = _reward_to_equip != ""
	if btn_equip_reward.visible:
		btn_equip_reward.text = LocaleStrings.text("equip_reward") % CosmeticsDatabase.item_name(CosmeticsDatabase.get_by_id(_reward_to_equip))
	reward_card.visible = unlock_label.visible or btn_equip_reward.visible or btn_claim_missions.visible

func _on_result_action() -> void:
	if GameManager.can_suggest_combat_upgrade() and not _result.get("is_daily_challenge", false):
		if is_instance_valid(battle_controller):
			if _result.get("is_conquest", false):
				GameManager.play_conquest(GameManager.conquest_next)
			elif _result.get("is_invasion", false):
				var next_invasion := GameManager.next_invasion_level(battle_controller.level_id)
				if next_invasion != "":
					GameManager.play_level(next_invasion)
			else:
				var next := GameManager.get_next_level(battle_controller.level_id)
				if next != "":
					GameManager.play_level(next)
		_on_upgrade_pressed()

func _on_equip_reward() -> void:
	if GameManager.equip_cosmetic(_reward_to_equip):
		AudioManager.play_click()
		_reward_to_equip = ""
		_refresh_next_goal()

func _claim_missions() -> void:
	var before := GameManager.experience
	var claimed := 0
	for m in GameManager.mission_definitions():
		if GameManager.claim_mission(m["id"]):
			claimed += 1
	if claimed > 0:
		AudioManager.play_star_reveal(1)
		GameManager.haptic(30)
	_result["xp"] = int(_result.get("xp", 0)) + GameManager.experience - before
	_show_progress(_result)

func trigger_confetti() -> void:
	confetti_pieces.clear()
	if GameManager.settings["reduced_motion"]:
		confetti_overlay.queue_redraw()
		return
	var colors := [UIThemeHelper.colors.gold, UIThemeHelper.colors.primary, UIThemeHelper.colors.success, UIThemeHelper.colors.text]
	for i in 75:
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		var spd = randf_range(320.0, 780.0)
		confetti_pieces.append({
			"pos": Vector2(randf_range(60, 840), randf_range(120, 260)),
			"vel": Vector2.from_angle(angle) * spd,
			"rot": randf_range(0.0, TAU),
			"rot_speed": randf_range(-7.0, 7.0),
			"wobble": randf_range(0.0, TAU),
			"wobble_speed": randf_range(5.0, 12.0),
			"size": Vector2(randf_range(12, 18), randf_range(6, 10)),
			"color": colors[i % colors.size()],
			"alpha": 1.0
		})

## Estrellas ganadas en oro (aparecen una a una) y las pendientes como contorno apagado
func animate_stars(stars_count: int) -> void:
	for t in _star_tweens:
		if is_instance_valid(t) and t.is_running():
			t.kill()
	_star_tweens.clear()

	var stars: Array[Label] = [star_1, star_2, star_3]
	for i in stars.size():
		var s := stars[i]
		var earned := i < stars_count
		s.text = "★" if earned else "☆"
		s.add_theme_color_override("font_color", UIThemeHelper.colors.gold if earned else UIThemeHelper.colors.muted)
		s.modulate = Color(1, 1, 1, 0.0 if earned else 1.0)
		s.scale = Vector2.ZERO if earned else Vector2.ONE

	if not is_inside_tree() or GameManager.settings["reduced_motion"]:
		for i in mini(stars_count, stars.size()):
			stars[i].modulate = Color.WHITE
			stars[i].scale = Vector2.ONE
		return

	for i in mini(stars_count, stars.size()):
		var s = stars[i]
		s.pivot_offset = s.size * 0.5
		var t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_star_tweens.append(t)
		t.tween_interval(0.2 + i * 0.25)
		t.tween_callback(AudioManager.play_star_reveal.bind(i))
		t.tween_property(s, "modulate:a", 1.0, 0.1)
		t.parallel().tween_property(s, "scale", Vector2.ONE, 0.25)

## Derrota: un consejo concreto de lo que pasó, la XP ganada y reintentar como acción principal.
## Mejorar sólo se ofrece si hay una mejora que se pueda comprar ya.
func _on_battle_lost() -> void:
	_cleanup_time_scale()
	dim_overlay.visible = true
	var tip := battle_controller.defeat_tip() if is_instance_valid(battle_controller) else ""
	defeat_tip.text = tip if tip != "" else LocaleStrings.text("defeat_sub")
	defeat_xp_label.text = LocaleStrings.text("defeat_xp") % [GameManager.DEFEAT_XP, PlayerRank.title(GameManager.player_level())]
	if is_instance_valid(battle_controller) and battle_controller.defeat_gold > 0:
		defeat_xp_label.text += "\n" + LocaleStrings.text("defeat_gold") % battle_controller.defeat_gold
	var upgrade := GameManager.recommended_combat_upgrade(true)
	var daily := is_instance_valid(battle_controller) and LevelDatabase.mode_of(battle_controller.level_id) == "daily"
	btn_defeat_upgrade.visible = upgrade != "" and not daily
	if btn_defeat_upgrade.visible:
		UIThemeHelper.set_icon(btn_defeat_upgrade, "bolt", 36)
		btn_defeat_upgrade.text = LocaleStrings.text("upgrade_named") % LocaleStrings.text("upg_" + upgrade)
	_fit_panel(defeat_panel)
	UIThemeHelper.animate_modal_pop_in(defeat_panel)
	call_deferred("_grab_focus_if_available", btn_retry)

# =========================================================================
# Pausa, botón "atrás" de Android y tarjetas de ayuda
# =========================================================================

func _can_pause() -> bool:
	return is_inside_tree() and not get_tree().paused and not victory_panel.visible and not defeat_panel.visible \
		and not (is_instance_valid(battle_controller) and battle_controller.is_game_over)

func _on_back_requested() -> void:
	if is_instance_valid(_accessible_panel):
		_close_accessible_controls()
	elif is_instance_valid(_utility_panel):
		if _utility_panel.has_method("_close"):
			_utility_panel._close()
		else:
			_utility_panel.queue_free()
	elif is_instance_valid(_tip_panel):
		_close_tip_card()
	elif pause_panel.visible:
		_on_resume_pressed()
	elif victory_panel.visible or defeat_panel.visible:
		_on_map_pressed()
	elif _can_pause():
		_on_pause_pressed()

## También se llama al perder el foco la app, sin clic
func _on_pause_pressed(automatic: bool = false) -> void:
	_cleanup_time_scale()
	if not is_inside_tree() or victory_panel.visible or defeat_panel.visible \
		or (is_instance_valid(battle_controller) and battle_controller.is_game_over):
		return
	if is_instance_valid(battle_controller):
		battle_controller._cancel_gesture()
	if not automatic:
		GameManager.save_game()
	_refresh_audio_buttons()
	pause_hint.visible = automatic
	dim_overlay.visible = true
	_fit_panel(pause_panel)
	UIThemeHelper.animate_modal_pop_in(pause_panel)
	get_tree().paused = true
	call_deferred("_grab_focus_if_available", btn_resume)

func _on_resume_pressed() -> void:
	if not pause_panel.visible or not GameManager.application_active or is_instance_valid(_tip_panel) or is_instance_valid(_utility_panel):
		return
	AudioManager.play_click()
	_cleanup_time_scale()
	UIThemeHelper.animate_modal_pop_out(pause_panel, func():
		if not GameManager.application_active:
			_on_pause_pressed(true)
			return
		dim_overlay.visible = false
		get_tree().paused = false
		call_deferred("_grab_focus_if_available", btn_pause)
	)

## Tarjeta modal explicativa (pausa la batalla hasta que el jugador la cierra)
func show_tip_card(title: String, body: String, on_close: Callable = Callable()) -> void:
	if is_instance_valid(_tip_panel):
		_tip_panel.queue_free()
	_tip_on_close = on_close
	_tip_panel = UIThemeHelper.create_modal_card(title, body, LocaleStrings.text("tip_ok"), _close_tip_card)
	add_child(_tip_panel)
	dim_overlay.visible = true
	get_tree().paused = true

func _close_tip_card() -> void:
	AudioManager.play_click()
	if is_instance_valid(_tip_panel):
		_tip_panel.queue_free()
	_tip_panel = null
	dim_overlay.visible = pause_panel.visible
	get_tree().paused = pause_panel.visible or not GameManager.application_active
	var cb = _tip_on_close
	_tip_on_close = Callable()
	if cb.is_valid():
		cb.call()

func _leave_battle(scene_path: String = "") -> void:
	AudioManager.play_click()
	GameManager.save_game()
	_cleanup_time_scale()
	get_tree().paused = false
	get_tree().scene_changed.connect(Toasts.flush, CONNECT_ONE_SHOT)
	if scene_path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)

func _on_retry_pressed() -> void:
	_leave_battle()

func _on_next_level_pressed() -> void:
	if LevelDatabase.mode_of(battle_controller.level_id) == "invasion":
		var next_invasion := GameManager.next_invasion_level(battle_controller.level_id)
		if next_invasion == "":
			_on_map_pressed()
			return
		GameManager.play_level(next_invasion)
		_leave_battle()
		return
	if LevelDatabase.mode_of(battle_controller.level_id) == "conquest":
		GameManager.play_conquest(LevelGenerator.conquest_index(battle_controller.level_id) + 1)
		_leave_battle()
		return
	var next_id = GameManager.get_next_level(battle_controller.level_id)
	if next_id == "":
		_on_map_pressed()
		return
	GameManager.play_level(next_id)
	_leave_battle()

## Sección del menú a la que se vuelve: diario a Retos, invasión a Invasiones, resto a Jugar
func exit_tab() -> String:
	if not is_instance_valid(battle_controller):
		return "play"
	if LevelDatabase.mode_of(battle_controller.level_id) == "daily":
		return "challenges"
	if LevelDatabase.mode_of(battle_controller.level_id) == "invasion":
		return "invasion"
	return "play"

func _on_map_pressed() -> void:
	MainMenuUI.next_tab = exit_tab()
	_leave_battle(MainMenuUI.SCENE)

## Tras una derrota, Ejército muestra un acceso directo para volver a esta misma batalla
func _on_upgrade_pressed() -> void:
	MainMenuUI.next_tab = "army"
	MainMenuUI.return_to_battle = true
	_leave_battle(MainMenuUI.SCENE)
