extends VBoxContainer

## Jugar: mapa del continente con la ruta de campaña, ficha del nivel elegido y accesos
## directos que empiezan la conquista libre o el desafío del día con un solo toque.

## Lienzo del mapa; se escala para caber en el alto disponible
const MAP_SIZE := Vector2(1080, 860)
const SILHOUETTE_RECT := Rect2(60, 40, 960, 780)
## Recorte amplio: el mapa se escala y centra, así la costa llega hasta los bordes de la pantalla
const SILHOUETTE_CLIP := Rect2(-600, -300, 2280, 1460)
const NODE_RECT := Rect2(110, 110, 860, 640)
const NODE_MIN_DISTANCE := 170.0
const NODE_SIZE := 104.0

## Por continente: {"geo": costas y fronteras, "nodes": posición de cada nivel sobre su región}
static var _layout_cache: Dictionary = {}

var continents: Array[Dictionary] = LevelDatabase.get_continents()
var current_continent_index := 0
var selected_level_id := ""
var marching_phase := 0.0
var pulse_time := 0.0

var continent_title: Label
var continent_progress: Label
var btn_prev_continent: Button
var btn_next_continent: Button
var route_container: Control
var levels_container: Control
var level_title: Label
var level_desc: Label
var level_rule: Label
var level_stars: Label
var level_chips: HFlowContainer
var level_medal: Label
var btn_start_level: Button
var btn_conquest: Button
var btn_daily: Button
var _silhouette: GeoSilhouette
var _node_positions := PackedVector2Array()

func _ready() -> void:
	add_theme_constant_override("separation", 0)
	for i in continents.size():
		if continents[i]["id"] == GameManager.current_continent:
			current_continent_index = i
	_build()
	_refresh_display()

func _build() -> void:
	# Selector de continente
	var header := UIThemeHelper.hbox(16)
	add_child(UIThemeHelper.page_margin(header, 0, 8))
	btn_prev_continent = UIThemeHelper.icon_button("back", LocaleStrings.text("previous"))
	btn_prev_continent.pressed.connect(_on_prev_continent)
	header.add_child(btn_prev_continent)
	var titles := UIThemeHelper.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continent_title = UIThemeHelper.label("", "Title")
	continent_progress = UIThemeHelper.label("", "Caption")
	for l in [continent_title, continent_progress]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titles.add_child(l)
	header.add_child(titles)
	btn_next_continent = UIThemeHelper.icon_button("next", LocaleStrings.text("next"))
	btn_next_continent.pressed.connect(_on_next_continent)
	header.add_child(btn_next_continent)

	# Mapa con la ruta de niveles
	var map_area := Control.new()
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.custom_minimum_size.y = 440
	map_area.clip_contents = true
	add_child(map_area)
	route_container = Control.new()
	route_container.size = MAP_SIZE
	map_area.add_child(route_container)
	map_area.resized.connect(func():
		var s := minf(map_area.size.x / MAP_SIZE.x, map_area.size.y / MAP_SIZE.y)
		route_container.scale = Vector2(s, s)
		route_container.position = (map_area.size - MAP_SIZE * s) * 0.5)
	route_container.draw.connect(_draw_route)
	_silhouette = GeoSilhouette.new()
	_silhouette.show_behind_parent = true
	_silhouette.size = MAP_SIZE
	route_container.add_child(_silhouette)
	levels_container = Control.new()
	levels_container.size = MAP_SIZE
	levels_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_container.add_child(levels_container)

	# Ficha del nivel seleccionado
	var sheet_holder := UIThemeHelper.vbox(0)
	add_child(UIThemeHelper.page_margin(sheet_holder, 0, 8))
	var sheet := UIThemeHelper.card(sheet_holder, "", 16)
	var top := UIThemeHelper.hbox(16)
	sheet.add_child(top)
	level_title = UIThemeHelper.label("", "Heading")
	level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(level_title)
	level_stars = UIThemeHelper.stars_label(0)
	top.add_child(level_stars)
	level_desc = UIThemeHelper.paragraph("")
	level_desc.max_lines_visible = 2
	sheet.add_child(level_desc)
	level_rule = UIThemeHelper.paragraph("", "Caption")
	level_rule.add_theme_color_override("font_color", UIThemeHelper.colors.gold)
	sheet.add_child(level_rule)
	level_chips = HFlowContainer.new()
	level_chips.add_theme_constant_override("h_separation", 12)
	level_chips.add_theme_constant_override("v_separation", 12)
	sheet.add_child(level_chips)
	level_medal = UIThemeHelper.label("", "Caption")
	sheet.add_child(level_medal)
	btn_start_level = UIThemeHelper.button("", "PrimaryButton", "play")
	btn_start_level.custom_minimum_size.y = 112
	# Deshabilitado mientras el nivel seleccionado siga bloqueado
	btn_start_level.pressed.connect(func(): UIThemeHelper.start_battle(self, selected_level_id))
	sheet.add_child(btn_start_level)

	# Otros modos, a un toque
	var shortcuts := UIThemeHelper.vbox(16)
	add_child(UIThemeHelper.page_margin(shortcuts, 0, 24))
	btn_conquest = UIThemeHelper.row_button("flag", LocaleStrings.text("conquest"), _conquest_subtitle(), "play")
	btn_conquest.pressed.connect(UIThemeHelper.start_battle.bind(self, LevelGenerator.conquest_id(GameManager.conquest_next)))
	shortcuts.add_child(btn_conquest)
	var done := GameManager.is_daily_challenge_done()
	var daily_sub := LocaleStrings.text("daily_row_done") if done else LocaleStrings.text("daily_row") % DailyRewards.DAILY_CHALLENGE_GOLD
	daily_sub += "\n" + LocaleStrings.text("daily_short_rules")
	btn_daily = UIThemeHelper.row_button("check" if done else "target", LocaleStrings.text("daily"), daily_sub, "play",
		UIThemeHelper.colors.success if done else UIThemeHelper.colors.gold)
	btn_daily.pressed.connect(UIThemeHelper.start_battle.bind(self, DailyRewards.challenge_id(DailyRewards.today())))
	shortcuts.add_child(btn_daily)

