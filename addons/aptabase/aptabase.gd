extends Node
## Aptabase analytics client for Godot.
##
## Privacy-first analytics for games and apps. Events are queued and sent
## asynchronously in batches using [HTTPRequest], so tracking never blocks
## your game loop.
##
## GDScript has no exceptions, so this client never crashes your game: every
## network failure is caught via result/response codes, logged as a warning,
## and the affected events are re-queued for the next flush. A misconfigured
## app key disables analytics silently rather than raising.
##
## This script is registered as the [code]Aptabase[/code] autoload singleton by
## the editor plugin. Typical usage:
## [codeblock]
## func _ready() -> void:
##     Aptabase.init("A-EU-0000000000", {"app_version": "1.2.3"})
##     Aptabase.track("app_started")
##     Aptabase.track("level_completed", {"level": 3, "score": 1200})
## [/codeblock]

const SDK_VERSION := "aptabase-godot@0.0.1"
const DEFAULT_APP_VERSION := "1.0.0"
const MAX_BATCH_SIZE := 25
const SESSION_TIMEOUT_SECONDS := 3600 # 1 hour, mirrors the other Aptabase SDKs.

## Hard cap on the in-memory queue so a long offline period can't grow it
## without bound. Oldest events beyond this are dropped on re-queue.
const MAX_QUEUE_SIZE := 1000

const _HOSTS := {
	"EU": "https://eu.aptabase.com",
	"US": "https://us.aptabase.com",
	"SH": "", # Self-hosted: requires base_url in the init options.
}

var _app_key := ""
var _base_url := ""
var _app_version := DEFAULT_APP_VERSION
var _is_debug := false
var _max_batch_size := MAX_BATCH_SIZE
var _flush_interval := 10.0
var _timeout := 30.0
var _initialized := false

var _event_queue: Array = []
var _system_props: Dictionary = {}
var _flush_timer: Timer
var _active_http: HTTPRequest
var _generation := 0

var _session_id := ""
var _last_touched_unix := 0

## Only one request is ever in flight at a time. This prevents HTTPRequest
## nodes (and their batches) from piling up while offline or when the server
## is slow — without it, a 30s timeout against a 10s flush interval would stack
## several requests at once.
var _request_in_flight := false


## Initialize the client. Safe to call once, typically from your main scene's
## [code]_ready()[/code]. Returns whether the client is ready to accept events.
##
## [param app_key] is your Aptabase app key, e.g. [code]A-EU-0000000000[/code].
## [param options] may contain: [code]app_version[/code] (String),
## [code]is_debug[/code] (bool, defaults to [method OS.is_debug_build]),
## [code]max_batch_size[/code] (int, max 25), [code]flush_interval[/code]
## (float seconds), [code]timeout[/code] (float seconds) and [code]base_url[/code]
## (String, required for self-hosted [code]A-SH-*[/code] keys).
func init(app_key: String, options: Dictionary = {}) -> bool:
	if _initialized:
		push_warning("[Aptabase] init() called more than once; ignoring.")
		return true

	if app_key.is_empty():
		push_error("[Aptabase] app_key is required. Analytics disabled.")
		return false

	if not (app_key.begins_with("A-EU-") or app_key.begins_with("A-US-") or app_key.begins_with("A-SH-")):
		push_error("[Aptabase] Invalid app key format. Expected A-{REGION}-{ID}. Analytics disabled.")
		return false

	_app_key = app_key
	_app_version = str(options.get("app_version", DEFAULT_APP_VERSION))
	_is_debug = bool(options.get("is_debug", OS.is_debug_build()))
	_max_batch_size = mini(int(options.get("max_batch_size", MAX_BATCH_SIZE)), MAX_BATCH_SIZE)
	_max_batch_size = maxi(_max_batch_size, 1)
	# Clamp to a positive minimum: Timer.wait_time must be > 0, and a tiny
	# interval would needlessly hammer the network.
	_flush_interval = maxf(float(options.get("flush_interval", 10.0)), 0.5)
	_timeout = maxf(float(options.get("timeout", 30.0)), 0.0)

	var base_url_opt := str(options.get("base_url", ""))
	_base_url = base_url_opt if not base_url_opt.is_empty() else _resolve_base_url(app_key)
	if _base_url.is_empty():
		push_error("[Aptabase] Could not resolve a base URL. Self-hosted keys (A-SH-*) require a 'base_url' option. Analytics disabled.")
		return false
	_base_url = _base_url.trim_suffix("/")

	_system_props = _build_system_props()
	_initialized = true
	_start_flush_timer()

	if _is_debug:
		print("[Aptabase] initialized (region base: %s, flush every %.1fs)" % [_base_url, _flush_interval])
	return true


## Stop collection immediately and discard unsent events when consent is withdrawn.
func disable() -> void:
	_generation += 1
	_initialized = false
	_event_queue.clear()
	_system_props.clear()
	_session_id = ""
	_last_touched_unix = 0
	_request_in_flight = false
	if is_instance_valid(_flush_timer):
		_flush_timer.stop()
	if is_instance_valid(_active_http):
		_active_http.cancel_request()


