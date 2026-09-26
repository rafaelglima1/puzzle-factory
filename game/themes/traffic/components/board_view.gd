extends Control
## Visual board/grid surface for the Traffic theme.
##
## Draws supplied dimensions + obstacles and places entity/destination views at
## supplied cells. It does NOT own logical occupancy: no cell state is
## computed, only rendered (blueprint §8.2, ADR-003). Dimensions are always
## supplied; the board has no fixed size.
##
## Incremental API (`add_or_update_entity`, `remove_entity`, `move_entity_to`,
## `set_entity_selected`, `set_entity_blocked`, `add_or_update_destination`,
## `set_destination_queue`) lets the presentation controller react to events
## without rebuilding the whole board.

const BoardData := preload("res://themes/traffic/model_board_view_data.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const DestinationData := preload("res://themes/traffic/model_destination_view_data.gd")
const EntityView := preload("res://themes/traffic/components/entity_view.gd")
const DestinationView := preload("res://themes/traffic/components/destination_view.gd")
const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const LayoutFit := preload("res://ui/layout_fit.gd")

const CELL_FILL_A := Color(0.16, 0.18, 0.22, 1.0)
const CELL_FILL_B := Color(0.185, 0.205, 0.25, 1.0)
const OBSTACLE_FILL := Color(0.31, 0.22, 0.18, 1.0)
const GRID_LINE := Color(0.26, 0.29, 0.34, 0.55)

const DEFAULT_CELL_SIZE := 64.0

var board_data: BoardData = null
var cell_size: float = DEFAULT_CELL_SIZE

var _palette: PaletteScript = PaletteScript.new()
var _entity_views: Dictionary = {}
var _destination_views: Dictionary = {}


func set_board_data(value: BoardData) -> void:
	board_data = value
	_rebuild()
	queue_redraw()


func get_board_data() -> BoardData:
	return board_data


func set_cell_size(px: float) -> void:
	cell_size = maxf(px, 1.0)
	_sync_positions()
	queue_redraw()


func entity_view_ids() -> Array:
	return _entity_views.keys()


func entity_view(id: StringName) -> Node2D:
	var view: Variant = _entity_views.get(id, null)
	if view is Node2D:
		return view
	return null


func destination_view(id: StringName) -> Node2D:
	var view: Variant = _destination_views.get(id, null)
	if view is Node2D:
		return view
	return null


func entity_view_count() -> int:
	return _entity_views.size()


func destination_view_count() -> int:
	return _destination_views.size()


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * cell_size, (float(cell.y) + 0.5) * cell_size)


## Adds or updates one entity view from supplied presentation data.
func add_or_update_entity(entity_data: EntityData) -> Node2D:
	var view: Node2D = entity_view(entity_data.id)
	if view == null:
		view = EntityView.new()
		view.name = "Entity_%s" % entity_data.id
		view.set_palette(_palette)
		add_child(view)
		_entity_views[entity_data.id] = view
	view.set_cell_size(cell_size)
	view.set_data(entity_data)
	view.position = cell_center(entity_data.cell)
	queue_redraw()
	return view


func remove_entity(id: StringName) -> bool:
	if not _entity_views.has(id):
		return false
	var view: Variant = _entity_views[id]
	_entity_views.erase(id)
	_remove_view(view)
	queue_redraw()
	return true


func set_entity_selected(id: StringName, on: bool) -> bool:
	var view: Node2D = entity_view(id)
	if view == null:
		return false
	view.set_selected(on)
	return true


func set_entity_blocked(id: StringName, on: bool) -> bool:
	var view: Node2D = entity_view(id)
	if view == null:
		return false
	view.set_blocked(on)
	return true


## Snaps an entity view to an authoritative cell (no legality implied).
func move_entity_to(id: StringName, cell: Vector2i) -> bool:
	var view: Node2D = entity_view(id)
	if view == null:
		return false
	var data: EntityData = view.get_data()
	if data != null:
		data.cell = cell
	view.position = cell_center(cell)
	queue_redraw()
	return true


func add_or_update_destination(destination_data: DestinationData) -> Node2D:
	var view: Node2D = destination_view(destination_data.id)
	if view == null:
		view = DestinationView.new()
		view.name = "Destination_%s" % destination_data.id
		view.set_palette(_palette)
		add_child(view)
		_destination_views[destination_data.id] = view
	view.set_cell_size(cell_size)
	view.set_data(destination_data)
	view.position = cell_center(destination_data.cell)
	queue_redraw()
	return view


func remove_destination(id: StringName) -> bool:
	if not _destination_views.has(id):
		return false
	var view: Variant = _destination_views[id]
	_destination_views.erase(id)
	_remove_view(view)
	queue_redraw()
	return true


func set_destination_queue(id: StringName, color_keys: Array) -> bool:
	var view: Node2D = destination_view(id)
	if view == null:
		return false
	view.set_queue(color_keys)
	return true


## Fits the board into `available`, keeping the cell aspect ratio, centring it
## and optionally capping width for tablets. Returns the board rect.
func layout_for_size(available: Vector2, margin: float = 0.0, max_width: float = 0.0) -> Rect2:
	if board_data == null:
		return Rect2()
	var rect := LayoutFit.fit_board_rect(available, board_data.cells(), margin, max_width)
	cell_size = rect.size.x / maxf(float(board_data.width), 1.0)
	position = rect.position
	size = rect.size
	_sync_positions()
	return rect


func _rebuild() -> void:
	_clear()
	if board_data == null:
		return
	for entity: Variant in board_data.entities:
		add_or_update_entity(entity)
	for destination: Variant in board_data.destinations:
		add_or_update_destination(destination)
	_sync_positions()


func _clear() -> void:
	for view: Variant in _entity_views.values():
		_remove_view(view)
	for view: Variant in _destination_views.values():
		_remove_view(view)
	_entity_views.clear()
	_destination_views.clear()


func _remove_view(view: Variant) -> void:
	if view != null and is_instance_valid(view):
		if view.get_parent() == self:
			remove_child(view)
		view.free()


func _sync_positions() -> void:
	for id: Variant in _entity_views.keys():
		var view = _entity_views[id]
		view.set_cell_size(cell_size)
		view.position = cell_center(view.get_data().cell)
	for id: Variant in _destination_views.keys():
		var view = _destination_views[id]
		view.set_cell_size(cell_size)
		view.position = cell_center(view.get_data().cell)


func _draw() -> void:
	if board_data == null:
		return
	for y in board_data.height:
		for x in board_data.width:
			var cell := Vector2i(x, y)
			var fill := OBSTACLE_FILL if board_data.obstacles.has(cell) else (CELL_FILL_A if (x + y) % 2 == 0 else CELL_FILL_B)
			draw_rect(Rect2(Vector2(float(x), float(y)) * cell_size, Vector2(cell_size, cell_size)), fill)
			draw_rect(Rect2(Vector2(float(x), float(y)) * cell_size, Vector2(cell_size, cell_size)), GRID_LINE, false, 1.0)
