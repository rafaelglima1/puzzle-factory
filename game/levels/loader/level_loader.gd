class_name LevelLoader
extends RefCounted
## Loads level definitions from JSON text, files or dictionaries.
##
## The pipeline never swallows errors: parse -> dictionary -> schema version ->
## migration -> build -> validation, with a structured [LevelLoadResult] for
## every failure. Files are only read, never rewritten.

static func load_from_json_text(text: String, source_path: String = "") -> LevelLoadResult:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failure(LevelLoadResult.Status.INVALID_JSON, source_path, ["INVALID_JSON:%d" % json.get_error_line()])
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _failure(LevelLoadResult.Status.NOT_A_DICTIONARY, source_path, ["NOT_A_DICTIONARY"])
	return load_from_dictionary(data, source_path)


static func load_from_file(path: String) -> LevelLoadResult:
	if path.is_empty() or not FileAccess.file_exists(path):
		return _failure(LevelLoadResult.Status.FILE_NOT_FOUND, path, ["FILE_NOT_FOUND:%s" % path])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(LevelLoadResult.Status.IO_ERROR, path, ["IO_ERROR:%s" % path])
	var text := file.get_as_text()
	file.close()
	return load_from_json_text(text, path)


static func load_from_dictionary(data: Dictionary, source_path: String = "") -> LevelLoadResult:
	var result := LevelLoadResult.new()
	result.source_path = source_path
	var raw_version: Variant = data.get("schemaVersion", null)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		result.status = LevelLoadResult.Status.UNSUPPORTED_SCHEMA_VERSION
		result.errors.append("UNSUPPORTED_SCHEMA_VERSION:missing")
		return result
	var version := int(raw_version)
	result.schema_version = version
	if not LevelMigrator.is_supported(version):
		result.status = LevelLoadResult.Status.UNSUPPORTED_SCHEMA_VERSION
		result.errors.append("UNSUPPORTED_SCHEMA_VERSION:%d" % version)
		return result

	var effective: Dictionary = data
	if version < LevelMigrator.current_version():
		var migration := LevelMigrator.migrate_with_result(data)
		if not bool(migration["ok"]):
			result.status = LevelLoadResult.Status.MIGRATION_FAILED
			result.errors.append("MIGRATION_FAILED:%d" % version)
			return result
		effective = migration["data"]

	result.definition = LevelDefinition.from_dictionary(effective)
	var errors := LevelValidator.validate(result.definition)
	if not errors.is_empty():
		result.status = LevelLoadResult.Status.VALIDATION_FAILED
		result.errors = errors
		return result
	result.status = LevelLoadResult.Status.OK
	return result


static func _failure(status: int, source_path: String, errors: Array) -> LevelLoadResult:
	var result := LevelLoadResult.new()
	result.status = status
	result.source_path = source_path
	for error in errors:
		result.errors.append(String(error))
	return result
