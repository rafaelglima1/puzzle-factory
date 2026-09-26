extends "res://tests/framework/test_base.gd"
## M3 scripted solvability: every one of the ten manual levels is completable
## with a known deterministic command sequence (solver is M6; M3 proves
## completability explicitly here, never in production data).
##
## Winning sequences are intentionally NOT stored in the catalogue.

const SOLUTIONS := {
	"traffic_m3_l01_first_roll": [&"v1"],
	"traffic_m3_l02_two_lanes": [&"v1", &"v2"],
	"traffic_m3_l03_right_order": [&"v1", &"v2"],
	"traffic_m3_l04_double_pickup": [&"v1", &"v2"],
	"traffic_m3_l05_tight_parking": [&"v1", &"v2", &"v3"],
	"traffic_m3_l06_the_blocker": [&"v1", &"v2"],
	"traffic_m3_l07_three_colors": [&"v1", &"v2", &"v3"],
	"traffic_m3_l08_no_room_to_wait": [&"v1", &"v2", &"v3"],
	"traffic_m3_l09_multi_step": [&"v_block", &"v_b", &"v_c"],
	"traffic_m3_l10_rush_hour": [&"v_block", &"v_b", &"v_c", &"v_d"],
}


func run() -> void:
	_all_levels_have_exactly_one_solution_script()
	_every_level_is_solvable()
	_solutions_are_deterministic()
	_wrong_first_moves_are_safe_or_losing()


func _build(level_id: StringName) -> Simulation:
	var index := M3LevelCatalogue.index_of(level_id)
	if index < 0:
		return null
	return TrafficGameFactory.build(M3LevelCatalogue.definition(index))


func _all_levels_have_exactly_one_solution_script() -> void:
	check_eq(SOLUTIONS.size(), M3LevelCatalogue.count(), "every catalogue level has a scripted solution")
	for level_id in M3LevelCatalogue.level_ids():
		check(SOLUTIONS.has(String(level_id)), "solution script exists for %s" % level_id)


func _every_level_is_solvable() -> void:
	var solved := 0
	for level_id in M3LevelCatalogue.level_ids():
		var sequence: Array = SOLUTIONS[String(level_id)]
		var simulation := _build(level_id)
		check(simulation != null, "%s builds" % level_id)
		if simulation == null:
			continue
		var all_commands_succeeded := true
		for entity_id in sequence:
			var result := simulation.execute(DispatchEntityCommand.new(entity_id))
			if not result.is_success():
				all_commands_succeeded = false
				check(false, "%s: command '%s' failed (%s/%s)" % [level_id, entity_id, result.status_name(), result.code])
				break
		if not all_commands_succeeded:
			continue
		var state := simulation.get_state()
		check(state.is_won(), "%s: final state is WON" % level_id)
		check(not state.is_lost(), "%s: final state is not lost" % level_id)
		check_eq(state.fail_reason, &"", "%s: no failure reason" % level_id)
		check(state.items.is_empty(), "%s: every passenger was processed" % level_id)
		check(state.staging.occupied_count() == 0, "%s: nothing was staged" % level_id)
		check_eq(state.move_index, sequence.size(), "%s: move count matches the solution length" % level_id)
		for entity_id in state.entity_ids():
			check_eq(
				state.get_entity(entity_id).state,
				EntityState.Value.COMPLETED,
				"%s: vehicle '%s' completed" % [level_id, entity_id]
			)
		if state.is_won():
			solved += 1
	check_eq(solved, 10, "10/10 manual levels are completable")


func _solutions_are_deterministic() -> void:
	for level_id in M3LevelCatalogue.level_ids():
		var sequence: Array = SOLUTIONS[String(level_id)]
		var first := _run_sequence(level_id, sequence)
		var second := _run_sequence(level_id, sequence)
		check(first != null and second != null, "%s replay runs" % level_id)
		if first == null or second == null:
			continue
		check(
			Serialization.values_equal(first.to_dictionary(), second.to_dictionary()),
			"%s: identical command sequence produces an identical final state" % level_id
		)


func _run_sequence(level_id: StringName, sequence: Array) -> GameState:
	var simulation := _build(level_id)
	if simulation == null:
		return null
	for entity_id in sequence:
		simulation.execute(DispatchEntityCommand.new(entity_id))
	return simulation.get_state()


## Negative paths that document the intended puzzle pressure. These make the
## level designs meaningful (wrong order must cost something) without being
## required for victory.
func _wrong_first_moves_are_safe_or_losing() -> void:
	# L3: wrong first vehicle stages, and the level then dead-ends.
	var l3 := _build(&"traffic_m3_l03_right_order")
	check(l3 != null, "L3 builds")
	if l3 != null:
		check(l3.execute(DispatchEntityCommand.new(&"v2")).is_success(), "L3 wrong-first dispatch is legal")
		check(l3.get_state().staging.has(&"v2"), "L3 wrong-first vehicle is staged")
		check(l3.execute(DispatchEntityCommand.new(&"v1")).is_success(), "L3 correct vehicle still completes")
		check(l3.get_state().is_lost(), "L3 dead-ends after the wrong order")
		check_eq(l3.get_state().fail_reason, FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), "L3 dead-end reason")

	# L5: one staging slot; a second unserved vehicle loses with staging_full.
	var l5 := _build(&"traffic_m3_l05_tight_parking")
	check(l5 != null, "L5 builds")
	if l5 != null:
		l5.execute(DispatchEntityCommand.new(&"v2"))
		check(l5.get_state().staging.is_full(), "L5 single slot is used by the wrong first move")
		var overflow := l5.execute(DispatchEntityCommand.new(&"v3"))
		check_eq(overflow.code, &"staging_full", "L5 overflow reports staging_full")
		check(l5.get_state().is_lost(), "L5 overflow ends the level")
		check_eq(l5.get_state().fail_reason, FailReason.to_string_name(FailReason.Value.STAGING_FULL), "L5 failure reason")

	# L8: zero staging slots; any unserved vehicle loses immediately.
	var l8 := _build(&"traffic_m3_l08_no_room_to_wait")
	check(l8 != null, "L8 builds")
	if l8 != null:
		var zero_slot := l8.execute(DispatchEntityCommand.new(&"v2"))
		check_eq(zero_slot.code, &"staging_full", "L8 with zero slots loses on the first wrong move")
		check_eq(l8.get_state().fail_reason, FailReason.to_string_name(FailReason.Value.STAGING_FULL), "L8 failure reason")

	# L6: the blocked first move is rejected safely (no state mutation).
	var l6 := _build(&"traffic_m3_l06_the_blocker")
	check(l6 != null, "L6 builds")
	if l6 != null:
		var before := l6.snapshot()
		var blocked := l6.execute(DispatchEntityCommand.new(&"v2"))
		check_eq(blocked.status, CommandResult.Status.BLOCKED, "L6 blocked dispatch reports BLOCKED")
		check_eq(blocked.code, &"cell_occupied", "L6 blocked code")
		check(Serialization.values_equal(before, l6.snapshot()), "L6 blocked dispatch does not mutate state")
		check(l6.execute(DispatchEntityCommand.new(&"v1")).is_success(), "L6 blocker can complete")
		check(l6.execute(DispatchEntityCommand.new(&"v2")).is_success(), "L6 blocked vehicle succeeds once cleared")
		check(l6.get_state().is_won(), "L6 wins after unblocking")
