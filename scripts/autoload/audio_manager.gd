extends Node

## AudioManager: Efectos de sonido procedurales pre-renderizados y mezclados con polifonía,
## y música procedural en bucle (MusicSynth).
## Cada efecto se sintetiza una sola vez (caché de AudioStreamWAV) y se reproduce mediante
## AudioStreamPolyphonic, de modo que varios efectos suenan a la vez sin retrasos ni cortes.
## Las pistas de música se sintetizan en un hilo aparte y cambian con un fundido suave.
## "Sonido" silencia todo; "Música" silencia sólo la música.

const MIX_RATE := MusicSynth.MIX_RATE
const MUSIC_VOLUME_DB := -11.0
const MUSIC_SILENT_DB := -40.0
const MUSIC_FADE := 0.8
const POLYPHONY := 24
## Intervalo mínimo entre sonidos de absorción para no saturar la mezcla con cientos de perlas
const ABSORB_MIN_INTERVAL_MSEC := 45

const PENTATONIC_REINFORCE = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51] # C5 a E6
const PENTATONIC_HIT = [440.00, 523.25, 587.33, 659.25, 783.99, 880.00, 1046.50]
const STAR_NOTES = [659.25, 783.99, 1046.50] # E5, G5, C6 brillante

var is_muted: bool = false
var music_muted: bool = false
## Pista que debería sonar ahora ("" = ninguna), aunque esté silenciada o aún se esté sintetizando
var current_track: String = ""
var last_played_fanfare: String = ""
var last_star_sound_index: int = -1
var last_played_sfx: String = ""

var _last_absorb_msec: int = 0
var _last_absorb_play_msec: int = 0
var _absorb_step: int = 0

var _player: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic
var _cache: Dictionary = {}

var _music_player: AudioStreamPlayer
var _music_cache: Dictionary = {}
var _music_tasks: Dictionary = {}
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_muted = GameManager.sound_muted
	music_muted = GameManager.music_muted
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_SILENT_DB
	add_child(_music_player)
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY
	_player = AudioStreamPlayer.new()
	_player.stream = poly
	_player.volume_db = -2.0
	add_child(_player)
	if DisplayServer.get_name() != "headless":
		_player.play()
		_playback = _player.get_stream_playback()
		_prewarm.call_deferred()
		for track in MusicSynth.TRACKS:
			_request_music(track)

func toggle_mute() -> bool:
	set_muted(not is_muted)
	return is_muted

func set_muted(muted: bool) -> void:
	is_muted = muted
	GameManager.sound_muted = muted
	GameManager.save_game()
	_refresh_music()
	EventBus.sound_toggled.emit(is_muted)

func toggle_music() -> bool:
	set_music_muted(not music_muted)
	return music_muted

func set_music_muted(muted: bool) -> void:
	music_muted = muted
	GameManager.music_muted = muted
	GameManager.save_game()
	_refresh_music()

# =========================================================================
# Música
# =========================================================================

## Cambia a la pista indicada con un fundido (no hace nada si ya está sonando)
func play_music(track: String) -> void:
	if track == current_track and (_music_player.playing or not _can_play_music()):
		return
	current_track = track
	_refresh_music()

func stop_music() -> void:
	current_track = ""
	_refresh_music()

func is_music_playing() -> bool:
	return _music_player.playing and current_track != ""

func _can_play_music() -> bool:
	return not is_muted and not music_muted and DisplayServer.get_name() != "headless"

func _refresh_music() -> void:
	if current_track == "" or not _can_play_music():
		_fade_music_to(null)
	elif _music_cache.has(current_track):
		if _music_player.stream != _music_cache[current_track] or not _music_player.playing:
			_fade_music_to(_music_cache[current_track])
	else:
		_request_music(current_track)

