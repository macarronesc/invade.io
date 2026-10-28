extends SceneTree

func _init() -> void:
	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg") == OK)
	# Debug installs must not replace the published app or share its private save storage.
	presets.set_value("preset.1.options", "package/unique_name", "macarronesc.invadeio.debug")
	if not OS.get_cmdline_user_args().has("--production"):
		presets.set_value("preset.0.options", "application/bundle_identifier", "macarronesc.invadeio.debug")
	# Only the isolated signing job ever receives the production upload key.
	presets.set_value("preset.2.options", "package/signed", false)
	assert(presets.save("res://export_presets.cfg") == OK)
	quit()
