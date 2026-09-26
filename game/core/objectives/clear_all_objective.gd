class_name ClearAllObjective
extends Objective
## Default M2 objective: every item processed AND every entity completed
## (blueprint §15). Items leave the item registry once processed, so
## "all items processed" is equivalent to "the item registry is empty".


func _init(p_id: StringName = &"clear_all", p_mandatory: bool = true) -> void:
	super(p_id, Objective.TYPE_CLEAR_ALL)
	mandatory = p_mandatory


func is_complete(state: GameState) -> bool:
	if state == null:
		return false
	if not state.items.is_empty():
		return false
	for entity_id in state.entity_ids():
		if state.entities[entity_id].state != EntityState.Value.COMPLETED:
			return false
	return true


func describe(state: GameState) -> Dictionary:
	var completed_entities := 0
	for entity_id in state.entity_ids():
		if state.entities[entity_id].state == EntityState.Value.COMPLETED:
			completed_entities += 1
	return {
		"objective_type": String(objective_type),
		"mandatory": mandatory,
		"remaining_items": state.items.size(),
		"completed_entities": completed_entities,
		"total_entities": state.entity_count(),
	}
