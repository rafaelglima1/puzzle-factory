extends RefCounted
## M5 Level Lab model: holds normalized plain data and projects it onto Traffic
## presentation DTOs for debug rendering.
##
## It consumes only the flat contract shapes from `level_lab_contract.gd` and
## the presentation view-data objects. It never mutates gameplay and never
## imports simulation code: this is a read-only presentation projection.

const Contract := preload("res://themes/traffic/dev/m5/level_lab_contract.gd")
const BoardData := preload("res://themes/traffic/model_board_view_data.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const DestinationData := preload("res://themes/traffic/model_destination_view_data.gd")

var preview: Dictionary = {}
var validation: Dictionary = {}
var solver: Dictionary = {}


func _init() -> void:
	clear()


## Resets every held shape to its normalized empty default.
func clear() -> void:
	preview = Contract.normalize_preview({})
	validation = Contract.normalize_validation({})
	solver = Contract.normalize_solver({})


## Loads a preview and resets validation/solver to their defaults.
func load_preview(raw: Dictionary) -> void:
	preview = Contract.normalize_preview(raw)
	validation = Contract.normalize_validation({})
	solver = Contract.normalize_solver({})


func set_validation(raw: Variant) -> void:
	validation = Contract.normalize_validation(raw)


func set_solver(raw: Variant) -> void:
	solver = Contract.normalize_solver(raw)


## Builds a presentation-only board DTO from the held preview data.
func build_board_data() -> BoardData:
	var width: int = int(preview.get("board_width", 0))
	var height: int = int(preview.get("board_height", 0))
	var board: BoardData = BoardData.new(width, height)

	var obstacles: Array = _as_array(preview.get("obstacles", []))
	for obstacle: Variant in obstacles:
		if typeof(obstacle) == TYPE_VECTOR2I:
			var obstacle_cell: Vector2i = obstacle
			board.obstacles.append(obstacle_cell)

	for entity: Dictionary in entities():
		var entity_id: StringName = entity.get("id", &"")
		var entity_type: StringName = entity.get("entity_type", &"")
		var color_key: StringName = entity.get("color_key", &"")
		var entity_view: EntityData = EntityData.new(entity_id, entity_type, color_key)
		entity_view.cell = _as_cell(entity.get("cell", Vector2i.ZERO))
		entity_view.footprint = _as_footprint(entity.get("footprint", Vector2i.ONE))
		entity_view.orientation = float(entity.get("orientation", 0.0))
		board.add_entity(entity_view)

	for destination: Dictionary in destinations():
		var destination_id: StringName = destination.get("id", &"")
		var destination_view: DestinationData = DestinationData.new(destination_id)
		destination_view.cell = _as_cell(destination.get("cell", Vector2i.ZERO))
		destination_view.footprint = _as_footprint(destination.get("footprint", Vector2i.ONE))
		destination_view.capacity = int(destination.get("capacity", 0))
		destination_view.occupancy = int(destination.get("occupancy", 0))
		destination_view.state = destination.get("state", &"")
		destination_view.accepted_color_keys = _keys_of(
			destination.get("accepted_color_keys", [])
		)
		destination_view.queue_color_keys = _keys_of(destination.get("queue_color_keys", []))
		board.add_destination(destination_view)

	return board


func entities() -> Array:
	return _as_array(preview.get("entities", []))


func destinations() -> Array:
	return _as_array(preview.get("destinations", []))


## Returns normalized paths, synthesizing one per entity that declares a path
## but has no explicit paths entry of its own.
func paths() -> Array:
	var result: Array = []
	var covered: Dictionary = {}
	var listed: Array = _as_array(preview.get("paths", []))
	for entry: Variant in listed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var path_entry: Dictionary = entry
		result.append(path_entry)
		var listed_entity_id: StringName = path_entry.get("entity_id", &"")
		covered[listed_entity_id] = true

	for entity: Dictionary in entities():
		var entity_id: StringName = entity.get("id", &"")
		if covered.has(entity_id):
			continue
		var cells: Array[Vector2i] = _typed_cells(entity.get("path", []))
		if cells.is_empty():
			continue
		result.append({"id": entity_id, "cells": cells, "entity_id": entity_id})
	return result


func entity_count() -> int:
	return entities().size()


func destination_count() -> int:
	return destinations().size()


func path_count() -> int:
	return paths().size()


func objective_count() -> int:
	return _as_array(preview.get("objectives", [])).size()


func staging_slots() -> int:
	return int(preview.get("staging_slots", 0))


func queue_color_keys(destination_id: StringName) -> Array[StringName]:
	for destination: Dictionary in destinations():
		var id: StringName = destination.get("id", &"")
		if id == destination_id:
			return _keys_of(destination.get("queue_color_keys", []))
	var empty: Array[StringName] = []
	return empty


func entity_path(entity_id: StringName) -> Array[Vector2i]:
	for entity: Dictionary in entities():
		var id: StringName = entity.get("id", &"")
		if id == entity_id:
			return _typed_cells(entity.get("path", []))
	var empty: Array[Vector2i] = []
	return empty


func validation_status() -> String:
	return str(validation.get("status", "VALID"))


func validation_error_count() -> int:
	return validation_errors().size()


func validation_errors() -> Array:
	return _as_array(validation.get("errors", []))


func solver_status() -> String:
	return str(solver.get("status", "UNKNOWN"))


func solution_commands() -> Array:
	return _as_array(solver.get("solution_commands", []))


func level_id() -> String:
	return str(preview.get("level_id", ""))


func board_size() -> Vector2i:
	return Vector2i(int(preview.get("board_width", 0)), int(preview.get("board_height", 0)))


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		var array_value: Array = value
		return array_value
	return []


func _as_cell(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO


func _as_footprint(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		var footprint: Vector2i = value
		return Vector2i(maxi(1, footprint.x), maxi(1, footprint.y))
	return Vector2i.ONE


func _typed_cells(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return cells
	for entry: Variant in value:
		if typeof(entry) == TYPE_VECTOR2I:
			var cell: Vector2i = entry
			cells.append(cell)
	return cells


func _keys_of(value: Variant) -> Array[StringName]:
	var keys: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return keys
	for entry: Variant in value:
		var entry_type: int = typeof(entry)
		if entry_type == TYPE_STRING or entry_type == TYPE_STRING_NAME:
			keys.append(StringName(str(entry)))
		elif entry_type == TYPE_DICTIONARY:
			var source: Dictionary = entry
			keys.append(StringName(str(source.get("id", ""))))
	return keys
