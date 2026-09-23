extends Node

## AudioManager: Sistema de efectos de sonido procedurales y adaptativos

var is_muted: bool = false
var audio_player: AudioStreamPlayer
var generator: AudioStreamGenerator

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = &"Master"
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.6
	audio_player.stream = generator
	add_child(audio_player)
	if DisplayServer.get_name() != "headless":
		audio_player.play()

func _exit_tree() -> void:
	if audio_player:
		audio_player.stop()
		audio_player.stream = null
		audio_player.free()
		audio_player = null

var _last_absorb_msec: int = 0
var _absorb_step: int = 0

const PENTATONIC_REINFORCE = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51] # C5 a E6
const PENTATONIC_HIT = [440.00, 523.25, 587.33, 659.25, 783.99, 880.00, 1046.50]

func play_click() -> void:
	if is_muted: return
	_play_tone(650.0, 0.04, 0.15)

func play_launch() -> void:
	if is_muted: return
	# Chirp rápido ascendente
	_play_tone(320.0, 0.07, 0.18, 580.0)

func play_troop_absorb(is_reinforce: bool) -> void:
	if is_muted: return
	var now = Time.get_ticks_msec()
	# Reiniciar progresión melódica en el primer golpe o si pasaron más de 380 ms
	if _last_absorb_msec == 0 or (now - _last_absorb_msec) > 380:
		_absorb_step = 0
	_last_absorb_msec = now
	
	if is_reinforce:
		var freq = PENTATONIC_REINFORCE[_absorb_step % PENTATONIC_REINFORCE.size()]
		_absorb_step += 1
		# Tono cristalino brillante State.io con subida suave
		_play_tone(freq, 0.045, 0.18, freq * 1.05)
	else:
		var freq = PENTATONIC_HIT[_absorb_step % PENTATONIC_HIT.size()]
		_absorb_step += 1
		# Impacto percusivo de asalto State.io con bajada
		_play_tone(freq, 0.042, 0.20, freq * 0.88)

func play_reinforce() -> void:
	if is_muted: return
	play_troop_absorb(true)

func play_capture() -> void:
	if is_muted: return
	# Fanfarria triunfal corta de conquista de territorio
	_play_tone(523.25, 0.12, 0.22, 1046.50)

func play_victory() -> void:
	if is_muted: return
	# Tono triunfal ascendente
	_play_tone(523.25, 0.45, 0.25, 1046.50)

func play_defeat() -> void:
	if is_muted: return
	# Tono descendente de derrota
	_play_tone(349.23, 0.5, 0.25, 130.81)

func _play_tone(freq: float, duration: float, volume: float = 0.2, slide_to_freq: float = -1.0) -> void:
	if is_muted or not audio_player or not audio_player.is_playing():
		return
	var playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
		
	var sample_rate: float = generator.mix_rate
	var total_frames: int = int(sample_rate * duration)
	var available: int = playback.get_frames_available()
	var frames_to_push: int = mini(total_frames, available)
	if frames_to_push <= 0:
		return
		
	var phase: float = 0.0
	var phase_inc: float = (TAU * freq) / sample_rate
	var target_phase_inc: float = phase_inc if slide_to_freq <= 0.0 else (TAU * slide_to_freq) / sample_rate
	
	for i in range(frames_to_push):
		var t: float = float(i) / float(frames_to_push)
		var cur_inc: float = lerp(phase_inc, target_phase_inc, t)
		var envelope: float = 1.0 - (t * t)
		# Fundamental + 2º armónico sutil para una textura más cálida y placentera
		var sample: float = (sin(phase) * 0.82 + sin(phase * 2.0) * 0.18) * volume * envelope
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + cur_inc, TAU)
