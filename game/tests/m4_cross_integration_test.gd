extends "res://tests/framework/test_base.gd"
## M4 cross-layer integration (AGENT-1 / M4-INTEGRATOR).
##
## Drives the REAL app composition root (`TrafficM3AppController`) with the REAL
## session, shell, presenter, router, simulation, settings store, audio facade
## and haptic service. No fake gameplay authority.
##
## Covers: default settings, toggle+persist through the real Settings UI, app
## restart restore, malformed settings, persistence I/O failure, accepted-move
## valid-move feedback (the previously unused SFX seam), blocked feedback with
## Sound/Haptics off, deferred completion/failure sequences, the 350 ms result
## guard, audio bus routing, and controller recreate (no growth).

const Controller := preload("res://integration/traffic/traffic_m3_app_controller.gd")
const RecordingAudio := preload("res://tests/support/recording_audio.gd")
const ResultScreen := preload("res://themes/traffic/m3/result_screen.gd")
const Contract := preload("res://audio/audio_contract.gd")

const REF := Vector2(1080.0, 1920.0)
const TMP_DIR := "user://m4_tests"

const L2_INDEX := 1   # traffic_m3_l02_two_lanes (accepted move, not a win)
const L6_INDEX := 5   # traffic_m3_l06_the_blocker (deterministic blocked first move)
const L8_INDEX := 7   # traffic_m3_l08_no_room_to_wait (deterministic staging_full fail)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	_cleanup()

	_test_a_defaults()
	_test_b_toggle_and_persist()
	_test_c_settings_app_restart()
	_test_d_malformed_settings()
	_test_e_persistence_io_failure()
	_test_f_accepted_move_valid_feedback()
	_test_g_blocked_move()
	_test_h_completion_sequence()
	_test_i_failure_sequence()
	_test_j_result_guard()
	_test_k_audio_bus_routing()
	_test_l_recreate_app_no_growth()

	_cleanup()


# --- harness ------------------------------------------------------------------

func _settings_path(name: String) -> String:
	return "%s/%s_settings.json" % [TMP_DIR, name]


func _progress_path(name: String) -> String:
	return "%s/%s_progress.json" % [TMP_DIR, name]


func _cleanup() -> void:
	for file in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute("%s/%s" % [TMP_DIR, file])
	for dir in DirAccess.get_directories_at(TMP_DIR):
		DirAccess.remove_absolute("%s/%s" % [TMP_DIR, dir])


func _make_app(name: String) -> Node:
	return _make_app_at(_settings_path(name), _progress_path(name))


func _make_app_at(settings_path: String, progress_path: String) -> Node:
	var controller: Node = Controller.new()
	controller.set("presentation_settings_path", settings_path)
	controller.set("progress_path", progress_path)
	controller.set("debug_enabled", true)
	controller.set("fallback_viewport", REF)
	check(controller.call("start"), "app controller starts")
	controller.call("layout_for", REF)
	return controller


func _free_app(app: Node) -> void:
	app.call("shutdown")
	app.free()


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "raw fixture writable: %s" % path)
	if file != null:
		file.store_string(text)
		file.close()


func _select_level(app: Node, index: int) -> void:
	var shell: Node = app.get_shell()
	shell.call("press_level_select")
	check(shell.call("press_debug_index", index), "debug entry %d selects" % index)


## Real shell hit test (same path as the input catcher). Does NOT settle.
func _tap_vehicle_raw(app: Node, entity_id: StringName) -> StringName:
	var shell: Node = app.get_shell()
	var presenter: Variant = app.call("get_presenter")
	var view: Node2D = presenter.board_view.entity_view(entity_id)
	check(view != null, "vehicle '%s' has a visible view" % entity_id)
	if view == null:
		return &""
	return shell.call("handle_tap_at", view.position)


## Tap then finish the cosmetic movement/sequence so locks cannot leak forward.
func _tap_vehicle(app: Node, entity_id: StringName) -> StringName:
	var tapped: StringName = _tap_vehicle_raw(app, entity_id)
	var presenter: Variant = app.call("get_presenter")
	presenter.call("advance", 0.7)
	presenter.call("skip_active_sequence")
	return tapped


## Installs the recording double so accepted SFX requests are observable.
func _install_recorder(app: Node) -> Variant:
	var presenter: Variant = app.call("get_presenter")
	var recorder: Variant = RecordingAudio.new()
	recorder.call("ensure_default_streams")
	presenter.set("audio", recorder)
	return recorder


