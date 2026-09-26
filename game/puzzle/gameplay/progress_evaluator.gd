class_name ProgressEvaluator
extends RefCounted
## Generic progress evaluation after a state change: objective completion,
## victory and the NO_VALID_MOVES loss (blueprint §15, §16).
##
## Deterministic rules:
## - Objectives are evaluated in their stored order; each objective emits
##   [constant DomainEvent.OBJECTIVE_COMPLETED] at most once (tracked in
##   [member GameState.objectives_completed]).
## - Victory requires at least one mandatory objective and all mandatory
##   objectives complete.
## - NO_VALID_MOVES is raised when no placed, operable entity has an
##   unobstructed valid path. A move that would immediately lose the level
##   (e.g. staging full) still counts as available; the loss happens when the
##   player takes it.

const OUTCOME_IN_PROGRESS := &"in_progress"
const OUTCOME_WON := &"won"
const OUTCOME_LOST := &"lost"


## Mutates state/emits events. Returns:
## { completed_objectives: Array[StringName], outcome: StringName, fail_reason: StringName }
func evaluate(context: CommandContext) -> Dictionary:
	var state := context.state
	var completed_now: Array[StringName] = []
	if not state.is_in_progress():
		return {
			"completed_objectives": completed_now,
			"outcome": OUTCOME_WON if state.is_won() else OUTCOME_LOST,
			"fail_reason": state.fail_reason,
		}

	for objective in state.objectives:
		if state.is_objective_completed(objective.id):
			continue
		if objective.is_complete(state):
			state.mark_objective_completed(objective.id)
			completed_now.append(objective.id)
			context.emit_event(DomainEvent.objective_completed(objective.id, objective.objective_type))

	if not state.mandatory_objectives().is_empty() and state.all_mandatory_objectives_completed():
		state.set_victory()
		context.emit_event(DomainEvent.game_completed(state.level_id, state.move_index))
		return {
			"completed_objectives": completed_now,
			"outcome": OUTCOME_WON,
			"fail_reason": &"",
		}

	if not has_valid_move(state):
		var reason := FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES)
		state.set_failure(reason)
		context.emit_event(DomainEvent.game_failed(reason, state.move_index))
		return {
			"completed_objectives": completed_now,
			"outcome": OUTCOME_LOST,
			"fail_reason": reason,
		}

	return {
		"completed_objectives": completed_now,
		"outcome": OUTCOME_IN_PROGRESS,
		"fail_reason": &"",
	}


## True when at least one placed, operable entity has a valid, unblocked path.
static func has_valid_move(state: GameState) -> bool:
	for entity_id in state.entity_ids():
		var entity: Entity = state.entities[entity_id]
		if not entity.is_placed():
			continue
		if not EntityState.can_receive_move(entity.state):
			continue
		if entity.path_id == &"":
			continue
		var path := state.get_path(entity.path_id)
		if path == null:
			continue
		if not path.is_valid(state.board.dimensions):
			continue
		if path.blockers_on(state.board, entity.id).is_empty():
			return true
	return false
