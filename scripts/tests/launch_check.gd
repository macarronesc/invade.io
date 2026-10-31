extends Node

## Ejercita el arranque real y permite capturar la intro sin tocar la partida del jugador.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var tree := get_tree()
	var args := OS.get_cmdline_user_args()
	var returning := "--returning" in args
	var reduced := "--reduced" in args
	GameManager.save_path = "user://test_launch_save.json"
	GameManager.reset_save()
	GameManager.has_started = returning
	GameManager.settings["reduced_motion"] = reduced
	GameManager.settings["light_mode"] = "--dark" not in args
	UIThemeHelper.apply_palette(tree, GameManager.settings["light_mode"])
	# El comprobador permanece en la raíz mientras las escenas reales cambian debajo de la intro.
	tree.current_scene = null
	if tree.change_scene_to_file(MainMenuUI.SCENE) != OK:
		tree.quit(1)
		return
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	var overlays := tree.root.get_children().filter(func(n): return n is LaunchOverlay)
	if overlays.size() != (0 if reduced else 1):
		push_error("Launch overlay count does not match Reduced Motion")
		tree.quit(1)
		return
	var passed := tree.current_scene is MainMenuUI if returning else tree.current_scene is BattleController
	if not reduced:
		var overlay: LaunchOverlay = overlays[0]
		overlay._tween.pause()
		if "--capture" in args:
			var prefix := "user://launch-%s" % ("dark" if "--dark" in args else "light")
			for seconds in [0.0, 0.24, 0.5, 0.72, 1.0]:
				overlay._artwork.advance(seconds)
				await RenderingServer.frame_post_draw
				passed = tree.root.get_texture().get_image().save_png(prefix + "-%.2f.png" % seconds) == OK and passed
			tree.root.size = Vector2i(960, 540)
			overlay._artwork.advance(0.72)
			await tree.process_frame
			await RenderingServer.frame_post_draw
			passed = tree.root.get_texture().get_image().save_png(prefix + "-landscape.png") == OK and passed
			overlay._artwork.advance(0.0)
		overlay._tween.play()
		await overlay.tree_exited
		await tree.process_frame
		passed = not is_instance_valid(overlay) and passed
	passed = tree.root.get_children().filter(func(n): return n is LaunchOverlay).is_empty() and passed
	passed = tree.change_scene_to_file(MainMenuUI.SCENE) == OK and passed
	await tree.process_frame
	await tree.process_frame
	passed = tree.current_scene is MainMenuUI and passed
	passed = tree.root.get_children().filter(func(n): return n is LaunchOverlay).is_empty() and passed
	for suffix in ["", ".previous"]:
		DirAccess.remove_absolute(GameManager.save_path + suffix)
	print("Launch integration %s: returning=%s reduced=%s" % ["passed" if passed else "failed", returning, reduced])
	tree.quit(0 if passed else 1)
