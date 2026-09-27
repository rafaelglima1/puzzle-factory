extends Control
## Responsive staging-area view (blueprint §3.4, §5).
##
## Renders an ARBITRARY supplied slot count and receives pressure state. It
## never decides occupancy, warning or full (blueprint §8.2). Slots are laid
## out by an HBoxContainer so the band adapts to any width / aspect.

const DataScript := preload("res://themes/traffic/model_staging_view_data.gd")
const SlotScript := preload("res://themes/traffic/components/staging_slot_view.gd")

const SLOT_MIN_SIZE := Vector2(64.0, 64.0)
const SLOT_SEPARATION := 10
const PULSE_DURATION := 0.35

var data: DataScript = null

var _row: HBoxContainer = null
var _slot_nodes: Array = []
var _pulse_remaining := 0.0
var _last_pressure: StringName = DataScript.PRESSURE_NORMAL


func _init() -> void:
	_row = HBoxContainer.new()
	_row.name = "SlotRow"
	_row.add_theme_constant_override("separation", SLOT_SEPARATION)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


func set_staging_data(value: DataScript) -> void:
	data = value
	_rebuild()
	queue_redraw()


func get_staging_data() -> DataScript:
	return data


func slot_count() -> int:
	return _slot_nodes.size()


func get_slot_nodes() -> Array:
	return _slot_nodes.duplicate()


func set_pressure(state: StringName) -> void:
	if data == null:
		return
	var previous := _last_pressure
	data.pressure = state
	_last_pressure = state
	if state != previous and (state == DataScript.PRESSURE_WARNING or state == DataScript.PRESSURE_FULL):
		_pulse_remaining = PULSE_DURATION
	_apply_pressure()
	_apply_pulse_strength(_pulse_strength())
	queue_redraw()


## Bounded pressure pulse; driven by the presenter's advance/_process.
func advance(delta: float) -> void:
	if _pulse_remaining <= 0.0:
		return
	_pulse_remaining = maxf(_pulse_remaining - delta, 0.0)
	_apply_pulse_strength(_pulse_strength())


func _pulse_strength() -> float:
	if _pulse_remaining <= 0.0:
		return 0.0
	return _pulse_remaining / PULSE_DURATION


func _apply_pulse_strength(strength: float) -> void:
	for slot: Variant in _slot_nodes:
		if is_instance_valid(slot):
			slot.set_pulse(strength)


func pressure() -> StringName:
	return data.pressure if data != null else DataScript.PRESSURE_NORMAL


func _rebuild() -> void:
	for slot: Variant in _slot_nodes:
		if is_instance_valid(slot):
			_row.remove_child(slot)
			slot.free()
	_slot_nodes.clear()
	var count: int = data.slot_count if data != null else 0
	for i in count:
		var slot: SlotScript = SlotScript.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = SLOT_MIN_SIZE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_row.add_child(slot)
		var occupant: Variant = data.occupant_at(i) if data != null else null
		if occupant != null:
			slot.set_entity(occupant)
		_slot_nodes.append(slot)
	_apply_pressure()
	_pulse_remaining = 0.0
	_apply_pulse_strength(0.0)
	_last_pressure = pressure()


func _apply_pressure() -> void:
	var state := pressure()
	for slot: Variant in _slot_nodes:
		if is_instance_valid(slot):
			slot.set_pressure_state(state)
