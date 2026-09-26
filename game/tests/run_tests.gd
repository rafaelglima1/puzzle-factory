extends SceneTree
## Headless test runner for Puzzle Factory.
##
## Usage:
##   godot --headless --path game --script res://tests/run_tests.gd
##
## Discovers res://tests/*_test.gd, runs each suite, prints a report and
## exits with code 0 (all passed) or 1 (failures).

const TEST_DIR := "res://tests"
const TEST_SUFFIX := "_test.gd"


func _init() -> void:
	quit(_run_all())


func _run_all() -> int:
	var started_ms := Time.get_ticks_msec()
	print("== Puzzle Factory test runner ==")
	print("engine: %s" % Engine.get_version_info().string)

	var files := _collect_tests()
	if files.is_empty():
		print("ERROR: no *%s files found in %s" % [TEST_SUFFIX, TEST_DIR])
		return 1

	var total_checks := 0
	var failed_tests := 0
	for file in files:
		var result := _run_test_file(TEST_DIR + "/" + file, file)
		total_checks += result["checks"]
		if not result["ok"]:
			failed_tests += 1

	var elapsed_ms := Time.get_ticks_msec() - started_ms
	print("== result: %d test files, %d failed, %d checks, %d ms ==" % [
		files.size(), failed_tests, total_checks, elapsed_ms
	])
	return 0 if failed_tests == 0 else 1


func _collect_tests() -> Array:
	var tests: Array = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.ends_with(TEST_SUFFIX):
			tests.append(file)
	tests.sort()
	return tests


func _run_test_file(path: String, label: String) -> Dictionary:
	var script: Variant = load(path)
	if script == null or not (script is GDScript) or not script.can_instantiate():
		print("[FAIL] %s (script failed to load)" % label)
		return {"ok": false, "checks": 0}

	var test: Variant = script.new()
	if test == null:
		print("[FAIL] %s (cannot instantiate)" % label)
		return {"ok": false, "checks": 0}

	test.test_name = label
	test.run()

	if test.failures.is_empty():
		print("[PASS] %s (%d checks)" % [label, test.checks_run])
		return {"ok": true, "checks": test.checks_run}

	print("[FAIL] %s (%d/%d checks failed)" % [label, test.failures.size(), test.checks_run])
	for failure: String in test.failures:
		print("       - %s" % failure)
	return {"ok": false, "checks": test.checks_run}
