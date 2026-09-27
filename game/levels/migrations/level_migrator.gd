class_name LevelMigrator
extends RefCounted
## Deterministic level schema migration registry (M5).
##
## Steps are keyed by source version and applied in ascending order. Migrating
## from the current version returns an unchanged copy. Requests that cannot be
## fulfilled (newer version, missing chain) return the original data and report
## failure through [method migrate_with_result].

const CURRENT_VERSION := 1
const MIGRATION_TARGETS := {0: 1}


static func current_version() -> int:
	return CURRENT_VERSION


static func is_supported(version: int) -> bool:
	if version < 0:
		return false
	var current := version
	var guard := 0
	while current != CURRENT_VERSION:
		if not MIGRATION_TARGETS.has(current):
			return false
		var next: int = MIGRATION_TARGETS[current]
		if next <= current:
			return false
		current = next
		guard += 1
		if guard > 64:
			return false
	return true


static func migrate(data: Dictionary) -> Dictionary:
	var result := migrate_with_result(data)
	var migrated: Dictionary = result["data"]
	return migrated


static func migrate_with_result(data: Dictionary) -> Dictionary:
	var unchanged: Dictionary = data.duplicate(true)
	var raw_version: Variant = data.get("schemaVersion", CURRENT_VERSION)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		return {"ok": false, "data": unchanged, "from": CURRENT_VERSION, "to": CURRENT_VERSION}
	var from_version := int(raw_version)
	if from_version == CURRENT_VERSION:
		return {"ok": true, "data": unchanged, "from": from_version, "to": from_version}
	if from_version > CURRENT_VERSION or not is_supported(from_version):
		return {"ok": false, "data": unchanged, "from": from_version, "to": from_version}
	var working: Dictionary = data.duplicate(true)
	var version := from_version
	while version != CURRENT_VERSION:
		var next: int = MIGRATION_TARGETS[version]
		working = _apply_step(version, next, working)
		version = next
	return {"ok": true, "data": working, "from": from_version, "to": version}


static func _apply_step(from_version: int, to_version: int, data: Dictionary) -> Dictionary:
	if from_version == 0 and to_version == 1:
		return _migrate_0_to_1(data)
	return data


static func _migrate_0_to_1(data: Dictionary) -> Dictionary:
	var converted := from_legacy_dictionary(data)
	converted["schemaVersion"] = CURRENT_VERSION
	return converted


## Converts a product-free flat legacy dictionary into the v1 external contract.
static func from_legacy_dictionary(data: Dictionary) -> Dictionary:
	var board := _as_dictionary(data.get("board", null))
	var width := _int(data.get("width", board.get("width", 0)), 0)
	var height := _int(data.get("height", board.get("height", 0)), 0)
	var staging := _as_dictionary(data.get("staging", null))
	var staging_slots := _int(data.get("staging_slots", staging.get("slots", 0)), 0)
	var level_id := _string(_pick(data, "levelId", "level_id"), "")
	var theme_id := _string(_pick(data, "themeId", "theme_id"), "generic")
	var revision := _int(data.get("revision", 1), 1)
	var seed_value := _int(data.get("seed", 0), 0)

	var boosters: Array = []
	var boosters_raw: Variant = data.get("allowedBoosters", null)
	if boosters_raw == null:
		boosters_raw = data.get("allowed_boosters", [])
	if typeof(boosters_raw) == TYPE_ARRAY:
		for booster in boosters_raw:
			boosters.append(_string(booster, ""))

	var tags: Array = []
	var tags_raw: Variant = data.get("tags", [])
	if typeof(tags_raw) == TYPE_ARRAY:
		for tag in tags_raw:
			tags.append(_string(tag, ""))

	return {
		"schemaVersion": CURRENT_VERSION,
		"levelId": level_id,
		"revision": revision,
		"seed": seed_value,
		"themeId": theme_id,
		"board": {"width": width, "height": height},
		"paths": _legacy_paths(data.get("paths", [])),
		"entities": _legacy_entities(data.get("entities", [])),
		"items": _legacy_items(data.get("items", [])),
		"queues": _legacy_queues(data.get("queues", [])),
		"destinations": _legacy_destinations(data.get("destinations", [])),
		"staging": {"slots": staging_slots},
		"objectives": _legacy_objectives(data.get("objectives", [])),
		"allowedBoosters": boosters,
		"difficultyTarget": Serialization.canonicalize(data.get("difficultyTarget", data.get("difficulty_target", null))),
		"tags": tags,
	}


