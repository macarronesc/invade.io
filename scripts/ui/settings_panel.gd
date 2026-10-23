extends Control

## Ajustes agrupados por tema: juego, sonido, accesibilidad y datos.

signal closed()
var allow_backups: bool = true
var focus_accessibility_on_open := false
var _content: VBoxContainer
var _group: VBoxContainer
var _status: Label
var _save_status: Label
var _save_retry: Button
var _vibration_slider: HSlider
var _vibration_test: Button

const BACKUP_FILTER := "*.json ; invade.io ; application/json"
const IOS_IMPORT_PATH := "user://backup_import.json"
const IOS_EXPORT_PATH := "user://backup_export.json"

func _ready() -> void:
	var focus_accessibility := focus_accessibility_on_open
	_build()
	if not focus_accessibility:
		call_deferred("_focus_control", "BtnBack")
	GameManager.save_status_changed.connect(_refresh_save_status)

func _focus_control(control_name: String) -> void:
	var control := find_child(control_name, true, false)
	if control is Control:
		control.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()

func _close() -> void:
	if is_queued_for_deletion():
		return
	AudioManager.play_click()
	closed.emit()
	queue_free()

func _build(restore_focus: String = "") -> void:
	var saved_scroll := 0
	var scrolls := find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		saved_scroll = (scrolls[0] as ScrollContainer).scroll_vertical
	if restore_focus == "":
		var focused := get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and is_ancestor_of(focused):
			restore_focus = str(focused.name)
	if restore_focus == "" and focus_accessibility_on_open:
		restore_focus = "Colorblind"
		focus_accessibility_on_open = false
	UIThemeHelper.clear(self)
	_content = UIThemeHelper.overlay_page(self, LocaleStrings.text("settings"), _close)

	_section("section_game")
	_label(LocaleStrings.text("appearance"))
	var appearance_changed := func(index):
		GameManager.set_setting("light_mode", index == 1)
		_build("Appearance")
	_group.add_child(_options([LocaleStrings.text("theme_dark"), LocaleStrings.text("theme_light")],
		1 if GameManager.settings["light_mode"] else 0, appearance_changed, "Appearance", LocaleStrings.text("appearance")))
	_label(LocaleStrings.text("language"))
	var locale_codes := LanguageCatalog.codes()
	var locale_names: Array = locale_codes.map(func(code): return LanguageCatalog.native_name(code))
	var language_changed := func(index):
		GameManager.set_language(locale_codes[index])
		_build("Language")
	_group.add_child(_options(locale_names, maxi(0, locale_codes.find(GameManager.language)),
		language_changed, "Language", LocaleStrings.text("language")))
	_label(LocaleStrings.text("speed"))
	var speeds: Array = GameManager.GAME_SPEEDS.map(func(value): return "×" + String.num(value))
	var speed_changed := func(index): GameManager.set_setting("speed", GameManager.GAME_SPEEDS[index])
	_group.add_child(_options(speeds, GameManager.GAME_SPEEDS.find(float(GameManager.settings["speed"])),
		speed_changed, "Speed", LocaleStrings.text("speed")))
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
	_label(LocaleStrings.text("accessibility_font_size"))
	var text_sizes := [LocaleStrings.text("text_size_standard"), LocaleStrings.text("text_size_large"), LocaleStrings.text("text_size_extra_large")]
	var text_size_changed := func(index): GameManager.set_setting("text_scale", index * 0.5)
	_group.add_child(_options(text_sizes, roundi(float(GameManager.settings["text_scale"]) * 2.0),
		text_size_changed, "TextSize", LocaleStrings.text("accessibility_font_size")))
	for key in ["colorblind", "reduced_motion"]:
		_toggle(key, GameManager.settings[key], func(value): GameManager.set_setting(key, value))
	_toggle("high_contrast_map", GameManager.settings["high_contrast_map"], func(value):
		GameManager.set_setting("high_contrast_map", value), "accessibility_high_contrast_map")
	if OS.has_feature("mobile") and not AccessibilityServer.is_supported():
		_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("accessibility_mobile_reader_note")))

	_section("section_privacy")
	_toggle("share_analytics", GameManager.settings["share_analytics"], func(value):
		GameManager.set_setting("share_analytics", value))
	_toggle("share_crashes", GameManager.settings["share_crashes"], func(value):
		GameManager.set_setting("share_crashes", value))
	_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("privacy_note")))
	_button("privacy_policy", func(): OS.shell_open(Telemetry.PRIVACY_URL), "shield")

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
	UIThemeHelper.pass_scroll_events(_content)
	call_deferred("_restore_focus_and_scroll", restore_focus, saved_scroll)

func _restore_focus_and_scroll(control_name: String, scroll_position: int) -> void:
	var scrolls := find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		(scrolls[0] as ScrollContainer).scroll_vertical = scroll_position
	if control_name != "":
		var control := find_child(control_name, true, false)
		if control is Control:
			control.grab_focus()

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

