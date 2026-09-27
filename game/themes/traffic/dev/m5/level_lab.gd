extends Control
## DEV-ONLY M5 Level Lab (AGENT-2): read-only content inspection.
##
## Developers use it to eyeball authored levels — geometry, entities, paths,
## destinations, queues, staging, objectives — plus supplied validation findings
## and solver results, and to step/play a supplied solution command sequence.
##
## Boundary rules:
## - It consumes ONLY the plain contract shapes (level_lab_contract.gd) or
##   presentation DTOs. It never imports core/puzzle/solver/levels/persistence.
## - It never validates, solves, generates or mutates gameplay. It renders what
##   the caller supplies and forwards commands to an optional driver.
## - It is debug-gated: `debug_enabled` defaults to OS.is_debug_build(), and it
##   is only referenced by a dev scene, never production startup.

const ModelScript := preload("res://themes/traffic/dev/m5/level_lab_model.gd")
const ViewScript := preload("res://themes/traffic/dev/m5/level_lab_view.gd")
const PlaybackScript := preload("res://themes/traffic/dev/m5/solution_playback_controller.gd")
const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")

signal closed
signal level_changed(index: int)
signal solution_step(step: int, count: int)

## Debug gate. Release builds must not expose the lab through production
## navigation (the scene is never wired into the main menu).
var debug_enabled: bool = OS.is_debug_build()

var _model: ModelScript = null
var _view: ViewScript = null
var _playback: PlaybackScript = null
var _palette: PaletteScript = PaletteScript.new()

var _levels: Array = []
var _index := 0
var _built := false

var _controls: Control = null
var _prev_button: Button = null
var _next_button: Button = null
var _play_button: Button = null
var _step_button: Button = null
var _reset_button: Button = null
var _close_button: Button = null
var _status_label: Label = null
var _viewport := Vector2(1080.0, 1920.0)


func _ready() -> void:
	build()
	layout_for(get_viewport_rect().size if get_viewport_rect().size.x > 0.0 else _viewport)


