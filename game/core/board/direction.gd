class_name Direction
extends RefCounted
## Logical cardinal direction with stable serialized names.
##
## Board coordinates are row-major with y growing downwards, therefore
## NORTH decreases y and SOUTH increases y.

enum Value { NORTH, EAST, SOUTH, WEST }

const ALL: Array[int] = [Value.NORTH, Value.EAST, Value.SOUTH, Value.WEST]

const _NAMES := {
	Value.NORTH: &"north",
	Value.EAST: &"east",
	Value.SOUTH: &"south",
	Value.WEST: &"west",
}


static func is_valid(value: int) -> bool:
	return _NAMES.has(value)


static func to_string_name(value: int) -> StringName:
	return _NAMES.get(value, &"")


static func from_string_name(name: StringName) -> int:
	for value in _NAMES:
		if _NAMES[value] == name:
			return value
	return -1


static func delta(value: int) -> GridPosition:
	match value:
		Value.NORTH:
			return GridPosition.new(0, -1)
		Value.EAST:
			return GridPosition.new(1, 0)
		Value.SOUTH:
			return GridPosition.new(0, 1)
		Value.WEST:
			return GridPosition.new(-1, 0)
	return GridPosition.new(0, 0)


static func opposite(value: int) -> int:
	match value:
		Value.NORTH:
			return Value.SOUTH
		Value.EAST:
			return Value.WEST
		Value.SOUTH:
			return Value.NORTH
		Value.WEST:
			return Value.EAST
	return -1
