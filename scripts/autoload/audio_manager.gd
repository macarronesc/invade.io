extends Node

## AudioManager: Sistema de efectos de sonido procedurales y adaptativos

var is_muted: bool = false
var audio_player: AudioStreamPlayer
var generator: AudioStreamGenerator

func toggle_mute() -> bool:
	set_muted(not is_muted)
	return is_muted

func set_muted(muted: bool) -> void:
	is_muted = muted
	EventBus.sound_toggled.emit(is_muted)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = &"Master"
	generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 1.5
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
var last_played_fanfare: String = ""
var last_star_sound_index: int = -1
var last_played_sfx: String = ""

const PENTATONIC_REINFORCE = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51] # C5 a E6
const PENTATONIC_HIT = [440.00, 523.25, 587.33, 659.25, 783.99, 880.00, 1046.50]
const STAR_NOTES = [659.25, 783.99, 1046.50] # E5, G5, C6 brillante

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
	last_played_fanfare = "victory"
	if is_muted: return
	# Fanfarria triunfal ascendente y resonante (C5 -> E5 -> G5 -> C6)
	_play_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.10, 0.26)

func play_continent_conquest() -> void:
	last_played_fanfare = "continent_conquest"
	if is_muted: return
	# Fanfarria de Conquista Continental con gran riqueza armónica de metales
	_play_harmonic_fanfare([523.25, 659.25, 783.99], [523.25, 659.25, 1046.50], 0.09, 0.28, 0.30)

func play_star_reveal(star_index: int) -> void:
	last_star_sound_index = star_index
	if is_muted: return
	var idx = star_index if star_index < STAR_NOTES.size() else (star_index - 1)
	idx = clampi(idx, 0, STAR_NOTES.size() - 1)
	var freq = STAR_NOTES[idx]
	# Pop/ding cristalino con armónico superior
	_play_tone(freq, 0.16, 0.25, freq * 1.04)

func play_star_pop(star_index: int) -> void:
	play_star_reveal(star_index)

func play_retreat() -> void:
	last_played_sfx = "retreat"
	if is_muted: return
	# Silbido táctico rápido descendente de retirada
	_play_tone(784.0, 0.08, 0.22, 392.0)

func play_troop_retreat() -> void:
	play_retreat()

func play_slice() -> void:
	last_played_sfx = "retreat"
	if is_muted: return
	# Sonido ágil de corte / estela de cuchilla seguido de silbido táctico
	_play_tone(1046.5, 0.04, 0.20, 523.25)
	_play_tone(784.0, 0.08, 0.22, 392.0)

func play_defeat() -> void:
	if is_muted: return
	# Tono descendente de derrota
	_play_tone(349.23, 0.5, 0.25, 130.81)

func _play_arpeggio(notes: Array, note_duration: float, volume: float = 0.22) -> void:
	if is_muted or not audio_player or not audio_player.is_playing():
		return
	var playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	var sample_rate: float = generator.mix_rate
	for freq in notes:
		var total_frames: int = int(sample_rate * note_duration)
		var available: int = playback.get_frames_available()
		var frames_to_push: int = mini(total_frames, available)
		if frames_to_push <= 0:
			break
		var phase: float = 0.0
		var phase_inc: float = (TAU * float(freq)) / sample_rate
		for i in range(frames_to_push):
			var t: float = float(i) / float(frames_to_push)
			var attack: float = minf(1.0, float(i) / maxf(1.0, float(frames_to_push) * 0.08))
			var release: float = minf(1.0, float(frames_to_push - 1 - i) / maxf(1.0, float(frames_to_push) * 0.15))
			var envelope: float = attack * release * (1.0 - (t * 0.4))
			var sample: float = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * volume * envelope
			playback.push_frame(Vector2(sample, sample))
			phase = fmod(phase + phase_inc, TAU)

func _play_harmonic_fanfare(flourish_notes: Array, chord_notes: Array, flourish_dur: float, chord_dur: float, volume: float = 0.28) -> void:
	if is_muted or not audio_player or not audio_player.is_playing():
		return
	var playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not playback:
		return
	var sample_rate: float = generator.mix_rate
	# 1. Flourish ascendente rápido
	for freq in flourish_notes:
		var total_frames: int = int(sample_rate * flourish_dur)
		var available: int = playback.get_frames_available()
		var frames_to_push: int = mini(total_frames, available)
		if frames_to_push <= 0:
			break
		var phase: float = 0.0
		var phase_inc: float = (TAU * float(freq)) / sample_rate
		for i in range(frames_to_push):
			var t: float = float(i) / float(frames_to_push)
			var attack: float = minf(1.0, float(i) / maxf(1.0, float(frames_to_push) * 0.08))
			var release: float = minf(1.0, float(frames_to_push - 1 - i) / maxf(1.0, float(frames_to_push) * 0.12))
			var envelope: float = attack * release * (1.0 - (t * 0.35))
			# Armónicos ricos para sensación de heraldo regio
			var sample: float = (sin(phase) * 0.65 + sin(phase * 2.0) * 0.22 + sin(phase * 3.0) * 0.13) * volume * envelope
			playback.push_frame(Vector2(sample, sample))
			phase = fmod(phase + phase_inc, TAU)
			
	# 2. Acorde triunfal sostenido polifónico con 4 armónicos
	var chord_frames: int = int(sample_rate * chord_dur)
	var available_chord: int = playback.get_frames_available()
	var frames_chord_push: int = mini(chord_frames, available_chord)
	if frames_chord_push > 0:
		var phases: Array[float] = []
		var phase_incs: Array[float] = []
		for freq in chord_notes:
			phases.append(0.0)
			phase_incs.append((TAU * float(freq)) / sample_rate)
		var num_voices: float = float(maxi(1, chord_notes.size()))
		for i in range(frames_chord_push):
			var t: float = float(i) / float(frames_chord_push)
			var attack: float = minf(1.0, float(i) / maxf(1.0, float(frames_chord_push) * 0.06))
			var release: float = minf(1.0, float(frames_chord_push - 1 - i) / maxf(1.0, float(frames_chord_push) * 0.20))
			var envelope: float = attack * release * (1.0 - (t * t * 0.6))
			var combined: float = 0.0
			for v in range(chord_notes.size()):
				var ph = phases[v]
				var voice_sample = sin(ph) * 0.55 + sin(ph * 2.0) * 0.25 + sin(ph * 3.0) * 0.15 + sin(ph * 4.0) * 0.05
				combined += voice_sample
				phases[v] = fmod(ph + phase_incs[v], TAU)
			var final_sample = (combined / num_voices) * volume * envelope
			playback.push_frame(Vector2(final_sample, final_sample))

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
		var attack: float = minf(1.0, float(i) / maxf(1.0, float(frames_to_push) * 0.08))
		var envelope: float = attack * (1.0 - (t * t))
		# Fundamental + 2º armónico sutil para una textura más cálida y placentera
		var sample: float = (sin(phase) * 0.82 + sin(phase * 2.0) * 0.18) * volume * envelope
		playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + cur_inc, TAU)
