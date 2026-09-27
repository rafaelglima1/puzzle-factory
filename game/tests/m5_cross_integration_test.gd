extends "res://tests/framework/test_base.gd"
## M5 cross-integration tests (M5-INTEGRATOR).
##
## Exercises the seam between AGENT-1's real content engine (official pack,
## LevelDefinition, LevelValidator, BfsSolver, SolverResult, simulation) and
## AGENT-2's Level Lab presentation tooling, through the integration adapter,
## controller and playback driver. Unit-level behaviour is covered by each side's
## own suite; these tests only prove the cross-layer contract.

const Adapter := preload("res://integration/traffic/dev/m5/traffic_level_lab_adapter.gd")
const Controller := preload("res://integration/traffic/dev/m5/traffic_level_lab_controller.gd")
const Driver := preload("res://integration/traffic/dev/m5/traffic_solution_playback_driver.gd")
const Lab := preload("res://themes/traffic/dev/m5/level_lab.gd")
const Solvable := preload("res://tests/m3_levels_solvable_test.gd")

const EXPECTED_IDS: Array[String] = [
	"traffic_m3_l01_first_roll",
	"traffic_m3_l02_two_lanes",
	"traffic_m3_l03_right_order",
	"traffic_m3_l04_double_pickup",
	"traffic_m3_l05_tight_parking",
	"traffic_m3_l06_the_blocker",
	"traffic_m3_l07_three_colors",
	"traffic_m3_l08_no_room_to_wait",
	"traffic_m3_l09_multi_step",
	"traffic_m3_l10_rush_hour",
]

const REF := Vector2(1080.0, 1920.0)


func run() -> void:
	_test_a_real_pack_to_lab()
	_test_b_real_solver_to_lab()
	_test_c_manifest_order()
	_test_d_driver_single_step()
	_test_e_driver_reset()
	_test_f_all_ten_playbacks()
	_test_g_visual_refresh()
	_test_h_level_switch()
	_test_i_debug_gate()
	_test_j_presentation_boundary()
	_test_k_resource_stability()


# --- harness ------------------------------------------------------------------

func _definition(index: int) -> LevelDefinition:
	return TrafficLevelCatalogue.load_definition(index)


func _make_lab() -> Variant:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.call("build")
	lab.call("layout_for", REF)
	return lab


## Frees a lab created by _make_lab(). The lab is a detached Control, so it is
## released directly through the Node type (Node.free is not reachable through
## Object.call on a Control).
func _dispose_lab(lab: Variant) -> void:
	if lab == null:
		return
	var node: Node = lab
	node.free()


# --- TEST A -------------------------------------------------------------------

func _test_a_real_pack_to_lab() -> void:
	for index in TrafficLevelCatalogue.count():
		var definition := _definition(index)
		check(definition != null, "A: official level %d loads" % index)
		if definition == null:
			continue
		var preview := Adapter.definition_to_preview(definition)
		check_eq(str(preview.get("level_id", "")), String(definition.level_id), "A: preview id matches definition")
		check_eq(int(preview.get("board_width", 0)), definition.board_width, "A: board width matches")
		check_eq(int(preview.get("board_height", 0)), definition.board_height, "A: board height matches")
		check_eq((preview.get("entities", []) as Array).size(), definition.entities.size(), "A: entity count matches")
		check_eq((preview.get("items", []) as Array).size(), definition.items.size(), "A: item count matches")
		check_eq((preview.get("queues", []) as Array).size(), definition.queues.size(), "A: queue count matches")
		check_eq((preview.get("destinations", []) as Array).size(), definition.destinations.size(), "A: destination count matches")
		check_eq((preview.get("paths", []) as Array).size(), definition.paths.size(), "A: path count matches")
		check_eq(int(preview.get("staging_slots", -1)), definition.staging_slots, "A: staging slots match")
		var validation := Adapter.validation_to_contract(LevelValidator.validate(definition))
		check_eq(str(validation.get("status", "")), "VALID", "A: official level %s validates" % definition.level_id)
		check_eq((validation.get("errors", []) as Array).size(), 0, "A: %s has zero validation errors" % definition.level_id)


# --- TEST B -------------------------------------------------------------------

