extends Node

## Play Store trailer rendered from the real game with Godot's Movie Maker; captions come
## from docs/store_listing/graphics.json, so --lang=xx localizes it like the screenshots.
## xvfb-run -a godot --path . --resolution 1920x1080 --write-movie build/trailer/trailer.avi \
##   --fixed-fps 30 res://scenes/tests/store_trailer.tscn [-- --lang=es]
## scripts/render_trailer.sh runs this and encodes the MP4.

const COPY := "res://docs/store_listing/graphics.json"
const ICON := "res://assets/brand/play-store-icon-512.png"
const URL := "macarronesc.github.io/invade.io/play"
const FADE := 0.35
const ORDER_EVERY := 0.9
# Each cut is a real battle driven by PlayerBot, or the real campaign menu.
const CUTS := [
	{"shot": "conquer", "level": "europe_4", "seconds": 8.0},
	{"shot": "tactics", "level": "europe_5", "seconds": 7.0},
	{"shot": "invasions", "level": "inv_iberia_3", "seconds": 7.0},
	{"shot": "daily", "level": "", "seconds": 6.0},
	{"shot": "campaign", "level": "", "seconds": 4.0},
]
const END_SECONDS := 4.0

var _lang := "en"
var _copy: Dictionary
var _cut := -1
var _elapsed := 0.0
var _order_timer := 0.0
var _scene: Node
var _battle: BattleController
var _caption: Label
var _caption_box: PanelContainer
var _fade: ColorRect
var _ending := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			_lang = arg.substr(7)
	if not LanguageCatalog.is_supported(_lang):
		push_error("Unsupported locale: " + _lang)
		get_tree().quit(1)
		return
	_copy = JSON.parse_string(FileAccess.get_file_as_string(COPY))
	GameManager.save_path = "user://trailer_save.json"
	StoreFixture.apply(_lang, get_tree())
	GameManager.sound_muted = false
	GameManager.music_muted = false
	GameManager.settings["reduced_motion"] = false
	GameManager.settings["speed"] = 1.5
	Toasts.hide() # Achievement popups would cover the captions.
	_build_overlay()
	_next_cut()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_caption_box = PanelContainer.new()
	_caption_box.add_theme_stylebox_override("panel", UIThemeHelper.box(Color(0.06, 0.1, 0.17, 0.86), 28, 28))
	_caption_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption_box.position.y = -220
	layer.add_child(_caption_box)
	_caption = Label.new()
	_caption.add_theme_font_override("font", UIThemeHelper.bold_font())
	_caption.add_theme_font_size_override("font_size", 52)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_box.add_child(_caption)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

func _process(delta: float) -> void:
	delta /= maxf(Engine.time_scale, 0.001) # The cut lengths are video seconds, not game seconds.
	_elapsed += delta
	var length: float = END_SECONDS if _ending else float(CUTS[_cut]["seconds"])
	if _battle != null and is_instance_valid(_battle) and not _battle.is_game_over:
		_order_timer -= delta
		if _order_timer <= 0.0:
			PlayerBot.order(_battle)
			_order_timer = ORDER_EVERY
	var fade_in := clampf(1.0 - _elapsed / FADE, 0.0, 1.0)
	var fade_out := clampf((_elapsed - (length - FADE)) / FADE, 0.0, 1.0)
	_fade.color.a = maxf(fade_in, fade_out)
	if _elapsed >= length:
		if _ending:
			get_tree().quit()
		else:
			_next_cut()

func _next_cut() -> void:
	_cut += 1
	_elapsed = 0.0
	_order_timer = 0.6
	_battle = null
	if is_instance_valid(_scene):
		_scene.free()
	if _cut >= CUTS.size():
		_ending = true
		_caption_box.hide()
		_scene = _end_card()
		add_child(_scene)
		return
	var cut: Dictionary = CUTS[_cut]
	_caption.text = _copy[_lang][cut["shot"]]["headline"]
	_caption_box.show()
	if cut["shot"] == "campaign":
		MainMenuUI.next_tab = "play"
		_scene = load(MainMenuUI.SCENE).instantiate()
	else:
		var level: String = cut["level"] if cut["level"] != "" else DailyRewards.challenge_id(StoreFixture.DAILY_DAY)
		GameManager.play_level(level)
		_scene = load(UIThemeHelper.BATTLE_SCENE).instantiate()
		_battle = _scene
	add_child(_scene)

func _end_card() -> Control:
	var root := ColorRect.new()
	root.color = Color("102b49")
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	root.add_child(column)
	var icon := TextureRect.new()
	icon.texture = load(ICON)
	icon.custom_minimum_size = Vector2(300, 300)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(icon)
	for line in [["invade.io", 120, Color.WHITE], [URL, 48, Color("78c6ff")]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", UIThemeHelper.bold_font())
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		column.add_child(label)
	return root
