extends "res://tests/framework/test_base.gd"
## Self-test of the M0 test framework: assertions must record correctly.


func run() -> void:
	var probe: Variant = load("res://tests/framework/test_base.gd").new()
	check(probe != null, "test_base instantiable")

	probe.check(true, "passing check")
	check_eq(probe.failures.size(), 0, "passing check records no failure")
	check_eq(probe.checks_run, 1, "passing check counted")

	probe.check(false, "failing check")
	check_eq(probe.failures.size(), 1, "failing check recorded")
	check_eq(probe.failures[0], "failing check", "failure message preserved")

	probe.check_eq(7, 7, "equal values")
	probe.check_eq("a", "b", "mismatched values")
	check_eq(probe.checks_run, 4, "checks counted cumulatively")
	check_eq(probe.failures.size(), 2, "mismatch recorded with detail")
	check(probe.failures[1].contains("expected=b"), "mismatch failure includes expected value")

	# A test subclass that forgets run() must fail loudly, not silently pass.
	var no_run: Variant = load("res://tests/framework/test_base.gd").new()
	no_run.run()
	check_eq(no_run.failures.size(), 1, "base run() reports missing implementation")
