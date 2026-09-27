extends "res://tests/framework/test_base.gd"
## M5 solver integration: the generic BFS solver proves every official Traffic
## level solvable, its solution replays to WON, and an impossible-but-valid
## fixture is proven UNSOLVABLE. Solver (generic) is driven only through the
## Traffic adapter; nothing here re-implements gameplay rules.

const Fixture := preload("res://tests/support/unsolvable_level_fixture.gd")


func run() -> void:
	_test_official_levels_solvable()
	_test_solution_replays_to_won()
	_test_repeated_solve_is_deterministic()
	_test_unsolvable_fixture()
	_test_bounds_yield_unknown()


func _solve(definition: LevelDefinition) -> SolverResult:
	return BfsSolver.new().solve(TrafficSolverDomain.for_definition(definition))


func _official_definition(level_id: StringName) -> LevelDefinition:
	var index := TrafficLevelCatalogue.index_of(level_id)
	check(index >= 0, "official level '%s' is in the pack" % level_id)
	if index < 0:
		return null
	return TrafficLevelCatalogue.load_definition(index)


func _test_official_levels_solvable() -> void:
	check_eq(TrafficLevelCatalogue.count(), 10, "official pack exposes ten levels")
	for index in TrafficLevelCatalogue.count():
		var level_id := TrafficLevelCatalogue.level_id(index)
		var definition := TrafficLevelCatalogue.load_definition(index)
		check(definition != null, "official level %d loads" % index)
		if definition == null:
			continue
		var result := _solve(definition)
		check_eq(result.status_name(), "SOLVABLE", "official level %s is SOLVABLE" % level_id)
		check(result.solution_depth >= 1, "official level %s has a non-empty solution" % level_id)
		check_eq(result.solution_commands.size(), result.solution_depth, "%s solution size == depth" % level_id)
		check(not result.bounds_hit, "official level %s solved within bounds" % level_id)
		check(result.visited_states > 0, "official level %s visited states recorded" % level_id)


func _test_solution_replays_to_won() -> void:
	for index in TrafficLevelCatalogue.count():
		var level_id := TrafficLevelCatalogue.level_id(index)
		var definition := TrafficLevelCatalogue.load_definition(index)
		if definition == null:
			continue
		var domain := TrafficSolverDomain.for_definition(definition)
		var result := BfsSolver.new().solve(domain)
		if not result.is_solvable():
			check(false, "%s solver must be SOLVABLE to replay" % level_id)
			continue
		var replay := SolutionReplay.replay(domain, result.solution_commands)
		check(replay["ok"], "%s solver solution replays (all commands accepted)" % level_id)
		check(replay["won"], "%s solver solution reaches WON" % level_id)
		check_eq(replay["applied"], result.solution_depth, "%s replay applied every command" % level_id)


func _test_repeated_solve_is_deterministic() -> void:
	for index in TrafficLevelCatalogue.count():
		var level_id := TrafficLevelCatalogue.level_id(index)
		var definition := TrafficLevelCatalogue.load_definition(index)
		if definition == null:
			continue
		var first := _solve(definition)
		var second := _solve(definition)
		check_eq(first.status_name(), second.status_name(), "%s status is deterministic" % level_id)
		check_eq(first.solution_depth, second.solution_depth, "%s depth is deterministic" % level_id)
		check_eq(first.visited_states, second.visited_states, "%s visited is deterministic" % level_id)
		check_eq(first.expanded_states, second.expanded_states, "%s expanded is deterministic" % level_id)
		check_eq(
			Serialization.to_json(first.solution_commands),
			Serialization.to_json(second.solution_commands),
			"%s solution commands are deterministic" % level_id
		)


func _test_unsolvable_fixture() -> void:
	# The fixture is a STATICALLY VALID level that cannot be won: two entities
	# sharing one destination whose queue holds a single matching item, so the
	# second entity is always staged and the staging area is too small.
	var definition := Fixture.build_definition()
	var validation := LevelValidator.validate(definition)
	check_eq(validation.size(), 0, "unsolvable fixture is statically VALID (%s)" % ", ".join(validation))
	check(TrafficLevelDefinitionAdapter.build_simulation(definition) != null, "unsolvable fixture builds a real simulation")
	var result := _solve(definition)
	check_eq(result.status_name(), "UNSOLVABLE", "valid-but-impossible fixture is UNSOLVABLE")
	check(result.solution_commands.is_empty(), "unsolvable fixture returns no commands")


func _test_bounds_yield_unknown() -> void:
	# Tiny bounds must not turn a solvable level into a false SOLVABLE; a depth
	# bound below the real solution depth yields UNKNOWN, never a wrong answer.
	var definition := _official_definition(&"traffic_m3_l10_rush_hour")
	if definition == null:
		return
	var bounded := BfsSolver.new().solve(TrafficSolverDomain.for_definition(definition), 200000, 1)
	check_eq(bounded.status_name(), "UNKNOWN", "depth bound below the solution yields UNKNOWN")
	check(bounded.bounds_hit, "bounded solve reports bounds_hit")
