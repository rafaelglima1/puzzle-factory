extends Control
## DEV-ONLY M6 Generator Lab (AGENT-2): developer inspection of generation output.
##
## It renders supplied candidate/batch plain data: board preview, generation
## constraints, validation, solver metrics, difficulty score/bucket/components,
## dedupe fingerprint, accept/reject decision, and batch accounting with a small
## histogram. It never generates, solves, validates or mutates anything.
##
## Debug-gated: `debug_enabled` defaults to OS.is_debug_build(); the dev scene is
## never referenced by production startup.

const ModelScript := preload("res://themes/traffic/dev/m6/generator_lab_model.gd")
const ViewScript := preload("res://themes/traffic/dev/m6/generator_lab_view.gd")
const Contract := preload("res://themes/traffic/dev/m6/generator_lab_contract.gd")
const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")

signal closed
signal candidate_changed(index: int)

var debug_enabled: bool = OS.is_debug_build()

var _model: ModelScript = null
var _view: ViewScript = null
var _palette: PaletteScript = PaletteScript.new()
var _position := 0
var _built := false

var _controls: Control = null
var _prev_button: Button = null
var _next_button: Button = null
var _bucket_button: Button = null
var _decision_button: Button = null
var _close_button: Button = null
var _status_label: Label = null
var _viewport := Vector2(1080.0, 1920.0)


func _ready() -> void:
	build()
	var viewport_size: Vector2 = get_viewport_rect().size
	layout_for(viewport_size if viewport_size.x > 0.0 else _viewport)


func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	_model = ModelScript.new()
	_view = ViewScript.new()
	_view.name = "GeneratorLabView"
	add_child(_view)
	_view.build()

	_controls = Control.new()
	_controls.name = "Controls"
	add_child(_controls)

	_prev_button = _make_button("PrevButton", "PREV")
	_next_button = _make_button("NextButton", "NEXT")
	_bucket_button = _make_button("BucketButton", "BUCKET: ALL")
	_decision_button = _make_button("DecisionButton", "DECISION: ALL")
	_close_button = _make_button("CloseButton", "CLOSE")

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	_controls.add_child(_status_label)

	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_bucket_button.pressed.connect(_on_bucket_pressed)
	_decision_button.pressed.connect(_on_decision_pressed)
	_close_button.pressed.connect(_on_close_pressed)

	_apply_enabled()
	_refresh_controls()


# --- Public API -------------------------------------------------------------

func is_enabled() -> bool:
	return debug_enabled


func show_candidates(candidates: Array, index: int = 0) -> bool:
	_ensure_built()
	if not debug_enabled:
		return false
	if candidates.is_empty():
		return false
	_model.set_candidates(candidates)
	_position = maxi(index, 0)
	_apply_current()
	return true


func set_batch(raw: Variant) -> void:
	_ensure_built()
	_model.set_batch(raw)
	_refresh_batch_text()


func set_filter(bucket: String, decision: String) -> void:
	_ensure_built()
	_model.set_filter(bucket, decision)
	_position = 0
	_apply_current()


func cycle_bucket_filter() -> String:
	_ensure_built()
	var options: Array = ["ALL", "EASY", "MEDIUM", "HARD", "EXPERT"]
	var current: String = _model.filter_bucket if not _model.filter_bucket.is_empty() else "ALL"
	var next_index: int = (options.find(current) + 1) % options.size()
	var bucket: String = options[next_index]
	_model.set_filter(bucket, _model.filter_decision)
	_position = 0
	_apply_current()
	return bucket


func cycle_decision_filter() -> String:
	_ensure_built()
	var options: Array = ["ALL", "ACCEPTED", "REJECTED"]
	var current: String = _model.filter_decision if not _model.filter_decision.is_empty() else "ALL"
	var next_index: int = (options.find(current) + 1) % options.size()
	var decision: String = options[next_index]
	_model.set_filter(_model.filter_bucket, decision)
	_position = 0
	_apply_current()
	return decision


func next_candidate() -> bool:
	_ensure_built()
	if _position + 1 >= _model.filtered_count():
		return false
	_position += 1
	_apply_current()
	return true


