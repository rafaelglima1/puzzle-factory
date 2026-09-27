extends "res://tests/framework/test_base.gd"
## M5 Level Lab tooling tests (AGENT-2). Presentation-only debug tooling:
## plain DTOs/mocks, no core/puzzle/solver/levels/persistence imports.

const Contract := preload("res://themes/traffic/dev/m5/level_lab_contract.gd")
const Model := preload("res://themes/traffic/dev/m5/level_lab_model.gd")
const View := preload("res://themes/traffic/dev/m5/level_lab_view.gd")
const PathOverlay := preload("res://themes/traffic/dev/m5/level_lab_path_overlay.gd")
const Playback := preload("res://themes/traffic/dev/m5/solution_playback_controller.gd")
const Lab := preload("res://themes/traffic/dev/m5/level_lab.gd")
const Samples := preload("res://themes/traffic/dev/m5/m5_samples.gd")

const REF := Vector2(1080.0, 1920.0)
const TALL := Vector2(1080.0, 2400.0)
const TABLET := Vector2(1600.0, 2560.0)


## Records driver calls so the playback hook contract can be asserted.
class FakeDriver extends RefCounted:
	var executed: Array = []
	var reset_count := 0
	var snapshot_value: Variant = null

	func execute(command: Dictionary) -> void:
		executed.append(command)

	func reset() -> void:
		reset_count += 1

	func snapshot() -> Variant:
		return snapshot_value


func run() -> void:
	_test_contract_preview()
	_test_contract_validation()
	_test_contract_solver()
	_test_contract_commands_order()
	_test_model_counts_and_board()
	_test_model_queue_and_paths()
	_test_model_invalid_preview()
	_test_view_renders_and_texts()
	_test_view_layout_viewports()
	_test_path_overlay()
	_test_playback_step_reset_bounds()
	_test_playback_driver_hook()
	_test_lab_show_and_navigation()
	_test_lab_switch_clears_and_bounded_nodes()
	_test_lab_validation_and_solver_ui()
	_test_lab_play_solution()
	_test_lab_debug_gate()
	_test_scene_loads()


func _test_contract_preview() -> void:
	var normalized: Dictionary = Contract.normalize_preview({
		"levelId": "x", "schemaVersion": 2, "width": 5, "height": 3, "stagingSlots": 6,
		"vehicles": [{"id": "v1", "type": "van", "colorKey": "COLOR_B",
			"position": {"x": 1, "y": 2}, "size": {"width": 2, "height": 1},
			"route": [{"x": 1, "y": 2}, {"x": 2, "y": 2}]}],
		"stations": [{"id": "s1", "cell": {"x": 4, "y": 0}, "accepted": "COLOR_B",
			"capacity": 1, "queue": ["COLOR_B"]}],
		"objectives": [{"id": "clear_all", "type": "clear_all", "mandatory": true}],
	})
	check_eq(normalized.get("level_id", ""), "x", "level id normalized")
	check_eq(int(normalized.get("schema_version", -1)), 2, "schema version normalized")
	check_eq(int(normalized.get("board_width", -1)), 5, "width alias normalized")
	check_eq(int(normalized.get("board_height", -1)), 3, "height alias normalized")
	check_eq(int(normalized.get("staging_slots", -1)), 6, "staging alias normalized")
	var entities: Array = normalized.get("entities", [])
	check_eq(entities.size(), 1, "entity normalized")
	if entities.size() == 1:
		var entity: Dictionary = entities[0]
		check_eq(entity.get("id", &""), &"v1", "entity id")
		check_eq(entity.get("color_key", &""), &"COLOR_B", "entity color alias")
		check(entity.get("cell", Vector2i.ZERO) == Vector2i(1, 2), "entity cell from dict")
		check(entity.get("footprint", Vector2i.ZERO) == Vector2i(2, 1), "entity footprint from dict")
		check((entity.get("path", []) as Array).size() == 2, "entity route normalized to path")
	var destinations: Array = normalized.get("destinations", [])
	check_eq(destinations.size(), 1, "destination normalized")
	if destinations.size() == 1:
		var destination: Dictionary = destinations[0]
		check_eq(destination.get("queue_color_keys", []), [&"COLOR_B"], "destination queue keys")
	check_eq((normalized.get("objectives", []) as Array).size(), 1, "objective normalized")

	var empty: Dictionary = Contract.normalize_preview({})
	check_eq(int(empty.get("board_width", -1)), 0, "empty preview defaults width")
	check_eq((empty.get("entities", []) as Array).size(), 0, "empty preview defaults entities")


