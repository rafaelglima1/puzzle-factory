extends "res://tests/framework/test_base.gd"
## M2 Traffic gameplay simulation (logical rules end to end).
##
## Levels are built through TrafficGameFactory (product integration layer) and
## driven through DispatchEntityCommand; assertions inspect generic state and
## the deterministic event stream.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")

const COLOR_A := &"COLOR_A"
const COLOR_B := &"COLOR_B"


func run() -> void:
	_single_vehicle_completion()
	_multi_color_completion()
	_capacity_limited_loading()
	_queue_fifo_stops_at_mismatch()
	_blocked_vehicle()
	_blocked_then_freed()
	_staging_receives_entity()
	_staging_full_failure()
	_zero_slot_staging()
	_arbitrary_staging_capacity()
	_dead_state_after_wrong_order()
	_initial_deadlock_stays_in_progress()
	_rejections_and_atomicity()
	_factory_validation()
	_determinism_replay()
	_no_randomness_in_m2_rules()


# --- level builders -----------------------------------------------------------

func _single_vehicle_level(staging_slots: int = 4) -> Dictionary:
	return {
		"level_id": "traffic_single",
		"seed": 11,
		"width": 5,
		"height": 2,
		"staging_slots": staging_slots,
		"paths": {"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]},
		"stations": [{
			"id": "station_a", "accepted": ["COLOR_A"], "capacity": 2, "queue": "q_a",
			"cell": {"x": 3, "y": 0}, "footprint": {"width": 2, "height": 1},
		}],
		"queues": {"q_a": ["p1", "p2"]},
		"passengers": [
			{"id": "p1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p2", "color": "COLOR_A", "station": "station_a"},
		],
		"vehicles": [{
			"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 2,
			"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a",
		}],
	}


func _two_color_level(staging_slots: int = 4) -> Dictionary:
	return {
		"level_id": "traffic_two_color",
		"seed": 5,
		"width": 6,
		"height": 3,
		"staging_slots": staging_slots,
		"paths": {
			"route_a": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_b": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
		},
		"stations": [
			{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 1, "queue": "q_a",
				"cell": {"x": 3, "y": 0}, "footprint": {"width": 2, "height": 1}},
			{"id": "station_b", "accepted": ["COLOR_B"], "capacity": 1, "queue": "q_b",
				"cell": {"x": 3, "y": 2}, "footprint": {"width": 2, "height": 1}},
		],
		"queues": {"q_a": ["pa1"], "q_b": ["pb1"]},
		"passengers": [
			{"id": "pa1", "color": "COLOR_A", "station": "station_a"},
			{"id": "pb1", "color": "COLOR_B", "station": "station_b"},
		],
		"vehicles": [
			{"id": "va", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"cell": {"x": 0, "y": 0}, "route": "route_a", "station": "station_a"},
			{"id": "vb", "type": "van", "color": "COLOR_B", "capacity": 1,
				"cell": {"x": 0, "y": 2}, "route": "route_b", "station": "station_b"},
		],
	}


func _event_types(result: CommandResult) -> Array[StringName]:
	var types: Array[StringName] = []
	for event in result.events:
		types.append(event.event_type)
	return types


func _dispatch(simulation: Simulation, entity_id: StringName) -> CommandResult:
	return simulation.execute(DispatchEntityCommand.new(entity_id))


# --- tests --------------------------------------------------------------------

func _single_vehicle_completion() -> void:
	var simulation := TrafficGameFactory.build(_single_vehicle_level())
	check(simulation != null, "single-vehicle level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	check_eq(state.schema_version, GameState.SCHEMA_VERSION, "state schema version")
	check_eq(state.get_entity(&"v1").entity_type, &"compact", "vehicle mapped to a generic entity")
	check_eq(state.get_item(&"p1").item_type, &"passenger_standard", "passenger mapped to a generic item")
	check_eq(state.get_destination(&"station_a").destination_type, &"station", "station mapped to a generic destination")
	check_eq(state.staging.slot_count, 4, "staging slots configured")
	check_eq(state.objectives.size(), 1, "default objective created")

	var result := _dispatch(simulation, &"v1")
	check(result.is_success(), "dispatch succeeds")
	check_eq(result.code, &"", "success carries no code")
	var expected: Array[StringName] = [
		DomainEvent.ENTITY_MOVE_STARTED,
		DomainEvent.ENTITY_MOVED,
		DomainEvent.ITEM_LOADED,
		DomainEvent.ITEM_LOADED,
		DomainEvent.MATCH_OCCURRED,
		DomainEvent.ENTITY_COMPLETED,
		DomainEvent.OBJECTIVE_COMPLETED,
		DomainEvent.GAME_COMPLETED,
	]
	check_eq(_event_types(result), expected, "deterministic event order for a completing dispatch")
	for index in result.events.size():
		check_eq(result.events[index].sequence, index, "event sequence is contiguous at %d" % index)
	check_eq(result.events[2].get_payload("item_id"), "p1", "FIFO: first item loaded first")
	check_eq(result.events[3].get_payload("item_id"), "p2", "FIFO: second item loaded second")
	check_eq(result.events[4].get_payload("loaded_count"), 2, "match summary reports the load count")
	check_eq(result.events[7].get_payload("level_id"), "traffic_single", "level id in completion payload")

	check(state.is_won(), "level is won")
	check_eq(state.fail_reason, &"", "no failure reason on victory")
	check(state.items.is_empty(), "all items processed")
	check(state.get_queue(&"q_a").is_empty(), "queue drained")
	check_eq(state.get_destination(&"station_a").processed_count, 2, "destination processed count")
	check_eq(state.get_destination(&"station_a").state, Destination.State.FULL, "destination reports full")
	check_eq(state.get_entity(&"v1").state, EntityState.Value.COMPLETED, "vehicle completed")
	check(not state.get_entity(&"v1").is_placed(), "completed vehicle left the board")
	check_eq(state.board.entity_count(), 0, "board is clear")
	check_eq(state.move_index, 1, "move index advanced")
	check(state.staging.occupied_count() == 0, "staging untouched")


func _multi_color_completion() -> void:
	var simulation := TrafficGameFactory.build(_two_color_level())
	check(simulation != null, "two-color level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var first := _dispatch(simulation, &"va")
	check(first.is_success(), "first vehicle dispatched")
	check(not state.is_won(), "level not won after the first vehicle")
	check_eq(state.items.size(), 1, "one passenger remains")
	check_eq(_event_types(first).back(), DomainEvent.ENTITY_COMPLETED, "first dispatch completes only the vehicle")
	var second := _dispatch(simulation, &"vb")
	check(second.is_success(), "second vehicle dispatched")
	check(state.is_won(), "level won after both vehicles")
	check_eq(_event_types(second).back(), DomainEvent.GAME_COMPLETED, "second dispatch completes the level")
	check_eq(state.get_destination(&"station_b").processed_count, 1, "second station processed its item")
	check(state.items.is_empty(), "no items remain")


func _capacity_limited_loading() -> void:
	var definition := _single_vehicle_level()
	definition["vehicles"][0]["capacity"] = 1
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "capacity-limited level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var result := _dispatch(simulation, &"v1")
	check(result.is_success(), "dispatch succeeds")
	var loads := 0
	for event in result.events:
		if event.event_type == DomainEvent.ITEM_LOADED:
			loads += 1
	check_eq(loads, 1, "capacity stops loading at one item")
	check_eq(state.get_entity(&"v1").state, EntityState.Value.COMPLETED, "partially loaded vehicle completes")
	check_eq(state.items.size(), 1, "unloaded item stays queued")
	check(not state.is_won(), "objective incomplete while items remain")
	check(state.is_lost(), "no moves remain after the only vehicle completed")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "dead state reports no_valid_moves")


func _queue_fifo_stops_at_mismatch() -> void:
	var definition := _single_vehicle_level()
	definition["queues"]["q_a"] = ["p1", "p2"]
	definition["passengers"] = [
		{"id": "p1", "color": "COLOR_A", "station": "station_a"},
		{"id": "p2", "color": "COLOR_B", "station": "station_a"},
	]
	definition["stations"][0]["accepted"] = ["COLOR_A", "COLOR_B"]
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "mixed-color queue level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var result := _dispatch(simulation, &"v1")
	check(result.is_success(), "dispatch succeeds")
	check_eq(state.get_entity(&"v1").state, EntityState.Value.COMPLETED, "vehicle completes with a partial load")
	check_eq(state.items.size(), 1, "mismatching front item is not skipped")
	var remaining := state.get_queue(&"q_a").item_ids()
	check_eq(remaining.size(), 1, "queue keeps the unserved item")
	check_eq(remaining[0], &"p2", "FIFO order preserved after the stop")
	check_eq(state.get_destination(&"station_a").processed_count, 1, "only the matching item was processed")
	check(state.is_lost(), "nothing else can move: dead state")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "dead state reason")


func _blocked_vehicle() -> void:
	var definition := _single_vehicle_level()
	definition["paths"]["route_v2"] = [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}]
	definition["paths"]["route_parked"] = [{"x": 2, "y": 1}, {"x": 3, "y": 1}]
	definition["vehicles"].append({
		"id": "v2", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_a",
	})
	# Park a blocker directly on v2's route.
	definition["vehicles"].append({
		"id": "blocker", "type": "truck", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 2, "y": 1}, "route": "route_parked", "station": "station_a",
	})
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "blocking level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var before := simulation.snapshot()
	var result := _dispatch(simulation, &"v2")
	check_eq(result.status, CommandResult.Status.BLOCKED, "blocked dispatch reports blocked")
	check_eq(result.code, &"cell_occupied", "blocked code")
	check_eq(result.events.size(), 1, "blocked dispatch emits one event")
	check_eq(result.events[0].event_type, DomainEvent.ENTITY_BLOCKED, "blocked event type")
	check_eq(result.events[0].get_payload("blockers"), ["blocker"], "blockers reported in payload")
	check(Serialization.values_equal(before, simulation.snapshot()), "blocked dispatch does not mutate state")
	check_eq(state.move_index, 0, "move index unchanged when blocked")


