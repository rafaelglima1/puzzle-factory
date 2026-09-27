class_name SolutionReplay
extends RefCounted
## Independent replay validator for a command list against a [SolverDomain].
##
## [BfsSolver] uses this logic when verifying a solution, but it is also useful
## on its own to confirm that a persisted or hand-authored plan still reproduces
## a win.

## Replays [param commands] from [method SolverDomain.initial_state].
##
## Returns a JSON-safe dictionary:
## [code]{"ok": bool, "won": bool, "applied": int, "failed_at": int,
## "failure_command": Dictionary}[/code].
## [code]failed_at[/code] is the 0-based index of the first command that could
## not be applied, or -1 when everything applied. [code]ok[/code] is true only
## when every command applied and the final state is won.
static func replay(domain: SolverDomain, commands: Array) -> Dictionary:
	var outcome := {
		"ok": false,
		"won": false,
		"applied": 0,
		"failed_at": -1,
		"failure_command": {},
	}
	if domain == null:
		outcome["failed_at"] = 0
		return outcome

	var state: Variant = domain.initial_state()
	if state == null:
		outcome["failed_at"] = 0
		return outcome

	var applied := 0
	for command in commands:
		if typeof(command) != TYPE_DICTIONARY:
			outcome["failed_at"] = applied
			outcome["failure_command"] = {}
			return outcome
		var next_state: Variant = domain.apply_command(state, command)
		if next_state == null:
			outcome["failed_at"] = applied
			outcome["failure_command"] = command
			return outcome
		state = next_state
		applied += 1

	var won: bool = domain.is_won(state)
	outcome["applied"] = applied
	outcome["won"] = won
	outcome["ok"] = won
	return outcome
