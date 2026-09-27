class_name SolverResult
extends RefCounted
## Outcome of one generic solver run.
##
## The result carries a stable status, the reconstructed command list (as
## serializable descriptor dictionaries only, never live object references),
## search metrics and a bounds flag. [method to_dictionary] is JSON-safe so a
## result can be logged or attached to a report without extra conversion.

enum Status { SOLVABLE, UNSOLVABLE, UNKNOWN }

const _STATUS_NAMES := {
	Status.SOLVABLE: "SOLVABLE",
	Status.UNSOLVABLE: "UNSOLVABLE",
	Status.UNKNOWN: "UNKNOWN",
}

var status: int = Status.UNKNOWN
## Serializable command descriptors from the initial state to the goal.
var solution_commands: Array = []
var solution_depth: int = 0
var visited_states: int = 0
var expanded_states: int = 0
var dead_end_count: int = 0
var branching_factor_avg: float = 0.0
var runtime_ms: int = 0
## Free-form extra metrics (implementation detail; JSON-safe primitives only).
var metrics: Dictionary = {}
## True when a search bound was reached before a proof was produced.
var bounds_hit: bool = false


func is_solvable() -> bool:
	return status == Status.SOLVABLE


func status_name() -> String:
	return _STATUS_NAMES.get(status, "UNKNOWN")


## JSON-safe representation. Commands are already primitive dictionaries.
func to_dictionary() -> Dictionary:
	return {
		"status": status,
		"status_name": status_name(),
		"solution_commands": Serialization.canonicalize(solution_commands),
		"solution_depth": solution_depth,
		"visited_states": visited_states,
		"expanded_states": expanded_states,
		"dead_end_count": dead_end_count,
		"branching_factor_avg": branching_factor_avg,
		"runtime_ms": runtime_ms,
		"metrics": Serialization.canonicalize(metrics),
		"bounds_hit": bounds_hit,
	}
