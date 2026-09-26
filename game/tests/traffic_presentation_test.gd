extends "res://tests/framework/test_base.gd"
## AGENT-2 presentation scaffold tests. Visual components only: no puzzle
## authority is exercised or required here.

const Palette := preload("res://themes/traffic/traffic_palette.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const ItemData := preload("res://themes/traffic/model_item_view_data.gd")
const DestinationData := preload("res://themes/traffic/model_destination_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")
const EntityView := preload("res://themes/traffic/components/entity_view.gd")
const ItemView := preload("res://themes/traffic/components/item_view.gd")
const DestinationView := preload("res://themes/traffic/components/destination_view.gd")
const StagingView := preload("res://themes/traffic/components/staging_view.gd")
const BlockedIndicator := preload("res://themes/traffic/components/blocked_indicator.gd")
const MovementController := preload("res://themes/traffic/components/movement_tween_controller.gd")
const MatchEffect := preload("res://themes/traffic/components/match_effect.gd")
const CompletionEffect := preload("res://themes/traffic/components/completion_effect.gd")
const FailureEffect := preload("res://themes/traffic/components/failure_effect.gd")
const InputGate := preload("res://ui/input_gate.gd")
const HapticService := preload("res://haptics/haptic_service.gd")
const AudioContract := preload("res://audio/audio_contract.gd")
const PresentationAudio := preload("res://audio/presentation_audio.gd")
const EventRouter := preload("res://themes/traffic/bridge/presentation_event_router.gd")


func run() -> void:
	_test_palette_symbol_fallback()
	_test_entity_orientation_and_symbol()
	_test_selection_feedback()
	_test_staging_arbitrary_slots()
	_test_item_and_destination()
	_test_blocked_bounded()
	_test_movement_from_supplied_path()
	_test_effects_bounded_and_skippable()
	_test_input_gate_failsafe()
	_test_audio_contract()
	_test_haptics_restraint()
	_test_event_router_boundary()


func _test_palette_symbol_fallback() -> void:
	var palette = Palette.new()
	check_eq(palette.entry_count(), 4, "four default color keys")
	check_eq(palette.symbol_for(&"COLOR_A"), &"circle", "COLOR_A -> circle")
	check_eq(palette.symbol_for(&"COLOR_B"), &"triangle", "COLOR_B -> triangle")
	check_eq(palette.symbol_for(&"COLOR_C"), &"square", "COLOR_C -> square")
	check_eq(palette.symbol_for(&"COLOR_D"), &"star", "COLOR_D -> star")
	check_eq(palette.symbol_for(&"BLUE"), Palette.FALLBACK_SYMBOL, "unknown key falls back to a symbol")
	check_eq(palette.color_for(&"RED"), Palette.FALLBACK_COLOR, "unknown key falls back to a color")
	check(not palette.has_key(&"RED"), "literal color words are not gameplay ids")


func _test_entity_orientation_and_symbol() -> void:
	var view = EntityView.new()
	view.set_cell_size(64.0)
	var data = EntityData.new(&"e1", EntityData.TYPE_COMPACT, &"COLOR_A")
	data.footprint = Vector2i(2, 1)
	data.orientation = 0.0
	view.set_data(data)
	check_eq(view.rotation_degrees, 0.0, "orientation 0 sets the presentation transform")
	check(view.presentation_extent() == Vector2(128.0, 64.0), "extent along X when upright")
	check_eq(view.symbol_kind(), &"circle", "entity symbol derives from the color key")
	check_eq(view.body_color(), Palette.new().color_for(&"COLOR_A"), "entity color derives from the color key")
	data.orientation = 90.0
	view.set_data(data)
	check_eq(view.rotation_degrees, 90.0, "orientation 90 updates the transform")
	check(view.presentation_extent() == Vector2(64.0, 128.0), "extent swaps on a side orientation")
	view.free()


func _test_selection_feedback() -> void:
	var view = EntityView.new()
	view.set_data(EntityData.new(&"e2", EntityData.TYPE_VAN, &"COLOR_B"))
	check(not view.is_selected(), "entity starts unselected")
	view.set_selected(true)
	check(view.is_selected(), "selection state reported")
	check(view.get_selection_indicator() != null, "selection indicator created")
	check(view.get_selection_indicator().is_active(), "selection indicator active")
	view.set_selected(false)
	check(not view.get_selection_indicator().is_active(), "selection indicator deactivated")
	view.free()


func _test_staging_arbitrary_slots() -> void:
	var staging = StagingView.new()
	staging.set_staging_data(StagingData.new(7))
	check_eq(staging.slot_count(), 7, "renders an arbitrary slot count (7)")
	check_eq(staging.get_slot_nodes().size(), 7, "slot child nodes match the count")
	staging.set_staging_data(StagingData.new(3))
	check_eq(staging.slot_count(), 3, "rebuilds down to 3 slots")
	staging.set_staging_data(StagingData.new(0))
	check_eq(staging.slot_count(), 0, "renders zero slots safely")
	staging.set_staging_data(StagingData.new(4))
	staging.set_pressure(StagingData.PRESSURE_FULL)
	check_eq(staging.pressure(), StagingData.PRESSURE_FULL, "pressure is received, never decided here")
	staging.free()


func _test_item_and_destination() -> void:
	var item = ItemView.new()
	item.set_data(ItemData.new(&"i1", ItemData.TYPE_PASSENGER, &"COLOR_C"))
	check_eq(item.symbol_kind(), &"square", "item symbol derives from the color key")
	item.set_highlight(true)
	check(item.highlight, "item highlight state recorded")
	item.free()

	var destination = DestinationView.new()
	var destination_data = DestinationData.new(&"d1")
	destination_data.accepted_color_keys.append(&"COLOR_A")
	destination_data.accepted_color_keys.append(&"COLOR_D")
	destination_data.capacity = 3
	destination_data.occupancy = 1
	destination_data.queue_color_keys.append(&"COLOR_A")
	destination.set_data(destination_data)
	check_eq(destination.accepted_symbols(), [&"circle", &"star"], "accepted keys are dual-coded")
	check_eq(destination.capacity(), 3, "capacity is displayed from supplied data")
	check_eq(destination.occupancy(), 1, "occupancy is displayed from supplied data")
	check_eq(destination.queue_size(), 1, "queue strip count comes from supplied data")
	destination.set_queue([&"COLOR_B", &"COLOR_C"])
	check_eq(destination.queue_size(), 2, "queue strip updates from supplied data")
	destination.free()


func _test_blocked_bounded() -> void:
	var indicator = BlockedIndicator.new()
	var finished := [false]
	indicator.finished.connect(func() -> void: finished[0] = true)
	var granted = indicator.play(Vector2.RIGHT, 5.0)
	check(granted <= BlockedIndicator.MAX_DURATION, "blocked duration clamped to max")
	check_eq(indicator.duration, BlockedIndicator.MAX_DURATION, "blocked uses the clamped duration")
	check(indicator.playing, "blocked feedback playing")
	for i in 10:
		indicator.update(0.05)
	check(not indicator.playing, "blocked feedback auto-finishes")
	check(finished[0], "blocked finished signal emitted")
	indicator.set_blocker_cell(Vector2i(2, 3))
	check_eq(indicator.blocker_cell, Vector2i(2, 3), "blocker flash hook stores its cell")
	indicator.free()


func _test_movement_from_supplied_path() -> void:
	var target := Node2D.new()
	var controller = MovementController.new()
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var finished := [false]
	controller.finished.connect(func(_target: Variant) -> void: finished[0] = true)
	var granted = controller.move_along(target, path, 0.2)
	check_eq(granted, 0.2, "movement accepts an externally supplied duration")
	check_eq(controller.point_count(), 3, "movement stores the supplied path points")
	check(controller.active, "movement active")
	for i in 6:
		controller.update(0.05)
	check(not controller.active, "movement finishes")
	check(target.position.distance_to(Vector2(100, 100)) < 0.01, "target reaches the path end")
	check(finished[0], "movement finished signal emitted")
	controller.move_along(target, path, 5.0)
	check_eq(controller.duration, MovementController.MAX_DURATION, "movement duration clamped")
	controller.stop()
	target.free()
	controller.free()


func _test_effects_bounded_and_skippable() -> void:
	var match_effect = MatchEffect.new()
	var match_done := [false]
	match_effect.finished.connect(func() -> void: match_done[0] = true)
	var match_duration = match_effect.play(Vector2(5, 5), &"COLOR_A", 10.0)
	check_eq(match_duration, MatchEffect.MAX_DURATION, "match effect duration clamped")
	for i in 20:
		match_effect.update(0.05)
	check(match_done[0], "match effect finishes")
	match_effect.free()

	var completion = CompletionEffect.new()
	var completion_done := [false]
	completion.finished.connect(func() -> void: completion_done[0] = true)
	completion.play(10.0)
	check_eq(completion.duration, CompletionEffect.MAX_DURATION, "completion clamped to the 2s max")
	check(not completion.can_skip(), "completion is not skippable immediately")
	completion.update(0.4)
	check(completion.can_skip(), "completion is skippable after the threshold")
	check(completion.skip(), "completion skip succeeds")
	check(completion_done[0], "completion finished after skip")
	check(not completion.playing, "completion stopped after skip")
	completion.free()

	var failure = FailureEffect.new()
	var failure_done := [false]
	failure.finished.connect(func() -> void: failure_done[0] = true)
	failure.play(&"STAGING_FULL", 10.0)
	check_eq(failure.duration, FailureEffect.MAX_DURATION, "failure clamped to the 1.5s max")
	check_eq(failure.reason_localization_key(), &"level.fail.staging_full", "failure maps reason to a key")
	failure.update(0.4)
	check(failure.skip(), "failure skip succeeds after the threshold")
	check(failure_done[0], "failure finished after skip")
	failure.free()


func _test_input_gate_failsafe() -> void:
	var gate = InputGate.new()
	var events: Array = []
	gate.lock_changed.connect(func(locked: bool) -> void: events.append(locked))
	var granted = gate.request(&"move", &"move_transition", 5.0)
	check_eq(granted, InputGate.DEFAULT_MAX_LOCK, "lock duration clamped to max")
	check(gate.is_locked(), "gate locked")
	check_eq(gate.owner_reason(&"move"), &"move_transition", "lock owner/reason traceable")
	gate.tick(0.7)
	check(not gate.is_locked(), "lock auto-releases (failsafe)")
	check_eq(events, [true, false], "lock_changed emitted on acquire and release")
	gate.set_max_lock(2.0)
	var granted_long = gate.request(&"result", &"win_sequence", 10.0)
	check_eq(granted_long, 2.0, "custom max lock respected")
	gate.release_all()
	check(not gate.is_locked(), "release_all clears locks")


func _test_audio_contract() -> void:
	check_eq(AudioContract.bus_for(AudioContract.SFX_TAP), AudioContract.BUS_UI, "tap routed to UI bus")
	check_eq(AudioContract.bus_for(AudioContract.SFX_MATCH), AudioContract.BUS_SFX, "match routed to SFX bus")
	check_eq(AudioContract.bus_for(&"unknown"), AudioContract.BUS_SFX, "unknown sfx defaults to SFX bus")
	check_eq(AudioContract.all_sfx().size(), 10, "ten required SFX classes declared")
	check_eq(AudioContract.expected_buses().size(), 4, "four buses declared")
	var audio = PresentationAudio.new()
	check(not audio.play(AudioContract.SFX_TAP), "no stream registered -> safe no-op")
	audio.register_stream(AudioContract.SFX_TAP, RefCounted.new())
	check(audio.play(AudioContract.SFX_TAP), "registered stream plays")
	check_eq(audio.play_count, 1, "play counted")
	audio.set_enabled(false)
	check(not audio.play(AudioContract.SFX_TAP), "disabled audio is silent")


func _test_haptics_restraint() -> void:
	var haptics = HapticService.new()
	check(haptics.trigger(HapticService.LIGHT, 1000), "light haptic fires")
	check(not haptics.trigger(HapticService.LIGHT, 1050), "cooldown suppresses a rapid repeat")
	check(haptics.trigger(HapticService.SUCCESS, 1200), "success fires after cooldown")
	check(not haptics.trigger(&"bogus", 2000), "unknown pattern ignored")
	haptics.set_enabled(false)
	check(not haptics.trigger(HapticService.WARNING, 3000), "disabled haptics are silent")
	check_eq(haptics.trigger_count, 2, "restrained trigger count")


func _test_event_router_boundary() -> void:
	var router = EventRouter.new()
	check_eq(router.dispatch(&"entity_placed"), 0, "event with no subscriber dispatches to nobody")
	check_eq(router.ignored_count, 1, "unhandled event counted, not crashed")
	var received: Array = []
	var callback := func(name: StringName, payload: Dictionary) -> void:
		received.append([name, payload])
	check(router.subscribe(EventRouter.ENTITY_PLACED, callback), "subscribe accepted")
	check_eq(router.dispatch(EventRouter.ENTITY_PLACED, {"entity_id": "e1"}), 1, "subscriber receives the event")
	check_eq(received.size(), 1, "callback invoked once")
	check_eq(received[0][0], EventRouter.ENTITY_PLACED, "event name forwarded")
	check(router.unsubscribe(EventRouter.ENTITY_PLACED, callback), "unsubscribe accepted")
	check_eq(router.dispatch(EventRouter.ENTITY_PLACED), 0, "no delivery after unsubscribe")
	check_eq(EventRouter.M1_EVENTS.size(), 5, "official M1 event vocabulary declared")
	check(EventRouter.M2_EXPECTED_EVENTS.size() >= 5, "additive M2 names documented (non-authoritative)")
	check_eq(router.dispatch_domain_event({"type": "unknown_future_event", "sequence": 0, "data": {}}), 0, "unknown additive event ignored")
	check_eq(
		router.dispatch_domain_event({"type": "entity_move_started", "sequence": 0, "data": {"entity_id": "e1"}}),
		0,
		"domain event dictionary shape accepted without core import"
	)
	check(EventRouter.payload_position({"to": {"x": 3, "y": 4}}, "to") == Vector2i(3, 4), "position payload helper")
	check(EventRouter.payload_footprint({"footprint": {"width": 2, "height": 1}}) == Vector2i(2, 1), "footprint payload helper")
	check_eq(EventRouter.payload_entity_id({"entity_id": "e9"}), &"e9", "entity id payload helper")
	check_eq(EventRouter.payload_blockers({"blockers": ["a", "b"]}), [&"a", &"b"], "blockers payload helper")
