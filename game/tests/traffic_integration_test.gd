extends "res://tests/framework/test_base.gd"
## M2 CROSS-LAYER integration tests (AGENT-1 / M2-INTEGRATOR).
##
## These tests wire the REAL implementations together â€” no mock event
## vocabulary and no self-consistency shortcuts:
##   TrafficGameFactory -> Simulation -> DispatchEntityCommand
##   -> TrafficPresentationAdapter -> PresentationEventRouter -> TrafficPresenter
##
## They verify the official snake_case vocabulary end to end, presentation
## hooks (movement/loading/match/objective/win/fail), the visual lifecycle of
## completed and staged entities, authoritative state synchronization,
## orientation units and movement sequencing.

const Presenter := preload("res://themes/traffic/traffic_presenter.gd")
const Router := preload("res://themes/traffic/bridge/presentation_event_router.gd")
const MatchEffect := preload("res://themes/traffic/components/match_effect.gd")
const TrafficTheme := preload("res://themes/traffic/traffic_theme.gd")

const INTEGRATION_DIR := "res://integration/traffic"

## Obsolete provisional vocabulary that must not reappear anywhere in the
## integration layer (single-vocabulary rule).
const LEGACY_NAMES: Array[String] = [
	"EntityPlaced", "EntityMoveStarted", "EntityArrived", "EntityBlocked",
	"CommandRejected", "EntityExited", "ItemLoaded", "MatchOccurred",
	"ObjectiveCompleted", "LevelCompleted", "LevelFailed",
	"StagingReceived", "StagingChanged", "StagingPressureChanged",
]


class Recorder extends RefCounted:
	var names: Array[StringName] = []
	var payloads: Dictionary = {}

	func on_event(event_name: StringName, payload: Dictionary) -> void:
		names.append(event_name)
		if not payloads.has(event_name):
			payloads[event_name] = []
		(payloads[event_name] as Array).append(payload)

	func has(event_name: StringName) -> bool:
		return names.has(event_name)

	func last_payload(event_name: StringName) -> Dictionary:
		if not payloads.has(event_name):
			return {}
		var entries: Array = payloads[event_name]
		if entries.is_empty():
			return {}
		return entries[entries.size() - 1]


func run() -> void:
	_unit_official_vocabulary()
	_unit_router_lifecycle()
	_unit_no_legacy_vocabulary_in_sources()
	_unit_enrichment_and_projection()
	_e2e_happy_path_with_turn()
	_e2e_staging_path()
	_e2e_failure_localization()
	_unit_orientation_degrees()
	_e2e_movement_synchronization()


# --- levels -------------------------------------------------------------------

func _turning_path_level() -> Dictionary:
	return {
		"level_id": "traffic_e2e_turn",
		"seed": 3,
		"width": 5,
		"height": 4,
		"staging_slots": 3,
		"paths": {"route_v1": [
			{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 2, "y": 1}, {"x": 2, "y": 2},
		]},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 2, "queue": "q_a",
			"cell": {"x": 4, "y": 2}, "footprint": {"width": 2, "height": 1}}],
		"queues": {"q_a": ["p1", "p2"]},
		"passengers": [
			{"id": "p1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p2", "color": "COLOR_A", "station": "station_a"},
		],
		"vehicles": [{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 2,
			"footprint": {"width": 1, "height": 1},
			"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"}],
	}


func _unserved_level(staging_slots: int = 1) -> Dictionary:
	return {
		"level_id": "traffic_e2e_staging",
		"seed": 4,
		"width": 5,
		"height": 2,
		"staging_slots": staging_slots,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}],
			"route_v2": [{"x": 3, "y": 1}, {"x": 4, "y": 1}],
		},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 0, "queue": "q_a",
			"cell": {"x": 4, "y": 0}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_a": []},
		"passengers": [],
		"vehicles": [{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
			"footprint": {"width": 1, "height": 1},
			"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"}],
	}


# --- harness ------------------------------------------------------------------

