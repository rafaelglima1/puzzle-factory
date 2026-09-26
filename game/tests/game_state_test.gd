extends "res://tests/framework/test_base.gd"
## GameState: defaults, entities, canonical serialization, validation.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_defaults()
	_entities()
	_roundtrip()
	_canonical_ordering()
	_validation()
	_completion()
	_m2_collections()
	_m2_roundtrip()
	_m1_migration()
	_m2_validation()


func _defaults() -> void:
	var state := GameState.new(&"level_1", 987234, BoardDimensions.new(4, 4))
	check_eq(state.schema_version, GameState.SCHEMA_VERSION, "schema version")
	check_eq(state.level_id, &"level_1", "level id")
	check_eq(state.level_revision, 1, "level revision default")
	check_eq(state.seed, 987234, "seed")
	check_eq(state.rng_state, DeterministicRng.normalize_seed(987234), "rng state derived from seed")
	check_eq(state.move_index, 0, "move index default")
	check_eq(state.elapsed_ms, 0, "elapsed time default")
	check(state.is_in_progress(), "state starts in progress")
	check(state.board.is_ready(), "board is ready")
	check_eq(state.entity_count(), 0, "no entities by default")


func _entities() -> void:
	var state := GameState.new(&"level_1", 1, BoardDimensions.new(4, 4))
	check(state.add_entity(Fixture.make_entity(&"b")), "add entity b")
	check(state.add_entity(Fixture.make_entity(&"a")), "add entity a")
	check(not state.add_entity(Fixture.make_entity(&"a")), "duplicate id rejected")
	check(not state.add_entity(null), "null entity rejected")
	check(not state.add_entity(Entity.new(&"", &"unit")), "empty id rejected")
	check(state.has_entity(&"a"), "has entity")
	check_eq(state.entity_count(), 2, "entity count")
	var ids := state.entity_ids()
	check_eq(ids.size(), 2, "entity id count")
	check_eq(ids[0], &"a", "entity ids sorted (1)")
	check_eq(ids[1], &"b", "entity ids sorted (2)")
	check(state.get_entity(&"a") != null, "get existing entity")
	check(state.get_entity(&"missing") == null, "get missing entity is null")
	check(state.remove_entity(&"a"), "remove entity")
	check(not state.has_entity(&"a"), "removed entity gone")
	check(not state.remove_entity(&"a"), "double remove rejected")


func _roundtrip() -> void:
	var state := _rich_state()
	var data := state.to_dictionary()
	var restored := GameState.from_dictionary(data)
	check(restored != null, "state restored from dictionary")
	if restored == null:
		return
	check(state.logical_equals(restored), "logical equality after dictionary roundtrip")
	check(Serialization.values_equal(data, restored.to_dictionary()), "canonical dictionaries identical")
	check_eq(restored.level_revision, 3, "level revision restored")
	check_eq(restored.move_index, 7, "move index restored")
	check_eq(restored.elapsed_ms, 1234, "elapsed restored")

	var json_text := Serialization.to_json(state.to_dictionary())
	var parsed: Variant = Serialization.from_json(json_text)
	check(typeof(parsed) == TYPE_DICTIONARY, "state serializes to parseable JSON")
	var from_json := GameState.from_dictionary(parsed)
	check(from_json != null, "state restored from JSON")
	if from_json == null:
		return
	check(state.logical_equals(from_json), "logical equality after JSON roundtrip")
	check(from_json.get_entity(&"slot").position.equals(GridPosition.new(2, 3)), "position survives JSON roundtrip")
	check_eq(from_json.get_entity(&"slot").capacity, 2, "capacity survives JSON roundtrip")
	check_eq(from_json.rng_state, state.rng_state, "rng state survives JSON roundtrip")
	check(not from_json.has_entity(&""), "no phantom entities after roundtrip")


func _rich_state() -> GameState:
	var state := GameState.new(&"level_rich", 424242, BoardDimensions.new(5, 5))
	state.level_revision = 3
	state.move_index = 7
	state.elapsed_ms = 1234
	state.rng_state = 12345

	var placed := Fixture.make_entity(&"slot", 2, 1, &"mover")
	placed.color_key = &"COLOR_B"
	placed.capacity = 2
	placed.state = EntityState.Value.WAITING
	placed.metadata = {"tags": ["x", "y"], "depth": {"n": 2}}
	state.board.place_entity(placed, GridPosition.new(2, 3))
	state.add_entity(placed)

	var unplaced := Fixture.make_entity(&"waiting", 1, 1, &"queued")
	unplaced.destination_id = &"destination_7"
	state.add_entity(unplaced)
	return state


