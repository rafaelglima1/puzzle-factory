extends "res://tests/framework/test_base.gd"
## M5 level schema: v1 parse, external round-trip, defaults and required fields.

func run() -> void:
	_valid_parse_and_roundtrip()
	_optional_defaults()
	_required_field_detection()
	_unknown_schema_version()
	_duplicate_is_independent()
	_deterministic_hash()


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


func _valid_parse_and_roundtrip() -> void:
	var input := _valid_dict()
	var definition := LevelDefinition.from_dictionary(input)
	check(definition != null, "definition parses")
	check_eq(definition.schema_version, 1, "schema version parsed")
	check_eq(String(definition.level_id), "example", "level id parsed")
	check_eq(definition.revision, 1, "revision parsed")
	check_eq(definition.seed, 11, "seed parsed")
	check_eq(String(definition.theme_id), "traffic", "theme parsed")
	check_eq(definition.board_width, 4, "board width parsed")
	check_eq(definition.board_height, 2, "board height parsed")
	check_eq(definition.paths.size(), 1, "one path parsed")
	check_eq(definition.entities.size(), 1, "one entity parsed")
	check_eq(definition.items.size(), 1, "one item parsed")
	check_eq(definition.queues.size(), 1, "one queue parsed")
	check_eq(definition.destinations.size(), 1, "one destination parsed")
	check_eq(definition.staging_slots, 4, "staging parsed")
	check_eq(definition.objectives.size(), 1, "one objective parsed")
	check(Serialization.values_equal(definition.to_dictionary(), input), "external round-trip is stable")
	check(LevelValidator.validate(definition).is_empty(), "schema fixture validates")


func _optional_defaults() -> void:
	var input := _valid_dict()
	input.erase("allowedBoosters")
	input.erase("difficultyTarget")
	input.erase("tags")
	var definition := LevelDefinition.from_dictionary(input)
	check_eq(definition.allowed_boosters.size(), 0, "allowedBoosters defaults to []")
	check(definition.difficulty_target == null, "difficultyTarget defaults to null")
	check_eq(definition.tags.size(), 0, "tags defaults to []")
	var roundtrip := definition.to_dictionary()
	check(roundtrip.has("allowedBoosters"), "default boosters emitted")
	check_eq(roundtrip["allowedBoosters"].size(), 0, "default boosters empty")
	check_eq(roundtrip["difficultyTarget"], null, "default difficulty emitted as null")
	check_eq(roundtrip["tags"].size(), 0, "default tags empty")


func _required_field_detection() -> void:
	var definition := LevelDefinition.from_dictionary({})
	var errors := LevelValidator.validate(definition)
	check(errors.has("UNSUPPORTED_SCHEMA_VERSION"), "missing schema version detected")
	check(errors.has("INVALID_LEVEL_ID"), "missing level id detected")
	check(errors.has("INVALID_REVISION"), "missing revision detected")
	check(errors.has("INVALID_THEME_ID"), "missing theme detected")
	check(errors.has("INVALID_BOARD"), "missing board detected")
	check(errors.has("INVALID_STAGING_SLOTS"), "missing staging detected")


func _unknown_schema_version() -> void:
	var input := _valid_dict()
	input["schemaVersion"] = 2
	var errors := LevelValidator.validate_dictionary(input)
	check(errors.has("UNSUPPORTED_SCHEMA_VERSION"), "unknown schema version detected")
	var definition := LevelDefinition.from_dictionary(input)
	check_eq(definition.schema_version, 2, "unknown version preserved for diagnostics")


func _duplicate_is_independent() -> void:
	var definition := LevelDefinition.from_dictionary(_valid_dict())
	var copy := definition.duplicate_definition()
	copy.level_id = &"changed"
	copy.board_width = 99
	check_eq(String(definition.level_id), "example", "duplicate does not alias original")
	check_eq(definition.board_width, 4, "duplicate does not alias numeric fields")
	check(Serialization.values_equal(definition.to_dictionary(), _valid_dict()), "duplicate leaves original intact")


func _deterministic_hash() -> void:
	var first := LevelDefinition.from_dictionary(_valid_dict())
	var source := _valid_dict()
	var rebuilt := {}
	for key in ["tags", "objectives", "staging", "destinations", "queues", "items", "entities", "paths", "board", "themeId", "seed", "revision", "levelId", "schemaVersion", "allowedBoosters", "difficultyTarget"]:
		rebuilt[key] = source[key]
	var second := LevelDefinition.from_dictionary(rebuilt)
	check_eq(first.content_hash(), second.content_hash(), "content hash is insertion-order independent")
	check_eq(first.content_hash(), first.content_hash(), "content hash is stable")
	check(not first.content_hash().is_empty(), "content hash is non-empty")