static func _legacy_paths(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		var mapping: Dictionary = raw
		var keys: Array = mapping.keys()
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			result.append({"id": String(key), "cells": _legacy_cells(mapping[key])})
	elif typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var path: Dictionary = entry
			result.append({
				"id": _string(path.get("id", ""), ""),
				"cells": _legacy_cells(path.get("cells", [])),
			})
	return result


static func _legacy_entities(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entity: Dictionary = entry
		result.append({
			"id": _string(entity.get("id", ""), ""),
			"type": _string(_pick(entity, "type", "entity_type"), "generic"),
			"colorKey": _string(_pick(entity, "colorKey", "color_key"), ""),
			"capacity": _int(entity.get("capacity", 1), 1),
			"position": _legacy_position(entity.get("position", null)),
			"footprint": _legacy_footprint(entity.get("footprint", null)),
			"pathId": _string(_pick(entity, "pathId", "path_id"), ""),
			"destinationId": _string(_pick(entity, "destinationId", "destination_id"), ""),
		})
	return result


static func _legacy_items(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		result.append({
			"id": _string(item.get("id", ""), ""),
			"type": _string(_pick(item, "type", "item_type"), "standard"),
			"colorKey": _string(_pick(item, "colorKey", "color_key"), ""),
			"destinationId": _string(_pick(item, "destinationId", "destination_id"), ""),
		})
	return result


static func _legacy_queues(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		var mapping: Dictionary = raw
		var keys: Array = mapping.keys()
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			result.append({"id": String(key), "itemIds": _legacy_string_list(mapping[key])})
	elif typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var queue: Dictionary = entry
			result.append({
				"id": _string(queue.get("id", ""), ""),
				"itemIds": _legacy_string_list(_pick(queue, "itemIds", "item_ids")),
			})
	return result


static func _legacy_destinations(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var destination: Dictionary = entry
		result.append({
			"id": _string(destination.get("id", ""), ""),
			"type": _string(_pick(destination, "type", "destination_type"), "default"),
			"acceptedKeys": _legacy_string_list(_pick(destination, "acceptedKeys", "accepted_keys")),
			"capacity": _int(destination.get("capacity", 0), 0),
			"queueId": _string(_pick(destination, "queueId", "queue_id"), ""),
			"position": _legacy_position(destination.get("position", null)),
			"footprint": _legacy_footprint(destination.get("footprint", null)),
		})
	return result


static func _legacy_objectives(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var objective: Dictionary = entry
			result.append({
				"id": _string(objective.get("id", ""), ""),
				"type": _string(objective.get("type", "CLEAR_ALL"), "CLEAR_ALL"),
				"mandatory": bool(objective.get("mandatory", true)),
			})
	if result.is_empty():
		result.append({"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true})
	return result


static func _legacy_cells(raw: Variant) -> Array:
	var cells: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return cells
	for entry in raw:
		if typeof(entry) == TYPE_DICTIONARY:
			var cell: Dictionary = entry
			cells.append({"x": _int(cell.get("x", 0), 0), "y": _int(cell.get("y", 0), 0)})
		elif typeof(entry) == TYPE_ARRAY:
			var pair: Array = entry
			if pair.size() >= 2:
				cells.append({"x": _int(pair[0], 0), "y": _int(pair[1], 0)})
	return cells


static func _legacy_string_list(raw: Variant) -> Array:
	var values: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return values
	for entry in raw:
		values.append(_string(entry, ""))
	return values


static func _legacy_position(value: Variant) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var position: Dictionary = value
	return {"x": _int(position.get("x", 0), 0), "y": _int(position.get("y", 0), 0)}


static func _legacy_footprint(value: Variant) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var footprint: Dictionary = value
	return {
		"width": _int(footprint.get("width", 1), 1),
		"height": _int(footprint.get("height", 1), 1),
	}


static func _pick(data: Dictionary, primary: String, fallback: String) -> Variant:
	if data.has(primary):
		return data[primary]
	return data.get(fallback, null)


static func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


static func _int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


static func _string(value: Variant, fallback: String) -> String:
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		return String(value)
	return fallback
