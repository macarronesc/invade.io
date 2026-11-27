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
var _help_card: Control
var _ios_picker: Object
var _ios_importing := false
var _ios_path := ""

const BACKUP_FILTER := "*.json ; invade.io ; application/json"
const IOS_IMPORT_PATH := "user://backup_import.json"
const IOS_EXPORT_PATH := "user://backup_export.json"

func _ready() -> void:
	_build()
	call_deferred("_focus_control", "BtnBack")
	GameManager.save_status_changed.connect(_refresh_save_status)

func _focus_control(control_name: String) -> void:
	var control := find_child(control_name, true, false)
	if control is Control:
		control.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_help_card):
			_help_card.queue_free()
			_help_card = null
			return
		var licenses := get_node_or_null("LicenseDetails")
		if licenses != null:
			licenses.queue_free()
			call_deferred("_focus_control", "OpenSourceLicenses")
		else:
			_close()

func _show_help() -> void:
	_help_card = UIThemeHelper.how_to_play_card()
	add_child(_help_card)

func _close() -> void:
	if is_queued_for_deletion():
		return
	AudioManager.play_click()
	closed.emit()
	queue_free()

func _exit_tree() -> void:
	_disconnect_ios_picker()

func _build(restore_focus: String = "") -> void:
	var saved_scroll := 0
	var scrolls := find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		saved_scroll = (scrolls[0] as ScrollContainer).scroll_vertical
	if restore_focus == "":
		var focused := get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and is_ancestor_of(focused):
			restore_focus = str(focused.name)
	UIThemeHelper.clear(self)
	_content = UIThemeHelper.overlay_page(self, LocaleStrings.text("settings"), _close)
	_section_game()
	_section_sound()
	_section_feedback()
	_section_access()
	_section_support()
	_section_privacy()
	_section_data()
	UIThemeHelper.pass_scroll_events(_content)
	call_deferred("_restore_focus_and_scroll", restore_focus, saved_scroll)

func _section_game() -> void:
	_section("section_game", "gear")
	var appearance_changed := func(index):
		GameManager.set_setting("light_mode", index == 1)
		_build()
	_choice("sun", "appearance", [{"text": LocaleStrings.text("theme_dark"), "icon": "moon"}, {"text": LocaleStrings.text("theme_light"), "icon": "sun"}],
		1 if GameManager.settings["light_mode"] else 0, appearance_changed, "Appearance")
	_header("globe", LocaleStrings.text("language"))
	var locale_codes := LanguageCatalog.codes()
	var locale_names: Array = locale_codes.map(func(code): return LanguageCatalog.native_name(code))
	var language_changed := func(index):
		GameManager.set_language(locale_codes[index])
		_build()
	var language := _options(locale_names, maxi(0, locale_codes.find(GameManager.language)),
		language_changed, "Language", LocaleStrings.text("language"))
	_group.add_child(language)
	var speeds: Array = GameManager.GAME_SPEEDS.map(func(value): return {"text": "×" + String.num(value)})
	_choice("speed", "speed", speeds, GameManager.GAME_SPEEDS.find(float(GameManager.settings["speed"])),
		func(index): GameManager.set_setting("speed", GameManager.GAME_SPEEDS[index]), "Speed")
	_button("how_to_play", _show_help, "help")

func _section_sound() -> void:
	_section("section_sound", "sound")
	_toggle("sound_enabled", not AudioManager.is_muted, func(value): AudioManager.set_muted(not value), "", "sound")
	_toggle("music_enabled", not AudioManager.music_muted, func(value): AudioManager.set_music_muted(not value), "", "music")
	_slider("volume", "sound")
	_slider("music_volume", "music")

func _section_feedback() -> void:
	_section("section_feedback", "vibrate", "vibration_note")
	_toggle("vibration", GameManager.settings["vibration"], func(value):
		GameManager.set_setting("vibration", value)
		_refresh_vibration_controls(), "", "vibrate")
	_vibration_test = UIThemeHelper.icon_button("play", LocaleStrings.text("vibration_test"))
	_vibration_test.name = "VibrationTest"
	_vibration_test.pressed.connect(func(): GameManager.haptic(60))
	_vibration_slider = _slider("vibration_intensity", "bolt", _vibration_test)
	if not GameManager.can_vibrate():
		_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("vibration_mobile_only")))
	_refresh_vibration_controls()

func _section_access() -> void:
	_section("section_access", "eye")
	var text_sizes := [LocaleStrings.text("text_size_standard"), LocaleStrings.text("text_size_large"), LocaleStrings.text("text_size_extra_large")]
	var text_size_items := []
	for i in text_sizes.size():
		text_size_items.append({"text": "A", "font": 28 + i * 8, "label": text_sizes[i]})
	_choice("text_size", "accessibility_font_size", text_size_items, roundi(float(GameManager.settings["text_scale"]) * 2.0),
		func(index): GameManager.set_setting("text_scale", index * 0.5), "TextSize")
	_toggle("colorblind", GameManager.settings["colorblind"], func(value): GameManager.set_setting("colorblind", value), "", "eye")
	_toggle("reduced_motion", GameManager.settings["reduced_motion"], func(value): GameManager.set_setting("reduced_motion", value), "", "motion")
	_toggle("high_contrast_map", GameManager.settings["high_contrast_map"], func(value):
		GameManager.set_setting("high_contrast_map", value), "accessibility_high_contrast_map", "contrast")
	_toggle("battle_controls_button", GameManager.settings["battle_controls_button"], func(value): GameManager.set_setting("battle_controls_button", value),
		"", "target", "battle_controls_button_note")
	if OS.has_feature("mobile") and not AccessibilityServer.is_supported():
		_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("accessibility_mobile_reader_note")))

