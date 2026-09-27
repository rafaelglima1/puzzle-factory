extends Node2D
## Interpolates an entity view along an EXTERNALLY supplied path.
##
## It never computes whether the path is legal and never reads puzzle state
## (blueprint §8.2, ADR-003). Deterministic waypoints only — physics is never
## authoritative (§8.3). Duration is clamped so movement can never hold the
## board indefinitely.

signal finished(target)

const MAX_DURATION := 0.6
const DEFAULT_SPEED_PX_PER_S := 900.0

var duration := 0.0
var active := false

var _target: Node2D = null
var _points := PackedVector2Array()
var _cumulative := PackedFloat32Array()
var _total := 0.0
var _elapsed := 0.0


func _ready() -> void:
	set_process(active)


## `max_duration < 0` derives duration from path length, then clamps.
## Returns the granted duration (0 when there is nothing to animate).
func move_along(target: Node2D, path_points: PackedVector2Array, max_duration: float = -1.0) -> float:
	_target = target
	_points = path_points
	_rebuild_lengths()
	var requested := max_duration
	if requested < 0.0:
		requested = _total / DEFAULT_SPEED_PX_PER_S
	duration = clampf(requested, 0.0, MAX_DURATION)
	_elapsed = 0.0
	active = _target != null and _points.size() > 0
	set_process(active)
	if not active:
		finished.emit(target)
		return 0.0
	if duration <= 0.0:
		_apply(1.0)
		active = false
		set_process(false)
		finished.emit(target)
	return duration


func update(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	var t := clampf(_elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0
	_apply(t)
	if t >= 1.0:
		active = false
		set_process(false)
		finished.emit(_target)


func stop() -> void:
	active = false
	set_process(false)


func target_node() -> Node2D:
	return _target


## Fast response, ease-out arrival. Deterministic and bounded: t=1 maps to
## exactly 1.0, so the entity always settles on the authoritative endpoint.
static func _ease_out(t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func point_count() -> int:
	return _points.size()


func _rebuild_lengths() -> void:
	_cumulative = PackedFloat32Array()
	_total = 0.0
	if _points.is_empty():
		return
	_cumulative.append(0.0)
	for i in range(1, _points.size()):
		_total += _points[i].distance_to(_points[i - 1])
		_cumulative.append(_total)


func _apply(t: float) -> void:
	if _target == null or _points.is_empty():
		return
	if _points.size() == 1 or _total <= 0.0:
		_target.position = _points[0]
		return
	var distance := _ease_out(t) * _total
	var index := 1
	while index < _cumulative.size() - 1 and _cumulative[index] < distance:
		index += 1
	var segment_start := _cumulative[index - 1]
	var segment_length := _cumulative[index] - segment_start
	var segment_t := 0.0 if segment_length <= 0.0 else (distance - segment_start) / segment_length
	_target.position = _points[index - 1].lerp(_points[index], clampf(segment_t, 0.0, 1.0))


func _process(delta: float) -> void:
	update(delta)
