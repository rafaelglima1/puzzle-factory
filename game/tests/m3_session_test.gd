extends "res://tests/framework/test_base.gd"
## M3 session controller: flow, restart, next, debug select, presentation
## binding, terminal signals and disposal (real cross-layer wiring).

const Presenter := preload("res://themes/traffic/traffic_presenter.gd")

const TMP_DIR := "user://m3_tests"
const TMP_PATH := "user://m3_tests/session_progress.json"

const L1 := &"traffic_m3_l01_first_roll"
const L2 := &"traffic_m3_l02_two_lanes"
const L6 := &"traffic_m3_l06_the_blocker"
const L8 := &"traffic_m3_l08_no_room_to_wait"
const L10 := &"traffic_m3_l10_rush_hour"

const L6_INDEX := 5
const L8_INDEX := 7
const L10_INDEX := 9


class Recorder extends RefCounted:
	var started: Array = []
	var restarted: Array = []
	var won: Array = []
	var failed: Array = []
	var progress: Array = []
	var errors: Array = []
	var finished := 0

	func on_started(level_index: int, level_id: StringName) -> void:
		started.append([level_index, level_id])

	func on_restarted(level_index: int, level_id: StringName) -> void:
		restarted.append([level_index, level_id])

	func on_won(level_index: int, level_id: StringName) -> void:
		won.append([level_index, level_id])

	func on_failed(level_index: int, level_id: StringName, fail_reason: StringName) -> void:
		failed.append([level_index, level_id, fail_reason])

	func on_progress(highest_unlocked_level: int) -> void:
		progress.append(highest_unlocked_level)

	func on_error(code: StringName) -> void:
		errors.append(code)

	func on_finished() -> void:
		finished += 1


func run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TMP_DIR)

	_new_session_flow_and_debug_select()
	_solve_first_level_end_to_end()
	_win_unlocks_and_next_level()
	_restart_resets_level_but_keeps_progress()
	_failure_emits_once()
	_terminal_at_the_last_level()
	_switching_levels_drops_previous_state()
	_blocked_dispatch_is_atomic()
	_disposal_releases_router_wiring()

	_cleanup()


func _cleanup() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _make_session() -> Dictionary:
	var store := M3ProgressStore.new(TMP_PATH)
	store.load_progress()
	var session := TrafficFirstPlayableSession.new(store)
	var presenter: Variant = Presenter.new()
	presenter.build()
	var bound: bool = session.bind_presentation(presenter)
	presenter.layout_for(Vector2(1080, 1920))
	var recorder := Recorder.new()
	session.level_started.connect(Callable(recorder, "on_started"))
	session.level_restarted.connect(Callable(recorder, "on_restarted"))
	session.level_won.connect(Callable(recorder, "on_won"))
	session.level_failed.connect(Callable(recorder, "on_failed"))
	session.progress_changed.connect(Callable(recorder, "on_progress"))
	session.session_error.connect(Callable(recorder, "on_error"))
	session.campaign_finished.connect(Callable(recorder, "on_finished"))
	return {"session": session, "store": store, "presenter": presenter, "bound": bound, "recorder": recorder}


func _dispose(context: Dictionary) -> void:
	var session: TrafficFirstPlayableSession = context["session"]
	var presenter: Variant = context["presenter"]
	session.dispose()
	presenter.teardown()
	presenter.free()


func _new_session_flow_and_debug_select() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var recorder: Recorder = context["recorder"]
	check(context["bound"], "presenter binds through the production API")
	check_eq(session.total_levels(), 10, "session exposes ten levels")
	check_eq(session.current_level_number(), 0, "no level active before play")
	check(not session.has_active_level(), "session starts without an active level")
	check(session.dispatch_entity(&"v1") == null, "dispatch without a level returns null")
	check(recorder.errors.has(TrafficFirstPlayableSession.ERROR_NO_ACTIVE_LEVEL), "no-active-level error emitted")

	check(session.play(), "play starts the campaign")
	check_eq(session.current_level_index(), 0, "play starts at index 0")
	check_eq(session.current_level_number(), 1, "play starts at level number 1")
	check_eq(session.current_level_id(), L1, "play starts at level 1 id")
	check_eq(recorder.started.size(), 1, "level_started emitted once")
	check(session.is_level_unlocked(0), "level 1 is unlocked")
	check(not session.is_level_unlocked(5), "later levels are locked for a new profile")

	check(not session.start_level(5), "locked level cannot be started normally")
	check(recorder.errors.has(TrafficFirstPlayableSession.ERROR_INVALID_LEVEL_INDEX), "locked start reports an error")
	check(session.debug_select_level(L6_INDEX), "debug select starts any level")
	check_eq(session.current_level_index(), L6_INDEX, "debug select moved to the requested index")
	var errors_before := recorder.errors.size()
	check(not session.debug_select_level(10), "debug select rejects an out-of-range index")
	check(not session.debug_select_level(-1), "debug select rejects a negative index")
	check_eq(recorder.errors.size(), errors_before + 2, "invalid debug selections emit errors")
	_dispose(context)


