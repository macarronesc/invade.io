extends SceneTree

## Renders the procedural music loops into assets/audio/music for the browser demo export.
## Usage: godot --headless --path . --script tools/render_web_music.gd

func _init() -> void:
	var failed := false
	for track in MusicSynth.TRACKS:
		var error := MusicSynth.save_bundled_track(track)
		print("%s -> %s (%s)" % [track, MusicSynth.bundled_path(track), error_string(error)])
		failed = failed or error != OK
	quit(1 if failed else 0)
