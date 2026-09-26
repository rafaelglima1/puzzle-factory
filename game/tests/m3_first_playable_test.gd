extends "res://tests/framework/test_base.gd"
## M3 first-playable shell tests (AGENT-2). Presentation only: mocks/view data,
## no core/puzzle imports. Follows the repo's headless component pattern
## (`Script.new()` -> `build()` -> drive -> `free()`).

const Shell := preload("res://themes/traffic/m3/m3_first_playable.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")
const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")

const REF := Vector2(1080.0, 1920.0)
const TALL := Vector2(1080.0, 2400.0)
const TABLET := Vector2(1600.0, 2560.0)


func run() -> void:
	_test_scene_loads()
	_test_main_menu()
	_test_play_intent()
	_test_gameplay_indicator()
	_test_entity_tap()
	_test_empty_tap()
	_test_locked_input()
	_test_intents()
	_test_win_result()
	_test_final_result()
	_test_fail_result()
	_test_debug_select()
	_test_debug_gate()
	_test_responsive()


func _make_shell(debug_enabled: bool) -> Variant:
	var shell = Shell.new()
	shell.debug_enabled = debug_enabled
	shell.build()
	shell.layout_for(REF)
	return shell


func _show_playing_with_board(shell: Variant) -> Variant:
	shell.show_playing(1, 10)
	var presenter = shell.get_traffic_presenter()
	presenter.setup(Mock.sample_board())
	shell.layout_for(REF)
	return presenter


func _test_scene_loads() -> void:
	var packed: Variant = load("res://themes/traffic/m3/m3_first_playable.tscn")
	check(packed is PackedScene, "M3 shell scene loads as a PackedScene")
	if not (packed is PackedScene):
		return
	var node: Node = packed.instantiate()
	check(node != null, "M3 shell scene instantiates")
	if node == null:
		return
	node.build()
	node.layout_for(REF)
	check_eq(node.current_state(), Shell.State.MAIN_MENU, "scene starts on the main menu")
	check(node.main_menu_visible(), "main menu visible after build")
	node.free()


func _test_main_menu() -> void:
	var shell = _make_shell(true)
	check_eq(shell.current_state(), Shell.State.MAIN_MENU, "starts on MAIN_MENU")
	check_eq(shell.state_name(), &"MAIN_MENU", "state name exposed")
	check(shell.main_menu_visible(), "main menu visible")
	check(not shell.gameplay_visible(), "gameplay hidden on the menu")
	check(not shell.result_visible(), "result hidden on the menu")
	check(not shell.debug_select_visible(), "debug selector hidden on the menu")
	shell.free()


func _test_play_intent() -> void:
	var shell = _make_shell(false)
	var count := [0]
	shell.play_requested.connect(func() -> void: count[0] += 1)
	shell.press_play()
	check_eq(count[0], 1, "Play emits play_requested exactly once")
	check_eq(shell.current_state(), Shell.State.MAIN_MENU, "presentation does not decide the next state")
	shell.free()


func _test_gameplay_indicator() -> void:
	var shell = _make_shell(false)
	shell.show_playing(3, 10)
	check_eq(shell.current_state(), Shell.State.PLAYING, "PLAYING state")
	check(shell.gameplay_visible(), "gameplay visible")
	check_eq(shell.gameplay_level_text(), "Level 3", "level indicator shows the supplied level")
	shell.set_progress(4, 10)
	check_eq(shell.gameplay_level_text(), "Level 4", "progress updates the level indicator")
	shell.free()


func _test_entity_tap() -> void:
	var shell = _make_shell(false)
	var presenter = _show_playing_with_board(shell)
	var view = presenter.board_view.entity_view(&"e_compact_a")
	check(view != null, "entity view exists on the board")
	if view == null:
		shell.free()
		return
	var tapped: Array = []
	shell.entity_tapped.connect(func(entity_id: StringName) -> void: tapped.append(entity_id))
	var result = shell.handle_tap_at(view.position)
	check_eq(result, &"e_compact_a", "tap on an entity returns its id")
	check_eq(tapped.size(), 1, "tap emits entity_tapped")
	check_eq(tapped[0], &"e_compact_a", "emitted id matches the tapped entity")
	shell.handle_tap_at(view.position)
	check_eq(tapped.size(), 2, "one tap -> one intent")
	shell.free()


func _test_empty_tap() -> void:
	var shell = _make_shell(false)
	_show_playing_with_board(shell)
	var tapped: Array = []
	shell.entity_tapped.connect(func(entity_id: StringName) -> void: tapped.append(entity_id))
	var result = shell.handle_tap_at(Vector2(2.0, 2.0))
	check_eq(result, &"", "tap on empty board returns no id")
	check_eq(tapped.size(), 0, "empty-space tap emits nothing")
	shell.free()


func _test_locked_input() -> void:
	var shell = _make_shell(false)
	var presenter = _show_playing_with_board(shell)
	var view = presenter.board_view.entity_view(&"e_compact_a")
	var tapped: Array = []
	shell.entity_tapped.connect(func(entity_id: StringName) -> void: tapped.append(entity_id))
	presenter.animate_path(&"e_compact_a", [Vector2i(1, 1), Vector2i(2, 1)])
	check(presenter.is_input_locked(), "moving entity requests an input lock")
	var ignored = shell.handle_tap_at(view.position)
	check_eq(ignored, &"", "tap ignored while input is locked")
	check_eq(tapped.size(), 0, "no intent emitted while locked")
	presenter.advance(1.0)
	check(not presenter.is_input_locked(), "lock auto-releases after the bounded move")
	var fresh = presenter.board_view.entity_view(&"e_van_b")
	var accepted = shell.handle_tap_at(fresh.position)
	check_eq(accepted, &"e_van_b", "tap works again after the lock releases")
	shell.free()