func _canonical_ordering() -> void:
	var first := _rich_state()
	var reversed := GameState.new(&"level_rich", 424242, BoardDimensions.new(5, 5))
	reversed.level_revision = 3
	reversed.move_index = 7
	reversed.elapsed_ms = 1234
	reversed.rng_state = 12345

	var unplaced := Fixture.make_entity(&"waiting", 1, 1, &"queued")
	unplaced.destination_id = &"destination_7"
	reversed.add_entity(unplaced)

	var placed := Fixture.make_entity(&"slot", 2, 1, &"mover")
	placed.color_key = &"COLOR_B"
	placed.capacity = 2
	placed.state = EntityState.Value.WAITING
	placed.metadata = {"tags": ["x", "y"], "depth": {"n": 2}}
	reversed.board.place_entity(placed, GridPosition.new(2, 3))
	reversed.add_entity(placed)

	check(first.logical_equals(reversed), "insertion order does not affect logical equality")
	check(
		Serialization.values_equal(first.to_dictionary(), reversed.to_dictionary()),
		"canonical dictionaries identical regardless of insertion order"
	)


func _validation() -> void:
	var data := _rich_state().to_dictionary()
	check_eq(GameState.validate_dictionary(data).size(), 0, "valid state reports no errors")

	var bad_version := data.duplicate(true)
	bad_version["schema_version"] = 999
	check(GameState.validate_dictionary(bad_version).has("unsupported_schema_version:999"), "unsupported schema version detected")

	var bad_rng := data.duplicate(true)
	bad_rng["rng_state"] = -5
	check(GameState.validate_dictionary(bad_rng).has("invalid_rng_state"), "invalid rng state detected")

	var bad_move_index := data.duplicate(true)
	bad_move_index["move_index"] = -1
	check(GameState.validate_dictionary(bad_move_index).has("invalid_move_index"), "invalid move index detected")

	var mismatch := data.duplicate(true)
	for entry in mismatch["entities"]:
		if entry["id"] == "slot":
			entry["position"] = {"x": 0, "y": 0}
	check(GameState.validate_dictionary(mismatch).has("entity_placement_mismatch:slot"), "entity/board placement mismatch detected")

	var unknown_state := data.duplicate(true)
	for entry in unknown_state["entities"]:
		if entry["id"] == "slot":
			entry["state"] = "teleporting"
	check(GameState.validate_dictionary(unknown_state).has("unknown_entity_state:slot"), "unknown entity state detected")

	var duplicate_entity := data.duplicate(true)
	duplicate_entity["entities"].append(duplicate_entity["entities"][0].duplicate(true))
	check(not GameState.validate_dictionary(duplicate_entity).is_empty(), "duplicate entity ids detected")

	var missing_board := data.duplicate(true)
	missing_board.erase("board")
	check(GameState.validate_dictionary(missing_board).has("missing_board"), "missing board detected")

	var placement_unknown := data.duplicate(true)
	placement_unknown["board"]["placements"][0]["entity_id"] = "ghost"
	var placement_errors := GameState.validate_dictionary(placement_unknown)
	check(placement_errors.has("placement_unknown_entity:ghost"), "placement of unknown entity detected")

	check(not GameState.validate_dictionary({}).is_empty(), "empty dictionary is invalid")
	# Deliberate negative load: from_dictionary logs the reason and returns null
	# (the error line in the test output is expected and asserted here).
	check(GameState.from_dictionary(missing_board) == null, "from_dictionary rejects invalid state")


func _completion() -> void:
	var state := GameState.new(&"level_1", 1, BoardDimensions.new(3, 3))
	check(state.is_in_progress(), "starts in progress")
	check(not state.set_completion(GameState.Completion.IN_PROGRESS), "cannot re-enter in_progress")
	check(not state.set_completion(123), "unknown completion value rejected")
	check(state.set_completion(GameState.Completion.COMPLETED), "completion allowed from in_progress")
	check(state.is_completed(), "state completed")
	check(not state.is_in_progress(), "not in progress after completion")
	check(not state.set_completion(GameState.Completion.FAILED), "terminal state cannot change")

	var data := state.to_dictionary()
	check_eq(data["completion_state"], "completed", "completion serialized as stable name")
	var restored := GameState.from_dictionary(data)
	check(restored != null and restored.is_completed(), "completion restored")

	var failed := GameState.new(&"level_2", 1, BoardDimensions.new(3, 3))
	check(failed.set_completion(GameState.Completion.FAILED), "failure allowed from in_progress")
	check(failed.is_failed(), "state failed")