func _solve_first_level_end_to_end() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var presenter: Variant = context["presenter"]
	var recorder: Recorder = context["recorder"]
	check(session.play(), "level 1 starts")
	check_eq(presenter.board_view.entity_view_count(), 1, "presenter shows the level board")

	var result: CommandResult = session.dispatch_entity(&"v1")
	check(result != null and result.is_success(), "valid dispatch succeeds")
	check(session.get_adapter().forwarded_event_count > 0, "events were forwarded to presentation through the adapter")
	check_eq(session.get_state().is_won(), true, "simulation is authoritative: level won")
	check_eq(recorder.won.size(), 1, "level_won emitted exactly once")
	check_eq(recorder.progress.size(), 1, "progress_changed emitted once")
	check_eq(session.highest_unlocked_level(), 2, "winning level 1 unlocks level 2")
	check_eq(context["store"].highest_unlocked_level(), 2, "progress store updated")
	check(FileAccess.file_exists(TMP_PATH), "progress was persisted")
	check_eq(presenter.active_sequence(), &"win", "presenter ran the win sequence")
	var destination_view: Node2D = presenter.board_view.destination_view(&"station_a")
	check(destination_view != null and destination_view.queue_size() == 0, "authoritative queue synced to presentation")

	# Terminal guard: no second win signal, no state mutation from another dispatch.
	var again: CommandResult = session.dispatch_entity(&"v1")
	check(again != null and not again.is_success(), "dispatch after the win is rejected")
	check_eq(recorder.won.size(), 1, "win still emitted exactly once")
	check_eq(recorder.progress.size(), 1, "progress still emitted once")
	check(session.progress_snapshot().has("completion_state"), "progress snapshot available for the HUD")
	check(Serialization.is_primitive_tree(session.progress_snapshot()), "progress snapshot is primitive-only")

	# Finish the cosmetic animation: the completed vehicle leaves the board.
	presenter.advance(2.0)
	check(presenter.board_view.entity_view(&"v1") == null, "completed vehicle left the presentation board")

	# Persistence across "app restart": a new store instance reads the unlock.
	var reopened := M3ProgressStore.new(TMP_PATH)
	check_eq(reopened.load_progress(), M3ProgressStore.LoadError.NONE, "persisted progress reloads")
	check(reopened.is_level_completed(L1), "completed level id persisted")
	check_eq(reopened.highest_unlocked_level(), 2, "unlock persisted across restart")
	_dispose(context)


func _win_unlocks_and_next_level() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var recorder: Recorder = context["recorder"]
	session.play()
	check(not session.next_level(), "next_level is refused before winning")
	check(recorder.errors.has(TrafficFirstPlayableSession.ERROR_LEVEL_NOT_WON), "not-won error emitted")

	session.dispatch_entity(&"v1")
	check(session.next_level(), "next_level advances after a win")
	check_eq(session.current_level_index(), 1, "next level index")
	check_eq(session.current_level_id(), L2, "next level id")
	check_eq(recorder.started.size(), 2, "level_started emitted for the next level")
	check_eq(session.get_state().move_index, 0, "next level starts with a fresh move count")
	_dispose(context)


