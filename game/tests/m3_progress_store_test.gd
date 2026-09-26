extends "res://tests/framework/test_base.gd"
## M3 basic progress store: defaults, unlock, persistence, corruption safety.

const TMP_DIR := "user://m3_tests"
const TMP_PATH := "user://m3_tests/progress_store_test.json"
const OTHER_PATH := "user://m3_tests/progress_store_test_b.json"

const LEVEL_1 := &"traffic_m3_l01_first_roll"
const LEVEL_2 := &"traffic_m3_l02_two_lanes"
const LEVEL_10 := &"traffic_m3_l10_rush_hour"


func run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

	_new_profile_defaults()
	_win_unlocks_next_and_persists()
	_repeated_completion_is_idempotent()
	_malformed_file_defaults_safely()
	_wrong_types_default_safely()
	_newer_version_is_untouched()
	_clamps_at_the_last_level()
	_last_selected_roundtrip()
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


func _new_profile_defaults() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.FILE_MISSING, "missing file reported")
	check_eq(store.highest_unlocked_level(), 1, "new profile starts at level 1")
	check_eq(store.last_selected_level(), 1, "new profile last selected is level 1")
	check_eq(store.completed_count(), 0, "new profile has no completions")
	check(not store.is_level_completed(LEVEL_1), "new profile has level 1 incomplete")
	check(not FileAccess.file_exists(TMP_PATH), "loading never creates the file")


func _win_unlocks_next_and_persists() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	check(store.mark_level_completed(LEVEL_1, 1, 10), "completing level 1 changes progress")
	check(store.is_level_completed(LEVEL_1), "level 1 recorded")
	check_eq(store.highest_unlocked_level(), 2, "level 2 unlocked")
	check_eq(store.save(), OK, "save succeeds")

	# A fresh instance (app restart) reads the persisted progress.
	var reopened := M3ProgressStore.new(TMP_PATH)
	check_eq(reopened.load_progress(), M3ProgressStore.LoadError.NONE, "reopened store loads")
	check(reopened.is_level_completed(LEVEL_1), "completion persisted")
	check_eq(reopened.highest_unlocked_level(), 2, "unlock persisted")
	check_eq(reopened.completed_count(), 1, "one completion after reopen")


func _repeated_completion_is_idempotent() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	store.mark_level_completed(LEVEL_1, 1, 10)
	check(not store.mark_level_completed(LEVEL_1, 1, 10), "repeating a completion does not change progress")
	check_eq(store.completed_count(), 1, "completion count stays stable")
	check_eq(store.highest_unlocked_level(), 2, "unlock stays stable")
	store.save()
	var first_bytes := FileAccess.get_file_as_string(TMP_PATH)
	store.save()
	check_eq(FileAccess.get_file_as_string(TMP_PATH), first_bytes, "repeated saves are byte-identical")
	var other := M3ProgressStore.new(LEVEL_2_PATH_UNUSED)
	check_eq(other.load_progress(), M3ProgressStore.LoadError.FILE_MISSING, "unused path stays empty")


const LEVEL_2_PATH_UNUSED := "user://m3_tests/progress_store_test_unused.json"


func _malformed_file_defaults_safely() -> void:
	_cleanup()
	_write_raw(TMP_PATH, "{not valid json")
	var store := M3ProgressStore.new(TMP_PATH)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.INVALID_JSON, "malformed JSON reported")
	check_eq(store.highest_unlocked_level(), 1, "malformed JSON falls back to level 1")
	check_eq(store.completed_count(), 0, "malformed JSON falls back to no completions")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), "{not valid json", "malformed file is never rewritten")
	# Recovery: a fresh save from the defaulted profile works.
	store.mark_level_completed(LEVEL_1, 1, 10)
	check_eq(store.save(), OK, "save after malformed load succeeds")
	var recovered := M3ProgressStore.new(TMP_PATH)
	check_eq(recovered.load_progress(), M3ProgressStore.LoadError.NONE, "recovered file loads")


