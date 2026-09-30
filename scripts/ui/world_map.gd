extends Control
class_name WorldMapUI

## WorldMapUI: Selección de continentes y niveles con ruta de campaña geopolítica interconectada (State.io)

@onready var continent_title: Label = %ContinentTitle
@onready var coins_label: Label = %CoinsLabel
@onready var stars_label: Label = %StarsLabel
@onready var levels_container: Control = %LevelsContainer
@onready var route_container: Control = %RouteContainer

@onready var btn_back: Button = %BtnBack
@onready var btn_upgrades: Button = %BtnUpgrades
@onready var btn_prev_continent: Button = %BtnPrevContinent
@onready var btn_next_continent: Button = %BtnNextContinent

@onready var briefing_panel: PanelContainer = %BriefingPanel
@onready var briefing_title: Label = %BriefingTitle
@onready var briefing_desc: Label = %BriefingDesc
@onready var briefing_stars: Label = %BriefingStars
@onready var stat_bases: Label = %StatBases
@onready var stat_enemy: Label = %StatEnemy
@onready var stat_target_time: Label = %StatTargetTime
@onready var btn_start_level: Button = %BtnStartLevel

@onready var continent_card: PanelContainer = %ContinentCard
@onready var stars_pill: PanelContainer = %StarsPill
@onready var coins_pill: PanelContainer = %CoinsPill

## Encuadre del continente dentro de la zona de la ruta, y límites de los nodos de nivel
const SILHOUETTE_RECT := Rect2(60, 20, 960, 900)
const SILHOUETTE_CLIP := Rect2(0, 0, 1080, 940)
const NODE_RECT := Rect2(70, 70, 940, 730)
const NODE_MIN_DISTANCE := 150.0

var continents: Array[Dictionary] = []
var _silhouette: GeoSilhouette
## Por continente: {"geo": costas y fronteras, "nodes": posición de cada nivel sobre su región}
var _layout_cache: Dictionary = {}
var _node_positions: PackedVector2Array = PackedVector2Array()
var current_continent_index: int = 0
var selected_level_id: String = ""
var marching_phase: float = 0.0
var pulse_time: float = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _ready() -> void:
	AudioManager.play_music("menu")
	_apply_visual_styling()
	UIThemeHelper.apply_safe_area_top($Header)

	btn_back.text = LocaleStrings.text("menu")
	btn_upgrades.text = LocaleStrings.text("upgrades")
	$Header/Title.text = LocaleStrings.text("to_map")

	continents = LevelDatabase.get_continents()
	for i in range(continents.size()):
		if continents[i]["id"] == GameManager.current_continent:
			current_continent_index = i
			break

	btn_back.pressed.connect(_on_back_pressed)
	btn_upgrades.pressed.connect(UIThemeHelper.go_to.bind(self, "res://scenes/ui/upgrade_menu.tscn"))
	btn_prev_continent.pressed.connect(_on_prev_continent)
	btn_next_continent.pressed.connect(_on_next_continent)
	btn_start_level.pressed.connect(_on_start_selected_level)

	route_container.draw.connect(_draw_route)
	_silhouette = GeoSilhouette.new()
	_silhouette.show_behind_parent = true
	route_container.add_child(_silhouette)
	route_container.move_child(_silhouette, 0)
	_silhouette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_update_coins(GameManager.coins)
	_update_total_stars()
	EventBus.coins_updated.connect(_update_coins)

	_refresh_display()

func _apply_visual_styling() -> void:
	UIThemeHelper.apply_stateio_button_style(btn_back, UIThemeHelper.COLOR_BTN_SECONDARY, 16, 4)
	UIThemeHelper.apply_stateio_button_style(btn_upgrades, Color(0.16, 0.50, 0.42), 18, 5)
	UIThemeHelper.apply_stateio_button_style(btn_prev_continent, Color(0.18, 0.26, 0.36), 14, 4)
	UIThemeHelper.apply_stateio_button_style(btn_next_continent, Color(0.18, 0.26, 0.36), 14, 4)
	UIThemeHelper.apply_card_style(briefing_panel, UIThemeHelper.COLOR_CARD, UIThemeHelper.COLOR_CARD_BORDER, 20, 2)
	UIThemeHelper.apply_pill_style(continent_card, Color(0.12, 0.15, 0.20, 0.90), Color(0.30, 0.40, 0.55, 0.70), 16)
	UIThemeHelper.apply_pill_style(stars_pill)
	UIThemeHelper.apply_pill_style(coins_pill)

