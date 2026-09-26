extends "res://tests/framework/test_base.gd"
## Domain events: deterministic ordering, payload conventions, contract fit.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_ordering_determinism()
	_payload_conventions()
	_serialization()
	_contract_coverage()
	_factories()


func _ordering_determinism() -> void:
	var first := _run_scripted_session()
	var second := _run_scripted_session()
	check_eq(first.size(), second.size(), "identical runs emit the same number of events")
	check(first.size() > 10, "scripted session emits a meaningful event stream")
	var identical := true
	for index in first.size():
		if not first[index].logical_equals(second[index]):
			identical = false
			break
	check(identical, "event stream is identical for an identical command sequence")

	var simulation := Fixture.make_simulation(&"level", 5, 4, 4)
	var place_result := simulation.execute(PlaceEntityCommand.new(Fixture.make_entity(&"a"), GridPosition.new(0, 0)))
	_check_contiguous_sequences(place_result)
	var move_result := simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 1)))
	_check_contiguous_sequences(move_result)
	check_eq(move_result.events[0].event_type, DomainEvent.ENTITY_MOVE_STARTED, "start event precedes arrival")
	check_eq(move_result.events[1].event_type, DomainEvent.ENTITY_MOVED, "arrival follows start")


func _check_contiguous_sequences(result: CommandResult) -> void:
	var contiguous := true
	for index in result.events.size():
		if result.events[index].sequence != index:
			contiguous = false
	check(contiguous, "sequence indexes are contiguous from 0 (%s)" % result.status_name())


func _run_scripted_session() -> Array[DomainEvent]:
	var simulation := Fixture.make_simulation(&"scripted", 77, 4, 4)
	var stream: Array[DomainEvent] = []
	stream.append_array(Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0)).events)
	stream.append_array(Fixture.place(simulation, Fixture.make_entity(&"b", 2, 1), GridPosition.new(1, 0)).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 3))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 0))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(9, 9))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 3))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 0))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 0))).events)
	stream.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(4, 4))).events)
	return stream


func _payload_conventions() -> void:
	var simulation := Fixture.make_simulation(&"level", 5, 5, 4)
	Fixture.place(simulation, Fixture.make_entity(&"mover", 2, 1), GridPosition.new(0, 2))
	Fixture.place(simulation, Fixture.make_entity(&"z_second"), GridPosition.new(0, 1))
	Fixture.place(simulation, Fixture.make_entity(&"a_first"), GridPosition.new(1, 1))
	var blocked := simulation.execute(MoveEntityCommand.new(&"mover", GridPosition.new(0, 1)))
	check_eq(blocked.status, CommandResult.Status.BLOCKED, "blocked for payload inspection")
	check(Serialization.values_equal(blocked.events[0].get_payload("blockers"), ["a_first", "z_second"]), "blockers are sorted strings")
	check(Serialization.values_equal(blocked.events[0].get_payload("target"), {"x": 0, "y": 1}), "target serialized as position dictionary")
	check_eq(blocked.events[0].get_payload("entity_id"), "mover", "entity ids are strings")
	for event in blocked.events:
		check(Serialization.is_primitive_tree(event.data), "payload stays primitive-only")

	var ok_simulation := Fixture.make_simulation(&"level", 5, 4, 4)
	Fixture.place(ok_simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0))
	var moved := ok_simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 0)))
	var from_payload: Dictionary = moved.events[0].get_payload("from")
	check(typeof(from_payload["x"]) == TYPE_INT, "position x is an int")
	check(typeof(from_payload["y"]) == TYPE_INT, "position y is an int")
	check(not moved.events[0].data.has("position"), "move payloads use from/to, not position")


func _serialization() -> void:
	var event := DomainEvent.entity_moved(&"a", GridPosition.new(0, 0), GridPosition.new(2, 3))
	event.sequence = 4
	var restored := DomainEvent.from_dictionary(event.to_dictionary())
	check_eq(restored.event_type, DomainEvent.ENTITY_MOVED, "event type restored")
	check_eq(restored.sequence, 4, "sequence restored")
	check(restored.logical_equals(event), "event logical equality after roundtrip")
	check(event.logical_equals(event), "self equality")
	check(not event.logical_equals(null), "null comparison is safe")

	var rejected := DomainEvent.command_rejected(CommandResult.Status.INVALID, &"unknown_entity", &"ghost")
	check_eq(rejected.get_payload("status"), "invalid", "rejection payload status")
	check_eq(rejected.get_payload("code"), "unknown_entity", "rejection payload code")
	check_eq(rejected.get_payload("entity_id"), "ghost", "rejection payload entity id")
	check_eq(DomainEvent.command_rejected(CommandResult.Status.INVALID, &"x").get_payload("entity_id"), "", "rejection entity id defaults to empty")


