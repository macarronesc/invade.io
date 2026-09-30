extends Control
class_name MainMenuUI

## MainMenuUI: Menú principal State.io con fondo táctico vivo,
## botones 2.5D con animación elástica y estadísticas globales de campaña.

const BATTLE_SCENE := "res://scenes/battle/battle_field.tscn"

@onready var btn_play: Button = %BtnPlay
@onready var btn_world_map: Button = %BtnWorldMap
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_daily: Button = %BtnDaily
@onready var btn_achievements: Button = %BtnAchievements
@onready var btn_conquest: Button = %BtnConquest
@onready var btn_atlas: Button = %BtnAtlas
@onready var title_badge: Label = $HeaderBox/TitleBadge
@onready var subtitle_label: Label = $HeaderBox/Subtitle
@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var stars_pill: PanelContainer = %StarsPill
@onready var coins_pill: PanelContainer = %CoinsPill
@onready var btn_settings: Button = %BtnSettings
@onready var btn_missions: Button = %BtnMissions
@onready var xp_label: Label = %XPLabel

var _play_pulse_tween: Tween = null
var _daily_card: Control = null
var _utility_panel: Control = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_utility_panel):
			return # El panel maneja su propio botón atrás.
		if is_instance_valid(_daily_card):
			_on_daily_reward_claimed()
		else:
			get_tree().quit()

func _ready() -> void:
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($TopBar)

	# Primer arranque: directo a la batalla, sin menús ni tarjetas en medio.
	# Sólo cuando el menú es la escena real (en tests se instancia como hijo).
	if not GameManager.has_started and get_tree().current_scene == self:
		GameManager.has_started = true
		GameManager.save_game()
		GameManager.play_level(GameManager.FIRST_LEVEL_ID)
		UIThemeHelper.go_to.bind(self, BATTLE_SCENE).call_deferred()
		return

	_apply_texts()
	btn_play.pressed.connect(_on_play_pressed)
	btn_world_map.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/world_map.tscn"))
	btn_upgrades.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/upgrade_menu.tscn"))
	btn_achievements.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/achievements_menu.tscn"))
	btn_conquest.pressed.connect(_on_conquest_pressed)
	btn_atlas.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/atlas_menu.tscn"))
	btn_daily.pressed.connect(_on_daily_pressed)
	btn_settings.pressed.connect(_open_settings)
	btn_missions.pressed.connect(_open_missions)
	EventBus.achievement_unlocked.connect(_update_secondary_buttons.unbind(1))
	EventBus.coins_updated.connect(_update_coins)

	AudioManager.play_music("menu")
	_update_coins(GameManager.coins)
	_update_stars()
	xp_label.text = UIThemeHelper.xp_text()
	_start_play_pulse()

	# Logros cumplidos con progreso anterior y recompensa diaria pendiente
	AchievementManager.check_all()
	_update_secondary_buttons()
	_show_daily_reward_card.call_deferred()

func _apply_texts() -> void:
	title_badge.text = LocaleStrings.text("menu_badge")
	subtitle_label.text = LocaleStrings.text("menu_subtitle")
	btn_play.text = LocaleStrings.text("play")
	btn_world_map.text = LocaleStrings.text("world_map")
	btn_upgrades.text = LocaleStrings.text("upgrades")
	btn_settings.text = "⚙"
	btn_settings.tooltip_text = LocaleStrings.text("settings")
	btn_missions.text = "☑ " + LocaleStrings.text("missions")

func _apply_visual_styling() -> void:
	UIThemeHelper.apply_stateio_button_style(btn_play, UIThemeHelper.COLOR_PRIMARY, 22, 7)
	UIThemeHelper.apply_stateio_button_style(btn_world_map, Color("2574b2"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_upgrades, Color("167862"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_daily, Color("996300"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_achievements, Color("7953bb"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_conquest, Color("087d92"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_atlas, Color("446cc1"), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_settings, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_missions, UIThemeHelper.COLOR_BTN_SECONDARY, 18, 4)
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

func _on_play_pressed() -> void:
	# Continuar con el nivel actual de la campaña
	GameManager.play_level(GameManager.current_level_id)
	UIThemeHelper.go_to(self, BATTLE_SCENE)

## Muestra si el desafío de hoy ya está superado y cuántos logros esperan su recompensa
func _update_secondary_buttons() -> void:
	btn_daily.text = LocaleStrings.text("daily") + (" ✅" if GameManager.is_daily_challenge_done() else "")
	var claimable := GameManager.get_claimable_achievement_count()
	btn_achievements.text = LocaleStrings.text("achievements") + (" (%d)" % claimable if claimable > 0 else "")
	btn_conquest.text = "%s #%d" % [LocaleStrings.text("conquest"), GameManager.conquest_next + 1]
	var total := GameManager.atlas_total_count()
	var pct := int(round(100.0 * GameManager.atlas_conquered_count() / float(maxi(1, total))))
	btn_atlas.text = "%s · %d%%" % [LocaleStrings.text("atlas"), pct]

func _on_conquest_pressed() -> void:
	GameManager.play_conquest(GameManager.conquest_next)
	UIThemeHelper.go_to(self, BATTLE_SCENE)

func _open_settings() -> void:
	if is_instance_valid(_utility_panel):
		return
	_utility_panel = load("res://scripts/ui/settings_panel.gd").new()
	_utility_panel.closed.connect(func(): get_tree().reload_current_scene())
	add_child(_utility_panel)

func _open_missions() -> void:
	if is_instance_valid(_utility_panel):
		return
	_utility_panel = load("res://scripts/ui/missions_panel.gd").new()
	_utility_panel.tree_exited.connect(func():
		if is_instance_valid(xp_label): xp_label.text = UIThemeHelper.xp_text())
	add_child(_utility_panel)

func _on_daily_pressed() -> void:
	GameManager.play_level(DailyRewards.challenge_id(DailyRewards.today()))
	UIThemeHelper.go_to(self, BATTLE_SCENE)

func _show_daily_reward_card() -> void:
	var state := GameManager.get_daily_reward_state()
	if not state["can_claim"] or is_instance_valid(_daily_card):
		return
	var body := LocaleStrings.text("daily_body") % [
		state["streak"], state["reward"], DailyRewards.STREAK_REWARDS[-1]]
	_daily_card = UIThemeHelper.create_modal_card(LocaleStrings.text("daily_title"), body, LocaleStrings.text("daily_claim"), _on_daily_reward_claimed, true)
	add_child(_daily_card)

func _on_daily_reward_claimed() -> void:
	if GameManager.claim_daily_reward() > 0:
		AudioManager.play_star_reveal(2)
		GameManager.haptic(30)
	if is_instance_valid(_daily_card):
		_daily_card.queue_free()
	_daily_card = null
