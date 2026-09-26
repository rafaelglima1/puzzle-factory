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