func previous_candidate() -> bool:
	_ensure_built()
	if _position <= 0:
		return false
	_position -= 1
	_apply_current()
	return true


func total_count() -> int:
	return _model.total_count() if _model != null else 0


func filtered_count() -> int:
	return _model.filtered_count() if _model != null else 0


func current_position() -> int:
	return _position


func current_index() -> int:
	if _model == null:
		return -1
	var indices: Array[int] = _model.filtered_indices()
	if _position < 0 or _position >= indices.size():
		return -1
	return indices[_position]


func current_candidate() -> Dictionary:
	var index: int = current_index()
	if index < 0:
		return {}
	return _model.candidate_at(index)


func model() -> ModelScript:
	_ensure_built()
	return _model


func view() -> ViewScript:
	_ensure_built()
	return _view


func status_text() -> String:
	return _status_label.text if _status_label != null else ""


# --- Layout -----------------------------------------------------------------

func layout_for(viewport: Vector2) -> void:
	_ensure_built()
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return
	_viewport = viewport
	size = viewport

	var controls_height: float = 96.0
	_view.layout_for(Vector2(viewport.x, maxf(viewport.y - controls_height, 1.0)))

	_controls.position = Vector2(0.0, maxf(viewport.y - controls_height, 0.0))
	_controls.size = Vector2(viewport.x, controls_height)

	var margin := 24.0
	var gap := 12.0
	var button_width := 190.0
	var button_height := 64.0
	var cursor := margin
	for button: Button in [_prev_button, _next_button, _bucket_button, _decision_button]:
		button.position = Vector2(cursor, 8.0)
		button.size = Vector2(button_width, button_height)
		cursor += button_width + gap
	_close_button.position = Vector2(maxf(viewport.x - margin - button_width, 0.0), 8.0)
	_close_button.size = Vector2(button_width, button_height)
	_status_label.position = Vector2(margin, button_height + 12.0)
	_status_label.size = Vector2(maxf(viewport.x - margin * 2.0, 1.0), 22.0)


# --- Internals --------------------------------------------------------------

func _ensure_built() -> void:
	if not _built:
		build()


func _apply_current() -> void:
	if _model == null:
		return
	var candidate: Dictionary = current_candidate()
	if candidate.is_empty():
		_view.clear()
		_view.set_batch_text(_compose_batch_text())
		_refresh_controls()
		_refresh_status_text()
		return

	_view.set_board(_model.build_board_data(candidate))
	_view.set_paths(_paths_for_view(candidate))
	_view.set_info_text(_compose_info_text(candidate))
	_view.set_candidate_list_text(_compose_candidate_list_text())
	_view.set_generation_text(_compose_generation_text(candidate))
	_view.set_validation_text(_compose_validation_text(candidate))
	_view.set_solver_text(_compose_solver_text(candidate))
	_view.set_difficulty_text(_compose_difficulty_text(candidate))
	_view.set_dedupe_text(_compose_dedupe_text(candidate))
	_view.set_decision_text(_compose_decision_text(candidate))
	_view.set_batch_text(_compose_batch_text())

	_refresh_controls()
	_refresh_status_text()
	candidate_changed.emit(current_index())


func _paths_for_view(candidate: Dictionary) -> Array:
	var result: Array = []
	for path_variant: Variant in _model.preview_paths(candidate):
		if not (path_variant is Dictionary):
			continue
		var path: Dictionary = path_variant
		var cells: Array = path.get("cells", [])
		if cells.is_empty():
			continue
		var entity_id: StringName = path.get("entity_id", &"")
		result.append({
			"id": path.get("id", entity_id),
			"cells": cells,
			"color": _palette.color_for(_entity_color(candidate, entity_id)),
		})
	return result


func _entity_color(candidate: Dictionary, entity_id: StringName) -> StringName:
	var preview: Variant = candidate.get("preview", {})
	if typeof(preview) != TYPE_DICTIONARY:
		return &""
	var entities: Variant = preview.get("entities", [])
	if typeof(entities) != TYPE_ARRAY:
		return &""
	for entity_variant: Variant in entities:
		if entity_variant is Dictionary:
			var entity: Dictionary = entity_variant
			if entity.get("id", &"") == entity_id:
				return entity.get("color_key", &"")
	return &""


