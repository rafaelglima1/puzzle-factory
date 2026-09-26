extends RefCounted
## Presentation-only view data for one entity (a vehicle in the Traffic theme).
##
## Boundary rule (blueprint §8.2, ADR-003): this object carries NO puzzle
## authority. It never validates movement, occupancy, blocking or matching.
## AGENT-1's simulation (game/core, game/puzzle) stays the single source of
## truth; presentation components only read values supplied to them.

const TYPE_COMPACT := &"compact"
const TYPE_VAN := &"van"
const TYPE_TRUCK := &"truck"
const STATE_IDLE := &"idle"

var id: StringName = &""
var entity_type: StringName = TYPE_COMPACT
var color_key: StringName = &"COLOR_A"
var footprint: Vector2i = Vector2i(2, 1)
var cell: Vector2i = Vector2i.ZERO
var orientation: float = 0.0
var state: StringName = STATE_IDLE
var metadata: Dictionary = {}


func _init(
	p_id: StringName = &"",
	p_type: StringName = TYPE_COMPACT,
	p_color_key: StringName = &"COLOR_A"
) -> void:
	id = p_id
	entity_type = p_type
	color_key = p_color_key


func get_script_instance() -> RefCounted:
	return get_script().new(id, entity_type, color_key)
