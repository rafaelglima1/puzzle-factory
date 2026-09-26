extends "res://tests/framework/test_base.gd"
## Generic objectives: CLEAR_ALL evaluation, factory, state integration.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_base_contract()
	_clear_all()
	_factory()
	_state_integration()


func _base_contract() -> void:
	var base := Objective.new(&"base", &"base_type")
	check(not base.is_complete(GameState.new(&"level", 1, BoardDimensions.new(2, 2))), "base objective never completes")
	check(base.mandatory, "objectives are mandatory by default")
	var described := base.describe(null)
	check(Serialization.is_primitive_tree(described), "describe() stays primitive")
	check_eq(Objective.TYPE_CLEAR_ALL, &"clear_all", "clear_all type id is stable")


func _clear_all() -> void:
	var objective := ClearAllObjective.new(&"clear_all", true)
	check_eq(objective.objective_type, Objective.TYPE_CLEAR_ALL, "objective type")
	check(objective.mandatory, "mandatory flag")

	var state := GameState.new(&"level", 1, BoardDimensions.new(4, 4))
	var queue := ItemQueue.new(&"q1")
	queue.enqueue(&"i1")
	state.add_queue(queue)
	var item := Item.new(&"i1", &"unit_item", &"COLOR_A")
	state.add_item(item)
	var entity := Fixture.make_entity(&"e1")
	state.board.place_entity(entity, GridPosition.new(0, 0))
	state.add_entity(entity)
	check(not objective.is_complete(state), "items still queued: not complete")

	# Empty the queue but leave the entity incomplete.
	queue.take()
	state.remove_item(&"i1")
	check(not objective.is_complete(state), "entity not completed: not complete")

	# Complete the entity (completed entities leave the board).
	entity.state = EntityState.Value.COMPLETED
	state.board.remove_entity(entity)
	check(objective.is_complete(state), "no items and all entities completed: complete")

	var described := objective.describe(state)
	check_eq(int(described["remaining_items"]), 0, "describe reports remaining items")
	check_eq(int(described["completed_entities"]), 1, "describe reports completed entities")
	check_eq(int(described["total_entities"]), 1, "describe reports total entities")

	var empty_level := GameState.new(&"empty", 1, BoardDimensions.new(2, 2))
	check(objective.is_complete(empty_level), "vacuously complete with no items and no entities")
	check(not objective.is_complete(null), "null state is safe")


func _factory() -> void:
	check(ObjectiveFactory.is_known_type(Objective.TYPE_CLEAR_ALL), "clear_all is known")
	check(not ObjectiveFactory.is_known_type(&"not_a_type"), "unknown type is not known")
	var created := ObjectiveFactory.create(Objective.TYPE_CLEAR_ALL, &"objective_1", false)
	check(created != null, "factory creates clear_all")
	if created != null:
		check_eq(created.id, &"objective_1", "factory honours the id")
		check(not created.mandatory, "factory honours the mandatory flag")
		check(created is ClearAllObjective, "factory returns the concrete objective")
	var defaulted := ObjectiveFactory.create(Objective.TYPE_CLEAR_ALL)
	check_eq(defaulted.id, &"clear_all", "default objective id")
	check(ObjectiveFactory.create(&"unknown", &"x", true) == null, "unknown type returns null")
	var restored := ObjectiveFactory.from_dictionary(created.to_dictionary())
	check(restored != null and restored.logical_equals(created), "objective roundtrip through the factory")
	check(Objective.from_dictionary(created.to_dictionary()).logical_equals(created), "base from_dictionary delegates to the factory")


func _state_integration() -> void:
	var state := GameState.new(&"level", 1, BoardDimensions.new(3, 3))
	var first := ClearAllObjective.new(&"clear_all")
	var second := ClearAllObjective.new(&"clear_all")
	check(state.add_objective(first), "objective added")
	check(not state.add_objective(second), "duplicate objective id rejected")
	var nameless := ClearAllObjective.new()
	nameless.id = &""
	check(not state.add_objective(nameless), "objective without id rejected")
	check(not state.add_objective(null), "null objective rejected")
	check_eq(state.get_objective(&"clear_all"), first, "objective lookup")
	check(state.get_objective(&"missing") == null, "unknown objective lookup is null")
	check_eq(state.mandatory_objectives().size(), 1, "mandatory objectives listed")
	check(not state.all_mandatory_objectives_completed(), "incomplete mandatory objective blocks victory")
	check(state.mark_objective_completed(&"clear_all"), "objective marked completed")
	check(state.is_objective_completed(&"clear_all"), "completed objective reported")
	check(not state.mark_objective_completed(&"clear_all"), "double completion rejected")
	check(state.all_mandatory_objectives_completed(), "victory condition satisfied")
	var empty_mandatory := GameState.new(&"no_objectives", 1, BoardDimensions.new(2, 2))
	check(empty_mandatory.mandatory_objectives().is_empty(), "no objectives present")
	check(empty_mandatory.all_mandatory_objectives_completed(), "vacuous truth for zero objectives (evaluator requires at least one)")
