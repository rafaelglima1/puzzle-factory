extends Node2D
## Bounded level-completion presentation. Satisfying but capped at
## MAX_DURATION (2 s) with a skip path after SKIP_AFTER (blueprint §32, §5.5).

signal finished

const MAX_DURATION := 2.0
const DEFAULT_DURATION := 1.4
const SKIP_AFTER := 0.3
const CONFETTI_COUNT := 16
## Fixed palette (bounded draws; matches the accessibility color family).
const CONFETTI_COLORS := [
	Color(1.0, 0.86, 0.35, 1.0),
	Color(1.0, 0.96, 0.80, 1.0),
	Color(0.45, 0.70, 1.0, 1.0),
	Color(1.0, 0.62, 0.25, 1.0),
]

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
	# Board glow: a bounded translucent wash that fades early.
	draw_rect(
		Rect2(Vector2(-500.0, -700.0), Vector2(1000.0, 1400.0)),
		Color(1.0, 0.86, 0.35, 0.10 * alpha * alpha)
	)
	# Two sweeping rings for a layered success read.
	draw_arc(
		Vector2.ZERO, 60.0 + progress * 120.0,
		-PI * 0.5, -PI * 0.5 + TAU * (1.0 - progress), 48,
		Color(1.0, 0.86, 0.35, alpha), 6.0, true
	)
	draw_arc(
		Vector2.ZERO, 30.0 + progress * 170.0,
		PI * 0.5, PI * 0.5 + TAU * (1.0 - progress), 40,
		Color(1.0, 0.95, 0.60, 0.7 * alpha), 4.0, true
	)
	# Confetti-like fixed particles (bounded count, simple deterministic fall).
	for i in CONFETTI_COUNT:
		var angle := TAU * float(i) / float(CONFETTI_COUNT) + progress * 1.5
		var distance := 24.0 + progress * 150.0
		var fall := progress * progress * 90.0
		var point := Vector2(cos(angle) * distance, sin(angle) * distance + fall)
		var tint: Color = CONFETTI_COLORS[i % CONFETTI_COLORS.size()]
		draw_circle(point, 5.0 * alpha + 1.0, Color(tint.r, tint.g, tint.b, alpha))