func _section_support() -> void:
	_section("section_support", "heart", "support_note")
	_tiles([
		["support_project", "heart", func(): OS.shell_open(Telemetry.DONATE_URL)],
		["share", "share", func():
			DisplayServer.clipboard_set(DailyShare.APP_URL)
			Toasts.show_toast("✅", "invade.io", LocaleStrings.text("copied"))],
	], 2)

func _section_privacy() -> void:
	_section("section_privacy", "shield")
	_toggle("share_analytics", GameManager.settings["share_analytics"], func(value):
		GameManager.set_setting("share_analytics", value), "", "chart")
	_toggle("share_crashes", GameManager.settings["share_crashes"], func(value):
		GameManager.set_setting("share_crashes", value), "", "flag")
	_group.add_child(UIThemeHelper.paragraph(LocaleStrings.text("privacy_note")))
	_tiles([
		["privacy_policy", "shield", func(): OS.shell_open(Telemetry.PRIVACY_URL)],
		["open_source_licenses", "doc", _show_licenses],
	], 2)

func _section_data() -> void:
	_section("section_data", "share", "save_local_note")
	_group.add_child(UIThemeHelper.label(LocaleStrings.text("save_auto"), "Heading"))
	_save_status = UIThemeHelper.paragraph("")
	_save_status.name = "LocalSaveStatus"
	_group.add_child(_save_status)
	_save_retry = _button("save_retry", func(): GameManager.save_game(), "retry")
	_refresh_save_status()
	if allow_backups:
		var actions := []
		if not OS.has_feature("web"): # El navegador no ofrece diálogos de archivo del sistema.
			actions.append(["backup_export", "share", _choose_file.bind(false)])
			actions.append(["backup_import", "retry", _choose_file.bind(true)])
		actions.append(["reset", "close", _confirm_reset, true])
		_tiles(actions, actions.size())
		_status = UIThemeHelper.paragraph("")
		_group.add_child(_status)

func _restore_focus_and_scroll(control_name: String, scroll_position: int) -> void:
	var scrolls := find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		(scrolls[0] as ScrollContainer).scroll_vertical = scroll_position
	if control_name != "":
		var control := find_child(control_name, true, false)
		if control is Control:
			control.grab_focus()

func _show_licenses() -> void:
	var panel := Control.new()
	panel.name = "LicenseDetails"
	add_child(panel)
	var close := func():
		panel.queue_free()
		call_deferred("_focus_control", "OpenSourceLicenses")
	var content := UIThemeHelper.overlay_page(panel, LocaleStrings.text("open_source_licenses"), close)
	var text := TextEdit.new()
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.custom_minimum_size = Vector2(0, 1000)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.accessibility_name = LocaleStrings.text("open_source_licenses")
	text.text = FileAccess.get_file_as_string("res://assets/legal/notices.txt") + "\n\nGodot Engine\n" + Engine.get_license_text()
	text.text += "\n\n" + JSON.stringify(Engine.get_copyright_info(), "\t") + "\n\n" + JSON.stringify(Engine.get_license_info(), "\t")
	content.add_child(text)
	text.grab_focus()

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
	_vibration_test.disabled = not GameManager.can_vibrate() or not GameManager.settings["vibration"] or GameManager.settings["vibration_intensity"] <= 0.0

func _section(key: String, icon: String, info_key: String = "") -> void:
	_group = _content
	var title := LocaleStrings.text(key)
	_header(icon, title, _info_button(info_key, title) if info_key != "" else null)
	_group = UIThemeHelper.card(_content, "", 12)

## Fila de título: icono, nombre y un control opcional a la derecha
func _header(icon: String, title: String, trailing: Control = null) -> void:
	var head := UIThemeHelper.hbox(12)
	head.add_child(Icons.rect(icon, 32, UIThemeHelper.colors.muted))
	var label := UIThemeHelper.label(title, "Caption")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	if trailing != null:
		head.add_child(trailing)
	_group.add_child(head)

func _info_button(note_key: String, title: String) -> Button:
	var button := UIThemeHelper.button("", "GhostButton", "info")
	button.tooltip_text = title
	button.accessibility_name = title
	button.name = "Info" + note_key.to_pascal_case()
	button.pressed.connect(func():
		AudioManager.play_click()
		_help_card = UIThemeHelper.info_card(title, LocaleStrings.text(note_key))
		add_child(_help_card))
	return button

