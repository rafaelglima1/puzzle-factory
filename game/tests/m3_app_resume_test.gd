extends "res://tests/framework/test_base.gd"
## M3 application resume + debug isolation (real app controller + shell + session).

const Controller := preload("res://integration/traffic/traffic_m3_app_controller.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

const REF := Vector2(1080.0, 1920.0)
const TMP_DIR := "user://m3_tests"

const L1 := &"traffic_m3_l01_first_roll"
const L5_INDEX := 4


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_test_app_resume_without_manual_load()
	_test_missing_and_malformed_saves()
	_test_debug_isolation_end_to_end()
	_test_release_gate_hides_debug_selector()


## `wipe_save` is opt-in: app-restart scenarios must keep the persisted profile
## of the previous run, so only tests that need a clean path delete it.
func _make_app(progress_path: String, debug_enabled: bool = true, wipe_save: bool = false) -> Node:
	if wipe_save and FileAccess.file_exists(progress_path):
		DirAccess.remove_absolute(progress_path)
	var controller: Node = Controller.new()
	controller.set("progress_path", progress_path)
	controller.set("debug_enabled", debug_enabled)
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


func _unique_path(name: String) -> String:
	return "%s/%s_%d.json" % [TMP_DIR, name, Time.get_ticks_usec()]


# --- app restart / resume ------------------------------------------------------

func _test_app_resume_without_manual_load() -> void:
	var path := _unique_path("resume")

	# Run A: a fresh app completes level 1 through the real UI and shuts down.
	var first := _make_app(path, true, true)
	first.get_shell().call("press_play")
	check_eq(_tap_vehicle(first, &"v1"), &"v1", "run A: level 1 solved through the shell")
	check_eq(first.call("highest_unlocked_level"), 2, "run A: level 2 unlocked")
	_free_app(first)

	# Run B: a brand-new app over the same persistence path. The caller never
	# calls load_progress(); the session/app must resume on its own.
	var second := _make_app(path)
	check_eq(second.call("highest_unlocked_level"), 2, "run B: persisted unlock recovered by the app")
	second.get_shell().call("press_play")
	check_eq(second.get_session().current_level_number(), 2, "run B: Play resumes at level 2")
	check_eq(second.get_shell().call("state_name"), &"PLAYING", "run B: gameplay resumes")
	check_eq(
		second.get_shell().call("gameplay_level_text"),
		Strings.format_text(&"ui.level_n", [2]),
		"run B: level 2 indicator"
	)
	_free_app(second)


func _test_missing_and_malformed_saves() -> void:
	var missing_path := _unique_path("missing")
	var missing := _make_app(missing_path, true, true)
	check_eq(missing.call("highest_unlocked_level"), 1, "missing save: fresh profile")
	missing.get_shell().call("press_play")
	check_eq(missing.get_session().current_level_number(), 1, "missing save: Play starts level 1")
	check(not FileAccess.file_exists(missing_path), "missing save is not created on boot")
	_free_app(missing)

	var malformed_path := _unique_path("malformed")
	var file := FileAccess.open(malformed_path, FileAccess.WRITE)
	check(file != null, "malformed fixture writable")
	if file != null:
		file.store_string("{not json at all")
		file.close()
	var malformed := _make_app(malformed_path)
	check_eq(malformed.call("highest_unlocked_level"), 1, "malformed save: clean default profile")
	malformed.get_shell().call("press_play")
	check_eq(malformed.get_session().current_level_number(), 1, "malformed save: Play starts level 1")
	check_eq(malformed.get_session().get_state().is_won(), false, "malformed save did not corrupt the level")
	_free_app(malformed)


# --- debug isolation -----------------------------------------------------------

func _test_debug_isolation_end_to_end() -> void:
	var path := _unique_path("debug_isolation")
	var controller := _make_app(path, true, true)
	var shell: Node = controller.get_shell()
	var session: TrafficFirstPlayableSession = controller.get_session()

	# Debug-select a locked level through the real selector UI and win it.
	shell.call("press_level_select")
	check(shell.call("press_debug_index", L5_INDEX), "debug selector starts locked L5")
	check_eq(session.current_level_index(), L5_INDEX, "debug level index applied")
	check(session.is_debug_attempt(), "debug attempt flagged")
	for entity_id in [&"v1", &"v2", &"v3"]:
		check_eq(_tap_vehicle(controller, entity_id), entity_id, "debug level solved via real taps")
	check(session.get_state().is_won(), "debug level won")
	check_eq(shell.call("state_name"), &"WIN_RESULT", "debug win still shows the win result")
	check_eq(controller.call("highest_unlocked_level"), 1, "debug win never unlocks production levels")
	check(not FileAccess.file_exists(path), "debug win never writes a save file")

	# Normal play afterwards still uses real production progression.
	shell.call("press_menu")
	check_eq(shell.call("state_name"), &"MAIN_MENU", "menu after the debug win")
	shell.call("press_play")
	check_eq(session.current_level_number(), 1, "normal Play still starts at level 1")
	check(not session.is_debug_attempt(), "normal play is not a debug attempt")
	check_eq(_tap_vehicle(controller, &"v1"), &"v1", "level 1 solved normally after the debug win")
	check_eq(controller.call("highest_unlocked_level"), 2, "normal play still persists progression")
	var store := M3ProgressStore.new(path)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.NONE, "normal completion persisted")
	check(store.is_level_completed(L1), "level 1 recorded")
	_free_app(controller)


func _test_release_gate_hides_debug_selector() -> void:
	var path := _unique_path("release_gate")
	var controller := _make_app(path, false, true)
	var shell: Node = controller.get_shell()
	check(not shell.get("debug_enabled"), "release-style app disables debug tooling")
	check(not shell.get_node("MainMenu").call("level_select_visible"), "level select hidden in release")
	shell.call("press_level_select")
	check_eq(shell.call("state_name"), &"MAIN_MENU", "release build cannot open the debug selector")
	check(not shell.call("debug_select_visible"), "debug screen stays hidden")
	check(not shell.call("press_debug_index", 0), "release build cannot select debug levels")
	shell.call("press_play")
	check_eq(shell.call("state_name"), &"PLAYING", "release build still plays normally")
	_free_app(controller)
