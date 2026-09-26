extends "res://tests/framework/test_base.gd"
## Command system: success paths, rejections, atomicity, RNG commit policy.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


class RngUsingCommand extends GameCommand:
	func command_name() -> StringName:
		return &"rng_using"

	func execute(context: CommandContext) -> CommandResult:
		context.get_rng().next_int()
		return CommandResult.success(context.events)


class RngUsingRejectedCommand extends GameCommand:
	func command_name() -> StringName:
		return &"rng_using_rejected"

	func execute(context: CommandContext) -> CommandResult:
		context.get_rng().next_int()
		var code := &"deliberate_rejection"
		context.emit_event(DomainEvent.command_rejected(CommandResult.Status.INVALID, code))
		return CommandResult.rejected(CommandResult.Status.INVALID, code, context.events)


func run() -> void:
	_move_success()
	_move_blocked()
	_move_rejections()
	_rejections_never_mutate()
	_place_command()
	_base_command()
	_rng_commit_policy()
	_result_helpers()


func _move_success() -> void:
	var simulation := Fixture.make_simulation(&"level", 111, 4, 4)
	check(Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0)).is_success(), "setup placement succeeds")
	var rng_before := simulation.get_state().rng_state
	var result := simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(2, 2)))
	check(result.is_success(), "move succeeds")
	check_eq(result.status, CommandResult.Status.SUCCESS, "success status")
	check_eq(result.code, &"", "no rejection code on success")
	check_eq(result.events.size(), 2, "successful move emits two events")
	check_eq(result.events[0].event_type, DomainEvent.ENTITY_MOVE_STARTED, "first event is move started")
	check_eq(result.events[1].event_type, DomainEvent.ENTITY_MOVED, "second event is moved")
	check_eq(result.events[0].sequence, 0, "first event sequence is 0")
	check_eq(result.events[1].sequence, 1, "second event sequence is 1")

	var state := simulation.get_state()
	check(state.get_entity(&"a").position.equals(GridPosition.new(2, 2)), "entity moved logically")
	check_eq(state.board.occupant_at(GridPosition.new(2, 2)), &"a", "occupancy updated")
	check(state.board.is_cell_free(GridPosition.new(0, 0)), "origin cell freed")
	check_eq(state.move_index, 1, "move index advanced")
	check_eq(state.rng_state, rng_before, "move command does not consume rng")
	check(Serialization.values_equal(result.events[0].get_payload("from"), {"x": 0, "y": 0}), "from payload")
	check(Serialization.values_equal(result.events[1].get_payload("to"), {"x": 2, "y": 2}), "to payload")


func _move_blocked() -> void:
	var simulation := Fixture.make_simulation(&"level", 111, 4, 4)
	Fixture.place(simulation, Fixture.make_entity(&"mover"), GridPosition.new(0, 0))
	Fixture.place(simulation, Fixture.make_entity(&"blocker", 2, 1), GridPosition.new(1, 0))
	var before := simulation.snapshot()
	var result := simulation.execute(MoveEntityCommand.new(&"mover", GridPosition.new(1, 0)))
	check_eq(result.status, CommandResult.Status.BLOCKED, "blocked status")
	check_eq(result.code, &"cell_occupied", "blocked code")
	check_eq(result.events.size(), 1, "blocked move emits exactly one event")
	check_eq(result.events[0].event_type, DomainEvent.ENTITY_BLOCKED, "blocked event type")
	check(Serialization.values_equal(result.events[0].get_payload("blockers"), ["blocker"]), "blocker ids in payload")
	check(Serialization.values_equal(result.events[0].get_payload("target"), {"x": 1, "y": 0}), "blocked target payload")
	check(Serialization.values_equal(before, simulation.snapshot()), "state unchanged after blocked move")
	check_eq(simulation.get_state().move_index, 0, "move index unchanged after blocked move")