## Drives the shell/presenter until a result overlay is revealed.
func _advance_until_result(app: Node, max_steps: int = 80) -> void:
	var shell: Node = app.get_shell()
	for _step in max_steps:
		var state: StringName = shell.call("state_name")
		if state == &"WIN_RESULT" or state == &"FAIL_RESULT":
			return
		app.call("advance", 0.1)


# --- TEST A: default settings -------------------------------------------------

func _test_a_defaults() -> void:
	_cleanup()
	var app := _make_app("a_defaults")
	var shell: Node = app.get_shell()
	var presenter: Variant = app.call("get_presenter")
	check_eq(shell.call("music_enabled"), true, "A: music defaults ON")
	check_eq(shell.call("sound_enabled"), true, "A: sound defaults ON")
	check_eq(shell.call("haptics_enabled"), true, "A: haptics defaults ON")
	check(presenter.call("is_music_enabled"), "A: runtime music gate ON")
	check(presenter.call("is_sound_enabled"), "A: runtime sound gate ON")
	check(presenter.call("is_haptics_enabled"), "A: runtime haptics gate ON")
	check_eq(
		app.call("last_settings_load_error"),
		M4PresentationSettingsStore.LoadError.FILE_MISSING,
		"A: first run reports a missing file"
	)
	check(not FileAccess.file_exists(_settings_path("a_defaults")), "A: startup load never creates the settings file")
	_free_app(app)


# --- TEST B: toggle + persist through the real Settings UI --------------------

func _test_b_toggle_and_persist() -> void:
	_cleanup()
	var app := _make_app("b_toggle")
	var shell: Node = app.get_shell()
	var presenter: Variant = app.call("get_presenter")
	var settings: Node = shell.call("get_settings_screen")

	shell.call("press_settings")
	check_eq(shell.call("state_name"), &"SETTINGS", "B: settings screen opened")
	settings.call("press_music")
	settings.call("press_sound")
	settings.call("press_haptics")

	check_eq(shell.call("music_enabled"), false, "B: shell music OFF")
	check_eq(shell.call("sound_enabled"), false, "B: shell sound OFF")
	check_eq(shell.call("haptics_enabled"), false, "B: shell haptics OFF")
	check(not presenter.call("is_music_enabled"), "B: runtime music gate OFF immediately")
	check(not presenter.call("is_sound_enabled"), "B: runtime sound gate OFF immediately")
	check(not presenter.call("is_haptics_enabled"), "B: runtime haptics gate OFF immediately")
	check_eq(app.call("last_settings_save_error"), OK, "B: persistence reported success")

	var path := _settings_path("b_toggle")
	check(FileAccess.file_exists(path), "B: a settings file now exists")
	var store := M4PresentationSettingsStore.new(path)
	check_eq(store.load_settings(), M4PresentationSettingsStore.LoadError.NONE, "B: persisted file loads")
	check(not store.music_enabled(), "B: store music OFF")
	check(not store.sound_enabled(), "B: store sound OFF")
	check(not store.haptics_enabled(), "B: store haptics OFF")
	_free_app(app)


# --- TEST C: settings survive app recreation ----------------------------------

func _test_c_settings_app_restart() -> void:
	_cleanup()
	var run_a := _make_app("c_restart")
	var shell_a: Node = run_a.get_shell()
	var settings_a: Node = shell_a.call("get_settings_screen")
	settings_a.call("press_music")
	settings_a.call("press_sound")
	settings_a.call("press_haptics")
	check(not shell_a.call("sound_enabled"), "C: run A turned sound off")
	_free_app(run_a)

	var run_b := _make_app("c_restart")
	var shell_b: Node = run_b.get_shell()
	var settings_b: Node = shell_b.call("get_settings_screen")
	var presenter_b: Variant = run_b.call("get_presenter")
	check_eq(run_b.call("last_settings_load_error"), M4PresentationSettingsStore.LoadError.NONE, "C: run B loaded cleanly")
	check_eq(shell_b.call("music_enabled"), false, "C: run B restored music OFF")
	check_eq(shell_b.call("sound_enabled"), false, "C: run B restored sound OFF")
	check_eq(shell_b.call("haptics_enabled"), false, "C: run B restored haptics OFF")
	check(not settings_b.call("music_enabled"), "C: run B controls show music OFF")
	check(not settings_b.call("sound_enabled"), "C: run B controls show sound OFF")
	check(not settings_b.call("haptics_enabled"), "C: run B controls show haptics OFF")
	check(not presenter_b.call("is_music_enabled"), "C: run B runtime music gate OFF")
	check(not presenter_b.call("is_sound_enabled"), "C: run B runtime sound gate OFF")
	check(not presenter_b.call("is_haptics_enabled"), "C: run B runtime haptics gate OFF")
	_free_app(run_b)