func _test_intents() -> void:
	var shell = _make_shell(false)
	var restarts := [0]
	var nexts := [0]
	var menus := [0]
	shell.restart_requested.connect(func() -> void: restarts[0] += 1)
	shell.next_requested.connect(func() -> void: nexts[0] += 1)
	shell.menu_requested.connect(func() -> void: menus[0] += 1)
	shell.press_restart()
	check_eq(restarts[0], 1, "restart button emits restart_requested")
	shell.show_win_result(1, false)
	shell.press_next()
	check_eq(nexts[0], 1, "NEXT emits next_requested")
	shell.press_menu()
	check_eq(menus[0], 1, "MENU emits menu_requested")
	shell.show_fail_result(1, &"STAGING_FULL")
	shell.press_retry()
	check_eq(restarts[0], 2, "RETRY maps to restart_requested")
	shell.free()


func _test_win_result() -> void:
	var shell = _make_shell(false)
	shell.show_win_result(3, false)
	check_eq(shell.current_state(), Shell.State.WIN_RESULT, "WIN_RESULT state")
	check(shell.result_visible(), "result overlay visible")
	check_eq(shell.result_title_text(), "LEVEL COMPLETE", "win title")
	check(shell.result_next_visible(), "NEXT visible on a non-final win")
	check(not shell.result_retry_visible(), "RETRY hidden on a win")
	check(shell.result_menu_visible(), "MENU visible on a win")
	shell.free()


func _test_final_result() -> void:
	var shell = _make_shell(false)
	shell.show_win_result(10, true)
	check(shell.result_title_text().contains("ALL"), "final-level title starts with ALL")
	check(shell.result_title_text().contains("10"), "final-level title includes the level count")
	check(not shell.result_next_visible(), "NEXT hidden on the final level")
	check(shell.result_menu_visible(), "MENU visible on the final level")
	shell.free()


func _test_fail_result() -> void:
	var shell = _make_shell(false)
	shell.show_fail_result(3, &"STAGING_FULL")
	check_eq(shell.current_state(), Shell.State.FAIL_RESULT, "FAIL_RESULT state")
	check_eq(shell.result_title_text(), "TRY AGAIN", "fail title")
	check(shell.result_message_text().contains(Strings.text(&"level.fail.staging_full")), "fail message resolves the supplied reason")
	check(not shell.result_message_text().contains("STAGING_FULL"), "raw reason names are never shown to users")
	check(shell.result_retry_visible(), "RETRY visible on a fail")
	check(not shell.result_next_visible(), "NEXT hidden on a fail")
	shell.show_fail_result(3, &"SOMETHING_NEW")
	check(shell.result_message_text().contains(Strings.text(&"level.fail.unknown")), "unknown reason falls back safely")
	shell.free()


func _test_debug_select() -> void:
	var shell = _make_shell(true)
	var selected: Array = []
	shell.debug_level_selected.connect(func(index: int) -> void: selected.append(index))
	check(shell.show_debug_level_select(), "debug selector opens when debug is enabled")
	check_eq(shell.current_state(), Shell.State.DEBUG_LEVEL_SELECT, "DEBUG_LEVEL_SELECT state")
	check(shell.debug_select_visible(), "debug selector visible")
	check_eq(shell.debug_entry_count(), 10, "ten debug level entries")
	check(shell.press_debug_index(3), "selecting level index 3 succeeds")
	check_eq(selected, [3], "debug_level_selected is zero-based (0..9)")
	shell.press_debug_index(9)
	check_eq(selected, [3, 9], "last zero-based index emits correctly")
	shell.free()


func _test_debug_gate() -> void:
	var shell = _make_shell(false)
	shell.show_main_menu()
	check(not shell.main_menu_level_select_visible(), "level-select entry hidden when debug is disabled")
	check(not shell.show_debug_level_select(), "debug selector refused when debug is disabled")
	check_eq(shell.current_state(), Shell.State.MAIN_MENU, "state unchanged when debug is refused")
	shell.free()


func _test_responsive() -> void:
	var shell = _make_shell(false)
	var presenter = _show_playing_with_board(shell)
	shell.debug_enabled = true
	for viewport: Vector2 in [REF, TALL, TABLET]:
		shell.show_playing(1, 10)
		shell.layout_for(viewport)
		var bounds := Rect2(Vector2.ZERO, viewport)

		var board_screen := Rect2(presenter.position + presenter.board_view.position, presenter.board_view.size)
		check(bounds.encloses(board_screen), "board inside viewport at %s" % viewport)
		check(board_screen.size.x > 0.0 and board_screen.size.y > 0.0, "board has area at %s" % viewport)

		var staging_screen := Rect2(presenter.position + presenter.staging_view.position, presenter.staging_view.size)
		check(bounds.encloses(staging_screen), "staging inside viewport at %s" % viewport)

		var buttons: Rect2 = shell.header_buttons_rect()
		check(buttons.size.x > 0.0 and buttons.size.y > 0.0, "header buttons sized at %s" % viewport)
		check(bounds.encloses(buttons), "header buttons inside viewport at %s" % viewport)

		shell.show_win_result(1, false)
		shell.layout_for(viewport)
		var result_panel: Rect2 = shell.result_panel_rect()
		check(result_panel.size.x > 0.0 and result_panel.size.y > 0.0, "result panel has area at %s" % viewport)
		check(bounds.encloses(result_panel), "result panel inside viewport at %s" % viewport)

		check(shell.show_debug_level_select(), "debug selector opens at %s" % viewport)
		shell.layout_for(viewport)
		var debug_panel: Rect2 = shell.debug_panel_rect()
		check(bounds.encloses(debug_panel), "debug panel inside viewport at %s" % viewport)

	shell.free()
