extends Node2D
## Bounded match/loading burst. Drawn procedurally (no particle nodes, no
## unbounded allocation) and auto-finishes within MAX_DURATION (blueprint §63,
## §32).

signal finished

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")

const MAX_DURATION := 0.6
const DEFAULT_DURATION := 0.5
const DOT_COUNT := 6

var duration := DEFAULT_DURATION
var progress := 0.0
var playing := false
var color := Color.WHITE

var _elapsed := 0.0
var _palette: RefCounted = PaletteScript.new()


func _ready() -> void:
	set_process(playing)


func play(world_position: Vector2, color_key: StringName, max_duration: float = DEFAULT_DURATION) -> float:
	position = world_position
	color = _palette.color_for(color_key)
	duration = clampf(max_duration, 0.1, MAX_DURATION)
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


func stop() -> void:
	playing = false
	set_process(false)
	queue_redraw()


func _finish() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	finished.emit()


func _process(delta: float) -> void:
	update(delta)


func _draw() -> void:
	if not playing:
		return
	var alpha := 1.0 - progress
	var radius := 8.0 + progress * 34.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, alpha), 4.0, true)
	for i in DOT_COUNT:
		var angle := TAU * float(i) / float(DOT_COUNT) + progress * PI
		var dot := Vector2(cos(angle), sin(angle)) * radius
		draw_circle(dot, 3.0 * alpha + 1.0, Color(1, 1, 1, alpha))
