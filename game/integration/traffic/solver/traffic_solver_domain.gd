class_name TrafficSolverDomain
extends SolverDomain
## Solver adapter for Traffic official levels — OWNER: AGENT-1 (M5 content).
##
## Bridges the generic [BfsSolver] to the real Traffic [Simulation]. It holds a
## [LevelDefinition]; the opaque state handle IS a [Simulation]. No gameplay
## rules live here: candidates come from the live state and every command is
## delegated to [DispatchEntityCommand] through the simulation.
##
## Determinism:
## - [method initial_state] builds a fresh simulation from the same definition
##   every call (repeated starts are equal).
## - [method candidate_commands] enumerates movable entities from the sorted
##   [method GameState.entity_ids].
## - [method apply_command] clones the current state before executing, so the
##   input handle is never mutated.

const COMMAND_TYPE_DISPATCH := "dispatch_entity"

var _definition: LevelDefinition = null


static func for_definition(definition: LevelDefinition) -> TrafficSolverDomain:
	return TrafficSolverDomain.new(definition)


func _init(definition: LevelDefinition = null) -> void:
	_definition = definition


func definition() -> LevelDefinition:
	return _definition


## Fresh simulation positioned at the puzzle start (null without a definition).
func initial_state() -> Variant:
	if _definition == null:
		return null
	return TrafficLevelDefinitionAdapter.build_simulation(_definition)


## Canonical GameState snapshot of the handle.
func state_snapshot(state: Variant) -> Dictionary:
	var simulation := state as Simulation
	if simulation == null:
		return {}
	return simulation.snapshot()


func is_won(state: Variant) -> bool:
	var simulation := state as Simulation
	if simulation == null:
		return false
	return simulation.get_state().is_won()


func is_lost(state: Variant) -> bool:
	var simulation := state as Simulation
	if simulation == null:
		return false
	return simulation.get_state().is_lost()


func is_terminal(state: Variant) -> bool:
	var simulation := state as Simulation
	if simulation == null:
		return true
	return not simulation.get_state().is_in_progress()


## Deterministic dispatch candidates for every movable entity still on the board.
## Blocked or otherwise illegal dispatches are intentionally still emitted; the
## real simulation rejects them in [method apply_command].
func candidate_commands(state: Variant) -> Array:
	var simulation := state as Simulation
	if simulation == null:
		return []
	var game_state := simulation.get_state()
	var commands: Array = []
	for entity_id in game_state.entity_ids():
		var entity := game_state.get_entity(entity_id)
		if entity == null or not entity.can_receive_move():
			continue
		commands.append({
			"type": COMMAND_TYPE_DISPATCH,
			"entityId": String(entity_id),
		})
	return commands


## Returns a NEW simulation after dispatching the descriptor's entity, or null
## when rejected/blocked. The input handle is never mutated (clone-on-apply).
func apply_command(state: Variant, command: Dictionary) -> Variant:
	var simulation := state as Simulation
	if simulation == null or command == null:
		return null
	var entity_id := StringName(str(command.get("entityId", "")))
	if entity_id == &"":
		return null

	var cloned_state: GameState = GameState.from_dictionary(simulation.snapshot())
	if cloned_state == null:
		return null
	var cloned_simulation := Simulation.new(cloned_state)
	var result := cloned_simulation.execute(DispatchEntityCommand.new(entity_id))
	if result == null or not result.is_success():
		return null
	return cloned_simulation


## Concrete command object for a descriptor (used for real replay execution).
func command_from_descriptor(descriptor: Dictionary) -> Variant:
	if descriptor == null:
		return null
	return DispatchEntityCommand.new(StringName(str(descriptor.get("entityId", ""))))
