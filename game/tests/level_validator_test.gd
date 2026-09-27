extends "res://tests/framework/test_base.gd"
## M5 level validator: one focused check per implemented error family.

func run() -> void:
	_valid_passes()
	_invalid_scalar_fields()
	_duplicate_ids()
	_path_errors()
	_entity_errors()
	_entity_overlap()
	_entity_position_rules()
	_route_start_mismatch()
	_item_errors()
	_queue_errors()
	_destination_errors()
	_objective_errors()
	_booster_rules()
	_unsolvable_but_valid()


func _valid_dict() -> Dictionary:
	return {
		"schemaVersion": 1,
		"levelId": "example",
		"revision": 1,
		"seed": 11,
		"themeId": "traffic",
		"board": {"width": 4, "height": 2},
		"paths": [{"id": "route_1", "cells": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]}],
		"entities": [{
			"id": "entity_1",
			"type": "compact",
			"colorKey": "COLOR_A",
			"capacity": 1,
			"position": {"x": 0, "y": 0},
			"footprint": {"width": 1, "height": 1},
			"pathId": "route_1",
			"destinationId": "destination_1",
		}],
		"items": [{
			"id": "item_1",
			"type": "standard",
			"colorKey": "COLOR_A",
			"destinationId": "destination_1",
		}],
		"queues": [{"id": "queue_1", "itemIds": ["item_1"]}],
		"destinations": [{
			"id": "destination_1",
			"type": "default",
			"acceptedKeys": ["COLOR_A"],
			"capacity": 1,
			"queueId": "queue_1",
			"position": {"x": 3, "y": 0},
			"footprint": {"width": 1, "height": 1},
		}],
		"staging": {"slots": 4},
		"objectives": [{"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true}],
		"allowedBoosters": [],
		"difficultyTarget": null,
		"tags": [],
	}


func _valid_passes() -> void:
	var errors := LevelValidator.validate_dictionary(_valid_dict())
	check(errors.is_empty(), "valid level has no errors (%s)" % ", ".join(errors))


func _invalid_scalar_fields() -> void:
	var data := _valid_dict()
	data["schemaVersion"] = 3
	data["levelId"] = ""
	data["revision"] = 0
	data["themeId"] = ""
	data["board"] = {"width": 0, "height": 2}
	data["staging"] = {"slots": -1}
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("UNSUPPORTED_SCHEMA_VERSION"), "schema version checked")
	check(errors.has("INVALID_LEVEL_ID"), "level id checked")
	check(errors.has("INVALID_REVISION"), "revision checked")
	check(errors.has("INVALID_THEME_ID"), "theme id checked")
	check(errors.has("INVALID_BOARD"), "board checked")
	check(errors.has("INVALID_STAGING_SLOTS"), "staging slots checked")


func _duplicate_ids() -> void:
	var data := _valid_dict()
	var paths: Array = data["paths"]
	paths.append({"id": "destination_1", "cells": [{"x": 0, "y": 1}, {"x": 1, "y": 1}]})
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("DUPLICATE_ID:destination_1"), "cross-namespace duplicate id detected")


func _path_errors() -> void:
	var data := _valid_dict()
	var paths: Array = data["paths"]
	paths.append({"id": "p_short", "cells": [{"x": 0, "y": 1}]})
	paths.append({"id": "p_gap", "cells": [{"x": 0, "y": 1}, {"x": 2, "y": 1}]})
	paths.append({"id": "p_dup", "cells": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 1, "y": 1}]})
	paths.append({"id": "p_oob", "cells": [{"x": 0, "y": 1}, {"x": 9, "y": 9}]})
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("INVALID_PATH:p_short:too_short"), "short path detected")
	check(errors.has("INVALID_PATH:p_gap:non_contiguous:1"), "non-contiguous path detected")
	check(errors.has("INVALID_PATH:p_dup:duplicate_cell:2"), "duplicate path cell detected")
	check(errors.has("OUT_OF_BOUNDS:path:p_oob:1"), "out-of-bounds path cell detected")


func _entity_errors() -> void:
	var data := _valid_dict()
	var entities: Array = data["entities"]
	var entity: Dictionary = entities[0]
	entity["pathId"] = "missing_path"
	entity["destinationId"] = "missing_destination"
	entity["capacity"] = 0
	entity["position"] = {"x": 9, "y": 9}
	entity["footprint"] = {"width": 0, "height": 1}
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("UNKNOWN_PATH:missing_path"), "unknown entity path detected")
	check(errors.has("UNKNOWN_DESTINATION:missing_destination"), "unknown entity destination detected")
	check(errors.has("INVALID_CAPACITY:entity_1"), "invalid entity capacity detected")
	check(errors.has("OUT_OF_BOUNDS:entity:entity_1"), "out-of-bounds entity detected")
	check(errors.has("INVALID_FOOTPRINT:entity_1"), "invalid entity footprint detected")


