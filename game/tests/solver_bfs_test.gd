extends "res://tests/framework/test_base.gd"
## BfsSolver and SolutionReplay over small, product-free fake domains.
##
## The fake domains below are toy graphs/switching puzzles: state is a small
## integer, commands are serializable descriptors. They exercise the generic
## solver without depending on any product adapter.

## Toy graph with a known shortest solution (0 -> 2 -> 4).
class GraphDomain:
	extends SolverDomain

	const EDGES := {
		0: [1, 2],
		1: [3],
		2: [4],
		3: [4],
		4: [],
	}
	const GOAL := 4

	func initial_state() -> Variant:
		return 0

	func state_snapshot(state: Variant) -> Dictionary:
		return {"node": int(state)}

	func is_won(state: Variant) -> bool:
		return int(state) == GOAL

	func is_lost(_state: Variant) -> bool:
		return false

	func candidate_commands(state: Variant) -> Array:
		var node := int(state)
		var targets: Array = EDGES.get(node, [])
		var commands: Array = []
		for target in targets:
			commands.append({"type": "go", "to": int(target)})
		return commands

	func apply_command(state: Variant, command: Dictionary) -> Variant:
		var node := int(state)
		var target := int(command.get("to", -1))
		var targets: Array = EDGES.get(node, [])
		if not targets.has(target):
			return null
		return target


## A graph that never reaches the goal; every leaf exhausts without winning.
class DeadEndDomain:
	extends SolverDomain

	func initial_state() -> Variant:
		return 0

	func state_snapshot(state: Variant) -> Dictionary:
		return {"node": int(state)}

	func is_won(_state: Variant) -> bool:
		return false

	func is_lost(_state: Variant) -> bool:
		return false

	func candidate_commands(state: Variant) -> Array:
		var node := int(state)
		if node >= 2:
			return []
		return [{"type": "step", "to": node + 1}]

	func apply_command(state: Variant, command: Dictionary) -> Variant:
		var node := int(state)
		var target := int(command.get("to", -1))
		if target != node + 1 or target > 2:
			return null
		return target


## Linear chain with a distant goal; never terminating within a depth bound.
class ChainDomain:
	extends SolverDomain

	const GOAL := 6

	func initial_state() -> Variant:
		return 0

	func state_snapshot(state: Variant) -> Dictionary:
		return {"node": int(state)}

	func is_won(state: Variant) -> bool:
		return int(state) == GOAL

	func is_lost(_state: Variant) -> bool:
		return false

	func candidate_commands(state: Variant) -> Array:
		var node := int(state)
		if node >= GOAL:
			return []
		return [{"type": "inc", "to": node + 1}]

	func apply_command(state: Variant, command: Dictionary) -> Variant:
		var node := int(state)
		var target := int(command.get("to", -1))
		if target != node + 1 or target > GOAL:
			return null
		return target


## Endless incrementing counter with no goal.
class CounterDomain:
	extends SolverDomain

	func initial_state() -> Variant:
		return 0

	func state_snapshot(state: Variant) -> Dictionary:
		return {"node": int(state)}

	func is_won(_state: Variant) -> bool:
		return false

	func is_lost(_state: Variant) -> bool:
		return false

	func candidate_commands(state: Variant) -> Array:
		return [{"type": "inc", "to": int(state) + 1}]

	func apply_command(state: Variant, command: Dictionary) -> Variant:
		var node := int(state)
		var target := int(command.get("to", -1))
		if target != node + 1:
			return null
		return target


## Already solved at the initial state.
class InstantWinDomain:
	extends SolverDomain

	func initial_state() -> Variant:
		return 7

	func state_snapshot(state: Variant) -> Dictionary:
		return {"node": int(state)}

	func is_won(_state: Variant) -> bool:
		return true

	func candidate_commands(_state: Variant) -> Array:
		return []

	func apply_command(_state: Variant, _command: Dictionary) -> Variant:
		return null


func run() -> void:
	_solvable_graph()
	_unsolvable_dead_end()
	_bounds_visited()
	_bounds_depth()
	_initial_win_depth_zero()
	_deterministic_repeat()
	_state_key_routes_through_hasher()
	_replay_reports_failure()


