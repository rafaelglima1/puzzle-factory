class_name RandomSource
extends RefCounted
## Deterministic random source contract (blueprint §11).
##
## Gameplay/simulation code must never instantiate uncontrolled randomness
## (no engine RNG singletons, no wall-clock seeding). It must use a
## [RandomSource] implementation whose full state is serializable so that a
## seed + operation sequence reproduces identical output anywhere, and so
## that replay/undo/solver (M2/M6/M11) can restore exact state.
##
## Subclasses implement [method next_int], [method get_state] and
## [method set_state]. Range and shuffle helpers are concrete and built on
## [method next_int] so every implementation stays deterministic.

## Returns the next raw non-negative integer of the source.
func next_int() -> int:
	push_error("RandomSource.next_int() must be implemented by a subclass")
	return 0


## Returns a deterministic integer in [code][min_value, max_value][/code] inclusive.
func next_int_range(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		return min_value
	var span := max_value - min_value + 1
	var value := next_int()
	return min_value + value % span


## Returns a deterministic float in [code][0.0, 1.0)[/code].
func next_float() -> float:
	return 0.0


## Returns the full internal state (JSON-safe primitives) for persistence.
func get_state() -> Dictionary:
	return {}


## Restores internal state previously produced by [method get_state].
func set_state(_state: Dictionary) -> void:
	push_error("RandomSource.set_state() must be implemented by a subclass")


## Deterministic Fisher-Yates shuffle; returns a new array, never mutates input.
func shuffled_copy(items: Array) -> Array:
	var result: Array = items.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := next_int_range(0, index)
		var temporary: Variant = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result
