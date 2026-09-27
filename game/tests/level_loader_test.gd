extends "res://tests/framework/test_base.gd"
## M5 level loader: JSON/file/dict pipeline, migration path and error surfaces.

const TMP_DIR := "user://m5_tests"
const VALID_PATH := "user://m5_tests/level_valid.json"
const MALFORMED_PATH := "user://m5_tests/level_malformed.json"
const INVALID_REF_PATH := "user://m5_tests/level_invalid_ref.json"
const PACK_PATH := "user://m5_tests/level_pack.json"


func run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_valid_text()
	_valid_file()
	_malformed_json()
	_missing_file()
	_invalid_reference_surfaces()
	_not_a_dictionary()
	_missing_schema_version()
	_unsupported_schema_version()
	_legacy_migration()
	_pack_manifest()
	_cleanup()


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


func _legacy_dict() -> Dictionary:
	return {
		"schemaVersion": 0,
		"level_id": "legacy_level",
		"revision": 1,
		"seed": 7,
		"theme_id": "generic",
		"width": 3,
		"height": 2,
		"staging_slots": 2,
		"paths": {"route_1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]},
		"entities": [{
			"id": "entity_1",
			"type": "compact",
			"color_key": "COLOR_A",
			"capacity": 1,
			"position": {"x": 0, "y": 0},
			"footprint": {"width": 1, "height": 1},
			"path_id": "route_1",
			"destination_id": "destination_1",
		}],
		"items": [{
			"id": "item_1",
			"type": "standard",
			"color_key": "COLOR_A",
			"destination_id": "destination_1",
		}],
		"queues": {"queue_1": ["item_1"]},
		"destinations": [{
			"id": "destination_1",
			"type": "default",
			"accepted_keys": ["COLOR_A"],
			"capacity": 1,
			"queue_id": "queue_1",
			"position": {"x": 2, "y": 0},
			"footprint": {"width": 1, "height": 1},
		}],
	}


func _cleanup() -> void:
	for path in [VALID_PATH, MALFORMED_PATH, INVALID_REF_PATH, PACK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "fixture writable: %s" % path)
	if file != null:
		file.store_string(text)
		file.close()


func _valid_text() -> void:
	var result := LevelLoader.load_from_json_text(JSON.stringify(_valid_dict()), "memory://level")
	check(result.is_ok(), "valid JSON text loads")
	check(result.definition != null, "valid text yields a definition")
	check_eq(result.status, LevelLoadResult.Status.OK, "valid text status OK")
	check_eq(result.source_path, "memory://level", "in-memory source path recorded")
	check_eq(result.schema_version, 1, "in-memory schema version recorded")


func _valid_file() -> void:
	_write(VALID_PATH, JSON.stringify(_valid_dict()))
	var result := LevelLoader.load_from_file(VALID_PATH)
	check(result.is_ok(), "valid file loads")
	check_eq(result.source_path, VALID_PATH, "file source path recorded")
	check_eq(result.schema_version, 1, "file schema version recorded")


func _malformed_json() -> void:
	_write(MALFORMED_PATH, "{not valid json")
	var result := LevelLoader.load_from_file(MALFORMED_PATH)
	check_eq(result.status, LevelLoadResult.Status.INVALID_JSON, "malformed JSON reported")
	check(result.definition == null, "malformed JSON has no definition")
	check_eq(FileAccess.get_file_as_string(MALFORMED_PATH), "{not valid json", "file is never rewritten")


func _missing_file() -> void:
	var result := LevelLoader.load_from_file("user://m5_tests/does_not_exist.json")
	check_eq(result.status, LevelLoadResult.Status.FILE_NOT_FOUND, "missing file reported")
	check(result.definition == null, "missing file has no definition")


func _invalid_reference_surfaces() -> void:
	var data := _valid_dict()
	var entities: Array = data["entities"]
	var entity: Dictionary = entities[0]
	entity["pathId"] = "unknown_route"
	_write(INVALID_REF_PATH, JSON.stringify(data))
	var result := LevelLoader.load_from_file(INVALID_REF_PATH)
	check_eq(result.status, LevelLoadResult.Status.VALIDATION_FAILED, "validation failure reported")
	check(result.error_codes().has("UNKNOWN_PATH:unknown_route"), "validation code surfaced")
	check(result.definition != null, "definition still exposed for diagnostics")


func _not_a_dictionary() -> void:
	var result := LevelLoader.load_from_json_text("[1, 2, 3]")
	check_eq(result.status, LevelLoadResult.Status.NOT_A_DICTIONARY, "non-dictionary JSON reported")


func _missing_schema_version() -> void:
	var data := _valid_dict()
	data.erase("schemaVersion")
	var result := LevelLoader.load_from_dictionary(data)
	check_eq(result.status, LevelLoadResult.Status.UNSUPPORTED_SCHEMA_VERSION, "missing schema version reported")
	check(result.error_codes().has("UNSUPPORTED_SCHEMA_VERSION:missing"), "missing schema code surfaced")


func _unsupported_schema_version() -> void:
	var data := _valid_dict()
	data["schemaVersion"] = 2
	var result := LevelLoader.load_from_dictionary(data)
	check_eq(result.status, LevelLoadResult.Status.UNSUPPORTED_SCHEMA_VERSION, "newer schema version reported")
	check_eq(result.schema_version, 2, "reported version preserved")


func _legacy_migration() -> void:
	var legacy := _legacy_dict()
	var result := LevelLoader.load_from_dictionary(legacy)
	check_eq(result.status, LevelLoadResult.Status.OK, "legacy v0 migrates and loads")
	check(result.definition != null, "migrated definition present")
	if result.definition != null:
		check_eq(result.definition.schema_version, 1, "migrated to the current schema")
		check_eq(String(result.definition.level_id), "legacy_level", "legacy id preserved")
		check_eq(result.definition.board_width, 3, "legacy board width preserved")
		check_eq(result.definition.entities.size(), 1, "legacy entity preserved")
	var text_result := LevelLoader.load_from_json_text(JSON.stringify(legacy))
	check(text_result.is_ok(), "legacy JSON text migrates and loads")


func _pack_manifest() -> void:
	var manifest := {
		"packId": "pack_a",
		"contentVersion": 1,
		"minGameVersion": 1,
		"levels": ["level_01.json", "level_02.json"],
	}
	var pack := LevelPack.from_dictionary(manifest)
	check(pack != null, "pack parses")
	check_eq(pack.pack_id, "pack_a", "pack id parsed")
	check_eq(pack.content_version, 1, "content version parsed")
	check_eq(pack.levels.size(), 2, "levels parsed")
	check(pack.validate().is_empty(), "valid pack validates")
	var paths := pack.level_paths("res://content/pack_a")
	check_eq(paths[0], "res://content/pack_a/level_01.json", "first level path resolved")
	check_eq(paths[1], "res://content/pack_a/level_02.json", "second level path resolved and ordered")
	check_eq(pack.level_paths("res://content/pack_a").size(), 2, "level paths preserve manifest order")
	var duplicate := LevelPack.from_dictionary({
		"packId": "pack_a",
		"contentVersion": 1,
		"minGameVersion": 1,
		"levels": ["level_01.json", "level_01.json"],
	})
	check(duplicate.validate().has("DUPLICATE_LEVEL:level_01.json"), "duplicate level detected")
	_write(PACK_PATH, JSON.stringify(manifest))
	var loaded := LevelPack.load_manifest(PACK_PATH)
	check(loaded != null, "manifest loads from file")
	if loaded != null:
		check_eq(loaded.to_dictionary(), manifest, "manifest round-trips")
	check(LevelPack.load_manifest("user://m5_tests/no_manifest.json") == null, "missing manifest returns null")
