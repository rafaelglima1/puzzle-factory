class_name Objective
extends RefCounted
## Generic objective contract (blueprint §15). Theme-independent.
##
## Objectives are evaluated on demand from [GameState]; progress is not
## stored inside the objective, so there is no drift between the objective and
## the state. M2 implements CLEAR_ALL only. Future objective types extend this
## base and are added to [ObjectiveFactory].

const TYPE_CLEAR_ALL := &"clear_all"

var id: StringName = &""
var objective_type: StringName = &""
var mandatory: bool = true


func _init(p_id: StringName = &"", p_objective_type: StringName = &"") -> void:
	id = p_id
	objective_type = p_objective_type


## Returns true when the objective is satisfied by the given state.
func is_complete(_state: GameState) -> bool:
	return false


## Optional human/debug summary of progress; must stay primitive and
## deterministic (no user-facing localized text).
func describe(_state: GameState) -> Dictionary:
	return {"objective_type": String(objective_type), "mandatory": mandatory}


func logical_equals(other: Objective) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"objective_type": String(objective_type),
		"mandatory": mandatory,
	}


static func from_dictionary(data: Dictionary) -> Objective:
	return ObjectiveFactory.from_dictionary(data)
