class_name FailReason
extends RefCounted
## Stable, machine-readable loss reasons (blueprint §16).
##
## Simulation never produces user-facing text; presentation maps these stable
## ids to localized copy. [constant Value.NONE] serializes as an empty string.

enum Value { NONE, STAGING_FULL, NO_VALID_MOVES }

const _NAMES := {
	Value.NONE: &"",
	Value.STAGING_FULL: &"staging_full",
	Value.NO_VALID_MOVES: &"no_valid_moves",
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


static func is_known_name(name: StringName) -> bool:
	return from_string_name(name) != -1
