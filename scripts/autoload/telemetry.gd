extends Node

## Telemetry: estadísticas de uso opt-in (Aptabase) e informes de fallos opt-in (Sentry).
##
## No envía cuentas, nombres, correos, ubicación precisa ni identificadores
## persistentes del dispositivo. Los proveedores sí reciben la IP de conexión.
## Las propiedades personalizadas sólo llevan números y cadenas cortas.
##
## Las claves son públicas de cliente: Aptabase usa una App Key y Sentry un DSN.
## Si se dejan vacías, el sistema queda desactivado sin afectar al juego.

const APTABASE_KEY := "A-EU-0808905150" # A-EU-... desde eu.aptabase.com
const SENTRY_DSN := "https://551161fb05ed88e939113d6b2ca03176@o4512300980436992.ingest.de.sentry.io/4512300983582800" # https://...@o....ingest.sentry.io/... desde sentry.io
const PRIVACY_URL := "https://macarronesc.github.io/invade.io/privacy-policy.html"

## Cortes de duración para poder agrupar en el panel sin consultas complejas
const LEVEL_BUCKETS := [20.0, 40.0, 60.0, 90.0, 120.0]
const SESSION_BUCKETS := [60.0, 180.0, 300.0, 600.0, 1200.0]

var _analytics_ready := false
var _crash_ready := false
var _session_active := false
var _session_started_ms := 0
var _session_levels_started := 0
var _session_levels_finished := 0
var _session_tabs := 0
var _current_tab := ""
var _battle: Dictionary = {}
## Intentos por nivel dentro de esta sesión; no se persiste ni identifica al jugador.
var _attempts: Dictionary = {}

func _ready() -> void:
	if _is_test_runtime():
		return
	_init_analytics()
	_init_crashes()
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_finished.connect(_on_battle_finished)
	EventBus.upgrade_purchased.connect(_on_upgrade_purchased)
	EventBus.daily_reward_claimed.connect(_on_daily_reward_claimed)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.settings_changed.connect(_on_settings_changed)
	if _analytics_allowed():
		_start_session()
	_set_screen("menu")

## En tests y ejecuciones headless no se inicializa ni se envía nada.
func _is_test_runtime() -> bool:
	return DisplayServer.get_name() == "headless" \
		or OS.has_feature("headless") \
		or OS.has_feature("editor") \
		or OS.get_cmdline_user_args().has("--no-telemetry")

func _analytics_allowed() -> bool:
	return bool(GameManager.settings.get("share_analytics", false))

func _crash_allowed() -> bool:
	return bool(GameManager.settings.get("share_crashes", false))

func _app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.2.0"))

# =========================================================================
# Inicialización y privacidad
# =========================================================================

func _init_analytics() -> void:
	if _analytics_ready or not _analytics_allowed() or APTABASE_KEY.is_empty():
		return
	if not is_instance_valid(Aptabase):
		return
	_analytics_ready = Aptabase.init(APTABASE_KEY, {
		"app_version": _app_version(),
		"is_debug": OS.is_debug_build() and not OS.has_feature("aptabase_release"),
		"flush_interval": 10.0,
	})

func _init_crashes() -> void:
	if _crash_ready or not _crash_allowed() or SENTRY_DSN.is_empty():
		return
	var sdk := _sentry()
	if sdk == null or not sdk.has_method("init"):
		return
	sdk.call("init", func(options) -> void:
		options.dsn = SENTRY_DSN
		options.release = "invade.io@" + _app_version()
		options.environment = "debug" if OS.is_debug_build() else "production"
		options.send_default_pii = false
		options.attach_log = false
		options.attach_scene_tree = false
		options.traces_sample_rate = 0.0)
	_crash_ready = bool(sdk.call("is_enabled"))

## El complemento nativo puede faltar en plataformas no exportadas. Resolverlo en
## tiempo de ejecución evita que el autoload dependa de una clase concreta.
func _sentry() -> Object:
	return Engine.get_singleton("SentrySDK") if Engine.has_singleton("SentrySDK") else null

func _on_settings_changed() -> void:
	if not _analytics_allowed():
		if _analytics_ready:
			Aptabase.disable()
			_analytics_ready = false
		_session_active = false
		_attempts.clear()
		if not _battle.is_empty():
			_battle["analytics_allowed"] = false
	else:
		if not _analytics_ready:
			_init_analytics()
		if not _session_active:
			_start_session()
	if not _crash_allowed() and _crash_ready:
		var sdk := _sentry()
		if sdk != null and sdk.has_method("close"):
			sdk.call("close")
		_crash_ready = false
	elif _crash_allowed() and not _crash_ready:
		_init_crashes()

