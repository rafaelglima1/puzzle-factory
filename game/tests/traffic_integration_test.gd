extends "res://tests/framework/test_base.gd"
## M2 Traffic integration layer: event mapping, presentation adapter, DTOs.

const ROBOT := preload("res://themes/traffic/bridge/presentation_event_router.gd")


class Collector extends RefCounted:
	var received: Array[Dictionary] = []

	func on_event(event_name: StringName, payload: Dictionary) -> void:
		received.append({"name": event_name, "payload": payload})

	func names() -> Array[StringName]:
		var collected: Array[StringName] = []
		for entry in received:
			collected.append(entry["name"])
		return collected

	func payload_for(event_name: StringName) -> Dictionary:
		for entry in received:
			if entry["name"] == event_name:
				return entry["payload"]
		return {}


func run() -> void:
	_event_map_catalogue()
	_translation_payloads()
	_adapter_forwards_to_router()
	_adapter_read_only()
	_view_data_projection()
	_end_to_end_session_names()


func _level() -> Dictionary:
	return {
		"level_id": "traffic_adapter",
		"seed": 4,
		"width": 5,
		"height": 2,
		"staging_slots": 2,
		"paths": {"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 2, "queue": "q_a",
			"cell": {"x": 3, "y": 0}, "footprint": {"width": 2, "height": 1}}],
		"queues": {"q_a": ["p1"]},
		"passengers": [{"id": "p1", "color": "COLOR_A", "station": "station_a"}],
		"vehicles": [{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 2,
			"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"}],
	}


func _new_adapter(collector: Collector) -> Dictionary:
	var router: Variant = ROBOT.new()
	var adapter := TrafficPresentationAdapter.new(router)
	for event_type in PresentationContract.known_event_types():
		var name := TrafficEventMap.presentation_name(event_type)
		if name != &"":
			router.subscribe(name, Callable(collector, "on_event"))
	router.subscribe(TrafficEventMap.NAME_STAGING_RECEIVED, Callable(collector, "on_event"))
	router.subscribe(TrafficEventMap.NAME_STAGING_CHANGED, Callable(collector, "on_event"))
	router.subscribe(TrafficEventMap.NAME_STAGING_PRESSURE, Callable(collector, "on_event"))
	return {"adapter": adapter, "router": router}


func _event_map_catalogue() -> void:
	var unmapped: Array[String] = []
	for event_type in PresentationContract.known_event_types():
		if not TrafficEventMap.is_mapped(event_type):
			unmapped.append(String(event_type))
	check(unmapped.is_empty(), "every contract event type is mapped to presentation (%s)" % ", ".join(unmapped))
	check(not TrafficEventMap.is_mapped(&"not_an_event"), "unknown event type is not mapped")
	check_eq(TrafficEventMap.presentation_name(DomainEvent.ENTITY_MOVED), &"EntityArrived", "entity_moved maps to EntityArrived")
	check_eq(TrafficEventMap.presentation_name(DomainEvent.ENTITY_COMPLETED), &"EntityExited", "entity_completed maps to EntityExited")
	check_eq(TrafficEventMap.presentation_name(DomainEvent.GAME_COMPLETED), &"LevelCompleted", "game_completed maps to LevelCompleted")
	check_eq(TrafficEventMap.presentation_name(DomainEvent.GAME_FAILED), &"LevelFailed", "game_failed maps to LevelFailed")
	check_eq(TrafficEventMap.presentation_name(DomainEvent.STAGING_CHANGED), &"StagingChanged", "staging default name")
	check_eq(TrafficEventMap.presentation_name(&"not_an_event"), &"", "unmapped name is empty")

	check_eq(TrafficEventMap.pressure_for(0, 4), &"normal", "empty staging is normal")
	check_eq(TrafficEventMap.pressure_for(1, 4), &"normal", "half-full staging is normal")
	check_eq(TrafficEventMap.pressure_for(3, 4), &"warning", "one free slot is a warning")
	check_eq(TrafficEventMap.pressure_for(4, 4), &"full", "no free slots is full")
	check_eq(TrafficEventMap.pressure_for(1, 1), &"full", "single slot occupied is full")
	check_eq(TrafficEventMap.pressure_for(0, 0), &"full", "zero capacity is full")
	check_eq(TrafficEventMap.pressure_for(0, 1), &"warning", "one free slot of one is a warning")