func _restart_resets_level_but_keeps_progress() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var recorder: Recorder = context["recorder"]
	check(session.debug_select_level(L8_INDEX), "L8 starts for the restart test")
	var first_result: CommandResult = session.dispatch_entity(&"v1")
	check(first_result.is_success(), "partial progress before restart")
	check_eq(session.get_state().move_index, 1, "one move consumed")
	check(not session.get_state().is_won(), "level is not finished yet")

	var highest_before := session.highest_unlocked_level()
	check(session.restart_current_level(), "restart_current_level rebuilds the level")
	check_eq(recorder.restarted.size(), 1, "level_restarted emitted once")

	var fresh := TrafficGameFactory.build(M3LevelCatalogue.definition(L8_INDEX))
	check(fresh != null, "fresh build of L8 succeeds")
	if fresh != null:
		check(
			Serialization.values_equal(session.get_state().to_dictionary(), fresh.get_state().to_dictionary()),
			"restarted state equals a fresh build of the same level"
		)
	check_eq(session.get_state().move_index, 0, "restart resets the move count")
	check_eq(session.get_state().staging.occupied_count(), 0, "restart resets staging")
	check_eq(session.get_state().is_won(), false, "restart resets completion")
	check_eq(session.highest_unlocked_level(), highest_before, "restart never loses progression")
	_dispose(context)


func _failure_emits_once() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var recorder: Recorder = context["recorder"]
	check(session.debug_select_level(L8_INDEX), "L8 starts for the failure test")
	var result: CommandResult = session.dispatch_entity(&"v2")
	check(result != null and result.code == &"staging_full", "zero-slot staging loses with staging_full")
	check_eq(recorder.failed.size(), 1, "level_failed emitted exactly once")
	check_eq(recorder.failed[0][2], &"staging_full", "failure reason forwarded from the simulation")
	var again: CommandResult = session.dispatch_entity(&"v1")
	check(again != null and not again.is_success(), "dispatch after a loss is rejected")
	check_eq(recorder.failed.size(), 1, "failure still emitted exactly once")
	_dispose(context)


func _terminal_at_the_last_level() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var recorder: Recorder = context["recorder"]
	check(session.debug_select_level(L10_INDEX), "final level starts")
	for entity_id in [&"v_block", &"v_b", &"v_c", &"v_d"]:
		var result: CommandResult = session.dispatch_entity(entity_id)
		check(result != null and result.is_success(), "final level command '%s' succeeds" % entity_id)
	check(session.get_state().is_won(), "final level is winnable through the session")
	check(not session.next_level(), "next_level at the final level returns false")
	check_eq(recorder.finished, 1, "campaign_finished emitted once")
	check_eq(session.current_level_index(), L10_INDEX, "session never indexes beyond the final level")
	check_eq(session.highest_unlocked_level(), 10, "final level remains the highest unlock")
	_dispose(context)


func _switching_levels_drops_previous_state() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var presenter: Variant = context["presenter"]
	session.play()
	check_eq(session.get_state().level_id, L1, "first level active")
	check(session.debug_select_level(L8_INDEX), "switch to another level")
	check_eq(session.get_state().level_id, L8, "state belongs to the new level")
	check_eq(session.get_state().move_index, 0, "new level starts fresh")
	check_eq(session.get_state().entity_ids().size(), 3, "new level has its own vehicles")
	check(session.get_state().get_entity(&"v1") != null, "new level entities are present")
	check(presenter.board_view.entity_view(&"v1") != null, "presentation shows the new level")
	check(session.debug_select_level(0), "switch back to the first level")
	check_eq(session.get_state().level_id, L1, "first level state restored fresh")
	check_eq(session.get_state().staging.slot_count, 4, "first level staging configuration applied")
	_dispose(context)


func _blocked_dispatch_is_atomic() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	check(session.debug_select_level(L6_INDEX), "blocker level starts")
	var before := session.get_state().to_dictionary()
	var result: CommandResult = session.dispatch_entity(&"v2")
	check(result != null and result.status == CommandResult.Status.BLOCKED, "blocked dispatch reports BLOCKED")
	check_eq(result.code, &"cell_occupied", "blocked code forwarded")
	check(
		Serialization.values_equal(before, session.get_state().to_dictionary()),
		"blocked dispatch through the session does not mutate state"
	)
	_dispose(context)


func _disposal_releases_router_wiring() -> void:
	_cleanup()
	var context := _make_session()
	var session: TrafficFirstPlayableSession = context["session"]
	var presenter: Variant = context["presenter"]
	session.play()
	check(session.has_presentation(), "presentation is bound")
	var router: Variant = session.get_adapter().router
	check(router.subscriber_count() > 0, "router has presenter subscribers")
	session.unbind_presentation()
	check_eq(router.subscriber_count(), 0, "unbinding clears router subscribers")
	check(not session.has_presentation(), "presentation reference released")
	check(is_instance_valid(presenter), "session never frees the presenter it does not own")
	session.dispose()
	check(not session.has_active_level(), "dispose drops the active level")
	presenter.teardown()
	presenter.free()