## Builds the production wiring: simulation + adapter + real router + real
## presenter, bound through the adapter's production-compatible API.
func _wire(definition: Dictionary) -> Dictionary:
	var simulation := TrafficGameFactory.build(definition)
	if simulation == null:
		check(false, "level builds for cross-layer wiring")
		return {}
	var router: Variant = Router.new()
	var adapter := TrafficPresentationAdapter.new(router)
	var presenter: Variant = Presenter.new()
	presenter.build()
	presenter.layout_for(Vector2(1080, 1920))
	var provider := func(id: StringName, _payload: Dictionary) -> Variant:
		var entity: Entity = simulation.get_state().get_entity(id)
		return adapter.build_entity_view(entity) if entity != null else null
	check(adapter.bind_presenter(presenter, provider), "adapter binds the presenter through the production API")
	presenter.setup(adapter.build_board_view(simulation.get_state()))
	var recorder := Recorder.new()
	router.event_forwarded.connect(Callable(recorder, "on_event"))
	return {"simulation": simulation, "router": router, "adapter": adapter, "presenter": presenter, "recorder": recorder}


func _dispatch(wired: Dictionary, entity_id: StringName) -> CommandResult:
	var simulation: Simulation = wired["simulation"]
	var adapter: TrafficPresentationAdapter = wired["adapter"]
	var result := simulation.execute(DispatchEntityCommand.new(entity_id))
	var dispatched: int = adapter.forward_result(result)
	check(dispatched > 0, "adapter dispatched presentation events for %s" % entity_id)
	return result


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_squared, 0.0, 1.0)
	return point.distance_to(a + ab * t)


## Centralized presenter disposal for the cross-layer tests. When the wired
## router is supplied its subscribers are cleared first, which breaks the
## adapter <-> router <-> subscriber-callable reference cycle (Godot does not
## collect RefCounted cycles), so the headless suite exits without leaks.
func _dispose(presenter: Variant, router: Variant = null) -> void:
	if router != null and router.has_method("clear_subscribers"):
		router.call("clear_subscribers")
	presenter.teardown()
	presenter.free()


# --- vocabulary ---------------------------------------------------------------

func _unit_official_vocabulary() -> void:
	for event_type in PresentationContract.known_event_types():
		check(TrafficEventMap.is_mapped(event_type), "contract event '%s' is mapped" % event_type)
		check_eq(TrafficEventMap.presentation_name(event_type), event_type, "presentation name is the official name for %s" % event_type)
	check_eq(
		TrafficEventMap.official_names().size(),
		PresentationContract.known_event_types().size(),
		"integration vocabulary matches the contract catalog"
	)
	check_eq(TrafficEventMap.official_names().size(), 12, "twelve official events (M1 + M2)")
	check_eq(Router.M1_EVENTS.size(), 5, "router keeps the five M1 events")
	check_eq(Router.M2_EVENTS.size(), 7, "router declares the seven additive M2 events")
	check_eq(Router.ALL_EVENTS.size(), 12, "router subscribes the full official catalog")
	check_eq(Router.M1_EVENTS.size() + Router.M2_EVENTS.size(), Router.ALL_EVENTS.size(), "M1 + M2 covers every official event")
	var snake_case_only := true
	for name in Router.ALL_EVENTS:
		if String(name) != String(name).to_lower():
			snake_case_only = false
	check(snake_case_only, "every official event name is snake_case")
	check(not TrafficEventMap.is_mapped(&"not_an_event"), "unknown event type is not mapped")
	check_eq(TrafficEventMap.presentation_name(&"not_an_event"), &"", "unknown event type has no presentation name")
	check_eq(TrafficEventMap.translate(null).size(), 0, "null events translate to nothing")
	check_eq(TrafficEventMap.translate_result(null).size(), 0, "null results translate to nothing")
	check_eq(Router.M2_EXPECTED_EVENTS[0], &"entity_arrived", "superseded proposal list kept for compatibility")
	check(not Router.M2_EVENTS.has(&"entity_arrived"), "entity_arrived is not part of the official vocabulary")


func _unit_router_lifecycle() -> void:
	var router: Variant = Router.new()
	var received: Array = []
	router.subscribe(&"entity_moved", func(name: StringName, _payload: Dictionary) -> void: received.append(name))
	check_eq(router.subscriber_count(), 1, "subscriber registered")
	check_eq(router.dispatch(&"entity_moved", {}), 1, "dispatch reaches the subscriber")
	check_eq(router.ignored_count, 0, "known event is not counted as ignored")
	check_eq(router.dispatch(&"not_an_event", {}), 0, "unknown event dispatches to nobody")
	check_eq(router.ignored_count, 1, "unknown event counted as ignored")
	router.clear_subscribers()
	check_eq(router.subscriber_count(), 0, "lifecycle helper clears subscriptions")
	check_eq(router.dispatch(&"entity_moved", {}), 0, "dispatch after clearing is a safe no-op")


