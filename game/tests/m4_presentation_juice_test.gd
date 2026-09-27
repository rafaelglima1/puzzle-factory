extends "res://tests/framework/test_base.gd"
## M4 presentation juice tests (AGENT-2). Presentation-only: mocks/view data,
## no core/puzzle imports. Deterministic and headless (presenters are driven by
## explicit `advance()` calls, as in the other presentation suites).

const Presenter := preload("res://themes/traffic/traffic_presenter.gd")
const Shell := preload("res://themes/traffic/m3/m3_first_playable.gd")
const ResultScreen := preload("res://themes/traffic/m3/result_screen.gd")
const Audio := preload("res://audio/presentation_audio.gd")
const Contract := preload("res://audio/audio_contract.gd")
const ProceduralSfx := preload("res://audio/procedural_sfx.gd")
const Haptics := preload("res://haptics/haptic_service.gd")
const BlockedIndicator := preload("res://themes/traffic/components/blocked_indicator.gd")
const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")

const REF := Vector2(1080.0, 1920.0)


func run() -> void:
	_test_procedural_audio()
	_test_audio_runtime()
	_test_haptics_settings_and_priority()
	_test_tap_acknowledgement()
	_test_valid_move_easing_and_settlement()
	_test_blocked_and_rejected()
	_test_match_loading_and_pulse()
	_test_objective_feedback()
	_test_completion_result_sequencing()
	_test_fail_result_sequencing()
	_test_result_input_guard_preserved()
	_test_settings_ui()
	_test_transitions_bounded()
	_test_effect_caps()


func _make_presenter() -> Variant:
	var presenter = Presenter.new()
	presenter.build()
	presenter.setup(Mock.sample_board())
	presenter.layout_for(REF)
	return presenter


func _make_shell(debug_enabled: bool = false) -> Variant:
	var shell = Shell.new()
	shell.debug_enabled = debug_enabled
	shell.build()
	shell.layout_for(REF)
	return shell


func _test_procedural_audio() -> void:
	for sfx: StringName in Contract.all_sfx():
		var stream: Variant = ProceduralSfx.build(sfx)
		check(stream is AudioStream, "generated stream for %s" % sfx)
		if stream is AudioStreamWAV:
			check((stream as AudioStreamWAV).data.size() > 0, "generated samples for %s" % sfx)
		check(ProceduralSfx.is_available(sfx), "%s reported available" % sfx)
	var unknown: Variant = ProceduralSfx.build(&"not_a_real_sfx")
	check(unknown == null, "unknown sfx generates nothing")


func _test_audio_runtime() -> void:
	var audio = Audio.new()
	check(not audio.play(Contract.SFX_TAP), "no stream -> no playback before generation")
	check_eq(audio.ensure_default_streams(), 10, "all ten interaction sounds generated")
	check_eq(audio.stream_count(), 10, "ten streams registered")

	check(audio.play(Contract.SFX_TAP), "tap plays once a stream exists")
	check_eq(audio.play_count, 1, "play counted")
	check_eq(audio.last_sfx, Contract.SFX_TAP, "last sfx tracked")
	check_eq(audio.last_bus, Contract.BUS_UI, "tap routed to the UI bus")
	check_eq(audio.playback_count, 0, "no hardware output without a host")

	var idx := AudioServer.get_bus_index(&"SFX")
	var expected := &"SFX" if idx >= 0 else &"Master"
	check_eq(audio.resolved_bus(&"SFX"), expected, "missing bus falls back to Master")

	var host := Node.new()
	audio.bind_host(host)
	check_eq(audio.pool_size(), 8, "bounded SFX pool of 8 players")
	check(audio.play(Contract.SFX_MATCH), "play accepted with a host")
	check_eq(audio.playback_count, 0, "host not in tree -> counted, not output")
	audio.detach_host()
	host.free()

	audio.set_sound_enabled(false)
	check(not audio.is_sound_enabled(), "sound gate off")
	check(not audio.play(Contract.SFX_TAP), "sound off -> safe no-op")
	audio.set_music_enabled(false)
	check(not audio.is_music_enabled(), "music gate off")