func _translation_payloads() -> void:
	var moved := DomainEvent.entity_moved(&"v1", GridPosition.new(0, 0), GridPosition.new(2, 0), [
		GridPosition.new(0, 0), GridPosition.new(1, 0), GridPosition.new(2, 0),
	])
	var moved_entries := TrafficEventMap.translate(moved)
	check_eq(moved_entries.size(), 1, "move translates to one presentation event")
	check_eq(moved_entries[0]["name"], &"EntityArrived", "move presentation name")
	check_eq(int(moved_entries[0]["payload"]["path"].size()), 3, "path cells forwarded for interpolation")

	var staging := StagingArea.new(2)
	staging.add(&"v1")
	var added := DomainEvent.staging_changed(DomainEvent.STAGING_ADDED, &"v1", 0, staging)
	var added_entries := TrafficEventMap.translate(added)
	check_eq(added_entries.size(), 2, "staging add translates to receipt + pressure")
	check_eq(added_entries[0]["name"], &"StagingReceived", "staging receipt name")
	check_eq(added_entries[1]["name"], &"StagingPressureChanged", "staging pressure name")
	check_eq(added_entries[1]["payload"]["pressure"], "warning", "pressure computed for one free slot")

	staging.remove(&"v1")
	var removed := DomainEvent.staging_changed(DomainEvent.STAGING_REMOVED, &"v1", 0, staging)
	var removed_entries := TrafficEventMap.translate(removed)
	check_eq(removed_entries.size(), 2, "staging removal translates to change + pressure")
	check_eq(removed_entries[0]["name"], &"StagingChanged", "staging removal name")

	var failed := DomainEvent.game_failed(FailReason.to_string_name(FailReason.Value.NO_VALID_MOVES), 3)
	var failed_entries := TrafficEventMap.translate(failed)
	check_eq(failed_entries.size(), 1, "failure translates to one event")
	check_eq(failed_entries[0]["name"], &"LevelFailed", "failure presentation name")
	check_eq(failed_entries[0]["payload"]["fail_reason"], "no_valid_moves", "failure reason forwarded")

	check_eq(TrafficEventMap.translate(DomainEvent.new(&"mystery", {"x": 1})).size(), 0, "unknown events translate to nothing")
	check_eq(TrafficEventMap.translate(null).size(), 0, "null events are safe")
	check_eq(TrafficEventMap.translate_result(null).size(), 0, "null results are safe")


