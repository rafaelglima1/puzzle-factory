extends Node2D
## Bounded "blocked move" feedback (blueprint §13.3, §5.5).
##
## Axis-aware short shake + optional blocker flash. Duration is CLAMPED to
## MAX_DURATION (250 ms) and `update()` auto-finishes, so a blocked tap can
## never create an indefinite presentation lock.

signal finished

const MAX_DURATION := 0.25
const DEFAULT_DURATION := 0.18
const SHAKE_CYCLES := 3.0
const DEFAULT_AMPLITUDE := 10.0

var duration := DEFAULT_DURATION
var amplitude := DEFAULT_AMPLITUDE
var axis := Vector2.RIGHT
var playing := false
var blocker_cell := Vector2i(-1, -1)
var blocker_flash := 0.0

var _elapsed := 0.0


func _ready() -> void:
	set_process(playing)


## Returns the granted (clamped) duration. `amplitude` lets the caller use a
## softer nudge for generic rejections.
func play(
	shake_axis: Vector2 = Vector2.RIGHT,
	max_duration: float = DEFAULT_DURATION,
	amplitude: float = DEFAULT_AMPLITUDE
) -> float:
	duration = clampf(max_duration, 0.05, MAX_DURATION)
	axis = shake_axis.normalized() if shake_axis.length() > 0.0 else Vector2.RIGHT
	self.amplitude = clampf(amplitude, 1.0, 24.0)
	_elapsed = 0.0
	playing = true
	set_process(true)
	return duration


func update(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	var t := clampf(_elapsed / duration, 0.0, 1.0)
	position = axis * sin(t * TAU * SHAKE_CYCLES) * amplitude * (1.0 - t)
	blocker_flash = 1.0 - t
	queue_redraw()
	if t >= 1.0:
		stop(true)


func stop(emit_finished: bool = false) -> void:
	var was_playing := playing
	playing = false
	position = Vector2.ZERO
	blocker_flash = 0.0
	set_process(false)
	queue_redraw()
	if emit_finished and was_playing:
		finished.emit()


func set_blocker_cell(cell: Vector2i) -> void:
	blocker_cell = cell
	queue_redraw()


func _process(delta: float) -> void:
	update(delta)


func _draw() -> void:
	if blocker_flash <= 0.0:
		return
	var flash := Color(0.95, 0.25, 0.25, 0.65 * blocker_flash)
	# M4: two concentric arcs give a clearer "blocked edge pulse".
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, flash, 5.0, true)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Color(1.0, 0.62, 0.25, 0.5 * blocker_flash), 3.0, true)
