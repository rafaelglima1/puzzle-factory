class_name EntityState
extends RefCounted
## Generic logical entity states with stable serialized names.
##
## M1 defines a conservative baseline transition graph. Gameplay milestones
## (M2+) extend the graph, never silently reinterpret it (blueprint §100).

enum Value { IDLE, BLOCKED, MOVING, WAITING, LOADING, UNLOADING, COMPLETED, DISABLED }

const _NAMES := {
	Value.IDLE: &"idle",
	Value.BLOCKED: &"blocked",
	Value.MOVING: &"moving",
	Value.WAITING: &"waiting",
	Value.LOADING: &"loading",
	Value.UNLOADING: &"unloading",
	Value.COMPLETED: &"completed",
	Value.DISABLED: &"disabled",
}

const _TRANSITIONS := {
	Value.IDLE: [Value.MOVING, Value.BLOCKED, Value.DISABLED],
	Value.BLOCKED: [Value.IDLE, Value.MOVING],
	Value.MOVING: [Value.IDLE, Value.BLOCKED, Value.WAITING, Value.LOADING, Value.COMPLETED],
	Value.WAITING: [Value.IDLE, Value.MOVING, Value.DISABLED],
	Value.LOADING: [Value.IDLE, Value.UNLOADING, Value.COMPLETED],
	Value.UNLOADING: [Value.IDLE, Value.COMPLETED],
	Value.COMPLETED: [],
	Value.DISABLED: [Value.IDLE],
}

## States in which an entity may accept a movement command.
const _MOVABLE := [Value.IDLE, Value.BLOCKED, Value.WAITING, Value.LOADING, Value.UNLOADING]


static func is_valid(value: int) -> bool:
	return _NAMES.has(value)


static func to_string_name(value: int) -> StringName:
	return _NAMES.get(value, &"")


static func from_string_name(name: StringName) -> int:
	for value in _NAMES:
		if _NAMES[value] == name:
			return value
	return -1


static func can_transition(from_state: int, to_state: int) -> bool:
	if not is_valid(from_state) or not is_valid(to_state):
		return false
	if from_state == to_state:
		return true
	return _TRANSITIONS[from_state].has(to_state)


static func can_receive_move(state: int) -> bool:
	return _MOVABLE.has(state)
