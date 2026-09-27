extends SceneTree
## M5 solver CLI (headless).
##
## Usage:
##   godot --headless --path game --script res://tools/solve_level.gd -- <args>
##
## Arguments:
##   <level-id>            solve one official level by id
##   <path.json>          solve a level file by res:// or absolute path
##   --all                solve every official level
##   --json               machine-readable JSON output
##   --expect-unsolvable  invert the exit-code rule (0 when every target is
##                        UNSOLVABLE); always exits 0 for a correct verdict
##
## Exit codes:
##   0 = every requested level proven SOLVABLE (or UNSOLVABLE with
##       --expect-unsolvable)
##   1 = invalid input / level failed to load or validate
##   2 = UNSOLVABLE (without --expect-unsolvable)
##   3 = UNKNOWN (bounds reached) / tooling error
##
## Output (text):
##   level: <id>
##   status: SOLVABLE
##   depth: <n>
##   visited: <n>
##   expanded: <n>
##   dead_ends: <n>
##   branching_avg: <f>
##   runtime_ms: <n>
##   solution:
##     1. dispatch_entity <entityId>

const Domains := preload("res://integration/traffic/solver/traffic_solver_domain.gd")

const EXIT_OK := 0
const EXIT_INVALID := 1
const EXIT_UNSOLVABLE := 2
const EXIT_UNKNOWN := 3


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var json_output := args.has("--json")
	var expect_unsolvable := args.has("--expect-unsolvable")
	var solve_all := args.has("--all")

	var targets: Array = []
	for arg in args:
		if arg.begins_with("--"):
			continue
		targets.append(arg)

	if not solve_all and targets.is_empty():
		_printerr("no level given (pass a level id, a .json path, or --all)")
		quit(EXIT_INVALID)
		return

	var reports: Array = []
	var exit_code := EXIT_OK

	if solve_all:
		var count := TrafficLevelCatalogue.count()
		if count == 0:
			_printerr("official pack is empty or missing")
			quit(EXIT_INVALID)
			return
		for index in count:
			var report := _solve_index(index)
			reports.append(report)
			exit_code = _merge_exit(exit_code, report, expect_unsolvable)
	else:
		for target in targets:
			var report := _solve_target(String(target))
			reports.append(report)
			exit_code = _merge_exit(exit_code, report, expect_unsolvable)

	if json_output:
		print(JSON.stringify({"levels": reports}, "  "))
	else:
		for report in reports:
			_print_report(report)
	quit(exit_code)


func _solve_index(index: int) -> Dictionary:
	var level_id := TrafficLevelCatalogue.level_id(index)
	var load_result := TrafficLevelCatalogue.load_load_result(index)
	if not load_result.is_ok():
		return _failure_report(String(level_id), "invalid", ", ".join(load_result.errors))
	var definition := load_result.definition
	var validation := LevelValidator.validate(definition)
	if not validation.is_empty():
		return _failure_report(String(level_id), "invalid", ", ".join(validation))
	return _run_solver(String(definition.level_id), definition)


func _solve_target(target: String) -> Dictionary:
	var index := TrafficLevelCatalogue.index_of(StringName(target))
	if index >= 0:
		return _solve_index(index)
	var path := target
	if path.ends_with(".json") and FileAccess.file_exists(path):
		var load_result := LevelLoader.load_from_file(path)
		if not load_result.is_ok():
			return _failure_report(target, "invalid", ", ".join(load_result.errors))
		return _run_solver(String(load_result.definition.level_id), load_result.definition)
	return _failure_report(target, "unknown", "no official level id and no readable .json path")


func _run_solver(label: String, definition: LevelDefinition) -> Dictionary:
	var domain := Domains.for_definition(definition)
	var result := BfsSolver.new().solve(domain)
	var solution: Array = []
	for command in result.solution_commands:
		solution.append(command)
	return {
		"level": label,
		"status": result.status_name(),
		"depth": result.solution_depth,
		"visited": result.visited_states,
		"expanded": result.expanded_states,
		"dead_ends": result.dead_end_count,
		"branching_avg": result.branching_factor_avg,
		"runtime_ms": result.runtime_ms,
		"bounds_hit": result.bounds_hit,
		"solution": solution,
	}


func _failure_report(label: String, status: String, detail: String) -> Dictionary:
	return {
		"level": label,
		"status": status,
		"depth": 0,
		"visited": 0,
		"expanded": 0,
		"dead_ends": 0,
		"branching_avg": 0.0,
		"runtime_ms": 0,
		"bounds_hit": false,
		"solution": [],
		"error": detail,
	}


func _merge_exit(current: int, report: Dictionary, expect_unsolvable: bool) -> int:
	var status := String(report.get("status", "unknown"))
	if status == "invalid" or status == "unknown":
		return maxi(current, EXIT_INVALID)
	if status == "SOLVABLE":
		return current if expect_unsolvable else maxi(current, EXIT_OK)
	if status == "UNSOLVABLE":
		return EXIT_OK if expect_unsolvable else maxi(current, EXIT_UNSOLVABLE)
	if status == "UNKNOWN":
		return maxi(current, EXIT_UNKNOWN)
	return maxi(current, EXIT_INVALID)


func _print_report(report: Dictionary) -> void:
	print("level: %s" % report.get("level", ""))
	print("status: %s" % report.get("status", "unknown"))
	if report.has("error"):
		print("error: %s" % report["error"])
	print("depth: %d" % int(report.get("depth", 0)))
	print("visited: %d" % int(report.get("visited", 0)))
	print("expanded: %d" % int(report.get("expanded", 0)))
	print("dead_ends: %d" % int(report.get("dead_ends", 0)))
	print("branching_avg: %.2f" % float(report.get("branching_avg", 0.0)))
	print("runtime_ms: %d" % int(report.get("runtime_ms", 0)))
	var solution: Array = report.get("solution", [])
	if solution.is_empty():
		print("solution: (none)")
	else:
		print("solution:")
		var step := 1
		for command in solution:
			print("  %d. %s %s" % [step, command.get("type", "?"), command.get("entityId", "?")])
			step += 1


func _printerr(message: String) -> void:
	printerr("solve_level: %s" % message)
