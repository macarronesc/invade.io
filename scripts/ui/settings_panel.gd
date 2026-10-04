extends Control

## Ajustes agrupados por tema: juego, sonido, accesibilidad y datos.

signal closed()
var allow_backups: bool = true
var _content: VBoxContainer
var _group: VBoxContainer
var _status: Label
var _save_status: Label
var _save_retry: Button
var _vibration_slider: HSlider
var _vibration_test: Button

func _ready() -> void:
	_build()
	GameManager.save_status_changed.connect(_refresh_save_status)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()

func _close() -> void:
	if is_queued_for_deletion():
		return
	AudioManager.play_click()
	closed.emit()
	queue_free()

func _build() -> void:
	UIThemeHelper.clear(self)
	_content = UIThemeHelper.overlay_page(self, LocaleStrings.text("settings"), _close)

	_section("section_game")
	_label(LocaleStrings.text("appearance"))
	_group.add_child(_options([LocaleStrings.text("theme_dark"), LocaleStrings.text("theme_light")], 1 if GameManager.settings["light_mode"] else 0, func(index):
		GameManager.set_setting("light_mode", index == 1)
		_build()))
	_label(LocaleStrings.text("language"))
	_group.add_child(_options(["Español", "English"], 1 if GameManager.language == "en" else 0, func(index):
		GameManager.set_language("en" if index == 1 else "es")
		_build()))
	_label(LocaleStrings.text("speed"))
	var speeds: Array = GameManager.GAME_SPEEDS.map(func(value): return "×" + String.num(value))
	_group.add_child(_options(speeds, GameManager.GAME_SPEEDS.find(float(GameManager.settings["speed"])), func(index):
		GameManager.set_setting("speed", GameManager.GAME_SPEEDS[index])))
	_button("how_to_play", func(): add_child(UIThemeHelper.how_to_play_card()), "help")

	_section("section_sound")
	_toggle("sound_enabled", not AudioManager.is_muted, func(value): AudioManager.set_muted(not value))
	_toggle("music_enabled", not AudioManager.music_muted, func(value): AudioManager.set_music_muted(not value))
	for key in ["volume", "music_volume"]:
		_slider(key)

	_section("section_feedback")
	_toggle("vibration", GameManager.settings["vibration"], func(value):
		GameManager.set_setting("vibration", value)
		_refresh_vibration_controls())
	_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("vibration_note")))
	_vibration_slider = _slider("vibration_intensity")
	_vibration_test = _button("vibration_test", func(): GameManager.haptic(60))
	if not OS.has_feature("mobile"):
		_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("vibration_mobile_only")))
	_refresh_vibration_controls()

	_section("section_access")
	for key in ["colorblind", "reduced_motion"]:
		_toggle(key, GameManager.settings[key], func(value): GameManager.set_setting(key, value))

	_section("section_data")
	_group.add_child(UIThemeHelper.label(LocaleStrings.text("save_auto"), "Heading"))
	_save_status = UIThemeHelper.paragraph("")
	_save_status.name = "LocalSaveStatus"
	_group.add_child(_save_status)
	_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("save_local_note")))
	_save_retry = _button("save_retry", func(): GameManager.save_game(), "retry")
	_refresh_save_status()
	if allow_backups:
		_button("backup_export", _choose_file.bind(false), "share")
		_button("backup_import", _choose_file.bind(true), "retry")
		_button("reset", _confirm_reset, "close")
		_status = UIThemeHelper.paragraph("")
		_group.add_child(_status)

func _refresh_save_status() -> void:
	var key := "save_local_ok"
	if GameManager.save_error == ERR_UNAVAILABLE:
		key = "save_newer_version"
	elif GameManager.save_error != OK:
		key = "save_local_error"
	elif GameManager.save_recovered:
		key = "save_recovered"
	_save_status.text = LocaleStrings.text(key)
	_save_status.add_theme_color_override("font_color", UIThemeHelper.colors.success if GameManager.save_error == OK else UIThemeHelper.colors.danger)
	_save_retry.visible = GameManager.save_error not in [OK, ERR_UNAVAILABLE]

func _refresh_vibration_controls() -> void:
	_vibration_slider.editable = GameManager.settings["vibration"]
	_vibration_test.disabled = not OS.has_feature("mobile") or not GameManager.settings["vibration"] or GameManager.settings["vibration_intensity"] <= 0.0

func _section(key: String) -> void:
	_content.add_child(UIThemeHelper.label(LocaleStrings.text(key), "Caption"))
	_group = UIThemeHelper.card(_content, "", 12)

func _label(text: String) -> void:
	_group.add_child(UIThemeHelper.label(text, "Caption"))

func _options(items: Array, selected: int, on_select: Callable) -> OptionButton:
	var options := OptionButton.new()
	options.custom_minimum_size.y = 128
	for item in items:
		options.add_item(item)
	options.selected = selected
	options.item_selected.connect(on_select)
	return options

func _button(key: String, callback: Callable, icon: String = "") -> Button:
	var button := UIThemeHelper.button(LocaleStrings.text(key), "", icon)
	button.custom_minimum_size.y = 128
	button.name = key.to_pascal_case()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	_group.add_child(button)
	return button

func _toggle(key: String, value: bool, callback: Callable) -> void:
	var check := CheckButton.new()
	check.custom_minimum_size.y = 128
	check.name = key.to_pascal_case()
	check.text = LocaleStrings.text(key)
	check.button_pressed = value
	check.toggled.connect(callback)
	_group.add_child(check)

func _slider(key: String) -> HSlider:
	var label := UIThemeHelper.label("", "Caption")
	var update := func(value: float): label.text = "%s · %d%%" % [LocaleStrings.text(key), roundi(value * 100)]
	update.call(float(GameManager.settings[key]))
	_group.add_child(label)
	var slider := HSlider.new()
	slider.name = key.to_pascal_case()
	slider.max_value = 1
	slider.step = 0.05
	slider.value = GameManager.settings[key]
	slider.custom_minimum_size.y = 128
	slider.value_changed.connect(func(value):
		GameManager.set_setting(key, value)
		update.call(value)
		if key == "vibration_intensity":
			_refresh_vibration_controls()
			GameManager.haptic(30))
	_group.add_child(slider)
	return slider

func _choose_file(importing: bool) -> void:
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.json ; invade.io"])
	dialog.current_file = "invade-backup.json"
	dialog.file_selected.connect(func(path):
		if importing:
			_confirm_import(path)
		else:
			_show_result(GameManager.write_save(path, GameManager.save_data()))
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)

func _confirm_import(path: String) -> void:
	_confirm(LocaleStrings.text("backup_confirm"), func():
		var error := GameManager.import_save(path)
		if error == OK:
			AudioManager.apply_volumes()
			_build()
		_show_result(error))

func _confirm_reset() -> void:
	_confirm(LocaleStrings.text("reset_confirm"), func():
		var error := GameManager.reset_save()
		AudioManager.apply_volumes()
		_build()
		if error != OK:
			_show_result(error))

func _confirm(text: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.confirmed.connect(func():
		action.call()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)

func _show_result(error: Error) -> void:
	_status.text = LocaleStrings.text("backup_ok" if error == OK else "backup_error")
