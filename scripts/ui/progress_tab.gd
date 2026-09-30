extends ScrollPage

## Progreso: nivel de jugador, resumen, atlas de ciudades conquistadas y logros.

const ATLAS_SIZE := Vector2(920, 350)
## Latitudes visibles del atlas (se omiten los polos)
const ATLAS_LAT := Vector2(-58.0, 78.0)

static var _world_geo: Dictionary = {}

var achievements_box: VBoxContainer
var achievements_count: Label

func _build() -> void:
	UIThemeHelper.section(content, LocaleStrings.text("tab_progress"))
	_build_player_level()
	_build_summary()
	_build_atlas()
	_build_achievements()

func _build_player_level() -> void:
	var xp := GameManager.experience
	var level := DailyMissions.player_level(xp)
	var start := DailyMissions.level_start(level)
	var span := DailyMissions.level_start(level + 1) - start
	var card := UIThemeHelper.card(content)
	var badge := UIThemeHelper.round_badge(UIThemeHelper.label(str(level), "Title", UIThemeHelper.COLOR_GOLD), UIThemeHelper.COLOR_GOLD, 120)
	card.add_child(UIThemeHelper.item_row(badge, LocaleStrings.text("player_level") % level, LocaleStrings.text("player_xp_note") % [xp - start, span]))
	card.add_child(UIThemeHelper.progress(xp - start, span, "GoldBar"))

func _build_summary() -> void:
	var all := AchievementDatabase.get_all()
	var unlocked := _unlocked_count()
	var row := UIThemeHelper.hbox(16)
	for stat in [
		["star", "%d/%d" % [GameManager.get_total_stars(), GameManager.get_max_possible_stars()], "stat_stars", UIThemeHelper.COLOR_GOLD],
		["globe", "%d/%d" % [GameManager.atlas_conquered_count(), GameManager.atlas_total_count()], "stat_cities", UIThemeHelper.COLOR_PRIMARY],
		["trophy", "%d/%d" % [unlocked, all.size()], "stat_achievements", UIThemeHelper.COLOR_GOLD],
	]:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tile := UIThemeHelper.vbox(6)
		panel.add_child(tile)
		tile.add_child(Icons.rect(stat[0], 44, stat[3]))
		var value := UIThemeHelper.label(stat[1], "Heading")
		value.name = "Stat_" + stat[2]
		tile.add_child(value)
		tile.add_child(UIThemeHelper.label(LocaleStrings.text(stat[2]), "Caption"))
		for c in tile.get_children():
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(panel)
	content.add_child(row)

## Atlas: mapa del mundo con las ciudades conquistadas, recuento por continente y últimas conquistas
func _build_atlas() -> void:
	var conquered := GameManager.conquered_cities
	UIThemeHelper.section(content, LocaleStrings.text("atlas"), LocaleStrings.text("atlas_sub"), "Heading")
	var card := UIThemeHelper.card(content)
	var center := CenterContainer.new()
	card.add_child(center)
	var map := GeoSilhouette.new()
	map.custom_minimum_size = ATLAS_SIZE
	map.clip_contents = true
	map.set_geography(_world_geography(), UIThemeHelper.COLOR_MUTED)
	center.add_child(map)
	var dots := AtlasDots.new()
	dots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var per_continent := {}
	for key in conquered:
		var lonlat: Vector2 = GeoDatabase.get_city(key).get("lonlat", Vector2.ZERO)
		dots.points.append(_project(lonlat))
		var cont := GeoDatabase.continent_of(lonlat)
		per_continent[cont] = per_continent.get(cont, 0) + 1
	map.add_child(dots)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for cont in LevelDatabase.get_continents():
		var count: int = per_continent.get(cont["id"], 0)
		var chip := UIThemeHelper.chip("%s  %d" % [LevelDatabase.continent_name(cont["id"]), count], "", UIThemeHelper.COLOR_TEXT if count > 0 else UIThemeHelper.COLOR_MUTED)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(chip)
	card.add_child(grid)
	if conquered.is_empty():
		card.add_child(UIThemeHelper.paragraph(LocaleStrings.text("atlas_empty")))
	else:
		var recent: Array[String] = []
		for i in range(conquered.size() - 1, maxi(-1, conquered.size() - 6), -1):
			recent.append(GeoDatabase.city_name(GeoDatabase.get_city(conquered[i])))
		card.add_child(UIThemeHelper.paragraph(LocaleStrings.text("atlas_recent") % " · ".join(recent), ""))

