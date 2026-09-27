class_name SolverDomain
extends RefCounted
## Abstract adapter contract used by [BfsSolver].
##
## The solver is product-agnostic: it never knows what a state contains. A
## caller supplies a concrete [SolverDomain] that wraps the real simulation and
## translates it into canonical snapshots and serializable command descriptors.
## No method on this class may depend on the scene tree.
##
## State handles are opaque to the solver. They are [code]Variant[/code] so an
## adapter can return whatever representation is cheapest to clone and apply
## (a deep copy of the simulation, an immutable snapshot, a packed array, ...).
##
## Contract:
## - [method initial_state] returns a fresh, mutable handle positioned at the
##   puzzle start. Repeated calls must produce equal starting states.
## - [method state_snapshot] returns the canonical, primitive-only dictionary
##   for hashing. Two logically equal states must serialize identically.
## - [method state_key] defaults to [method SolverStateHasher.hash_snapshot]
##   over [method state_snapshot]; adapters normally inherit it.
## - [method is_terminal] / [method is_won] / [method is_lost] classify a
##   handle. Terminal means no further decision is meaningful.
## - [method candidate_commands] returns command DESCRIPTORS in a deterministic
##   order (stable ordering is required for reproducibility).
## - [method apply_command] returns a NEW handle after applying a descriptor, or
##   [code]null[/code] when the command is rejected, blocked or a no-op. It must
##   never mutate the input handle.
## - [method command_from_descriptor] builds the concrete command object the
##   real simulation expects from a descriptor.
##
## The base implementations are safe defaults that make the class runnable but
## report their abstract use with [method @GlobalScope.push_error].


## Fresh mutable starting handle. Adapters must override this.
func initial_state() -> Variant:
	push_error("SolverDomain.initial_state() is abstract and must be overridden")
	return null


## Canonical primitive dictionary describing [param state]. Adapters must
## override this.
func state_snapshot(_state: Variant) -> Dictionary:
	push_error("SolverDomain.state_snapshot() is abstract and must be overridden")
	return {}


## Stable hashing identity of [param state]. The default delegates to
## [method SolverStateHasher.hash_snapshot] over the canonical snapshot.
func state_key(state: Variant) -> String:
	return SolverStateHasher.hash_snapshot(state_snapshot(state))


## True when no further decision can change the outcome. The default is the
## union of [method is_won] and [method is_lost].
func is_terminal(state: Variant) -> bool:
	return is_won(state) or is_lost(state)


## True when the state satisfies the goal. Adapters must override this.
func is_won(_state: Variant) -> bool:
	push_error("SolverDomain.is_won() is abstract and must be overridden")
	return false


## True when the state is a losing/trapped end state. Adapters must override
## this; the default treats every non-winning state as non-lost.
func is_lost(_state: Variant) -> bool:
	return false


## Deterministic list of command descriptors available in [param state]. The
## default offers no choices.
func candidate_commands(_state: Variant) -> Array:
	return []


## Returns a NEW handle after applying [param command] to [param state], or
## [code]null[/code] when the command is rejected/blocked/no-op. Must not
## mutate [param state]. The default rejects everything.
func apply_command(_state: Variant, _command: Dictionary) -> Variant:
	return null


## Builds the concrete command object for [param descriptor]. The default
## returns the descriptor unchanged.
func command_from_descriptor(descriptor: Dictionary) -> Variant:
	return descriptor