func _m2_state() -> GameState:
	var state := GameState.new(&"level_m2", 909, BoardDimensions.new(5, 4))
	state.staging = StagingArea.new(3)

	var path := LogicalPath.new(&"route_1")
	path.cells = [GridPosition.new(0, 0), GridPosition.new(1, 0), GridPosition.new(2, 0)]
	state.add_path(path)

	var destination := Destination.new(&"destination_1", &"unit_destination")
	destination.accepted_color_keys = [&"COLOR_A"]
	destination.capacity = 2
	destination.queue_id = &"queue_1"
	destination.processed_count = 1
	destination.refresh_state()
	destination.metadata = {"cell": {"x": 3, "y": 1}}
	state.add_destination(destination)

	var queue := ItemQueue.new(&"queue_1")
	queue.enqueue(&"item_1")
	queue.enqueue(&"item_2")
	state.add_queue(queue)

	var first_item := Item.new(&"item_1", &"unit_item", &"COLOR_A")
	first_item.destination_id = &"destination_1"
	state.add_item(first_item)
	var second_item := Item.new(&"item_2", &"unit_item", &"COLOR_A")
	second_item.destination_id = &"destination_1"
	state.add_item(second_item)

	var entity := Fixture.make_entity(&"entity_1", 1, 1, &"unit")
	entity.color_key = &"COLOR_A"
	entity.capacity = 2
	entity.path_id = &"route_1"
	entity.destination_id = &"destination_1"
	if not state.board.place_entity(entity, GridPosition.new(0, 0)):
		check(false, "fixture entity placed")
	state.add_entity(entity)

	var staged := Fixture.make_entity(&"entity_2", 1, 1, &"unit")
	staged.state = EntityState.Value.WAITING
	state.add_entity(staged)
	state.staging.add(&"entity_2")

	state.add_objective(ClearAllObjective.new(&"clear_all", true))
	state.mark_objective_completed(&"clear_all")
	return state


func _m2_collections() -> void:
	var state := GameState.new(&"level_m2", 5, BoardDimensions.new(3, 3))
	check(state.items.is_empty(), "no items by default")
	check(state.queues.is_empty(), "no queues by default")
	check(state.destinations.is_empty(), "no destinations by default")
	check(state.paths.is_empty(), "no paths by default")
	check(state.objectives.is_empty(), "no objectives by default")
	check(state.objectives_completed.is_empty(), "no completed objectives by default")
	check_eq(state.staging.slot_count, StagingArea.DEFAULT_SLOT_COUNT, "default staging slots")
	check_eq(state.fail_reason, &"", "no failure reason by default")

	var item := Item.new(&"item_1", &"unit_item", &"COLOR_A")
	check(state.add_item(item), "item added")
	check(not state.add_item(item), "duplicate item rejected")
	check(not state.add_item(null), "null item rejected")
	check(state.has_item(&"item_1"), "item lookup")
	var single_item: Array[StringName] = [&"item_1"]
	check_eq(state.item_ids(), single_item, "item ids listed")
	check(state.remove_item(&"item_1"), "item removed")
	check(not state.remove_item(&"item_1"), "double removal rejected")

	var queue := ItemQueue.new(&"queue_1")
	check(state.add_queue(queue), "queue added")
	check(not state.add_queue(queue), "duplicate queue rejected")
	check(state.get_queue(&"queue_1") == queue, "queue lookup")
	check(state.get_queue(&"missing") == null, "unknown queue lookup is null")

	var destination := Destination.new(&"destination_1", &"unit_destination")
	check(state.add_destination(destination), "destination added")
	check(not state.add_destination(destination), "duplicate destination rejected")
	check(state.get_destination(&"destination_1") == destination, "destination lookup")

	var path := LogicalPath.new(&"route_1")
	path.cells = [GridPosition.new(0, 0), GridPosition.new(1, 0)]
	check(state.add_path(path), "path added")
	check(not state.add_path(path), "duplicate path rejected")
	check(state.get_path(&"route_1") == path, "path lookup")

	var objective := ClearAllObjective.new(&"clear_all")
	check(state.add_objective(objective), "objective added")
	check(not state.add_objective(ClearAllObjective.new(&"clear_all")), "duplicate objective rejected")

	var ids := GameState.new(&"ordering", 1, BoardDimensions.new(2, 2))
	ids.add_item(Item.new(&"zeta"))
	ids.add_item(Item.new(&"alpha"))
	ids.add_queue(ItemQueue.new(&"q_b"))
	ids.add_queue(ItemQueue.new(&"q_a"))
	ids.add_destination(Destination.new(&"d_b"))
	ids.add_destination(Destination.new(&"d_a"))
	ids.add_path(LogicalPath.new(&"p_b"))
	ids.add_path(LogicalPath.new(&"p_a"))
	var sorted_items: Array[StringName] = [&"alpha", &"zeta"]
	check_eq(ids.item_ids(), sorted_items, "item ids sorted")
	check_eq(ids.queue_ids()[0], &"q_a", "queue ids sorted")
	check_eq(ids.destination_ids()[0], &"d_a", "destination ids sorted")
	check_eq(ids.path_ids()[0], &"p_a", "path ids sorted")

	check(state.set_victory(), "victory set")
	check(state.is_won(), "is_won alias")
	check(state.is_completed(), "is_completed reflects victory")
	check(not state.set_failure(FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES)), "cannot fail a finished level")

	var losing := GameState.new(&"losing", 1, BoardDimensions.new(2, 2))
	check(not losing.set_failure(&"not_a_reason"), "unknown failure reason rejected")
	check(losing.is_in_progress(), "state unchanged after rejected failure reason")
	check(losing.set_failure(FailReason.to_string_name(FailReason.Value.STAGING_FULL)), "failure set")
	check(losing.is_lost(), "is_lost alias")
	check(losing.is_failed(), "is_failed reflects loss")
	check_eq(losing.fail_reason, &"staging_full", "failure reason stored")
	check(not losing.set_failure(FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES)), "failure is terminal")