## Funde la pista actual y, si se indica, entra la nueva
func _fade_music_to(stream: AudioStream) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music_player.playing:
		_music_tween.tween_property(_music_player, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE * 0.5)
	_music_tween.tween_callback(func():
		_music_player.stop()
		if stream:
			_music_player.stream = stream
			_music_player.play()
	)
	if stream:
		_music_tween.tween_property(_music_player, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE)

func _request_music(track: String) -> void:
	if _music_cache.has(track) or _music_tasks.has(track):
		return
	_music_tasks[track] = WorkerThreadPool.add_task(_render_music.bind(track), false, "music_%s" % track)

## Se ejecuta en un hilo de trabajo: sintetizar ~20 s de audio no congela la interfaz
func _render_music(track: String) -> void:
	var wav := MusicSynth.to_wav(MusicSynth.render_track(track), true)
	_on_music_rendered.call_deferred(track, wav)

func _on_music_rendered(track: String, wav: AudioStreamWAV) -> void:
	WorkerThreadPool.wait_for_task_completion(_music_tasks[track])
	_music_tasks.erase(track)
	_music_cache[track] = wav
	if track == current_track:
		_refresh_music()

func play_click() -> void:
	_play("click", func(): return _render_tone(650.0, 0.04, 0.15))

func play_launch() -> void:
	# Chirp rápido ascendente
	_play("launch", func(): return _render_tone(320.0, 0.07, 0.18, 580.0))

func play_troop_absorb(is_reinforce: bool) -> void:
	var now = Time.get_ticks_msec()
	# Reiniciar progresión melódica en el primer golpe o si pasaron más de 380 ms
	if _last_absorb_msec == 0 or (now - _last_absorb_msec) > 380:
		_absorb_step = 0
	_last_absorb_msec = now
	var scale: Array = PENTATONIC_REINFORCE if is_reinforce else PENTATONIC_HIT
	var note_idx: int = _absorb_step % scale.size()
	_absorb_step += 1
	if now - _last_absorb_play_msec < ABSORB_MIN_INTERVAL_MSEC:
		return
	_last_absorb_play_msec = now
	var freq: float = scale[note_idx]
	if is_reinforce:
		# Tono cristalino brillante con subida suave
		_play("reinforce_%d" % note_idx, func(): return _render_tone(freq, 0.045, 0.18, freq * 1.05))
	else:
		# Impacto percusivo de asalto con bajada
		_play("hit_%d" % note_idx, func(): return _render_tone(freq, 0.042, 0.20, freq * 0.88))

func play_capture() -> void:
	# Fanfarria triunfal corta de conquista de territorio
	_play("capture", func(): return _render_tone(523.25, 0.12, 0.22, 1046.50))

func play_victory() -> void:
	last_played_fanfare = "victory"
	# Fanfarria triunfal ascendente y resonante (C5 -> E5 -> G5 -> C6)
	_play("victory", func(): return _render_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.10, 0.26))

func play_continent_conquest() -> void:
	last_played_fanfare = "continent_conquest"
	_play("continent", func(): return _render_fanfare([523.25, 659.25, 783.99], [523.25, 659.25, 1046.50], 0.09, 0.28, 0.30))

func play_star_reveal(star_index: int) -> void:
	last_star_sound_index = star_index
	var idx = clampi(star_index, 0, STAR_NOTES.size() - 1)
	var freq: float = STAR_NOTES[idx]
	# Pop/ding cristalino con armónico superior
	_play("star_%d" % idx, func(): return _render_tone(freq, 0.16, 0.25, freq * 1.04))

func play_troop_retreat() -> void:
	last_played_sfx = "retreat"
	# Silbido táctico rápido descendente de retirada
	_play("retreat", func(): return _render_tone(784.0, 0.08, 0.22, 392.0))

func play_defeat() -> void:
	_play("defeat", func(): return _render_tone(349.23, 0.5, 0.25, 130.81))

# =========================================================================
# Reproducción y caché
# =========================================================================

