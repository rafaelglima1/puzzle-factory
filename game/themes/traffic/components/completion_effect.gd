extends Node2D
## Bounded level-completion presentation. Satisfying but capped at
## MAX_DURATION (2 s) with a skip path after SKIP_AFTER (blueprint §32, §5.5).

signal finished

const MAX_DURATION := 2.0
const DEFAULT_DURATION := 1.4
const SKIP_AFTER := 0.3

var duration := DEFAULT_DURATION
var progress := 0.0
var playing := false

var _elapsed := 0.0


func _ready() -> void:
	set_process(playing)


func play(max_duration: float = DEFAULT_DURATION) -> float:
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


## Returns true when the sequence was actually skipped.
func skip() -> bool:
	if not can_skip():
		return false
	_finish()
	return true


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
	var alpha := 1.0 - progress
	# Sweeping bright arc.
	draw_arc(Vector2.ZERO, 60.0 + progress * 120.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - progress), 48, Color(1.0, 0.86, 0.35, alpha), 6.0, true)
	# Radial sparkles (fixed count, bounded).
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var distance := 20.0 + progress * 130.0
		var point := Vector2(cos(angle), sin(angle)) * distance
		draw_circle(point, 4.0 * alpha + 1.0, Color(1.0, 0.96, 0.75, alpha))
