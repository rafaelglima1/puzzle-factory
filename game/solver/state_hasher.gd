class_name SolverStateHasher
extends RefCounted
## Deterministic logical-state identity for the generic solver.
##
## A state's identity is derived only from the data that can influence future
## simulation outcomes. [GameState] already exposes such a representation via
## [method GameState.to_dictionary]: it is canonical (sorted ids, primitive-only
## values) and contains every logical field the rules can read
## (board/entities/items/queues/destinations/paths/staging/objectives and the
## scalar fields rng_state/move_index/completion/fail_reason/...).
##
## Deliberate exclusions:
## - There are no visual, audible or device-feedback fields in [GameState]
##   today; [method GameState.to_dictionary] cannot emit any. If such fields are
##   ever added they must NOT be added to the canonical form, because they can
##   never change the outcome of a future command.
## - No walls of the simulation are excluded: every field [method
##   GameState.to_dictionary] emits today is kept, so two states hash equal iff
##   they are logically equal under the current schema.
##
## Digests are cryptographic (SHA-256 over canonical JSON), never
## [method @GlobalScope.hash]-based, so they are stable across processes,
## platforms and engine runs.

const _HEX_DIGEST_LENGTH := 64


## Canonical dictionary used for hashing. Returns an empty dictionary for a
## null state so callers can hash defensively without branching.
static func canonical_state(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var canonical: Dictionary = Serialization.canonicalize(state.to_dictionary())
	return canonical


## Stable digest of a real [GameState].
static func hash_state(state: GameState) -> String:
	return hash_snapshot(canonical_state(state))


## Stable digest of an already canonical snapshot dictionary.
static func hash_snapshot(snapshot: Dictionary) -> String:
	return Serialization.to_json(snapshot).sha256_text()


## Logical equality through the canonical form.
static func states_equal(a: GameState, b: GameState) -> bool:
	if a == null or b == null:
		return a == b
	return Serialization.values_equal(canonical_state(a), canonical_state(b))


## True when [param digest] has the shape produced by [method hash_snapshot].
static func is_valid_digest(digest: String) -> bool:
	if digest.length() != _HEX_DIGEST_LENGTH:
		return false
	for index in digest.length():
		var code := digest.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 102
		if not is_digit and not is_lower:
			return false
	return true
