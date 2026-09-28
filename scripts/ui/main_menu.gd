extends Control
class_name MainMenuUI

## MainMenuUI: Menú principal State.io con fondo táctico vivo,
## botones 2.5D con animación elástica y estadísticas globales de campaña.

const BATTLE_SCENE := "res://scenes/battle/battle_field.tscn"

@onready var btn_play: Button = %BtnPlay
@onready var btn_world_map: Button = %BtnWorldMap
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_reset: Button = %BtnReset
@onready var btn_daily: Button = %BtnDaily
@onready var btn_achievements: Button = %BtnAchievements
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
## Cada armado del reinicio tiene su id: un temporizador antiguo no desarma uno nuevo
var _reset_arm_id: int = 0
var _daily_card: Control = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_daily_card):
			_on_daily_reward_claimed()
		else:
			get_tree().quit()

func _ready() -> void:
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($TopBar)
	btn_reset.text = RESET_LABEL

	btn_play.pressed.connect(_on_play_pressed)
	btn_world_map.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/world_map.tscn"))
	btn_upgrades.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/upgrade_menu.tscn"))
	btn_achievements.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/achievements_menu.tscn"))
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_daily.pressed.connect(_on_daily_pressed)
	btn_music.pressed.connect(_on_music_toggle_pressed)
	btn_sound.pressed.connect(_on_sound_toggle_pressed)
	EventBus.achievement_unlocked.connect(_update_secondary_buttons.unbind(1))
	EventBus.sound_toggled.connect(_update_sound_icon)
	EventBus.coins_updated.connect(_update_coins)

	AudioManager.play_music("menu")
	UIThemeHelper.update_music_button(btn_music, AudioManager.music_muted)
	_update_sound_icon(AudioManager.is_muted)
	_update_coins(GameManager.coins)
	_update_stars()
	_start_play_pulse()

	# Logros cumplidos con progreso anterior y recompensa diaria pendiente
	AchievementManager.check_all()
	_update_secondary_buttons()
	_show_daily_reward_card.call_deferred()

func _apply_visual_styling() -> void:
	UIThemeHelper.apply_stateio_button_style(btn_play, UIThemeHelper.COLOR_PRIMARY, 22, 7)
	UIThemeHelper.apply_stateio_button_style(btn_world_map, Color(0.18, 0.44, 0.65), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_upgrades, Color(0.16, 0.50, 0.42), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_reset, Color(0.38, 0.22, 0.24, 0.85), 14, 3)
	UIThemeHelper.apply_stateio_button_style(btn_sound, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_music, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_daily, Color(0.55, 0.36, 0.10), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_achievements, Color(0.42, 0.26, 0.58), 18, 5)
	UIThemeHelper.apply_pill_style(stars_pill)
	UIThemeHelper.apply_pill_style(coins_pill)

## Respiración sutil del botón de asalto; se detiene mientras el botón rebota al tocarlo,
## porque ambas animaciones mueven la misma escala
func _start_play_pulse() -> void:
	_play_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse_tween.tween_property(btn_play, "scale", Vector2(1.035, 1.035), 1.1)
	_play_pulse_tween.tween_property(btn_play, "scale", Vector2.ONE, 1.1)
	for sig in [btn_play.mouse_entered, btn_play.button_down]:
		sig.connect(_play_pulse_tween.pause)
	for sig in [btn_play.mouse_exited, btn_play.button_up]:
		sig.connect(_play_pulse_tween.play)

func _update_coins(amount: int) -> void:
	coins_label.text = UIThemeHelper.coins_text(amount)

func _update_stars() -> void:
	stars_label.text = UIThemeHelper.stars_text()

func _update_sound_icon(muted: bool) -> void:
	btn_sound.text = "🔇" if muted else "🔊"

func _on_music_toggle_pressed() -> void:
	AudioManager.play_click()
	UIThemeHelper.update_music_button(btn_music, AudioManager.toggle_music())

func _on_sound_toggle_pressed() -> void:
	if not AudioManager.toggle_mute():
		AudioManager.play_click()

func _on_play_pressed() -> void:
	# Continuar con el nivel actual de la campaña
	GameManager.play_level(GameManager.current_level_id)
	UIThemeHelper.go_to(self, BATTLE_SCENE)

## Muestra si el desafío de hoy ya está superado y cuántos logros esperan su recompensa
func _update_secondary_buttons() -> void:
	btn_daily.text = "🎯 DESAFÍO DIARIO" + (" ✅" if GameManager.is_daily_challenge_done() else "")
	var claimable := GameManager.get_claimable_achievement_count()
	btn_achievements.text = "🏆 LOGROS" + (" (%d)" % claimable if claimable > 0 else "")

func _on_daily_pressed() -> void:
	GameManager.play_level(DailyRewards.challenge_id(DailyRewards.today()))
	UIThemeHelper.go_to(self, BATTLE_SCENE)

func _show_daily_reward_card() -> void:
	var state := GameManager.get_daily_reward_state()
	if not state["can_claim"] or is_instance_valid(_daily_card):
		return
	var body := "Día %d de racha\n+%d 🪙\n\nVuelve mañana para seguir la racha: el día 7 da %d 🪙" % [
		state["streak"], state["reward"], DailyRewards.STREAK_REWARDS[-1]]
	_daily_card = UIThemeHelper.create_modal_card("🎁 RECOMPENSA DIARIA", body, "¡RECOGER!", _on_daily_reward_claimed, true)
	add_child(_daily_card)

func _on_daily_reward_claimed() -> void:
	if GameManager.claim_daily_reward() > 0:
		AudioManager.play_star_reveal(2)
		GameManager.haptic(30)
	if is_instance_valid(_daily_card):
		_daily_card.queue_free()
	_daily_card = null

## Reinicio en dos pasos: el primer toque pide confirmación durante unos segundos
func _on_reset_pressed() -> void:
	AudioManager.play_click()
	if not _reset_armed:
		_reset_armed = true
		_reset_arm_id += 1
		btn_reset.text = "⚠️ ¿SEGURO? PULSA DE NUEVO PARA BORRAR TODO"
		get_tree().create_timer(RESET_CONFIRM_WINDOW).timeout.connect(_on_reset_window_expired.bind(_reset_arm_id))
		return
	_disarm_reset()
	GameManager.reset_save()
	_update_coins(GameManager.coins)
	_update_stars()
	_update_secondary_buttons()
	_show_daily_reward_card()

func _on_reset_window_expired(arm_id: int) -> void:
	if arm_id == _reset_arm_id:
		_disarm_reset()

func _disarm_reset() -> void:
	_reset_armed = false
	_reset_arm_id += 1
	btn_reset.text = RESET_LABEL
