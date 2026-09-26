extends "res://tests/framework/test_base.gd"
## Determinism test: identical seeds must produce identical sequences, and
## the fixture must be stable across machines/runs (golden vector).

const Fixture := preload("res://tests/fixtures/deterministic_fixture.gd")

const SEED_A := 987234
const GOLDEN_FIRST := 724829683
const GOLDEN_SECOND := 199803568


func run() -> void:
	var a: Variant = Fixture.new(SEED_A)
	var b: Variant = Fixture.new(SEED_A)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 32:
		seq_a.append(a.next_value())
		seq_b.append(b.next_value())
	check_eq(seq_a, seq_b, "same seed reproduces identical sequence")

	check_eq(seq_a[0], GOLDEN_FIRST, "golden first value (cross-machine stability)")
	check_eq(seq_a[1], GOLDEN_SECOND, "golden second value (cross-machine stability)")

	var c: Variant = Fixture.new(SEED_A + 1)
	var diverged := false
	for i in 32:
		if c.next_value() != seq_a[i]:
			diverged = true
			break
	check(diverged, "different seed produces different sequence")

	var negative: Variant = Fixture.new(-1)
	check(negative.next_value() >= 0, "negative seed normalized into range")
