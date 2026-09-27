extends "res://tests/framework/test_base.gd"
## M6 Generator Lab tooling tests (AGENT-2). Presentation-only debug tooling:
## plain DTOs/mocks, no generator/solver/levels/core/puzzle imports.

const Contract := preload("res://themes/traffic/dev/m6/generator_lab_contract.gd")
const Model := preload("res://themes/traffic/dev/m6/generator_lab_model.gd")
const View := preload("res://themes/traffic/dev/m6/generator_lab_view.gd")
const Lab := preload("res://themes/traffic/dev/m6/generator_lab.gd")
const Samples := preload("res://themes/traffic/dev/m6/m6_samples.gd")

const REF := Vector2(1080.0, 1920.0)
const TALL := Vector2(1080.0, 2400.0)
const TABLET := Vector2(1600.0, 2560.0)


func run() -> void:
	_test_contract_candidate()
	_test_contract_difficulty_and_bucket()
	_test_contract_dedupe_and_decision()
	_test_contract_batch()
	_test_contract_malformed()
	_test_model_counts_and_board()
	_test_model_filter()
	_test_view_renders_and_texts()
	_test_view_layout_viewports()
	_test_lab_show_and_navigation()
	_test_lab_difficulty_display()
	_test_lab_rejection_and_dedupe_display()
	_test_lab_batch_display()
	_test_lab_filter_behavior()
	_test_lab_no_node_growth()
	_test_lab_debug_gate()
	_test_scene_loads()


func _test_contract_candidate() -> void:
	var candidate: Dictionary = Contract.normalize_candidate(Samples.sample_candidates()[0])
	check_eq(candidate.get("candidate_id", ""), "cand_0001", "candidate id normalized")
	check_eq(int(candidate.get("seed", -1)), 101, "seed normalized")
	var preview: Dictionary = candidate.get("preview", {})
	check_eq(int(preview.get("board_width", -1)), 4, "preview board width normalized")
	check_eq((preview.get("entities", []) as Array).size(), 1, "preview entities normalized")
	check_eq(candidate.get("solver", {}).get("status", ""), "SOLVABLE", "solver normalized")
	check_eq(candidate.get("validation", {}).get("status", ""), "VALID", "validation normalized")


func _test_contract_difficulty_and_bucket() -> void:
	var difficulty: Dictionary = Contract.normalize_difficulty({"score": 0.52, "tier": "medium", "parts": {"depth": 0.5}})
	check(is_equal_approx(float(difficulty.get("score", 0.0)), 0.52), "difficulty score normalized")
	check_eq(difficulty.get("bucket", ""), "MEDIUM", "bucket normalized from tier + lower case")
	check(is_equal_approx(float(difficulty.get("components", {}).get("depth", 0.0)), 0.5), "component normalized")
	var clamped: Dictionary = Contract.normalize_difficulty({"score": 9.0})
	check(is_equal_approx(float(clamped.get("score", -1.0)), 1.0), "difficulty score clamped to 1")
	check_eq(Contract.normalize_bucket("nonsense"), "UNKNOWN", "unknown bucket -> UNKNOWN")
	check_eq(Contract.normalize_bucket("expert"), "EXPERT", "expert bucket recognized")
	var fallback: Dictionary = Contract.normalize_difficulty("bad")
	check_eq(fallback.get("bucket", ""), "UNKNOWN", "malformed difficulty -> UNKNOWN")


func _test_contract_dedupe_and_decision() -> void:
	var dedupe: Dictionary = Contract.normalize_dedupe({"hash": "fp_x", "is_duplicate": true, "duplicate_of": "cand_0009"})
	check_eq(dedupe.get("fingerprint", ""), "fp_x", "fingerprint alias normalized")
	check(bool(dedupe.get("duplicate", false)), "duplicate flag normalized")
	check_eq(dedupe.get("of", ""), "cand_0009", "duplicate-of alias normalized")
	var decision: Dictionary = Contract.normalize_decision({"status": "rejected", "rejection_reasons": ["duplicate", "invalid"]})
	check_eq(decision.get("status", ""), "REJECTED", "decision status normalized")
	check_eq((decision.get("reasons", []) as Array).size(), 2, "decision reasons normalized")
	var bool_decision: Dictionary = Contract.normalize_decision(true)
	check_eq(bool_decision.get("status", ""), "ACCEPTED", "bare bool decision -> ACCEPTED")


func _test_contract_batch() -> void:
	var batch: Dictionary = Contract.normalize_batch(Samples.sample_batch())
	check_eq(int(batch.get("generated", -1)), 10000, "batch generated normalized")
	check_eq(int(batch.get("accepted", -1)), 4000, "batch accepted normalized")
	check_eq(int(batch.get("buckets", {}).get("MEDIUM", -1)), 1800, "batch bucket normalized")
	var fallback: Dictionary = Contract.normalize_batch(null)
	check_eq(int(fallback.get("generated", -1)), 0, "malformed batch -> zeroed")
	check_eq((fallback.get("buckets", {}) as Dictionary).size(), 0, "malformed batch -> empty buckets")


