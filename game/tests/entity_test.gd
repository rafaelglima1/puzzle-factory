extends "res://tests/framework/test_base.gd"
## Generic entity model: identity, defaults, states, directions, serialization.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_defaults()
	_states()
	_directions()
	_serialization()
	_equality()


func _defaults() -> void:
	var entity := Entity.new(&"e1", &"unit")
	check_eq(entity.id, &"e1", "id")
	check_eq(entity.entity_type, &"unit", "entity type")
	check_eq(entity.state, EntityState.Value.IDLE, "default state is idle")
	check_eq(entity.orientation, Direction.Value.NORTH, "default orientation is north")
	check_eq(entity.capacity, 0, "default capacity")
	check_eq(entity.color_key, &"", "default color key is empty")
	check_eq(entity.movement_type, &"", "default movement type is empty")
	check(not entity.is_placed(), "entity starts unplaced")
	check(entity.footprint.equals(Footprint.new(1, 1)), "default footprint is 1x1")
	check(entity.metadata.is_empty(), "metadata empty by default")
	check(entity.can_receive_move(), "idle entity can receive a move")
	var other := Entity.new(&"e2", &"unit")
	check(entity.id != other.id, "ids are independent between instances")


func _states() -> void:
	check(EntityState.can_transition(EntityState.Value.IDLE, EntityState.Value.MOVING), "idle -> moving allowed")
	check(EntityState.can_transition(EntityState.Value.IDLE, EntityState.Value.IDLE), "same-state transition allowed")
	check(not EntityState.can_transition(EntityState.Value.IDLE, EntityState.Value.LOADING), "idle -> loading not allowed in M1 baseline")
	check(not EntityState.can_transition(EntityState.Value.COMPLETED, EntityState.Value.IDLE), "completed is terminal")
	check(EntityState.can_transition(EntityState.Value.DISABLED, EntityState.Value.IDLE), "disabled can be re-enabled")
	check(EntityState.can_transition(EntityState.Value.LOADING, EntityState.Value.UNLOADING), "loading -> unloading allowed")
	check(not EntityState.can_transition(EntityState.Value.IDLE, 999), "unknown target state rejected")
	check(EntityState.is_valid(EntityState.Value.WAITING), "known state value valid")
	check(not EntityState.is_valid(999), "unknown state value invalid")
	check_eq(EntityState.from_string_name(&"unknown_state"), -1, "unknown state name invalid")

	var entity := Entity.new(&"e1", &"unit")
	check(entity.set_state(EntityState.Value.MOVING), "valid transition applied")
	check_eq(entity.state, EntityState.Value.MOVING, "state updated")
	check(not entity.set_state(EntityState.Value.DISABLED), "invalid transition rejected")
	check_eq(entity.state, EntityState.Value.MOVING, "state unchanged after invalid transition")
	check(entity.set_state(EntityState.Value.IDLE), "moving -> idle allowed")
	check(EntityState.can_receive_move(EntityState.Value.IDLE), "idle can receive a move")
	check(not EntityState.can_receive_move(EntityState.Value.COMPLETED), "completed cannot receive a move")
	check_eq(EntityState.to_string_name(EntityState.Value.UNLOADING), &"unloading", "state name is stable")
	check_eq(EntityState.from_string_name(&"unloading"), EntityState.Value.UNLOADING, "state name roundtrips")


func _directions() -> void:
	check(Direction.is_valid(Direction.Value.WEST), "west is valid")
	check(not Direction.is_valid(42), "unknown direction value invalid")
	check(Direction.delta(Direction.Value.NORTH).equals(GridPosition.new(0, -1)), "north delta decreases y")
	check(Direction.delta(Direction.Value.EAST).equals(GridPosition.new(1, 0)), "east delta increases x")
	check(Direction.delta(Direction.Value.SOUTH).equals(GridPosition.new(0, 1)), "south delta increases y")
	check(Direction.delta(Direction.Value.WEST).equals(GridPosition.new(-1, 0)), "west delta decreases x")
	check_eq(Direction.from_string_name(&"east"), Direction.Value.EAST, "direction name roundtrips")
	check_eq(Direction.from_string_name(&"nowhere"), -1, "unknown direction name invalid")
	check_eq(Direction.opposite(Direction.Value.EAST), Direction.Value.WEST, "opposite direction")
	check_eq(Direction.to_string_name(Direction.Value.SOUTH), &"south", "direction name is stable")

	var entity := Entity.new(&"e1", &"unit")
	check(entity.has_allowed_direction(Direction.Value.NORTH), "empty allowed list means unrestricted")
	entity.allowed_directions = [Direction.Value.EAST]
	check(entity.has_allowed_direction(Direction.Value.EAST), "allowed direction accepted")
	check(not entity.has_allowed_direction(Direction.Value.WEST), "other direction rejected")


func _serialization() -> void:
	var entity := Fixture.make_entity(&"e1", 2, 1)
	entity.position = GridPosition.new(1, 2)
	entity.color_key = &"COLOR_A"
	entity.capacity = 3
	entity.movement_type = &"path_follower"
	entity.allowed_directions = [Direction.Value.EAST, Direction.Value.SOUTH]
	entity.path_id = &"path_1"
	entity.destination_id = &"destination_1"
	entity.state = EntityState.Value.WAITING
	entity.metadata = {"nested": {"b": 2, "a": 1}, "list": [3, 2, 1], "flag": true}

	var restored := Entity.from_dictionary(entity.to_dictionary())
	check_eq(restored.id, entity.id, "id restored")
	check(restored.footprint.equals(entity.footprint), "footprint restored")
	check(restored.position.equals(entity.position), "position restored")
	check_eq(restored.color_key, entity.color_key, "color key restored")
	check_eq(restored.capacity, entity.capacity, "capacity restored")
	check_eq(restored.movement_type, entity.movement_type, "movement type restored")
	check_eq(restored.path_id, entity.path_id, "path id restored")
	check_eq(restored.destination_id, entity.destination_id, "destination id restored")
	check_eq(restored.state, entity.state, "state restored")
	check_eq(restored.orientation, entity.orientation, "orientation restored")
	check_eq(restored.allowed_directions, entity.allowed_directions, "allowed directions restored")
	check(restored.logical_equals(entity), "logical equality after roundtrip")
	check(restored.metadata.has("nested"), "metadata restored")

	var unplaced := Entity.new(&"u1", &"unit")
	var restored_unplaced := Entity.from_dictionary(unplaced.to_dictionary())
	check(restored_unplaced.position == null, "unplaced entity restores a null position")
	check(not restored_unplaced.is_placed(), "restored unplaced entity is not placed")


func _equality() -> void:
	var first := Fixture.make_entity(&"e1")
	var second := Fixture.make_entity(&"e1")
	check(first.logical_equals(second), "logically equal entities")
	second.capacity = 5
	check(not first.logical_equals(second), "capacity difference breaks equality")
	check(not first.logical_equals(null), "null comparison is safe")
	check(first.logical_equals(first), "self equality")
