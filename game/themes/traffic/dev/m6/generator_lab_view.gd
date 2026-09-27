extends Control
## DEV-ONLY M6 Generator Lab visual view (AGENT-2).
##
## Read-only visualization of plain supplied data. It composes the existing
## Traffic board renderer with the M5 debug path overlay and a stack of plain
## text panels (info / candidate list / generation / validation / solver /
## difficulty / dedupe / decision / batch). It never imports or reads
## generator/solver/levels/core/puzzle/integration code.

const BoardView := preload("res://themes/traffic/components/board_view.gd")
const PathOverlay := preload("res://themes/traffic/dev/m5/level_lab_path_overlay.gd")

const MARGIN := 24.0
const SPACING := 12.0
const INFO_FONT_SIZE := 30
const LABEL_FONT_SIZE := 20
const MIN_PANEL_WIDTH := 300.0
const MAX_PANEL_WIDTH := 660.0
const FALLBACK_VIEWPORT := Vector2(1080.0, 1920.0)

const TEXT_INFO := Color(0.95, 0.96, 0.98, 1.0)
const TEXT_MUTED := Color(0.74, 0.78, 0.84, 1.0)

var _built := false
var _paths: Array = []

var _info_label: Label = null
var _candidate_list_label: Label = null
var _board_view: BoardView = null
var _path_overlay: PathOverlay = null
var _panel_root: Control = null
var _generation_label: Label = null
var _validation_label: Label = null
var _solver_label: Label = null
var _difficulty_label: Label = null
var _dedupe_label: Label = null
var _decision_label: Label = null
var _batch_label: Label = null


func _ready() -> void:
	build()
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = FALLBACK_VIEWPORT
	layout_for(viewport_size)