func _test_contract_malformed() -> void:
	var candidate: Dictionary = Contract.normalize_candidate({})
	check_eq(candidate.get("candidate_id", "x"), "", "empty candidate id default")
	check_eq(candidate.get("solver", {}).get("status", ""), "UNKNOWN", "empty candidate solver default")
	var weird: Dictionary = Contract.normalize_candidate({"seed": "abc", "preview": "nonsense", "difficulty": 5})
	check_eq(int(weird.get("seed", -1)), 0, "non-int seed defaults")
	check_eq(int(weird.get("preview", {}).get("board_width", -1)), 0, "malformed preview defaults")
	check_eq(weird.get("difficulty", {}).get("bucket", ""), "UNKNOWN", "malformed difficulty defaults")


func _test_model_counts_and_board() -> void:
	var model = Model.new()
	model.set_candidates(Samples.sample_candidates())
	model.set_batch(Samples.sample_batch())
	check_eq(model.total_count(), 5, "model candidate count")
	check_eq(model.filtered_count(), 5, "no filter -> all candidates")
	check(model.build_board_data(model.candidate_at(0)) != null, "candidate board DTO builds")
	check_eq(model.build_board_data(model.candidate_at(0)).cells(), Vector2i(4, 2), "candidate board dimensions")
	check(model.preview_paths(model.candidate_at(0)).size() >= 1, "candidate preview paths exposed")
	check_eq(int(model.histogram().get("EASY", -1)), 900, "histogram exposed")


func _test_model_filter() -> void:
	var model = Model.new()
	model.set_candidates(Samples.sample_candidates())
	model.set_filter("EASY", "")
	check_eq(model.filtered_count(), 2, "EASY filter matches two candidates")
	model.set_filter("", "ACCEPTED")
	check_eq(model.filtered_count(), 2, "ACCEPTED filter matches two candidates")
	model.set_filter("EASY", "ACCEPTED")
	check_eq(model.filtered_count(), 1, "combined bucket+decision filter")
	check_eq(model.candidate_at(model.filtered_indices()[0]).get("candidate_id", ""), "cand_0001", "combined filter picks cand_0001")
	model.set_filter("EXPERT", "")
	check_eq(model.filtered_count(), 0, "no EXPERT candidates")
	model.set_filter("ALL", "ALL")
	check_eq(model.filtered_count(), 5, "ALL/ALL resets the filter")


func _test_view_renders_and_texts() -> void:
	var model = Model.new()
	model.set_candidates(Samples.sample_candidates())
	var view = View.new()
	view.build()
	view.set_board(model.build_board_data(model.candidate_at(0)))
	view.set_paths(model.preview_paths(model.candidate_at(0)))
	view.set_info_text("INFO")
	view.set_candidate_list_text("LIST")
	view.set_generation_text("GEN")
	view.set_validation_text("VALIDATION")
	view.set_solver_text("SOLVER")
	view.set_difficulty_text("DIFFICULTY")
	view.set_dedupe_text("DEDUPE")
	view.set_decision_text("DECISION")
	view.set_batch_text("BATCH")
	check_eq(view.info_text(), "INFO", "info text set")
	check_eq(view.batch_text(), "BATCH", "batch text set")
	check_eq(view.board_view().entity_view_count(), 1, "board renders supplied entity")
	check(view.path_overlay().path_count() >= 1, "path overlay received paths")
	view.clear()
	check_eq(view.info_text(), "", "clear resets info")
	check_eq(view.path_overlay().path_count(), 0, "clear resets paths")
	view.free()


func _test_view_layout_viewports() -> void:
	for viewport: Vector2 in [REF, TALL, TABLET]:
		var model = Model.new()
		model.set_candidates(Samples.sample_candidates())
		var view = View.new()
		view.build()
		view.set_board(model.build_board_data(model.candidate_at(0)))
		view.layout_for(viewport)
		var board: Rect2 = view.board_rect()
		check(board.size.x > 0.0 and board.size.y > 0.0, "board laid out at %s" % viewport)
		check(board.end.x <= viewport.x + 1.0 and board.end.y <= viewport.y + 1.0, "board fits at %s" % viewport)
		view.free()


func _test_lab_show_and_navigation() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	check(lab.show_candidates(Samples.sample_candidates(), 0), "candidates load")
	check_eq(lab.total_count(), 5, "lab total count")
	check_eq(lab.filtered_count(), 5, "lab filtered count")
	check_eq(lab.current_index(), 0, "starts at first candidate")
	check_eq(lab.current_candidate().get("candidate_id", ""), "cand_0001", "first candidate selected")
	check(lab.next_candidate(), "next advances")
	check_eq(lab.current_index(), 1, "index advanced")
	check(lab.previous_candidate(), "previous goes back")
	check_eq(lab.current_index(), 0, "index moved back")
	check(not lab.previous_candidate(), "previous at start refused")
	for i in 4:
		lab.next_candidate()
	check_eq(lab.current_index(), 4, "navigate to last candidate")
	check(not lab.next_candidate(), "next at end refused")
	lab.free()


