extends "res://scripts/tests/store_assets.gd"

## Repeatable rendered fixtures; keep captures/metrics outside tracked store artwork.
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use xvfb-run, not --headless, for performance captures")
		get_tree().quit(1)
		return
	OS.low_processor_usage_mode = false
	GameManager.sound_muted = true
	GameManager.music_muted = true
	AudioManager.stop_music()
	for task in AudioManager._music_tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)
	var output := "user://performance"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	var metrics := {}
	for shot in ["conquer", "tactics", "invasions", "campaign", "cosmetics", "atlas"]:
		_fixture()
		_new_view(GAME)
		var image := await _capture(shot)
		image.save_png(output.path_join(shot + ".png"))
		metrics[shot] = await _measure()
		_close_view()
	for style in ["troop_classic", "troop_big", "troop_halo"]:
		_fixture()
		_new_view(Vector2i(1080, 400))
		var canvas := Node2D.new()
		_view.add_child(canvas)
		canvas.draw.connect(func():
			for packet in Troop.MAX_PACKETS:
				Troop.draw_packet(canvas, Vector2(90 + packet * 125, 100), 20, Color.CORNFLOWER_BLUE, style)
				Troop.draw_packet(canvas, Vector2(90 + packet * 125, 280), 20, Color.TOMATO, style, 2.0))
		await _settle()
		_view.get_texture().get_image().save_png(output.path_join(style + ".png"))
		metrics[style] = await _measure(canvas)
		_close_view()
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "\t"))
	print("PERFORMANCE ", JSON.stringify(metrics))
	AudioManager._player.stop()
	AudioManager._music_player.stop()
	AudioManager._playback = null
	await _settle()
	get_tree().quit(1 if _failed else 0)

func _measure(redraw: CanvasItem = null) -> Dictionary:
	var calls := 0.0
	var elapsed := 0
	for frame in 30:
		if redraw:
			redraw.queue_redraw()
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		elapsed += Time.get_ticks_usec() - started
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"draw_calls": calls / 30.0, "frame_ms": elapsed / 30000.0}