static func _conquest_subtitle() -> String:
	var index := GameManager.conquest_next
	var expedition := LevelGenerator.expedition_of(index)
	if LevelGenerator.is_expedition_finale(index):
		return LocaleStrings.text("conquest_row_boss") % expedition
	return LocaleStrings.text("conquest_row") % [expedition, LevelGenerator.expedition_step(index), GameManager.EXPEDITION_SIZE]

func _process(delta: float) -> void:
	if GameManager.settings["reduced_motion"]:
		return
	marching_phase = fmod(marching_phase + delta * 0.8, 1.0)
	pulse_time += delta * 3.0
	route_container.queue_redraw()

func _refresh_display() -> void:
	var cont := continents[current_continent_index]
	var level_ids := LevelDatabase.get_continent_level_ids(cont["id"])
	var earned := 0
	var completed := 0
	for lid in level_ids:
		earned += GameManager.completed_levels.get(lid, 0)
		completed += 1 if GameManager.completed_levels.has(lid) else 0
	continent_title.text = LevelDatabase.continent_name(cont["id"])
	continent_progress.text = LocaleStrings.text("continent_progress") % [completed, level_ids.size(), earned, level_ids.size() * 3]
	_apply_continent_layout(cont["id"], cont["color"])

	# Nivel propuesto: el de la campaña si está aquí; si no, el primero pendiente
	selected_level_id = level_ids[0]
	if level_ids.has(GameManager.current_level_id):
		selected_level_id = GameManager.current_level_id
	else:
		for lid in level_ids:
			if GameManager.is_level_unlocked(lid):
				selected_level_id = lid
				if not GameManager.completed_levels.has(lid):
					break

	UIThemeHelper.clear(levels_container)
	for i in level_ids.size():
		levels_container.add_child(_build_level_node(level_ids[i], i))
	_update_briefing_card()