func _blocked_then_freed() -> void:
	var definition := _single_vehicle_level()
	definition["paths"]["route_v2"] = [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}]
	definition["paths"]["route_parked"] = [{"x": 2, "y": 1}, {"x": 3, "y": 1}]
	definition["vehicles"].append({
		"id": "v2", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_a",
	})
	# A parked vehicle with an unrelated colour: it frees the route by staging.
	definition["vehicles"].append({
		"id": "mover", "type": "truck", "color": "COLOR_Z", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 2, "y": 1}, "route": "route_parked", "station": "station_a",
	})
	var simulation := TrafficGameFactory.build(definition)
	if simulation == null:
		check(false, "blocking level builds")
		return
	check_eq(_dispatch(simulation, &"v2").status, CommandResult.Status.BLOCKED, "v2 blocked while mover is ahead")
	check(_dispatch(simulation, &"mover").is_success(), "mover dispatches (loads or stages)")
	check(_dispatch(simulation, &"v2").is_success(), "previously blocked vehicle can move once the path clears")


func _staging_receives_entity() -> void:
	var definition := _single_vehicle_level()
	definition["queues"]["q_a"] = []
	definition["passengers"] = []
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "no-passenger level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var result := _dispatch(simulation, &"v1")
	check(result.is_success(), "dispatch succeeds")
	check(state.staging.has(&"v1"), "unserved vehicle is staged")
	check_eq(state.staging.slot_of(&"v1"), 0, "deterministic slot assignment")
	check_eq(state.get_entity(&"v1").state, EntityState.Value.WAITING, "staged vehicle waits")
	check(not state.get_entity(&"v1").is_placed(), "staged vehicle left the board")
	var staging_events := 0
	for event in result.events:
		if event.event_type == DomainEvent.STAGING_CHANGED:
			staging_events += 1
			check_eq(event.get_payload("action"), DomainEvent.STAGING_ADDED, "staging action is added")
			check_eq(event.get_payload("slot_index"), 0, "staging payload slot index")
			check_eq(event.get_payload("occupied_count"), 1, "staging payload occupancy")
			check_eq(event.get_payload("available_slots"), 3, "staging payload availability")
	check_eq(staging_events, 1, "one staging event emitted")
	check(state.is_lost(), "staged vehicle with nothing left to move loses")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "loss reason")


