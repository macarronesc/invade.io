extends Node

## Real game scenes → raw captures → localized Play graphics. No previous --ui run needed.
## xvfb-run -a godot --path . res://scenes/tests/store_assets.tscn [-- --lang=pl,th]
## Renders into build/store_capture/ and writes its manifest.json; nothing tracked changes.
## python3 tools/build_store_listings.py --publish then validates and publishes the images.

# shortcut: one generator per checkout; use separate workspaces for concurrent captures.
const STAGE := "res://build/store_capture"
const COPY := "res://docs/store_listing/graphics.json"
const PHONE := Vector2i(1080, 1920)
const GAME := Vector2i(1080, 1600)
const TABLET := Vector2i(1920, 1080)
const SECONDS_PER_LANGUAGE := 150.0 # measured ~40 s with software rendering; keep a wide margin
const SHOTS := ["conquer", "tactics", "invasions", "campaign", "daily", "upgrades", "cosmetics", "atlas"]
const TABLET_SHOTS := ["campaign", "invasions", "cosmetics", "atlas"]

var _failed := false
var _copy: Dictionary
var _view: SubViewport
var _lang := "en"
var _real_save_hash := ""
var _manifest := {"version": "", "seed": StoreFixture.SEED, "daily_day": StoreFixture.DAILY_DAY, "locales": {}, "tablets": {}}

func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        _require(false, "Screenshots need a rendering display; use xvfb-run, not --headless")
        return
    OS.low_processor_usage_mode = false
    _real_save_hash = FileAccess.get_sha256("user://invade_save.json") if FileAccess.file_exists("user://invade_save.json") else ""
    GameManager.save_path = "user://store_capture_save.json"
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(COPY))
    if not _require(parsed is Dictionary, "Graphics copy must be a JSON object"):
        return
    _copy = parsed
    _manifest["version"] = str(ProjectSettings.get_setting("application/config/version"))
    var commit: Array = []
    OS.execute("git", ["rev-parse", "HEAD"], commit)
    _manifest["commit"] = "".join(commit).strip_edges()
    var status: Array = []
    OS.execute("git", ["status", "--porcelain"], status)
    _manifest["working_tree_dirty"] = not "".join(status).strip_edges().is_empty()
    _manifest["godot"] = Engine.get_version_info()["string"]
    var langs := LanguageCatalog.codes()
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--lang="):
            langs.clear()
            for code in arg.substr(7).split(",", false):
                if not _require(LanguageCatalog.is_supported(code), "Unsupported locale: " + code):
                    return
                langs.append(code)
    var watchdog := get_tree().create_timer(60.0 + SECONDS_PER_LANGUAGE * langs.size())
    watchdog.timeout.connect(func(): _require(false, "Capture exceeded its time budget"))
    if not _require(LevelDatabase.get_level_ids().size() == 30 and InvasionDatabase.get_region_count() == 59
            and InvasionDatabase.get_total_fronts() == 177 and AchievementDatabase.get_all().size() == 23,
            "Update store counts when game content changes"):
        return
    for lang in langs:
        _lang = lang
        if not _validate_copy():
            return
        _mkdir(STAGE + "/raw/" + lang)
        _mkdir(STAGE + "/screenshots_" + lang)
        _mkdir(STAGE + "/tablet_" + lang)
        _manifest["locales"][lang] = []
        _manifest["tablets"][lang] = []
        for index in SHOTS.size():
            _fixture()
            _new_view(GAME)
            var raw := await _capture(SHOTS[index])
            if _failed:
                return
            _save(raw, "%s/raw/%s/%s.png" % [STAGE, lang, SHOTS[index]])
            var composed := await _compose(raw, _copy[lang][SHOTS[index]], index)
            var file := "%d_%s.png" % [index + 1, SHOTS[index]]
            var path := "%s/screenshots_%s/%s" % [STAGE, lang, file]
            _save(composed, path)
            var entry: Dictionary = _copy[lang][SHOTS[index]].duplicate()
            entry.merge({"file": file, "sha256": FileAccess.get_sha256(path), "scenario": _scenario(SHOTS[index]),
                "raw": "build/store_capture/raw/%s/%s.png" % [lang, SHOTS[index]], "raw_size": [GAME.x, GAME.y]})
            _manifest["locales"][lang].append(entry)
            _close_view()
        for index in TABLET_SHOTS.size():
            _fixture()
            _new_view(TABLET)
            var raw := await _capture(TABLET_SHOTS[index])
            var file := "%d_%s.png" % [index + 1, TABLET_SHOTS[index]]
            var path := "%s/tablet_%s/%s" % [STAGE, lang, file]
            _save(raw, path)
            _manifest["tablets"][lang].append({"file": file, "sha256": FileAccess.get_sha256(path),
                "alt": _copy[lang][TABLET_SHOTS[index]]["alt"]})
            _close_view()
        await _contact_sheet(lang)
        print("STORE locale complete: ", lang)
    _lang = "en"
    _fixture()
    _new_view(TABLET)
    var hero := await _capture("invasions")
    await _feature_graphic(hero)
    _close_view()
    _require(_real_save_hash == (FileAccess.get_sha256("user://invade_save.json") if FileAccess.file_exists("user://invade_save.json") else ""),
        "Capture must not modify the real player save")
    if not _failed:
        _write_stage_manifest()
    AudioManager._player.stop()
    AudioManager._music_player.stop()
    AudioManager._playback = null
    await _settle()
    print("STORE ", "FAILED" if _failed else "COMPLETE in build/store_capture")
    get_tree().quit(1 if _failed else 0)

