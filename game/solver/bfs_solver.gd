class_name BfsSolver
extends RefCounted
## Textbook breadth-first search over logical states, via a [SolverDomain].
##
## Safety bounds:
## - [constant DEFAULT_MAX_VISITED] caps the number of distinct states so a
##   cyclic/infinite domain cannot exhaust memory.
## - [constant DEFAULT_MAX_DEPTH] caps the solution depth so a deep or endless
##   chain cannot run forever.
## Both are deterministic search-shape limits. [member SolverResult.runtime_ms]
## is measured for reporting only and is NEVER used as a correctness bound.
##
## Reconstruction uses a predecessor table (parent index + the command that
## produced each node) instead of copying a path array per node, keeping memory
## linear in the number of visited states.

const DEFAULT_MAX_VISITED := 200000
const DEFAULT_MAX_DEPTH := 64


## Runs BFS from [method SolverDomain.initial_state] to a winning state.
## Returns [constant SolverResult.Status.SOLVABLE] only after the reconstructed
## command list independently passes [method verify_solution].
func solve(domain: SolverDomain, max_visited: int = DEFAULT_MAX_VISITED, max_depth: int = DEFAULT_MAX_DEPTH) -> SolverResult:
	var started_ms := Time.get_ticks_msec()
	var result := SolverResult.new()

	if domain == null:
		result.status = SolverResult.Status.UNKNOWN
		result.metrics["error"] = "null_domain"
		result.runtime_ms = Time.get_ticks_msec() - started_ms
		return result

	var initial: Variant = domain.initial_state()
	if initial == null:
		result.status = SolverResult.Status.UNKNOWN
		result.metrics["error"] = "null_initial_state"
		result.runtime_ms = Time.get_ticks_msec() - started_ms
		return result

	var visited: Dictionary = {}
	var parents: Array[int] = [-1]
	var producing: Array = [{}]
	var depths: Array[int] = [0]
	var states: Array = [initial]
	var frontier: Array[int] = [0]

	var initial_key: String = domain.state_key(initial)
	visited[initial_key] = 0

	if domain.is_terminal(initial):
		result.visited_states = 1
		if domain.is_won(initial):
			result.status = SolverResult.Status.SOLVABLE
			result.solution_commands = []
			result.solution_depth = 0
		else:
			result.status = SolverResult.Status.UNSOLVABLE
		result.runtime_ms = Time.get_ticks_msec() - started_ms
		return result

	var head := 0
	var expanded := 0
	var dead_ends := 0
	var accepted_edges := 0
	var hit_bounds := false
	var won_index := -1

	while head < frontier.size():
		var node_index: int = frontier[head]
		head += 1
		var state: Variant = states[node_index]
		var node_depth: int = depths[node_index]
		expanded += 1

		var candidates: Array = domain.candidate_commands(state)
		if candidates.is_empty():
			dead_ends += 1
			continue

		for command in candidates:
			var next_state: Variant = domain.apply_command(state, command)
			if next_state == null:
				continue
			accepted_edges += 1

			var next_key: String = domain.state_key(next_state)
			if visited.has(next_key):
				continue

			var next_depth: int = node_depth + 1
			if next_depth > max_depth:
				hit_bounds = true
				continue

			if domain.is_terminal(next_state):
				if not domain.is_won(next_state):
					dead_ends += 1
					continue
				visited[next_key] = states.size()
				parents.append(node_index)
				producing.append(command)
				depths.append(next_depth)
				states.append(next_state)
				won_index = states.size() - 1
				break

			if visited.size() >= max_visited:
				hit_bounds = true
				break

			visited[next_key] = states.size()
			parents.append(node_index)
			producing.append(command)
			depths.append(next_depth)
			states.append(next_state)
			frontier.append(states.size() - 1)

		if won_index >= 0 or hit_bounds:
			break

	result.visited_states = visited.size()
	result.expanded_states = expanded
	result.dead_end_count = dead_ends
	result.branching_factor_avg = (float(accepted_edges) / float(expanded)) if expanded > 0 else 0.0

	if won_index >= 0:
		var commands := _reconstruct(parents, producing, won_index)
		result.solution_commands = commands
		result.solution_depth = commands.size()
		if verify_solution(domain, commands):
			result.status = SolverResult.Status.SOLVABLE
		else:
			result.status = SolverResult.Status.UNKNOWN
			result.metrics["verification_failed"] = true
		result.runtime_ms = Time.get_ticks_msec() - started_ms
		return result

	if hit_bounds:
		result.status = SolverResult.Status.UNKNOWN
		result.bounds_hit = true
	else:
		result.status = SolverResult.Status.UNSOLVABLE
	result.runtime_ms = Time.get_ticks_msec() - started_ms
	return result


## Replays [param commands] from a fresh initial state. Every command must apply
## to a non-null next state and the final state must be won. Used both by the
## solver (defense in depth before reporting SOLVABLE) and by callers.
func verify_solution(domain: SolverDomain, commands: Array) -> bool:
	if domain == null:
		return false
	var state: Variant = domain.initial_state()
	if state == null:
		return false
	for command in commands:
		if typeof(command) != TYPE_DICTIONARY:
			return false
		state = domain.apply_command(state, command)
		if state == null:
			return false
	return domain.is_won(state)


## Walks the predecessor table back from [param node_index] and returns the
## command descriptors in forward order.
func _reconstruct(parents: Array[int], producing: Array, node_index: int) -> Array:
	var commands: Array = []
	var index := node_index
	while index >= 0 and parents[index] != -1:
		commands.append(producing[index])
		index = parents[index]
	commands.reverse()
	return commands