func _staging_full_failure() -> void:
	var definition := _single_vehicle_level(1)
	definition["queues"]["q_a"] = []
	definition["passengers"] = []
	definition["paths"]["route_v2"] = [{"x": 3, "y": 1}, {"x": 4, "y": 1}]
	definition["vehicles"].append({
		"id": "v2", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 3, "y": 1}, "route": "route_v2", "station": "station_a",
	})
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "single-slot staging level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	check(_dispatch(simulation, &"v1").is_success(), "first unserved vehicle is staged")
	check(state.staging.is_full(), "staging is full after one of one slots")
	check_eq(state.staging.occupied_count(), 1, "occupancy matches capacity")

	var result := _dispatch(simulation, &"v2")
	check(result.is_success(), "the losing move is still a legal action")
	check_eq(result.code, &"staging_full", "loss outcome reports its code")
	var failed := 0
	for event in result.events:
		if event.event_type == DomainEvent.GAME_FAILED:
			failed += 1
			check_eq(event.get_payload("fail_reason"), "staging_full", "fail reason in payload")
	check_eq(failed, 1, "exactly one game_failed event")
	check(state.is_lost(), "level is lost")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.STAGING_FULL), "state records staging_full")
	check(not state.staging.has(&"v2"), "overflowing vehicle is not staged")
	check_eq(state.staging.occupied_count(), 1, "staging occupancy unchanged by overflow")
	check_eq(state.get_entity(&"v2").state, EntityState.Value.WAITING, "unserved vehicle waits")