## Etiqueta con icono y un selector segmentado debajo
func _choice(icon: String, label_key: String, items: Array, selected: int, on_select: Callable, control_name: String) -> void:
	var title := LocaleStrings.text(label_key)
	_header(icon, title)
	var segments := UIThemeHelper.segmented(items, selected, on_select, control_name, title)
	for segment in segments.find_children("*", "Button", true, false):
		segment.custom_minimum_size.y = 96
	_group.add_child(segments)

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

func _toggle(key: String, value: bool, callback: Callable, label_key: String = "", icon: String = "", info_key: String = "") -> void:
	var check := CheckButton.new()
	check.custom_minimum_size.y = 128
	check.name = key.to_pascal_case()
	check.text = LocaleStrings.text(label_key if label_key != "" else key)
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Etiquetas largas (alemán, ruso) con texto grande no ensanchan la página.
	if icon != "":
		UIThemeHelper.set_icon(check, icon)
	check.button_pressed = value
	check.toggled.connect(callback)
	if info_key == "":
		_group.add_child(check)
		return
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIThemeHelper.hbox(8)
	row.add_child(check)
	row.add_child(_info_button(info_key, check.text))
	_group.add_child(row)

## Fila con icono, nombre y porcentaje, y el deslizador debajo (con un botón opcional a su lado)
func _slider(key: String, icon: String, trailing: Control = null) -> HSlider:
	var title := LocaleStrings.text(key)
	var percent := UIThemeHelper.label("", "Caption")
	_header(icon, title, percent)
	var slider := HSlider.new()
	slider.name = key.to_pascal_case()
	slider.accessibility_name = title
	slider.max_value = 1
	slider.step = 0.05
	slider.value = GameManager.settings[key]
	slider.custom_minimum_size.y = 128
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var update := func(value: float):
		percent.text = "%d%%" % roundi(value * 100)
		slider.accessibility_description = "%s · %s" % [title, percent.text]
	update.call(slider.value)
	slider.value_changed.connect(func(value):
		GameManager.set_setting(key, value, false)
		update.call(value)
		if key == "vibration_intensity":
			_refresh_vibration_controls()
			GameManager.haptic(30))
	if trailing == null:
		_group.add_child(slider)
	else:
		var row := UIThemeHelper.hbox(16)
		row.add_child(slider)
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(trailing)
		_group.add_child(row)
	return slider

## Cuadrícula de botones con icono sobre el texto
func _tiles(items: Array, columns: int) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for item in items:
		var tile := UIThemeHelper.button(LocaleStrings.text(item[0]), "", item[1])
		tile.name = item[0].to_pascal_case()
		tile.custom_minimum_size.y = 168
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if item.size() > 3:
			for state in ["font", "font_hover", "font_pressed", "font_focus", "icon_normal", "icon_hover", "icon_pressed", "icon_focus"]:
				tile.add_theme_color_override(state + "_color", UIThemeHelper.colors.danger)
		tile.pressed.connect(item[2])
		grid.add_child(tile)
	_group.add_child(grid)

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
	if is_instance_valid(_ios_picker):
		return
	if not Engine.has_singleton("BackupFilePicker"):
		_show_result(ERR_UNAVAILABLE)
		return
	var picker: Object = Engine.get_singleton("BackupFilePicker")
	if importing:
		var path := ProjectSettings.globalize_path(IOS_IMPORT_PATH)
		DirAccess.remove_absolute(path)
		_connect_ios_picker(picker, true, path)
		picker.call("pick_open", path)
		return

	var path := ProjectSettings.globalize_path(IOS_EXPORT_PATH)
	var error := GameManager.write_save(path, GameManager.save_data())
	if error != OK:
		_show_result(error)
		return
	_connect_ios_picker(picker, false, path)
	picker.call("pick_export", path)

func _connect_ios_picker(picker: Object, importing: bool, path: String) -> void:
	_disconnect_ios_picker()
	_ios_picker = picker
	_ios_importing = importing
	_ios_path = path
	picker.connect("file_selected", _on_ios_file_selected)
	picker.connect("exported", _on_ios_exported)
	picker.connect("canceled", _on_ios_canceled)
	picker.connect("failed", _on_ios_failed)

func _disconnect_ios_picker() -> void:
	if is_instance_valid(_ios_picker):
		for entry in [["file_selected", _on_ios_file_selected], ["exported", _on_ios_exported], ["canceled", _on_ios_canceled], ["failed", _on_ios_failed]]:
			_ios_picker.disconnect(entry[0], entry[1])
	_ios_picker = null
	if _ios_path != "":
		DirAccess.remove_absolute(_ios_path)
		_ios_path = ""

func _on_ios_file_selected(path: String) -> void:
	_ios_path = "" # Keep the imported temporary file until confirmation or cancellation.
	_disconnect_ios_picker()
	_confirm_import(path, true)

func _on_ios_exported() -> void:
	_disconnect_ios_picker()
	_show_result(OK)

func _on_ios_canceled() -> void:
	_disconnect_ios_picker()

func _on_ios_failed() -> void:
	var error := ERR_CANT_OPEN if _ios_importing else ERR_CANT_CREATE
	_disconnect_ios_picker()
	_show_result(error)

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
