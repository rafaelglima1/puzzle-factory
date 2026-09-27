class_name LevelDefinition
extends RefCounted
## Product-free level definition value object (M5 schema v1).
##
## The internal representation is snake_case DTOs, while [method to_dictionary]
## emits the external camelCase contract exactly so a parsed level round-trips
## to the same logical payload. [method from_dictionary] is structural only: it
## never validates semantics, so callers run [LevelValidator] afterwards.

const SCHEMA_VERSION := 1


class PathDto:
	var id: StringName = &""
	var cells: Array[GridPosition] = []

	func origin() -> GridPosition:
		if cells.is_empty():
			return null
		return cells[0]

	func target() -> GridPosition:
		if cells.is_empty():
			return null
		return cells[cells.size() - 1]

	func to_dictionary() -> Dictionary:
		var cell_data: Array = []
		for cell in cells:
			cell_data.append(cell.to_dictionary())
		return {"id": String(id), "cells": cell_data}

	static func from_dictionary(data: Dictionary) -> PathDto:
		var dto := PathDto.new()
		dto.id = StringName(str(data.get("id", "")))
		var raw: Variant = data.get("cells", [])
		if typeof(raw) == TYPE_ARRAY:
			for entry in raw:
				if typeof(entry) == TYPE_DICTIONARY:
					dto.cells.append(GridPosition.from_dictionary(entry))
		return dto


class EntityDto:
	var id: StringName = &""
	var entity_type: StringName = &""
	var color_key: StringName = &""
	var capacity: int = 0
	var position: GridPosition = null
	var footprint: Footprint = null
	var path_id: StringName = &""
	var destination_id: StringName = &""

	func to_dictionary() -> Dictionary:
		return {
			"id": String(id),
			"type": String(entity_type),
			"colorKey": String(color_key),
			"capacity": capacity,
			"position": position.to_dictionary() if position != null else null,
			"footprint": footprint.to_dictionary() if footprint != null else null,
			"pathId": String(path_id),
			"destinationId": String(destination_id),
		}

	static func from_dictionary(data: Dictionary) -> EntityDto:
		var dto := EntityDto.new()
		dto.id = StringName(str(data.get("id", "")))
		dto.entity_type = StringName(str(data.get("type", "")))
		dto.color_key = StringName(str(data.get("colorKey", "")))
		dto.capacity = int(data.get("capacity", 0))
		var position_raw: Variant = data.get("position", null)
		if typeof(position_raw) == TYPE_DICTIONARY:
			dto.position = GridPosition.from_dictionary(position_raw)
		var footprint_raw: Variant = data.get("footprint", null)
		if typeof(footprint_raw) == TYPE_DICTIONARY:
			dto.footprint = Footprint.from_dictionary(footprint_raw)
		dto.path_id = StringName(str(data.get("pathId", "")))
		dto.destination_id = StringName(str(data.get("destinationId", "")))
		return dto


class ItemDto:
	var id: StringName = &""
	var item_type: StringName = &""
	var color_key: StringName = &""
	var destination_id: StringName = &""

	func to_dictionary() -> Dictionary:
		return {
			"id": String(id),
			"type": String(item_type),
			"colorKey": String(color_key),
			"destinationId": String(destination_id),
		}

	static func from_dictionary(data: Dictionary) -> ItemDto:
		var dto := ItemDto.new()
		dto.id = StringName(str(data.get("id", "")))
		dto.item_type = StringName(str(data.get("type", "")))
		dto.color_key = StringName(str(data.get("colorKey", "")))
		dto.destination_id = StringName(str(data.get("destinationId", "")))
		return dto


class QueueDto:
	var id: StringName = &""
	var item_ids: Array[StringName] = []

	func to_dictionary() -> Dictionary:
		var ids: Array = []
		for item_id in item_ids:
			ids.append(String(item_id))
		return {"id": String(id), "itemIds": ids}

	static func from_dictionary(data: Dictionary) -> QueueDto:
		var dto := QueueDto.new()
		dto.id = StringName(str(data.get("id", "")))
		var raw: Variant = data.get("itemIds", [])
		if typeof(raw) == TYPE_ARRAY:
			for item_id in raw:
				dto.item_ids.append(StringName(str(item_id)))
		return dto


class DestinationDto:
	var id: StringName = &""
	var destination_type: StringName = &""
	var accepted_keys: Array[StringName] = []
	var capacity: int = 0
	var queue_id: StringName = &""
	var position: GridPosition = null
	var footprint: Footprint = null

	func to_dictionary() -> Dictionary:
		var keys: Array = []
		for color_key in accepted_keys:
			keys.append(String(color_key))
		return {
			"id": String(id),
			"type": String(destination_type),
			"acceptedKeys": keys,
			"capacity": capacity,
			"queueId": String(queue_id),
			"position": position.to_dictionary() if position != null else null,
			"footprint": footprint.to_dictionary() if footprint != null else null,
		}

	static func from_dictionary(data: Dictionary) -> DestinationDto:
		var dto := DestinationDto.new()
		dto.id = StringName(str(data.get("id", "")))
		dto.destination_type = StringName(str(data.get("type", "")))
		var keys_raw: Variant = data.get("acceptedKeys", [])
		if typeof(keys_raw) == TYPE_ARRAY:
			for color_key in keys_raw:
				dto.accepted_keys.append(StringName(str(color_key)))
		dto.capacity = int(data.get("capacity", 0))
		dto.queue_id = StringName(str(data.get("queueId", "")))
		var position_raw: Variant = data.get("position", null)
		if typeof(position_raw) == TYPE_DICTIONARY:
			dto.position = GridPosition.from_dictionary(position_raw)
		var footprint_raw: Variant = data.get("footprint", null)
		if typeof(footprint_raw) == TYPE_DICTIONARY:
			dto.footprint = Footprint.from_dictionary(footprint_raw)
		return dto