func _fixture() -> void:
    StoreFixture.apply(_lang, get_tree())

func _scenario(shot: String) -> String:
    return {"conquer": "europe_4", "tactics": "europe_5", "invasions": "inv_iberia_3",
        "daily": DailyRewards.challenge_id(StoreFixture.DAILY_DAY)}.get(shot, shot)

func _new_view(dimensions: Vector2i) -> void:
    _view = SubViewport.new()
    _view.size = dimensions
    _view.world_2d = World2D.new()
    _view.transparent_bg = false
    _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_view)

func _close_view() -> void:
    if is_instance_valid(_view):
        _view.free()
    UIThemeHelper.clear(Toasts)

func _capture(shot: String) -> Image:
    if shot in ["conquer", "tactics", "invasions", "daily"]:
        GameManager.play_level(_scenario(shot))
        var battle: BattleController = load(UIThemeHelper.BATTLE_SCENE).instantiate()
        _view.add_child(battle)
        battle.set_process(false)
        for base in battle.bases:
            base.set_process(false)
        for ai in battle.ai_controllers:
            ai.set_process(false)
        # Fixed, real production/AI steps; never inflate armies or paint fake troop streams.
        for step in 160:
            for base in battle.bases:
                base._process(0.05)
            for ai in battle.ai_controllers:
                ai._process(0.05)
            battle._process(0.05)
        var homes := battle.bases.filter(func(b): return b.faction == GameManager.Faction.PLAYER)
        if not _require(not homes.is_empty(), "Scenario has a player base: " + shot):
            return Image.new()
        var home: BaseNode = homes[0]
        var targets := battle.bases.filter(func(b): return b != home and battle.can_dispatch(home, b))
        if not _require(not targets.is_empty(), "Scenario has a legal target: " + shot):
            return Image.new()
        var target: BaseNode = targets[0]
        for candidate in targets:
            if candidate.city_key == {"conquer": "istanbul", "tactics": "berlin", "invasions": "madrid"}.get(shot, ""):
                target = candidate
        if not _require(battle.dispatch_troops(home, target), "Real troop dispatch succeeds: " + shot):
            return Image.new()
        var stream: Troop = battle.active_troops[-1]
        var frames := maxi(1, floori(stream.arrival_dist / stream.speed * 0.68 / 0.05))
        for step in frames:
            battle._process(0.05)
        battle.set_simulation_paused(true)
        _require(not battle.is_game_over and not battle.active_troops.is_empty(), "Capture shows a live battle: " + shot)
    else:
        if shot == "cosmetics":
            GameManager.settings["light_mode"] = false
            UIThemeHelper.apply_palette(get_tree(), false)
        var menu: MainMenuUI = load(MainMenuUI.SCENE).instantiate()
        _view.add_child(menu)
        if shot in ["upgrades", "cosmetics"]:
            menu.show_tab("army")
            if shot == "cosmetics":
                var button := menu.find_child("Segment_looks", true, false) as Button
                button.pressed.emit()
                await _settle()
                _scroll_to_label(menu._content.get_child(0) as ScrollPage, "cat_troop_style")
        elif shot == "atlas":
            menu.show_tab("progress")
            await _settle()
            var page := menu._content.get_child(0) as ScrollPage
            _scroll_to_label(page, "atlas")
        else:
            _require(shot == "campaign", "Known menu scenario: " + shot)
    await _settle()
    var image := _view.get_texture().get_image()
    if not _has_detail(image):
        image.save_png(STAGE + "/debug_" + shot + ".png")
    _require(_has_detail(image), "Rendered scene is not blank: " + shot)
    return image

