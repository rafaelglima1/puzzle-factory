extends "res://tests/framework/test_base.gd"
## M3 campaign integration: all ten manual levels presented and driven to a
## final result through the real app controller + shell + session + presenter.
##
## The winning sequences come from the proven M3 solvability suite (single
## source of truth, test-only data).

const Controller := preload("res://integration/traffic/traffic_m3_app_controller.gd")
const Solvable := preload("res://tests/m3_levels_solvable_test.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

const REF := Vector2(1080.0, 1920.0)
const TMP_DIR := "user://m3_tests"


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_test_normal_campaign_all_ten_levels()
	_test_debug_sweep_all_ten_levels()


func _make_app(name: String) -> Node:
	var path := "%s/%s_%d.json" % [TMP_DIR, name, Time.get_ticks_usec()]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var controller: Node = Controller.new()
	controller.set("progress_path", path)
	controller.set("debug_enabled", true)
	controller.set("fallback_viewport", REF)
	check(controller.call("start"), "app controller starts")
	controller.call("layout_for", REF)
	return controller


func _free_app(controller: Node) -> void:
	controller.call("shutdown")
	controller.free()


func _tap_vehicle(controller: Node, entity_id: StringName) -> StringName:
	var shell: Node = controller.get_shell()
	var presenter: Variant = controller.get_presenter()
	var view: Node2D = presenter.board_view.entity_view(entity_id)
	check(view != null, "vehicle '%s' has a visible view" % entity_id)
	if view == null:
		return &""
	var tapped: StringName = shell.call("handle_tap_at", view.position)
	presenter.call("advance", 0.7)
	presenter.call("skip_active_sequence")
	return tapped


# --- normal campaign -----------------------------------------------------------

func _test_normal_campaign_all_ten_levels() -> void:
	var controller := _make_app("campaign")
	var shell: Node = controller.get_shell()
	var session: TrafficFirstPlayableSession = controller.get_session()
	check_eq(controller.call("highest_unlocked_level"), 1, "campaign starts with only level 1 unlocked")

	shell.call("press_play")
	var total: int = session.total_levels()
	check_eq(total, 10, "campaign has ten levels")

	for index in total:
		var level_id: StringName = session.current_level_id()
		check_eq(
			shell.call("state_name"),
			&"PLAYING",
			"level %d is playable through the campaign" % (index + 1)
		)
		check_eq(
			shell.call("gameplay_level_text"),
			Strings.format_text(&"ui.level_n", [index + 1]),
			"level %d indicator" % (index + 1)
		)
		var presenter: Variant = controller.get_presenter()
		check(presenter.board_view.entity_view_count() > 0, "level %d presents real vehicles" % (index + 1))
		check_eq(
			presenter.staging_view.slot_count(),
			int(M3LevelCatalogue.definition(index).get("staging_slots", 4)),
			"level %d presents the configured staging" % (index + 1)
		)

		var sequence: Array = Solvable.SOLUTIONS[String(level_id)]
		for entity_id in sequence:
			check_eq(
				_tap_vehicle(controller, entity_id),
				entity_id,
				"level %d: tap resolves '%s'" % [index + 1, entity_id]
			)
		check(session.get_state().is_won(), "level %d solved through real taps" % (index + 1))
		check_eq(shell.call("state_name"), &"WIN_RESULT", "level %d shows the win result" % (index + 1))
		check_eq(session.get_state().move_index, sequence.size(), "level %d command count" % (index + 1))
		check_eq(controller.call("last_session_error"), &"", "level %d produced no session error" % (index + 1))

		var is_final: bool = index + 1 >= total
		check_eq(
			shell.call("result_next_visible"),
			not is_final,
			"level %d %s NEXT" % [index + 1, "hides" if is_final else "offers"]
		)
		if is_final:
			# Terminal level: asking for NEXT must be safe and stay terminal.
			shell.call("press_next")
			check_eq(session.current_level_index(), total - 1, "campaign never indexes past the final level")
			check_eq(shell.call("state_name"), &"WIN_RESULT", "final level keeps the terminal result surface")
		else:
			check_eq(controller.call("highest_unlocked_level"), index + 2, "level %d unlocks the next" % (index + 1))
			shell.call("press_next")
			check_eq(session.current_level_index(), index + 1, "NEXT advances to level %d" % (index + 2))

	check_eq(controller.call("highest_unlocked_level"), 10, "campaign finished with all levels unlocked")
	var store := M3ProgressStore.new(controller.get("progress_path"))
	check_eq(store.load_progress(), M3ProgressStore.LoadError.NONE, "campaign progress persisted")
	check_eq(store.completed_count(), 10, "all ten completions persisted")
	_free_app(controller)


# --- debug sweep (presentation confidence, no progression) ---------------------

func _test_debug_sweep_all_ten_levels() -> void:
	var controller := _make_app("debug_sweep")
	var shell: Node = controller.get_shell()
	var session: TrafficFirstPlayableSession = controller.get_session()
	for index in session.total_levels():
		shell.call("press_level_select")
		check_eq(shell.call("state_name"), &"DEBUG_LEVEL_SELECT", "debug selector for level %d" % (index + 1))
		check(shell.call("press_debug_index", index), "debug entry %d selects" % index)
		check_eq(session.current_level_index(), index, "debug level index %d applied" % index)
		check_eq(shell.call("state_name"), &"PLAYING", "debug level %d playable" % (index + 1))
		var presenter: Variant = controller.get_presenter()
		check(presenter.board_view.entity_view_count() > 0, "debug level %d presents vehicles" % (index + 1))
		for entity_id in Solvable.SOLUTIONS[String(session.current_level_id())]:
			check_eq(_tap_vehicle(controller, entity_id), entity_id, "debug level %d tap '%s'" % [index + 1, entity_id])
		check_eq(shell.call("state_name"), &"WIN_RESULT", "debug level %d shows the win result" % (index + 1))
		check_eq(controller.call("last_session_error"), &"", "debug level %d produced no session error" % (index + 1))
	check_eq(controller.call("highest_unlocked_level"), 1, "debug sweep never wrote production progression")
	_free_app(controller)
