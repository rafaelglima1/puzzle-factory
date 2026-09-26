extends "res://tests/framework/test_base.gd"
## M3 CROSS-LAYER application integration (real shell + real session + real
## presenter through the production app controller).
##
## Every scenario here drives the real stack:
##   TrafficM3AppController -> M3FirstPlayable shell -> shell tap hit test ->
##   TrafficFirstPlayableSession -> Simulation -> adapter/router -> presenter.

const Controller := preload("res://integration/traffic/traffic_m3_app_controller.gd")
const Shell := preload("res://themes/traffic/m3/m3_first_playable.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

const REF := Vector2(1080.0, 1920.0)
const TALL := Vector2(1080.0, 2400.0)
const TABLET := Vector2(1600.0, 2560.0)

const TMP_DIR := "user://m3_tests"

## Zero-based debug indices used by the scenarios below.
const L8_INDEX := 7

var _app_counter := 0


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_test_app_startup()
	_test_play_presents_real_level()
	_test_real_tap_wins_level_one()
	_test_next_starts_level_two()
	_test_fail_and_retry_debug_level()
	_test_restart_mid_level()
	_test_menu_reentry_loop()
	_test_synthetic_mouse_guard()
	_test_input_dedupe_one_command_per_tap()
	_test_responsive_real_boards()


# --- harness ------------------------------------------------------------------

func _make_app(viewport: Vector2 = REF, debug_enabled: bool = true) -> Node:
	_app_counter += 1
	var path := "%s/app_%d_%d.json" % [TMP_DIR, Time.get_ticks_usec(), _app_counter]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var controller: Node = Controller.new()
	controller.set("progress_path", path)
	controller.set("debug_enabled", debug_enabled)
	controller.set("fallback_viewport", viewport)
	check(controller.call("start"), "app controller starts")
	controller.call("layout_for", viewport)
	return controller


func _free_app(controller: Node) -> void:
	controller.call("shutdown")
	controller.free()


func _shell(controller: Node) -> Node:
	return controller.get_shell()


func _session(controller: Node) -> TrafficFirstPlayableSession:
	return controller.get_session()


func _presenter(controller: Node) -> Variant:
	return controller.get_presenter()


## Taps a vehicle through the REAL shell hit test (same path as the input
## catcher), then settles the cosmetic movement/result sequence so the next tap
## is not blocked by presentation locks.
func _tap_vehicle(controller: Node, entity_id: StringName) -> StringName:
	var shell: Node = _shell(controller)
	var presenter: Variant = _presenter(controller)
	var view: Node2D = presenter.board_view.entity_view(entity_id)
	check(view != null, "vehicle '%s' has a visible view" % entity_id)
	if view == null:
		return &""
	var tapped: StringName = shell.call("handle_tap_at", view.position)
	_settle(controller)
	return tapped


func _settle(controller: Node) -> void:
	var presenter: Variant = _presenter(controller)
	presenter.call("advance", 0.7)
	presenter.call("skip_active_sequence")


func _count_find_label_text(node: Node, text: String) -> int:
	var count := 0
	if node is Label and (node as Label).text == text:
		count += 1
	for child: Node in node.get_children():
		count += _count_find_label_text(child, text)
	return count


# --- 1. app startup -----------------------------------------------------------

func _test_app_startup() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	check_eq(shell.call("state_name"), &"MAIN_MENU", "app boots into the main menu")
	check(shell.call("main_menu_visible"), "main menu is the visible screen")
	var menu: Node = shell.get_node("MainMenu")
	check_eq(menu.call("title_text"), "Project Traffic", "main menu shows the Project Traffic title")
	check(menu.call("play_button_visible"), "PLAY is available")
	check_eq(_count_find_label_text(shell, "Puzzle Factory"), 0, "the M0 placeholder is not the running UI")

	# Debug/release gating is applied deterministically by show_main_menu().
	check_eq(shell.call("state_name"), &"MAIN_MENU", "startup state remains MAIN_MENU")
	var debug_controller := _make_app(REF, true)
	check(_shell(debug_controller).get_node("MainMenu").call("level_select_visible"), "debug build shows level select")
	_free_app(debug_controller)
	var release_controller := _make_app(REF, false)
	var release_shell: Node = _shell(release_controller)
	check(not release_shell.get_node("MainMenu").call("level_select_visible"), "release build hides level select")
	check(not release_shell.call("show_debug_level_select"), "release build refuses the debug selector")
	check_eq(release_shell.call("state_name"), &"MAIN_MENU", "refused debug selector keeps the menu")
	_free_app(release_controller)
	_free_app(controller)


# --- 2. play presents a real level --------------------------------------------

func _test_play_presents_real_level() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	shell.call("press_play")
	check_eq(shell.call("state_name"), &"PLAYING", "PLAY switches to gameplay")
	check_eq(session.current_level_number(), 1, "fresh profile plays level 1")
	check_eq(shell.call("gameplay_level_text"), Strings.format_text(&"ui.level_n", [1]), "level 1 is shown")
	var presenter: Variant = _presenter(controller)
	check(presenter != null, "presenter is bound to the session")
	check_eq(presenter.board_view.entity_view_count(), 1, "real board shows level 1's vehicle")
	check_eq(presenter.staging_view.slot_count(), 4, "staging is configured from the level definition")
	check(controller.get_session().get_state().get_entity(&"v1") != null, "level 1 simulation state is live")
	_free_app(controller)


# --- 3. real tap -> simulation -> win -----------------------------------------

func _test_real_tap_wins_level_one() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	shell.call("press_play")
	var taps: Array = []
	shell.connect(&"entity_tapped", func(entity_id: StringName) -> void: taps.append(entity_id))

	var tapped: StringName = _tap_vehicle(controller, &"v1")
	check_eq(tapped, &"v1", "shell hit test resolves the visible vehicle")
	check_eq(taps.size(), 1, "one physical tap produces exactly one intent")
	check_eq(session.get_state().move_index, 1, "one tap produces exactly one dispatched command")
	check(session.get_state().is_won(), "the tapped move completes the level in the simulation")
	check_eq(shell.call("state_name"), &"WIN_RESULT", "the win result screen is shown")
	check_eq(_shell(controller).call("result_next_visible"), true, "non-final win offers NEXT")
	check_eq(controller.call("highest_unlocked_level"), 2, "winning level 1 unlocks level 2")

	# Persistence through the application layer (no manual load anywhere).
	var save_path: Variant = controller.get("progress_path")
	check(FileAccess.file_exists(save_path), "progression was saved by the app layer")
	var store := M3ProgressStore.new(save_path)
	check_eq(store.load_progress(), M3ProgressStore.LoadError.NONE, "saved profile reloads")
	check(store.is_level_completed(&"traffic_m3_l01_first_roll"), "completed level id persisted")
	_free_app(controller)


# --- 4. next ------------------------------------------------------------------

func _test_next_starts_level_two() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	shell.call("press_play")
	_tap_vehicle(controller, &"v1")
	check_eq(shell.call("state_name"), &"WIN_RESULT", "level 1 won before NEXT")
	shell.call("press_next")
	check_eq(session.current_level_number(), 2, "NEXT starts level 2")
	check_eq(shell.call("state_name"), &"PLAYING", "NEXT returns to gameplay")
	check_eq(shell.call("gameplay_level_text"), Strings.format_text(&"ui.level_n", [2]), "level 2 is shown")
	var presenter: Variant = _presenter(controller)
	check_eq(presenter.board_view.entity_view_count(), 2, "level 2 board shows its own vehicles")
	check_eq(session.get_state().move_index, 0, "level 2 starts with a fresh move count")
	check(not presenter.is_input_locked(), "level 2 starts with no stale presentation lock")
	_free_app(controller)


# --- 5. fail -> retry (debug-selected level) ----------------------------------

func _test_fail_and_retry_debug_level() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	var save_path: Variant = controller.get("progress_path")
	var save_existed := FileAccess.file_exists(save_path)

	# Debug select L8 (zero slots of staging) through the real shell surface.
	shell.call("press_level_select")
	check_eq(shell.call("state_name"), &"DEBUG_LEVEL_SELECT", "debug selector opens")
	check(shell.call("press_debug_index", L8_INDEX), "debug entry selects L8")
	check_eq(shell.call("state_name"), &"PLAYING", "debug selection starts the level")
	check_eq(session.current_level_index(), L8_INDEX, "debug level index")
	check(session.is_debug_attempt(), "debug attempt is flagged")

	# Wrong first vehicle (no matching passengers) loses with staging_full.
	var tapped: StringName = _tap_vehicle(controller, &"v2")
	check_eq(tapped, &"v2", "wrong vehicle tapped through the shell")
	check_eq(shell.call("state_name"), &"FAIL_RESULT", "failure shows the fail result screen")
	check(shell.call("result_retry_visible"), "fail result offers RETRY")
	check(_shell(controller).call("result_message_text").length() > 0, "fail result shows a localized message")

	shell.call("press_retry")
	check_eq(shell.call("state_name"), &"PLAYING", "RETRY returns to gameplay")
	check_eq(session.current_level_id(), &"traffic_m3_l08_no_room_to_wait", "RETRY rebuilds the same level")
	check(session.is_debug_attempt(), "retry stays a debug attempt")
	check_eq(session.get_state().move_index, 0, "retry resets the move count")
	check_eq(session.get_state().staging.occupied_count(), 0, "retry resets staging")
	check_eq(session.get_state().is_won(), false, "retry resets completion")
	check_eq(controller.call("highest_unlocked_level"), 1, "debug attempts never unlock production levels")
	check_eq(FileAccess.file_exists(save_path), save_existed, "debug attempts never create a save file")
	_free_app(controller)


# --- 6. restart ---------------------------------------------------------------

func _test_restart_mid_level() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	shell.call("press_level_select")
	shell.call("press_debug_index", L8_INDEX)
	var tapped: StringName = _tap_vehicle(controller, &"v1")
	check_eq(tapped, &"v1", "legal move tapped before restart")
	check_eq(session.get_state().move_index, 1, "one move consumed")
	check(not session.get_state().is_won(), "level unfinished")

	shell.call("press_restart")
	check_eq(shell.call("state_name"), &"PLAYING", "RESTART keeps the player in gameplay")
	var fresh := TrafficGameFactory.build(M3LevelCatalogue.definition(L8_INDEX))
	check(fresh != null, "fresh definition builds")
	if fresh != null:
		check(
			Serialization.values_equal(session.get_state().to_dictionary(), fresh.get_state().to_dictionary()),
			"restarted level equals a fresh build (entities, queues, staging, completion)"
		)
	check_eq(session.get_state().move_index, 0, "restart resets the move count")
	check_eq(_presenter(controller).board_view.entity_view_count(), 3, "restart rebuilds the presentation board")
	_free_app(controller)


# --- 7. menu / reentry --------------------------------------------------------

func _test_menu_reentry_loop() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	var router: Variant = session.get_adapter().router
	var subscribers_before: int = router.subscriber_count()
	var taps: Array = []
	var tap_handler := func(entity_id: StringName) -> void: taps.append(entity_id)
	shell.connect(&"entity_tapped", tap_handler)

	for cycle in 3:
		shell.call("press_play")
		check_eq(shell.call("state_name"), &"PLAYING", "cycle %d: PLAY enters gameplay" % cycle)
		check_eq(session.current_level_number(), 1, "cycle %d: fresh profile plays level 1" % cycle)
		shell.call("press_menu")
		check_eq(shell.call("state_name"), &"MAIN_MENU", "cycle %d: MENU returns to the main menu" % cycle)
		check_eq(
			router.subscriber_count(),
			subscribers_before,
			"cycle %d: no duplicated router subscriptions" % cycle
		)

	# One tap, one command, after the navigation loop.
	shell.call("press_play")
	taps.clear()
	var tapped: StringName = _tap_vehicle(controller, &"v1")
	check_eq(tapped, &"v1", "tap works after menu re-entry")
	check_eq(taps.size(), 1, "menu re-entry leaves exactly one intent callback")
	check_eq(session.get_state().move_index, 1, "one tap produces one command after re-entry")
	check_eq(router.subscriber_count(), subscribers_before, "taps do not add subscribers")
	shell.disconnect(&"entity_tapped", tap_handler)
	_free_app(controller)


# --- synthetic mouse guard (device-derived hardening) -------------------------

## Android delivers a touch event and then a synthetic mouse event for the same
## physical tap. When that tap changes the screen (a winning move shows the
## result screen), the synthetic mouse event must not activate the control that
## appeared under the finger. This was found on a physical device; the guard
## lifecycle is asserted here and the real behaviour was re-verified on device.
func _test_synthetic_mouse_guard() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true

	# Startup (show_main_menu) arms the guard; the first synthetic mouse event
	# is consumed exactly once.
	check_eq(shell.get("_swallow_next_mouse"), true, "startup arms the synthetic-mouse guard")
	shell.call("_input", mouse)
	check_eq(shell.get("_swallow_next_mouse"), false, "startup guard consumes one mouse event")

	# A screen change arms it again.
	shell.call("press_play")
	check_eq(shell.get("_swallow_next_mouse"), true, "screen change re-arms the guard")
	shell.call("_input", mouse)
	check_eq(shell.get("_swallow_next_mouse"), false, "next mouse event swallowed once")

	# Touch events themselves are never swallowed.
	shell.call("press_menu")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	shell.call("_input", touch)
	check_eq(shell.get("_swallow_next_mouse"), true, "touch events do not clear the mouse guard")
	_free_app(controller)


# --- input de-dupe ------------------------------------------------------------

func _test_input_dedupe_one_command_per_tap() -> void:
	var controller := _make_app()
	var shell: Node = _shell(controller)
	var session := _session(controller)
	shell.call("press_level_select")
	shell.call("press_debug_index", L8_INDEX)
	var gameplay: Node = shell.get_node("Gameplay")
	var presenter: Variant = _presenter(controller)

	# First tap through the real input handler (touch), like a phone tap.
	var v1: Node2D = presenter.board_view.entity_view(&"v1")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = v1.position
	gameplay.call("_on_tap_catcher_gui_input", touch)
	check_eq(session.get_state().move_index, 1, "one touch produces one command")
	_settle(controller)

	# Synthetic mouse event within the de-dupe window must NOT dispatch again.
	var v3: Node2D = presenter.board_view.entity_view(&"v3")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = v3.position
	gameplay.call("_on_tap_catcher_gui_input", mouse)
	check_eq(session.get_state().move_index, 1, "mouse-after-touch within 400 ms is ignored")
	_settle(controller)

	# A later touch still dispatches (the guard is a window, not a permanent lock).
	var late_touch := InputEventScreenTouch.new()
	late_touch.pressed = true
	late_touch.position = v3.position
	gameplay.call("_on_tap_catcher_gui_input", late_touch)
	check_eq(session.get_state().move_index, 2, "a later tap dispatches normally")
	_free_app(controller)


# --- responsive ----------------------------------------------------------------

func _test_responsive_real_boards() -> void:
	for viewport: Vector2 in [REF, TALL, TABLET]:
		var controller := _make_app(viewport)
		var shell: Node = _shell(controller)
		var presenter: Variant = _presenter(controller)
		shell.call("press_play")
		controller.call("layout_for", viewport)
		var board_rect: Rect2 = shell.call("board_rect")
		var staging_rect: Rect2 = shell.call("staging_rect")
		check(board_rect.size.x > 0.0 and board_rect.size.y > 0.0, "board laid out at %s" % viewport)
		check(
			board_rect.position.y >= 0.0 and board_rect.end.y <= viewport.y + 1.0,
			"board fits vertically at %s" % viewport
		)
		check(staging_rect.end.y <= viewport.y + 1.0, "staging visible inside the viewport at %s" % viewport)
		check(_tap_vehicle(controller, &"v1") == &"v1", "real vehicle tappable at %s" % viewport)
		check_eq(shell.call("state_name"), &"WIN_RESULT", "win result at %s" % viewport)
		var panel: Rect2 = shell.call("result_panel_rect")
		check(panel.size.x > 0.0 and panel.size.y > 0.0, "result panel usable at %s" % viewport)
		check(panel.position.y >= 0.0 and panel.end.y <= viewport.y + 1.0, "result panel inside the viewport at %s" % viewport)
		_free_app(controller)