func _unit_no_legacy_vocabulary_in_sources() -> void:
	var scripts := _collect_gd(INTEGRATION_DIR)
	check(scripts.size() >= 3, "integration scripts discovered (%d)" % scripts.size())
	var violations: Array[String] = []
	for path: String in scripts:
		var text := FileAccess.get_file_as_string(path)
		for legacy: String in LEGACY_NAMES:
			if text.contains(legacy):
				violations.append("%s contains '%s'" % [path, legacy])
	check(violations.is_empty(), "integration layer keeps a single official vocabulary (%s)" % ", ".join(violations))


func _collect_gd(path: String) -> Array[String]:
	var scripts: Array[String] = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):
			scripts.append(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		scripts.append_array(_collect_gd(path.path_join(directory)))
	return scripts


# --- enrichment + projection --------------------------------------------------

func _unit_enrichment_and_projection() -> void:
	var simulation := TrafficGameFactory.build(_turning_path_level())
	check(simulation != null, "enrichment level builds")
	if simulation == null:
		return
	var adapter := TrafficPresentationAdapter.new(Router.new())
	var result := simulation.execute(DispatchEntityCommand.new(&"v1"))
	var entries := TrafficEventMap.translate_result(result)
	var started: Dictionary = {}
	var moved: Dictionary = {}
	var staging: Array[Dictionary] = []
	for entry in entries:
		match entry["name"]:
			&"entity_move_started":
				started = entry
			&"entity_moved":
				moved = entry
			&"staging_changed":
				staging.append(entry)
	check(not started.is_empty(), "entity_move_started forwarded with the official name")
	check(not moved.is_empty(), "entity_moved forwarded with the official name")
	var path: Variant = started["payload"].get("path", null)
	check(typeof(path) == TYPE_ARRAY and (path as Array).size() == 5, "move-started payload carries the full logical path")
	if typeof(path) == TYPE_ARRAY and not (path as Array).is_empty():
		var last: Dictionary = (path as Array)[(path as Array).size() - 1]
		check_eq(int(last["x"]), 2, "path ends at the authoritative target (x)")
		check_eq(int(last["y"]), 2, "path ends at the authoritative target (y)")
	check(Serialization.values_equal(started["payload"].get("to", {}), {"x": 2, "y": 2}), "move-started target matches the path target")

	var state := simulation.get_state()
	var entity: Entity = state.get_entity(&"v1")
	entity.orientation = Direction.Value.EAST
	var entity_view: Variant = adapter.build_entity_view(entity)
	check_eq(entity_view.orientation, 90.0, "adapter projects EAST as 90 degrees")
	check_eq(entity_view.cell, Vector2i(0, 0), "adapter projects the entity cell")
	check_eq(entity_view.footprint, Vector2i(1, 1), "adapter projects the entity footprint")

	var staging_simulation := TrafficGameFactory.build(_unserved_level(1))
	if staging_simulation == null:
		check(false, "staging level builds")
		return
	var staging_result := staging_simulation.execute(DispatchEntityCommand.new(&"v1"))
	var staging_entries := TrafficEventMap.translate_result(staging_result)
	var staging_entry: Dictionary = {}
	for entry in staging_entries:
		if entry["name"] == &"staging_changed":
			staging_entry = entry
	check(not staging_entry.is_empty(), "staging_changed forwarded with the official name")
	check_eq(staging_entry["payload"].get("pressure"), "full", "staging_changed payload carries derived pressure")
	var staging_view: Variant = adapter.build_staging_view(staging_simulation.get_state())
	check_eq(staging_view.pressure, &"full", "staging projection reports authoritative pressure")
	check_eq(staging_view.slot_count, 1, "staging projection reports arbitrary slot count")
	check(staging_view.occupant_at(0) != null, "staging projection exposes the staged entity")
	var progress := adapter.build_progress_snapshot(staging_simulation.get_state())
	check(Serialization.is_primitive_tree(progress), "progress snapshot stays primitive")

	var before := staging_simulation.snapshot()
	adapter.build_board_view(staging_simulation.get_state())
	adapter.build_entity_view(entity)
	adapter.build_staging_view(staging_simulation.get_state())
	check(Serialization.values_equal(before, staging_simulation.snapshot()), "adapter projection never mutates simulation state")


# --- end-to-end ---------------------------------------------------------------

func _e2e_happy_path_with_turn() -> void:
	var wired := _wire(_turning_path_level())
	if wired.is_empty():
		return
	var simulation: Simulation = wired["simulation"]
	var presenter: Variant = wired["presenter"]
	var recorder: Recorder = wired["recorder"]
	var adapter: TrafficPresentationAdapter = wired["adapter"]

	var objective_events: Array = []
	presenter.objective_presented.connect(func(id: StringName) -> void: objective_events.append(id))

	var result := _dispatch(wired, &"v1")
	check(result.is_success(), "happy-path dispatch succeeds")

	# Official vocabulary end to end (no provisional names).
	check(recorder.has(&"entity_move_started"), "presenter received entity_move_started")
	check(recorder.has(&"entity_moved"), "presenter received entity_moved")
	check(recorder.has(&"item_loaded"), "presenter received item_loaded")
	check(recorder.has(&"match_occurred"), "presenter received match_occurred")
	check(recorder.has(&"entity_completed"), "presenter received entity_completed")
	check(recorder.has(&"objective_completed"), "presenter received objective_completed")
	check(recorder.has(&"game_completed"), "presenter received game_completed")
	check(not recorder.has(&"EntityArrived"), "no provisional PascalCase name reached the router")
	var non_official: Array[String] = []
	for name in recorder.names:
		if not Router.ALL_EVENTS.has(name):
			non_official.append(String(name))
	check(non_official.is_empty(), "every forwarded event uses the official vocabulary (%s)" % ", ".join(non_official))

	# Movement started: bounded lock, animation active, entity still on board.
	var view: Node2D = presenter.board_view.entity_view(&"v1")
	check(view != null, "entity view exists during movement")
	check(presenter.is_input_locked(), "movement acquired the input lock")
	check(presenter.input_lock_remaining() <= Presenter.RESULT_LOCK_CAP + 0.0001, "every presentation lock is bounded")
	var start_center: Vector2 = presenter.board_view.cell_center(Vector2i(0, 0))
	check(view.position.distance_to(start_center) < 0.5, "no visual snap-back before the animation advances")

	# Hooks run synchronously with the (real) completion outcome.
	check(_has_effect(presenter), "match/loading hook spawned a match effect")
	check_eq(objective_events.size(), 1, "objective hook fired once")
	check_eq(presenter.active_sequence(), &"win", "win hook ran immediately (simulation completion is not delayed)")
	check(simulation.get_state().is_won(), "simulation is authoritative: level won")

	# The animation follows the supplied path (a straight line would stay close
	# to the start->target segment).
	var target_center: Vector2 = presenter.board_view.cell_center(Vector2i(2, 2))
	var cell_px: float = presenter.board_view.cell_center(Vector2i(1, 0)).distance_to(start_center)
	var max_off_segment := 0.0
	for step in 60:
		presenter.advance(0.02)
		var moving_view: Node2D = presenter.board_view.entity_view(&"v1")
		if moving_view == null:
			break
		max_off_segment = maxf(max_off_segment, _distance_to_segment(moving_view.position, start_center, target_center))
	check(max_off_segment > cell_px * 0.25, "presentation follows the supplied path, not a straight line")

	# Visual lifecycle: the completed entity left the board once movement ended.
	check(presenter.board_view.entity_view(&"v1") == null, "completed entity removed after its animation finished")

	# Bounded locks: after the cosmetic sequences expire nothing stays locked.
	for step in 5:
		presenter.advance(1.0)
	check(not presenter.is_input_locked(), "all presentation locks released after the bounded sequences")

	# Authoritative synchronization after the command.
	var updated: int = adapter.sync_authoritative_state(simulation.get_state(), presenter)
	check_eq(updated, 1, "authoritative sync updated the destination")
	var destination_view: Node2D = presenter.board_view.destination_view(&"station_a")
	check(destination_view != null, "destination view exists after sync")
	if destination_view != null:
		check_eq(destination_view.queue_size(), 0, "authoritative queue drained in presentation")
	check_eq(presenter.staging_view.pressure(), TW_PRESSURE_NORMAL, "staging pressure synchronized")
	_dispose(presenter, wired["router"])


const TW_PRESSURE_NORMAL := &"normal"


func _has_effect(presenter: Variant) -> bool:
	for child: Node in presenter.effects_layer.get_children():
		if child.get_script() == MatchEffect:
			return true
	return false


func _e2e_staging_path() -> void:
	var wired := _wire(_unserved_level(1))
	if wired.is_empty():
		return
	var simulation: Simulation = wired["simulation"]
	var presenter: Variant = wired["presenter"]
	var recorder: Recorder = wired["recorder"]
	var adapter: TrafficPresentationAdapter = wired["adapter"]

	_dispatch(wired, &"v1")
	check(recorder.has(&"staging_changed"), "presenter received staging_changed")
	check_eq(recorder.last_payload(&"staging_changed").get("action"), "added", "staging action forwarded")
	check_eq(recorder.last_payload(&"staging_changed").get("pressure"), "full", "pressure forwarded with the staging event")
	check_eq(presenter.staging_view.pressure(), &"full", "presentation reflects staging pressure")
	check(recorder.has(&"game_failed"), "presenter received game_failed (no valid moves)")
	check_eq(recorder.last_payload(&"game_failed").get("fail_reason"), "no_valid_moves", "fail reason forwarded from the simulation")
	check_eq(presenter.active_sequence(), &"fail", "fail hook ran")
	check(simulation.get_state().is_lost(), "simulation is authoritative: level lost")
	check(presenter.board_view.entity_view(&"v1") != null, "staged entity remains visible while its animation runs")

	presenter.advance(1.0)
	check(presenter.board_view.entity_view(&"v1") == null, "staged entity left the board after its animation finished")
	var updated: int = adapter.sync_authoritative_state(simulation.get_state(), presenter)
	check_eq(updated, 1, "authoritative sync ran for the staging level")
	var staging_data: Variant = presenter.staging_view.get_staging_data()
	check(staging_data != null, "presentation holds authoritative staging data")
	if staging_data != null:
		check_eq(staging_data.slot_count, 1, "authoritative slot count applied")
		check(staging_data.occupant_at(0) != null, "authoritative staging occupant applied")
	check_eq(presenter.staging_view.pressure(), &"full", "authoritative pressure applied after sync")
	var destination_view: Node2D = presenter.board_view.destination_view(&"station_a")
	check(destination_view != null and destination_view.queue_size() == 0, "authoritative empty queue applied after sync")
	_dispose(presenter, wired["router"])


func _e2e_failure_localization() -> void:
	# no_valid_moves (single unserved vehicle).
	var single := _wire(_unserved_level(2))
	if not single.is_empty():
		var single_presenter: Variant = single["presenter"]
		var single_recorder: Recorder = single["recorder"]
		_dispatch(single, &"v1")
		check_eq(single_recorder.last_payload(&"game_failed").get("fail_reason"), "no_valid_moves", "no_valid_moves reached presentation")
		check_eq(
			single_presenter.fail_reason_localization_key(&"no_valid_moves"),
			&"level.fail.no_moves",
			"no_valid_moves maps to its localization key through the real presenter"
		)
		_dispose(single_presenter, single["router"])

	# staging_full (one slot, two unserved vehicles).
	var definition := _unserved_level(1)
	definition["vehicles"].append({"id": "v2", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 3, "y": 1}, "route": "route_v2", "station": "station_a"})
	var full := _wire(definition)
	if full.is_empty():
		return
	var presenter: Variant = full["presenter"]
	var recorder: Recorder = full["recorder"]
	var simulation: Simulation = full["simulation"]
	_dispatch(full, &"v1")
	check_eq(simulation.get_state().is_lost(), false, "level continues while a valid move remains")
	check_eq(simulation.get_state().staging.occupied_count(), 1, "first unserved vehicle staged")
	_dispatch(full, &"v2")
	check_eq(recorder.last_payload(&"game_failed").get("fail_reason"), "staging_full", "staging_full reached presentation")
	check_eq(
		presenter.fail_reason_localization_key(&"staging_full"),
		&"level.fail.staging_full",
		"staging_full maps to its localization key through the real presenter"
	)
	check_eq(presenter.active_sequence(), &"fail", "staging_full runs the fail sequence")
	_dispose(presenter, full["router"])