func _m2_roundtrip() -> void:
	var state := _m2_state()
	var data := state.to_dictionary()
	var restored := GameState.from_dictionary(data)
	check(restored != null, "M2 state restored from dictionary")
	if restored == null:
		return
	check(state.logical_equals(restored), "M2 logical equality after dictionary roundtrip")
	check(Serialization.values_equal(data, restored.to_dictionary()), "M2 canonical dictionaries identical")
	check_eq(restored.queue_ids()[0], &"queue_1", "queue restored")
	check_eq(restored.get_queue(&"queue_1").item_ids().size(), 2, "queue contents restored")
	check_eq(restored.get_queue(&"queue_1").peek(), &"item_1", "FIFO order restored")
	check_eq(restored.get_destination(&"destination_1").processed_count, 1, "destination counters restored")
	check_eq(restored.get_destination(&"destination_1").state, Destination.State.OPEN, "destination state restored")
	check(restored.get_destination(&"destination_1").metadata.has("cell"), "destination metadata restored")
	check_eq(restored.get_path(&"route_1").length(), 3, "path restored")
	check_eq(restored.staging.occupied_count(), 1, "staging occupancy restored")
	check_eq(restored.staging.occupant_at(0), &"entity_2", "staging slot restored")
	check_eq(restored.objectives.size(), 1, "objectives restored")
	check(restored.is_objective_completed(&"clear_all"), "objective completion restored")
	check_eq(restored.get_entity(&"entity_2").state, EntityState.Value.WAITING, "staged entity state restored")
	check(not restored.get_entity(&"entity_2").is_placed(), "staged entity stays off the board")

	var parsed: Variant = Serialization.from_json(Serialization.to_json(data))
	var from_json := GameState.from_dictionary(parsed)
	check(from_json != null and state.logical_equals(from_json), "M2 state survives a JSON roundtrip")

	var failed := _m2_state()
	failed.set_failure(FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES))
	var failed_restored := GameState.from_dictionary(failed.to_dictionary())
	check(failed_restored != null and failed_restored.is_lost(), "lost state restored")
	check_eq(failed_restored.fail_reason, &"no_valid_moves", "failure reason preserved")


func _m1_migration() -> void:
	var v2_data := _m2_state().to_dictionary()
	var v1_data: Dictionary = v2_data.duplicate(true)
	for key in ["items", "queues", "destinations", "paths", "staging", "objectives", "objectives_completed", "fail_reason"]:
		v1_data.erase(key)
	v1_data["schema_version"] = 1

	check_eq(GameState.validate_dictionary(v1_data).size(), 0, "v1 payload validates through migration")
	var migrated := GameState.from_dictionary(v1_data)
	check(migrated != null, "v1 payload loads")
	if migrated == null:
		return
	check_eq(migrated.schema_version, GameState.SCHEMA_VERSION, "migrated state uses the current schema")
	check(migrated.items.is_empty(), "migrated state has no items")
	check(migrated.queues.is_empty(), "migrated state has no queues")
	check(migrated.destinations.is_empty(), "migrated state has no destinations")
	check(migrated.paths.is_empty(), "migrated state has no paths")
	check(migrated.objectives.is_empty(), "migrated state has no objectives")
	check_eq(migrated.staging.slot_count, 0, "migrated state stages nothing")
	check(migrated.has_entity(&"entity_1"), "entities preserved across migration")
	check(migrated.board.position_of(&"entity_1").equals(GridPosition.new(0, 0)), "board preserved across migration")
	check_eq(migrated.move_index, v2_data["move_index"], "move index preserved across migration")

	var v1_without_destinations: Dictionary = v1_data.duplicate(true)
	v1_without_destinations["entities"][0]["destination_id"] = "destination_that_does_not_exist"
	check_eq(
		GameState.validate_dictionary(v1_without_destinations).size(),
		0,
		"entity destination references stay optional for generic validation"
	)

	var unsupported: Dictionary = v1_data.duplicate(true)
	unsupported["schema_version"] = 999
	check(GameState.validate_dictionary(unsupported).has("unsupported_schema_version:999"), "unsupported version reported")
	# Deliberate negative load: from_dictionary logs the reason and returns null.
	check(GameState.from_dictionary(unsupported) == null, "unsupported version is not loaded")


