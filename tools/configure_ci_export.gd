extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var candidate := args.has("--size-candidate")
	if candidate and args.has("--production"):
		push_error("Size candidates cannot be production exports")
		quit(1)
		return
	var presets := ConfigFile.new()
	assert(presets.load("res://export_presets.cfg") == OK)
	# Disposable-key candidates must not replace store installs or existing Debug saves.
	var test_package := "macarronesc.invadeio.size" if candidate else "macarronesc.invadeio.debug"
	presets.set_value("preset.1.options", "package/unique_name", test_package)
	for preset in ["preset.0", "preset.1"]:
		presets.set_value(preset, "custom_features", "size_candidate" if candidate else "")
	if not args.has("--production"):
		presets.set_value("preset.0.options", "application/bundle_identifier", test_package)
	# Only the isolated signing job ever receives the production upload key.
	presets.set_value("preset.2.options", "package/signed", false)
	assert(presets.save("res://export_presets.cfg") == OK)
	quit()