func _test_haptics_settings_and_priority() -> void:
	var haptics = Haptics.new()
	check(haptics.trigger(Haptics.LIGHT, 1000), "light fires")
	check(not haptics.trigger(Haptics.LIGHT, 1050), "same-pattern repeat suppressed in cooldown")
	check(haptics.trigger(Haptics.WARNING, 1060), "stronger pattern upgrades inside the cooldown")
	check(not haptics.trigger(Haptics.LIGHT, 1070), "weaker pattern still suppressed")
	haptics.set_enabled(false)
	check(not haptics.trigger(Haptics.SUCCESS, 5000), "disabled haptics ignored")
	check(haptics.is_enabled() == false, "disabled state exposed")


func _test_tap_acknowledgement() -> void:
	var presenter = _make_presenter()
	check(presenter.acknowledge_tap(&"e_compact_a"), "tap on an entity is acknowledged")
	var view = presenter.board_view.entity_view(&"e_compact_a")
	check(view.is_selected(), "tap highlight shown immediately")
	check_eq(presenter.audio.last_sfx, Contract.SFX_TAP, "tap sound requested")
	check(presenter.haptics.trigger_count >= 1, "tap haptic requested")
	presenter.advance(0.2)
	check(not view.is_selected(), "tap highlight is bounded and clears")
	check(not presenter.acknowledge_tap(&""), "empty tap is not acknowledged")
	presenter.teardown()
	presenter.free()


func _test_valid_move_easing_and_settlement() -> void:
	var presenter = _make_presenter()
	var view = presenter.board_view.entity_view(&"e_compact_a")
	var start: Vector2 = view.position
	var target_cell := Vector2i(3, 1)
	var end: Vector2 = presenter.board_view.cell_center(target_cell)
	var duration: float = presenter.animate_path(&"e_compact_a", [Vector2i(1, 1), target_cell])
	check(duration > 0.0 and duration <= 0.6, "movement duration bounded (<= 0.6s)")
	check(presenter.is_input_locked(), "movement holds a bounded input lock")

	# Ease-out: half-way through the time, more than half the distance is done.
	presenter.advance(duration * 0.5)
	var travelled: float = start.distance_to(view.position)
	var total: float = start.distance_to(end)
	check(travelled > total * 0.5, "movement eases out (fast start)")

	presenter.advance(duration)
	check(view.position.distance_to(end) < 0.01, "movement settles exactly on the authoritative target")
	check(not presenter.is_input_locked(), "movement lock released on arrival")
	presenter.teardown()
	presenter.free()


func _test_blocked_and_rejected() -> void:
	var presenter = _make_presenter()
	var before_plays: int = presenter.audio.play_count
	var before_haptics: int = presenter.haptics.trigger_count
	var blocked_duration: float = presenter.show_blocked(&"e_compact_a", Vector2.RIGHT, [])
	check(blocked_duration <= BlockedIndicator.MAX_DURATION, "blocked feedback bounded to <= 250 ms")
	check_eq(presenter.last_blocked_duration, blocked_duration, "blocked duration recorded")
	check_eq(presenter.audio.last_sfx, Contract.SFX_BLOCKED_MOVE, "blocked sound requested")
	check(presenter.audio.play_count > before_plays, "blocked sound counted")
	check(presenter.haptics.trigger_count > before_haptics, "blocked haptic requested")
	check(not presenter.is_input_locked(), "blocked feedback never locks input")

	presenter.show_command_rejected(&"e_compact_a", &"invalid", &"no_op_move")
	check_eq(presenter.last_rejection.get("code", ""), "no_op_move", "rejection code kept for debug")
	check(presenter.audio.play_count > before_plays + 1, "rejected sound counted")
	presenter.teardown()
	presenter.free()