func _test_contract_validation() -> void:
	var valid: Dictionary = Contract.normalize_validation({"valid": true, "errors": []})
	check_eq(valid.get("status", ""), "VALID", "valid status")
	var invalid: Dictionary = Contract.normalize_validation(Samples.invalid_validation())
	check_eq(invalid.get("status", ""), "INVALID", "invalid status")
	check_eq((invalid.get("errors", []) as Array).size(), 3, "three validation errors")
	var first: Dictionary = (invalid.get("errors", []) as Array)[0]
	check_eq(first.get("code", ""), "unknown_destination", "error code preserved")
	check_eq(first.get("path", ""), "vehicles[0].station", "error path preserved")
	check(not str(first.get("message", "")).is_empty(), "error message preserved")
	var from_array: Dictionary = Contract.normalize_validation(["BAD"])
	check_eq(from_array.get("status", ""), "INVALID", "bare error array -> INVALID")
	var fallback: Dictionary = Contract.normalize_validation(null)
	check_eq(fallback.get("status", ""), "VALID", "malformed validation -> VALID default")


func _test_contract_solver() -> void:
	var solvable: Dictionary = Contract.normalize_solver(Samples.level_two().get("solver", {}))
	check_eq(solvable.get("status", ""), "SOLVABLE", "solvable status")
	check_eq(int(solvable.get("solution_depth", -1)), 2, "solution depth")
	check_eq(int(solvable.get("visited_states", -1)), 5, "visited states")
	check_eq(int(solvable.get("expanded_states", -1)), 3, "expanded states")
	check_eq(int(solvable.get("dead_end_count", -1)), 1, "dead ends")
	check(is_equal_approx(float(solvable.get("branching_factor_avg", 0.0)), 1.6), "branching avg")
	check_eq(int(solvable.get("runtime_ms", -1)), 7, "runtime ms")
	var unsolvable: Dictionary = Contract.normalize_solver(Samples.unsolvable_solver())
	check_eq(unsolvable.get("status", ""), "UNSOLVABLE", "unsolvable status")
	var unknown: Dictionary = Contract.normalize_solver(Samples.unknown_solver())
	check_eq(unknown.get("status", ""), "UNKNOWN", "unknown status")
	var fallback: Dictionary = Contract.normalize_solver("nonsense")
	check_eq(fallback.get("status", ""), "UNKNOWN", "malformed solver -> UNKNOWN")


func _test_contract_commands_order() -> void:
	var commands: Array = Contract.normalize_commands([
		{"entityId": "v1"},
		{"entity_id": "v2", "type": "dispatch_entity"},
		{"entity": "v3"},
		"bad",
		{"type": "dispatch_entity"},
	])
	check_eq(commands.size(), 3, "malformed/empty commands skipped")
	check_eq(commands[0].get("entity_id", &""), &"v1", "command 0 entity preserved")
	check_eq(commands[1].get("entity_id", &""), &"v2", "command 1 entity preserved")
	check_eq(commands[2].get("entity_id", &""), &"v3", "command 2 entity preserved (order kept)")
	check_eq(commands[0].get("type", ""), "dispatch_entity", "default command type")


func _test_model_counts_and_board() -> void:
	var model = Model.new()
	model.load_preview(Samples.level_two())
	check_eq(model.level_id(), "sample_lab_l02", "model level id")
	check(model.board_size() == Vector2i(5, 3), "model board size")
	check_eq(model.entity_count(), 2, "model entity count")
	check_eq(model.destination_count(), 2, "model destination count")
	check_eq(model.path_count(), 2, "model path count")
	check_eq(model.objective_count(), 1, "model objective count")
	check_eq(model.staging_slots(), 4, "model staging slots")
	var board = model.build_board_data()
	check_eq(board.cells(), Vector2i(5, 3), "board DTO dimensions")
	check_eq(board.entity_count(), 2, "board DTO entity count")
	check_eq(board.destination_count(), 2, "board DTO destination count")


func _test_model_queue_and_paths() -> void:
	var model = Model.new()
	model.load_preview(Samples.level_one())
	check_eq(model.queue_color_keys(&"station_a"), [&"COLOR_A"], "queue order preserved")
	check_eq(model.queue_color_keys(&"missing").size(), 0, "missing queue -> empty")
	var path: Array[Vector2i] = model.entity_path(&"v1")
	check_eq(path.size(), 3, "entity path length")
	check(path.size() == 3 and path[0] == Vector2i(0, 0) and path[2] == Vector2i(2, 0), "entity path ordered cells")
	model.clear()
	check_eq(model.entity_count(), 0, "clear resets preview")
	check_eq(model.staging_slots(), 0, "clear resets staging")