func _compose_info_text(candidate: Dictionary) -> String:
	var preview: Dictionary = candidate.get("preview", {})
	return "%s  ·  seed %d  ·  board %dx%d  ·  entities %d  ·  paths %d" % [
		candidate.get("candidate_id", ""),
		int(candidate.get("seed", 0)),
		int(preview.get("board_width", 0)),
		int(preview.get("board_height", 0)),
		(preview.get("entities", []) as Array).size(),
		(preview.get("paths", []) as Array).size(),
	]


func _compose_candidate_list_text() -> String:
	var bucket: String = _model.filter_bucket if not _model.filter_bucket.is_empty() else "ALL"
	var decision: String = _model.filter_decision if not _model.filter_decision.is_empty() else "ALL"
	return "candidate %d/%d (filtered)  ·  total %d  ·  bucket=%s  ·  decision=%s" % [
		_position + 1,
		_model.filtered_count(),
		_model.total_count(),
		bucket,
		decision,
	]


func _compose_generation_text(candidate: Dictionary) -> String:
	var lines: Array = ["GENERATION:"]
	var generation: Variant = candidate.get("generation", {})
	var constraints: Variant = generation.get("constraints", {}) if typeof(generation) == TYPE_DICTIONARY else {}
	if typeof(constraints) == TYPE_DICTIONARY:
		var source: Dictionary = constraints
		if source.is_empty():
			lines.append("  (no constraints supplied)")
		for key: Variant in source.keys():
			lines.append("  %s: %s" % [key, source[key]])
	else:
		lines.append("  (no constraints supplied)")
	return "\n".join(lines)


func _compose_validation_text(candidate: Dictionary) -> String:
	var validation: Variant = candidate.get("validation", {})
	var status: String = str(validation.get("status", "VALID")) if typeof(validation) == TYPE_DICTIONARY else "VALID"
	var errors: Array = validation.get("errors", []) if typeof(validation) == TYPE_DICTIONARY else []
	var lines: Array = ["VALIDATION: %s" % status]
	for error_variant: Variant in errors:
		if error_variant is Dictionary:
			var error: Dictionary = error_variant
			lines.append("  - %s @%s: %s" % [error.get("code", ""), error.get("path", ""), error.get("message", "")])
	return "\n".join(lines)


func _compose_solver_text(candidate: Dictionary) -> String:
	var solver: Variant = candidate.get("solver", {})
	if typeof(solver) != TYPE_DICTIONARY:
		return "SOLVER: UNKNOWN"
	var lines: Array = ["SOLVER: %s" % str(solver.get("status", "UNKNOWN"))]
	lines.append("  depth %d  visited %d  expanded %d  dead-ends %d  branch %.2f  %d ms" % [
		int(solver.get("solution_depth", 0)),
		int(solver.get("visited_states", 0)),
		int(solver.get("expanded_states", 0)),
		int(solver.get("dead_end_count", 0)),
		float(solver.get("branching_factor_avg", 0.0)),
		int(solver.get("runtime_ms", 0)),
	])
	return "\n".join(lines)


func _compose_difficulty_text(candidate: Dictionary) -> String:
	var difficulty: Variant = candidate.get("difficulty", {})
	if typeof(difficulty) != TYPE_DICTIONARY:
		return "DIFFICULTY: 0.00 · UNKNOWN"
	var lines: Array = ["DIFFICULTY: %.2f  ·  %s" % [
		float(difficulty.get("score", 0.0)),
		str(difficulty.get("bucket", "UNKNOWN")),
	]]
	var components: Variant = difficulty.get("components", {})
	if typeof(components) == TYPE_DICTIONARY:
		var source: Dictionary = components
		for key: Variant in source.keys():
			lines.append("  %s: %.2f" % [key, float(source[key])])
	return "\n".join(lines)