func _solvable_graph() -> void:
	var domain := GraphDomain.new()
	var result := BfsSolver.new().solve(domain, 1000, 32)

	check_eq(result.status, SolverResult.Status.SOLVABLE, "graph is solvable")
	check(result.is_solvable(), "is_solvable agrees with status")
	check_eq(result.status_name(), "SOLVABLE", "status name")
	check_eq(result.solution_depth, 2, "shortest depth is 2")
	check_eq(result.solution_commands.size(), result.solution_depth, "solution size equals depth")
	check_eq(result.visited_states, 5, "five distinct states visited")
	check_eq(result.expanded_states, 3, "three nodes expanded")
	check_eq(result.dead_end_count, 0, "no dead ends in the graph")
	check(not result.bounds_hit, "bounds not hit")
	check(result.runtime_ms >= 0, "runtime is measured")
	check(BfsSolver.new().verify_solution(domain, result.solution_commands), "solver verification passes")

	var replay := SolutionReplay.replay(domain, result.solution_commands)
	check(replay["ok"], "replay reports ok")
	check(replay["won"], "replay reports win")
	check_eq(int(replay["applied"]), 2, "replay applied both commands")
	check_eq(int(replay["failed_at"]), -1, "replay reports no failure")


func _unsolvable_dead_end() -> void:
	var result := BfsSolver.new().solve(DeadEndDomain.new(), 1000, 32)
	check_eq(result.status, SolverResult.Status.UNSOLVABLE, "exhausted graph is unsolvable")
	check_eq(result.status_name(), "UNSOLVABLE", "status name")
	check_eq(result.solution_commands.size(), 0, "no solution commands")
	check(not result.bounds_hit, "unsolvable without hitting bounds")
	check_eq(result.dead_end_count, 1, "one empty-candidate dead end")


func _bounds_visited() -> void:
	var result := BfsSolver.new().solve(CounterDomain.new(), 5, 64)
	check_eq(result.status, SolverResult.Status.UNKNOWN, "counter is unknown under visited bound")
	check(result.bounds_hit, "visited bound recorded")
	check_eq(result.visited_states, 5, "visited count stops at the bound")


func _bounds_depth() -> void:
	var result := BfsSolver.new().solve(ChainDomain.new(), 1000, 3)
	check_eq(result.status, SolverResult.Status.UNKNOWN, "chain is unknown under depth bound")
	check(result.bounds_hit, "depth bound recorded")


func _initial_win_depth_zero() -> void:
	var domain := InstantWinDomain.new()
	var result := BfsSolver.new().solve(domain, 100, 8)
	check_eq(result.status, SolverResult.Status.SOLVABLE, "already-won state is solvable")
	check_eq(result.solution_depth, 0, "depth zero solution")
	check_eq(result.solution_commands.size(), 0, "no commands for depth zero")
	check(BfsSolver.new().verify_solution(domain, result.solution_commands), "empty solution verifies")


func _deterministic_repeat() -> void:
	var solver := BfsSolver.new()
	var first := solver.solve(GraphDomain.new(), 1000, 32)
	var second := solver.solve(GraphDomain.new(), 1000, 32)

	check_eq(first.status, second.status, "deterministic status")
	check_eq(first.solution_depth, second.solution_depth, "deterministic depth")
	check(Serialization.values_equal(first.solution_commands, second.solution_commands), "deterministic commands")
	check_eq(first.visited_states, second.visited_states, "deterministic visited count")
	check_eq(first.expanded_states, second.expanded_states, "deterministic expanded count")
	check_eq(first.dead_end_count, second.dead_end_count, "deterministic dead end count")


func _state_key_routes_through_hasher() -> void:
	var domain := GraphDomain.new()
	check_eq(
		domain.state_key(0),
		SolverStateHasher.hash_snapshot(domain.state_snapshot(0)),
		"fake state_key routes through SolverStateHasher.hash_snapshot"
	)
	check(domain.state_key(0) != domain.state_key(1), "different nodes hash differently")


func _replay_reports_failure() -> void:
	var replay := SolutionReplay.replay(GraphDomain.new(), [{"type": "go", "to": 3}])
	check(not replay["ok"], "illegal first command is not ok")
	check_eq(int(replay["applied"]), 0, "no command applied on failure")
	check_eq(int(replay["failed_at"]), 0, "failure index recorded")
	check(not (replay["failure_command"] as Dictionary).is_empty(), "failure command captured")