# =========================================================================
# Sesión y pantallas
# =========================================================================

func _start_session() -> void:
	if _session_active or not _analytics_ready or not _analytics_allowed():
		return
	_session_active = true
	_session_started_ms = Time.get_ticks_msec()
	_session_levels_started = 0
	_session_levels_finished = 0
	_session_tabs = 0
	_attempts.clear()
	_current_tab = ""
	_track("session_start", {
		"first_run": not GameManager.has_started,
		"player_level": GameManager.player_level(),
		"total_stars": GameManager.get_total_stars(),
		"invasion_stars": GameManager.total_invasion_stars(),
		"language": GameManager.language,
	})
	# Send the first opt-in event now instead of waiting for a mobile idle timer.
	Aptabase.flush()

func _end_session(reason: String) -> void:
	if not _session_active:
		return
	_session_active = false
	var seconds := maxf(0.0, (Time.get_ticks_msec() - _session_started_ms) / 1000.0)
	_track("session_end", {
		"duration_s": seconds,
		"duration_bucket": _bucket(seconds, SESSION_BUCKETS),
		"reason": reason,
		"levels_started": _session_levels_started,
		"levels_finished": _session_levels_finished,
		"tabs": _session_tabs,
	})
	if _analytics_ready:
		Aptabase.flush()

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_end_session("background")
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_start_session()
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_end_session("quit")

func _exit_tree() -> void:
	_end_session("quit")

func tab_opened(tab: String) -> void:
	_session_tabs += 1
	_track("tab_view", {"tab": tab, "previous_tab": _current_tab})
	_current_tab = tab
	_set_screen(tab)

func screen_opened(screen_name: String) -> void:
	_track("screen_view", {"screen": screen_name})
	_set_screen(screen_name)

func _set_screen(screen_name: String) -> void:
	var sdk := _sentry()
	if _crash_ready and sdk != null and sdk.has_method("set_tag"):
		sdk.call("set_tag", "screen", screen_name)

# =========================================================================
# Batallas
# =========================================================================

func _on_battle_started(level_id: String) -> void:
	var mode := _mode(level_id)
	var analytics_allowed := _analytics_allowed() and _analytics_ready
	if not analytics_allowed and not _crash_ready:
		return
	var attempt := 0
	if analytics_allowed:
		attempt = int(_attempts.get(level_id, 0)) + 1
		_attempts[level_id] = attempt
	_battle = {
		"level": level_id,
		"mode": mode,
		"attempt": attempt,
		"analytics_allowed": analytics_allowed,
		"prev_stars": _previous_stars(level_id, mode),
		"first_clear": _first_clear(level_id, mode),
		"started_ms": Time.get_ticks_msec(),
	}
	if analytics_allowed:
		_session_levels_started += 1
	var props := _level_props(_battle)
	if analytics_allowed:
		_track("level_start", props)
	var sdk := _sentry()
	if _crash_ready and sdk != null and sdk.has_method("set_tag"):
		sdk.call("set_tag", "screen", "battle")
		sdk.call("set_tag", "level", level_id)
		sdk.call("set_tag", "mode", mode)
		sdk.call("set_tag", "player_level", str(GameManager.player_level()))
		_breadcrumb("level_start", props)

func _on_battle_finished(result: Dictionary) -> void:
	if _battle.is_empty():
		return
	var analytics_allowed := bool(_battle.get("analytics_allowed", false)) and _analytics_allowed() and _analytics_ready
	var outcome := str(result.get("outcome", "loss"))
	var seconds := maxf(0.0, float(result.get("time", 0.0)))
	var real_seconds := maxf(0.0, (Time.get_ticks_msec() - int(_battle["started_ms"])) / 1000.0)
	var props := _level_props(_battle)
	props["outcome"] = outcome
	props["duration_s"] = seconds
	props["real_seconds"] = real_seconds
	props["duration_bucket"] = _bucket(seconds, LEVEL_BUCKETS)
	props["stars"] = int(result.get("stars", 0))
	props["is_replay"] = bool(result.get("is_replay", false))
	props["first_clear"] = bool(_battle["first_clear"]) and outcome == "win"
	props["new_medal"] = bool(result.get("new_medal", false))
	props["new_record"] = bool(result.get("new_record", false))
	props["new_cities"] = int(result.get("new_cities", 0))
	props["captures"] = int(result.get("captures", 0))
	props["gold"] = int(result.get("gold_earned", result.get("gold", 0)))
	props["player_level_after"] = GameManager.player_level()
	if analytics_allowed:
		_track("level_end", props)
		_session_levels_finished += 1
	_breadcrumb("level_end", props)
	_battle = {}

