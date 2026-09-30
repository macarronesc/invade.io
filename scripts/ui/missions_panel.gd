extends Control

var _day: int = -1
var _content: VBoxContainer

func _ready() -> void:
	_content = UIThemeHelper.overlay_page(self, LocaleStrings.text("missions"), queue_free)
	_refresh()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(func():
		if DailyRewards.today() > _day:
			_refresh())
	add_child(timer)
	timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		queue_free()

func _refresh() -> void:
	GameManager.ensure_missions()
	GameManager.save_game()
	_day = int(GameManager.missions["day"])
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var xp := Label.new()
	xp.text = UIThemeHelper.xp_text()
	xp.add_theme_font_size_override("font_size", 32)
	_content.add_child(xp)
	for mission in DailyMissions.for_day(_day):
		var card := PanelContainer.new()
		UIThemeHelper.apply_card_style(card)
		var style: StyleBoxFlat = card.get_theme_stylebox("panel")
		for side in ["left", "right", "top", "bottom"]:
			style.set("content_margin_" + side, 24.0)
		_content.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 20)
		card.add_child(column)
		var label := Label.new()
		label.text = LocaleStrings.text(mission["key"]) % mission["goal"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 30)
		column.add_child(label)
		var progress := ProgressBar.new()
		progress.max_value = mission["goal"]
		progress.value = GameManager.missions["progress"].get(mission["id"], 0)
		progress.custom_minimum_size.y = 32
		progress.show_percentage = false
		column.add_child(progress)
		var count := Label.new()
		count.text = "%d / %d" % [progress.value, progress.max_value]
		count.add_theme_font_size_override("font_size", 26)
		column.add_child(count)
		var claim := Button.new()
		claim.name = "Claim_" + mission["id"]
		claim.custom_minimum_size.y = 88
		claim.add_theme_font_size_override("font_size", 28)
		var claimed: bool = GameManager.missions["claimed"].has(mission["id"])
		claim.text = LocaleStrings.text("mission_claimed") if claimed else LocaleStrings.text("mission_claim") % [mission["gold"], mission["xp"]]
		claim.disabled = claimed or progress.value < progress.max_value
		UIThemeHelper.apply_stateio_button_style(claim, UIThemeHelper.COLOR_SUCCESS)
		claim.pressed.connect(func():
			if GameManager.claim_mission(mission["id"]):
				AudioManager.play_star_reveal(1)
			_refresh())
		column.add_child(claim)
	var note := Label.new()
	note.text = LocaleStrings.text("mission_reset")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 24)
	_content.add_child(note)
	if not GameManager.daily_best.is_empty() and int(GameManager.daily_best["day"]) == DailyRewards.today():
		var share := Button.new()
		share.text = LocaleStrings.text("share")
		share.custom_minimum_size.y = 80
		share.add_theme_font_size_override("font_size", 28)
		UIThemeHelper.apply_stateio_button_style(share, UIThemeHelper.COLOR_PRIMARY)
		share.pressed.connect(func():
			DisplayServer.clipboard_set(DailyShare.text(GameManager.daily_best))
			Toasts.show_toast("✓", "invade.io", LocaleStrings.text("copied")))
		_content.add_child(share)