func _zero_slot_staging() -> void:
	var definition := _single_vehicle_level(0)
	definition["queues"]["q_a"] = []
	definition["passengers"] = []
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "zero-slot staging level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	var result := _dispatch(simulation, &"v1")
	check(result.is_success(), "dispatch succeeds")
	check_eq(result.code, &"staging_full", "no staging capacity means immediate loss")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.STAGING_FULL), "staging_full recorded")


func _arbitrary_staging_capacity() -> void:
	var definition := {
		"level_id": "traffic_staging_6",
		"seed": 3,
		"width": 7,
		"height": 6,
		"staging_slots": 6,
		"paths": {},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 0, "queue": "q_a",
			"cell": {"x": 6, "y": 5}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_a": []},
		"passengers": [],
		"vehicles": [],
	}
	for index in 6:
		definition["paths"]["route_%d" % index] = [{"x": 0, "y": index}, {"x": 1, "y": index}]
		definition["vehicles"].append({
			"id": "v%d" % index, "type": "compact", "color": "COLOR_A", "capacity": 1,
			"cell": {"x": 0, "y": index}, "route": "route_%d" % index, "station": "station_a",
		})
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "six-vehicle/six-slot level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	for index in 6:
		var result := _dispatch(simulation, StringName("v%d" % index))
		check(result.is_success(), "vehicle %d dispatched" % index)
		check_eq(state.staging.slot_of(StringName("v%d" % index)), index, "slot %d used deterministically" % index)
	check(state.staging.is_full(), "all six slots occupied")
	check_eq(state.staging.occupied_count(), 6, "occupancy equals arbitrary capacity")
	check(state.is_lost(), "nothing left to move after all vehicles are staged")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "no_valid_moves reported")


func _dead_state_after_wrong_order() -> void:
	var definition := _two_color_level()
	# Both vehicles target station_a whose queue works for COLOR_A only:
	# dispatching the COLOR_B vehicle first consumes nothing and wastes a slot.
	definition["stations"] = [definition["stations"][0]]
	definition["queues"] = {"q_a": ["pa1"]}
	definition["passengers"] = [{"id": "pa1", "color": "COLOR_A", "station": "station_a"}]
	definition["vehicles"][1]["station"] = "station_a"
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "wrong-order level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	check(_dispatch(simulation, &"vb").is_success(), "wrong vehicle dispatched first and staged")
	check(state.staging.has(&"vb"), "wrong vehicle is stuck in staging")
	check(not state.is_lost(), "level continues while a valid move remains")
	check(_dispatch(simulation, &"va").is_success(), "correct vehicle still completes")
	check(state.items.is_empty(), "all provided items were processed")
	check_not_won_because_staged(state)