# --- TEST D: malformed settings ----------------------------------------------

func _test_d_malformed_settings() -> void:
	_cleanup()
	var path := _settings_path("d_malformed")
	_write_raw(path, "{not valid json")
	var app := _make_app("d_malformed")
	var shell: Node = app.get_shell()
	check_eq(shell.call("music_enabled"), true, "D: malformed -> music defaults ON")
	check_eq(shell.call("sound_enabled"), true, "D: malformed -> sound defaults ON")
	check_eq(shell.call("haptics_enabled"), true, "D: malformed -> haptics defaults ON")
	check_eq(
		app.call("last_settings_load_error"),
		M4PresentationSettingsStore.LoadError.INVALID_JSON,
		"D: diagnostic retained"
	)
	shell.call("press_play")
	check_eq(shell.call("state_name"), &"PLAYING", "D: app remains playable with malformed settings")
	check_eq(FileAccess.get_file_as_string(path), "{not valid json", "D: malformed source is never rewritten by load")
	_free_app(app)


# --- TEST E: persistence I/O failure ------------------------------------------

func _test_e_persistence_io_failure() -> void:
	_cleanup()
	var blocker := "%s/e_blocker" % TMP_DIR
	_write_raw(blocker, "not a directory")
	var settings_path := "%s/e_blocker/settings.json" % TMP_DIR
	var app := _make_app_at(settings_path, _progress_path("e_failure"))
	var shell: Node = app.get_shell()
	var presenter: Variant = app.call("get_presenter")
	var settings: Node = shell.call("get_settings_screen")

	settings.call("press_sound")
	check_eq(shell.call("sound_enabled"), false, "E: runtime keeps the player's choice")
	check(not presenter.call("is_sound_enabled"), "E: runtime sound gate OFF after a failed save")
	check(app.call("last_settings_save_error") != OK, "E: controller records a non-OK save error")
	check(not FileAccess.file_exists(settings_path), "E: nothing was written to the unwritable path")
	shell.call("press_play")
	check_eq(shell.call("state_name"), &"PLAYING", "E: app continues after a persistence failure")
	_free_app(app)
	DirAccess.remove_absolute(blocker)


# --- TEST F: accepted move + valid-move feedback ------------------------------

func _test_f_accepted_move_valid_feedback() -> void:
	_cleanup()
	var app := _make_app("f_accepted")
	var shell: Node = app.get_shell()
	var session: TrafficFirstPlayableSession = app.get_session()
	var presenter: Variant = app.call("get_presenter")
	_select_level(app, L2_INDEX)
	check_eq(session.current_level_id(), &"traffic_m3_l02_two_lanes", "F: deterministic level selected")
	var recorder: Variant = _install_recorder(app)

	var before_moves: int = session.get_state().move_index
	var tapped: StringName = _tap_vehicle_raw(app, &"v1")
	check_eq(tapped, &"v1", "F: the real hit test resolves the vehicle")
	check_eq(session.get_state().move_index, before_moves + 1, "F: exactly one command dispatched")
	check_eq(recorder.call("requested_count", Contract.SFX_TAP), 1, "F: one neutral tap acknowledgement")
	check_eq(
		recorder.call("requested_count", Contract.SFX_VALID_MOVE),
		1,
		"F: valid-move feedback requested exactly once on the accepted move"
	)
	check_eq(recorder.call("requested_count", Contract.SFX_BLOCKED_MOVE), 0, "F: accepted move has no blocked feedback")
	check(presenter.call("is_input_locked"), "F: movement holds a bounded input lock")

	var logical_immediate := Serialization.to_json(session.get_state().to_dictionary())
	presenter.call("advance", 0.7)
	presenter.call("skip_active_sequence")
	check(not presenter.call("is_input_locked"), "F: movement lock released after the bounded animation")
	var logical_settled := Serialization.to_json(session.get_state().to_dictionary())
	check_eq(logical_settled, logical_immediate, "F: presentation advancement never changes the logical state")

	# A control run with no recorder/presentation coupling yields the identical state.
	var control := _make_app("f_control")
	var control_session: TrafficFirstPlayableSession = control.get_session()
	_select_level(control, L2_INDEX)
	_tap_vehicle(control, &"v1")
	check_eq(
		Serialization.to_json(control_session.get_state().to_dictionary()),
		logical_immediate,
		"F: logical result is identical with and without presentation"
	)
	_free_app(control)
	_free_app(app)


# --- TEST G: blocked move -----------------------------------------------------

