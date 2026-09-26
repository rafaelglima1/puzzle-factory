extends "res://tests/framework/test_base.gd"
## M4 presentation settings store: defaults, persistence, malformed/foreign
## input safety, deterministic serialization. M10 save machinery is out of scope.

const TMP_DIR := "user://m4_tests"
const TMP_PATH := "user://m4_tests/presentation_settings_test.json"
const OTHER_PATH := "user://m4_tests/presentation_settings_test_b.json"


func run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

	_empty_path_is_safe()
	_defaults_when_missing()
	_toggles_persist_immediately()
	_music_and_sound_are_independent()
	_explicit_save_and_reload()
	_malformed_json_defaults_safely()
	_wrong_types_default_safely()
	_unsupported_version_is_untouched()
	_apply_writes_whole_set()
	_noop_setter_keeps_bytes()
	_deterministic_serialization()
	_reset_and_delete()
	_cleanup()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)
	if FileAccess.file_exists(OTHER_PATH):
		DirAccess.remove_absolute(OTHER_PATH)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "raw fixture writable: %s" % path)
	if file != null:
		file.store_string(text)
		file.close()


func _empty_path_is_safe() -> void:
	var store := M4PresentationSettingsStore.new("")
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.IO_ERROR, "empty path reports IO_ERROR on load")
	check_eq(store.music_enabled(), true, "empty path keeps enabled defaults")
	check_eq(store.save(), ERR_INVALID_PARAMETER, "empty path refuses to save")


func _defaults_when_missing() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.FILE_MISSING, "missing file reported")
	check_eq(store.version(), M4PresentationSettingsStore.SETTINGS_VERSION, "default schema version")
	check_eq(store.music_enabled(), true, "music defaults ON")
	check_eq(store.sound_enabled(), true, "sound defaults ON")
	check_eq(store.haptics_enabled(), true, "haptics defaults ON")
	check(not FileAccess.file_exists(TMP_PATH), "loading never creates the file")


func _toggles_persist_immediately() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	check_eq(store.set_sound_enabled(false), OK, "disabling sound persists immediately")
	check_eq(store.set_haptics_enabled(false), OK, "disabling haptics persists immediately")
	check(FileAccess.file_exists(TMP_PATH), "a real toggle created the file")

	# Fresh instance = app restart.
	var reopened := M4PresentationSettingsStore.new(TMP_PATH)
	check_eq(reopened.load_settings(), M4PresentationSettingsStore.LoadError.NONE, "reopened store loads")
	check_eq(reopened.sound_enabled(), false, "sound disabled persisted")
	check_eq(reopened.haptics_enabled(), false, "haptics disabled persisted")
	check_eq(reopened.music_enabled(), true, "music untouched by the other toggles")


func _music_and_sound_are_independent() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	store.set_music_enabled(false)
	store.set_sound_enabled(false)
	check_eq(store.save(), OK, "explicit save succeeds")
	var reopened := M4PresentationSettingsStore.new(TMP_PATH)
	reopened.load_settings()
	check_eq(reopened.music_enabled(), false, "music disabled persisted")
	check_eq(reopened.sound_enabled(), false, "sound disabled persisted")
	check_eq(reopened.haptics_enabled(), true, "haptics still enabled")


func _explicit_save_and_reload() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	store.apply(true, false, true)
	check_eq(store.save(), OK, "explicit save succeeds")
	store.save()
	var bytes := FileAccess.get_file_as_string(TMP_PATH)
	store.save()
	check_eq(FileAccess.get_file_as_string(TMP_PATH), bytes, "repeated saves are byte-identical")


func _malformed_json_defaults_safely() -> void:
	_cleanup()
	_write_raw(TMP_PATH, "{not valid json")
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_JSON, "malformed JSON reported")
	check(store.music_enabled(), "malformed JSON falls back to music ON")
	check(store.sound_enabled(), "malformed JSON falls back to sound ON")
	check(store.haptics_enabled(), "malformed JSON falls back to haptics ON")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), "{not valid json", "malformed file is never rewritten")

	# Recovery: a fresh save from the defaulted state works.
	check_eq(store.set_sound_enabled(false), OK, "save after malformed load succeeds")
	var recovered := M4PresentationSettingsStore.new(TMP_PATH)
	check_eq(recovered.load_settings(), M4PresentationSettingsStore.LoadError.NONE, "recovered file loads")
	check_eq(recovered.sound_enabled(), false, "recovered value restored")