func _unit_orientation_degrees() -> void:
	var wired := _wire(_turning_path_level())
	if wired.is_empty():
		return
	var simulation: Simulation = wired["simulation"]
	var adapter: TrafficPresentationAdapter = wired["adapter"]
	var presenter: Variant = wired["presenter"]
	var entity: Entity = simulation.get_state().get_entity(&"v1")

	entity.orientation = Direction.Value.EAST
	var east: Variant = adapter.build_entity_view(entity)
	check_eq(east.orientation, 90.0, "EAST projects as 90 degrees")
	entity.orientation = Direction.Value.WEST
	var west: Variant = adapter.build_entity_view(entity)
	check_eq(west.orientation, 270.0, "WEST projects as 270 degrees")
	check_eq(TrafficTheme.DIRECTION_DEGREES[&"east"], 90.0, "presentation theme documents 90 degrees for east")
	check_eq(TrafficTheme.DIRECTION_DEGREES[&"west"], 270.0, "presentation theme documents 270 degrees for west")

	presenter.show_entity(west)
	var view: Node2D = presenter.board_view.entity_view(&"v1")
	check(view != null, "entity view created for orientation check")
	if view != null:
		check_eq(view.rotation_degrees, 270.0, "presentation applies degrees directly")
	_dispose(presenter, wired["router"])