func _wrong_types_default_safely() -> void:
	_cleanup()
	_write_raw(TMP_PATH, JSON.stringify({
		"version": 1,
		"highest_unlocked_level": "three",
		"completed_level_ids": [],
		"last_selected_level": 1,
	}))
	var store := M3ProgressStore.new(TMP_PATH)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.INVALID_FORMAT, "wrong numeric type reported")
	check_eq(store.highest_unlocked_level(), 1, "wrong numeric type falls back")

	_write_raw(TMP_PATH, JSON.stringify({
		"version": 1,
		"highest_unlocked_level": 1,
		"completed_level_ids": "nope",
		"last_selected_level": 1,
	}))
	check_eq(store.load_progress(), M3ProgressStore.LoadError.INVALID_FORMAT, "wrong array type reported")

	_write_raw(TMP_PATH, JSON.stringify({
		"version": 1,
		"highest_unlocked_level": 1,
		"completed_level_ids": [1.5],
		"last_selected_level": 1,
	}))
	check_eq(store.load_progress(), M3ProgressStore.LoadError.INVALID_FORMAT, "non-string level id reported")
	check_eq(store.completed_count(), 0, "invalid ids are not adopted")


func _newer_version_is_untouched() -> void:
	_cleanup()
	var payload := JSON.stringify({
		"version": 999,
		"highest_unlocked_level": 7,
		"completed_level_ids": [String(LEVEL_1)],
		"last_selected_level": 3,
	})
	_write_raw(TMP_PATH, payload)
	var store := M3ProgressStore.new(TMP_PATH)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.UNSUPPORTED_VERSION, "newer save version reported")
	check_eq(store.highest_unlocked_level(), 1, "newer version falls back to defaults")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), payload, "newer version file is left untouched")


func _clamps_at_the_last_level() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	store.mark_level_completed(LEVEL_10, 10, 10)
	check_eq(store.highest_unlocked_level(), 10, "completing level 10 keeps the last level unlocked")
	check(store.is_level_completed(LEVEL_10), "level 10 recorded")
	store.mark_level_completed(&"traffic_m3_out_of_range", 99, 10)
	check_eq(store.highest_unlocked_level(), 10, "unlock never exceeds the catalogue size")
	store.mark_level_completed(&"traffic_m3_zero", 0, 10)
	check_eq(store.highest_unlocked_level(), 10, "non-positive level numbers do not change unlocks")
	check_eq(store.completed_count(), 3, "completions are recorded independently of unlock clamping")
	check_eq(store.save(), OK, "clamped profile saves")
	var reopened := M3ProgressStore.new(TMP_PATH)
	reopened.load_progress()
	check_eq(reopened.highest_unlocked_level(), 10, "clamped unlock persisted (never 11)")


func _last_selected_roundtrip() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	store.set_last_selected_level(7, 10)
	check_eq(store.last_selected_level(), 7, "last selected set in range")
	store.set_last_selected_level(99, 10)
	check_eq(store.last_selected_level(), 10, "last selected clamps to the last level")
	store.set_last_selected_level(0, 10)
	check_eq(store.last_selected_level(), 1, "last selected clamps to the first level")
	store.set_last_selected_level(4, 10)
	store.save()
	var reopened := M3ProgressStore.new(TMP_PATH)
	reopened.load_progress()
	check_eq(reopened.last_selected_level(), 4, "last selected persists")


func _deterministic_serialization() -> void:
	_cleanup()
	var first := M3ProgressStore.new(TMP_PATH)
	first.load_progress()
	first.mark_level_completed(LEVEL_2, 2, 10)
	first.mark_level_completed(LEVEL_1, 1, 10)
	first.set_last_selected_level(2, 10)
	first.save()

	var second := M3ProgressStore.new(OTHER_PATH)
	second.load_progress()
	second.mark_level_completed(LEVEL_1, 1, 10)
	second.mark_level_completed(LEVEL_2, 2, 10)
	second.set_last_selected_level(2, 10)
	second.save()

	check_eq(
		FileAccess.get_file_as_string(TMP_PATH),
		FileAccess.get_file_as_string(OTHER_PATH),
		"completion order does not affect the serialized bytes"
	)
	check_eq(first.to_dictionary()["completed_level_ids"], [String(LEVEL_1), String(LEVEL_2)], "completed ids are sorted and unique")
	check(Serialization.is_primitive_tree(first.to_dictionary()), "persisted payload is primitive-only")


func _reset_and_delete() -> void:
	_cleanup()
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	store.mark_level_completed(LEVEL_1, 1, 10)
	store.save()
	check(FileAccess.file_exists(TMP_PATH), "save file exists before reset")
	store.reset()
	check_eq(store.highest_unlocked_level(), 1, "reset clears unlocks in memory")
	check_eq(store.completed_count(), 0, "reset clears completions in memory")
	check(store.delete_save_file(), "delete_save_file removes the file")
	check(not FileAccess.file_exists(TMP_PATH), "file is gone after delete")
	check(not store.delete_save_file(), "deleting a missing file reports false")