func _test_model_invalid_preview() -> void:
	var model = Model.new()
	model.load_preview({"level_id": 123, "entities": "nonsense", "destinations": 5, "width": "x"})
	check_eq(model.entity_count(), 0, "malformed entities ignored")
	check_eq(model.destination_count(), 0, "malformed destinations ignored")
	check_eq(model.board_size(), Vector2i.ZERO, "malformed dims default to zero")
	var board = model.build_board_data()
	check(board != null, "malformed preview still builds a board DTO")


func _test_view_renders_and_texts() -> void:
	var model = Model.new()
	model.load_preview(Samples.level_two())
	var view = View.new()
	view.build()
	view.set_board(model.build_board_data())
	view.set_paths([{"id": &"v1", "cells": [Vector2i(0, 0), Vector2i(1, 0)]}])
	view.set_info_text("INFO")
	view.set_validation_text("VALIDATION")
	view.set_solver_text("SOLVER")
	view.set_commands_text("COMMANDS")
	view.set_queues_text("QUEUES")
	view.set_staging_text("STAGING")
	view.set_objectives_text("OBJECTIVES")
	check_eq(view.info_text(), "INFO", "info text set")
	check_eq(view.staging_text(), "STAGING", "staging text set")
	check_eq(view.path_overlay().path_count(), 1, "path overlay received paths")
	check_eq(view.board_view().entity_view_count(), 2, "board renders supplied entities")
	check_eq(view.board_view().destination_view_count(), 2, "board renders supplied destinations")
	view.clear()
	check_eq(view.info_text(), "", "clear resets info text")
	check_eq(view.path_overlay().path_count(), 0, "clear resets paths")
	view.free()


func _test_view_layout_viewports() -> void:
	for viewport: Vector2 in [REF, TALL, TABLET]:
		var model = Model.new()
		model.load_preview(Samples.level_one())
		var view = View.new()
		view.build()
		view.set_board(model.build_board_data())
		view.layout_for(viewport)
		var board: Rect2 = view.board_rect()
		check(board.size.x > 0.0 and board.size.y > 0.0, "board laid out at %s" % viewport)
		check(board.position.x >= 0.0 and board.position.y >= 0.0, "board position in bounds at %s" % viewport)
		check(board.end.x <= viewport.x + 1.0 and board.end.y <= viewport.y + 1.0, "board fits at %s" % viewport)
		view.free()


func _test_path_overlay() -> void:
	var overlay = PathOverlay.new()
	overlay.set_paths([{"id": &"p", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]}], 64.0)
	check_eq(overlay.path_count(), 1, "overlay stores paths")
	overlay.clear_paths()
	check_eq(overlay.path_count(), 0, "overlay clears paths")
	overlay.set_paths([], 0.0)
	check_eq(overlay.path_count(), 0, "overlay tolerates zero cell size")
	overlay.free()


func _test_playback_step_reset_bounds() -> void:
	var playback = Playback.new()
	playback.set_commands([
		{"type": "dispatch_entity", "entityId": "v1"},
		{"type": "dispatch_entity", "entityId": "v2"},
		{"type": "dispatch_entity", "entityId": "v3"},
	])
	check_eq(playback.command_count(), 3, "playback command count")
	check_eq(playback.step(), 0, "playback starts at step 0")
	check_eq(playback.current_command().get("entity_id", &""), &"v1", "current command is first")
	check(playback.step_once(), "step once succeeds")
	check_eq(playback.step(), 1, "step increments exactly once")
	check(playback.step_once(), "second step succeeds")
	check(playback.step_once(), "third step succeeds")
	check(playback.is_complete(), "playback complete after all steps")
	check(not playback.step_once(), "step past the end is refused")
	check_eq(playback.step(), 3, "no overflow past the end")
	check_eq(playback.current_command(), {}, "no current command when complete")
	playback.reset()
	check_eq(playback.step(), 0, "reset returns to step zero")
	check_eq(playback.play_all(), 3, "play_all applies every remaining command")
	check_eq(playback.play_all(), 0, "play_all on a complete sequence applies nothing")