func _mode(level_id: String) -> String:
	if DailyRewards.is_challenge(level_id):
		return "daily"
	if LevelGenerator.is_conquest(level_id):
		return "conquest"
	if InvasionDatabase.is_invasion(level_id):
		return "invasion"
	return "campaign"

func _previous_stars(level_id: String, mode: String) -> int:
	match mode:
		"campaign":
			return int(GameManager.completed_levels.get(level_id, 0))
		"invasion":
			return GameManager.invasion_level_stars(level_id)
		_:
			return 0

func _first_clear(level_id: String, mode: String) -> bool:
	match mode:
		"campaign":
			return not GameManager.completed_levels.has(level_id)
		"invasion":
			return GameManager.invasion_level_stars(level_id) == 0
		"daily":
			return not GameManager.is_daily_challenge_done(DailyRewards.challenge_day(level_id))
		_:
			return false

func _level_props(context: Dictionary) -> Dictionary:
	var level_id: String = str(context["level"])
	var mode: String = str(context["mode"])
	var props := {
		"level": level_id,
		"mode": mode,
		"attempt": int(context["attempt"]),
		"prev_stars": int(context["prev_stars"]),
		"first_clear": bool(context["first_clear"]),
		"player_level": GameManager.player_level(),
		"total_stars": GameManager.get_total_stars(),
		"invasion_stars": GameManager.total_invasion_stars(),
		"upgrade_sum": _upgrade_sum(),
		"combat_upgrades": _combat_upgrade_sum(),
		"speed": float(GameManager.settings["speed"]),
	}
	if mode == "campaign" or mode == "invasion":
		props["continent"] = LevelDatabase.get_continent_of(level_id)
		props["level_no"] = LevelDatabase.get_level_number(level_id)
	return props

func _upgrade_sum() -> int:
	var total := 0
	for value in GameManager.upgrades.values():
		total += int(value)
	return total

func _combat_upgrade_sum() -> int:
	var total := 0
	for key in ["starting_troops", "production_rate", "troop_speed"]:
		total += int(GameManager.upgrades.get(key, 0))
	return total

# =========================================================================
# Economía y recompensas
# =========================================================================

func _on_upgrade_purchased(upgrade_id: String, new_level: int) -> void:
	_track("upgrade_bought", {
		"upgrade": upgrade_id,
		"new_level": new_level,
		"coins_after": GameManager.coins,
		"player_level": GameManager.player_level(),
	})

func _on_daily_reward_claimed(streak: int, reward: int) -> void:
	_track("reward_claimed", {"kind": "daily", "amount": reward, "streak": streak})

func _on_achievement_unlocked(achievement_id: String) -> void:
	_track("reward_claimed", {"kind": "achievement", "id": achievement_id})

# =========================================================================
# Utilidades
# =========================================================================

func _track(event_name: String, props: Dictionary = {}) -> void:
	if not _analytics_ready or not _analytics_allowed():
		return
	var clean := _clean_props(props)
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--telemetry-debug"):
		print("[Telemetry] ", event_name, " ", clean)
	Aptabase.track(event_name, clean)

## Aptabase sólo acepta cadenas y números; los booleanos viajan como 0/1.
func _clean_props(props: Dictionary) -> Dictionary:
	var clean := {}
	for key in props:
		var value: Variant = props[key]
		if value is bool:
			clean[key] = 1 if value else 0
		elif value is int or value is float or value is String:
			clean[key] = value
	return clean

func _bucket(seconds: float, cuts: Array) -> String:
	var previous := 0.0
	for cut in cuts:
		if seconds < float(cut):
			return "%d_%d" % [int(previous), int(cut)]
		previous = float(cut)
	return "%d_plus" % int(previous)

func _breadcrumb(name: String, props: Dictionary) -> void:
	var sdk := _sentry()
	if not _crash_ready or sdk == null or not sdk.has_method("add_breadcrumb") or not ClassDB.class_exists("SentryBreadcrumb"):
		return
	var crumb: Object = ClassDB.class_call_static("SentryBreadcrumb", "create", name)
	if crumb == null:
		return
	crumb.set("category", "game")
	var data := {}
	for key in props:
		data[key] = str(props[key])
	crumb.set("data", data)
	sdk.call("add_breadcrumb", crumb)
