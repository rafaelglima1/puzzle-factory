class_name Destination
extends RefCounted
## Generic destination with accepted color keys and a processing capacity
## (blueprint §9.3). Theme-independent: a product/theme layer maps it to a
## concrete concept; the core only knows accepted keys, capacity and state.
##
## Capacity semantics (documented M2 rule):
## - [member capacity] <= 0 means unlimited.
## - [member processed_count] counts items processed by this destination.
## - The destination is FULL once a positive capacity is reached; loading
##   stops there (see docs/GAME_RULES.md).

enum State { OPEN, FULL }

const _STATE_NAMES := {
	State.OPEN: &"open",
	State.FULL: &"full",
}

var id: StringName = &""
var destination_type: StringName = &"generic"
var accepted_color_keys: Array[StringName] = []
var capacity: int = 0
var queue_id: StringName = &""
var state: int = State.OPEN
var processed_count: int = 0
var metadata: Dictionary = {}


func _init(p_id: StringName = &"", p_destination_type: StringName = &"generic") -> void:
	id = p_id
	destination_type = p_destination_type


## Empty accepted list means "accepts everything".
func accepts(color_key: StringName) -> bool:
	if accepted_color_keys.is_empty():
		return true
	return accepted_color_keys.has(color_key)


func has_capacity() -> bool:
	return capacity <= 0 or processed_count < capacity


func is_full() -> bool:
	return capacity > 0 and processed_count >= capacity


## Recomputes [member state] from capacity usage.
func refresh_state() -> void:
	state = State.FULL if is_full() else State.OPEN


func logical_equals(other: Destination) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	var keys: Array = []
	for color_key in accepted_color_keys:
		keys.append(String(color_key))
	return {
		"id": String(id),
		"destination_type": String(destination_type),
		"accepted_color_keys": keys,
		"capacity": capacity,
		"queue_id": String(queue_id),
		"state": String(_STATE_NAMES.get(state, &"")),
		"processed_count": processed_count,
		"metadata": Serialization.canonicalize(metadata),
	}


static func from_dictionary(data: Dictionary) -> Destination:
	var destination := Destination.new(
		StringName(str(data.get("id", ""))),
		StringName(str(data.get("destination_type", "generic")))
	)
	var keys: Variant = data.get("accepted_color_keys", [])
	if typeof(keys) == TYPE_ARRAY:
		for color_key in keys:
			destination.accepted_color_keys.append(StringName(str(color_key)))
	destination.capacity = int(data.get("capacity", 0))
	destination.queue_id = StringName(str(data.get("queue_id", "")))
	destination.processed_count = int(data.get("processed_count", 0))
	destination.state = state_from_string_name(StringName(str(data.get("state", "open"))))
	if destination.state == -1:
		destination.state = State.OPEN
	var metadata: Variant = data.get("metadata", {})
	destination.metadata = Serialization.canonicalize(metadata) if metadata != null else {}
	return destination


static func state_to_string_name(value: int) -> StringName:
	return _STATE_NAMES.get(value, &"")


static func state_from_string_name(name: StringName) -> int:
	for value in _STATE_NAMES:
		if _STATE_NAMES[value] == name:
			return value
	return -1