func build() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_info_label = _make_label("InfoLabel", INFO_FONT_SIZE, TEXT_INFO)
	add_child(_info_label)

	_candidate_list_label = _make_label("CandidateListLabel", LABEL_FONT_SIZE, TEXT_INFO)
	add_child(_candidate_list_label)

	_board_view = BoardView.new()
	_board_view.name = "BoardView"
	add_child(_board_view)

	_path_overlay = PathOverlay.new()
	_path_overlay.name = "PathOverlay"
	_path_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_path_overlay)

	_panel_root = Control.new()
	_panel_root.name = "TextPanel"
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	_generation_label = _make_label("GenerationLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_validation_label = _make_label("ValidationLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_solver_label = _make_label("SolverLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_difficulty_label = _make_label("DifficultyLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_dedupe_label = _make_label("DedupeLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_decision_label = _make_label("DecisionLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	_batch_label = _make_label("BatchLabel", LABEL_FONT_SIZE, TEXT_MUTED)
	for label: Label in _panel_labels():
		_panel_root.add_child(label)

	_layout_panel_labels()


func set_board(board_data) -> void:
	_ensure_built()
	_board_view.set_board_data(board_data)
	_refresh_overlay_layout()


func set_paths(paths: Array) -> void:
	_ensure_built()
	_paths = paths
	_refresh_overlay_layout()


func set_info_text(text: String) -> void:
	_ensure_built()
	_info_label.text = text


func set_candidate_list_text(text: String) -> void:
	_ensure_built()
	_candidate_list_label.text = text


func set_generation_text(text: String) -> void:
	_ensure_built()
	_generation_label.text = text


func set_validation_text(text: String) -> void:
	_ensure_built()
	_validation_label.text = text


func set_solver_text(text: String) -> void:
	_ensure_built()
	_solver_label.text = text


func set_difficulty_text(text: String) -> void:
	_ensure_built()
	_difficulty_label.text = text


func set_dedupe_text(text: String) -> void:
	_ensure_built()
	_dedupe_label.text = text


func set_decision_text(text: String) -> void:
	_ensure_built()
	_decision_label.text = text


func set_batch_text(text: String) -> void:
	_ensure_built()
	_batch_label.text = text


func clear() -> void:
	_ensure_built()
	_paths = []
	_board_view.set_board_data(null)
	_path_overlay.clear_paths()
	_info_label.text = ""
	_candidate_list_label.text = ""
	_generation_label.text = ""
	_validation_label.text = ""
	_solver_label.text = ""
	_difficulty_label.text = ""
	_dedupe_label.text = ""
	_decision_label.text = ""
	_batch_label.text = ""
	_refresh_overlay_layout()


func layout_for(viewport: Vector2) -> void:
	_ensure_built()
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	var info_height: float = clampf(viewport.y * 0.04, 40.0, 76.0)
	var list_height: float = clampf(viewport.y * 0.035, 34.0, 64.0)
	_info_label.position = Vector2(MARGIN, MARGIN)
	_info_label.size = Vector2(maxf(viewport.x - MARGIN * 2.0, 1.0), info_height)
	_candidate_list_label.position = Vector2(MARGIN, MARGIN + info_height)
	_candidate_list_label.size = Vector2(maxf(viewport.x - MARGIN * 2.0, 1.0), list_height)

	var content_top: float = MARGIN + info_height + list_height + SPACING
	var content_bottom: float = viewport.y - MARGIN
	var content_height: float = maxf(content_bottom - content_top, 1.0)
	var wide: bool = viewport.x > viewport.y

	if wide:
		var panel_width: float = clampf(viewport.x * 0.32, MIN_PANEL_WIDTH, MAX_PANEL_WIDTH)
		var board_width: float = maxf(viewport.x - panel_width - MARGIN * 3.0, 1.0)
		var board_origin: Vector2 = Vector2(MARGIN, content_top)
		_board_view.layout_for_size(Vector2(board_width, content_height), MARGIN, board_width)
		_board_view.position = board_origin + _board_view.position
		_panel_root.position = Vector2(viewport.x - MARGIN - panel_width, content_top)
		_panel_root.size = Vector2(panel_width, content_height)
	else:
		var board_height: float = maxf(content_height * 0.55, 1.0)
		var board_origin: Vector2 = Vector2(MARGIN, content_top)
		var board_width: float = maxf(viewport.x - MARGIN * 2.0, 1.0)
		_board_view.layout_for_size(Vector2(board_width, board_height), MARGIN, board_width)
		_board_view.position = board_origin + _board_view.position
		var panel_top: float = _board_view.position.y + _board_view.size.y + SPACING
		_panel_root.position = Vector2(MARGIN, panel_top)
		_panel_root.size = Vector2(board_width, maxf(content_bottom - panel_top, 1.0))

	_layout_panel_labels()
	_refresh_overlay_layout()


func board_rect() -> Rect2:
	_ensure_built()
	if _board_view == null:
		return Rect2()
	return Rect2(_board_view.position, _board_view.size)


func board_view() -> Node:
	_ensure_built()
	return _board_view


func path_overlay() -> Node:
	_ensure_built()
	return _path_overlay


func info_text() -> String:
	_ensure_built()
	return _info_label.text


func candidate_list_text() -> String:
	_ensure_built()
	return _candidate_list_label.text


func generation_text() -> String:
	_ensure_built()
	return _generation_label.text


func validation_text() -> String:
	_ensure_built()
	return _validation_label.text


func solver_text() -> String:
	_ensure_built()
	return _solver_label.text


func difficulty_text() -> String:
	_ensure_built()
	return _difficulty_label.text


func dedupe_text() -> String:
	_ensure_built()
	return _dedupe_label.text


func decision_text() -> String:
	_ensure_built()
	return _decision_label.text


func batch_text() -> String:
	_ensure_built()
	return _batch_label.text


func _ensure_built() -> void:
	if not _built:
		build()


func _make_label(label_name: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_labels() -> Array[Label]:
	return [
		_generation_label,
		_validation_label,
		_solver_label,
		_difficulty_label,
		_dedupe_label,
		_decision_label,
		_batch_label,
	]


func _layout_panel_labels() -> void:
	if _panel_root == null:
		return
	var labels: Array[Label] = _panel_labels()
	var count: int = labels.size()
	if count == 0:
		return
	var slot: float = _panel_root.size.y / float(count)
	var cursor: float = 0.0
	for label: Label in labels:
		label.position = Vector2(0.0, cursor)
		label.size = Vector2(_panel_root.size.x, maxf(slot - 4.0, 1.0))
		cursor += slot


func _refresh_overlay_layout() -> void:
	if _board_view == null or _path_overlay == null:
		return
	_path_overlay.position = _board_view.position
	_path_overlay.size = _board_view.size
	_path_overlay.set_board_origin(Vector2.ZERO)
	_path_overlay.set_paths(_paths, _board_view.cell_size)
