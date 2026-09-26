class_name LogicalPath
extends RefCounted
## Deterministic logical movement path (blueprint: movement / waypoints).
##
## A path is an ordered list of board cells starting at the entity's current
## cell and ending at its travel target. Paths are data: they are validated
## before use and never computed by physics or general pathfinding.
##
## Validation rules (documented M2 contract):
## - must contain at least two cells (origin + at least one travel step);
## - every cell must be inside the board;
## - consecutive cells must be 4-neighbour adjacent (no teleporting);
## - a cell must not repeat (no loops).

var id: StringName = &""
var cells: Array[GridPosition] = []


func _init(p_id: StringName = &"", p_cells: Array[GridPosition] = []) -> void:
	id = p_id
	cells = p_cells


func length() -> int:
	return cells.size()


func origin() -> GridPosition:
	if cells.is_empty():
		return null
	return cells[0]


func target() -> GridPosition:
	if cells.is_empty():
		return null
	return cells[cells.size() - 1]


func contains_cell(position: GridPosition) -> bool:
	for cell in cells:
		if cell.equals(position):
			return true
	return false


## Returns validation errors; empty result means the path is usable.
func validate(dimensions: BoardDimensions) -> PackedStringArray:
	var errors := PackedStringArray()
	if cells.size() < 2:
		errors.append("path_too_short")
		return errors
	if dimensions == null or not dimensions.is_valid():
		errors.append("board_not_ready")
		return errors
	var seen := {}
	for index in cells.size():
		var cell := cells[index]
		if not dimensions.contains(cell):
			errors.append("out_of_bounds:%d" % index)
			continue
		var key := dimensions.index_of(cell)
		if seen.has(key):
			errors.append("duplicate_cell:%d" % index)
		seen[key] = true
		if index == 0:
			continue
		var previous := cells[index - 1]
		var distance := absi(cell.x - previous.x) + absi(cell.y - previous.y)
		if distance != 1:
			errors.append("non_contiguous:%d" % index)
	return errors


func is_valid(dimensions: BoardDimensions) -> bool:
	return validate(dimensions).is_empty()


## Entity ids occupying path cells, excluding [param ignored_id] (the mover).
## Sorted and unique for deterministic results.
func blockers_on(board: Board, ignored_id: StringName = &"") -> Array[StringName]:
	var seen := {}
	if board == null:
		return []
	for cell in cells:
		if not board.dimensions.contains(cell):
			continue
		var occupant := board.occupant_at(cell)
		if occupant != &"" and occupant != ignored_id:
			seen[occupant] = true
	var blockers: Array[StringName] = []
	var keys: Array = seen.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for entity_id in keys:
		blockers.append(entity_id)
	return blockers


## First cell of the path blocked by another entity, or null when clear.
func first_blocked_cell(board: Board, ignored_id: StringName = &"") -> GridPosition:
	if board == null:
		return null
	for cell in cells:
		if not board.dimensions.contains(cell):
			continue
		var occupant := board.occupant_at(cell)
		if occupant != &"" and occupant != ignored_id:
			return cell
	return null


func cell_dictionaries() -> Array:
	var output: Array = []
	for cell in cells:
		output.append(cell.to_dictionary())
	return output


func logical_equals(other: LogicalPath) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"cells": cell_dictionaries(),
	}


static func from_dictionary(data: Dictionary) -> LogicalPath:
	var path := LogicalPath.new(StringName(str(data.get("id", ""))))
	var cells_data: Variant = data.get("cells", [])
	if typeof(cells_data) == TYPE_ARRAY:
		for cell in cells_data:
			path.cells.append(GridPosition.from_dictionary(cell))
	return path
