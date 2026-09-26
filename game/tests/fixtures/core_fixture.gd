extends RefCounted
## Shared fixtures for M1 core tests (test-only, never shipped logic).


static func make_entity(id: StringName, width: int = 1, height: int = 1, entity_type: StringName = &"unit") -> Entity:
	return Entity.new(id, entity_type, Footprint.new(width, height))


static func make_simulation(level_id: StringName = &"test_level", seed_value: int = 1234, width: int = 6, height: int = 6) -> Simulation:
	return Simulation.create(level_id, seed_value, BoardDimensions.new(width, height))


static func place(simulation: Simulation, entity: Entity, position: GridPosition) -> CommandResult:
	return simulation.execute(PlaceEntityCommand.new(entity, position))
