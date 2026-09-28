extends Control
class_name AchievementsMenuUI

## AchievementsMenuUI: lista de logros con su progreso y el botón para reclamar la recompensa.
## Orden: primero los que se pueden reclamar, después los que están en curso y al final los cobrados.

@onready var coins_label: Label = %CoinsLabel
@onready var count_label: Label = %CountLabel
@onready var cards_container: VBoxContainer = %CardsContainer
@onready var btn_back: Button = %BtnBack
@onready var count_pill: PanelContainer = %CountPill
@onready var coins_pill: PanelContainer = %CoinsPill

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _ready() -> void:
	AudioManager.play_music("menu")
	UIThemeHelper.apply_stateio_button_style(btn_back, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_pill_style(count_pill)
	UIThemeHelper.apply_pill_style(coins_pill)
	UIThemeHelper.apply_safe_area_top($Header)
	btn_back.pressed.connect(_on_back_pressed)
	EventBus.coins_updated.connect(_update_coins)
	_update_coins(GameManager.coins)
	_build_cards()

func _update_coins(amount: int) -> void:
	coins_label.text = UIThemeHelper.coins_text(amount)

static func _sort_rank(a: Dictionary) -> int:
	if GameManager.is_achievement_claimed(a["id"]):
		return 2
	return 0 if GameManager.is_achievement_unlocked(a["id"]) else 1

func _build_cards() -> void:
	for c in cards_container.get_children():
		cards_container.remove_child(c)
		c.queue_free()
	var all := AchievementDatabase.get_all()
	# Por grupos y, dentro de cada uno, en el orden de diseño
	for rank in 3:
		for a in all:
			if _sort_rank(a) == rank:
				cards_container.add_child(_build_card(a))
	var unlocked := all.filter(func(a): return GameManager.is_achievement_unlocked(a["id"])).size()
	count_label.text = "🏆 %d/%d" % [unlocked, all.size()]

func _build_card(a: Dictionary) -> PanelContainer:
	var unlocked := GameManager.is_achievement_unlocked(a["id"])
	var claimed := GameManager.is_achievement_claimed(a["id"])
	var card := PanelContainer.new()
	card.name = "Card_%s" % a["id"]
	var border := UIThemeHelper.COLOR_ACCENT if unlocked and not claimed else UIThemeHelper.COLOR_CARD_BORDER
	UIThemeHelper.apply_card_style(card, UIThemeHelper.COLOR_CARD, border, 18, 2)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	var icon := Label.new()
	icon.text = a["icon"]
	icon.add_theme_font_size_override("font_size", 56)
	icon.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.45)
	row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 6)
	row.add_child(texts)
	var title := Label.new()
	title.text = a["title"]
	title.add_theme_font_size_override("font_size", 30)
	texts.add_child(title)
	var desc := Label.new()
	desc.text = a["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	texts.add_child(desc)
	if not unlocked:
		texts.add_child(_build_progress(a))

	if claimed:
		var done := Label.new()
		done.text = "✔️"
		done.add_theme_font_size_override("font_size", 44)
		row.add_child(done)
	elif unlocked:
		var btn := Button.new()
		btn.name = "BtnClaim"
		btn.text = "RECLAMAR\n🪙 %d" % a["reward"]
		btn.custom_minimum_size = Vector2(210, 100)
		btn.add_theme_font_size_override("font_size", 24)
		UIThemeHelper.apply_stateio_button_style(btn, UIThemeHelper.COLOR_SUCCESS, 16, 5)
		btn.pressed.connect(_on_claim_pressed.bind(a["id"]))
		row.add_child(btn)
	else:
		var reward := Label.new()
		reward.text = UIThemeHelper.coins_text(a["reward"])
		reward.add_theme_font_size_override("font_size", 26)
		reward.modulate = Color(1, 1, 1, 0.55)
		row.add_child(reward)
	return card

func _build_progress(a: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 1.0
	bar.value = AchievementManager.get_progress(a)
	for part in [["background", Color(0.08, 0.10, 0.14)], ["fill", UIThemeHelper.COLOR_PRIMARY]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = part[1]
		sb.set_corner_radius_all(8)
		bar.add_theme_stylebox_override(part[0], sb)
	box.add_child(bar)
	var amount := Label.new()
	amount.text = "%d/%d" % [mini(AchievementManager.get_stat(a["stat"]), a["goal"]), a["goal"]]
	amount.add_theme_font_size_override("font_size", 22)
	box.add_child(amount)
	return box

func _on_claim_pressed(id: String) -> void:
	if GameManager.claim_achievement(id) > 0:
		AudioManager.play_star_reveal(2)
		GameManager.haptic(30)
	_build_cards()

func _on_back_pressed() -> void:
	UIThemeHelper.go_to(self, "res://scenes/ui/main_menu.tscn")