func _play(key: String, render: Callable) -> void:
	if is_muted or _playback == null:
		return
	_playback.play_stream(_get_stream(key, render))

func _get_stream(key: String, render: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = MusicSynth.to_wav(render.call())
	return _cache[key]

## Sintetiza por adelantado los sonidos más largos para evitar tirones en mitad de la partida
func _prewarm() -> void:
	_get_stream("victory", func(): return _render_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.10, 0.26))
	_get_stream("continent", func(): return _render_fanfare([523.25, 659.25, 783.99], [523.25, 659.25, 1046.50], 0.09, 0.28, 0.30))
	_get_stream("defeat", func(): return _render_tone(349.23, 0.5, 0.25, 130.81))

# =========================================================================
# Síntesis
# =========================================================================

static func _render_tone(freq: float, duration: float, volume: float, slide_to_freq: float = -1.0) -> PackedFloat32Array:
	var frames := int(MIX_RATE * duration)
	var out := PackedFloat32Array()
	out.resize(frames)
	var phase := 0.0
	var phase_inc := (TAU * freq) / MIX_RATE
	var target_inc := phase_inc if slide_to_freq <= 0.0 else (TAU * slide_to_freq) / MIX_RATE
	for i in frames:
		var t := float(i) / float(frames)
		var attack := minf(1.0, float(i) / maxf(1.0, frames * 0.08))
		var envelope := attack * (1.0 - t * t)
		# Fundamental + 2º armónico sutil para una textura más cálida
		out[i] = (sin(phase) * 0.82 + sin(phase * 2.0) * 0.18) * volume * envelope
		phase = fmod(phase + lerpf(phase_inc, target_inc, t), TAU)
	return out

static func _render_note(out: PackedFloat32Array, freq: float, duration: float, volume: float, release_frac: float, decay: float, harmonics: PackedFloat32Array) -> void:
	var frames := int(MIX_RATE * duration)
	var phase := 0.0
	var phase_inc := (TAU * freq) / MIX_RATE
	for i in frames:
		var t := float(i) / float(frames)
		var attack := minf(1.0, float(i) / maxf(1.0, frames * 0.08))
		var release := minf(1.0, float(frames - 1 - i) / maxf(1.0, frames * release_frac))
		var s := 0.0
		for h in harmonics.size():
			s += sin(phase * (h + 1)) * harmonics[h]
		out.append(s * volume * attack * release * (1.0 - t * decay))
		phase = fmod(phase + phase_inc, TAU)

static func _render_arpeggio(notes: Array, note_duration: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for freq in notes:
		_render_note(out, freq, note_duration, volume, 0.15, 0.4, PackedFloat32Array([0.8, 0.2]))
	return out

static func _render_fanfare(flourish_notes: Array, chord_notes: Array, flourish_dur: float, chord_dur: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	# 1. Flourish ascendente rápido con armónicos ricos
	for freq in flourish_notes:
		_render_note(out, freq, flourish_dur, volume, 0.12, 0.35, PackedFloat32Array([0.65, 0.22, 0.13]))
	# 2. Acorde triunfal sostenido polifónico
	var frames := int(MIX_RATE * chord_dur)
	var voices := chord_notes.size()
	var phases := PackedFloat32Array()
	phases.resize(voices)
	for i in frames:
		var t := float(i) / float(frames)
		var attack := minf(1.0, float(i) / maxf(1.0, frames * 0.06))
		var release := minf(1.0, float(frames - 1 - i) / maxf(1.0, frames * 0.20))
		var combined := 0.0
		for v in voices:
			var ph := phases[v]
			combined += sin(ph) * 0.55 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.15 + sin(ph * 4.0) * 0.05
			phases[v] = fmod(ph + (TAU * float(chord_notes[v])) / MIX_RATE, TAU)
		out.append((combined / maxf(1.0, voices)) * volume * attack * release * (1.0 - t * t * 0.6))
	return out