func _build_level_node(level_id: String, index: int) -> Control:
	var holder := Control.new()
	holder.name = "NodeHolder_%d" % (index + 1)
	holder.position = _node_positions[index] - Vector2.ONE * NODE_SIZE * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := Button.new()
	btn.name = "BtnLevel_%d" % (index + 1)
	btn.size = Vector2.ONE * NODE_SIZE
	btn.add_theme_font_override("font", UIThemeHelper.bold_font())
	btn.add_theme_font_size_override("font_size", 40)
	holder.add_child(btn)
	var stars: int = GameManager.completed_levels.get(level_id, 0)
	if not GameManager.is_level_unlocked(level_id):
		btn.disabled = true
		btn.icon = Icons.texture("lock", 40)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_node(btn, UIThemeHelper.colors.surface_2, UIThemeHelper.colors.muted)
	else:
		btn.text = str(index + 1)
		# Hecho: azul. Pendiente: blanco, para que el siguiente paso destaque
		_style_node(btn, UIThemeHelper.colors.primary if stars > 0 else UIThemeHelper.colors.text, UIThemeHelper.colors.ink)
		btn.pressed.connect(_select_level.bind(level_id))
	if stars > 0:
		var star_row := UIThemeHelper.stars_label(stars, "Caption")
		if GameManager.medals.has(level_id):
			star_row.text += " 💎"
		star_row.position = Vector2(0, NODE_SIZE + 4)
		star_row.size = Vector2(NODE_SIZE, 30)
		star_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(star_row)
	if LevelDatabase.get_level_number(level_id) == LevelDatabase.LEVELS_PER_CONTINENT:
		var boss := UIThemeHelper.label("👑", "Heading")
		boss.position = Vector2(NODE_SIZE * 0.5 - 22, -48)
		holder.add_child(boss)
	return holder

func refresh_appearance() -> void:
	var selection := selected_level_id
	UIThemeHelper.clear(self)
	_build()
	_refresh_display()
	_select_level(selection)

