extends ScrollPage
class_name InvasionPage

## Invasiones: mapa del continente, regiones reales y tres frentes por región.
## El mapa es decorativo y seleccionable; las fichas de región funcionan también como
## selector accesible cuando los pines quedan juntos en una isla o una costa.

const MAP_SIZE := Vector2(920, 360)
const SILHOUETTE_RECT := Rect2(20, 8, 880, 344)
const SILHOUETTE_CLIP := Rect2(-240, -100, 1400, 560)
const NODE_RECT := Rect2(60, 34, 800, 292)
const NODE_MIN_DISTANCE := 100.0
const NODE_SIZE := 60.0

static var last_continent := ""
static var last_region := ""
static var _layout_cache: Dictionary = {}

var selected_continent := ""
var selected_region := ""
var continent_buttons: Dictionary = {}
var region_buttons: Dictionary = {}
var front_buttons: Dictionary = {}
var progress_label: Label
var detail_card: VBoxContainer
var map_container: Control
var _map_overlay: Control
var _map_region_ids: Array[String] = []
var _map_layout: Dictionary = {}
var pulse_time := 0.0
var _redraw_accum := 0.0

func _build() -> void:
	_ensure_selection()
	continent_buttons.clear()
	region_buttons.clear()
	front_buttons.clear()
	UIThemeHelper.section(content, LocaleStrings.text("tab_invasion"), LocaleStrings.text("invasions_sub"))

	var progress := GameManager.invasion_progress()
	var progress_card := UIThemeHelper.card(content, "CompactCard", 12)
	progress_label = UIThemeHelper.label(LocaleStrings.text("invasions_progress") % [
		progress["regions"], progress["regions_total"], progress["fronts"], progress["fronts_total"]], "Heading")
	progress_label.name = "InvasionProgress"
	progress_card.add_child(progress_label)
	progress_card.add_child(UIThemeHelper.progress(int(progress["regions"]), int(progress["regions_total"])))
	progress_card.add_child(UIThemeHelper.label(LocaleStrings.text("invasions_world") % _world_percent(progress), "Caption", UIThemeHelper.colors.gold))

	_build_continent_selector()
	var continent := selected_continent if selected_continent != "" else "europe"
	if not GameManager.is_continent_complete(continent):
		_build_locked_card(continent)
		return

	_build_map(continent)
	_build_region_selector(continent)
	_build_detail(continent)

func _ensure_selection() -> void:
	if selected_continent == "" or not _has_continent(selected_continent):
		selected_continent = last_continent if _has_continent(last_continent) else _default_continent()
	if not _has_continent(selected_continent):
		selected_continent = _default_continent()
	var region_ids := _region_ids(selected_continent)
	if selected_region == "" or not region_ids.has(selected_region):
		selected_region = last_region if region_ids.has(last_region) else _default_region(selected_continent)
	last_continent = selected_continent
	last_region = selected_region

func _has_continent(continent_id: String) -> bool:
	return LevelDatabase.get_continents().any(func(c): return c["id"] == continent_id)

func _default_continent() -> String:
	for continent in LevelDatabase.get_continents():
		if GameManager.is_continent_complete(continent["id"]) and not GameManager.all_regions_complete(continent["id"]):
			return continent["id"]
	for continent in LevelDatabase.get_continents():
		if GameManager.is_continent_complete(continent["id"]):
			return continent["id"]
	return "europe"

func _default_region(continent_id: String) -> String:
	var ids := _region_ids(continent_id)
	for region_id in ids:
		if not GameManager.is_region_complete(region_id):
			return region_id
	return ids[0] if not ids.is_empty() else ""

func _world_percent(progress: Dictionary) -> int:
	var total := int(progress.get("regions_total", 0))
	return roundi(100.0 * int(progress.get("regions", 0)) / total) if total > 0 else 0

func _region_ids(continent_id: String) -> Array[String]:
	var ids: Array[String] = []
	for region in InvasionDatabase.get_regions_by_continent(continent_id):
		ids.append(str(region["id"]))
	return ids

func _build_continent_selector() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	content.add_child(flow)
	var group := ButtonGroup.new()
	for continent in LevelDatabase.get_continents():
		var btn := UIThemeHelper.button(LevelDatabase.continent_name(continent["id"]), "SegmentButton")
		btn.name = "BtnInvasionContinent_" + str(continent["id"])
		btn.toggle_mode = true
		btn.button_group = group
		btn.set_pressed_no_signal(continent["id"] == selected_continent)
		if not GameManager.is_continent_complete(continent["id"]):
			btn.icon = Icons.texture("lock", 28)
		btn.pressed.connect(_select_continent.bind(continent["id"]))
		flow.add_child(btn)
		continent_buttons[continent["id"]] = btn

