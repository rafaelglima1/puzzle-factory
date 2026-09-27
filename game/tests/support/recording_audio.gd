extends "res://audio/presentation_audio.gd"
## Test-only audio double for the M4 cross-integration suite (AGENT-1 tests).
##
## It records the SFX that were ACCEPTED by the real gating path (Sound ON,
## known id, stream registered) so a test can prove "valid_move requested
## exactly once" through the real controller/session/presenter — which is
## otherwise unobservable, since PresentationAudio only exposes the last SFX.
##
## Gating is unchanged: `super.play()` still returns false when Sound is OFF, so
## nothing is recorded for a silenced cue.

var requested: Array[StringName] = []


func play(sfx: StringName, pitch: float = 1.0) -> bool:
	var accepted := super.play(sfx, pitch)
	if accepted:
		requested.append(sfx)
	return accepted


func requested_count(sfx: StringName) -> int:
	var count := 0
	for entry in requested:
		if entry == sfx:
			count += 1
	return count


func clear_requested() -> void:
	requested.clear()
