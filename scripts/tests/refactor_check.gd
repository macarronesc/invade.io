extends Node

## Record on the base revision, then compare the refactor with the same engine.
## godot --headless --path . scenes/tests/refactor_check.tscn -- --record=/tmp/opencode/invade-baseline.json
## godot --headless --path . scenes/tests/refactor_check.tscn -- --compare=/tmp/opencode/invade-baseline.json

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not (args[0].begins_with("--record=") or args[0].begins_with("--compare=")):
		push_error("Use exactly one --record=<path> or --compare=<path> argument")
		get_tree().quit(2)
		return
	GameManager.save_path = "user://refactor_check_save.json"
	var signatures := _signatures()
	var failed := false
	for arg in args:
		if arg.begins_with("--record="):
			var file := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if file == null:
				push_error("Cannot write refactor baseline")
				get_tree().quit(2)
				return
			file.store_string(JSON.stringify(signatures, "\t"))
		elif arg.begins_with("--compare="):
			var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(arg.substr(10)))
			if not baseline is Dictionary:
				push_error("Invalid refactor baseline")
				get_tree().quit(2)
				return
			for key in signatures:
				if signatures[key] != baseline.get(key):
					push_error("REFACTOR mismatch: " + key)
					failed = true
	for suffix in ["", ".previous"]:
		DirAccess.remove_absolute(GameManager.save_path + suffix)
	print("REFACTOR ", "FAILED" if failed else "PASS", " (", signatures.size(), " signatures)")
	get_tree().quit(1 if failed else 0)

func _signatures() -> Dictionary:
	var out := {}
	var ids: Array = LevelDatabase.get_level_ids().duplicate()
	for region in InvasionDatabase.get_regions():
		ids.append_array(InvasionDatabase.get_region_level_ids(region["id"]))
	for day in range(20750, 20756):
		ids.append(DailyRewards.challenge_id(day))
	for index in [0, 4, 5, 9, 10, 19, 29]:
		ids.append(LevelGenerator.conquest_id(index))
	for lang in LanguageCatalog.codes():
		GameManager.language = lang
		for landscape in [false, true]:
			var levels := PackedStringArray()
			for id in ids:
				levels.append(JSON.stringify(LevelDatabase.get_level_data(id, landscape)).sha256_text())
			out["levels/%s/%s" % [lang, landscape]] = "".join(levels).sha256_text()
	var formation := PackedVector2Array()
	for packet in Troop.MAX_PACKETS:
		for dots in range(1, Troop.MAX_DOTS + 1):
			for j in dots:
				formation.append(Troop.formation_offset(j, dots, packet))
	out["formations"] = str(formation).sha256_text()
	GameManager.language = "en"
	var rewards := []
	for id in ids:
		for previous in [0, 1, 3]:
			GameManager._apply_save({})
			GameManager.upgrades["gold_bonus"] = 3
			if previous > 0:
				if InvasionDatabase.is_invasion(id):
					GameManager.invasion_stars[id] = previous
				elif DailyRewards.is_challenge(id):
					GameManager.daily["challenge_day"] = DailyRewards.challenge_day(id)
				else:
					GameManager.completed_levels[id] = previous
			var battle := BattleController.new()
			battle.level_id = id
			battle.battle_time = 30.0
			battle.target_time = 45.0
			var result := {}
			var receive := func(value: Dictionary): result.merge(value, true)
			EventBus.battle_won.connect(receive)
			battle._trigger_victory()
			EventBus.battle_won.disconnect(receive)
			rewards.append([result, GameManager.save_data()])
			battle.free()
	out["rewards"] = JSON.stringify(rewards).sha256_text()
	return out