func _build_locked_card(continent_id: String) -> void:
	var regions := InvasionDatabase.get_regions_by_continent(continent_id)
	var level_ids := LevelDatabase.get_continent_level_ids(continent_id)
	var completed := level_ids.filter(func(id): return GameManager.completed_levels.has(id)).size()
	var card := UIThemeHelper.card(content)
	card.name = "InvasionLockedCard"
	card.add_child(UIThemeHelper.label(LocaleStrings.text("invasion_locked_title"), "Title"))
	card.add_child(UIThemeHelper.paragraph(LocaleStrings.text("invasion_locked_desc") % [
		LevelDatabase.continent_name(continent_id), regions.size()], ""))
	card.add_child(UIThemeHelper.label(LocaleStrings.text("invasion_locked_progress") % [completed, level_ids.size()], "Caption"))
	card.add_child(UIThemeHelper.progress(completed, level_ids.size()))
	var go := UIThemeHelper.button(LocaleStrings.text("invasion_go_campaign"), "PrimaryButton", "play")
	go.name = "BtnInvasionGoCampaign"
	go.pressed.connect(_go_to_campaign)
	card.add_child(go)

func _build_map(continent_id: String) -> void:
	if not _layout_cache.has(continent_id):
		_layout_cache[continent_id] = _build_continent_layout(continent_id)
	var layout: Dictionary = _layout_cache[continent_id]
	_map_layout = layout
	_map_region_ids.assign(layout.get("region_ids", []))
	var center := CenterContainer.new()
	content.add_child(center)
	map_container = Control.new()
	map_container.name = "InvasionMap"
	# El mapa es geografía: no se espeja en árabe. La ficha y los botones sí.
	map_container.layout_direction = Control.LAYOUT_DIRECTION_LTR
	map_container.custom_minimum_size = MAP_SIZE
	map_container.size = MAP_SIZE
	map_container.clip_contents = true
	center.add_child(map_container)
	var silhouette := GeoSilhouette.new()
	silhouette.layout_direction = Control.LAYOUT_DIRECTION_LTR
	silhouette.size = MAP_SIZE
	silhouette.set_geography(layout["geo"], LevelDatabase.get_continents().filter(func(c): return c["id"] == continent_id)[0]["color"])
	map_container.add_child(silhouette)
	silhouette.position = Vector2.ZERO
	_map_overlay = Control.new()
	_map_overlay.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_map_overlay.size = MAP_SIZE
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_overlay.draw.connect(_draw_map_overlay)
	map_container.add_child(_map_overlay)
	_map_overlay.position = Vector2.ZERO
	var nodes: PackedVector2Array = layout["nodes"]
	var region_ids: Array[String] = _map_region_ids
	for i in region_ids.size():
		var region_id := region_ids[i]
		var btn := Button.new()
		btn.name = "MapPin_" + region_id
		btn.layout_direction = Control.LAYOUT_DIRECTION_LTR
		btn.size = Vector2.ONE * NODE_SIZE
		var pin_pos := nodes[i] - Vector2.ONE * NODE_SIZE * 0.5
		btn.text = str(i + 1)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_font_override("font", UIThemeHelper.bold_font())
		var region := InvasionDatabase.get_region(region_id)
		btn.accessibility_name = InvasionDatabase.region_name(region)
		btn.accessibility_description = LocaleStrings.text("invasions_stars") % [GameManager.region_stars(region_id), InvasionDatabase.FRONTS * 3]
		var selected := region_id == selected_region
		_style_pin(btn, UIThemeHelper.colors.primary if selected else UIThemeHelper.colors.text,
			UIThemeHelper.colors.ink if selected else UIThemeHelper.colors.ink)
		btn.pressed.connect(_select_region.bind(region_id))
		map_container.add_child(btn)
		btn.position = pin_pos