func _move_rejections() -> void:
	var simulation := Fixture.make_simulation(&"level", 111, 4, 4)
	Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0))
	var before := simulation.snapshot()

	var out_of_bounds := simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(4, 0)))
	check_eq(out_of_bounds.status, CommandResult.Status.OUT_OF_BOUNDS, "out of bounds status")
	check_eq(out_of_bounds.code, &"out_of_bounds", "out of bounds code")
	check_eq(out_of_bounds.events.size(), 1, "rejection emits one event")
	check_eq(out_of_bounds.events[0].event_type, DomainEvent.COMMAND_REJECTED, "rejection event type")
	check_eq(out_of_bounds.events[0].get_payload("status"), "out_of_bounds", "rejection payload status")
	check_eq(out_of_bounds.events[0].get_payload("code"), "out_of_bounds", "rejection payload code")

	var unknown := simulation.execute(MoveEntityCommand.new(&"ghost", GridPosition.new(1, 1)))
	check_eq(unknown.status, CommandResult.Status.INVALID, "unknown entity invalid")
	check_eq(unknown.code, &"unknown_entity", "unknown entity code")

	var missing_target := simulation.execute(MoveEntityCommand.new(&"a", null))
	check_eq(missing_target.code, &"missing_target", "missing target code")

	var no_op := simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 0)))
	check_eq(no_op.status, CommandResult.Status.INVALID, "no-op move invalid")
	check_eq(no_op.code, &"no_op_move", "no-op code")

	check(Serialization.values_equal(before, simulation.snapshot()), "state unchanged by rejected move commands")

	# Entity exists in state but was never placed on the board.
	var unplaced_simulation := Fixture.make_simulation(&"level", 111, 4, 4)
	unplaced_simulation.get_state().add_entity(Fixture.make_entity(&"unplaced"))
	var unplaced_before := unplaced_simulation.snapshot()
	var not_placed := unplaced_simulation.execute(MoveEntityCommand.new(&"unplaced", GridPosition.new(1, 1)))
	check_eq(not_placed.status, CommandResult.Status.INVALID_STATE, "unplaced entity invalid state")
	check_eq(not_placed.code, &"entity_not_placed", "unplaced entity code")
	check(Serialization.values_equal(unplaced_before, unplaced_simulation.snapshot()), "unplaced rejection does not mutate state")

	# Entity in a terminal state cannot move.
	var finished_entity_simulation := Fixture.make_simulation(&"level", 111, 4, 4)
	Fixture.place(finished_entity_simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0))
	finished_entity_simulation.get_state().get_entity(&"a").state = EntityState.Value.COMPLETED
	var completed_before := finished_entity_simulation.snapshot()
	var not_movable := finished_entity_simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 1)))
	check_eq(not_movable.status, CommandResult.Status.INVALID_STATE, "completed entity invalid state")
	check_eq(not_movable.code, &"entity_not_movable", "completed entity code")
	check(Serialization.values_equal(completed_before, finished_entity_simulation.snapshot()), "completed rejection does not mutate state")

	# Board is not usable.
	var not_ready := Simulation.new(GameState.new(&"level_2", 1, BoardDimensions.new(0, 0)))
	not_ready.get_state().add_entity(Fixture.make_entity(&"x"))
	var no_board := not_ready.execute(MoveEntityCommand.new(&"x", GridPosition.new(0, 0)))
	check_eq(no_board.status, CommandResult.Status.INVALID_STATE, "board not ready invalid state")
	check_eq(no_board.code, &"board_not_ready", "board not ready code")

	# Level already finished.
	var finished := Fixture.make_simulation(&"level_3", 1, 3, 3)
	finished.get_state().set_completion(GameState.Completion.COMPLETED)
	var complete := finished.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 1)))
	check_eq(complete.status, CommandResult.Status.GAME_ALREADY_COMPLETE, "completed level rejects commands")
	check_eq(complete.code, &"game_not_in_progress", "completed level code")


func _rejections_never_mutate() -> void:
	var simulation := Fixture.make_simulation(&"guard", 7, 3, 3)
	Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0))
	Fixture.place(simulation, Fixture.make_entity(&"b"), GridPosition.new(1, 0))
	var before := simulation.snapshot()
	simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 0)))
	simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(9, 9)))
	simulation.execute(MoveEntityCommand.new(&"nope", GridPosition.new(2, 2)))
	simulation.execute(MoveEntityCommand.new(&"a", null))
	simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 0)))
	simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"b"), GridPosition.new(2, 2)))
	simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"c", 3, 1), GridPosition.new(1, 0)))
	check(Serialization.values_equal(before, simulation.snapshot()), "state identical after a series of rejected commands")