func _adapter_forwards_to_router() -> void:
	var collector := Collector.new()
	var built := _new_adapter(collector)
	var adapter: Variant = built["adapter"]
	var simulation := TrafficGameFactory.build(_level())
	check(simulation != null, "adapter level builds")
	if simulation == null:
		return
	var result := simulation.execute(DispatchEntityCommand.new(&"v1"))
	var dispatched: int = adapter.forward_result(result)
	check(dispatched > 0, "adapter dispatches presentation events")
	var names := collector.names()
	check(names.has(&"EntityMoveStarted"), "move start forwarded")
	check(names.has(&"EntityArrived"), "arrival forwarded")
	check(names.has(&"ItemLoaded"), "loading forwarded")
	check(names.has(&"MatchOccurred"), "match forwarded")
	check(names.has(&"EntityExited"), "completion forwarded")
	check(names.has(&"ObjectiveCompleted"), "objective forwarded")
	check(names.has(&"LevelCompleted"), "level completion forwarded")
	check_eq(adapter.forwarded_event_count, dispatched, "forwarded counter matches dispatches")

	var unknown_result := CommandResult.success([DomainEvent.new(&"mystery_event", {"a": 1})])
	var unknown_dispatched: int = adapter.forward_result(unknown_result)
	check_eq(unknown_dispatched, 0, "unknown events dispatch nothing")
	check_eq(adapter.ignored_event_count, 1, "unknown events are counted as ignored")

	var placed_result := CommandResult.success([
		DomainEvent.entity_placed(&"v9", GridPosition.new(1, 1), Footprint.new(1, 1)),
	])
	check_eq(adapter.forward_result(placed_result), 1, "placement forwards one presentation event")
	check(collector.names().has(&"EntityPlaced"), "placement presentation name")
	var rejected_result := CommandResult.rejected(CommandResult.Status.INVALID, &"unknown_entity", [
		DomainEvent.command_rejected(CommandResult.Status.INVALID, &"unknown_entity", &"ghost"),
	])
	check(adapter.forward_result(rejected_result) > 0, "rejection forwards presentation feedback")
	check(collector.names().has(&"CommandRejected"), "rejection presentation name")


func _adapter_read_only() -> void:
	var collector := Collector.new()
	var built := _new_adapter(collector)
	var adapter: Variant = built["adapter"]
	var simulation := TrafficGameFactory.build(_level())
	if simulation == null:
		check(false, "adapter level builds for read-only check")
		return
	var state := simulation.get_state()
	var result := simulation.execute(DispatchEntityCommand.new(&"v1"))
	var before := simulation.snapshot()
	adapter.forward_result(result)
	adapter.build_board_view(state)
	adapter.build_staging_view(state)
	adapter.build_progress_snapshot(state)
	adapter.build_entity_view(state.get_entity(&"v1"))
	adapter.build_item_view(Item.new(&"i1", &"unit_item", &"COLOR_A"))
	check(Serialization.values_equal(before, simulation.snapshot()), "adapter never mutates simulation state")


func _view_data_projection() -> void:
	var simulation := TrafficGameFactory.build(_level())
	if simulation == null:
		check(false, "adapter level builds for projection")
		return
	var state := simulation.get_state()
	var adapter := TrafficPresentationAdapter.new()

	var board_view: Variant = adapter.build_board_view(state)
	check_eq(board_view.width, 5, "board view width")
	check_eq(board_view.height, 2, "board view height")
	check_eq(board_view.entity_count(), 1, "board view lists placed entities")
	check_eq(board_view.destination_count(), 1, "board view lists stations")

	var entity_view: Variant = adapter.build_entity_view(state.get_entity(&"v1"))
	check_eq(entity_view.id, &"v1", "entity view id")
	check_eq(entity_view.entity_type, &"compact", "entity view type")
	check_eq(entity_view.color_key, &"COLOR_A", "entity view color key")
	check_eq(entity_view.cell, Vector2i(0, 0), "entity view cell")
	check_eq(entity_view.state, &"idle", "entity view state name")
	check(typeof(entity_view.orientation) == TYPE_FLOAT, "entity view orientation is a float")
	check_eq(entity_view.get_script().resource_path, "res://themes/traffic/model_entity_view_data.gd", "uses the AGENT-2 entity DTO")

	var destination_view: Variant = adapter.build_destination_view(state.get_destination(&"station_a"), state)
	check_eq(destination_view.id, &"station_a", "station view id")
	check_eq(destination_view.destination_type, &"station", "station view type")
	check_eq(destination_view.accepted_color_keys, state.get_destination(&"station_a").accepted_color_keys, "accepted keys forwarded")
	check_eq(destination_view.capacity, 2, "station capacity forwarded")
	check_eq(destination_view.occupancy, 0, "station occupancy starts at zero")
	check_eq(destination_view.queue_color_keys, [&"COLOR_A"], "queued item colors forwarded in FIFO order")
	check_eq(destination_view.cell, Vector2i(3, 0), "station anchor cell from metadata")
	check_eq(destination_view.footprint, Vector2i(2, 1), "station anchor footprint from metadata")

	var item_view: Variant = adapter.build_item_view(state.get_item(&"p1"))
	check_eq(item_view.id, &"p1", "item view id")
	check_eq(item_view.item_type, &"passenger_standard", "item view type")

	var staging_view: Variant = adapter.build_staging_view(state)
	check_eq(staging_view.slot_count, 2, "staging view slot count")
	check_eq(staging_view.pressure, &"normal", "staging view pressure")
	check_eq(staging_view.occupants.size(), 2, "staging view occupant rows")

	var progress := adapter.build_progress_snapshot(state)
	check_eq(int(progress["queued_passengers"]), 1, "progress snapshot item count")
	check_eq(int(progress["staging_slots"]), 2, "progress snapshot slot count")
	check_eq(String(progress["fail_reason"]), "", "progress snapshot has no failure yet")
	check(Serialization.is_primitive_tree(progress), "progress snapshot stays primitive")


