extends RefCounted
## Base class for Puzzle Factory automated tests (M0 test foundation).
##
## Tests are plain GDScript classes extending this base with a `run()`
## implementation. They are executed headlessly by res://tests/run_tests.gd.

var test_name: String = ""
var checks_run: int = 0
var failures: Array[String] = []


func run() -> void:
	failures.append("run() not implemented by test")


func check(condition: bool, message: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	checks_run += 1
	if actual != expected:
		failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])
