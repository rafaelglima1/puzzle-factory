extends "res://tests/framework/test_base.gd"
## M5 migration: version registry, determinism and generic legacy conversion.

func run() -> void:
	_version_registry()
	_current_version_unchanged()
	_unsupported_is_unchanged()
	_explicit_chain()
	_deterministic_bytes()
	_legacy_conversion_is_valid()
	_legacy_conversion_deterministic()


func _v1_dict() -> Dictionary:
	return {
		"schemaVersion": 1,
		"levelId": "level",
		"revision": 1,
		"seed": 1,
		"themeId": "generic",
		"board": {"width": 2, "height": 2},
		"paths": [],
		"entities": [],
		"items": [],
		"queues": [],
		"destinations": [],
		"staging": {"slots": 0},
		"objectives": [],
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


func _version_registry() -> void:
	check_eq(LevelMigrator.current_version(), 1, "current version is 1")
	check(LevelMigrator.is_supported(1), "v1 supported")
	check(LevelMigrator.is_supported(0), "v0 supported through the chain")
	check(not LevelMigrator.is_supported(2), "v2 unsupported")
	check(not LevelMigrator.is_supported(-1), "negative version unsupported")


func _current_version_unchanged() -> void:
	var data := _v1_dict()
	var migrated := LevelMigrator.migrate(data)
	check(Serialization.values_equal(migrated, data), "current version is returned unchanged")
	var result := LevelMigrator.migrate_with_result(data)
	check(bool(result["ok"]), "current version reports success")
	check_eq(int(result["from"]), 1, "current from version is 1")
	check_eq(int(result["to"]), 1, "current to version is 1")


func _unsupported_is_unchanged() -> void:
	var data := _v1_dict()
	data["schemaVersion"] = 9
	var result := LevelMigrator.migrate_with_result(data)
	check(not bool(result["ok"]), "newer version reports failure")
	check(Serialization.values_equal(result["data"], data), "newer version is returned unchanged")
	check_eq(int(result["from"]), 9, "newer from version reported")
	check_eq(int(result["to"]), 9, "newer version is never downgraded")


func _explicit_chain() -> void:
	var result := LevelMigrator.migrate_with_result(_legacy_dict())
	check(bool(result["ok"]), "v0 migrates through the registered chain")
	check_eq(int(result["from"]), 0, "chain from version 0")
	check_eq(int(result["to"]), 1, "chain to version 1")
	var migrated: Dictionary = result["data"]
	check_eq(int(migrated["schemaVersion"]), 1, "schema stamped as current")
	check(migrated.has("levelId"), "migrated payload uses the external contract")


func _deterministic_bytes() -> void:
	var first := LevelMigrator.migrate(_legacy_dict())
	var second := LevelMigrator.migrate(_legacy_dict())
	check_eq(Serialization.to_json(first), Serialization.to_json(second), "same input migrates to identical bytes")
	var reordered := {}
	for key in ["destinations", "queues", "items", "entities", "paths", "staging_slots", "height", "width", "theme_id", "seed", "revision", "level_id", "schemaVersion"]:
		reordered[key] = _legacy_dict()[key]
	check_eq(
		Serialization.to_json(LevelMigrator.migrate(reordered)),
		Serialization.to_json(first),
		"key insertion order does not affect migration bytes"
	)


func _legacy_conversion_is_valid() -> void:
	var converted := LevelMigrator.from_legacy_dictionary(_legacy_dict())
	check_eq(int(converted["schemaVersion"]), 1, "legacy conversion emits v1")
	check(Serialization.is_primitive_tree(converted), "legacy conversion is primitive-only")
	var errors := LevelValidator.validate_dictionary(converted)
	check(errors.is_empty(), "legacy conversion passes validation (%s)" % ", ".join(errors))


func _legacy_conversion_deterministic() -> void:
	var first := LevelMigrator.from_legacy_dictionary(_legacy_dict())
	var second := LevelMigrator.from_legacy_dictionary(_legacy_dict())
	check_eq(Serialization.to_json(first), Serialization.to_json(second), "legacy conversion is deterministic")