func _scroll_to_label(page: ScrollPage, key: String) -> void:
    var target: Label
    for label in page.content.find_children("*", "Label", true, false):
        if label.text == LocaleStrings.text(key):
            # A translated tab title can equal a category title; the feature comes later.
            target = label
    if not _require(target != null, "Missing feature heading: " + key):
        return
    page.scroll_vertical = int(target.global_position.y - page.content.global_position.y) - 16
    _require(page.scroll_vertical > 0, "Scroll reaches the requested feature: " + key)

func _settle(frames := 5) -> void:
    for frame in frames:
        await get_tree().process_frame
    await RenderingServer.frame_post_draw

func _validate_copy() -> bool:
    if not _require(_copy.has(_lang), "Missing graphics locale: " + _lang):
        return false
    for shot in SHOTS:
        if not _require(_copy[_lang].has(shot), "Missing caption: " + shot):
            return false
        for key in ["headline", "subtitle", "alt"]:
            if not _require(not str(_copy[_lang][shot].get(key, "")).is_empty(), "Missing " + key):
                return false
        GameManager.language = _lang
        var font := UIThemeHelper.bold_font()
        for text in [_copy[_lang][shot]["headline"], _copy[_lang][shot]["subtitle"]]:
            for index in text.length():
                var code: int = text.unicode_at(index)
                if code > 127 and code not in [0x200C, 0x200D, 0x200E, 0x200F]:
                    if not _require(font.has_char(code), "Missing glyph U+%04X in %s" % [code, _lang]):
                        return false
    return true

func _compose(raw: Image, text: Dictionary, index: int) -> Image:
    var viewport := SubViewport.new()
    viewport.size = PHONE
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var root := Control.new()
    # Only the caption text is RTL; the manually positioned artwork must stay LTR.
    root.layout_direction = Control.LAYOUT_DIRECTION_LTR
    root.size = Vector2(PHONE)
    viewport.add_child(root)
    var bg := ColorRect.new()
    bg.layout_direction = Control.LAYOUT_DIRECTION_LTR
    bg.color = Color("102b49")
    bg.size = Vector2(PHONE)
    root.add_child(bg)
    var image := TextureRect.new()
    image.layout_direction = Control.LAYOUT_DIRECTION_LTR
    image.texture = ImageTexture.create_from_image(raw)
    image.position = Vector2(0, 320)
    image.size = Vector2(GAME)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    root.add_child(image)
    var brand := _label("invade.io", 28, Color("78c6ff"), Rect2(56, 20, 440, 42))
    brand.layout_direction = Control.LAYOUT_DIRECTION_LTR
    root.add_child(brand)
    var number := _label("%02d / 08" % (index + 1), 24, Color("b8d5ef"), Rect2(840, 24, 184, 38))
    number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    root.add_child(number)
    var headline := _label(text["headline"], 74, Color.WHITE, Rect2(56, 76, 968, 170))
    headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(headline)
    var subtitle := _label(text["subtitle"], 32, Color("c6dff3"), Rect2(56, 252, 968, 56))
    root.add_child(subtitle)
    if LanguageCatalog.is_rtl(_lang):
        for label in [headline, subtitle]:
            label.text_direction = Control.TEXT_DIRECTION_RTL
            label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    await _settle(2)
    for font_size in range(74, 49, -2):
        headline.add_theme_font_size_override("font_size", font_size)
        if headline.get_line_count() <= 2 and headline.get_minimum_size().y <= 170:
            break
    _require(headline.get_line_count() <= 2 and headline.get_minimum_size().y <= 170,
        "Headline fits: %s (%d lines, %s, font %d)" % [text["headline"], headline.get_line_count(),
            str(headline.get_minimum_size()), headline.get_theme_font_size("font_size")])
    headline.size = Vector2(968, 170)
    var subtitle_font := UIThemeHelper.regular_font()
    subtitle.add_theme_font_override("font", subtitle_font)
    for font_size in range(32, 23, -1):
        subtitle.add_theme_font_size_override("font_size", font_size)
        if subtitle_font.get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= 968:
            break
    _require(subtitle.get_minimum_size().x <= 968, "Subtitle fits: " + subtitle.text)
    subtitle.size = Vector2(968, 56)
    await _settle(2)
    var band := Rect2(0, 0, 1080, 320)
    _require(bg.get_global_rect() == Rect2(Vector2.ZERO, Vector2(PHONE)), "Artwork background stays on canvas")
    _require(band.encloses(headline.get_global_rect()) and band.encloses(subtitle.get_global_rect()),
        "Caption frames stay inside the header: " + _lang)
    var output := viewport.get_texture().get_image()
    viewport.free()
    return output

