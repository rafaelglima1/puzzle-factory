extends Node2D
## Bounded level-failure presentation with a machine-reason hook (blueprint
## §16, §32, §5.5). No localized copy is stored here — only the reason key,
## resolved through localization elsewhere (blueprint §58).

signal finished

const MAX_DURATION := 1.5
const DEFAULT_DURATION := 1.0
const SKIP_AFTER := 0.3

const REASON_KEYS := {
	# Canonical machine-readable ids from the simulation (lowercase).
	&"staging_full": &"level.fail.staging_full",
	&"no_valid_moves": &"level.fail.no_moves",
	&"move_limit_exceeded": &"level.fail.move_limit",
	&"time_limit_exceeded": &"level.fail.time_limit",
	&"special_objective_failed": &"level.fail.special",
	# Uppercase aliases kept for older callers/tests. Lowercase is authoritative.
	&"STAGING_FULL": &"level.fail.staging_full",
	&"NO_VALID_MOVES": &"level.fail.no_moves",
	&"MOVE_LIMIT_EXCEEDED": &"level.fail.move_limit",
	&"TIME_LIMIT_EXCEEDED": &"level.fail.time_limit",
	&"SPECIAL_OBJECTIVE_FAILED": &"level.fail.special",
}
const UNKNOWN_REASON_KEY := &"level.fail.unknown"

var duration := DEFAULT_DURATION
var progress := 0.0
var playing := false
var reason: StringName = &""

var _elapsed := 0.0


func _ready() -> void:
	set_process(playing)


func play(fail_reason: StringName = &"", max_duration: float = DEFAULT_DURATION) -> float:
	reason = fail_reason
	duration = clampf(max_duration, 0.2, MAX_DURATION)
	_elapsed = 0.0
	progress = 0.0
	playing = true
	set_process(true)
	queue_redraw()
	return duration


func update(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	progress = clampf(_elapsed / duration, 0.0, 1.0)
	queue_redraw()
	if progress >= 1.0:
		_finish()


func can_skip() -> bool:
	return playing and _elapsed >= SKIP_AFTER


func skip() -> bool:
	if not can_skip():
		return false
	_finish()
	return true


func reason_localization_key() -> StringName:
	return localization_key_for(reason)


## Maps a machine `fail_reason` to a localization key. The canonical ids are the
## simulation's lowercase machine ids (`staging_full`, `no_valid_moves`);
## uppercase aliases remain accepted for compatibility. Unknown reasons fall
## back to a generic key; internal enum names are never surfaced to users.
static func localization_key_for(fail_reason: StringName) -> StringName:
	if REASON_KEYS.has(fail_reason):
		return REASON_KEYS[fail_reason]
	var lowered := StringName(String(fail_reason).to_lower())
	if REASON_KEYS.has(lowered):
		return REASON_KEYS[lowered]
	return UNKNOWN_REASON_KEY


func stop() -> void:
	playing = false
	set_process(false)
	queue_redraw()


func _finish() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	queue_redraw()
	finished.emit()


func _process(delta: float) -> void:
	update(delta)


func _draw() -> void:
	if not playing and progress <= 0.0:
		return
	var alpha := (1.0 - progress) * 0.55
	# Board tint (bounded overlay, fades out).
	draw_rect(
		Rect2(Vector2(-500.0, -700.0), Vector2(1000.0, 1400.0)),
		Color(0.55, 0.06, 0.10, alpha)
	)
	# Staging warning band along the bottom edge.
	draw_rect(
		Rect2(Vector2(-500.0, 520.0), Vector2(1000.0, 60.0)),
		Color(0.95, 0.63, 0.13, (1.0 - progress) * 0.5)
	)
	# Short impact bars for a brief "thud".
	for i in 3:
		var offset := float(i) * 26.0
		draw_rect(
			Rect2(Vector2(-260.0 + offset, -60.0), Vector2(14.0, 120.0)),
			Color(1.0, 0.85, 0.60, alpha * 0.5)
		)
