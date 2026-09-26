class_name DeterministicRng
extends RandomSource
## Deterministic, engine-independent pseudo-random source (blueprint §11).
##
## Algorithm: ANSI-C style linear congruential generator
## [code]state = (1103515245 * state + 12345) mod 2^31[/code].
##
## Why this algorithm:
## - Pure 64-bit integer math with a bounded product (< 2^62), so GDScript
##   integer overflow can never occur and results are identical on every
##   platform and engine version (replays stay valid across engine upgrades).
## - Full state is a single integer: trivial to serialize, restore and hash.
##
## Quality note: adequate for puzzle shuffling and runtime variation. If the
## M6/M8 solver/generator require higher-quality distribution, a new
## implementation of [RandomSource] must be added through an ADR, never by
## silently changing this algorithm (existing saved RNG states must keep
## meaning).

const MODULUS := 2147483648
const MULTIPLIER := 1103515245
const INCREMENT := 12345
const STATE_KEY := "state"


var _state: int = 0


func _init(seed_value: int = 0) -> void:
	set_seed(seed_value)


## Normalizes any integer into the valid state range [code][0, MODULUS)[/code].
static func normalize_seed(value: int) -> int:
	var normalized := value % MODULUS
	if normalized < 0:
		normalized += MODULUS
	return normalized


func set_seed(seed_value: int) -> void:
	_state = normalize_seed(seed_value)


func get_seed_state() -> int:
	return _state


func next_int() -> int:
	_state = (MULTIPLIER * _state + INCREMENT) % MODULUS
	return _state


func next_int_range(min_value: int, max_value: int) -> int:
	if max_value < min_value:
		return min_value
	var span := max_value - min_value + 1
	if span > MODULUS:
		return min_value
	# Rejection sampling removes modulo bias while staying fully deterministic.
	var limit := MODULUS - (MODULUS % span)
	var value := next_int()
	var guard := 0
	while value >= limit and guard < 1000:
		value = next_int()
		guard += 1
	if value >= limit:
		value %= span
	return min_value + value % span


func next_float() -> float:
	return float(next_int()) / float(MODULUS)


func get_state() -> Dictionary:
	return {STATE_KEY: _state}


func set_state(state: Dictionary) -> void:
	_state = normalize_seed(int(state.get(STATE_KEY, 0)))