func check_not_won_because_staged(state: GameState) -> void:
	check(not state.is_won(), "staged vehicle prevents victory")
	check(state.is_lost(), "no valid moves remain after the staged vehicle is stuck")
	check_eq(state.fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "dead state reason")


func _initial_deadlock_stays_in_progress() -> void:
	var definition := {
		"level_id": "traffic_deadlock",
		"seed": 1,
		"width": 4,
		"height": 2,
		"staging_slots": 4,
		"paths": {
			"route_a": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 3, "y": 0}],
			"route_b": [{"x": 3, "y": 0}, {"x": 2, "y": 0}, {"x": 1, "y": 0}, {"x": 0, "y": 0}],
		},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 0, "queue": "q_a",
			"cell": {"x": 3, "y": 1}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_a": []},
		"passengers": [],
		"vehicles": [
			{"id": "va", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_a", "station": "station_a"},
			{"id": "vb", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 3, "y": 0}, "route": "route_b", "station": "station_a"},
		],
	}
	var simulation := TrafficGameFactory.build(definition)
	check(simulation != null, "mutually blocking level builds")
	if simulation == null:
		return
	var state := simulation.get_state()
	check_eq(_dispatch(simulation, &"va").status, CommandResult.Status.BLOCKED, "va is blocked by vb")
	check_eq(_dispatch(simulation, &"vb").status, CommandResult.Status.BLOCKED, "vb is blocked by va")
	check(state.is_in_progress(), "rejected commands never mutate completion state")
	check(not ProgressEvaluator.has_valid_move(state), "engine agrees there is no valid move")
	check_eq(state.move_index, 0, "no move was consumed")


