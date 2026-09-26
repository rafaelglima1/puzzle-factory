class_name MoveEntityCommand
extends GameCommand
## Moves an existing, placed entity to a target cell (blueprint §12).
##
## Logical movement is instantaneous and atomic: the entity's logical
## position changes only if the whole footprint can be placed. Presentation
## animates using [constant DomainEvent.ENTITY_MOVE_STARTED] /
## [constant DomainEvent.ENTITY_MOVED]; the simulation never waits for it.
##
## Validation order (deterministic, rejection codes stable):
## 1. game_not_in_progress  → GAME_ALREADY_COMPLETE
## 2. missing_target        → INVALID
## 3. unknown_entity        → INVALID
## 4. board_not_ready       → INVALID_STATE
## 5. entity_not_placed     → INVALID_STATE
## 6. entity_not_movable    → INVALID_STATE
## 7. out_of_bounds         → OUT_OF_BOUNDS
## 8. no_op_move            → INVALID
## 9. cell_occupied         → BLOCKED

var entity_id: StringName = &""
var target: GridPosition = null


func _init(p_entity_id: StringName = &"", p_target: GridPosition = null) -> void:
	entity_id = p_entity_id
	target = p_target


func command_name() -> StringName:
	return &"move_entity"


func execute(context: CommandContext) -> CommandResult:
	var state := context.state

	if not state.is_in_progress():
		return _reject(context, CommandResult.Status.GAME_ALREADY_COMPLETE, &"game_not_in_progress")
	if target == null:
		return _reject(context, CommandResult.Status.INVALID, &"missing_target")

	var entity := state.get_entity(entity_id)
	if entity == null:
		return _reject(context, CommandResult.Status.INVALID, &"unknown_entity")
	if not state.board.is_ready():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"board_not_ready")
	if not entity.is_placed():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"entity_not_placed")
	if not entity.can_receive_move():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"entity_not_movable")
	if not state.board.is_in_bounds(entity.footprint, target):
		return _reject(context, CommandResult.Status.OUT_OF_BOUNDS, &"out_of_bounds")

	var from_position := entity.position
	if from_position.equals(target):
		return _reject(context, CommandResult.Status.INVALID, &"no_op_move")

	var blockers := state.board.blockers_for(entity.footprint, target, entity.id)
	if not blockers.is_empty():
		context.emit_event(DomainEvent.entity_blocked(entity.id, target, blockers))
		return CommandResult.rejected(CommandResult.Status.BLOCKED, &"cell_occupied", context.events)

	if not state.board.move_entity(entity, target):
		return _reject(context, CommandResult.Status.INVALID_STATE, &"move_failed")

	state.move_index += 1
	context.emit_event(DomainEvent.entity_move_started(entity.id, from_position, target))
	context.emit_event(DomainEvent.entity_moved(entity.id, from_position, target))
	return CommandResult.success(context.events)


func _reject(context: CommandContext, status: int, code: StringName) -> CommandResult:
	context.emit_event(DomainEvent.command_rejected(status, code, entity_id))
	return CommandResult.rejected(status, code, context.events)
