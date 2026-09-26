extends RefCounted
## Presentation-only view data for one item (a passenger in the Traffic theme).
##
## Display only: no queue (FIFO) logic, no matching rules. Values are supplied
## by the simulation/presentation bridge (blueprint §8.2, ADR-003).

const TYPE_PASSENGER := &"passenger_standard"

var id: StringName = &""
var item_type: StringName = TYPE_PASSENGER
var color_key: StringName = &"COLOR_A"
var destination_id: StringName = &""
var metadata: Dictionary = {}


func _init(
	p_id: StringName = &"",
	p_type: StringName = TYPE_PASSENGER,
	p_color_key: StringName = &"COLOR_A"
) -> void:
	id = p_id
	item_type = p_type
	color_key = p_color_key