func _process(delta: float) -> void:
	marching_phase = fmod(marching_phase + delta * 1.8, 1.0)
	pulse_time += delta * 3.0
	route_container.queue_redraw()

func _update_coins(amount: int) -> void:
	coins_label.text = UIThemeHelper.coins_text(amount)

func _update_total_stars() -> void:
	stars_label.text = UIThemeHelper.stars_text()

func _refresh_display() -> void:
	var cont = continents[current_continent_index]
	GameManager.current_continent = cont["id"]
	GameManager.save_game()

	var cont_color: Color = cont["color"]
	var level_ids := LevelDatabase.get_continent_level_ids(cont["id"])

	var earned_stars = 0
	for lid in level_ids:
		earned_stars += GameManager.completed_levels.get(lid, 0)

	continent_title.text = "%s  (%d/%d ⭐)" % [LevelDatabase.continent_name(cont["id"]), earned_stars, level_ids.size() * 3]
	continent_title.add_theme_color_override("font_color", cont_color.lightened(0.20))
	_apply_continent_layout(cont["id"], cont_color)

	# Determinar nivel predeterminado seleccionado (el mayor desbloqueado o el primero no completado)
	var default_selected = level_ids[0]
	for lid in level_ids:
		if GameManager.is_level_unlocked(lid):
			default_selected = lid
			if GameManager.completed_levels.get(lid, 0) == 0:
				break
	selected_level_id = default_selected

	# Limpiar y regenerar nodos de la ruta de campaña
	for child in levels_container.get_children():
		levels_container.remove_child(child)
		child.queue_free()

	for lvl_idx in level_ids.size():
		var lvl_num = lvl_idx + 1
		var level_id = level_ids[lvl_idx]
		var is_unlocked = GameManager.is_level_unlocked(level_id)
		var stars = GameManager.completed_levels.get(level_id, 0)
		var node_pos = _node_positions[lvl_idx]

		# Contenedor del nodo táctico
		var node_holder = Control.new()
		node_holder.name = "NodeHolder_%d" % lvl_num
		node_holder.position = node_pos - Vector2(50, 50)
		node_holder.custom_minimum_size = Vector2(100, 140)
		levels_container.add_child(node_holder)

		# Botón circular del nivel
		var btn = Button.new()
		btn.name = "BtnLevel_%d" % lvl_num
		btn.custom_minimum_size = Vector2(100, 100)
		btn.add_theme_font_size_override("font_size", 34)

		if is_unlocked:
			btn.text = str(lvl_num)
			# El último nivel (conquista del continente) lleva el color del continente
			var node_bg = cont_color if lvl_num == level_ids.size() else UIThemeHelper.COLOR_PRIMARY
			UIThemeHelper.apply_stateio_button_style(btn, node_bg, 50, 6)
			btn.pressed.connect(_select_level.bind(level_id))
		else:
			btn.text = "🔒"
			btn.disabled = true
			UIThemeHelper.apply_stateio_button_style(btn, Color(0.20, 0.23, 0.28, 0.65), 50, 2)

		node_holder.add_child(btn)

		# Etiqueta de estrellas ganadas debajo del nodo
		var star_lbl = Label.new()
		star_lbl.position = Vector2(0, 104)
		star_lbl.custom_minimum_size = Vector2(100, 30)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 18)
		if is_unlocked:
			star_lbl.text = UIThemeHelper.star_rating(stars)
			star_lbl.add_theme_color_override("font_color", UIThemeHelper.COLOR_ACCENT if stars > 0 else Color(0.5, 0.5, 0.5))
		else:
			star_lbl.text = LocaleStrings.text("blocked")
			star_lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
		node_holder.add_child(star_lbl)

	_update_briefing_card()
	route_container.queue_redraw()

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
	route_container.queue_redraw()