func _style_pin(btn: Button, fill: Color, ink: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := UIThemeHelper.box(fill.darkened(0.12) if state == "pressed" else fill, 999, 0)
		box.draw_center = state != "focus"
		box.set_border_width_all(4)
		box.border_color = UIThemeHelper.colors.bg if state != "focus" else UIThemeHelper.colors.gold
		btn.add_theme_stylebox_override(state, box)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(color_name, ink)

func _draw_map_overlay() -> void:
	if _map_layout.is_empty() or not is_instance_valid(_map_overlay):
		return
	var index := _map_region_ids.find(selected_region)
	if index < 0:
		return
	var nodes: PackedVector2Array = _map_layout["nodes"]
	if index >= nodes.size():
		return
	var radius := NODE_SIZE * 0.5 + 12.0 + sin(pulse_time) * 3.0
	_map_overlay.draw_circle(nodes[index], radius, Color(UIThemeHelper.colors.gold, 0.14))
	_map_overlay.draw_arc(nodes[index], radius, 0, TAU, 44, UIThemeHelper.colors.gold, 4.0, true)

func _process(delta: float) -> void:
	if GameManager.settings["reduced_motion"] or not is_instance_valid(_map_overlay):
		return
	pulse_time = fmod(pulse_time + delta * 3.0, TAU)
	_redraw_accum += delta
	if _redraw_accum >= 0.05:
		_redraw_accum = 0.0
		_map_overlay.queue_redraw()

func _build_region_selector(continent_id: String) -> void:
	# Una sola fila desplazable: la ficha de la región debe quedar cerca del primer pantallazo.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = UIThemeHelper.TOUCH_SCROLL_DEADZONE
	scroll.custom_minimum_size.y = 72
	content.add_child(scroll)
	var row := UIThemeHelper.hbox(12)
	scroll.add_child(row)
	var group := ButtonGroup.new()
	var regions := InvasionDatabase.get_regions_by_continent(continent_id)
	for i in regions.size():
		var region: Dictionary = regions[i]
		var region_id := str(region["id"])
		var btn := UIThemeHelper.button("%d · %s" % [i + 1, InvasionDatabase.region_name(region)], "SegmentButton")
		btn.name = "BtnInvasionRegion_" + region_id
		btn.toggle_mode = true
		btn.button_group = group
		btn.set_pressed_no_signal(region_id == selected_region)
		btn.pressed.connect(_select_region.bind(region_id))
		row.add_child(btn)
		region_buttons[region_id] = btn
		if region_id == selected_region:
			_scroll_to_region.call_deferred(scroll, btn)

func _scroll_to_region(scroll: ScrollContainer, btn: Control) -> void:
	if is_instance_valid(scroll) and is_instance_valid(btn):
		scroll.ensure_control_visible(btn)

func _build_detail(continent_id: String) -> void:
	var region := InvasionDatabase.get_region(selected_region)
	if region.is_empty():
		return
	var completed := GameManager.region_completed_fronts(selected_region)
	var stars := GameManager.region_stars(selected_region)
	var card := UIThemeHelper.card(content)
	detail_card = card
	card.name = "InvasionRegionCard"
	var top := UIThemeHelper.hbox(16)
	card.add_child(top)
	var title := UIThemeHelper.label(InvasionDatabase.region_name(region), "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UIThemeHelper.label(LocaleStrings.text("invasions_stars") % [stars, InvasionDatabase.FRONTS * 3], "Heading", UIThemeHelper.colors.gold))
	card.add_child(UIThemeHelper.paragraph(InvasionDatabase.region_subtitle(region), ""))

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 12)
	card.add_child(chips)
	chips.add_child(UIThemeHelper.chip(LocaleStrings.text("invasion_tier") % int(region["tier"]), "shield", UIThemeHelper.colors.muted))
	chips.add_child(UIThemeHelper.chip(LocaleStrings.text("invasion_fronts_chip") % [completed, InvasionDatabase.FRONTS], "flag", UIThemeHelper.colors.primary))
	chips.add_child(UIThemeHelper.chip(InvasionDatabase.rule_text(str(region["rule"])), "bolt", UIThemeHelper.colors.gold))
	if GameManager.is_region_mastered(selected_region):
		chips.add_child(UIThemeHelper.chip(LocaleStrings.text("invasion_region_mastered"), "star", UIThemeHelper.colors.gold))
	elif GameManager.is_region_complete(selected_region):
		chips.add_child(UIThemeHelper.chip(LocaleStrings.text("invasion_region_complete"), "check", UIThemeHelper.colors.success))

	# La acción principal queda siempre a la vista; la lista de frentes es el detalle.
	var next_front := _next_front(region)
	if next_front != "":
		var go := UIThemeHelper.button(LocaleStrings.text("invasion_continue" if completed > 0 else "invasion_start"), "PrimaryButton", "play")
		go.name = "BtnInvasionNext"
		go.custom_minimum_size.y = 104
		go.pressed.connect(_start_front.bind(next_front))
		card.add_child(go)
	elif GameManager.is_region_complete(selected_region):
		var next_region := _next_region(continent_id, selected_region)
		if next_region != "":
			var go := UIThemeHelper.button(LocaleStrings.text("next_region"), "GoldButton", "next")
			go.name = "BtnNextInvasionRegion"
			go.pressed.connect(_select_region.bind(next_region))
			card.add_child(go)
		elif GameManager.all_regions_complete(continent_id):
			card.add_child(UIThemeHelper.paragraph(LocaleStrings.text("invasion_all_complete"), "Caption"))

	for step in range(1, InvasionDatabase.FRONTS + 1):
		card.add_child(_front_row(region, step))

	var reward_gold := InvasionDatabase.REGION_COMPLETION_GOLD + int(region["tier"]) * 50
	var reward_text := LocaleStrings.text("invasion_reward_chip") % reward_gold
	var reward := CosmeticsDatabase.invasion_reward(continent_id)
	if not reward.is_empty():
		reward_text += "\n" + LocaleStrings.text("invasion_continent_reward") % CosmeticsDatabase.item_name(reward)
	card.add_child(UIThemeHelper.paragraph(reward_text, "Caption"))

func _front_row(region: Dictionary, step: int) -> HBoxContainer:
	var level_id := InvasionDatabase.level_id(str(region["id"]), step)
	var stars := GameManager.invasion_level_stars(level_id)
	var unlocked := GameManager.is_invasion_level_unlocked(level_id)
	var row := UIThemeHelper.hbox(14)
	row.name = "InvasionFrontRow_%d" % step
	row.add_child(UIThemeHelper.label(str(step), "Heading"))
	var text := UIThemeHelper.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UIThemeHelper.label(InvasionDatabase.get_front_title(step), "Heading"))
	text.add_child(UIThemeHelper.label(LocaleStrings.text("inv_front_progress") % [step, InvasionDatabase.FRONTS], "Caption"))
	row.add_child(text)
	row.add_child(UIThemeHelper.stars_label(stars, "Caption"))
	var btn := UIThemeHelper.button("", "GhostButton")
	btn.name = "BtnInvasionFront_%d" % step
	btn.custom_minimum_size = Vector2(190, 0)
	if not unlocked:
		btn.text = LocaleStrings.text("level_locked")
		btn.icon = Icons.texture("lock", 34)
		btn.disabled = true
	elif stars > 0:
		btn.text = LocaleStrings.text("invasion_replay")
		btn.icon = Icons.texture("retry", 34)
		btn.pressed.connect(_start_front.bind(level_id))
	else:
		btn.text = LocaleStrings.text("invasion_continue" if step > 1 else "invasion_start")
		btn.icon = Icons.texture("play", 34)
		# La acción principal ya está sobre la ficha; la fila sólo acompaña.
		btn.theme_type_variation = "Button"
		btn.pressed.connect(_start_front.bind(level_id))
	row.add_child(btn)
	front_buttons[level_id] = btn
	return row

