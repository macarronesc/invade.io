extends Control

signal closed()
var allow_backups: bool = true
var _content: VBoxContainer
var _status: Label

func _ready() -> void:
	_build()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()

func _close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_content = UIThemeHelper.overlay_page(self, LocaleStrings.text("settings"), _close)
	_label(LocaleStrings.text("language"))
	var languages := OptionButton.new()
	languages.add_item("Español")
	languages.add_item("English")
	languages.selected = 1 if GameManager.language == "en" else 0
	languages.custom_minimum_size.y = 80
	languages.add_theme_font_size_override("font_size", 30)
	languages.item_selected.connect(func(index):
		GameManager.set_language("en" if index == 1 else "es")
		_build())
	_content.add_child(languages)
	_toggle("sound_enabled", not AudioManager.is_muted, func(value): AudioManager.set_muted(not value))
	_toggle("music_enabled", not AudioManager.music_muted, func(value): AudioManager.set_music_muted(not value))
	for key in ["volume", "music_volume"]:
		_slider(key)
	for key in ["vibration", "colorblind"]:
		_toggle(key, GameManager.settings[key], func(value): GameManager.set_setting(key, value))
	_label(LocaleStrings.text("speed"))
	var speed := OptionButton.new()
	for value in GameManager.GAME_SPEEDS:
		speed.add_item("×%.2f" % value)
	speed.selected = GameManager.GAME_SPEEDS.find(float(GameManager.settings["speed"]))
	speed.custom_minimum_size.y = 80
	speed.add_theme_font_size_override("font_size", 30)
	speed.item_selected.connect(func(index): GameManager.set_setting("speed", GameManager.GAME_SPEEDS[index]))
	_content.add_child(speed)
	if allow_backups:
		_button("backup_export", _choose_file.bind(false))
		_button("backup_import", _choose_file.bind(true))
		_button("reset", _confirm_reset)
	_status = _label("")
	_label(LocaleStrings.text("platform_pending"))

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	_content.add_child(label)
	return label

func _button(key: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = LocaleStrings.text(key)
	button.custom_minimum_size.y = 80
	button.add_theme_font_size_override("font_size", 28)
	UIThemeHelper.apply_stateio_button_style(button, UIThemeHelper.COLOR_BTN_SECONDARY)
	button.pressed.connect(callback)
	_content.add_child(button)

func _toggle(key: String, value: bool, callback: Callable) -> void:
	var check := CheckButton.new()
	check.text = LocaleStrings.text(key)
	check.button_pressed = value
	check.custom_minimum_size.y = 80
	check.add_theme_font_size_override("font_size", 28)
	# Iconos nativos escalados para el lienzo vertical 1080p; fila completa táctil.
	for icon in ["checked", "unchecked"]:
		var image := check.get_theme_icon(icon, "CheckButton").get_image()
		image.resize(64, 32, Image.INTERPOLATE_LANCZOS)
		check.add_theme_icon_override(icon, ImageTexture.create_from_image(image))
	check.toggled.connect(callback)
	_content.add_child(check)

func _slider(key: String) -> void:
	var label := _label("%s · %d%%" % [LocaleStrings.text(key), roundi(float(GameManager.settings[key]) * 100)])
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = GameManager.settings[key]
	slider.custom_minimum_size.y = 60
	for icon in ["grabber", "grabber_highlight"]:
		var image := slider.get_theme_icon(icon).get_image()
		image.resize(36, 36, Image.INTERPOLATE_LANCZOS)
		slider.add_theme_icon_override(icon, ImageTexture.create_from_image(image))
	slider.value_changed.connect(func(value):
		GameManager.set_setting(key, value)
		label.text = "%s · %d%%" % [LocaleStrings.text(key), roundi(value * 100)])
	_content.add_child(slider)

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
		GameManager.reset_save()
		AudioManager.apply_volumes()
		_build())

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
