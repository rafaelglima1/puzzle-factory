extends RefCounted
## Deterministic seeded generator fixture for the M0 test harness.
##
## Proves that the harness can reproduce identical value sequences from a
## seed on any machine. This is test scaffolding only: gameplay randomness
## (seeded RNG, rng_state) belongs to milestone M1 and lives in game/core.

const MODULUS := 2147483648
const MULTIPLIER := 1103515245
const INCREMENT := 12345

var _state: int


func _init(seed_value: int) -> void:
	_state = seed_value % MODULUS
	if _state < 0:
		_state += MODULUS


func next_value() -> int:
	_state = (MULTIPLIER * _state + INCREMENT) % MODULUS
	return _state