func _next_front(region: Dictionary) -> String:
	return GameManager.first_pending_invasion_front(str(region["id"]))

func _next_region(continent_id: String, after_region: String) -> String:
	var regions := InvasionDatabase.get_regions_by_continent(continent_id)
	var seen := false
	for region in regions:
		var region_id := str(region["id"])
		if seen and not GameManager.is_region_complete(region_id):
			return region_id
		if region_id == after_region:
			seen = true
	for region in regions:
		var region_id := str(region["id"])
		if not GameManager.is_region_complete(region_id):
			return region_id
	return ""

func _select_continent(continent_id: String) -> void:
	AudioManager.play_click()
	selected_continent = continent_id
	selected_region = ""
	last_continent = continent_id
	last_region = ""
	rebuild()

func _select_region(region_id: String) -> void:
	AudioManager.play_click()
	selected_region = region_id
	last_region = region_id
	rebuild()

func _start_front(level_id: String) -> void:
	if not GameManager.is_invasion_level_unlocked(level_id):
		return
	AudioManager.play_click()
	UIThemeHelper.start_battle(self, level_id)

func _go_to_campaign() -> void:
	var node: Node = self
	while node and not (node is MainMenuUI):
		node = node.get_parent()
	if node:
		(node as MainMenuUI).show_tab("play")

static func _build_continent_layout(continent_id: String) -> Dictionary:
	var regions := InvasionDatabase.get_regions_by_continent(continent_id)
	var anchors: Array[Vector2] = []
	var region_ids: Array[String] = []
	for region in regions:
		var capital := GeoDatabase.get_city(str(region["capital"]))
		if capital.is_empty():
			continue
		anchors.append(capital["lonlat"])
		region_ids.append(str(region["id"]))
	if anchors.is_empty():
		return {"geo": {"land": [], "borders": []}, "nodes": PackedVector2Array(), "region_ids": region_ids}
	var proj := LevelGenerator.fit_projection(anchors, SILHOUETTE_RECT)
	var nodes := PackedVector2Array()
	for lonlat in anchors:
		nodes.append(proj.project(lonlat))
	nodes = LevelGenerator.separate_points(nodes, func(_i, _j): return NODE_MIN_DISTANCE, NODE_RECT)
	return {
		"geo": LevelGenerator.project_geography(proj, SILHOUETTE_CLIP),
		"nodes": nodes,
		"region_ids": region_ids,
	}