func _test_g_blocked_move() -> void:
	_cleanup()
	var app := _make_app("g_blocked")
	var shell: Node = app.get_shell()
	var session: TrafficFirstPlayableSession = app.get_session()
	var presenter: Variant = app.call("get_presenter")
	_select_level(app, L6_INDEX)
	check_eq(session.current_level_id(), &"traffic_m3_l06_the_blocker", "G: deterministic blocked level selected")
	var recorder: Variant = _install_recorder(app)

	var before := Serialization.to_json(session.get_state().to_dictionary())
	var haptics_before: int = presenter.haptics.trigger_count
	var tapped: StringName = _tap_vehicle_raw(app, &"v2")
	check_eq(tapped, &"v2", "G: the blocked vehicle is still a valid tap target")
	check_eq(recorder.call("requested_count", Contract.SFX_VALID_MOVE), 0, "G: blocked move never requests valid-move feedback")
	check_eq(recorder.call("requested_count", Contract.SFX_BLOCKED_MOVE), 1, "G: blocked feedback requested once")
	check_eq(recorder.call("requested_count", Contract.SFX_TAP), 1, "G: neutral tap acknowledgement once")
	check(presenter.haptics.trigger_count > haptics_before, "G: warning haptic requested while enabled")
	check(not presenter.call("is_input_locked"), "G: blocked feedback never locks input")
	check_eq(
		Serialization.to_json(session.get_state().to_dictionary()),
		before,
		"G: blocked move never mutates the simulation"
	)

	# Same tap with Sound + Haptics OFF: visuals only, simulation still identical.
	shell.call("get_settings_screen").call("press_sound")
	shell.call("get_settings_screen").call("press_haptics")
	recorder.call("clear_requested")
	var haptics_off_before: int = presenter.haptics.trigger_count
	_tap_vehicle_raw(app, &"v2")
	check_eq(recorder.call("requested_count", Contract.SFX_BLOCKED_MOVE), 0, "G: sound OFF -> no blocked audio request")
	check_eq(presenter.haptics.trigger_count, haptics_off_before, "G: haptics OFF -> no haptic call")
	check_eq(
		Serialization.to_json(session.get_state().to_dictionary()),
		before,
		"G: still no simulation mutation with feedback disabled"
	)
	_free_app(app)


# --- TEST H: completion sequence ----------------------------------------------

func _test_h_completion_sequence() -> void:
	_cleanup()
	var app := _make_app("h_completion")
	var shell: Node = app.get_shell()
	var session: TrafficFirstPlayableSession = app.get_session()
	var presenter: Variant = app.call("get_presenter")
	shell.call("press_play")
	check_eq(session.current_level_id(), &"traffic_m3_l01_first_roll", "H: level 1 started")

	_tap_vehicle_raw(app, &"v1")
	check(session.get_state().is_won(), "H: logical win is immediate")
	check_eq(presenter.call("active_sequence"), &"win", "H: completion sequence started")
	check_eq(shell.call("state_name"), &"PLAYING", "H: gameplay stays visible during the completion sequence")
	check(shell.call("is_result_pending"), "H: the result is deferred while the sequence plays")
	check(not shell.call("result_visible"), "H: the result overlay stays hidden during the sequence")

	# Progression is immediate and independent of the cosmetic sequence.
	var store := M3ProgressStore.new(app.get("progress_path"))
	check_eq(store.load_progress(), M3ProgressStore.LoadError.NONE, "H: progression persisted immediately")
	check(store.is_level_completed(&"traffic_m3_l01_first_roll"), "H: completion persisted before the reveal")

	_advance_until_result(app)
	check_eq(shell.call("state_name"), &"WIN_RESULT", "H: result revealed after the completion sequence")
	check(shell.call("result_visible"), "H: result overlay visible after the sequence")
	check(not shell.call("is_result_pending"), "H: pending result consumed once")
	check(not presenter.call("is_input_locked"), "H: input lock released after the sequence")
	_free_app(app)


# --- TEST I: failure sequence -------------------------------------------------

func _test_i_failure_sequence() -> void:
	_cleanup()
	var app := _make_app("i_failure")
	var shell: Node = app.get_shell()
	var session: TrafficFirstPlayableSession = app.get_session()
	var presenter: Variant = app.call("get_presenter")
	_select_level(app, L8_INDEX)
	check_eq(session.current_level_id(), &"traffic_m3_l08_no_room_to_wait", "I: deterministic failing level selected")

	_tap_vehicle_raw(app, &"v2")
	check(session.get_state().is_lost(), "I: logical failure is immediate")
	check_eq(presenter.call("active_sequence"), &"fail", "I: failure sequence started")
	check_eq(shell.call("state_name"), &"PLAYING", "I: gameplay stays visible during the failure sequence")
	check(not shell.call("result_visible"), "I: the result overlay stays hidden during the sequence")

	_advance_until_result(app)
	check_eq(shell.call("state_name"), &"FAIL_RESULT", "I: result revealed after the failure sequence")
	check(shell.call("result_retry_visible"), "I: fail result offers RETRY")
	check(not presenter.call("is_input_locked"), "I: input lock released after the failure sequence")
	_free_app(app)