func _compose_dedupe_text(candidate: Dictionary) -> String:
	var dedupe: Variant = candidate.get("dedupe", {})
	if typeof(dedupe) != TYPE_DICTIONARY:
		return "DEDUPE: unique"
	if bool(dedupe.get("duplicate", false)):
		return "DEDUPE: DUPLICATE of %s (fp %s)" % [dedupe.get("of", ""), dedupe.get("fingerprint", "")]
	return "DEDUPE: unique (fp %s)" % dedupe.get("fingerprint", "")


func _compose_decision_text(candidate: Dictionary) -> String:
	var decision: Variant = candidate.get("decision", {})
	if typeof(decision) != TYPE_DICTIONARY:
		return "DECISION: (none)"
	var status: String = str(decision.get("status", ""))
	if status == "":
		status = "(none)"
	var lines: Array = ["DECISION: %s" % status]
	var reasons: Variant = decision.get("reasons", [])
	if typeof(reasons) == TYPE_ARRAY and not (reasons as Array).is_empty():
		var parts: Array = []
		for reason: Variant in reasons:
			parts.append(str(reason))
		lines.append("  reasons: %s" % ", ".join(parts))
	return "\n".join(lines)


func _compose_batch_text() -> String:
	var counts: Dictionary = _model.batch_counts()
	var lines: Array = ["BATCH:"]
	lines.append("  generated %d  invalid %d  unsolvable %d  duplicates %d  accepted %d" % [
		int(counts.get("generated", 0)),
		int(counts.get("invalid", 0)),
		int(counts.get("unsolvable", 0)),
		int(counts.get("duplicates", 0)),
		int(counts.get("accepted", 0)),
	])
	var buckets: Dictionary = _model.histogram()
	var max_count := 1
	for key: Variant in buckets.keys():
		max_count = maxi(max_count, int(buckets[key]))
	for bucket: String in Contract.BUCKETS:
		var count: int = int(buckets.get(bucket, 0))
		var bar_length: int = int(round(float(count) / float(max_count) * 20.0))
		lines.append("  %-6s %5d  %s" % [bucket, count, "|".repeat(maxi(bar_length, 0))])
	return "\n".join(lines)


func _refresh_batch_text() -> void:
	if _view != null:
		_view.set_batch_text(_compose_batch_text())


func _refresh_controls() -> void:
	if _bucket_button == null or _decision_button == null:
		return
	var bucket: String = _model.filter_bucket if not _model.filter_bucket.is_empty() else "ALL"
	var decision: String = _model.filter_decision if not _model.filter_decision.is_empty() else "ALL"
	_bucket_button.text = "BUCKET: %s" % bucket
	_decision_button.text = "DECISION: %s" % decision
	var has_candidates: bool = _model.filtered_count() > 0
	_prev_button.disabled = not has_candidates or _position <= 0
	_next_button.disabled = not has_candidates or _position + 1 >= _model.filtered_count()


func _refresh_status_text() -> void:
	if _status_label == null:
		return
	if _model.filtered_count() == 0:
		_status_label.text = "no candidates match the filter"
		return
	var candidate: Dictionary = current_candidate()
	var status: String = str(candidate.get("decision", {}).get("status", ""))
	if status == "":
		status = "(no decision)"
	_status_label.text = "%s  ·  solver %s  ·  %s" % [
		candidate.get("candidate_id", ""),
		str(candidate.get("solver", {}).get("status", "UNKNOWN")),
		status,
	]


func _apply_enabled() -> void:
	visible = debug_enabled
	for button: Button in [_prev_button, _next_button, _bucket_button, _decision_button, _close_button]:
		if button != null:
			button.disabled = not debug_enabled


func _make_button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	_controls.add_child(button)
	return button


func _on_prev_pressed() -> void:
	previous_candidate()


func _on_next_pressed() -> void:
	next_candidate()


func _on_bucket_pressed() -> void:
	cycle_bucket_filter()


func _on_decision_pressed() -> void:
	cycle_decision_filter()


func _on_close_pressed() -> void:
	closed.emit()
