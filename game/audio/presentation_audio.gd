extends RefCounted
## Presentation-side audio facade (blueprint §60).
##
## No assets ship in this scaffold: streams are registered by a future theme /
## M4 integration step. `play()` is a safe no-op when a stream is not
## registered, so gameplay and tests never depend on audio availability.
## Real AudioStreamPlayer pooling + bus routing is deferred to M4 and must not
## change the shared project bus layout without integration approval.

const Contract := preload("res://audio/audio_contract.gd")

var enabled := true
var play_count := 0
var last_sfx: StringName = &""

var _streams: Dictionary = {}


func register_stream(sfx: StringName, stream: Variant) -> void:
	if stream != null:
		_streams[sfx] = stream


func unregister_stream(sfx: StringName) -> void:
	_streams.erase(sfx)


func has_stream(sfx: StringName) -> bool:
	return _streams.has(sfx)


func stream_count() -> int:
	return _streams.size()


## Returns true when a stream would have played. Never throws, never blocks.
func play(sfx: StringName, pitch: float = 1.0) -> bool:
	if not enabled:
		return false
	if not Contract.is_known(sfx):
		return false
	if not _streams.has(sfx):
		return false
	play_count += 1
	last_sfx = sfx
	# M4: route through a pooled AudioStreamPlayer on Contract.bus_for(sfx).
	return true


func set_enabled(value: bool) -> void:
	enabled = value
