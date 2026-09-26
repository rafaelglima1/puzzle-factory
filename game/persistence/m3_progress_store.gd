class_name M3ProgressStore
extends RefCounted
## M3 minimal progress persistence — OWNER: AGENT-1.
##
## Blueprint M3 only requires "progress survives app restart". This is
## deliberately NOT the M10 save system: no coins, no economy, no boosters, no
## cloud, no backup file, no atomic temp+rename, no migration framework (all
## M10). One deterministic JSON document under `user://` (or an injected path
## for tests).
##
## Index convention: persisted level numbers are 1-based level NUMBERS
## (`1..total_levels`); level ids are the catalogue ids. The session layer owns
## the mapping between those and 0-based list indices.
##
## Payload (primitive-only, canonical JSON):
## {
##   "version": 1,
##   "highest_unlocked_level": 1,
##   "completed_level_ids": ["traffic_m3_l01_first_roll"],
##   "last_selected_level": 1
## }

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://m3_progress.json"
const MIN_LEVEL := 1

enum LoadError {
	NONE,
	FILE_MISSING,
	INVALID_JSON,
	INVALID_FORMAT,
	UNSUPPORTED_VERSION,
	IO_ERROR,
}

var save_path: String = DEFAULT_PATH
var last_load_error: int = LoadError.NONE
var last_save_error: Error = OK

var _version: int = SAVE_VERSION
var _highest_unlocked: int = MIN_LEVEL
var _last_selected: int = MIN_LEVEL
var _completed_ids: Array[String] = []


func _init(p_save_path: String = DEFAULT_PATH) -> void:
	save_path = p_save_path


# --- read API -----------------------------------------------------------------

## Loads the profile, always leaving a valid in-memory state. Missing or
## malformed files fall back to a clean default profile (never crashes, never
## rewrites or deletes the file — M10 owns recovery).
func load_progress() -> int:
	reset()
	last_load_error = LoadError.NONE
	if save_path.is_empty():
		last_load_error = LoadError.IO_ERROR
		return last_load_error
	if not FileAccess.file_exists(save_path):
		last_load_error = LoadError.FILE_MISSING
		return last_load_error

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_load_error = LoadError.IO_ERROR
		return last_load_error
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		last_load_error = LoadError.INVALID_JSON
		reset()
		return last_load_error
	if typeof(json.data) != TYPE_DICTIONARY:
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error

	var payload: Dictionary = json.data
	var version: Variant = _as_int(payload.get("version", null))
	if version == null:
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error
	if version > SAVE_VERSION:
		last_load_error = LoadError.UNSUPPORTED_VERSION
		reset()
		return last_load_error
	if version < SAVE_VERSION:
		# No migration exists yet (M10 owns it); treat as unsupported shape.
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error

	var highest: Variant = _as_int(payload.get("highest_unlocked_level", null))
	if highest == null or highest < MIN_LEVEL:
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error
	var last_selected: Variant = _as_int(payload.get("last_selected_level", null))
	if last_selected == null or last_selected < MIN_LEVEL:
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error

	var completed: Variant = payload.get("completed_level_ids", [])
	if typeof(completed) != TYPE_ARRAY:
		last_load_error = LoadError.INVALID_FORMAT
		reset()
		return last_load_error
	var ids: Array[String] = []
	for entry: Variant in completed:
		if typeof(entry) != TYPE_STRING and typeof(entry) != TYPE_STRING_NAME:
			last_load_error = LoadError.INVALID_FORMAT
			reset()
			return last_load_error
		var level_id_text := str(entry)
		if not level_id_text.is_empty() and not ids.has(level_id_text):
			ids.append(level_id_text)

	_version = version
	_highest_unlocked = highest
	_last_selected = last_selected
	ids.sort()
	_completed_ids = ids
	return last_load_error


func is_level_completed(level_id: StringName) -> bool:
	return _completed_ids.has(String(level_id))


func completed_level_ids() -> Array[String]:
	var copy: Array[String] = []
	copy.assign(_completed_ids)
	return copy


func completed_count() -> int:
	return _completed_ids.size()


## 1-based highest unlocked level number (>= 1).
func highest_unlocked_level() -> int:
	return _highest_unlocked


func last_selected_level() -> int:
	return _last_selected


func version() -> int:
	return _version


# --- write API ----------------------------------------------------------------

## Records a completion and unlocks the next level, clamped to
## [param total_levels]. Idempotent: repeating a completion changes nothing.
func mark_level_completed(level_id: StringName, level_number: int, total_levels: int) -> bool:
	if level_id == &"":
		return false
	var changed := false
	var level_id_text := String(level_id)
	if not _completed_ids.has(level_id_text):
		_completed_ids.append(level_id_text)
		_completed_ids.sort()
		changed = true
	var unlocked := _highest_unlocked
	if level_number >= MIN_LEVEL:
		unlocked = maxi(_highest_unlocked, mini(level_number + 1, maxi(total_levels, MIN_LEVEL)))
	if unlocked != _highest_unlocked:
		_highest_unlocked = unlocked
		changed = true
	return changed


func set_last_selected_level(level_number: int, total_levels: int) -> void:
	_last_selected = clampi(level_number, MIN_LEVEL, maxi(total_levels, MIN_LEVEL))


func reset() -> void:
	_version = SAVE_VERSION
	_highest_unlocked = MIN_LEVEL
	_last_selected = MIN_LEVEL
	_completed_ids = []


func to_dictionary() -> Dictionary:
	var ids: Array = []
	for level_id_text in _completed_ids:
		ids.append(level_id_text)
	return {
		"version": _version,
		"highest_unlocked_level": _highest_unlocked,
		"completed_level_ids": ids,
		"last_selected_level": _last_selected,
	}


## Writes the profile as canonical JSON. Creates the parent directory when the
## injected path needs one (e.g. test directories under `user://`).
func save() -> Error:
	last_save_error = OK
	if save_path.is_empty():
		last_save_error = ERR_INVALID_PARAMETER
		return last_save_error
	var parent := save_path.get_base_dir()
	if not parent.is_empty() and not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_save_error = FileAccess.get_open_error()
		return last_save_error
	file.store_string(Serialization.to_json(to_dictionary()))
	file.close()
	return last_save_error


## Deletes the persisted file (debug/tests only; the in-memory profile keeps
## its values unless [method reset] is called too).
func delete_save_file() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	return DirAccess.remove_absolute(save_path) == OK


# --- helpers ------------------------------------------------------------------

## JSON parses every number as float, so integral values are normalized back to
## int; non-integral or non-numeric values are rejected (no silent truncation).
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return null