func _update_briefing_card() -> void:
	var level_data = LevelDatabase.get_level_data(selected_level_id)
	var is_unlocked = GameManager.is_level_unlocked(selected_level_id)
	var stars = GameManager.completed_levels.get(selected_level_id, 0)

	briefing_title.text = level_data["name"]
	briefing_desc.text = level_data["description"]
	var rule := CampaignRules.description(level_data)
	if rule != "":
		briefing_desc.text += "\n" + rule
	briefing_stars.text = UIThemeHelper.star_rating(stars)

	var bases: Array = level_data.get("bases", [])
	stat_bases.text = LocaleStrings.text("bases") % bases.size()

	var enemy_factions := {}
	for b in bases:
		if b["faction"] != GameManager.Faction.PLAYER and b["faction"] != GameManager.Faction.NEUTRAL:
			enemy_factions[b["faction"]] = true
	var enemy_count := enemy_factions.size()
	stat_enemy.text = LocaleStrings.text("rival" if enemy_count == 1 else "rivals") % enemy_count
	stat_target_time.text = LocaleStrings.text("target_time") % level_data.get("target_time", 45)

	btn_start_level.disabled = not is_unlocked
	if is_unlocked:
		btn_start_level.text = LocaleStrings.text("start_assault")
		UIThemeHelper.apply_stateio_button_style(btn_start_level, UIThemeHelper.COLOR_PRIMARY, 18, 6)
	else:
		btn_start_level.text = LocaleStrings.text("level_locked")
		UIThemeHelper.apply_stateio_button_style(btn_start_level, Color(0.25, 0.28, 0.34), 18, 3)

func _draw_route() -> void:
	if continents.is_empty():
		return
	var cont = continents[current_continent_index]
	var cont_color: Color = cont["color"]
	var level_ids := LevelDatabase.get_continent_level_ids(cont["id"])

	# Conexiones entre los niveles de la campaña del continente
	for i in level_ids.size() - 1:
		var p1 = _node_positions[i]
		var p2 = _node_positions[i + 1]
		var is_segment_active = GameManager.is_level_unlocked(level_ids[i + 1])
		var is_frontier = GameManager.is_level_unlocked(level_ids[i])

		# Sombra proyectada 2.5D de la ruta
		route_container.draw_line(p1 + Vector2(0, 3), p2 + Vector2(0, 3), Color(0, 0, 0, 0.35), 6.0, true)

		if is_segment_active:
			# Ruta conquistada activa (trazo grueso iluminado con el color del continente)
			route_container.draw_line(p1, p2, cont_color, 6.0, true)
			route_container.draw_line(p1, p2, Color(1, 1, 1, 0.65), 2.0, true)
		elif is_frontier:
			# Frontera activa de avance (línea discontinua con animación de puntos de marcha)
			route_container.draw_dashed_line(p1, p2, Color(1, 1, 1, 0.40), 4.0, 10.0)
			# Marching dot táctico animado
			var dot_pos = p1.lerp(p2, marching_phase)
			route_container.draw_circle(dot_pos, 5.0, UIThemeHelper.COLOR_ACCENT)
			route_container.draw_circle(dot_pos, 8.0, Color(UIThemeHelper.COLOR_ACCENT, 0.35))
		else:
			# Ruta bloqueada
			route_container.draw_dashed_line(p1, p2, Color(0.30, 0.36, 0.45, 0.35), 3.0, 12.0)

	# Resaltar con halo pulsante el nodo seleccionado actualmente
	var selected := level_ids.find(selected_level_id)
	if selected >= 0:
		var pos = _node_positions[selected]
		var halo_r = 62.0 + sin(pulse_time) * 5.0
		route_container.draw_arc(pos, halo_r, 0, TAU, 32, UIThemeHelper.COLOR_ACCENT, 3.5, true)
		route_container.draw_circle(pos, halo_r, Color(UIThemeHelper.COLOR_ACCENT, 0.12))

func _on_prev_continent() -> void:
	AudioManager.play_click()
	current_continent_index = (current_continent_index - 1 + continents.size()) % continents.size()
	_refresh_display()

func _on_next_continent() -> void:
	AudioManager.play_click()
	current_continent_index = (current_continent_index + 1) % continents.size()
	_refresh_display()

## El botón está deshabilitado mientras el nivel seleccionado siga bloqueado
func _on_start_selected_level() -> void:
	GameManager.play_level(selected_level_id)
	UIThemeHelper.go_to(self, "res://scenes/battle/battle_field.tscn")

func _on_back_pressed() -> void:
	UIThemeHelper.go_to(self, "res://scenes/ui/main_menu.tscn")