func _place_command() -> void:
	var simulation := Fixture.make_simulation(&"level", 111, 3, 3)
	var result := simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"a", 2, 1), GridPosition.new(1, 1)))
	check(result.is_success(), "placement succeeds")
	check_eq(result.events.size(), 1, "placement emits one event")
	check_eq(result.events[0].event_type, DomainEvent.ENTITY_PLACED, "placement event type")
	check_eq(result.events[0].get_payload("entity_id"), "a", "placement payload id")
	check(Serialization.values_equal(result.events[0].get_payload("footprint"), {"width": 2, "height": 1}), "placement payload footprint")
	check(simulation.get_state().has_entity(&"a"), "entity registered in state")
	check_eq(simulation.get_state().board.occupant_at(GridPosition.new(2, 1)), &"a", "board occupancy set")

	var duplicate := simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"a"), GridPosition.new(0, 0)))
	check_eq(duplicate.status, CommandResult.Status.INVALID, "duplicate id invalid")
	check_eq(duplicate.code, &"duplicate_entity_id", "duplicate id code")

	var overlap := simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"b"), GridPosition.new(2, 1)))
	check_eq(overlap.status, CommandResult.Status.BLOCKED, "overlapping placement blocked")
	check_eq(overlap.events[0].event_type, DomainEvent.ENTITY_BLOCKED, "overlap emits blocked event")

	var out_of_bounds := simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"c", 3, 1), GridPosition.new(1, 0)))
	check_eq(out_of_bounds.code, &"out_of_bounds", "placement out of bounds code")

	var missing := simulation.execute(PlaceEntityCommand.new(null, GridPosition.new(0, 0)))
	check_eq(missing.code, &"missing_arguments", "missing arguments code")

	check(not simulation.get_state().has_entity(&"b"), "blocked placement not registered")
	check(not simulation.get_state().has_entity(&"c"), "out-of-bounds placement not registered")
	check_eq(simulation.get_state().move_index, 0, "placement does not advance move index")


func _base_command() -> void:
	var simulation := Fixture.make_simulation(&"level", 1, 3, 3)
	var result := simulation.execute(GameCommand.new())
	check_eq(result.status, CommandResult.Status.INVALID, "base command invalid")
	check_eq(result.code, &"not_implemented", "base command code")
	check_eq(result.events.size(), 1, "base command emits rejection event")
	check_eq(result.events[0].event_type, DomainEvent.COMMAND_REJECTED, "base command rejection event type")
	check_eq(GameCommand.new().command_name(), &"game_command", "base command name")
	var null_result := simulation.execute(null)
	check_eq(null_result.code, &"null_command", "null command rejected")


func _rng_commit_policy() -> void:
	var consuming := Fixture.make_simulation(&"level", 99, 3, 3)
	var before := consuming.get_state().rng_state
	check(consuming.execute(RngUsingCommand.new()).is_success(), "rng-consuming command succeeds")
	check(consuming.get_state().rng_state != before, "successful command commits rng state")
	var expected := DeterministicRng.new(0)
	expected.set_state({DeterministicRng.STATE_KEY: before})
	expected.next_int()
	check_eq(consuming.get_state().rng_state, expected.get_seed_state(), "committed rng state matches deterministic advance")

	var rejecting := Fixture.make_simulation(&"level", 99, 3, 3)
	var rejecting_before := rejecting.get_state().rng_state
	var rejected := rejecting.execute(RngUsingRejectedCommand.new())
	check(rejected.is_rejected(), "rng-consuming command can reject")
	check_eq(rejecting.get_state().rng_state, rejecting_before, "rejected command does not commit rng state")


func _result_helpers() -> void:
	var success := CommandResult.success([])
	check(success.is_success(), "success result reports success")
	check(not success.is_rejected(), "success result is not rejected")
	var rejected := CommandResult.rejected(CommandResult.Status.BLOCKED, &"cell_occupied")
	check(rejected.is_rejected(), "rejected result reports rejection")
	check(not rejected.is_success(), "rejected result is not success")
	check_eq(rejected.status_name(), &"blocked", "status name")
	check_eq(CommandResult.status_from_string_name(&"out_of_bounds"), CommandResult.Status.OUT_OF_BOUNDS, "status name roundtrips")
	check_eq(CommandResult.status_from_string_name(&"not_a_status"), -1, "unknown status name invalid")
	check(CommandResult.success([]).logical_equals(CommandResult.success([])), "identical results are logically equal")
	check(not CommandResult.success([]).logical_equals(rejected), "different results are not equal")
	check(not CommandResult.success([]).logical_equals(null), "null comparison is safe")
