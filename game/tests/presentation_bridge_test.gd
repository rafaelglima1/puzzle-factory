extends "res://tests/framework/test_base.gd"
## Presentation bridge: FIFO queue behaviour, ordering, contract surface.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_fifo_behaviour()
	_queue_from_results()
	_drain_and_clear()
	_consuming_events_never_mutates_state()
	_contract_surface()


func _fifo_behaviour() -> void:
	var queue := SimulationEventQueue.new()
	check(queue.is_empty(), "new queue is empty")
	check_eq(queue.size(), 0, "new queue size is 0")
	check(queue.peek() == null, "peek on empty queue is null")
	check(queue.dequeue() == null, "dequeue on empty queue is null")
	queue.enqueue(DomainEvent.entity_moved(&"a", GridPosition.new(0, 0), GridPosition.new(1, 0)))
	queue.enqueue(DomainEvent.entity_moved(&"b", GridPosition.new(0, 0), GridPosition.new(1, 0)))
	check_eq(queue.size(), 2, "size after enqueue")
	check_eq(queue.peek().get_payload("entity_id"), "a", "peek returns the oldest event")
	check_eq(queue.dequeue().get_payload("entity_id"), "a", "FIFO order (1)")
	check_eq(queue.dequeue().get_payload("entity_id"), "b", "FIFO order (2)")
	check(queue.is_empty(), "queue empty after consuming all events")
	queue.enqueue(null)
	check(queue.is_empty(), "null events are ignored")


func _queue_from_results() -> void:
	var simulation := Fixture.make_simulation(&"level", 5, 4, 4)
	var queue := SimulationEventQueue.new()
	queue.enqueue_result(Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0)))
	queue.enqueue_result(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(2, 2))))
	check_eq(queue.size(), 3, "queue holds placement plus move events")
	check_eq(queue.dequeue().event_type, DomainEvent.ENTITY_PLACED, "first queued event is placed")
	check_eq(queue.dequeue().event_type, DomainEvent.ENTITY_MOVE_STARTED, "second queued event is move started")
	check_eq(queue.dequeue().event_type, DomainEvent.ENTITY_MOVED, "third queued event is moved")
	var blocked_queue := SimulationEventQueue.new()
	Fixture.place(simulation, Fixture.make_entity(&"wall"), GridPosition.new(3, 3))
	blocked_queue.enqueue_result(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(3, 3))))
	check_eq(blocked_queue.size(), 1, "rejected command still yields presentation feedback")
	check_eq(blocked_queue.dequeue().event_type, DomainEvent.ENTITY_BLOCKED, "blocked feedback event type")
	queue.enqueue_result(null)
	check(queue.is_empty(), "null results are ignored")
	var events: Array[DomainEvent] = [DomainEvent.entity_moved(&"x", GridPosition.new(0, 0), GridPosition.new(1, 0))]
	queue.enqueue_all(events)
	check_eq(queue.size(), 1, "enqueue_all appends events")


func _drain_and_clear() -> void:
	var queue := SimulationEventQueue.new()
	queue.enqueue(DomainEvent.entity_moved(&"a", GridPosition.new(0, 0), GridPosition.new(1, 0)))
	queue.enqueue(DomainEvent.entity_moved(&"b", GridPosition.new(0, 0), GridPosition.new(1, 0)))
	var drained := queue.drain()
	check_eq(drained.size(), 2, "drain returns all pending events")
	check_eq(drained[0].get_payload("entity_id"), "a", "drain preserves order")
	check(queue.is_empty(), "queue empty after drain")
	queue.enqueue(DomainEvent.entity_moved(&"c", GridPosition.new(0, 0), GridPosition.new(1, 0)))
	queue.clear()
	check(queue.is_empty(), "clear empties the queue")
	check_eq(int(queue.to_dictionary()["size"]), 0, "serialized size reflects empty queue")


func _consuming_events_never_mutates_state() -> void:
	var simulation := Fixture.make_simulation(&"level", 5, 4, 4)
	Fixture.place(simulation, Fixture.make_entity(&"a"), GridPosition.new(0, 0))
	var queue := SimulationEventQueue.new()
	queue.enqueue_result(simulation.execute(MoveEntityCommand.new(&"a", GridPosition.new(1, 1))))
	var after_command := simulation.snapshot()
	queue.drain()
	check(Serialization.values_equal(after_command, simulation.snapshot()), "consuming events does not mutate simulation state")
	check_eq(simulation.get_state().get_entity(&"a").position.x, 1, "state reflects the applied command")


func _contract_surface() -> void:
	check_eq(PresentationContract.CONTRACT_VERSION, 1, "contract version pinned (M2 additive)")
	check_eq(PresentationContract.known_event_types().size(), 12, "event vocabulary size (M1 + M2)")
	var schemas_present := true
	for event_type in PresentationContract.known_event_types():
		if PresentationContract.payload_schema(event_type).is_empty():
			schemas_present = false
	check(schemas_present, "every known event type has a payload schema")
	check(PresentationContract.is_known_event(DomainEvent.COMMAND_REJECTED), "rejection is a known event")
	check(
		PresentationContract.validate_event(DomainEvent.new(&"", {})).has("unknown_event_type:"),
		"empty event type is reported as unknown"
	)
