class_name DispatchEntityCommand
extends GameCommand
## M2 gameplay action: dispatch a placed entity along its logical path and
## resolve everything that follows (blueprint §13.2).
##
## Flow (deterministic, validated before any mutation):
## command -> resolve entity -> validate state -> validate path ->
## detect blockers -> (blocked: reject, no mutation) -> apply logical move ->
## emit move events -> resolve arrival (loading / completion / staging) ->
## evaluate objectives -> evaluate win/lose.
##
## In the first product this action is "tap a moving entity". The simulation
## never waits for animation; presentation consumes the emitted events at its
## own pace.
##
## Rejection codes (stable):
## game_not_in_progress, unknown_entity, board_not_ready, entity_not_placed,
## entity_not_movable, unknown_path, invalid_path, path_start_mismatch,
## unknown_destination, cell_occupied, move_failed.
## Note: STAGING_FULL is a legal move that loses the level; the command
## reports success with code "staging_full" (see docs/GAME_RULES.md).

var entity_id: StringName = &""

var _matching_rule: MatchingRule = null


func _init(p_entity_id: StringName = &"", p_matching_rule: MatchingRule = null) -> void:
	entity_id = p_entity_id
	_matching_rule = p_matching_rule


func command_name() -> StringName:
	return &"dispatch_entity"


func execute(context: CommandContext) -> CommandResult:
	var state := context.state

	if not state.is_in_progress():
		return _reject(context, CommandResult.Status.GAME_ALREADY_COMPLETE, &"game_not_in_progress")

	var entity := state.get_entity(entity_id)
	if entity == null:
		return _reject(context, CommandResult.Status.INVALID, &"unknown_entity")
	if not state.board.is_ready():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"board_not_ready")
	if not entity.is_placed():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"entity_not_placed")
	if not entity.can_receive_move():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"entity_not_movable")
	if entity.path_id == &"":
		return _reject(context, CommandResult.Status.INVALID_STATE, &"unknown_path")

	var path := state.get_path(entity.path_id)
	if path == null:
		return _reject(context, CommandResult.Status.INVALID_STATE, &"unknown_path")
	if not path.validate(state.board.dimensions).is_empty():
		return _reject(context, CommandResult.Status.INVALID, &"invalid_path")
	if not path.origin().equals(entity.position):
		return _reject(context, CommandResult.Status.INVALID_STATE, &"path_start_mismatch")

	var destination := state.get_destination(entity.destination_id)
	if destination == null:
		return _reject(context, CommandResult.Status.INVALID_STATE, &"unknown_destination")

	var blocked_cell := path.first_blocked_cell(state.board, entity.id)
	if blocked_cell != null:
		context.emit_event(DomainEvent.entity_blocked(entity.id, blocked_cell, path.blockers_on(state.board, entity.id)))
		return CommandResult.rejected(CommandResult.Status.BLOCKED, &"cell_occupied", context.events)

	# --- validated: apply the logical move ---
	var from_position := entity.position
	var target := path.target()
	if not state.board.move_entity(entity, target):
		return _reject(context, CommandResult.Status.INVALID_STATE, &"move_failed")
	entity.set_state(EntityState.Value.MOVING)
	state.move_index += 1
	context.emit_event(DomainEvent.entity_move_started(entity.id, from_position, target))
	context.emit_event(DomainEvent.entity_moved(entity.id, from_position, target, path.cells))

	# --- arrival resolution ---
	var resolver := ArrivalResolver.new(_matching_rule)
	var arrival := resolver.resolve(context, entity)
	if arrival["outcome"] == ArrivalResolver.OUTCOME_STAGING_FULL:
		var reason := FailReason.to_string_name(FailReason.Value.STAGING_FULL)
		state.set_failure(reason)
		context.emit_event(DomainEvent.game_failed(reason, state.move_index))
		return CommandResult.success_with_code(&"staging_full", context.events)

	# --- objectives + win/lose ---
	ProgressEvaluator.new().evaluate(context)
	return CommandResult.success(context.events)


func _reject(context: CommandContext, status: int, code: StringName) -> CommandResult:
	context.emit_event(DomainEvent.command_rejected(status, code, entity_id))
	return CommandResult.rejected(status, code, context.events)