func _wrong_types_default_safely() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)

	var stringy := JSON.stringify({
		"version": 1, "music_enabled": "yes", "sound_enabled": true, "haptics_enabled": true,
	})
	_write_raw(TMP_PATH, stringy)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_FORMAT, "string toggle reported as invalid")
	check(store.music_enabled(), "string toggle falls back to default")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), stringy, "wrong-typed file is never rewritten")

	var numeric := JSON.stringify({
		"version": 1, "music_enabled": 1, "sound_enabled": true, "haptics_enabled": true,
	})
	_write_raw(TMP_PATH, numeric)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_FORMAT, "numeric toggle is not coerced")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), numeric, "numeric-typed file is untouched")

	var missing := JSON.stringify({
		"version": 1, "music_enabled": true, "sound_enabled": true,
	})
	_write_raw(TMP_PATH, missing)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_FORMAT, "a missing toggle is reported as invalid")

	var bad_root := JSON.stringify([1, 2, 3])
	_write_raw(TMP_PATH, bad_root)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_FORMAT, "non-object root is reported as invalid")

	var no_version := JSON.stringify({
		"music_enabled": true, "sound_enabled": true, "haptics_enabled": true,
	})
	_write_raw(TMP_PATH, no_version)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.INVALID_FORMAT, "a missing version is reported as invalid")


func _unsupported_version_is_untouched() -> void:
	_cleanup()
	var payload := JSON.stringify({
		"version": 2, "music_enabled": false, "sound_enabled": false, "haptics_enabled": false,
	})
	_write_raw(TMP_PATH, payload)
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.UNSUPPORTED_VERSION, "future schema version reported")
	check(store.music_enabled() and store.sound_enabled() and store.haptics_enabled(), "future version falls back to enabled defaults")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), payload, "future version file is left untouched")


func _apply_writes_whole_set() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	check_eq(store.apply(false, false, false), OK, "apply persists a whole set in one write")
	check_eq(store.set_haptics_enabled(true), OK, "a single toggle after apply persists")
	var reopened := M4PresentationSettingsStore.new(TMP_PATH)
	reopened.load_settings()
	check_eq(reopened.music_enabled(), false, "apply persisted music")
	check_eq(reopened.sound_enabled(), false, "apply persisted sound")
	check_eq(reopened.haptics_enabled(), true, "later toggle overrides the applied value")


func _noop_setter_keeps_bytes() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	store.set_sound_enabled(false)
	var bytes := FileAccess.get_file_as_string(TMP_PATH)
	check_eq(store.set_sound_enabled(false), OK, "setting the current value returns OK")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), bytes, "a no-op setter does not rewrite the file")


func _deterministic_serialization() -> void:
	_cleanup()
	var first := M4PresentationSettingsStore.new(TMP_PATH)
	first.load_settings()
	first.apply(false, true, false)

	var second := M4PresentationSettingsStore.new(OTHER_PATH)
	second.load_settings()
	second.set_haptics_enabled(false)
	second.set_music_enabled(false)

	check_eq(
		FileAccess.get_file_as_string(TMP_PATH),
		FileAccess.get_file_as_string(OTHER_PATH),
		"setter order does not affect the serialized bytes"
	)
	check_eq(first.snapshot(), second.snapshot(), "snapshots match")
	check(Serialization.is_primitive_tree(first.snapshot()), "persisted payload is primitive-only")
	check_eq(
		first.snapshot(),
		{"version": 1, "music_enabled": false, "sound_enabled": true, "haptics_enabled": false},
		"snapshot carries the exact schema keys and values"
	)
	check_eq(
		Serialization.to_json(first.snapshot()),
		'{"haptics_enabled":false,"music_enabled":false,"sound_enabled":true,"version":1}',
		"canonical JSON is key-sorted and stable"
	)


func _reset_and_delete() -> void:
	_cleanup()
	var store := M4PresentationSettingsStore.new(TMP_PATH)
	store.load_settings()
	store.apply(false, false, false)
	check(FileAccess.file_exists(TMP_PATH), "file exists before reset")
	store.reset()
	check_eq(store.music_enabled(), true, "reset re-enables music in memory")
	check_eq(store.sound_enabled(), true, "reset re-enables sound in memory")
	check_eq(store.haptics_enabled(), true, "reset re-enables haptics in memory")
	check(store.delete_settings_file(), "delete_settings_file removes the file")
	check(not FileAccess.file_exists(TMP_PATH), "file is gone after delete")
	check(not store.delete_settings_file(), "deleting a missing file reports false")