func _entity_overlap() -> void:
	var data := _valid_dict()
	var entities: Array = data["entities"]
	entities.append({
		"id": "entity_2",
		"type": "compact",
		"colorKey": "COLOR_A",
		"capacity": 1,
		"position": {"x": 0, "y": 0},
		"footprint": {"width": 1, "height": 1},
		"pathId": "route_1",
		"destinationId": "destination_1",
	})
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("ENTITY_OVERLAP:entity_1:entity_2"), "entity overlap detected")

func _route_start_mismatch() -> void:
	var data := _valid_dict()
	var entities: Array = data["entities"]
	var entity: Dictionary = entities[0]
	entity["position"] = {"x": 1, "y": 0}
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("ROUTE_START_MISMATCH:entity_1"), "route start mismatch detected")


func _entity_position_rules() -> void:
	var data := _valid_dict()
	var entities: Array = data["entities"]
	var entity: Dictionary = entities[0]
	entity["position"] = "not a position"
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("INVALID_POSITION:entity_1"), "missing/typed entity position detected")


func _item_errors() -> void:
	var data := _valid_dict()
	var items: Array = data["items"]
	var item: Dictionary = items[0]
	item["colorKey"] = ""
	item["destinationId"] = "missing_destination"
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("MISSING_COLOR_KEY:item_1"), "missing item color key detected")
	check(errors.has("UNKNOWN_DESTINATION:missing_destination"), "unknown item destination detected")


func _queue_errors() -> void:
	var data := _valid_dict()
	var items: Array = data["items"]
	items.append({
		"id": "item_2",
		"type": "standard",
		"colorKey": "COLOR_A",
		"destinationId": "destination_1",
	})
	var queues: Array = data["queues"]
	var queue: Dictionary = queues[0]
	var ids: Array = queue["itemIds"]
	ids.append("ghost_item")
	queues.append({"id": "queue_2", "itemIds": ["item_1"]})
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("UNKNOWN_ITEM:ghost_item"), "unknown queue item detected")
	check(errors.has("DUPLICATE_ITEM_OWNERSHIP:item_1"), "duplicate item ownership detected")
	check(errors.has("UNREFERENCED_ITEM:item_2"), "unreferenced item detected")


func _destination_errors() -> void:
	var data := _valid_dict()
	var destinations: Array = data["destinations"]
	var destination: Dictionary = destinations[0]
	destination["queueId"] = "missing_queue"
	destination["capacity"] = -1
	destination["acceptedKeys"] = []
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("UNKNOWN_QUEUE:missing_queue"), "unknown destination queue detected")
	check(errors.has("INVALID_CAPACITY:destination_1"), "invalid destination capacity detected")
	check(errors.has("INVALID_ACCEPTED_KEYS:destination_1"), "empty accepted keys detected")


func _objective_errors() -> void:
	var data := _valid_dict()
	data["objectives"] = [
		{"id": "", "type": "CLEAR_ALL", "mandatory": true},
		{"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true},
		{"id": "clear_all", "type": "CLEAR_ALL", "mandatory": false},
		{"id": "weird", "type": "NOT_A_TYPE", "mandatory": true},
	]
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.has("INVALID_OBJECTIVE:empty_id"), "empty objective id detected")
	check(errors.has("INVALID_OBJECTIVE:clear_all:duplicate"), "duplicate objective detected")
	check(errors.has("INVALID_OBJECTIVE:weird:unknown_type"), "unknown objective type detected")
	var lower := _valid_dict()
	lower["objectives"] = [{"id": "clear_all", "type": "clear_all", "mandatory": true}]
	check(LevelValidator.validate_dictionary(lower).is_empty(), "lowercase clear_all accepted")


func _booster_rules() -> void:
	var data := _valid_dict()
	data["allowedBoosters"] = ["UNDO", "EXTRA_SLOT", "SHUFFLE", "TELEPORT"]
	var errors := LevelValidator.validate_dictionary(data)
	check(not errors.has("INVALID_BOOSTER:UNDO"), "known booster accepted")
	check(errors.has("INVALID_BOOSTER:TELEPORT"), "unknown booster rejected")
	var lower := _valid_dict()
	lower["allowedBoosters"] = ["undo", "shuffle"]
	check(LevelValidator.validate_dictionary(lower).is_empty(), "booster case is normalized")


func _unsolvable_but_valid() -> void:
	var data := _valid_dict()
	data["items"] = []
	data["queues"] = [{"id": "queue_1", "itemIds": []}]
	data["entities"] = [{
		"id": "entity_1",
		"type": "compact",
		"colorKey": "COLOR_A",
		"capacity": 1,
		"position": {"x": 0, "y": 0},
		"footprint": {"width": 1, "height": 1},
		"pathId": "route_1",
		"destinationId": "destination_1",
	}]
	data["objectives"] = [{"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true}]
	var errors := LevelValidator.validate_dictionary(data)
	check(errors.is_empty(), "unsolvable but structurally valid level passes (%s)" % ", ".join(errors))