func _end_to_end_session_names() -> void:
	var collector := Collector.new()
	var built := _new_adapter(collector)
	var adapter: Variant = built["adapter"]

	# Session A: a completing dispatch.
	var workspace := TrafficGameFactory.build(_level())
	if workspace != null:
		adapter.forward_result(workspace.execute(DispatchEntityCommand.new(&"v1")))

	# Session B: blocked + rejected.
	var blocked_level := _level()
	blocked_level["paths"]["route_blocked"] = [{"x": 0, "y": 1}, {"x": 1, "y": 1}]
	blocked_level["paths"]["route_free"] = [{"x": 1, "y": 1}, {"x": 2, "y": 1}]
	blocked_level["vehicles"].append({"id": "v2", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 0, "y": 1}, "route": "route_blocked", "station": "station_a"})
	blocked_level["vehicles"].append({"id": "v3", "type": "van", "color": "COLOR_A", "capacity": 1,
		"footprint": {"width": 1, "height": 1},
		"cell": {"x": 1, "y": 1}, "route": "route_free", "station": "station_a"})
	var blocked_simulation := TrafficGameFactory.build(blocked_level)
	if blocked_simulation == null:
		check(false, "blocked session level builds")
	else:
		adapter.forward_result(blocked_simulation.execute(DispatchEntityCommand.new(&"v2")))
		adapter.forward_result(blocked_simulation.execute(DispatchEntityCommand.new(&"ghost")))

	var staging_level := _level()
	staging_level["queues"]["q_a"] = []
	staging_level["passengers"] = []
	var staging_simulation := TrafficGameFactory.build(staging_level)
	if staging_simulation != null:
		adapter.forward_result(staging_simulation.execute(DispatchEntityCommand.new(&"v1")))

	# Placement (produced by commands, not by level setup) and rejection.
	adapter.forward_result(CommandResult.success([
		DomainEvent.entity_placed(&"v9", GridPosition.new(1, 1), Footprint.new(1, 1)),
	]))

	var names := collector.names()
	# StagingChanged (the removal action) is not emitted by M2 rules (nothing
	# un-stages an entity yet); its mapping is covered by _translation_payloads.
	var expected: Array[StringName] = [
		&"EntityPlaced", &"EntityMoveStarted", &"EntityArrived", &"EntityBlocked",
		&"CommandRejected", &"EntityExited", &"ItemLoaded", &"MatchOccurred",
		&"StagingReceived", &"StagingPressureChanged",
		&"ObjectiveCompleted", &"LevelCompleted", &"LevelFailed",
	]
	var missing: Array[String] = []
	for name in expected:
		if not names.has(name):
			missing.append(String(name))
	check(missing.is_empty(), "end-to-end session covers every runtime presentation event (%s)" % ", ".join(missing))