func _contract_coverage() -> void:
	var simulation := Fixture.make_simulation(&"coverage", 123, 5, 5)
	var events: Array[DomainEvent] = []
	events.append_array(Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0)).events)
	events.append_array(Fixture.place(simulation, Fixture.make_entity(&"b"), GridPosition.new(0, 1)).events)
	events.append_array(Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(2, 2)).events)
	events.append_array(Fixture.place(simulation, Fixture.make_entity(&"c"), GridPosition.new(0, 1)).events)
	events.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(2, 3))).events)
	events.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(0, 1))).events)
	events.append_array(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(9, 9))).events)
	events.append_array(simulation.execute(MoveEntityCommand.new(&"ghost", GridPosition.new(0, 0))).events)
	check(events.size() > 0, "coverage session emits events")

	var emitted_types := {}
	var all_valid := true
	for event in events:
		emitted_types[event.event_type] = true
		if not PresentationContract.validate_event(event).is_empty():
			all_valid = false
	check(all_valid, "every emitted event validates against PresentationContract")
	check_eq(emitted_types.size(), PresentationContract.known_event_types().size(), "M1 exercises the whole M1 event vocabulary")
	check_eq(PresentationContract.CONTRACT_VERSION, 1, "contract version pinned at 1")
	check_eq(PresentationContract.known_event_types().size(), 5, "M1 vocabulary has five event types")
	check(PresentationContract.is_known_event(DomainEvent.ENTITY_PLACED), "placed is a known event")
	check(not PresentationContract.is_known_event(&"not_a_real_event"), "unknown event type rejected")

	check(not PresentationContract.validate_event(null).is_empty(), "null event is invalid")
	check(not PresentationContract.validate_event(DomainEvent.new(&"not_a_real_event", {})).is_empty(), "unknown type is invalid")
	var missing_keys := DomainEvent.new(DomainEvent.ENTITY_MOVED, {"entity_id": "a"})
	check(
		PresentationContract.validate_event(missing_keys).has("missing_payload_key:entity_moved:from"),
		"missing payload keys are reported"
	)
	var bad_shape := DomainEvent.new(DomainEvent.ENTITY_MOVED, {
		"entity_id": "a",
		"from": {"x": "zero", "y": 0},
		"to": {"x": 0, "y": 0},
	})
	check(
		PresentationContract.validate_event(bad_shape).has("payload_shape_mismatch:entity_moved:from"),
		"payload shape mismatches are reported"
	)
	var non_primitive := DomainEvent.new(DomainEvent.ENTITY_MOVED, {
		"entity_id": "a",
		"from": GridPosition.new(0, 0),
		"to": GridPosition.new(1, 1),
	})
	check(not PresentationContract.validate_event(non_primitive).is_empty(), "engine objects in payload are rejected")


func _factories() -> void:
	var placed := DomainEvent.entity_placed(&"a", GridPosition.new(1, 2), Footprint.new(2, 1))
	check_eq(placed.event_type, DomainEvent.ENTITY_PLACED, "placed factory type")
	check(Serialization.values_equal(placed.get_payload("position"), {"x": 1, "y": 2}), "placed factory position")
	check(Serialization.values_equal(placed.get_payload("footprint"), {"width": 2, "height": 1}), "placed factory footprint")
	check_eq(placed.sequence, 0, "fresh events start at sequence 0")

	var blocked := DomainEvent.entity_blocked(&"a", GridPosition.new(0, 0), [&"b", &"c"])
	check(Serialization.values_equal(blocked.get_payload("blockers"), ["b", "c"]), "blocked factory converts ids to strings")

	var started := DomainEvent.entity_move_started(&"a", GridPosition.new(0, 0), GridPosition.new(1, 0))
	check_eq(started.event_type, DomainEvent.ENTITY_MOVE_STARTED, "move started factory type")
	check(Serialization.values_equal(started.get_payload("to"), {"x": 1, "y": 0}), "move started factory target")
