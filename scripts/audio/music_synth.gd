extends RefCounted
class_name MusicSynth

## MusicSynth: compone y sintetiza bucles de música procedural.
## Cada pista es una progresión de acordes con capas (colchón, bajo, arpegio y percusión).
## Las colas de las notas se escriben de forma circular, así que el bucle no tiene costuras.
## Es puro y determinista: se puede ejecutar en un hilo aparte y probar sin audio.

const MIX_RATE := 22050
const PEAK := 0.8

## Acordes en notas MIDI. Menú: Cmaj7 - Am7 - Fmaj7 - G (sereno). Batalla: Am - F - C - G (épico).
const TRACKS = {
	"menu": {
		"bpm": 76, "beats_per_chord": 8,
		"chords": [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]],
		"bass_step": 4.0, "arp_step": 1.0, "drums": false, "seed": 7,
	},
	"battle": {
		"bpm": 104, "beats_per_chord": 8,
		"chords": [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]],
		"bass_step": 1.0, "arp_step": 0.5, "drums": true, "seed": 11,
	},
}

static func midi_to_freq(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

static func loop_seconds(spec: Dictionary) -> float:
	return spec["chords"].size() * spec["beats_per_chord"] * 60.0 / spec["bpm"]

static func render_track(track_id: String) -> PackedFloat32Array:
	return render(TRACKS[track_id])

static func render(spec: Dictionary) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(loop_seconds(spec) * MIX_RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = spec.get("seed", 1)
	var beat: float = 60.0 / spec["bpm"]
	var chord_len: float = spec["beats_per_chord"] * beat

	for c in spec["chords"].size():
		var chord: Array = spec["chords"][c]
		var t0: float = c * chord_len
		# 1. Colchón: el acorde sostenido con ataque y cola lentos
		for note in chord:
			_add_tone(buf, t0, chord_len + 0.9, midi_to_freq(note), 0.055, 0.45, 0.9, 0.0, 0.3)
		# 2. Bajo: la fundamental dos octavas abajo, pulsada
		var step: float = spec["bass_step"] * beat
		var t := 0.0
		while t < chord_len - 0.001:
			_add_tone(buf, t0 + t, minf(step, 0.6), midi_to_freq(chord[0] - 24), 0.16, 0.01, 0.15, 3.5, 0.35)
			t += step
		# 3. Arpegio: recorre las notas del acorde una octava arriba, con variaciones deterministas
		var arp_step: float = spec["arp_step"] * beat
		var k := 0
		t = 0.0
		while t < chord_len - 0.001:
			var note: int = chord[k % chord.size()] + 12
			if rng.randf() < 0.2:
				note += 12
			_add_tone(buf, t0 + t, arp_step * 1.6, midi_to_freq(note), 0.035, 0.005, 0.1, 7.0, 0.1)
			k += 1
			t += arp_step
		# 4. Percusión suave: bombo en las partes fuertes y hi-hat en los contratiempos
		if spec.get("drums", false):
			for b in spec["beats_per_chord"]:
				if b % 2 == 0:
					_add_kick(buf, t0 + b * beat)
				_add_hat(buf, t0 + (b + 0.5) * beat, rng)

	_normalize(buf)
	return buf

## Nota sinusoidal con 2º armónico. `decay` > 0 añade caída exponencial (pulsos); 0 = sostenida.
static func _add_tone(buf: PackedFloat32Array, start: float, duration: float, freq: float, volume: float,
		attack: float, release: float, decay: float, harmonic: float) -> void:
	var n := buf.size()
	var frames := int(duration * MIX_RATE)
	var first := int(start * MIX_RATE)
	var inc := TAU * freq / MIX_RATE
	var attack_frames := maxf(1.0, attack * MIX_RATE)
	var release_frames := maxf(1.0, release * MIX_RATE)
	var phase := 0.0
	for i in frames:
		var env := minf(1.0, i / attack_frames) * minf(1.0, (frames - i) / release_frames)
		if decay > 0.0:
			env *= exp(-decay * i / MIX_RATE)
		var idx := (first + i) % n
		buf[idx] += (sin(phase) + sin(phase * 2.0) * harmonic) * volume * env
		phase += inc

static func _add_kick(buf: PackedFloat32Array, start: float) -> void:
	var n := buf.size()
	var frames := int(0.16 * MIX_RATE)
	var first := int(start * MIX_RATE)
	var phase := 0.0
	for i in frames:
		var x := float(i) / frames
		phase += TAU * lerpf(120.0, 42.0, sqrt(x)) / MIX_RATE
		buf[(first + i) % n] += sin(phase) * 0.30 * (1.0 - x) * (1.0 - x)

static func _add_hat(buf: PackedFloat32Array, start: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var frames := int(0.035 * MIX_RATE)
	var first := int(start * MIX_RATE)
	var prev := 0.0
	for i in frames:
		var noise := rng.randf_range(-1.0, 1.0)
		# Diferencia de muestras: filtro paso alto barato para un siseo metálico
		buf[(first + i) % n] += (noise - prev) * 0.025 * (1.0 - float(i) / frames)
		prev = noise

static func _normalize(buf: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	if peak <= 0.0:
		return
	var gain := PEAK / peak
	for i in buf.size():
		buf[i] *= gain

## Empaqueta muestras como AudioStreamWAV de 16 bits (opcionalmente en bucle sin costuras)
static func to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
