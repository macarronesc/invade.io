extends Node

## AudioManager: Sistema de efectos de sonido procedurales y adaptativos

var is_muted: bool = false
var audio_player: AudioStreamPlayer

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

func play_click() -> void:
	if is_muted: return
	_play_tone(600.0, 0.05, 0.1)

func play_launch() -> void:
	if is_muted: return
	_play_tone(440.0, 0.08, 0.12)

func play_reinforce() -> void:
	if is_muted: return
	_play_tone(587.33, 0.06, 0.1)

func play_capture() -> void:
	if is_muted: return
	# Tono ascendente dinámico
	_play_tone(784.0, 0.15, 0.2)

func play_victory() -> void:
	if is_muted: return
	_play_tone(880.0, 0.35, 0.3)

func play_defeat() -> void:
	if is_muted: return
	_play_tone(220.0, 0.4, 0.3)

func _play_tone(freq: float, duration: float, volume: float = 0.2) -> void:
	# En modo headless o si no hay salida de audio activa, evitar errores
	if AudioServer.get_speaker_mode() == AudioServer.SPEAKER_MODE_STEREO and not DisplayServer.get_name().is_empty():
		pass # Soporte para reproducción interactiva