## Track an analytics event. Non-blocking: the event is appended to the queue
## and sent on the next flush (or immediately once a full batch accumulates).
## No-op if the client was not initialized successfully.
##
## [param event_name] is the event name. [param props] are optional custom
## properties (strings, numbers and booleans are recommended).
func track(event_name: String, props: Dictionary = {}) -> void:
	if not _initialized:
		return

	if event_name.is_empty():
		push_warning("[Aptabase] event_name is required; event ignored.")
		return

	var event := {
		"timestamp": _now_iso8601(),
		"sessionId": _get_or_create_session(),
		"eventName": event_name,
		"systemProps": _system_props,
		"props": props,
	}

	_event_queue.append(event)

	# Hard cap so extended offline play (events queued, never sent) can't grow
	# memory without bound. Keep the most recent MAX_QUEUE_SIZE events.
	if _event_queue.size() > MAX_QUEUE_SIZE:
		_event_queue = _event_queue.slice(_event_queue.size() - MAX_QUEUE_SIZE)

	if _event_queue.size() >= _max_batch_size:
		flush()


## Send any queued events now. Called automatically on a timer, when a batch
## fills up, and on quit. Safe to call manually. No-op if not initialized or
## the queue is empty.
func flush() -> void:
	if not _initialized or _event_queue.is_empty():
		return

	# One request at a time: if a send is already running, leave the events
	# queued. They'll go out when the current request finishes (see the drain
	# in _on_request_completed) or on the next timer tick.
	if _request_in_flight:
		return

	var batch := _event_queue.slice(0, _max_batch_size)
	_event_queue = _event_queue.slice(_max_batch_size)
	_send_batch(batch)


func _start_flush_timer() -> void:
	if not is_instance_valid(_flush_timer):
		_flush_timer = Timer.new()
		_flush_timer.one_shot = false
		_flush_timer.timeout.connect(flush)
		add_child(_flush_timer)
	_flush_timer.wait_time = _flush_interval
	_flush_timer.start()


func _send_batch(batch: Array) -> void:
	_request_in_flight = true
	var generation := _generation

	# A fresh HTTPRequest node per send, freed as soon as the request finishes
	# (request_completed always fires — on success, failure, or timeout — so the
	# node never leaks).
	var http := HTTPRequest.new()
	http.timeout = _timeout
	_active_http = http
	add_child(http)

	http.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			_on_request_completed(result, response_code, body, batch, http, generation)
	)

	var url := _base_url + "/api/v0/events"
	var headers := PackedStringArray([
		"App-Key: " + _app_key,
		"Content-Type: application/json",
	])
	var payload := JSON.stringify(batch)

	var err := http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		push_warning("[Aptabase] Could not start request (error %d). Events re-queued." % err)
		http.queue_free()
		if generation == _generation:
			_active_http = null
			_request_in_flight = false
			_requeue(batch)


func _on_request_completed(result: int, response_code: int, body: PackedByteArray, batch: Array, http: HTTPRequest, generation: int) -> void:
	http.queue_free()
	if _active_http == http:
		_active_http = null
	if generation != _generation:
		return
	_request_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		# Offline / DNS / connection failures land here. Re-queue and wait for
		# the next timer tick — we deliberately don't retry immediately, to
		# avoid hammering the network while offline.
		push_warning("[Aptabase] Request failed (result %d). Events re-queued." % result)
		_requeue(batch)
		return

	if response_code < 200 or response_code >= 300:
		# 4xx usually means a bad payload/key and will never succeed, so we
		# drop those; 5xx and the rest are transient and worth retrying.
		if response_code >= 400 and response_code < 500:
			push_warning("[Aptabase] Server rejected %d events (HTTP %d): %s. Dropping." % [
				batch.size(), response_code, body.get_string_from_utf8()
			])
		else:
			push_warning("[Aptabase] HTTP %d while sending events. Re-queued." % response_code)
			_requeue(batch)
		return

	if _is_debug:
		print("[Aptabase] sent %d event(s)." % batch.size())

	# Success: drain any remaining backlog right away so a burst clears quickly
	# instead of trickling out one batch per timer tick.
	if not _event_queue.is_empty():
		flush()


func _requeue(batch: Array) -> void:
	# Prepend so failed events keep their order ahead of newer ones.
	var combined := batch + _event_queue
	if combined.size() > MAX_QUEUE_SIZE:
		var overflow := combined.size() - MAX_QUEUE_SIZE
		combined = combined.slice(overflow)
		push_warning("[Aptabase] Queue full; dropped %d oldest event(s)." % overflow)
	_event_queue = combined


func _resolve_base_url(app_key: String) -> String:
	var parts := app_key.split("-")
	if parts.size() < 3 or not _HOSTS.has(parts[1]):
		return ""
	return str(_HOSTS[parts[1]]) # "" for SH -> caller reports the error.


func _build_system_props() -> Dictionary:
	return {
		"isDebug": _is_debug,
		"locale": OS.get_locale(),
		"osName": OS.get_name(),
		"osVersion": OS.get_version(),
		"deviceModel": OS.get_model_name(),
		"appVersion": _app_version,
		"sdkVersion": SDK_VERSION,
	}


func _get_or_create_session() -> String:
	var now := int(Time.get_unix_time_from_system())
	if _session_id.is_empty() or (now - _last_touched_unix) > SESSION_TIMEOUT_SECONDS:
		_session_id = _new_session_id()
	_last_touched_unix = now
	return _session_id


func _new_session_id() -> String:
	var epoch_seconds := int(Time.get_unix_time_from_system())
	var random_part := randi() % 100000000
	return str(epoch_seconds * 100000000 + random_part)


func _now_iso8601() -> String:
	# UTC ISO-8601 with a trailing "Z", matching the API's expected format.
	return Time.get_datetime_string_from_system(true) + "Z"


func _notification(what: int) -> void:
	# Best-effort flush when the game is closing. This kicks off a send, but the
	# async round-trip generally won't complete during teardown, so the last
	# unsent batch may be lost on quit — lower flush_interval if that matters.
	# It never blocks or errors; it's purely a "last chance" attempt.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()
