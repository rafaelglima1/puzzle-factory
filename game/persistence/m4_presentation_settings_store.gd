class_name M4PresentationSettingsStore
extends RefCounted
## M4 presentation preference persistence — OWNER: AGENT-1.
##
## Blueprint M4 acceptance requires "audio settings persist" and "haptics can be
## disabled" (MASTER_BLUEPRINT.md §M4). This is the smallest store that
## satisfies the infrastructure half: three player switches under one versioned
## JSON document.
##
## Deliberately NOT the M10 save system: no economy, no progression, no backup
## file, no atomic temp+rename, no checksum, no migration framework, no recovery
## chain (all M10). It also does not share the M3 progression file
## (`user://m3_progress.json`). M10 consolidates player data — including these
## switches — behind the versioned save schema; this store is expected to be
## folded into `settings` at that point.
##
## It never knows how the switches are rendered or consumed: presentation owns
## that, and `game/presentation`-side code must not import this file. The
## integration layer drives it (see docs/M4_PRESENTATION_SETTINGS.md).
##
## Payload (primitive-only, canonical JSON; keys are canonical-sorted by
## `Serialization.to_json`, so the document is byte-stable):
## {
##   "version": 1,
##   "haptics_enabled": true,
##   "music_enabled": true,
##   "sound_enabled": true
## }

const SETTINGS_VERSION := 1
const DEFAULT_PATH := "user://m4_presentation_settings.json"

enum LoadError {
	NONE,
	FILE_MISSING,
	INVALID_JSON,
	INVALID_FORMAT,
	UNSUPPORTED_VERSION,
	IO_ERROR,
}

var settings_path: String = DEFAULT_PATH
var last_load_error: int = LoadError.NONE
var last_save_error: Error = OK

var _version: int = SETTINGS_VERSION
var _music_enabled := true
var _sound_enabled := true
var _haptics_enabled := true


func _init(p_settings_path: String = DEFAULT_PATH) -> void:
	settings_path = p_settings_path


# --- read API -----------------------------------------------------------------

## Loads the preferences, always leaving a valid in-memory state. Missing or
## malformed files fall back to the enabled defaults; loading never crashes,
## never writes, and never rewrites or deletes the source file (M10 owns
## recovery). Returns one of the `LoadError` values.
func load_settings() -> int:
	reset()
	last_load_error = LoadError.NONE
	if settings_path.is_empty():
		last_load_error = LoadError.IO_ERROR
		return last_load_error
	if not FileAccess.file_exists(settings_path):
		last_load_error = LoadError.FILE_MISSING
		return last_load_error

	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		last_load_error = LoadError.IO_ERROR
		return last_load_error
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		last_load_error = LoadError.INVALID_JSON
		return last_load_error
	if typeof(json.data) != TYPE_DICTIONARY:
		last_load_error = LoadError.INVALID_FORMAT
		return last_load_error

	var payload: Dictionary = json.data
	var version: Variant = _as_int(payload.get("version", null))
	if version == null:
		last_load_error = LoadError.INVALID_FORMAT
		return last_load_error
	if version > SETTINGS_VERSION:
		last_load_error = LoadError.UNSUPPORTED_VERSION
		return last_load_error
	if version < SETTINGS_VERSION:
		# No migration exists yet (M10 owns it); treat as an unsupported shape.
		last_load_error = LoadError.INVALID_FORMAT
		return last_load_error

	var music: Variant = _as_bool(payload.get("music_enabled", null))
	var sound: Variant = _as_bool(payload.get("sound_enabled", null))
	var haptics: Variant = _as_bool(payload.get("haptics_enabled", null))
	if music == null or sound == null or haptics == null:
		last_load_error = LoadError.INVALID_FORMAT
		return last_load_error

	_version = version
	_music_enabled = music
	_sound_enabled = sound
	_haptics_enabled = haptics
	return last_load_error


func music_enabled() -> bool:
	return _music_enabled


func sound_enabled() -> bool:
	return _sound_enabled


func haptics_enabled() -> bool:
	return _haptics_enabled


func version() -> int:
	return _version


## Canonical, primitive-only view of the current preferences. Safe to forward
## to presentation as the "apply these settings" payload.
func snapshot() -> Dictionary:
	return to_dictionary()


func to_dictionary() -> Dictionary:
	return {
		"version": _version,
		"music_enabled": _music_enabled,
		"sound_enabled": _sound_enabled,
		"haptics_enabled": _haptics_enabled,
	}


# --- write API ----------------------------------------------------------------

## Toggles persist immediately (the UI-facing path): a change that actually
## changes state is written to disk before returning. Setting a value it already
## has is a no-op and does not touch the file. Returns the `Error` from the
## write, or `OK` when nothing changed.
func set_music_enabled(value: bool) -> Error:
	if value == _music_enabled:
		return OK
	_music_enabled = value
	return save()


func set_sound_enabled(value: bool) -> Error:
	if value == _sound_enabled:
		return OK
	_sound_enabled = value
	return save()


func set_haptics_enabled(value: bool) -> Error:
	if value == _haptics_enabled:
		return OK
	_haptics_enabled = value
	return save()


## Applies a whole preference set in one write (e.g. restoring a snapshot).
func apply(music: bool, sound: bool, haptics: bool) -> Error:
	var changed := music != _music_enabled or sound != _sound_enabled or haptics != _haptics_enabled
	_music_enabled = music
	_sound_enabled = sound
	_haptics_enabled = haptics
	if not changed:
		return OK
	return save()


func reset() -> void:
	_version = SETTINGS_VERSION
	_music_enabled = true
	_sound_enabled = true
	_haptics_enabled = true


## Writes the preferences as canonical JSON. Creates the parent directory when
## the injected path needs one (e.g. test directories under `user://`).
func save() -> Error:
	last_save_error = OK
	if settings_path.is_empty():
		last_save_error = ERR_INVALID_PARAMETER
		return last_save_error
	var parent := settings_path.get_base_dir()
	if not parent.is_empty() and not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		last_save_error = FileAccess.get_open_error()
		return last_save_error
	file.store_string(Serialization.to_json(to_dictionary()))
	file.close()
	return last_save_error


## Deletes the persisted file (debug/tests only; the in-memory values are kept
## unless [method reset] is called too).
func delete_settings_file() -> bool:
	if not FileAccess.file_exists(settings_path):
		return false
	return DirAccess.remove_absolute(settings_path) == OK


# --- helpers ------------------------------------------------------------------

## JSON parses every number as float, so integral values are normalized back to
## int; non-integral or non-numeric values are rejected (no silent truncation).
## Booleans are NOT accepted here (a settings version is a number).
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return null


## Strict boolean: only `true`/`false` are accepted. Numbers and strings are
## rejected so a wrong-typed field fails the load instead of being coerced.
static func _as_bool(value: Variant) -> Variant:
	if typeof(value) == TYPE_BOOL:
		return value
	return null