func _e2e_movement_synchronization() -> void:
	var presenter: Variant = Presenter.new()
	presenter.build()
	presenter.layout_for(Vector2(1080, 1920))
	presenter.setup(null)

	presenter.handle_event(Router.ENTITY_PLACED, {
		"entity_id": "e1",
		"position": {"x": 0, "y": 0},
		"footprint": {"width": 1, "height": 1},
	}, Callable())
	presenter.handle_event(Router.ENTITY_MOVE_STARTED, {
		"entity_id": "e1",
		"from": {"x": 0, "y": 0},
		"to": {"x": 2, "y": 0},
		"path": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
	}, Callable())
	# Arrival arrives synchronously, with no animation time in between.
	presenter.handle_event(Router.ENTITY_MOVED, {
		"entity_id": "e1",
		"from": {"x": 0, "y": 0},
		"to": {"x": 2, "y": 0},
		"path": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
	}, Callable())

	var start_center: Vector2 = presenter.board_view.cell_center(Vector2i(0, 0))
	var target_center: Vector2 = presenter.board_view.cell_center(Vector2i(2, 0))
	var view: Node2D = presenter.board_view.entity_view(&"e1")
	check(view != null, "moving entity view exists")
	if view != null:
		check(view.position.distance_to(start_center) < 0.5, "no backwards snap when entity_moved arrives mid-animation")
		check_eq(view.get_data().cell, Vector2i(0, 0), "logical cell is not moved ahead of the animation")
	check(presenter.is_input_locked(), "movement lock still held while animating")
	check(presenter.input_lock_remaining() <= Presenter.MOVE_LOCK_CAP + 0.0001, "movement lock remains bounded")

	presenter.advance(1.0)
	var settled: Node2D = presenter.board_view.entity_view(&"e1")
	check(settled != null, "entity view survives the animation")
	if settled != null:
		check(settled.position.distance_to(target_center) < 0.5, "authoritative target wins when the animation completes")
		check_eq(settled.get_data().cell, Vector2i(2, 0), "logical cell matches the authoritative target")
	check(not presenter.is_input_locked(), "movement lock released after completion")

	# An arrival for an entity with no active movement snaps immediately.
	presenter.handle_event(Router.ENTITY_PLACED, {
		"entity_id": "e2",
		"position": {"x": 0, "y": 1},
		"footprint": {"width": 1, "height": 1},
	}, Callable())
	presenter.handle_event(Router.ENTITY_MOVED, {
		"entity_id": "e2",
		"from": {"x": 0, "y": 1},
		"to": {"x": 3, "y": 1},
	}, Callable())
	var idle_view: Node2D = presenter.board_view.entity_view(&"e2")
	check(idle_view != null and idle_view.get_data().cell == Vector2i(3, 1), "idle arrivals still snap to the authoritative target")

	# Unknown M2 proposal names stay safely ignorable.
	check(not presenter.handle_event(Router.M2_EXPECTED_EVENTS[0], {}), "superseded proposal name remains ignored")
	check(not presenter.handle_event(&"totally_unknown_event", {}), "unknown events remain ignored")
	_dispose(presenter)
