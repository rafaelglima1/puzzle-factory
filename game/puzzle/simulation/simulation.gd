class_name Simulation
extends RefCounted
## Deterministic headless simulation facade (blueprint §8.2, §12).
##
## Owns a [GameState] and executes [GameCommand]s. This is the only entry
## point presentation/gameplay code needs; it requires no scene tree, no
## rendering and no assets, so the full create → place → execute → inspect
## loop is testable headlessly.
##
## Guarantee: a rejected command never mutates state, including RNG state
## (the deterministic RNG is committed only for successful commands).

var _state: GameState


func _init(p_state: GameState) -> void:
	_state = p_state


static func create(level_id: StringName, seed_value: int, dimensions: BoardDimensions) -> Simulation:
	return Simulation.new(GameState.new(level_id, seed_value, dimensions))


func get_state() -> GameState:
	return _state


## Canonical serialized snapshot (stable comparable representation).
func snapshot() -> Dictionary:
	return _state.to_dictionary()


func execute(command: GameCommand) -> CommandResult:
	if command == null:
		var code := &"null_command"
		return CommandResult.rejected(
			CommandResult.Status.INVALID,
			code,
			[DomainEvent.command_rejected(CommandResult.Status.INVALID, code)]
		)
	var context := CommandContext.new(_state)
	var result := command.execute(context)
	if result.is_success():
		context.commit()
	return result
