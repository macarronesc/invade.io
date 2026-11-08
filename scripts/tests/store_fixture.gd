extends RefCounted
class_name StoreFixture

## Mid-game save shared by the store screenshots and the trailer; never touches the real save.
const DAILY_DAY := 20754
const SEED := 20261028

static func apply(lang: String, tree: SceneTree) -> void:
    seed(SEED)
    GameManager._apply_save({})
    GameManager.sound_muted = true
    GameManager.music_muted = true
    GameManager.language = lang
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
    UIThemeHelper.apply_palette(tree, true)