func _test_playback_driver_hook() -> void:
	var playback = Playback.new()
	var driver := FakeDriver.new()
	driver.snapshot_value = {"step": 0}
	playback.set_driver(driver)
	playback.set_commands([
		{"type": "dispatch_entity", "entityId": "v1"},
		{"type": "dispatch_entity", "entityId": "v2"},
	])
	check(playback.has_driver(), "driver attached")
	check_eq(driver.reset_count, 1, "set_commands calls driver.reset()")
	check(playback.step_once(), "driver step succeeds")
	check_eq(driver.executed.size(), 1, "driver received one command")
	check_eq(driver.executed[0].get("entity_id", &""), &"v1", "driver receives normalized command")
	check(playback.snapshot() != null, "snapshot forwarded to driver")
	playback.reset()
	check_eq(driver.reset_count, 2, "reset forwards to driver")


func _test_lab_show_and_navigation() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	check(lab.is_enabled(), "lab enabled in debug")
	check(lab.show_levels(Samples.sample_previews(), 0), "levels load")
	check_eq(lab.level_count(), 2, "two sample levels")
	check_eq(lab.current_index(), 0, "first level selected")
	check_eq(lab.model().level_id(), "sample_lab_l01", "first level model loaded")
	check_eq(lab.model().entity_count(), 1, "first level entity count reflected")
	check(lab.next_level(), "next level advances")
	check_eq(lab.current_index(), 1, "index advanced")
	check_eq(lab.model().level_id(), "sample_lab_l02", "second level model loaded")
	check(not lab.next_level(), "next at the end is refused")
	check(lab.previous_level(), "previous level goes back")
	check_eq(lab.current_index(), 0, "index moved back")
	check(not lab.previous_level(), "previous at the start is refused")
	lab.free()


func _test_lab_switch_clears_and_bounded_nodes() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_levels(Samples.sample_previews(), 0)
	var baseline := _count_nodes(lab)
	for i in 5:
		lab.show_levels(Samples.sample_previews(), i % 2)
	check_eq(_count_nodes(lab), baseline, "repeated level loads do not grow the node tree")
	lab.show_levels(Samples.sample_previews(), 1)
	check_eq(lab.playback().command_count(), 2, "switching levels reloads the solution commands")
	check_eq(lab.playback().step(), 0, "switching levels resets playback state")
	lab.free()


func _test_lab_validation_and_solver_ui() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_level(Samples.level_one())
	check(lab.validation_text().contains("VALID"), "valid state shown")
	lab.set_validation_result(Samples.invalid_validation())
	check(lab.validation_text().contains("INVALID (3)"), "invalid count shown")
	check(lab.validation_text().contains("unknown_destination"), "error code shown")
	lab.set_solver_result(Samples.unsolvable_solver())
	check(lab.solver_text().contains("UNSOLVABLE"), "unsolvable status shown")
	check(lab.solver_text().contains("dead-ends 4"), "solver metrics shown")
	check(lab.commands_text().contains("0 steps"), "empty solution command list shown")
	lab.set_solver_result(Samples.level_two().get("solver", {}))
	check(lab.commands_text().contains("2 steps"), "solution command list reflected")
	check(lab.commands_text().contains("v1"), "command target shown")
	lab.free()


func _test_lab_play_solution() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_level(Samples.level_two())
	check_eq(lab.playback().command_count(), 2, "solution commands loaded")
	check_eq(lab.play_solution(), 2, "play_solution applies both commands")
	check(lab.playback().is_complete(), "playback complete")
	check_eq(lab.playback().step(), 2, "playback step at the end")
	check(lab.status_text().contains("2 / 2"), "status text reflects progress")
	lab.reset_preview()
	check_eq(lab.playback().step(), 0, "reset returns preview to step zero")
	check(lab.step_solution(), "single step works")
	check_eq(lab.playback().step(), 1, "single step increments once")
	lab.free()


func _test_lab_debug_gate() -> void:
	var lab = Lab.new()
	lab.debug_enabled = false
	lab.build()
	check(not lab.is_enabled(), "lab disabled when the gate is off")
	check(not lab.show_levels(Samples.sample_previews(), 0), "disabled lab refuses levels")
	check_eq(lab.level_count(), 0, "disabled lab loads nothing")
	check(not lab.visible, "disabled lab hides itself")
	lab.free()


func _test_scene_loads() -> void:
	var packed: Variant = load("res://themes/traffic/dev/m5/level_lab.tscn")
	check(packed is PackedScene, "level lab scene loads")
	if not (packed is PackedScene):
		return
	var node: Node = packed.instantiate()
	check(node != null, "level lab scene instantiates")
	if node == null:
		return
	node.set("debug_enabled", true)
	node.call("build")
	node.call("layout_for", REF)
	check(node.call("show_levels", Samples.sample_previews(), 0), "scene shows sample levels")
	check_eq(node.call("level_count"), 2, "scene level count")
	node.free()


func _count_nodes(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total