func _rejections_and_atomicity() -> void:
	var simulation := TrafficGameFactory.build(_single_vehicle_level())
	if simulation == null:
		check(false, "level builds")
		return
	var state := simulation.get_state()
	var before := simulation.snapshot()

	check_eq(_dispatch(simulation, &"ghost").code, &"unknown_entity", "unknown entity rejected")
	check(Serialization.values_equal(before, simulation.snapshot()), "unknown entity rejection is atomic")

	# Completed entity cannot be dispatched again (two-color level stays in progress).
	var second_level := TrafficGameFactory.build(_two_color_level())
	if second_level == null:
		check(false, "level rebuilds for completed check")
		return
	check(_dispatch(second_level, &"va").is_success(), "vehicle completes")
	check(second_level.get_state().is_in_progress(), "level still in progress with another vehicle left")
	var after_completion := second_level.snapshot()
	check_eq(_dispatch(second_level, &"va").code, &"entity_not_placed", "completed vehicle has left the board")
	check(Serialization.values_equal(after_completion, second_level.snapshot()), "post-completion rejection is atomic")

	# Missing path.
	var missing_path := TrafficGameFactory.build(_single_vehicle_level())
	if missing_path == null:
		check(false, "level rebuilds")
		return
	missing_path.get_state().get_entity(&"v1").path_id = &""
	var missing_before := missing_path.snapshot()
	check_eq(_dispatch(missing_path, &"v1").code, &"unknown_path", "missing path rejected")
	check(Serialization.values_equal(missing_before, missing_path.snapshot()), "missing path rejection is atomic")

	# Unknown destination.
	var no_destination := TrafficGameFactory.build(_single_vehicle_level())
	if no_destination == null:
		check(false, "level rebuilds again")
		return
	no_destination.get_state().get_entity(&"v1").destination_id = &""
	var destination_before := no_destination.snapshot()
	check_eq(_dispatch(no_destination, &"v1").code, &"unknown_destination", "unknown destination rejected")
	check(Serialization.values_equal(destination_before, no_destination.snapshot()), "destination rejection is atomic")

	# Invalid path (non-contiguous).
	var broken_path := TrafficGameFactory.build(_single_vehicle_level())
	if broken_path == null:
		check(false, "level rebuilds once more")
		return
	var path := broken_path.get_state().get_path(&"route_v1")
	path.cells = [GridPosition.new(0, 0), GridPosition.new(3, 0)]
	var path_before := broken_path.snapshot()
	check_eq(_dispatch(broken_path, &"v1").code, &"invalid_path", "invalid path rejected")
	check(Serialization.values_equal(path_before, broken_path.snapshot()), "invalid path rejection is atomic")

	# Path that no longer starts where the entity stands.
	var stale_path := TrafficGameFactory.build(_single_vehicle_level())
	if stale_path == null:
		check(false, "level rebuilds for stale path")
		return
	var stale_state := stale_path.get_state()
	stale_state.board.move_entity(stale_state.get_entity(&"v1"), GridPosition.new(1, 0))
	var stale_before := stale_path.snapshot()
	check_eq(_dispatch(stale_path, &"v1").code, &"path_start_mismatch", "stale path rejected")
	check(Serialization.values_equal(stale_before, stale_path.snapshot()), "stale path rejection is atomic")

	# Finished level rejects further commands.
	var finished := TrafficGameFactory.build(_single_vehicle_level())
	if finished == null:
		check(false, "level rebuilds for finished state")
		return
	finished.get_state().set_victory()
	var finished_before := finished.snapshot()
	var finished_result := _dispatch(finished, &"v1")
	check_eq(finished_result.status, CommandResult.Status.GAME_ALREADY_COMPLETE, "finished level rejects dispatch")
	check_eq(finished_result.code, &"game_not_in_progress", "finished level code")
	check(Serialization.values_equal(finished_before, finished.snapshot()), "finished rejection is atomic")

	# Not a board.
	var no_board := TrafficGameFactory.build(_single_vehicle_level())
	if no_board == null:
		check(false, "level rebuilds for board check")
		return
	no_board.get_state().board = Board.new(BoardDimensions.new(0, 0))
	var no_board_before := no_board.snapshot()
	check_eq(_dispatch(no_board, &"v1").code, &"board_not_ready", "unusable board rejected")
	check(Serialization.values_equal(no_board_before, no_board.snapshot()), "board rejection is atomic")


func _factory_validation() -> void:
	check(TrafficGameFactory.validate_definition(_single_vehicle_level()).is_empty(), "valid definition has no errors")
	check(TrafficGameFactory.validate_definition({}).has("missing_level_id"), "missing level id reported")
	check(TrafficGameFactory.validate_definition(_single_vehicle_level()).is_empty(), "validation is repeatable")

	var no_vehicles := _single_vehicle_level()
	no_vehicles["vehicles"] = []
	check(TrafficGameFactory.validate_definition(no_vehicles).has("vehicles_missing"), "missing vehicles reported")
	check(TrafficGameFactory.build(no_vehicles) == null, "invalid definition is not built")

	var unknown_station := _single_vehicle_level()
	unknown_station["vehicles"][0]["station"] = "station_missing"
	check(TrafficGameFactory.validate_definition(unknown_station).has("vehicle_unknown_station:v1"), "unknown station reported")

	var unknown_route := _single_vehicle_level()
	unknown_route["vehicles"][0]["route"] = "route_missing"
	check(TrafficGameFactory.validate_definition(unknown_route).has("vehicle_unknown_route:v1"), "unknown route reported")

	var mismatched_route := _single_vehicle_level()
	mismatched_route["paths"]["route_v1"] = [{"x": 1, "y": 0}, {"x": 2, "y": 0}]
	check(TrafficGameFactory.validate_definition(mismatched_route).has("vehicle_route_start_mismatch:v1"), "route/cell mismatch reported")

	var bad_capacity := _single_vehicle_level()
	bad_capacity["vehicles"][0]["capacity"] = 0
	check(TrafficGameFactory.validate_definition(bad_capacity).has("vehicle_invalid_capacity:v1"), "invalid capacity reported")

	var duplicate_vehicle := _single_vehicle_level()
	duplicate_vehicle["vehicles"].append(duplicate_vehicle["vehicles"][0].duplicate(true))
	check(TrafficGameFactory.validate_definition(duplicate_vehicle).has("duplicate_vehicle_id:v1"), "duplicate vehicle reported")

	var orphan_passenger := _single_vehicle_level()
	orphan_passenger["passengers"].append({"id": "p9", "color": "COLOR_A", "station": "station_a"})
	check(TrafficGameFactory.validate_definition(orphan_passenger).has("unreferenced_passenger:p9"), "unreferenced passenger reported")

	var unknown_item := _single_vehicle_level()
	unknown_item["queues"]["q_a"] = ["p1", "missing_passenger"]
	check(TrafficGameFactory.validate_definition(unknown_item).has("queue_unknown_passenger:missing_passenger"), "unknown queued passenger reported")

	var unknown_objective := _single_vehicle_level()
	unknown_objective["objectives"] = [{"id": "o1", "type": "not_a_type"}]
	check(TrafficGameFactory.validate_definition(unknown_objective).has("unknown_objective_type:o1"), "unknown objective reported")

	var out_of_bounds := _single_vehicle_level()
	out_of_bounds["vehicles"][0]["cell"] = {"x": 99, "y": 0}
	var oob_errors := TrafficGameFactory.validate_definition(out_of_bounds)
	check(oob_errors.has("vehicle_out_of_bounds:v1") or oob_errors.has("vehicle_route_start_mismatch:v1"), "out-of-bounds vehicle reported")