func _label(text: String, font_size: int, color: Color, rect: Rect2) -> Label:
    var label := Label.new()
    label.layout_direction = Control.LAYOUT_DIRECTION_LTR
    label.text_direction = Control.TEXT_DIRECTION_LTR
    label.text = text
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_override("font", UIThemeHelper.bold_font())
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label

func _feature_graphic(raw: Image) -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1024, 500)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)
    var art := TextureRect.new()
    art.texture = ImageTexture.create_from_image(raw.get_region(Rect2i(110, 250, 1700, 830)))
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.size = Vector2(1024, 500)
    viewport.add_child(art)
    var gradient := Gradient.new()
    gradient.set_color(0, Color("102b49"))
    gradient.set_color(1, Color(0.06, 0.17, 0.29, 0.0))
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = Vector2.ZERO
    texture.fill_to = Vector2(0.75, 0)
    var veil := TextureRect.new()
    veil.texture = texture
    veil.size = Vector2(1024, 500)
    viewport.add_child(veil)
    var name := _label("invade.io", 80, Color.WHITE, Rect2(72, 66, 540, 120))
    viewport.add_child(name)
    await _settle()
    _save(viewport.get_texture().get_image(), STAGE + "/feature-graphic-1024x500.png")
    viewport.free()

func _contact_sheet(lang: String) -> void:
    var sheet := Image.create_empty(1080, 960, false, Image.FORMAT_RGB8)
    for index in SHOTS.size():
        var shot := Image.load_from_file("%s/screenshots_%s/%d_%s.png" % [STAGE, lang, index + 1, SHOTS[index]])
        shot.resize(270, 480, Image.INTERPOLATE_LANCZOS)
        sheet.blit_rect(shot, Rect2i(0, 0, 270, 480), Vector2i(index % 4 * 270, index / 4 * 480))
    _save(sheet, STAGE + "/contact_" + lang + ".png")

func _write_stage_manifest() -> void:
    _manifest["feature_sha256"] = FileAccess.get_sha256(STAGE + "/feature-graphic-1024x500.png")
    var file := FileAccess.open(STAGE + "/manifest.json", FileAccess.WRITE)
    if _require(file != null, "Open stage manifest"):
        file.store_string(JSON.stringify(_manifest, "\t") + "\n")

func _save(image: Image, path: String) -> void:
    if not image.is_empty() and not _has_detail(image):
        image.save_png(STAGE + "/debug_output.png")
    if not _require(not image.is_empty() and _has_detail(image), "Nonblank output: " + path):
        return
    image.convert(Image.FORMAT_RGB8)
    _require(image.save_png(path) == OK, "Save image: " + path)

func _has_detail(image: Image) -> bool:
    if image.is_empty():
        return false
    var colors := {}
    for x in range(0, image.get_width(), 37):
        for y in range(0, image.get_height(), 41):
            colors[image.get_pixel(x, y).to_html(false)] = true
    return colors.size() > 16

func _mkdir(path: String) -> void:
    _require(DirAccess.make_dir_recursive_absolute(path) == OK, "Create output directory: " + path)

func _require(condition: bool, message: String) -> bool:
    if not condition:
        _failed = true
        push_error("STORE: " + message)
        get_tree().quit(1)
    return condition
