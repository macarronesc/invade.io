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
	if "--slow-startup" in args:
		tree.node_added.connect(func(node: Node):
			if node is LaunchOverlay:
				node.ready.connect(func(): OS.delay_msec(1600), CONNECT_ONE_SHOT))
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
		if DisplayServer.get_name() == "headless":
			RenderingServer.force_draw()
			RenderingServer.force_draw()
		passed = overlay._startup_frames == 2 and passed
		overlay.set_process(false)
		var drawn_times: Array[float] = []
		if DisplayServer.get_name() != "headless":
			overlay._artwork.draw.connect(func(): drawn_times.append(overlay._artwork.elapsed))
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
		overlay._last_frame_usec = Time.get_ticks_usec()
		overlay.set_process(true)
		await overlay.tree_exited
		await tree.process_frame
		passed = not is_instance_valid(overlay) and passed
		if DisplayServer.get_name() != "headless":
			var start_visible := drawn_times.any(func(t: float): return t >= 0.0 and t < 0.2)
			var end_visible := drawn_times.any(func(t: float): return t >= 0.82 and t <= 1.05)
			if not start_visible or not end_visible:
				push_error("Intro skipped rendered stages: %s" % str(drawn_times))
			passed = start_visible and end_visible and passed
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