func _test_lab_difficulty_display() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_candidates(Samples.sample_candidates(), 0)
	check(lab.view().difficulty_text().contains("0.12"), "difficulty score displayed")
	check(lab.view().difficulty_text().contains("EASY"), "difficulty bucket displayed")
	check(lab.view().difficulty_text().contains("depth"), "difficulty components displayed")
	check(lab.view().solver_text().contains("SOLVABLE"), "solver status displayed")
	check(lab.view().solver_text().contains("depth 1"), "solver depth displayed")
	lab.free()


func _test_lab_rejection_and_dedupe_display() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_candidates(Samples.sample_candidates(), 0)
	lab.next_candidate()
	lab.next_candidate()
	check(lab.view().decision_text().contains("REJECTED"), "rejection status displayed")
	check(lab.view().decision_text().contains("validation_failed"), "rejection reason displayed")
	check(lab.view().validation_text().contains("INVALID"), "invalid validation displayed")
	check(lab.view().validation_text().contains("OUT_OF_BOUNDS"), "validation error code displayed")
	lab.set_filter("ALL", "ALL")
	for i in 4:
		lab.next_candidate()
	check_eq(lab.current_candidate().get("candidate_id", ""), "cand_0005", "duplicate candidate selected")
	check(lab.view().dedupe_text().contains("DUPLICATE"), "duplicate status displayed")
	check(lab.view().dedupe_text().contains("cand_0001"), "duplicate origin displayed")
	lab.free()


func _test_lab_batch_display() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_candidates(Samples.sample_candidates(), 0)
	lab.set_batch(Samples.sample_batch())
	check(lab.view().batch_text().contains("generated 10000"), "batch generated displayed")
	check(lab.view().batch_text().contains("accepted 4000"), "batch accepted displayed")
	check(lab.view().batch_text().contains("MEDIUM"), "batch histogram bucket displayed")
	check(lab.view().batch_text().contains("|"), "batch histogram bar displayed")
	lab.free()


func _test_lab_filter_behavior() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_candidates(Samples.sample_candidates(), 0)
	check_eq(lab.cycle_bucket_filter(), "EASY", "bucket filter cycles to EASY")
	check_eq(lab.filtered_count(), 2, "EASY filter narrows candidates")
	lab.set_filter("ALL", "REJECTED")
	check_eq(lab.filtered_count(), 3, "REJECTED filter narrows candidates")
	check_eq(lab.current_index(), 2, "first rejected candidate index")
	lab.set_filter("MEDIUM", "ACCEPTED")
	check_eq(lab.filtered_count(), 1, "combined filter narrows to one")
	check_eq(lab.current_index(), 1, "combined filter selects cand_0002")
	check_eq(lab.cycle_decision_filter(), "REJECTED", "decision filter cycles")
	check_eq(lab.filtered_count(), 0, "MEDIUM + REJECTED has no candidates")
	check(lab.status_text().contains("no candidates"), "empty filter state shown")
	lab.free()


func _test_lab_no_node_growth() -> void:
	var lab = Lab.new()
	lab.debug_enabled = true
	lab.build()
	lab.layout_for(REF)
	lab.show_candidates(Samples.sample_candidates(), 0)
	var baseline := _count_nodes(lab)
	for i in 5:
		lab.show_candidates(Samples.sample_candidates(), i % 5)
	check_eq(_count_nodes(lab), baseline, "repeated loads do not grow the node tree")
	lab.free()


func _test_lab_debug_gate() -> void:
	var lab = Lab.new()
	lab.debug_enabled = false
	lab.build()
	check(not lab.is_enabled(), "lab disabled when gate is off")
	check(not lab.show_candidates(Samples.sample_candidates(), 0), "disabled lab refuses candidates")
	check_eq(lab.total_count(), 0, "disabled lab loads nothing")
	check(not lab.visible, "disabled lab hides itself")
	lab.free()


func _test_scene_loads() -> void:
	var packed: Variant = load("res://themes/traffic/dev/m6/generator_lab.tscn")
	check(packed is PackedScene, "generator lab scene loads")
	if not (packed is PackedScene):
		return
	var node: Node = packed.instantiate()
	check(node != null, "generator lab scene instantiates")
	if node == null:
		return
	node.set("debug_enabled", true)
	node.call("build")
	node.call("layout_for", REF)
	check(node.call("show_candidates", Samples.sample_candidates(), 0), "scene loads candidates")
	check_eq(node.call("total_count"), 5, "scene candidate count")
	node.free()


func _count_nodes(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total
