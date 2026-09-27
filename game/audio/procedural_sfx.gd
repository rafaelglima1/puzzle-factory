extends RefCounted
## Original, code-generated interaction sounds for M4 (blueprint §60).
##
## The repository ships NO binary audio assets: `presentation_boundary_test`
## forbids audio binaries in presentation dirs and the blueprint requires
## original content (§3). Every required SFX class is therefore synthesized once
## per process into a small 16-bit mono AudioStreamWAV — short UI tones/clicks,
## not music, not copied from any game.
##
## Generated streams are cached statically so repeated presenter builds (and
## tests) reuse the same AudioStream resources.

const Contract := preload("res://audio/audio_contract.gd")

const RATE := 22050

static var _cache: Dictionary = {}


## Returns a generated AudioStream for a known SFX id, or null for unknown ids.
static func build(sfx: StringName) -> AudioStream:
	if _cache.has(sfx):
		return _cache[sfx]
	var stream := _stream_for(sfx)
	if stream != null:
		_cache[sfx] = stream
	return stream


static func is_available(sfx: StringName) -> bool:
	return _stream_for(sfx) != null


static func _stream_for(sfx: StringName) -> AudioStream:
	var samples := PackedFloat32Array()
	match sfx:
		Contract.SFX_TAP:
			samples = _click(0.05, 1500.0, 0.5)
		Contract.SFX_BUTTON:
			samples = _click(0.04, 900.0, 0.42)
		Contract.SFX_VALID_MOVE:
			samples = _sweep(0.16, 320.0, 720.0, 0.5)
		Contract.SFX_BLOCKED_MOVE:
			samples = _knock(0.14, 150.0, 0.7)
		Contract.SFX_LOADING:
			samples = _sweep(0.09, 520.0, 780.0, 0.45)
		Contract.SFX_MATCH:
			samples = _ping(0.22, 880.0, 0.5)
		Contract.SFX_COMBO:
			samples = _combo(0.20, 990.0, 1320.0, 0.5)
		Contract.SFX_LEVEL_COMPLETE:
			samples = _chord([523.25, 659.25, 783.99], 0.5, 0.42)
		Contract.SFX_LEVEL_FAIL:
			samples = _sweep(0.42, 330.0, 180.0, 0.5)
		Contract.SFX_REWARD:
			samples = _combo(0.30, 660.0, 990.0, 0.45)
		_:
			return null
	if samples.is_empty():
		return null
	return _to_stream(samples)


static func _frames(duration: float) -> int:
	return maxi(int(duration * float(RATE)), 1)


## Deterministic pseudo-noise in [-1, 1) (no engine RNG; audio is cosmetic).
static func _noise(index: int) -> float:
	var x := (index * 1103515245 + 12345) & 0x7fffffff
	return float(x) / float(0x3fffffff) - 1.0


static func _click(duration: float, freq: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * 45.0)
		var body := sin(TAU * freq * t) * 0.5
		out[i] = clampf((body + _noise(i) * 0.5) * env * amp, -1.0, 1.0)
	return out


static func _sweep(duration: float, freq_start: float, freq_end: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var progress := t / maxf(duration, 0.0001)
		phase += TAU * lerpf(freq_start, freq_end, progress) / float(RATE)
		var env := exp(-t * 7.0) * (1.0 - 0.35 * progress)
		out[i] = clampf(sin(phase) * env * amp, -1.0, 1.0)
	return out


static func _knock(duration: float, freq: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * 30.0)
		var body := sin(TAU * freq * t) * 0.8
		out[i] = clampf((body + _noise(i) * 0.3) * env * amp, -1.0, 1.0)
	return out


static func _ping(duration: float, freq: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * 10.0)
		var body := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.3
		out[i] = clampf(body * env * amp, -1.0, 1.0)
	return out


static func _combo(duration: float, freq_low: float, freq_high: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var first := sin(TAU * freq_low * t) * exp(-t * 9.0)
		var second_t := maxf(t - 0.08, 0.0)
		var second := sin(TAU * freq_high * second_t) * exp(-second_t * 9.0) * 0.8
		out[i] = clampf((first + second) * 0.6 * amp, -1.0, 1.0)
	return out


static func _chord(freqs: Array, duration: float, amp: float) -> PackedFloat32Array:
	var count := _frames(duration)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / float(RATE)
		var value := 0.0
		for k in freqs.size():
			var start := 0.06 * float(k)
			var local := maxf(t - start, 0.0)
			value += sin(TAU * float(freqs[k]) * local) * exp(-local * 3.5)
		out[i] = clampf(value / float(maxi(freqs.size(), 1)) * amp * 1.3, -1.0, 1.0)
	return out


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)))
	stream.data = bytes
	return stream
