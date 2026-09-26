extends "res://tests/framework/test_base.gd"
## Generic staging area: arbitrary capacity, deterministic slots, overflow.


func run() -> void:
	_defaults_and_capacity()
	_deterministic_slots()
	_full_and_overflow()
	_resizing()
	_serialization()


func _defaults_and_capacity() -> void:
	var staging := StagingArea.new()
	check_eq(staging.slot_count, 4, "default slot count is 4")
	check_eq(staging.slot_count, StagingArea.DEFAULT_SLOT_COUNT, "default constant matches")
	check_eq(staging.occupied_count(), 0, "empty at start")
	check_eq(staging.available_slots(), 4, "all slots available")
	check(not staging.is_full(), "not full at start")
	for capacity in [0, 1, 3, 5, 6]:
		var sized := StagingArea.new(capacity)
		check_eq(sized.slot_count, capacity, "arbitrary slot count %d accepted" % capacity)
		check_eq(sized.available_slots(), capacity, "available slots match capacity %d" % capacity)
		check_eq(sized.occupants().size(), capacity, "occupant array tracks capacity %d" % capacity)
	var negative := StagingArea.new(-3)
	check_eq(negative.slot_count, 0, "negative capacity clamps to zero")


func _deterministic_slots() -> void:
	var staging := StagingArea.new(4)
	check_eq(staging.add(&"a"), 0, "first occupant takes slot 0")
	check_eq(staging.add(&"b"), 1, "second occupant takes slot 1")
	check_eq(staging.add(&"c"), 2, "third occupant takes slot 2")
	check_eq(staging.slot_of(&"b"), 1, "slot lookup by id")
	check(staging.has(&"c"), "has reports staged entity")
	var expected_layout: Array[StringName] = [&"a", &"b", &"c", &""]
	check_eq(staging.occupants(), expected_layout, "slot layout is deterministic")
	check(staging.remove(&"b"), "remove staged entity")
	check_eq(staging.add(&"d"), 1, "lowest free slot is reused after removal")
	check_eq(staging.slot_of(&"d"), 1, "reused slot index")
	check_eq(staging.occupied_count(), 3, "occupied count after reuse")
	check(not staging.remove(&"missing"), "removing an unknown occupant is refused")
	check_eq(staging.add(&"a"), -1, "duplicate occupant rejected")
	check_eq(staging.add(&""), -1, "empty occupant rejected")
	check_eq(staging.occupant_at(99), &"", "out-of-range slot reads as free")
	check_eq(staging.slot_of(&"missing"), -1, "unknown occupant slot is -1")
	staging.clear()
	check_eq(staging.occupied_count(), 0, "clear frees every slot")
	check_eq(staging.slot_count, 4, "clear preserves slot count")


func _full_and_overflow() -> void:
	var staging := StagingArea.new(3)
	check_eq(staging.add(&"a"), 0, "fill 1")
	check_eq(staging.add(&"b"), 1, "fill 2")
	check_eq(staging.add(&"c"), 2, "fill 3")
	check(staging.is_full(), "staging reports full")
	check_eq(staging.available_slots(), 0, "no slots available when full")
	check_eq(staging.add(&"d"), -1, "overflow is refused safely")
	check_eq(staging.occupied_count(), 3, "overflow does not corrupt occupancy")
	check(not staging.has(&"d"), "overflowed entity is not staged")
	var zero := StagingArea.new(0)
	check(zero.is_full(), "zero-slot staging is immediately full")
	check_eq(zero.add(&"a"), -1, "zero-slot staging refuses occupants")


func _resizing() -> void:
	var staging := StagingArea.new(4)
	staging.add(&"a")
	staging.add(&"b")
	check(staging.set_slot_count(6), "growing is allowed")
	check_eq(staging.slot_count, 6, "grown slot count")
	check_eq(staging.occupied_count(), 2, "occupants survive growth")
	check_eq(staging.slot_of(&"a"), 0, "existing slots keep their indices")
	check(not staging.set_slot_count(1), "shrinking below occupancy is refused")
	check_eq(staging.slot_count, 6, "refused resize leaves capacity untouched")
	check(staging.set_slot_count(2), "shrinking to occupancy is allowed")
	check_eq(staging.slot_count, 2, "shrunk slot count")
	check(not staging.set_slot_count(-1), "negative capacity is refused")


func _serialization() -> void:
	var staging := StagingArea.new(5)
	staging.add(&"a")
	staging.add(&"b")
	staging.remove(&"a")
	var restored := StagingArea.from_dictionary(staging.to_dictionary())
	check(restored.logical_equals(staging), "roundtrip preserves staging state")
	check_eq(restored.slot_count, 5, "slot count restored")
	check_eq(restored.occupants(), staging.occupants(), "occupant layout restored exactly")
	check_eq(restored.slot_of(&"b"), 1, "slot index preserved after roundtrip")
	check(not restored.logical_equals(null), "null comparison is safe")
	var odd_payload := StagingArea.from_dictionary({"slot_count": 2, "occupants": ["x", "y", "z"]})
	var expected_clamped: Array[StringName] = [&"x", &"y"]
	check_eq(odd_payload.occupants(), expected_clamped, "extra occupants beyond capacity are ignored")
