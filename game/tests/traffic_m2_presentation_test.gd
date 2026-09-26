extends "res://tests/framework/test_base.gd"
## M2 Traffic presentation integration tests (AGENT-2).
##
## Verifies the official M1 event mappings, M2 additive hooks, input-lock
## safety and ThemeContract compatibility WITHOUT importing core/puzzle.

const Presenter := preload("res://themes/traffic/traffic_presenter.gd")
const Router := preload("res://themes/traffic/bridge/presentation_event_router.gd")
const TrafficTheme := preload("res://themes/traffic/traffic_theme.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")
const BlockedIndicator := preload("res://themes/traffic/components/blocked_indicator.gd")
const CompletionEffect := preload("res://themes/traffic/components/completion_effect.gd")
const FailureEffect := preload("res://themes/traffic/components/failure_effect.gd")
const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")


func run() -> void:
	_test_event_mapping()
	_test_move_and_block()
	_test_unknown_events()
	_test_staging_authoritative()
	_test_queue_destination()
	_test_match_loading_hooks()
	_test_win_fail_hooks()
	_test_input_lock_release()
	_test_theme_contract()


func _make_presenter() -> Variant:
	var presenter = Presenter.new()
	presenter.build()
	presenter.setup(Mock.sample_board())
	presenter.layout_for(Vector2(1080, 1920))
	return presenter


func _test_event_mapping() -> void:
	var presenter = _make_presenter()

	check(
		presenter.handle_event(Router.ENTITY_PLACED, {
			"entity_id": "e_new",
			"position": {"x": 1, "y": 2},
			"footprint": {"width": 2, "height": 1},
		}),
		"entity_placed handled"
	)
	var placed = presenter.board_view.entity_view(&"e_new")
	check(placed != null, "entity view created from placement")
	check(placed.get_data().cell == Vector2i(1, 2), "placement position applied from payload")
	check(placed.get_data().footprint == Vector2i(2, 1), "placement footprint applied from payload")

	var provider := func(id: Variant, _payload: Variant) -> Variant:
		return Mock.entity(StringName(id), EntityData.TYPE_TRUCK, &"COLOR_C", Vector2i(4, 5), 90.0)
	check(
		presenter.handle_event(Router.ENTITY_PLACED, {
			"entity_id": "e_truck",
			"position": {"x": 4, "y": 5},
			"footprint": {"width": 3, "height": 1},
		}, provider),
		"entity_placed with provider handled"
	)
	var truck = presenter.board_view.entity_view(&"e_truck")
	check(truck != null, "provider entity created")
	check_eq(truck.get_data().color_key, &"COLOR_C", "provider color applied")
	check_eq(truck.rotation_degrees, 90.0, "provider orientation applied")
	check_eq(truck.symbol_kind(), &"square", "symbol derived from the color key")

	presenter.teardown()
	presenter.free()


func _test_move_and_block() -> void:
	var presenter = _make_presenter()
	presenter.handle_event(Router.ENTITY_PLACED, {
		"entity_id": "e1",
		"position": {"x": 1, "y": 1},
		"footprint": {"width": 2, "height": 1},
	})

	check(
		presenter.handle_event(Router.ENTITY_MOVE_STARTED, {
			"entity_id": "e1",
			"from": {"x": 1, "y": 1},
			"to": {"x": 4, "y": 1},
		}),
		"entity_move_started handled"
	)
	check(presenter.is_input_locked(), "movement requests a bounded input lock")
	check(presenter.input_lock_remaining() <= Presenter.MOVE_LOCK_CAP + 0.0001, "movement lock within cap")
	presenter.advance(1.0)
	check(not presenter.is_input_locked(), "movement lock released on completion")
	check(
		presenter.board_view.entity_view(&"e1").position == presenter.board_view.cell_center(Vector2i(4, 1)),
		"entity settled at the supplied target"
	)

	presenter.handle_event(Router.ENTITY_MOVED, {
		"entity_id": "e1",
		"from": {"x": 4, "y": 1},
		"to": {"x": 5, "y": 1},
	})
	check_eq(presenter.board_view.entity_view(&"e1").get_data().cell, Vector2i(5, 1), "entity_moved snaps to authoritative target")
	check(not presenter.is_input_locked(), "entity_moved leaves no lock")

	var blocked_duration = presenter.show_blocked(&"e1", Vector2.RIGHT, [])
	check(blocked_duration <= BlockedIndicator.MAX_DURATION, "blocked feedback bounded to <=250ms")
	check_eq(presenter.last_blocked_duration, blocked_duration, "blocked duration recorded")
	presenter.advance(0.05)
	check(not presenter.is_input_locked(), "blocked feedback never locks input")

	presenter.teardown()
	presenter.free()


func _test_unknown_events() -> void:
	var presenter = _make_presenter()
	var ignored: Array = []
	presenter.event_ignored.connect(func(name: StringName) -> void: ignored.append(name))
	check(not presenter.handle_event(&"totally_unknown_event", {"x": 1}), "unknown event returns false")
	check_eq(ignored, [&"totally_unknown_event"], "unknown event signalled as ignored")
	check(not presenter.handle_event(Router.M2_EXPECTED_EVENTS[0], {}), "expected-but-unpublished M2 name ignored safely")
	presenter.teardown()
	presenter.free()