func _style_node(btn: Button, fill: Color, ink: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := UIThemeHelper.box(fill.darkened(0.12) if state == "pressed" else fill, 999, 0)
		b.draw_center = state != "focus"
		b.set_border_width_all(4)
		b.border_color = UIThemeHelper.colors.bg if state != "focus" else UIThemeHelper.colors.gold
		btn.add_theme_stylebox_override(state, b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "icon_disabled_color"]:
		btn.add_theme_color_override(c, ink)

## Coloca cada nivel sobre su región real del continente y dibuja la silueta detrás
func _apply_continent_layout(continent_id: String, color: Color) -> void:
	if not _layout_cache.has(continent_id):
		_layout_cache[continent_id] = _build_continent_layout(continent_id)
	var layout: Dictionary = _layout_cache[continent_id]
	_node_positions = layout["nodes"]
	_silhouette.set_geography(layout["geo"], color)

static func _build_continent_layout(continent_id: String) -> Dictionary:
	var per_level: Array = []
	var all_lonlats: Array[Vector2] = []
	for level_id in LevelDatabase.get_continent_level_ids(continent_id):
		var lonlats := LevelDatabase.get_level_lonlats(level_id)
		per_level.append(lonlats)
		all_lonlats.append_array(lonlats)
	var proj := LevelGenerator.fit_projection(all_lonlats, SILHOUETTE_RECT)
	var nodes := PackedVector2Array()
	for lonlats in per_level:
		var center := Vector2.ZERO
		for ll in lonlats:
			center += proj.project(ll)
		nodes.append(center / maxf(1.0, lonlats.size()))
	nodes = LevelGenerator.separate_points(nodes, func(_i, _j): return NODE_MIN_DISTANCE, NODE_RECT)
	return {"geo": LevelGenerator.project_geography(proj, SILHOUETTE_CLIP), "nodes": nodes}

func _select_level(level_id: String) -> void:
	AudioManager.play_click()
	selected_level_id = level_id
	_update_briefing_card()

func _update_briefing_card() -> void:
	var data := LevelDatabase.get_level_data(selected_level_id)
	var unlocked := GameManager.is_level_unlocked(selected_level_id)
	var stars: int = GameManager.completed_levels.get(selected_level_id, 0)
	level_title.text = data["name"]
	level_desc.text = data["description"]
	if selected_level_id == "europe_4":
		level_desc.text = LocaleStrings.text("hint_factory")
	level_rule.text = CampaignRules.description(data).strip_edges()
	if LevelDatabase.get_level_number(selected_level_id) == LevelDatabase.LEVELS_PER_CONTINENT:
		var reward := CosmeticsDatabase.continent_reward(LevelDatabase.get_continent_of(selected_level_id))
		level_rule.text += "\n" + LocaleStrings.text("boss_reward") % CosmeticsDatabase.item_name(reward)
		if stars == 0:
			level_rule.text += " · " + LocaleStrings.text("boss_gold_preview") % roundi(GameManager.FIRST_BOSS_GOLD * GameManager.get_gold_multiplier())
	level_rule.visible = level_rule.text != ""
	UIThemeHelper.set_stars(level_stars, stars)

	var bases: Array = data.get("bases", [])
	var rivals := {}
	for b in bases:
		if b["faction"] not in [GameManager.Faction.PLAYER, GameManager.Faction.NEUTRAL]:
			rivals[b["faction"]] = true
	UIThemeHelper.clear(level_chips)
	level_chips.add_child(UIThemeHelper.chip(LocaleStrings.text("bases") % bases.size(), "flag", UIThemeHelper.colors.muted))
	level_chips.add_child(UIThemeHelper.chip(LocaleStrings.text("rival" if rivals.size() == 1 else "rivals") % rivals.size(), "shield", UIThemeHelper.colors.danger))
	level_chips.add_child(UIThemeHelper.chip(LocaleStrings.text("target_time") % data.get("target_time", 45), "clock", UIThemeHelper.colors.gold))
	# Motivos para jugar (o repetir) este nivel: ciudades aún no coleccionadas y la medalla
	var new_cities := bases.filter(func(b): return GeoDatabase.has_city(b.get("city", "")) and not GameManager.conquered_cities.has(b["city"])).size()
	if new_cities > 0:
		level_chips.add_child(UIThemeHelper.chip(LocaleStrings.text("new_cities_chip") % new_cities, "globe", UIThemeHelper.colors.primary))
	level_medal.text = LocaleStrings.text("medal_won") if GameManager.medals.has(selected_level_id) else LocaleStrings.text("medal_todo")
	level_medal.add_theme_color_override("font_color", UIThemeHelper.colors.gold if GameManager.medals.has(selected_level_id) else UIThemeHelper.colors.muted)

	btn_start_level.disabled = not unlocked
	btn_start_level.icon = Icons.texture("play" if unlocked else "lock", 44)
	var number := LevelDatabase.get_level_number(selected_level_id)
	if not unlocked:
		btn_start_level.text = LocaleStrings.text("level_locked")
	elif selected_level_id == GameManager.current_level_id and stars == 0:
		btn_start_level.text = LocaleStrings.text("continue")
	else:
		btn_start_level.text = LocaleStrings.text("replay_level" if stars > 0 else "play_level") % number
	route_container.queue_redraw()

func _draw_route() -> void:
	var cont := continents[current_continent_index]
	var level_ids := LevelDatabase.get_continent_level_ids(cont["id"])
	for i in level_ids.size() - 1:
		var p1 := _node_positions[i]
		var p2 := _node_positions[i + 1]
		if GameManager.is_level_unlocked(level_ids[i + 1]):
			route_container.draw_line(p1, p2, Color(UIThemeHelper.colors.primary, 0.85), 6.0, true)
		elif GameManager.is_level_unlocked(level_ids[i]):
			# Frontera: el siguiente tramo por conquistar
			route_container.draw_dashed_line(p1, p2, Color(UIThemeHelper.colors.text, 0.45), 4.0, 12.0)
			route_container.draw_circle(p1.lerp(p2, marching_phase), 7.0, UIThemeHelper.colors.gold)
		else:
			route_container.draw_dashed_line(p1, p2, UIThemeHelper.colors.line, 3.0, 12.0)
	var selected := level_ids.find(selected_level_id)
	if selected >= 0:
		var r := NODE_SIZE * 0.5 + 14.0 + sin(pulse_time) * 3.0
		route_container.draw_circle(_node_positions[selected], r, Color(UIThemeHelper.colors.gold, 0.14))
		route_container.draw_arc(_node_positions[selected], r, 0, TAU, 48, UIThemeHelper.colors.gold, 4.0, true)

func _on_prev_continent() -> void:
	_change_continent(-1)

func _on_next_continent() -> void:
	_change_continent(1)

func _change_continent(step: int) -> void:
	AudioManager.play_click()
	current_continent_index = posmod(current_continent_index + step, continents.size())
	GameManager.current_continent = continents[current_continent_index]["id"]
	GameManager.save_game()
	_refresh_display()
