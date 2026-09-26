extends "res://tests/framework/test_base.gd"
## Deterministic RNG: reproducibility, golden vector, state restore, ranges.

const SEED_A := 987234
const GOLDEN_FIRST := 724829683
const GOLDEN_SECOND := 199803568


func run() -> void:
	_reproducibility()
	_golden_vector()
	_state_restore()
	_ranges()
	_floats()
	_shuffle()
	_interface()


func _reproducibility() -> void:
	var first := DeterministicRng.new(SEED_A)
	var second := DeterministicRng.new(SEED_A)
	var identical := true
	for i in 64:
		if first.next_int() != second.next_int():
			identical = false
			break
	check(identical, "same seed reproduces an identical sequence")

	var baseline := DeterministicRng.new(SEED_A)
	var different := DeterministicRng.new(SEED_A + 1)
	var diverged := false
	for i in 64:
		if different.next_int() != baseline.next_int():
			diverged = true
			break
	check(diverged, "different seed diverges")


func _golden_vector() -> void:
	var rng := DeterministicRng.new(SEED_A)
	check_eq(rng.next_int(), GOLDEN_FIRST, "golden first value (cross-machine stability)")
	check_eq(rng.next_int(), GOLDEN_SECOND, "golden second value (cross-machine stability)")
	check_eq(DeterministicRng.normalize_seed(0), 0, "zero seed normalizes to 0")
	check_eq(DeterministicRng.normalize_seed(-1), DeterministicRng.MODULUS - 1, "negative seed normalizes into range")
	check_eq(DeterministicRng.normalize_seed(DeterministicRng.MODULUS + 5), 5, "seed above modulus normalizes")
	check_eq(DeterministicRng.new(-1).get_seed_state(), DeterministicRng.MODULUS - 1, "negative seed accepted at construction")


func _state_restore() -> void:
	var rng := DeterministicRng.new(SEED_A)
	for i in 5:
		rng.next_int()
	var saved := rng.get_state()
	var expected: Array[int] = []
	for i in 8:
		expected.append(rng.next_int())

	rng.set_state(saved)
	var reproduced := true
	for i in 8:
		if rng.next_int() != expected[i]:
			reproduced = false
			break
	check(reproduced, "restored state continues the same sequence")

	var clone := DeterministicRng.new(0)
	clone.set_state(saved)
	check_eq(clone.next_int(), expected[0], "separate instance restored from serialized state")
	for i in range(1, 8):
		clone.next_int()
	check_eq(clone.get_seed_state(), rng.get_seed_state(), "state converges after identical sequences")
	check(Serialization.values_equal(saved, {"state": int(saved["state"])}), "state dictionary is primitive-only")


func _ranges() -> void:
	var rng := DeterministicRng.new(4242)
	var seen := {}
	var in_range := true
	for i in 2000:
		var value := rng.next_int_range(3, 7)
		if value < 3 or value > 7:
			in_range = false
			break
		seen[value] = true
	check(in_range, "range values stay within bounds")
	check_eq(seen.size(), 5, "every value of a small range appears")
	check_eq(rng.next_int_range(9, 2), 9, "inverted range returns min deterministically")
	check_eq(rng.next_int_range(5, 5), 5, "single-value range")

	var first := DeterministicRng.new(77)
	var second := DeterministicRng.new(77)
	var same := true
	for i in 32:
		if first.next_int_range(0, 100) != second.next_int_range(0, 100):
			same = false
	check(same, "range draws are reproducible for the same seed")


func _floats() -> void:
	var rng := DeterministicRng.new(SEED_A)
	var valid := true
	for i in 200:
		var value := rng.next_float()
		if value < 0.0 or value >= 1.0:
			valid = false
			break
	check(valid, "floats stay in [0,1)")
	check(
		DeterministicRng.new(SEED_A).next_float() == DeterministicRng.new(SEED_A).next_float(),
		"floats are reproducible"
	)


func _shuffle() -> void:
	var source: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var first := DeterministicRng.new(SEED_A).shuffled_copy(source)
	var second := DeterministicRng.new(SEED_A).shuffled_copy(source)
	check_eq(first, second, "shuffle is deterministic for the same seed")
	check_eq(source, [1, 2, 3, 4, 5, 6, 7, 8], "shuffle does not mutate the input")
	check_eq(first.size(), source.size(), "shuffle preserves size")
	var sorted_copy: Array = first.duplicate()
	sorted_copy.sort()
	check_eq(sorted_copy, [1, 2, 3, 4, 5, 6, 7, 8], "shuffle output is a permutation")
	var different := DeterministicRng.new(SEED_A + 1).shuffled_copy(source)
	check(first != different, "different seed changes shuffle order")
	check_eq(DeterministicRng.new(1).shuffled_copy([]), [], "empty shuffle is safe")
	check_eq(DeterministicRng.new(1).shuffled_copy([9]), [9], "single-element shuffle is safe")


func _interface() -> void:
	var rng := DeterministicRng.new(1)
	check(rng is RandomSource, "DeterministicRng implements RandomSource")
	var source: RandomSource = rng
	check(source.next_int_range(0, 1) >= 0, "range helper works through the interface")
	check(source.next_float() >= 0.0, "float helper works through the interface")
