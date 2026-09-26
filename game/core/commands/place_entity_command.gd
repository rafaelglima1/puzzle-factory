class_name PlaceEntityCommand
extends GameCommand
## Places an entity on the board (setup / level-load path, blueprint §12).
##
## This command exists to prove the placement path of the command system and
## to emit [constant DomainEvent.ENTITY_PLACED]. It is not a player action.
## Rejection codes are stable and follow the same rule set as
## [MoveEntityCommand].

var entity: Entity = null
var position: GridPosition = null


func _init(p_entity: Entity = null, p_position: GridPosition = null) -> void:
	entity = p_entity
	position = p_position


func command_name() -> StringName:
	return &"place_entity"


func execute(context: CommandContext) -> CommandResult:
	var state := context.state

	if not state.is_in_progress():
		return _reject(context, CommandResult.Status.GAME_ALREADY_COMPLETE, &"game_not_in_progress")
	if entity == null or position == null:
		return _reject(context, CommandResult.Status.INVALID, &"missing_arguments")
	if state.has_entity(entity.id):
		return _reject(context, CommandResult.Status.INVALID, &"duplicate_entity_id")
	if not state.board.is_ready():
		return _reject(context, CommandResult.Status.INVALID_STATE, &"board_not_ready")
	if not state.board.is_in_bounds(entity.footprint, position):
		return _reject(context, CommandResult.Status.OUT_OF_BOUNDS, &"out_of_bounds")

	var blockers := state.board.blockers_for(entity.footprint, position)
	if not blockers.is_empty():
		context.emit_event(DomainEvent.entity_blocked(entity.id, position, blockers))
		return CommandResult.rejected(CommandResult.Status.BLOCKED, &"cell_occupied", context.events)

	if not state.board.place_entity(entity, position):
		return _reject(context, CommandResult.Status.INVALID_STATE, &"placement_failed")
	if not state.add_entity(entity):
		state.board.remove_entity(entity)
		return _reject(context, CommandResult.Status.INVALID, &"entity_rejected")

	context.emit_event(DomainEvent.entity_placed(entity.id, position, entity.footprint))
	return CommandResult.success(context.events)


func _reject(context: CommandContext, status: int, code: StringName) -> CommandResult:
	var entity_id := entity.id if entity != null else &""
	context.emit_event(DomainEvent.command_rejected(status, code, entity_id))
	return CommandResult.rejected(status, code, context.events)