func _options(items: Array, selected: int, on_select: Callable, control_name: String, accessible_name: String) -> OptionButton:
	var options := OptionButton.new()
	options.name = control_name
	options.accessibility_name = accessible_name
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

func _toggle(key: String, value: bool, callback: Callable, label_key: String = "") -> void:
	var check := CheckButton.new()
	check.custom_minimum_size.y = 128
	check.name = key.to_pascal_case()
	check.text = LocaleStrings.text(label_key if label_key != "" else key)
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
	slider.accessibility_name = LocaleStrings.text(key)
	slider.accessibility_description = label.text
	slider.max_value = 1
	slider.step = 0.05
	slider.value = GameManager.settings[key]
	slider.custom_minimum_size.y = 128
	slider.value_changed.connect(func(value):
		GameManager.set_setting(key, value)
		update.call(value)
		slider.accessibility_description = label.text
		if key == "vibration_intensity":
			_refresh_vibration_controls()
			GameManager.haptic(30))
	_group.add_child(slider)
	return slider

func _choose_file(importing: bool) -> void:
	if OS.has_feature("ios"):
		_choose_ios_file(importing)
		return
	if OS.has_feature("android"):
		var title := LocaleStrings.text("backup_import" if importing else "backup_export")
		var mode := DisplayServer.FILE_DIALOG_MODE_OPEN_FILE if importing else DisplayServer.FILE_DIALOG_MODE_SAVE_FILE
		var path := "" if importing else "invade-backup.json"
		var error := DisplayServer.file_dialog_show(title, OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), path, false, mode,
			PackedStringArray(["application/json"]), _on_android_file_selected.bind(importing))
		if error != OK:
			_show_result(error)
		return
	_choose_desktop_file(importing)

func _choose_desktop_file(importing: bool) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray([BACKUP_FILTER])
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

func _on_android_file_selected(ok: bool, paths: PackedStringArray, _filter: int, importing: bool) -> void:
	if not ok or paths.is_empty():
		return
	if importing:
		_confirm_import(paths[0])
	else:
		_show_result(_write_backup(paths[0]))

func _choose_ios_file(importing: bool) -> void:
	if not Engine.has_singleton("BackupFilePicker"):
		_show_result(ERR_UNAVAILABLE)
		return
	var picker: Object = Engine.get_singleton("BackupFilePicker")
	if importing:
		var path := ProjectSettings.globalize_path(IOS_IMPORT_PATH)
		DirAccess.remove_absolute(path)
		picker.connect("file_selected", func(selected_path): _confirm_import(selected_path, true), CONNECT_ONE_SHOT)
		picker.connect("canceled", func(): DirAccess.remove_absolute(path), CONNECT_ONE_SHOT)
		picker.connect("failed", func():
			DirAccess.remove_absolute(path)
			_show_result(ERR_CANT_OPEN), CONNECT_ONE_SHOT)
		picker.call("pick_open", path)
		return

	var path := ProjectSettings.globalize_path(IOS_EXPORT_PATH)
	var error := GameManager.write_save(path, GameManager.save_data())
	if error != OK:
		_show_result(error)
		return
	picker.connect("exported", func():
		DirAccess.remove_absolute(path)
		_show_result(OK), CONNECT_ONE_SHOT)
	picker.connect("canceled", func(): DirAccess.remove_absolute(path), CONNECT_ONE_SHOT)
	picker.connect("failed", func():
		DirAccess.remove_absolute(path)
		_show_result(ERR_CANT_CREATE), CONNECT_ONE_SHOT)
	picker.call("pick_export", path)

func _write_backup(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(GameManager.save_data()))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _confirm_import(path: String, temporary: bool = false) -> void:
	_confirm(LocaleStrings.text("backup_confirm"), func():
		var error := GameManager.import_save(path)
		if temporary:
			DirAccess.remove_absolute(path)
		if error == OK:
			AudioManager.apply_volumes()
			_build()
		_show_result(error), func():
			if temporary:
				DirAccess.remove_absolute(path))

func _confirm_reset() -> void:
	_confirm(LocaleStrings.text("reset_confirm"), func():
		var error := GameManager.reset_save()
		AudioManager.apply_volumes()
		_build()
		if error != OK:
			_show_result(error))

func _confirm(text: String, action: Callable, on_cancel: Callable = Callable()) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.ok_button_text = LocaleStrings.text("confirm")
	dialog.cancel_button_text = LocaleStrings.text("cancel")
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.confirmed.connect(func():
		action.call()
		dialog.queue_free())
	dialog.canceled.connect(func():
		if on_cancel.is_valid():
			on_cancel.call()
		dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)

func _show_result(error: Error) -> void:
	_status.text = LocaleStrings.text("backup_ok" if error == OK else "backup_error")