func _test_match_loading_and_pulse() -> void:
	var presenter = _make_presenter()
	var entity = presenter.board_view.entity_view(&"e_compact_a")
	check(presenter.show_match(&"e_compact_a"), "match hook works")
	presenter.advance(0.08)
	check(entity.scale.x > 1.0, "matched view pulses")
	presenter.advance(0.3)
	check(is_equal_approx(entity.scale.x, 1.0), "pulse returns to rest")
	presenter.set_destination(Mock.sample_destination())
	check(presenter.show_item_loaded(&"dest_station", &"COLOR_B"), "loading hook works")
	presenter.teardown()
	presenter.free()


func _test_objective_feedback() -> void:
	var presenter = _make_presenter()
	presenter.setup(Mock.sample_board())
	presenter.set_objectives([&"COLOR_A", &"COLOR_B"])
	check(presenter.show_objective_complete(&"clear_all"), "objective hook works")
	check(presenter.hud_shell.is_flashing(), "objective chip flash active")
	check_eq(presenter.audio.last_sfx, Contract.SFX_COMBO, "objective success sound requested")
	presenter.advance(1.0)
	check(not presenter.hud_shell.is_flashing(), "objective flash bounded")
	presenter.teardown()
	presenter.free()


func _test_completion_result_sequencing() -> void:
	var shell = _make_shell()
	var presenter = shell.get_traffic_presenter()
	presenter.setup(Mock.sample_board())
	shell.show_playing(1, 10)
	shell.layout_for(REF)

	presenter.show_win(10.0)
	check_eq(presenter.active_sequence(), &"win", "win sequence started")
	shell.show_win_result(1, false)
	check(shell.is_result_pending(), "result deferred while the sequence is visible")
	check_eq(shell.state_name(), &"PLAYING", "gameplay remains visible during the win sequence")
	check(not shell.result_visible(), "result overlay does not cover the sequence")

	presenter.advance(0.4)
	check(presenter.skip_active_sequence(), "win sequence skippable")
	check(not shell.is_result_pending(), "pending result consumed on sequence finish")
	check_eq(shell.state_name(), &"WIN_RESULT", "result revealed after the sequence")
	check(shell.result_visible(), "result overlay visible after the sequence")
	check(not presenter.is_input_locked(), "input lock released when the sequence ends")
	shell.teardown()
	shell.free()


func _test_fail_result_sequencing() -> void:
	var shell = _make_shell()
	var presenter = shell.get_traffic_presenter()
	presenter.setup(Mock.sample_board())
	shell.show_playing(1, 10)
	shell.layout_for(REF)

	presenter.show_fail(&"staging_full")
	shell.show_fail_result(1, &"staging_full")
	check(shell.is_result_pending(), "fail result deferred during the fail sequence")
	check_eq(shell.state_name(), &"PLAYING", "gameplay visible during the fail sequence")
	presenter.advance(0.4)
	check(presenter.skip_active_sequence(), "fail sequence skippable")
	check_eq(shell.state_name(), &"FAIL_RESULT", "fail result revealed after the sequence")
	check(not shell.is_result_pending(), "fail pending cleared")
	shell.teardown()
	shell.free()


func _test_result_input_guard_preserved() -> void:
	check_eq(ResultScreen.INPUT_GUARD_MS, 350, "M3 device-derived 350 ms result guard preserved")
	var shell = _make_shell()
	var nexts: Array = []
	shell.next_requested.connect(func() -> void: nexts.append(true))
	shell.show_win_result(1, false)  # no presenter sequence -> immediate reveal
	check_eq(shell.state_name(), &"WIN_RESULT", "result shown immediately without a sequence")
	var result: Node = shell.get_node("Result")
	check(result.call("input_guard_active"), "result ignores presses right after it appears")
	result.call("_arm_input_guard")
	var next_button: Button = result.get_node("Panel/NextButton")
	next_button.emit_signal("pressed")
	check_eq(nexts.size(), 0, "guarded press produces no navigation intent")
	check_eq(shell.state_name(), &"WIN_RESULT", "guarded press does not skip the result")
	result.set("_input_guard_until_msec", -1)
	next_button.emit_signal("pressed")
	check_eq(nexts.size(), 1, "press after the guard emits exactly one navigation intent")
	shell.teardown()
	shell.free()