func _test_staging_authoritative() -> void:
	var presenter = _make_presenter()
	for slots: int in [3, 4, 5, 6]:
		presenter.set_staging(StagingData.new(slots))
		check_eq(presenter.staging_view.slot_count(), slots, "staging renders %d slots" % slots)
	presenter.set_staging_pressure(StagingData.PRESSURE_WARNING)
	check_eq(presenter.staging_view.pressure(), StagingData.PRESSURE_WARNING, "warning state preserved")
	presenter.set_staging_pressure(StagingData.PRESSURE_FULL)
	check_eq(presenter.staging_view.pressure(), StagingData.PRESSURE_FULL, "full state preserved")
	check(not presenter.is_input_locked(), "staging state never locks input or ends the game")
	presenter.teardown()
	presenter.free()


func _test_queue_destination() -> void:
	var presenter = _make_presenter()
	presenter.set_destination(Mock.sample_destination())
	check(presenter.board_view.destination_view_count() >= 1, "destination view created")
	check(presenter.set_queue(&"dest_station", [&"COLOR_A", &"COLOR_B", &"COLOR_C"]), "queue update accepted")
	check_eq(presenter.board_view.destination_view(&"dest_station").queue_size(), 3, "queue renders supplied keys")
	presenter.set_queue(&"dest_station", [&"COLOR_D"])
	check_eq(presenter.board_view.destination_view(&"dest_station").queue_size(), 1, "queue re-renders from supplied keys")
	presenter.teardown()
	presenter.free()


func _test_match_loading_hooks() -> void:
	var presenter = _make_presenter()
	presenter.set_destination(Mock.sample_destination())
	check(presenter.show_match(&"e_compact_a"), "match hook on an entity works")
	check(presenter.show_match(&"dest_station"), "match hook on a destination works")
	check(presenter.show_item_loaded(&"dest_station", &"COLOR_B"), "item-loaded hook at a destination works")
	check(not presenter.show_item_loaded(&"missing_destination", &"COLOR_A"), "missing destination returns false safely")
	check(not presenter.is_input_locked(), "match/loading hooks do not lock input")
	presenter.teardown()
	presenter.free()


func _test_win_fail_hooks() -> void:
	var presenter = _make_presenter()
	var finished: Array = []
	presenter.sequence_finished.connect(func(kind: StringName) -> void: finished.append(kind))

	var win_duration = presenter.show_win(10.0)
	check(win_duration <= CompletionEffect.MAX_DURATION, "win duration bounded to <=2s")
	check_eq(presenter.active_sequence(), &"win", "win sequence active")
	check(presenter.is_input_locked(), "win locks input briefly")
	presenter.advance(0.4)
	check(presenter.skip_active_sequence(), "win is skippable after the threshold")
	check(not presenter.is_input_locked(), "win skip releases the input lock")
	check_eq(finished, [&"win"], "win sequence finished exactly once")

	var fail_duration = presenter.show_fail(&"STAGING_FULL", 10.0)
	check(fail_duration <= FailureEffect.MAX_DURATION, "fail duration bounded to <=1.5s")
	check_eq(presenter.fail_reason_localization_key(&"STAGING_FULL"), &"level.fail.staging_full", "fail reason mapped to a localization key")
	check_eq(presenter.fail_reason_localization_key(&"NO_VALID_MOVES"), &"level.fail.no_moves", "no-valid-moves reason mapped")
	check_eq(presenter.fail_reason_localization_key(&"SOMETHING_NEW"), &"level.fail.unknown", "unknown fail reason falls back safely")
	presenter.advance(0.4)
	check(presenter.skip_active_sequence(), "fail is skippable after the threshold")
	check_eq(finished, [&"win", &"fail"], "fail sequence finished exactly once")
	check(not presenter.is_input_locked(), "fail skip releases the input lock")

	presenter.teardown()
	presenter.free()


func _test_input_lock_release() -> void:
	var presenter = _make_presenter()
	presenter.handle_event(Router.ENTITY_PLACED, {
		"entity_id": "e1",
		"position": {"x": 0, "y": 0},
		"footprint": {"width": 1, "height": 1},
	})
	presenter.handle_event(Router.ENTITY_MOVE_STARTED, {
		"entity_id": "e1",
		"from": {"x": 0, "y": 0},
		"to": {"x": 6, "y": 0},
	})
	check(presenter.is_input_locked(), "movement lock acquired")
	presenter.advance(2.0)
	check(not presenter.is_input_locked(), "movement lock released by completion/failsafe")

	presenter.show_win()
	check(presenter.is_input_locked(), "result lock acquired")
	presenter.advance(3.0)
	check(not presenter.is_input_locked(), "result lock auto-released by bounded expiry")

	presenter.handle_event(Router.ENTITY_MOVE_STARTED, {
		"entity_id": "e1",
		"from": {"x": 6, "y": 0},
		"to": {"x": 0, "y": 0},
	})
	check(presenter.is_input_locked(), "lock present before teardown")
	presenter.teardown()
	check(not presenter.is_input_locked(), "teardown releases all locks")
	presenter.free()


func _test_theme_contract() -> void:
	var theme = TrafficTheme.new()
	check_eq(theme.validation_errors().size(), 0, "Traffic manifest satisfies ThemeContract")
	check(theme.supports_all_slots(), "Traffic binds every generic presentation slot")
	check(theme.accepts_color_key(&"COLOR_A"), "COLOR_A is a contract-valid color key")
	check(not theme.accepts_color_key(&"BLUE"), "literal color words are not contract color keys")
	var palette = theme.palette()
	for key: StringName in palette.all_keys():
		check(theme.accepts_color_key(key), "palette key '%s' is contract-valid" % key)
	check_eq(theme.direction_degrees(&"east"), 90.0, "direction maps to presentation degrees")
	check_eq(theme.manifest().get("themeId", ""), "traffic", "manifest theme id")
