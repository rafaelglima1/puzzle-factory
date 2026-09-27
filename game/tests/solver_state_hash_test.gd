extends "res://tests/framework/test_base.gd"
## SolverStateHasher: deterministic identity over real [GameState] values.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")

## Every key [method GameState.to_dictionary] is expected to emit. Anything
## outside this set would be a new (possibly non-logical) field leaking into the
## hash input.
const LOGICAL_KEYS := [
	"schema_version", "level_id", "level_revision", "seed", "rng_state",
	"move_index", "elapsed_ms", "completion_state", "fail_reason", "board",
	"entities", "items", "queues", "destinations", "paths", "staging",
	"objectives", "objectives_completed",
]


func run() -> void:
	_stable_digest()
	_snapshot_roundtrip()
	_future_relevant_mutations()
	_canonical_contains_only_logical_keys()
	_states_equal()


func _make_state() -> GameState:
	var state := GameState.new(&"level_hash", 424242, BoardDimensions.new(4, 4))
	state.level_revision = 2
	state.move_index = 5
	state.rng_state = 777
	state.elapsed_ms = 100

	var mover := Fixture.make_entity(&"e1", 1, 1, &"unit")
	mover.color_key = &"COLOR_A"
	mover.state = EntityState.Value.IDLE
	state.board.place_entity(mover, GridPosition.new(1, 1))
	state.add_entity(mover)

	var item_a := Item.new(&"i1", &"generic", &"COLOR_A")
	var item_b := Item.new(&"i2", &"generic", &"COLOR_B")
	state.add_item(item_a)
	state.add_item(item_b)

	var queue := ItemQueue.new(&"q1")
	queue.enqueue(&"i1")
	queue.enqueue(&"i2")
	state.add_queue(queue)
	return state


func _stable_digest() -> void:
	var state := _make_state()
	var first := SolverStateHasher.hash_state(state)
	var second := SolverStateHasher.hash_state(state)
	check_eq(first, second, "same state produces the same digest on repeated calls")
	check_eq(first.length(), 64, "digest is a 64-character hex string")
	check(SolverStateHasher.is_valid_digest(first), "digest is lowercase hexadecimal")
	check(first != "", "digest is not empty")


func _snapshot_roundtrip() -> void:
	var state := _make_state()
	var restored := GameState.from_dictionary(state.to_dictionary())
	check(restored != null, "state restores from its canonical dictionary")
	if restored == null:
		return

	check_eq(
		SolverStateHasher.hash_state(state),
		SolverStateHasher.hash_state(restored),
		"dictionary roundtrip preserves the digest"
	)
	check_eq(
		SolverStateHasher.hash_snapshot(SolverStateHasher.canonical_state(state)),
		SolverStateHasher.hash_state(state),
		"hash_snapshot over canonical_state matches hash_state"
	)

	var parsed: Variant = Serialization.from_json(Serialization.to_json(state.to_dictionary()))
	var from_json := GameState.from_dictionary(parsed)
	check(from_json != null, "state restores from JSON")
	if from_json != null:
		check_eq(
			SolverStateHasher.hash_state(state),
			SolverStateHasher.hash_state(from_json),
			"JSON roundtrip preserves the digest"
		)

	check_eq(SolverStateHasher.canonical_state(null).size(), 0, "null state canonicalizes to empty")


func _future_relevant_mutations() -> void:
	var base_hash := SolverStateHasher.hash_state(_make_state())

	var moved_index := _make_state()
	moved_index.move_index += 1
	check(base_hash != SolverStateHasher.hash_state(moved_index), "move_index affects the digest")

	var advanced_rng := _make_state()
	advanced_rng.rng_state = 123456
	check(base_hash != SolverStateHasher.hash_state(advanced_rng), "rng_state affects the digest")

	var removed_item := _make_state()
	removed_item.remove_item(&"i2")
	check(base_hash != SolverStateHasher.hash_state(removed_item), "removing an item affects the digest")

	var reordered_queue := _make_state()
	var queue: ItemQueue = reordered_queue.get_queue(&"q1")
	queue.remove(&"i1")
	queue.remove(&"i2")
	queue.enqueue(&"i2")
	queue.enqueue(&"i1")
	check(base_hash != SolverStateHasher.hash_state(reordered_queue), "queue order affects the digest")

	var repositioned := _make_state()
	var mover: Entity = repositioned.get_entity(&"e1")
	repositioned.board.move_entity(mover, GridPosition.new(2, 2))
	check(base_hash != SolverStateHasher.hash_state(repositioned), "entity position affects the digest")

	var restated := _make_state()
	var entity: Entity = restated.get_entity(&"e1")
	entity.state = EntityState.Value.MOVING
	check(base_hash != SolverStateHasher.hash_state(restated), "entity state affects the digest")

	var completed := _make_state()
	completed.set_victory()
	check(base_hash != SolverStateHasher.hash_state(completed), "completion affects the digest")

	var other_seed := GameState.new(&"level_hash", 999, BoardDimensions.new(4, 4))
	check(base_hash != SolverStateHasher.hash_state(other_seed), "seed and derived rng affect the digest")


func _canonical_contains_only_logical_keys() -> void:
	var canonical: Dictionary = SolverStateHasher.canonical_state(_make_state())
	for key in canonical.keys():
		check(LOGICAL_KEYS.has(String(key)), "canonical state has only logical key: %s" % String(key))
	check(canonical.has("entities"), "canonical state includes entities")
	check(canonical.has("move_index"), "canonical state includes move_index")


func _states_equal() -> void:
	var a := _make_state()
	var b := GameState.from_dictionary(a.to_dictionary())
	check(SolverStateHasher.states_equal(a, b), "logically equal states compare equal")
	if b != null:
		b.move_index += 1
	check(not SolverStateHasher.states_equal(a, b), "mutated state compares unequal")
	check(not SolverStateHasher.states_equal(a, null), "null comparison is unequal")
