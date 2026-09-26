extends RefCounted
## Presentation-side haptics facade (blueprint §61).
##
## Display-only: puzzle logic never depends on vibration. Restraint rules:
## - only three patterns: light / warning / success;
## - a global cooldown suppresses machine-gun vibration;
## - hardware calls are attempted only on mobile, so desktop/editor/tests are
##   safe no-ops;
## - a master toggle can disable haptics entirely.

const LIGHT := &"light"
const WARNING := &"warning"
const SUCCESS := &"success"

const DURATION_MS := {
	LIGHT: 15,
	WARNING: 30,
	SUCCESS: 45,
}

var enabled := true
var cooldown_ms := 150

var trigger_count := 0
var last_pattern: StringName = &""

var _last_time_ms := -1000000


## Returns true when a haptic was emitted. `now_ms` is injectable for tests.
func trigger(pattern: StringName, now_ms: int = -1) -> bool:
	if not enabled:
		return false
	if not DURATION_MS.has(pattern):
		return false
	var now := now_ms if now_ms >= 0 else Time.get_ticks_msec()
	if now - _last_time_ms < cooldown_ms:
		return false
	_last_time_ms = now
	trigger_count += 1
	last_pattern = pattern
	if _hardware_available():
		Input.vibrate_handheld(DURATION_MS[pattern])
	return true


func set_enabled(value: bool) -> void:
	enabled = value


func reset_cooldown() -> void:
	_last_time_ms = -1000000


func _hardware_available() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")
