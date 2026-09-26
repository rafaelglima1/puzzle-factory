class_name CommandContext
extends RefCounted
## Execution context for a single [GameCommand].
##
## Responsibilities:
## - expose the mutable [member GameState] (commands mutate it only after
##   full validation);
## - collect emitted [DomainEvent]s in deterministic order and assign
##   their sequence index;
## - provide a deterministic RNG positioned at the state's rng_state.
##
## Commands MUST NOT consume randomness before their validation has passed,
## otherwise a rejected command could still advance RNG state. Rejections are
## also enforced by [Simulation], which only commits RNG state on success.

var state: GameState
var events: Array[DomainEvent] = []

var _rng: RandomSource = null


func _init(p_state: GameState) -> void:
	state = p_state


## Appends an event and stamps its deterministic sequence index.
func emit_event(event: DomainEvent) -> DomainEvent:
	event.sequence = events.size()
	events.append(event)
	return event


## Returns a deterministic RNG positioned at the current state rng_state.
func get_rng() -> RandomSource:
	if _rng == null:
		_rng = state.create_rng()
	return _rng


func used_rng() -> bool:
	return _rng != null


## Writes consumed RNG state back into the game state.
func commit() -> void:
	if _rng == null:
		return
	var rng_state: Variant = _rng.get_state().get(DeterministicRng.STATE_KEY, null)
	if rng_state != null:
		state.rng_state = int(rng_state)