static func _project(lonlat: Vector2) -> Vector2:
	return Vector2((lonlat.x + 180.0) / 360.0 * ATLAS_SIZE.x, (ATLAS_LAT.y - lonlat.y) / (ATLAS_LAT.y - ATLAS_LAT.x) * ATLAS_SIZE.y)

## Costas del mundo proyectadas una sola vez (equirrectangular)
static func _world_geography() -> Dictionary:
	if _world_geo.is_empty():
		var land: Array[PackedVector2Array] = []
		for poly in GeoDatabase.get_land():
			var projected := PackedVector2Array()
			for p in poly:
				projected.append(_project(p))
			if GeoDatabase.bounds_of(projected).get_area() > 4.0:
				land.append(projected)
		_world_geo = {"land": land, "borders": []}
	return _world_geo

func _build_achievements() -> void:
	var all := AchievementDatabase.get_all()
	var unlocked := _unlocked_count()
	var head := UIThemeHelper.hbox(16)
	var title := UIThemeHelper.label(LocaleStrings.text("achievements"), "Heading")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	achievements_count = UIThemeHelper.label("%d/%d" % [unlocked, all.size()], "Heading", UIThemeHelper.COLOR_GOLD)
	head.add_child(achievements_count)
	content.add_child(head)
	achievements_box = UIThemeHelper.vbox(16)
	# Primero lo que se puede reclamar, después lo que está en curso y al final lo cobrado
	for rank in 3:
		for a in all:
			if _rank(a) == rank:
				achievements_box.add_child(_achievement_card(a))
	content.add_child(achievements_box)

static func _unlocked_count() -> int:
	return AchievementDatabase.get_all().filter(func(a): return GameManager.is_achievement_unlocked(a["id"])).size()

static func _rank(a: Dictionary) -> int:
	if GameManager.is_achievement_claimed(a["id"]):
		return 2
	return 0 if GameManager.is_achievement_unlocked(a["id"]) else 1

func _achievement_card(a: Dictionary) -> PanelContainer:
	var unlocked := GameManager.is_achievement_unlocked(a["id"])
	var claimed := GameManager.is_achievement_claimed(a["id"])
	var trailing: Control
	if claimed:
		trailing = Icons.rect("check", 48, UIThemeHelper.COLOR_SUCCESS)
	elif unlocked:
		trailing = UIThemeHelper.button("+%d" % a["reward"], "GoldButton", "coin")
		trailing.name = "BtnClaim"
		trailing.pressed.connect(_on_claim_pressed.bind(a["id"]))
	else:
		trailing = UIThemeHelper.chip("+%d" % a["reward"], "coin", UIThemeHelper.COLOR_MUTED)
	var icon := UIThemeHelper.label(a["icon"], "Title")
	icon.modulate.a = 1.0 if unlocked else 0.35
	var card := PanelContainer.new()
	card.name = "Card_%s" % a["id"]
	var column := UIThemeHelper.vbox(16)
	card.add_child(column)
	column.add_child(UIThemeHelper.item_row(icon, AchievementDatabase.achievement_title(a), AchievementDatabase.achievement_desc(a), trailing))
	if not unlocked:
		var bar := UIThemeHelper.hbox(12)
		bar.add_child(UIThemeHelper.progress(AchievementManager.get_progress(a), 1.0))
		bar.add_child(UIThemeHelper.label("%d/%d" % [mini(AchievementManager.get_stat(a["stat"]), a["goal"]), a["goal"]], "Caption"))
		column.add_child(bar)
	return card

## Reclamar suma oro: coins_updated vuelve a construir la página con el logro ya cobrado
func _on_claim_pressed(id: String) -> void:
	if GameManager.claim_achievement(id) > 0:
		AudioManager.play_star_reveal(2)
		GameManager.haptic(30)

class AtlasDots extends Control:
	var points := PackedVector2Array()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for p in points:
			draw_circle(p, 10.0, Color(UIThemeHelper.COLOR_PRIMARY, 0.25))
			draw_circle(p, 5.0, UIThemeHelper.COLOR_PRIMARY)