func build() -> void:
	if _built:
		return
	_built = true

	# The lab is sized explicitly through `layout_for()`; normalizing anchors
	# avoids fighting the full-rect anchors of the dev scene root.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	_model = ModelScript.new()
	_playback = PlaybackScript.new()

	_view = ViewScript.new()
	_view.name = "LevelLabView"
	add_child(_view)
	_view.build()

	_controls = Control.new()
	_controls.name = "Controls"
	add_child(_controls)

	_prev_button = _make_button("PrevButton", "PREV")
	_next_button = _make_button("NextButton", "NEXT")
	_play_button = _make_button("PlayButton", "PLAY")
	_step_button = _make_button("StepButton", "STEP")
	_reset_button = _make_button("ResetButton", "RESET")
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
	_play_button.pressed.connect(_on_play_pressed)
	_step_button.pressed.connect(_on_step_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_playback.step_changed.connect(_on_playback_step_changed)

	_apply_enabled()


# --- Public API -------------------------------------------------------------

func is_enabled() -> bool:
	return debug_enabled


## Shows a single preview (clears held validation/solver).
func show_level(preview: Dictionary) -> bool:
	return show_levels([preview], 0)


## Shows a list of previews and selects `index`. Returns false when the debug
## gate is off or the list is empty.
func show_levels(levels: Array, index: int = 0) -> bool:
	_ensure_built()
	if not debug_enabled:
		return false
	if levels.is_empty():
		return false
	_levels = levels
	_index = clampi(index, 0, levels.size() - 1)
	_apply_current()
	return true


func next_level() -> bool:
	_ensure_built()
	if _index + 1 >= _levels.size():
		return false
	_index += 1
	_apply_current()
	return true


func previous_level() -> bool:
	_ensure_built()
	if _index <= 0:
		return false
	_index -= 1
	_apply_current()
	return true


func set_validation_result(raw: Variant) -> void:
	_ensure_built()
	_model.set_validation(raw)
	_refresh_validation_text()


func set_solver_result(raw: Variant) -> void:
	_ensure_built()
	_model.set_solver(raw)
	_refresh_solver_text()
	_view.set_commands_text(_compose_commands_text())
	_playback.set_commands(_model.solution_commands())
	_refresh_status_text()


func set_playback_driver(driver: Variant) -> void:
	_ensure_built()
	_playback.set_driver(driver)


func play_solution() -> int:
	_ensure_built()
	return _playback.play_all()


func step_solution() -> bool:
	_ensure_built()
	return _playback.step_once()


func reset_preview() -> void:
	_ensure_built()
	_playback.reset()
	_refresh_status_text()


## Re-renders the CURRENT level's board/runtime debug data from an updated
## preview WITHOUT resetting solver metrics, the command list or the current
## playback step. Used by the M5 cross-integration layer after a playback step so
## the board reflects the real authoritative state. It never restarts playback
## and never decides gameplay; it only redraws supplied plain data.
func refresh_runtime_preview(preview: Dictionary) -> void:
	_ensure_built()
	if preview.is_empty():
		return
	if _levels.is_empty():
		return
	var validation: Variant = _model.validation
	var solver: Variant = _model.solver
	var entry: Dictionary = preview.duplicate(true)
	_levels[_index] = entry
	_model.load_preview(entry)
	# Preserve solver/validation/commands/step: only the runtime board changes.
	_model.set_validation(validation)
	_model.set_solver(solver)
	_view.set_board(_model.build_board_data())
	_view.set_paths(_paths_for_view())
	_view.set_info_text(_compose_info_text())
	_refresh_validation_text()
	_refresh_solver_text()
	_view.set_queues_text(_compose_queues_text())
	_view.set_staging_text(_compose_staging_text())
	_view.set_objectives_text(_compose_objectives_text())
	_refresh_status_text()


func current_index() -> int:
	return _index


func level_count() -> int:
	return _levels.size()


func model() -> ModelScript:
	_ensure_built()
	return _model


func view() -> ViewScript:
	_ensure_built()
	return _view


func playback() -> PlaybackScript:
	_ensure_built()
	return _playback


func validation_text() -> String:
	return _view.validation_text() if _view != null else ""


func solver_text() -> String:
	return _view.solver_text() if _view != null else ""


func commands_text() -> String:
	return _view.commands_text() if _view != null else ""


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
	var button_width := 140.0
	var button_height := 64.0
	var cursor := margin
	for button: Button in [_prev_button, _next_button, _play_button, _step_button, _reset_button]:
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
	if _levels.is_empty():
		_view.clear()
		_playback.set_commands([])
		_refresh_status_text()
		return
	var raw_variant: Variant = _levels[_index]
	var raw: Dictionary = raw_variant if raw_variant is Dictionary else {}

	# A fresh level starts from clean temporary state (no stale solver/playback).
	_model.load_preview(raw)
	if raw.has("validation"):
		_model.set_validation(raw.get("validation"))
	if raw.has("solver"):
		_model.set_solver(raw.get("solver"))

	_view.set_board(_model.build_board_data())
	_view.set_paths(_paths_for_view())
	_view.set_info_text(_compose_info_text())
	_refresh_validation_text()
	_refresh_solver_text()
	_view.set_commands_text(_compose_commands_text())
	_view.set_queues_text(_compose_queues_text())
	_view.set_staging_text(_compose_staging_text())
	_view.set_objectives_text(_compose_objectives_text())

	_playback.set_commands(_model.solution_commands())
	_refresh_status_text()
	level_changed.emit(_index)


func _paths_for_view() -> Array:
	var result: Array = []
	for path_variant: Variant in _model.paths():
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
			"color": _path_color(entity_id),
		})
	return result


func _path_color(entity_id: StringName) -> Color:
	for entity_variant: Variant in _model.entities():
		if entity_variant is Dictionary:
			var entity: Dictionary = entity_variant
			if entity.get("id", &"") == entity_id:
				return _palette.color_for(entity.get("color_key", &""))
	return _palette.color_for(&"")


func _compose_info_text() -> String:
	var size_cells: Vector2i = _model.board_size()
	return "%s  ·  schema v%d  ·  rev %d  ·  board %dx%d  ·  entities %d  ·  destinations %d  ·  paths %d" % [
		_model.level_id(),
		int(_model.preview.get("schema_version", 0)),
		int(_model.preview.get("revision", 0)),
		size_cells.x,
		size_cells.y,
		_model.entity_count(),
		_model.destination_count(),
		_model.path_count(),
	]