func _test_settings_ui() -> void:
	var shell = _make_shell()
	var presenter = shell.get_traffic_presenter()
	presenter.setup(Mock.sample_board())
	shell.layout_for(REF)
	var settings = shell.get_settings_screen()
	var music_events: Array = []
	var sound_events: Array = []
	var haptics_events: Array = []
	shell.music_enabled_changed.connect(func(v: bool) -> void: music_events.append(v))
	shell.sound_enabled_changed.connect(func(v: bool) -> void: sound_events.append(v))
	shell.haptics_enabled_changed.connect(func(v: bool) -> void: haptics_events.append(v))

	shell.show_settings()
	check_eq(shell.state_name(), &"SETTINGS", "settings screen shown")
	check(shell.settings_visible(), "settings visible")

	settings.press_music()
	check_eq(music_events, [false], "music toggle emits exactly once")
	check(not shell.music_enabled(), "shell music state updated")
	check(not presenter.is_music_enabled(), "runtime music gate updated")

	settings.press_sound()
	check_eq(sound_events, [false], "sound toggle emits exactly once")
	check(not presenter.is_sound_enabled(), "runtime sound gate updated")
	check(not presenter.audio.play(Contract.SFX_TAP), "sound off -> no audio playback")
	# Gameplay is unaffected by sound being off.
	check(presenter.animate_path(&"e_compact_a", [Vector2i(1, 1), Vector2i(2, 1)]) > 0.0, "movement works with sound off")
	check_eq(presenter.audio.playback_count, 0, "no audible playback with sound off")
	presenter.advance(1.0)

	settings.press_haptics()
	check_eq(haptics_events, [false], "haptics toggle emits exactly once")
	check(not presenter.is_haptics_enabled(), "runtime haptics disabled")
	var before: int = presenter.haptics.trigger_count
	presenter.haptics.trigger(Haptics.WARNING, 9000)
	check_eq(presenter.haptics.trigger_count, before, "disabled haptics ignore triggers")

	shell.apply_presentation_settings(true, true, true)
	check(shell.music_enabled() and shell.sound_enabled() and shell.haptics_enabled(), "inbound settings applied")
	check(presenter.is_sound_enabled() and presenter.is_haptics_enabled(), "runtime services re-enabled")
	check_eq(music_events.size(), 1, "inbound apply does not emit toggle intents")
	check_eq(sound_events.size(), 1, "inbound apply does not emit sound intents")
	check_eq(haptics_events.size(), 1, "inbound apply does not emit haptics intents")
	shell.teardown()
	shell.free()


func _test_transitions_bounded() -> void:
	var shell = _make_shell()
	var plays: Array = []
	shell.play_requested.connect(func() -> void: plays.append(true))
	shell.press_play()
	check_eq(plays.size(), 1, "one press -> exactly one navigation intent")
	check(shell.transition_active(), "screen transition active after a state change")
	check(shell.transition_alpha() < 1.0, "transition starts faded")
	shell.advance(0.3)
	check(not shell.transition_active(), "transition bounded and finished")
	check(is_equal_approx(shell.transition_alpha(), 1.0), "incoming screen fully visible after transition")
	shell.teardown()
	shell.free()


func _test_effect_caps() -> void:
	var presenter = _make_presenter()
	presenter.set_destination(Mock.sample_destination())
	for i in 12:
		presenter.show_match(&"e_compact_a")
	check(
		presenter.active_match_effects() <= Presenter.MAX_ACTIVE_MATCH_EFFECTS,
		"match effects are capped (no unbounded node churn)"
	)
	for i in 12:
		presenter.show_blocked(&"e_compact_a", Vector2.RIGHT, [])
	check(
		presenter.active_blocked_indicators() <= Presenter.MAX_ACTIVE_BLOCKED_INDICATORS,
		"blocked indicators are capped"
	)
	check_eq(presenter.audio_pool_size(), 8, "audio pool bounded")
	presenter.teardown()
	presenter.free()