func _determinism_replay() -> void:
	var sequence: Array[StringName] = [&"va", &"vb"]
	var first := _run_scripted(sequence)
	var second := _run_scripted(sequence)
	check(first["snapshot_ok"], "first run produced a snapshot")
	check(Serialization.values_equal(first["snapshot"], second["snapshot"]), "identical command sequences produce identical state")
	check_eq(first["events"], second["events"], "identical command sequences produce identical event streams")
	check_eq(first["queue_state"], second["queue_state"], "queue state identical across runs")
	check_eq(first["staging_state"], second["staging_state"], "staging state identical across runs")
	check_eq(first["completion"], second["completion"], "completion state identical across runs")

	var third := _run_scripted(sequence, 999)
	check_eq(third["events"], first["events"], "seed does not affect M2 rules (no randomness consumed)")
	check(
		Serialization.values_equal(_logic_projection(third["snapshot"]), _logic_projection(first["snapshot"])),
		"seed does not change the resulting logic state"
	)


## Snapshot without the RNG/seed bookkeeping keys (rules are seed-independent).
func _logic_projection(snapshot: Dictionary) -> Dictionary:
	var projection: Dictionary = snapshot.duplicate(true)
	projection.erase("seed")
	projection.erase("rng_state")
	return projection


func _no_randomness_in_m2_rules() -> void:
	var simulation := TrafficGameFactory.build(_single_vehicle_level())
	if simulation == null:
		check(false, "level builds for rng check")
		return
	var rng_before := simulation.get_state().rng_state
	check(_dispatch(simulation, &"v1").is_success(), "dispatch succeeds")
	check_eq(simulation.get_state().rng_state, rng_before, "M2 gameplay consumes no randomness")


func _run_scripted(sequence: Array[StringName], seed_value: int = 5) -> Dictionary:
	var definition := _two_color_level()
	definition["seed"] = seed_value
	var simulation := TrafficGameFactory.build(definition)
	if simulation == null:
		return {"snapshot_ok": false}
	var events: Array = []
	for entity_id in sequence:
		var result := _dispatch(simulation, entity_id)
		for event in result.events:
			events.append(event.to_dictionary())
	var state := simulation.get_state()
	var queue_state: Array = []
	for queue_id in state.queue_ids():
		queue_state.append(state.get_queue(queue_id).to_dictionary())
	return {
		"snapshot_ok": true,
		"snapshot": simulation.snapshot(),
		"events": events,
		"queue_state": queue_state,
		"staging_state": state.staging.to_dictionary(),
		"completion": [GameState.completion_state_name(state.completion_state), String(state.fail_reason)],
	}
