extends "res://tests/framework/test_base.gd"
## Generic destination: accepted keys, capacity semantics, state, serialization.


func run() -> void:
	_defaults()
	_acceptance()
	_capacity()
	_serialization()
	_equality()


func _defaults() -> void:
	var destination := Destination.new(&"d1", &"unit_destination")
	check_eq(destination.id, &"d1", "id")
	check_eq(destination.destination_type, &"unit_destination", "destination type")
	check_eq(destination.capacity, 0, "capacity default is unlimited (0)")
	check_eq(destination.processed_count, 0, "processed count default")
	check_eq(destination.queue_id, &"", "queue id default")
	check_eq(destination.state, Destination.State.OPEN, "state default is open")
	check(destination.has_capacity(), "unlimited destination has capacity")
	check(not destination.is_full(), "unlimited destination is never full")


func _acceptance() -> void:
	var open_destination := Destination.new(&"d1")
	check(open_destination.accepts(&"COLOR_A"), "empty accepted list accepts everything")
	check(open_destination.accepts(&"COLOR_Z"), "empty accepted list accepts unknown keys too")
	var restricted := Destination.new(&"d2")
	restricted.accepted_color_keys = [&"COLOR_A", &"COLOR_B"]
	check(restricted.accepts(&"COLOR_A"), "listed key accepted")
	check(restricted.accepts(&"COLOR_B"), "second listed key accepted")
	check(not restricted.accepts(&"COLOR_C"), "unlisted key rejected")
	check(not restricted.accepts(&""), "empty key rejected when a list exists")


func _capacity() -> void:
	var destination := Destination.new(&"d1")
	destination.capacity = 2
	check(destination.has_capacity(), "capacity available at start")
	destination.processed_count = 1
	check(destination.has_capacity(), "capacity available with one item processed")
	destination.refresh_state()
	check_eq(destination.state, Destination.State.OPEN, "state open while below capacity")
	destination.processed_count = 2
	check(not destination.has_capacity(), "capacity exhausted")
	check(destination.is_full(), "destination reports full")
	destination.refresh_state()
	check_eq(destination.state, Destination.State.FULL, "state becomes full")
	check_eq(Destination.state_to_string_name(destination.state), &"full", "state name is stable")
	check_eq(Destination.state_from_string_name(&"open"), Destination.State.OPEN, "state name roundtrips")
	check_eq(Destination.state_from_string_name(&"nope"), -1, "unknown state name reports -1")
	var unlimited := Destination.new(&"d2")
	unlimited.capacity = 0
	unlimited.processed_count = 99
	check(unlimited.has_capacity(), "zero capacity means unlimited")
	check(not unlimited.is_full(), "unlimited destination never fills")


func _serialization() -> void:
	var destination := Destination.new(&"d1", &"unit_destination")
	destination.accepted_color_keys = [&"COLOR_B", &"COLOR_A"]
	destination.capacity = 3
	destination.queue_id = &"q1"
	destination.processed_count = 1
	destination.refresh_state()
	destination.metadata = {"cell": {"x": 1, "y": 2}}
	var restored := Destination.from_dictionary(destination.to_dictionary())
	check(restored.logical_equals(destination), "roundtrip preserves the destination")
	check_eq(restored.accepted_color_keys, destination.accepted_color_keys, "accepted keys restored")
	check_eq(restored.processed_count, 1, "processed count restored")
	check_eq(restored.state, Destination.State.OPEN, "state restored")
	check_eq(restored.queue_id, &"q1", "queue id restored")
	check(restored.metadata.has("cell"), "metadata restored")
	var unknown_state := Destination.from_dictionary({"id": "d2", "state": "confused"})
	check_eq(unknown_state.state, Destination.State.OPEN, "unknown state falls back to open")


func _equality() -> void:
	var first := Destination.new(&"d1")
	var second := Destination.new(&"d1")
	check(first.logical_equals(second), "identical destinations are equal")
	second.capacity = 5
	check(not first.logical_equals(second), "capacity difference breaks equality")
	check(not first.logical_equals(null), "null comparison is safe")
