extends Control
class_name MainMenuUI

const UIThemeHelper = preload("res://scripts/ui/ui_theme_helper.gd")

## MainMenuUI: Menú principal State.io con fondo táctico vivo,
## botones 2.5D con animación elástica y estadísticas globales de campaña.

@onready var btn_play: Button = %BtnPlay
@onready var btn_world_map: Button = %BtnWorldMap
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_reset: Button = %BtnReset
@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var btn_sound: Button = %BtnSound
@onready var btn_music: Button = %BtnMusic
@onready var stars_pill: PanelContainer = %StarsPill
@onready var coins_pill: PanelContainer = %CoinsPill

const RESET_CONFIRM_WINDOW := 3.0
const RESET_LABEL := "🔄 REINICIAR PROGRESO"

var _play_pulse_tween: Tween = null
var _reset_armed: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()

func _ready() -> void:
	# 1. Aplicar estilos visuales 2.5D State.io
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($TopBar)
	btn_reset.text = RESET_LABEL

	# 2. Conectar eventos de interacción
	btn_play.pressed.connect(_on_play_pressed)
	btn_world_map.pressed.connect(_on_world_map_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)

	AudioManager.play_music("menu")
	btn_music.pressed.connect(_on_music_toggle_pressed)
	UIThemeHelper.update_music_button(btn_music, AudioManager.music_muted)
	if btn_sound:
		btn_sound.pressed.connect(_on_sound_toggle_pressed)
		_update_sound_icon(AudioManager.is_muted)
		if not EventBus.sound_toggled.is_connected(_update_sound_icon):
			EventBus.sound_toggled.connect(_update_sound_icon)

	# 3. Indicadores de estado de recursos
	_update_coins(GameManager.coins)
	_update_stars()
	EventBus.coins_updated.connect(_update_coins)

	# 4. Iniciar animación de respiración sutil en el botón central de asalto
	_start_play_pulse()

func _apply_visual_styling() -> void:
	if btn_play:
		UIThemeHelper.apply_stateio_button_style(btn_play, UIThemeHelper.COLOR_PRIMARY, Color.TRANSPARENT, 22, 7)
	if btn_world_map:
		UIThemeHelper.apply_stateio_button_style(btn_world_map, Color(0.18, 0.44, 0.65), Color.TRANSPARENT, 18, 5)
	if btn_upgrades:
		UIThemeHelper.apply_stateio_button_style(btn_upgrades, Color(0.16, 0.50, 0.42), Color.TRANSPARENT, 18, 5)
	if btn_reset:
		UIThemeHelper.apply_stateio_button_style(btn_reset, Color(0.38, 0.22, 0.24, 0.85), Color.TRANSPARENT, 14, 3)
	if btn_sound:
		UIThemeHelper.apply_stateio_button_style(btn_sound, Color(0.18, 0.24, 0.32), Color.TRANSPARENT, 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_music, Color(0.18, 0.24, 0.32), Color.TRANSPARENT, 16, 4)

	if stars_pill:
		UIThemeHelper.apply_pill_style(stars_pill, UIThemeHelper.COLOR_HEADER_PILL, Color(0.35, 0.45, 0.58, 0.60), 22)
	if coins_pill:
		UIThemeHelper.apply_pill_style(coins_pill, UIThemeHelper.COLOR_HEADER_PILL, Color(0.35, 0.45, 0.58, 0.60), 22)

func _start_play_pulse() -> void:
	if not btn_play or not is_inside_tree():
		return
	if _play_pulse_tween and _play_pulse_tween.is_running():
		_play_pulse_tween.kill()

	btn_play.pivot_offset = btn_play.size * 0.5
	_play_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse_tween.tween_property(btn_play, "scale", Vector2(1.035, 1.035), 1.1)
	_play_pulse_tween.tween_property(btn_play, "scale", Vector2.ONE, 1.1)

func _update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 %d" % amount

func _update_stars() -> void:
	if stars_label:
		var total_stars = GameManager.get_total_stars()
		var max_stars = GameManager.get_max_possible_stars()
		stars_label.text = "⭐ %d/%d" % [total_stars, max_stars]

func _update_sound_icon(muted: bool) -> void:
	if btn_sound:
		btn_sound.text = "🔇" if muted else "🔊"

func _on_music_toggle_pressed() -> void:
	AudioManager.play_click()
	UIThemeHelper.update_music_button(btn_music, AudioManager.toggle_music())

func _on_sound_toggle_pressed() -> void:
	var new_muted = AudioManager.toggle_mute()
	_update_sound_icon(new_muted)
	if not new_muted:
		AudioManager.play_click()

func _on_play_pressed() -> void:
	AudioManager.play_click()
	# Continuar con el nivel actual
	get_tree().change_scene_to_file("res://scenes/battle/battle_field.tscn")

func _on_world_map_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/world_map.tscn")

func _on_upgrades_pressed() -> void:
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_menu.tscn")

## Reinicio en dos pasos: el primer toque pide confirmación durante unos segundos
func _on_reset_pressed() -> void:
	AudioManager.play_click()
	if not _reset_armed:
		_reset_armed = true
		btn_reset.text = "⚠️ ¿SEGURO? PULSA DE NUEVO PARA BORRAR TODO"
		if is_inside_tree():
			get_tree().create_timer(RESET_CONFIRM_WINDOW).timeout.connect(_disarm_reset)
		return
	_disarm_reset()
	GameManager.reset_save()
	_update_coins(GameManager.coins)
	_update_stars()

func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(btn_reset):
		btn_reset.text = RESET_LABEL
