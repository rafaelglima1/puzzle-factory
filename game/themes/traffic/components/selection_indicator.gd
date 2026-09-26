extends Node2D
## Selection ring for a selected entity. Fast, clear, hue-independent feedback
## (blueprint §32, §59).

const RING_COLOR := Color(1.0, 0.92, 0.35, 0.95)
const RING_WIDTH := 4.0
const PULSE_SECONDS := 0.35
const PULSE_SCALE := 0.12

var radius := 40.0
var active := false

var _phase := 0.0


func _ready() -> void:
	set_process(active)


func set_radius(value: float) -> void:
	radius = maxf(value, 1.0)
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	visible = value
	_phase = 0.0
	set_process(value)
	queue_redraw()


func is_active() -> bool:
	return active


func update(delta: float) -> void:
	if not active:
		return
	_phase = fmod(_phase + delta, PULSE_SECONDS)
	queue_redraw()


func pulse_scale() -> float:
	if not active:
		return 1.0
	var t := _phase / PULSE_SECONDS
	return 1.0 + sin(t * TAU) * PULSE_SCALE


func _process(delta: float) -> void:
	update(delta)


func _draw() -> void:
	if not active:
		return
	draw_arc(Vector2.ZERO, radius * pulse_scale(), 0.0, TAU, 40, RING_COLOR, RING_WIDTH, true)