func _m2_validation() -> void:
	var base := _m2_state().to_dictionary()
	check_eq(GameState.validate_dictionary(base).size(), 0, "M2 fixture is valid")

	var unknown_queued_item := base.duplicate(true)
	unknown_queued_item["queues"][0]["item_ids"] = ["item_1", "ghost_item"]
	check(
		GameState.validate_dictionary(unknown_queued_item).has("queue_unknown_item:ghost_item"),
		"queue referencing an unknown item is reported"
	)

	var unreferenced := base.duplicate(true)
	unreferenced["items"].append({"id": "orphan_item", "item_type": "unit_item", "color_key": "COLOR_A"})
	check(GameState.validate_dictionary(unreferenced).has("unreferenced_item:orphan_item"), "unreferenced item is reported")

	var shared := base.duplicate(true)
	shared["queues"].append({"id": "queue_2", "policy": "fifo", "visible_count": 0, "item_ids": ["item_1"]})
	check(GameState.validate_dictionary(shared).has("item_in_multiple_queues:item_1"), "item in two queues is reported")

	var unknown_queue := base.duplicate(true)
	unknown_queue["destinations"][0]["queue_id"] = "ghost_queue"
	check(
		GameState.validate_dictionary(unknown_queue).has("unknown_destination_queue:destination_1"),
		"destination referencing an unknown queue is reported"
	)

	var broken_path := base.duplicate(true)
	broken_path["paths"][0]["cells"] = [{"x": 0, "y": 0}, {"x": 3, "y": 3}]
	check(
		GameState.validate_dictionary(broken_path).has("invalid_path:route_1:non_contiguous:1"),
		"invalid path is reported with detail"
	)

	var staging_mismatch := base.duplicate(true)
	staging_mismatch["staging"]["occupants"] = ["entity_2"]
	check(
		GameState.validate_dictionary(staging_mismatch).has("staging_occupant_count_mismatch"),
		"staging occupant count mismatch is reported"
	)

	var staging_unknown := base.duplicate(true)
	staging_unknown["staging"]["occupants"] = ["ghost_entity", "", ""]
	check(
		GameState.validate_dictionary(staging_unknown).has("staged_unknown_entity:ghost_entity"),
		"staging an unknown entity is reported"
	)

	var staging_duplicate := base.duplicate(true)
	staging_duplicate["staging"]["occupants"] = ["entity_2", "entity_2", ""]
	check(
		GameState.validate_dictionary(staging_duplicate).has("staged_entity_twice:entity_2"),
		"staging the same entity twice is reported"
	)

	var unknown_objective := base.duplicate(true)
	unknown_objective["objectives"] = [{"id": "objective_x", "objective_type": "not_a_type", "mandatory": true}]
	check(
		GameState.validate_dictionary(unknown_objective).has("unknown_objective_type:objective_x"),
		"unknown objective type is reported"
	)

	var completed_unknown := base.duplicate(true)
	completed_unknown["objectives_completed"] = ["ghost_objective"]
	check(
		GameState.validate_dictionary(completed_unknown).has("completed_unknown_objective:ghost_objective"),
		"completed unknown objective is reported"
	)

	var unknown_reason := base.duplicate(true)
	unknown_reason["fail_reason"] = "mystery_reason"
	check(GameState.validate_dictionary(unknown_reason).has("unknown_fail_reason:mystery_reason"), "unknown fail reason is reported")

	var completed_on_board := base.duplicate(true)
	completed_on_board["entities"][0]["state"] = "completed"
	check(
		GameState.validate_dictionary(completed_on_board).has("completed_entity_on_board:entity_1"),
		"completed entity on the board is reported"
	)
