class_name TrafficLevelCatalogue
extends RefCounted
## PRODUCT CONTENT FACADE (Traffic) — OWNER: AGENT-1 (M5 content conversion).
##
## The official-pack loader for Traffic. Official levels live as pure V1 JSON
## under [constant PACK_DIR]; the manifest is the single source of truth for
## order and membership. This facade never falls back to hardcoded data.
##
## Determinism: manifest order defines the progression order, ids are derived
## from manifest entries (filename stem == level id), and parsed definitions are
## cached per index so repeated reads are stable and cheap.

const PACK_DIR := "res://content/levels/traffic/pack_001"
const MANIFEST_FILE := "manifest.json"
const EXPECTED_LEVEL_COUNT := 10

static var _pack: LevelPack = null
static var _level_ids: Array[StringName] = []
static var _loaded := false
static var _definition_cache: Dictionary = {}


## Absolute (res://) directory holding the official pack.
static func pack_dir() -> String:
	return PACK_DIR


## Absolute (res://) path of the pack manifest.
static func manifest_path() -> String:
	return PACK_DIR.path_join(MANIFEST_FILE)


## Ordered level ids from the manifest (deterministic progression order).
static func level_ids() -> Array[StringName]:
	_ensure_loaded()
	return _level_ids.duplicate()


static func count() -> int:
	return level_ids().size()


## Level id at [param level_index], or an empty id when out of range.
static func level_id(level_index: int) -> StringName:
	var ids := level_ids()
	if level_index < 0 or level_index >= ids.size():
		return &""
	return ids[level_index]


## Index of [param target_id] in manifest order, or -1 when absent.
static func index_of(target_id: StringName) -> int:
	var ids := level_ids()
	for index in ids.size():
		if ids[index] == target_id:
			return index
	return -1


## Manifest filename at [param level_index] (empty when out of range).
static func pack_level_filename(level_index: int) -> String:
	_ensure_loaded()
	if _pack == null or level_index < 0 or level_index >= _pack.levels.size():
		return ""
	return _pack.levels[level_index]


## Loads the raw [LevelLoadResult] for [param level_index] through [LevelLoader].
static func load_load_result(level_index: int) -> LevelLoadResult:
	_ensure_loaded()
	if _pack == null or level_index < 0 or level_index >= _pack.levels.size():
		var failure := LevelLoadResult.new()
		failure.status = LevelLoadResult.Status.FILE_NOT_FOUND
		failure.errors.append("LEVEL_NOT_FOUND:%d" % level_index)
		return failure
	var path := PACK_DIR.path_join(_pack.levels[level_index])
	return LevelLoader.load_from_file(path)


## Cached parsed definition for [param level_index], or null when the level is
## missing or invalid.
static func load_definition(level_index: int) -> LevelDefinition:
	if _definition_cache.has(level_index):
		return _definition_cache[level_index]
	var result := load_load_result(level_index)
	var definition: LevelDefinition = result.definition if result.is_ok() else null
	_definition_cache[level_index] = definition
	return definition


## External V1 dictionary for [param level_index] (empty on failure).
static func definition_dictionary(level_index: int) -> Dictionary:
	var definition := load_definition(level_index)
	if definition == null:
		return {}
	return definition.to_dictionary()


## Integrity check: manifest present + valid, exactly ten levels, no duplicate
## ids, every level loads and passes [LevelValidator].
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	_ensure_loaded()
	if _pack == null:
		errors.append("MANIFEST_NOT_FOUND:%s" % manifest_path())
		return errors
	errors.append_array(_pack.validate())
	if _pack.levels.size() != EXPECTED_LEVEL_COUNT:
		errors.append("unexpected_level_count:%d" % _pack.levels.size())

	var seen := {}
	var seen_definition_ids := {}
	for index in _pack.levels.size():
		var id_value := level_id(index)
		var label := String(id_value)
		if label.is_empty():
			errors.append("level_missing_id:%d" % index)
		elif seen.has(label):
			errors.append("duplicate_level_id:%s" % label)
		seen[label] = true

		var result := load_load_result(index)
		if not result.is_ok():
			errors.append("%s:load_failed:%s" % [label, ",".join(result.errors)])
			continue
		var definition := load_definition(index)
		if definition == null:
			errors.append("%s:definition_missing" % label)
			continue
		# Identity consistency: the manifest filename stem is the catalogue id,
		# but progression relies on the id inside the LevelDefinition. The
		# official convention is `filename stem == definition.level_id`, and the
		# ACTUAL definition id must be unique across the pack (two different
		# filenames may not resolve to the same internal id).
		errors.append_array(validate_level_identity(_pack.levels[index], definition))
		# Track the ACTUAL definition ids so a malformed pack whose files share an
		# internal id is rejected even when the filenames differ.
		var definition_id := String(definition.level_id)
		if seen_definition_ids.has(definition_id):
			errors.append("DUPLICATE_DEFINITION_LEVEL_ID:%s" % definition_id)
		seen_definition_ids[definition_id] = true
		for error in LevelValidator.validate(definition):
			errors.append("%s:%s" % [label, error])
	return errors


## Deterministic identity check for one manifest entry. Returns machine-readable
## errors; empty means the file and its definition agree. Extracted so malformed
## fixtures can be tested without touching production content files.
static func validate_level_identity(file_name: String, definition: LevelDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	var filename_id := filename_level_id(file_name)
	if definition == null:
		errors.append("LEVEL_IDENTITY_MISSING_DEFINITION:%s" % String(filename_id))
		return errors
	var definition_id := String(definition.level_id)
	if String(filename_id) != definition_id:
		errors.append("LEVEL_ID_FILENAME_MISMATCH:%s:%s" % [String(filename_id), definition_id])
	return errors


## Catalogue id derived from a manifest filename (stem without `.json`).
static func filename_level_id(file_name: String) -> StringName:
	return _level_id_from_file(file_name)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_level_ids.clear()
	_pack = LevelPack.load_manifest(manifest_path())
	if _pack == null:
		return
	for file_name in _pack.levels:
		_level_ids.append(_level_id_from_file(file_name))


static func _level_id_from_file(file_name: String) -> StringName:
	return StringName(file_name.trim_suffix(".json"))
