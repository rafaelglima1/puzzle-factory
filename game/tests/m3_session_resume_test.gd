extends "res://tests/framework/test_base.gd"
## Focused regression for the M3 resume seam: a freshly constructed production
## session recovers persisted progress WITHOUT the caller ever calling
## `load_progress()`.
##
## This is the blueprint M3 acceptance path:
##   app starts -> new session -> persisted progress loaded -> Play resumes
## at the highest unlocked level.

const TMP_DIR := "user://m3_tests"
const TMP_PATH := "user://m3_tests/resume_progress.json"
const MISSING_PATH := "user://m3_tests/resume_missing.json"
const MALFORMED_PATH := "user://m3_tests/resume_malformed.json"

const L1 := &"traffic_m3_l01_first_roll"
const L2 := &"traffic_m3_l02_two_lanes"
const L5 := &"traffic_m3_l05_tight_parking"
const L8 := &"traffic_m3_l08_no_room_to_wait"


func run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

	_persisted_progress_resumes_without_manual_load()
	_missing_save_starts_at_level_one()
	_malformed_save_starts_at_level_one()
	_debug_selection_does_not_touch_production_progress()

	_cleanup()


func _cleanup() -> void:
	for path in [TMP_PATH, MISSING_PATH, MALFORMED_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _persisted_progress_resumes_without_manual_load() -> void:
	# "App run 1": the player completes level 1 and the app shuts down.
	var first_run := M3ProgressStore.new(TMP_PATH)
	first_run.load_progress()
	check(first_run.mark_level_completed(L1, 1, 10), "level 1 recorded during the first run")
	check_eq(first_run.save(), OK, "progress persisted before shutdown")

	# "App run 2": a brand-new store + session over the same path. The caller
	# deliberately does NOT call load_progress().
	var resumed_store := M3ProgressStore.new(TMP_PATH)
	var session := TrafficFirstPlayableSession.new(resumed_store)
	check_eq(resumed_store.last_load_error, M3ProgressStore.LoadError.NONE, "the session performed the disk load")
	check_eq(session.highest_unlocked_level(), 2, "session recovered the persisted unlock")
	check(session.play(), "Play succeeds from the recovered profile")
	check_eq(session.current_level_index(), 1, "Play resumes at level 2 without a manual load")
	check_eq(session.current_level_id(), L2, "resumed level id")
	session.dispose()


func _missing_save_starts_at_level_one() -> void:
	var store := M3ProgressStore.new(MISSING_PATH)
	var session := TrafficFirstPlayableSession.new(store)
	check_eq(store.last_load_error, M3ProgressStore.LoadError.FILE_MISSING, "missing save reported by the session load")
	check_eq(session.highest_unlocked_level(), 1, "fresh install starts at level 1")
	check(session.play(), "Play works on a fresh install")
	check_eq(session.current_level_index(), 0, "fresh install plays level 1")
	check(not FileAccess.file_exists(MISSING_PATH), "the session never creates a save file on a fresh install")
	session.dispose()


func _malformed_save_starts_at_level_one() -> void:
	var file := FileAccess.open(MALFORMED_PATH, FileAccess.WRITE)
	check(file != null, "malformed fixture writable")
	if file != null:
		file.store_string("{definitely not json")
		file.close()

	var store := M3ProgressStore.new(MALFORMED_PATH)
	var session := TrafficFirstPlayableSession.new(store)
	check_eq(store.last_load_error, M3ProgressStore.LoadError.INVALID_JSON, "malformed save reported by the session load")
	check_eq(session.highest_unlocked_level(), 1, "malformed save falls back to level 1")
	check(session.play(), "malformed save does not crash Play")
	check_eq(session.current_level_index(), 0, "malformed save plays level 1")
	session.dispose()


func _debug_selection_does_not_touch_production_progress() -> void:
	# Rebuild the persisted profile: level 1 completed (level 2 unlocked).
	var prepare := M3ProgressStore.new(TMP_PATH)
	prepare.load_progress()
	prepare.mark_level_completed(L1, 1, 10)
	prepare.save()
	var file_before := FileAccess.get_file_as_string(TMP_PATH)

	var store := M3ProgressStore.new(TMP_PATH)
	var session := TrafficFirstPlayableSession.new(store)
	var wins: Array = []
	session.level_won.connect(func(level_index: int, level_id: StringName) -> void: wins.append([level_index, level_id]))

	# Start a locked level through the debug path and win it.
	check(session.debug_select_level(4), "debug select starts a locked level")
	check(session.is_debug_attempt(), "the attempt is flagged as debug")
	check_eq(session.current_level_id(), L5, "debug level id")
	for entity_id in [&"v1", &"v2", &"v3"]:
		var result: CommandResult = session.dispatch_entity(entity_id)
		check(result != null and result.is_success(), "debug level command '%s' succeeds" % entity_id)
	check(session.get_state().is_won(), "debug level is winnable")
	check_eq(wins.size(), 1, "debug win still emits level_won")
	check_eq(session.highest_unlocked_level(), 2, "debug win does not unlock production levels")
	check_eq(FileAccess.get_file_as_string(TMP_PATH), file_before, "debug win does not rewrite the save file")

	# Restart keeps the debug flag, so a restarted debug win is still isolated.
	check(session.restart_current_level(), "debug level restarts")
	check(session.is_debug_attempt(), "restart preserves the debug attempt flag")

	# A normal attempt still persists progression.
	check(session.start_level(1), "level 2 starts through the production path")
	check(not session.is_debug_attempt(), "normal attempts are not flagged as debug")
	for entity_id in [&"v1", &"v2"]:
		var normal_result: CommandResult = session.dispatch_entity(entity_id)
		check(normal_result != null and normal_result.is_success(), "level 2 command '%s' succeeds" % entity_id)
	check(session.get_state().is_won(), "level 2 won normally")
	check_eq(session.highest_unlocked_level(), 3, "a normal win still unlocks the next level")
	var persisted := M3ProgressStore.new(TMP_PATH)
	check_eq(persisted.load_progress(), M3ProgressStore.LoadError.NONE, "production progress persisted")
	check(persisted.is_level_completed(L2), "normal completion persisted")
	check(not persisted.is_level_completed(L5), "debug completion never persisted")
	session.dispose()