func _test_b_real_solver_to_lab() -> void:
	for index in TrafficLevelCatalogue.count():
		var definition := _definition(index)
		if definition == null:
			continue
		var result := BfsSolver.new().solve(TrafficSolverDomain.for_definition(definition))
		var contract := Adapter.solver_to_contract(result)
		check_eq(str(contract.get("status", "")), "SOLVABLE", "B: %s solver SOLVABLE" % definition.level_id)
		check_eq(str(contract.get("status", "")), result.status_name(), "B: %s status preserved" % definition.level_id)
		check_eq(int(contract.get("solution_depth", -1)), result.solution_depth, "B: %s depth preserved" % definition.level_id)
		check_eq(int(contract.get("visited_states", -1)), result.visited_states, "B: %s visited preserved" % definition.level_id)
		check_eq(int(contract.get("expanded_states", -1)), result.expanded_states, "B: %s expanded preserved" % definition.level_id)
		var commands: Array = contract.get("solution_commands", [])
		check_eq(commands.size(), result.solution_depth, "B: %s normalized command count == depth" % definition.level_id)
		for position in commands.size():
			check_eq(
				str((commands[position] as Dictionary).get("entity_id", "")),
				str((result.solution_commands[position] as Dictionary).get("entityId", "")),
				"B: %s command %d order preserved" % [definition.level_id, position]
			)


# --- TEST C -------------------------------------------------------------------

func _test_c_manifest_order() -> void:
	check_eq(TrafficLevelCatalogue.count(), EXPECTED_IDS.size(), "C: ten official levels")
	for index in EXPECTED_IDS.size():
		check_eq(String(TrafficLevelCatalogue.level_id(index)), EXPECTED_IDS[index], "C: index %d id order" % index)
		check_eq(String(_definition(index).level_id), EXPECTED_IDS[index], "C: index %d definition id" % index)

	var lab = _make_lab()
	var controller = Controller.new(lab)
	var loaded := int(controller.call("load_official_levels"))
	check_eq(loaded, 10, "C: controller loads ten official levels")
	check(controller.call("feed_lab"), "C: controller feeds the lab")
	check_eq(String(lab.call("model").call("level_id")), EXPECTED_IDS[0], "C: lab starts on level 1")
	_dispose_lab(lab)


# --- TEST D -------------------------------------------------------------------

func _test_d_driver_single_step() -> void:
	var definition := _definition(0)
	var original := Serialization.to_json(definition.to_dictionary())
	var driver = Driver.for_definition(definition)
	var before := SolverStateHasher.hash_snapshot(driver.snapshot())
	check_eq(driver.call("move_index"), 0, "D: fresh driver starts at move 0")

	var command := Adapter.normalize_command({"type": "dispatch_entity", "entityId": "v1"})
	check(driver.call("execute", command), "D: first solution command is accepted")
	check_eq(driver.call("move_index"), 1, "D: move index advances exactly once")
	check_eq(driver.call("applied_count"), 1, "D: applied count is one")
	check(SolverStateHasher.hash_snapshot(driver.call("snapshot")) != before, "D: state hash changes after a step")
	check_eq(Serialization.to_json(definition.to_dictionary()), original, "D: the original LevelDefinition is unchanged")


# --- TEST E -------------------------------------------------------------------

func _test_e_driver_reset() -> void:
	var definition := _definition(4)
	var driver = Driver.for_definition(definition)
	var initial := SolverStateHasher.hash_snapshot(driver.call("snapshot"))
	driver.call("execute", Adapter.normalize_command({"type": "dispatch_entity", "entityId": "v1"}))
	driver.call("execute", Adapter.normalize_command({"type": "dispatch_entity", "entityId": "v2"}))
	check(driver.call("applied_count") > 0, "E: steps were applied before reset")

	driver.call("reset")
	check_eq(SolverStateHasher.hash_snapshot(driver.call("snapshot")), initial, "E: reset restores the initial state hash")
	check_eq(driver.call("move_index"), 0, "E: reset restores move index 0")
	check_eq(driver.call("applied_count"), 0, "E: reset clears applied count")

	# Repeated reset is deterministic.
	driver.call("reset")
	check_eq(SolverStateHasher.hash_snapshot(driver.call("snapshot")), initial, "E: repeated reset is deterministic")


# --- TEST F -------------------------------------------------------------------

func _test_f_all_ten_playbacks() -> void:
	var all_solved := 0
	for index in TrafficLevelCatalogue.count():
		var definition := _definition(index)
		var result := BfsSolver.new().solve(TrafficSolverDomain.for_definition(definition))
		if not result.is_solvable():
			check(false, "F: %s not SOLVABLE" % definition.level_id)
			continue
		var driver = Driver.for_definition(definition)
		var rejected := 0
		for descriptor in result.solution_commands:
			var command := Adapter.normalize_command(descriptor)
			if not driver.call("execute", command):
				rejected += 1
		check_eq(rejected, 0, "F: %s has no rejected solver command" % definition.level_id)
		check(driver.call("is_won"), "F: %s playback ends WON" % definition.level_id)
		check_eq(driver.call("applied_count"), result.solution_depth, "F: %s applied_count == solution_depth" % definition.level_id)
		all_solved += 1
	check_eq(all_solved, 10, "F: all ten official levels play back to a win")
	# The known M3 solution sequences remain the independent gameplay evidence.
	check_eq(Solvable.SOLUTIONS.size(), 10, "F: M3 solution scripts still cover all ten levels")