func _refresh_validation_text() -> void:
	var lines: Array = []
	if _model.validation_status() == "VALID":
		lines.append("VALIDATION: VALID")
	else:
		lines.append("VALIDATION: INVALID (%d)" % _model.validation_error_count())
	for error_variant: Variant in _model.validation_errors():
		if error_variant is Dictionary:
			var error: Dictionary = error_variant
			var code: String = str(error.get("code", ""))
			var path: String = str(error.get("path", ""))
			var message: String = str(error.get("message", ""))
			var location: String = " @%s" % path if not path.is_empty() else ""
			lines.append("  - %s%s: %s" % [code, location, message])
	_view.set_validation_text("\n".join(lines))


func _refresh_solver_text() -> void:
	var lines: Array = []
	lines.append("SOLVER: %s" % _model.solver_status())
	lines.append(
		"  depth %d  visited %d  expanded %d  dead-ends %d  branch %.2f  %d ms" % [
			int(_model.solver.get("solution_depth", 0)),
			int(_model.solver.get("visited_states", 0)),
			int(_model.solver.get("expanded_states", 0)),
			int(_model.solver.get("dead_end_count", 0)),
			float(_model.solver.get("branching_factor_avg", 0.0)),
			int(_model.solver.get("runtime_ms", 0)),
		]
	)
	_view.set_solver_text("\n".join(lines))


func _compose_commands_text() -> String:
	var commands: Array = _model.solution_commands()
	var lines: Array = ["SOLUTION (%d steps):" % commands.size()]
	var number := 1
	for command_variant: Variant in commands:
		if command_variant is Dictionary:
			var command: Dictionary = command_variant
			lines.append("  %d. %s %s" % [number, command.get("type", ""), command.get("entity_id", "")])
			number += 1
	return "\n".join(lines)


func _compose_queues_text() -> String:
	var lines: Array = ["QUEUES:"]
	for destination_variant: Variant in _model.destinations():
		if not (destination_variant is Dictionary):
			continue
		var destination: Dictionary = destination_variant
		var destination_id: StringName = destination.get("id", &"")
		var keys: Array[StringName] = _model.queue_color_keys(destination_id)
		var parts: Array = []
		var order := 1
		for key: StringName in keys:
			parts.append("%d->%s(%s)" % [order, key, _palette.symbol_for(key)])
			order += 1
		lines.append("  %s: %s" % [destination_id, " ".join(parts) if not parts.is_empty() else "(empty)"])
	return "\n".join(lines)


func _compose_staging_text() -> String:
	return "STAGING: %d slots" % _model.staging_slots()


func _compose_objectives_text() -> String:
	var lines: Array = ["OBJECTIVES (%d):" % _model.objective_count()]
	for objective_variant: Variant in _model.preview.get("objectives", []):
		if objective_variant is Dictionary:
			var objective: Dictionary = objective_variant
			var mandatory: String = "mandatory" if bool(objective.get("mandatory", false)) else "optional"
			lines.append("  %s: %s (%s)" % [objective.get("id", ""), objective.get("objective_type", ""), mandatory])
	return "\n".join(lines)


func _refresh_status_text() -> void:
	if _status_label == null:
		return
	var count: int = _playback.command_count()
	var step: int = _playback.step()
	var suffix: String = "complete" if _playback.is_complete() else "ready"
	_status_label.text = "solution step %d / %d (%s)" % [step, count, suffix]
	solution_step.emit(step, count)


func _apply_enabled() -> void:
	visible = debug_enabled
	for button: Button in [_prev_button, _next_button, _play_button, _step_button, _reset_button, _close_button]:
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
	previous_level()


func _on_next_pressed() -> void:
	next_level()


func _on_play_pressed() -> void:
	play_solution()


func _on_step_pressed() -> void:
	step_solution()


func _on_reset_pressed() -> void:
	reset_preview()


func _on_close_pressed() -> void:
	closed.emit()


func _on_playback_step_changed(_step: int) -> void:
	_refresh_status_text()