class ObjectiveDto:
	var id: StringName = &""
	var objective_type: StringName = &""
	var mandatory: bool = true

	func to_dictionary() -> Dictionary:
		return {
			"id": String(id),
			"type": String(objective_type),
			"mandatory": mandatory,
		}

	static func from_dictionary(data: Dictionary) -> ObjectiveDto:
		var dto := ObjectiveDto.new()
		dto.id = StringName(str(data.get("id", "")))
		dto.objective_type = StringName(str(data.get("type", "")))
		dto.mandatory = bool(data.get("mandatory", true))
		return dto


var schema_version: int = SCHEMA_VERSION
var level_id: StringName = &""
var revision: int = 0
var seed: int = 0
var theme_id: StringName = &""
var board_width: int = 0
var board_height: int = 0
var paths: Array = []
var entities: Array = []
var items: Array = []
var queues: Array = []
var destinations: Array = []
var staging_slots: int = 0
var objectives: Array = []
var allowed_boosters: Array[StringName] = []
var difficulty_target: Variant = null
var tags: Array[StringName] = []


static func from_dictionary(data: Dictionary) -> LevelDefinition:
	var definition := LevelDefinition.new()
	definition.schema_version = int(data.get("schemaVersion", 0))
	definition.level_id = StringName(str(data.get("levelId", "")))
	definition.revision = int(data.get("revision", 0))
	definition.seed = int(data.get("seed", 0))
	definition.theme_id = StringName(str(data.get("themeId", "")))

	var board_raw: Variant = data.get("board", null)
	if typeof(board_raw) == TYPE_DICTIONARY:
		var board: Dictionary = board_raw
		definition.board_width = int(board.get("width", 0))
		definition.board_height = int(board.get("height", 0))

	var paths_raw: Variant = data.get("paths", [])
	if typeof(paths_raw) == TYPE_ARRAY:
		for entry in paths_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.paths.append(PathDto.from_dictionary(entry))

	var entities_raw: Variant = data.get("entities", [])
	if typeof(entities_raw) == TYPE_ARRAY:
		for entry in entities_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.entities.append(EntityDto.from_dictionary(entry))

	var items_raw: Variant = data.get("items", [])
	if typeof(items_raw) == TYPE_ARRAY:
		for entry in items_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.items.append(ItemDto.from_dictionary(entry))

	var queues_raw: Variant = data.get("queues", [])
	if typeof(queues_raw) == TYPE_ARRAY:
		for entry in queues_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.queues.append(QueueDto.from_dictionary(entry))

	var destinations_raw: Variant = data.get("destinations", [])
	if typeof(destinations_raw) == TYPE_ARRAY:
		for entry in destinations_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.destinations.append(DestinationDto.from_dictionary(entry))

	var staging_raw: Variant = data.get("staging", null)
	if typeof(staging_raw) == TYPE_DICTIONARY:
		var staging: Dictionary = staging_raw
		definition.staging_slots = int(staging.get("slots", -1))
	else:
		definition.staging_slots = -1

	var objectives_raw: Variant = data.get("objectives", [])
	if typeof(objectives_raw) == TYPE_ARRAY:
		for entry in objectives_raw:
			if typeof(entry) == TYPE_DICTIONARY:
				definition.objectives.append(ObjectiveDto.from_dictionary(entry))

	var boosters_raw: Variant = data.get("allowedBoosters", [])
	if typeof(boosters_raw) == TYPE_ARRAY:
		for booster in boosters_raw:
			definition.allowed_boosters.append(StringName(str(booster)))

	definition.difficulty_target = Serialization.canonicalize(data.get("difficultyTarget", null))

	var tags_raw: Variant = data.get("tags", [])
	if typeof(tags_raw) == TYPE_ARRAY:
		for tag in tags_raw:
			definition.tags.append(StringName(str(tag)))
	return definition


func to_dictionary() -> Dictionary:
	var paths_out: Array = []
	for path in paths:
		paths_out.append(path.to_dictionary())

	var entities_out: Array = []
	for entity in entities:
		entities_out.append(entity.to_dictionary())

	var items_out: Array = []
	for item in items:
		items_out.append(item.to_dictionary())

	var queues_out: Array = []
	for queue in queues:
		queues_out.append(queue.to_dictionary())

	var destinations_out: Array = []
	for destination in destinations:
		destinations_out.append(destination.to_dictionary())

	var objectives_out: Array = []
	for objective in objectives:
		objectives_out.append(objective.to_dictionary())

	var boosters_out: Array = []
	for booster in allowed_boosters:
		boosters_out.append(String(booster))

	var tags_out: Array = []
	for tag in tags:
		tags_out.append(String(tag))

	return {
		"schemaVersion": schema_version,
		"levelId": String(level_id),
		"revision": revision,
		"seed": seed,
		"themeId": String(theme_id),
		"board": {"width": board_width, "height": board_height},
		"paths": paths_out,
		"entities": entities_out,
		"items": items_out,
		"queues": queues_out,
		"destinations": destinations_out,
		"staging": {"slots": staging_slots},
		"objectives": objectives_out,
		"allowedBoosters": boosters_out,
		"difficultyTarget": Serialization.canonicalize(difficulty_target),
		"tags": tags_out,
	}


func duplicate_definition() -> LevelDefinition:
	return LevelDefinition.from_dictionary(to_dictionary())


func content_hash() -> String:
	return Serialization.to_json(to_dictionary()).sha256_text()