# --- TEST G -------------------------------------------------------------------

func _test_g_visual_refresh() -> void:
	var lab = _make_lab()
	var controller = Controller.new(lab)
	check_eq(int(controller.call("load_official_levels")), 10, "G: controller loads official levels")
	check(controller.call("feed_lab"), "G: controller feeds the lab")
	controller.call("prepare_playback")

	var board_before: Variant = lab.call("view").call("board_view")
	var before_sprite_count := _board_child_count(board_before)
	var solver_before: String = lab.call("solver_text")
	var commands_before: String = lab.call("commands_text")
	var step_before: int = lab.call("playback").call("step")

	check(controller.call("step_once"), "G: one playback step runs")
	check_eq(lab.call("playback").call("step"), step_before + 1, "G: playback step advanced by one")
	check_eq(lab.call("solver_text"), solver_before, "G: solver metrics preserved across refresh")
	check_eq(lab.call("commands_text"), commands_before, "G: command list preserved across refresh")
	check_eq(lab.call("playback").call("step"), step_before + 1, "G: playback not restarted by refresh")
	check(_board_child_count(lab.call("view").call("board_view")) != before_sprite_count, "G: board re-rendered from authoritative state")
	_dispose_lab(lab)


func _board_child_count(board_view: Variant) -> int:
	if board_view == null:
		return -1
	return board_view.get_child_count()


# --- TEST H -------------------------------------------------------------------

func _test_h_level_switch() -> void:
	var lab = _make_lab()
	var controller = Controller.new(lab)
	controller.call("load_official_levels")
	controller.call("feed_lab")
	controller.call("prepare_playback")
	controller.call("step_once")

	check_eq(String(lab.call("model").call("level_id")), EXPECTED_IDS[0], "H: lab on level 1 before switch")
	check(controller.call("next"), "H: controller advances to level 2")
	controller.call("prepare_playback")
	check_eq(String(lab.call("model").call("level_id")), EXPECTED_IDS[1], "H: lab shows level 2 after switch")
	check_eq(lab.call("playback").call("step"), 0, "H: playback step reset on level switch")
	check_eq(int(lab.call("model").call("solver_status") != "UNKNOWN"), 1, "H: level 2 solver result present")
	check_eq((lab.call("model").call("solution_commands") as Array).size() > 0, true, "H: level 2 commands present")
	# The live driver must be the level 2 driver, not a stale level 1 one.
	check_eq(String(controller.call("get_driver").call("snapshot").get("level_id", "")), EXPECTED_IDS[1], "H: driver replaced for level 2")
	_dispose_lab(lab)


# --- TEST I -------------------------------------------------------------------

func _test_i_debug_gate() -> void:
	var lab = _make_lab()
	lab.debug_enabled = false
	lab.call("_apply_enabled")
	check(not lab.call("is_enabled"), "I: lab reports disabled")
	check(not lab.call("show_levels", [Adapter.definition_to_preview(_definition(0))], 0), "I: disabled lab refuses content")

	var controller = Controller.new(lab)
	controller.debug_enabled = false
	check(not controller.call("is_enabled"), "I: controller reports disabled")
	check(not controller.call("feed_lab"), "I: disabled controller refuses to feed the lab")
	_dispose_lab(lab)

	# Production main scene is unchanged.
	var config := ConfigFile.new()
	if config.load("res://project.godot") == OK:
		var main_scene: String = str(config.get_value("application", "run/main_scene", ""))
		check_eq(main_scene, "res://integration/traffic/traffic_m3_app_controller.tscn", "I: run/main_scene unchanged")


# --- TEST J -------------------------------------------------------------------

func _test_j_presentation_boundary() -> void:
	var forbidden: Array[String] = [
		"res://levels", "res://solver", "res://core", "res://puzzle",
		"res://integration", "res://persistence", "res://content",
	]
	var dir := "res://themes/traffic/dev/m5"
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir.path_join(file))
		for reference in forbidden:
			check(not text.contains(reference), "J: %s imports no %s" % [file, reference])


# --- TEST K -------------------------------------------------------------------

func _test_k_resource_stability() -> void:
	var lab = _make_lab()
	var controller = Controller.new(lab)
	controller.call("load_official_levels")
	controller.call("feed_lab")
	var lab_children_before: int = lab.get_child_count()

	for cycle in 5:
		controller.call("prepare_playback")
		controller.call("step_once")
		controller.call("reset_playback")
		controller.call("next")
		controller.call("previous")

	check_eq(lab.get_child_count(), lab_children_before, "K: lab node tree stable across repeated cycles")
	check_eq(controller.call("level_count"), 10, "K: controller entry list stable")
	check_eq(lab.call("playback").call("command_count"), (lab.call("model").call("solution_commands") as Array).size(), "K: no duplicate command accumulation")
	_dispose_lab(lab)
