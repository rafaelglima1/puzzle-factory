class_name LevelPack
extends RefCounted
## Manifest for an ordered collection of level files.
##
## The manifest is data: [method level_paths] resolves entries against a base
## directory while preserving manifest order. The concrete pack manifest is
## content owned by the product integration layer.

var pack_id: String = ""
var content_version: int = 0
var min_game_version: int = 0
var levels: Array[String] = []


static func from_dictionary(data: Dictionary) -> LevelPack:
	var pack := LevelPack.new()
	pack.pack_id = str(data.get("packId", ""))
	pack.content_version = int(data.get("contentVersion", 0))
	pack.min_game_version = int(data.get("minGameVersion", 0))
	var entries: Variant = data.get("levels", [])
	if typeof(entries) == TYPE_ARRAY:
		for entry in entries:
			pack.levels.append(str(entry))
	return pack


static func load_manifest(path: String) -> LevelPack:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return LevelPack.from_dictionary(data)


func to_dictionary() -> Dictionary:
	var entries: Array = []
	for level in levels:
		entries.append(level)
	return {
		"packId": pack_id,
		"contentVersion": content_version,
		"minGameVersion": min_game_version,
		"levels": entries,
	}


func level_paths(base_dir: String) -> Array[String]:
	var paths: Array[String] = []
	for level in levels:
		if base_dir.is_empty():
			paths.append(level)
		else:
			paths.append(base_dir.path_join(level))
	return paths


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if pack_id.is_empty():
		errors.append("EMPTY_PACK_ID")
	if content_version < 1:
		errors.append("INVALID_CONTENT_VERSION")
	if min_game_version < 0:
		errors.append("INVALID_MIN_GAME_VERSION")
	var seen := {}
	for level in levels:
		if level.is_empty():
			errors.append("EMPTY_LEVEL_ENTRY")
			continue
		if seen.has(level):
			errors.append("DUPLICATE_LEVEL:%s" % level)
		else:
			seen[level] = true
	return errors
