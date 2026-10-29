extends Node

## Real game scenes → raw captures → localized Play graphics. No previous --ui run needed.
## xvfb-run -a godot --path . res://scenes/tests/store_assets.tscn
## -- --lang=en previews one locale without replacing the complete manifest.

const OUT := "res://docs/store_assets"
# shortcut: one generator per checkout; use separate workspaces for concurrent captures.
const STAGE := "res://build/store_capture"
const COPY := "res://docs/store_listing/graphics.json"
const PHONE := Vector2i(1080, 1920)
const GAME := Vector2i(1080, 1600)
const TABLET := Vector2i(1920, 1080)
const SHOTS := ["conquer", "tactics", "invasions", "campaign", "daily", "upgrades", "cosmetics", "atlas"]
const TABLET_SHOTS := ["campaign", "invasions", "cosmetics", "atlas"]
const DAILY_DAY := 20754
const SEED := 20261028
const OLD_SHOTS := ["1_menu.png", "2_invasion.png", "3_march.png", "4_victory.png", "5_army.png", "6_challenges.png", "7_progress.png"]

var _failed := false
var _copy: Dictionary
var _view: SubViewport
var _lang := "en"
var _real_save_hash := ""
var _manifest := {"version": "", "seed": SEED, "daily_day": DAILY_DAY, "locales": {}, "tablets": {}}

func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        _require(false, "Screenshots need a rendering display; use xvfb-run, not --headless")
        return
    var watchdog := get_tree().create_timer(600.0)
    watchdog.timeout.connect(func(): _require(false, "Capture did not complete within ten minutes"))
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
    var preview := false
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--lang="):
            _lang = arg.substr(7)
            if not _require(LanguageCatalog.is_supported(_lang), "Unsupported locale: " + _lang):
                return
            langs = [_lang]
            preview = true
    if not _require(LevelDatabase.get_level_ids().size() == 30 and InvasionDatabase.get_region_count() == 36
            and InvasionDatabase.get_total_fronts() == 108 and AchievementDatabase.get_all().size() == 20,
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
    if not _failed and not preview:
        _publish(langs)
    AudioManager._player.stop()
    AudioManager._music_player.stop()
    AudioManager._playback = null
    await _settle()
    print("STORE ", "FAILED" if _failed else ("PREVIEW in build/store_capture" if preview else "COMPLETE in docs/store_assets"))
    get_tree().quit(1 if _failed else 0)

func _fixture() -> void:
    seed(SEED)
    GameManager._apply_save({})
    GameManager.sound_muted = true
    GameManager.music_muted = true
    GameManager.language = _lang
    GameManager.has_started = true
    GameManager.settings.merge({"reduced_motion": true, "light_mode": true, "share_analytics": false, "share_crashes": false}, true)
    GameManager.coins = 1320
    GameManager.experience = 1600
    GameManager.upgrades = {"starting_troops": 3, "production_rate": 3, "troop_speed": 2, "gold_bonus": 1}
    for id in LevelDatabase.get_level_ids().slice(0, 12):
        GameManager.completed_levels[id] = 3
        GameManager.unlocked_levels.append(id)
        for base in LevelDatabase.get_level_definition(id)["bases"]:
            if not GameManager.conquered_cities.has(base["city"]):
                GameManager.conquered_cities.append(base["city"])
    GameManager.unlocked_levels.append("south_america_3")
    for city in ["tokyo", "seoul", "sydney", "auckland", "cairo", "nairobi"]:
        GameManager.conquered_cities.append(city)
    GameManager.invasion_stars = {"inv_iberia_1": 3, "inv_iberia_2": 3}
    GameManager.conquest_next = 7
    GameManager.stats = {"victories": 24, "bases_captured": 140, "flawless_victories": 9, "chain_max": 3}
    for id in ["color_cyan", "color_violet", "color_orange", "color_pink", "troop_big", "troop_halo", "base_square", "theme_ocean", "theme_paper"]:
        GameManager.cosmetics_owned.append(id)
    for id in ["first_victory", "conqueror", "strategist", "continental", "coordination", "flawless"]:
        GameManager.achievements[id] = GameManager.ACHIEVEMENT_CLAIMED
    GameManager.seen_tips = ["drag", "factory", "fortress", "rival_0", "rival_1", "rival_2"]
    GameManager.current_level_id = "south_america_3"
    GameManager.current_continent = "south_america"
    MainMenuUI.next_tab = "play"
    MainMenuUI.return_to_battle = false
    InvasionPage.last_continent = "europe"
    InvasionPage.last_region = "iberia"
    UIThemeHelper.apply_palette(get_tree(), true)

func _scenario(shot: String) -> String:
    return {"conquer": "europe_4", "tactics": "europe_5", "invasions": "inv_iberia_3",
        "daily": DailyRewards.challenge_id(DAILY_DAY)}.get(shot, shot)

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

func _settle() -> void:
    for frame in 5:
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
    await _settle()
    for font_size in range(74, 49, -2):
        headline.add_theme_font_size_override("font_size", font_size)
        await get_tree().process_frame
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
    await _settle()
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

func _publish(langs: Array[String]) -> void:
    # Every render/fit check finishes before touching the previous deliverables.
    for lang in langs:
        for prefix in ["screenshots_", "tablet_"]:
            _mkdir(OUT + "/" + prefix + lang)
            var ids: Array = SHOTS if prefix == "screenshots_" else TABLET_SHOTS
            for index in ids.size():
                var file := "%s%s/%d_%s.png" % [prefix, lang, index + 1, ids[index]]
                if not _copy_file(STAGE + "/" + file, OUT + "/" + file):
                    return
    if not _copy_file(STAGE + "/feature-graphic-1024x500.png", OUT + "/feature-graphic-1024x500.png"):
        return
    for lang in langs:
        for obsolete in OLD_SHOTS:
            var path: String = OUT + "/screenshots_" + lang + "/" + obsolete
            if FileAccess.file_exists(path) and not _require(DirAccess.remove_absolute(path) == OK,
                    "Retire previous gallery image: " + path):
                return
    _manifest["feature_sha256"] = FileAccess.get_sha256(OUT + "/feature-graphic-1024x500.png")
    var file := FileAccess.open(OUT + "/manifest.json.tmp", FileAccess.WRITE)
    if not _require(file != null, "Open capture manifest"):
        return
    file.store_string(JSON.stringify(_manifest, "\t") + "\n")
    file.close()
    if not _require(DirAccess.rename_absolute(OUT + "/manifest.json.tmp", OUT + "/manifest.json") == OK, "Publish manifest"):
        return

func _copy_file(source: String, target: String) -> bool:
    if not _require(DirAccess.copy_absolute(source, target + ".tmp") == OK, "Stage asset: " + target):
        return false
    return _require(DirAccess.rename_absolute(target + ".tmp", target) == OK, "Publish asset: " + target)

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
