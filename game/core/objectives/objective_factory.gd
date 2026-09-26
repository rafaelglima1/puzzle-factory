class_name ObjectiveFactory
extends RefCounted
## Builds objectives from serialized data or type ids.
##
## Kept separate from [Objective] to avoid a cyclic class reference between the
## base and its subclasses. Unknown objective types are reported, never
## silently ignored.

const KNOWN_TYPES: Array[StringName] = [Objective.TYPE_CLEAR_ALL]


static func is_known_type(objective_type: StringName) -> bool:
	return KNOWN_TYPES.has(objective_type)


## Returns null for unknown types (callers validate first for diagnostics).
static func create(objective_type: StringName, id: StringName = &"", mandatory: bool = true) -> Objective:
	match objective_type:
		Objective.TYPE_CLEAR_ALL:
			return ClearAllObjective.new(id if id != &"" else &"clear_all", mandatory)
	return null


static func from_dictionary(data: Dictionary) -> Objective:
	return create(
		StringName(str(data.get("objective_type", ""))),
		StringName(str(data.get("id", ""))),
		bool(data.get("mandatory", true))
	)
