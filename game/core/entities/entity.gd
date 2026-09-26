class_name Entity
extends RefCounted
## Theme-independent logical entity (blueprint §9.1).
##
## The core understands generic concepts only (blueprint §8.1). A theme maps
## these generic fields to presentation data; it can never change rules.
##
## [member position] is managed exclusively by [Board] placement/movement so
## the occupancy index and the entity can never diverge (see [Board]).

var id: StringName = &""
var entity_type: StringName = &""
var position: GridPosition = null
var orientation: int = Direction.Value.NORTH
var footprint: Footprint = null
var color_key: StringName = &""
var capacity: int = 0
var movement_type: StringName = &""
var allowed_directions: Array[int] = []
var path_id: StringName = &""
var destination_id: StringName = &""
var state: int = EntityState.Value.IDLE
var metadata: Dictionary = {}


func _init(p_id: StringName = &"", p_entity_type: StringName = &"", p_footprint: Footprint = null) -> void:
	id = p_id
	entity_type = p_entity_type
	footprint = p_footprint if p_footprint != null else Footprint.new(1, 1)


func is_placed() -> bool:
	return position != null


func has_allowed_direction(direction: int) -> bool:
	if allowed_directions.is_empty():
		return true
	return allowed_directions.has(direction)


func can_receive_move() -> bool:
	return EntityState.can_receive_move(state)


func set_state(new_state: int) -> bool:
	if not EntityState.can_transition(state, new_state):
		return false
	state = new_state
	return true


func logical_equals(other: Entity) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"entity_type": String(entity_type),
		"position": position.to_dictionary() if position != null else null,
		"orientation": String(Direction.to_string_name(orientation)),
		"footprint": footprint.to_dictionary(),
		"color_key": String(color_key),
		"capacity": capacity,
		"movement_type": String(movement_type),
		"allowed_directions": _allowed_direction_names(),
		"path_id": String(path_id),
		"destination_id": String(destination_id),
		"state": String(EntityState.to_string_name(state)),
		"metadata": Serialization.canonicalize(metadata),
	}


static func from_dictionary(data: Dictionary) -> Entity:
	var entity := Entity.new(
		StringName(str(data.get("id", ""))),
		StringName(str(data.get("entity_type", ""))),
		Footprint.from_dictionary(data.get("footprint", {}))
	)
	var position: Variant = data.get("position")
	entity.position = null if position == null else GridPosition.from_dictionary(position)
	entity.orientation = Direction.from_string_name(StringName(str(data.get("orientation", "north"))))
	if not Direction.is_valid(entity.orientation):
		entity.orientation = Direction.Value.NORTH
	entity.color_key = StringName(str(data.get("color_key", "")))
	entity.capacity = int(data.get("capacity", 0))
	entity.movement_type = StringName(str(data.get("movement_type", "")))
	entity.allowed_directions = _directions_from_names(data.get("allowed_directions", []))
	entity.path_id = StringName(str(data.get("path_id", "")))
	entity.destination_id = StringName(str(data.get("destination_id", "")))
	entity.state = EntityState.from_string_name(StringName(str(data.get("state", "idle"))))
	if not EntityState.is_valid(entity.state):
		entity.state = EntityState.Value.IDLE
	var metadata: Variant = data.get("metadata", {})
	entity.metadata = Serialization.canonicalize(metadata) if metadata != null else {}
	return entity


func _allowed_direction_names() -> Array:
	var names: Array = []
	for direction in allowed_directions:
		names.append(String(Direction.to_string_name(direction)))
	return names


static func _directions_from_names(names: Variant) -> Array[int]:
	var directions: Array[int] = []
	if typeof(names) != TYPE_ARRAY:
		return directions
	for name in names:
		var value := Direction.from_string_name(StringName(str(name)))
		if Direction.is_valid(value) and not directions.has(value):
			directions.append(value)
	return directions