# --- TEST J: result input guard ----------------------------------------------

func _test_j_result_guard() -> void:
	_cleanup()
	var app := _make_app("j_guard")
	var shell: Node = app.get_shell()
	check_eq(ResultScreen.INPUT_GUARD_MS, 350, "J: M3 device-derived 350 ms guard preserved")
	shell.call("press_play")
	_tap_vehicle(app, &"v1")
	check_eq(shell.call("state_name"), &"WIN_RESULT", "J: result revealed through the real flow")

	var result: Node = shell.get_node("Result")
	check(result.call("input_guard_active"), "J: result ignores presses right after it appears")
	var nexts: Array = []
	shell.next_requested.connect(func() -> void: nexts.append(true))
	result.call("_arm_input_guard")
	var next_button: Button = result.get_node("Panel/NextButton")
	next_button.emit_signal("pressed")
	check_eq(nexts.size(), 0, "J: a press during the guard produces no NEXT intent")
	check_eq(shell.call("state_name"), &"WIN_RESULT", "J: guarded press does not skip the result")

	result.set("_input_guard_until_msec", -1)
	next_button.emit_signal("pressed")
	check_eq(nexts.size(), 1, "J: one press after the guard yields exactly one NEXT intent")
	_free_app(app)


# --- TEST K: audio bus routing ------------------------------------------------

func _test_k_audio_bus_routing() -> void:
	_cleanup()
	var app := _make_app("k_buses")
	var presenter: Variant = app.call("get_presenter")
	var audio: Variant = presenter.get("audio")
	for bus_name: StringName in [&"Master", &"Music", &"SFX", &"UI"]:
		check(AudioServer.get_bus_index(bus_name) != -1, "K: real runtime bus '%s' exists" % bus_name)
	check_eq(audio.call("resolved_bus", Contract.BUS_UI), &"UI", "K: UI cue resolves to the UI bus (no fallback)")
	check_eq(audio.call("resolved_bus", Contract.BUS_SFX), &"SFX", "K: gameplay cue resolves to the SFX bus")
	check_eq(audio.call("resolved_bus", Contract.BUS_MUSIC), &"Music", "K: music resolves to the Music bus")
	check_eq(Contract.bus_for(Contract.SFX_TAP), Contract.BUS_UI, "K: tap maps to UI")
	check_eq(Contract.bus_for(Contract.SFX_MATCH), Contract.BUS_SFX, "K: match maps to SFX")
	_free_app(app)


# --- TEST L: recreate app / no growth -----------------------------------------

func _test_l_recreate_app_no_growth() -> void:
	_cleanup()
	var shell_children := -1
	for cycle in 3:
		var app := _make_app("l_recreate")
		var shell: Node = app.get_shell()
		var presenter: Variant = app.call("get_presenter")
		var session: TrafficFirstPlayableSession = app.get_session()
		var router: Variant = session.get_adapter().router
		var subscribers: int = router.subscriber_count()

		check_eq(presenter.call("audio_pool_size"), 8, "L: SFX pool stays bounded (cycle %d)" % cycle)
		if shell_children < 0:
			shell_children = shell.get_child_count()
		check_eq(shell.get_child_count(), shell_children, "L: shell child count stable (cycle %d)" % cycle)

		shell.call("press_settings")
		check_eq(shell.call("state_name"), &"SETTINGS", "L: settings opened (cycle %d)" % cycle)
		shell.call("get_settings_screen").call("press_back")
		check_eq(shell.call("state_name"), &"MAIN_MENU", "L: settings closed back to the menu (cycle %d)" % cycle)
		check_eq(router.subscriber_count(), subscribers, "L: no duplicated router subscriptions (cycle %d)" % cycle)

		shell.call("press_play")
		check_eq(shell.call("state_name"), &"PLAYING", "L: play works after the settings round-trip (cycle %d)" % cycle)
		check_eq(presenter.call("audio_pool_size"), 8, "L: pool still bounded after play (cycle %d)" % cycle)

		app.call("shutdown")
		check(not app.call("is_started"), "L: shutdown clears started (cycle %d)" % cycle)
		check_eq(app.get_child_count(), 0, "L: shutdown frees the shell (cycle %d)" % cycle)
		app.free()
