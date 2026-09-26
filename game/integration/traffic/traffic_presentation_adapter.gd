class_name TrafficPresentationAdapter
extends RefCounted
## PRODUCT INTEGRATION LAYER (Traffic) — OWNER: AGENT-1.
##
## Bridges generic simulation output to the AGENT-2 Traffic presentation
## contracts. This is the ONLY translation point between the layers:
##
##   generic core / puzzle  ->  adapter  ->  Traffic presentation DTOs + router
##
## Dependency direction (ADR-013):
## - the adapter may import generic core/puzzle AND Traffic presentation;
## - presentation (`game/themes/traffic`, `game/ui`, `game/audio`,
##   `game/haptics`) must keep importing neither core nor puzzle.
##
## The adapter is read-only with respect to simulation state: it translates
## events and projects state into view data, and never validates moves,
## changes matching/staging/enumeration, grants rewards or waits for
## animation. Callers keep ownership of the simulation.

const ROUTER_SCRIPT := preload("res://themes/traffic/bridge/presentation_event_router.gd")
const ENTITY_VIEW_SCRIPT := preload("res://themes/traffic/model_entity_view_data.gd")
const ITEM_VIEW_SCRIPT := preload("res://themes/traffic/model_item_view_data.gd")
const DESTINATION_VIEW_SCRIPT := preload("res://themes/traffic/model_destination_view_data.gd")
const STAGING_VIEW_SCRIPT := preload("res://themes/traffic/model_staging_view_data.gd")
const BOARD_VIEW_SCRIPT := preload("res://themes/traffic/model_board_view_data.gd")

## Documented orientation mapping: Direction value -> radians for presentation.
const ORIENTATION_RADIANS := {
	Direction.Value.NORTH: 0.0,
	Direction.Value.EAST: PI / 2.0,
	Direction.Value.SOUTH: PI,
	Direction.Value.WEST: -PI / 2.0,
}

## Presentation event router (AGENT-2 contract); created by default.
var router: Variant = null
var forwarded_event_count := 0
var ignored_event_count := 0


func _init(p_router: Variant = null) -> void:
	router = p_router if p_router != null else ROUTER_SCRIPT.new()


## Forwards a command result's events to presentation; returns the number of
## presentation events dispatched, and counts unmapped events as ignored.
func forward_result(result: CommandResult) -> int:
	var dispatched := 0
	if result == null:
		return 0
	for event in result.events:
		if not TrafficEventMap.is_mapped(event.event_type):
			ignored_event_count += 1
			continue
		for entry in TrafficEventMap.translate(event):
			_dispatch(str(entry["name"]), entry["payload"])
			dispatched += 1
	return dispatched


func _dispatch(name: StringName, payload: Dictionary) -> void:
	forwarded_event_count += 1
	if router != null:
		router.dispatch(name, payload)


# --- state projection (view data) ---------------------------------------------

func build_board_view(state: GameState) -> Variant:
	var view: Variant = BOARD_VIEW_SCRIPT.new(state.board.dimensions.width, state.board.dimensions.height)
	for entity_id in state.entity_ids():
		var entity: Entity = state.entities[entity_id]
		if entity.is_placed():
			view.add_entity(build_entity_view(entity))
	for destination_id in state.destination_ids():
		view.add_destination(build_destination_view(state.destinations[destination_id], state))
	return view


func build_entity_view(entity: Entity) -> Variant:
	var view: Variant = ENTITY_VIEW_SCRIPT.new(entity.id, entity.entity_type, entity.color_key)
	view.footprint = Vector2i(entity.footprint.width, entity.footprint.height)
	view.cell = _cell_of(entity)
	view.orientation = ORIENTATION_RADIANS.get(entity.orientation, 0.0)
	view.state = EntityState.to_string_name(entity.state)
	view.metadata = Serialization.canonicalize(entity.metadata)
	return view


func build_item_view(item: Item) -> Variant:
	var view: Variant = ITEM_VIEW_SCRIPT.new(item.id, item.item_type, item.color_key)
	view.destination_id = item.destination_id
	view.metadata = Serialization.canonicalize(item.metadata)
	return view


func build_destination_view(destination: Destination, state: GameState) -> Variant:
	var view: Variant = DESTINATION_VIEW_SCRIPT.new(destination.id)
	view.destination_type = destination.destination_type
	view.accepted_color_keys = _copied_keys(destination.accepted_color_keys)
	view.capacity = destination.capacity
	view.occupancy = destination.processed_count
	view.queue_color_keys = _queue_color_keys(destination, state)
	view.state = Destination.state_to_string_name(destination.state)
	var anchors := _station_anchors(destination)
	view.cell = anchors["cell"]
	view.footprint = anchors["footprint"]
	view.metadata = Serialization.canonicalize(destination.metadata)
	return view


func build_staging_view(state: GameState) -> Variant:
	var view: Variant = STAGING_VIEW_SCRIPT.new(state.staging.slot_count)
	for slot_index in state.staging.slot_count:
		var entity_id := state.staging.occupant_at(slot_index)
		if entity_id == StagingArea.FREE_SLOT:
			view.set_occupant(slot_index, null)
			continue
		var entity := state.get_entity(entity_id)
		view.set_occupant(slot_index, build_entity_view(entity) if entity != null else null)
	view.pressure = TrafficEventMap.pressure_for(state.staging.occupied_count(), state.staging.slot_count)
	return view


## Fleet summary used by HUD chips (counts only; presentation formats them).
func build_progress_snapshot(state: GameState) -> Dictionary:
	var waiting := 0
	var completed := 0
	for entity_id in state.entity_ids():
		var entity: Entity = state.entities[entity_id]
		match entity.state:
			EntityState.Value.COMPLETED:
				completed += 1
			EntityState.Value.WAITING:
				waiting += 1
	return {
		"queued_passengers": state.items.size(),
		"completed_vehicles": completed,
		"waiting_vehicles": waiting,
		"staging_occupied": state.staging.occupied_count(),
		"staging_slots": state.staging.slot_count,
		"completion_state": String(GameState.completion_state_name(state.completion_state)),
		"fail_reason": String(state.fail_reason),
		"move_count": state.move_index,
	}


func _cell_of(entity: Entity) -> Vector2i:
	if entity.position == null:
		return Vector2i.ZERO
	return Vector2i(entity.position.x, entity.position.y)


func _copied_keys(color_keys: Array[StringName]) -> Array[StringName]:
	var copy: Array[StringName] = []
	copy.assign(color_keys)
	return copy


func _queue_color_keys(destination: Destination, state: GameState) -> Array[StringName]:
	var keys: Array[StringName] = []
	if destination.queue_id == &"":
		return keys
	var queue := state.get_queue(destination.queue_id)
	if queue == null:
		return keys
	for item_id in queue.item_ids():
		var item := state.get_item(item_id)
		if item != null:
			keys.append(item.color_key)
	return keys


## Station anchors are Traffic composition data stored in generic metadata.
func _station_anchors(destination: Destination) -> Dictionary:
	var cell := Vector2i.ZERO
	var footprint := Vector2i(2, 2)
	var metadata: Dictionary = destination.metadata if typeof(destination.metadata) == TYPE_DICTIONARY else {}
	var cell_data: Variant = metadata.get("cell", null)
	if typeof(cell_data) == TYPE_DICTIONARY:
		cell = Vector2i(int(cell_data.get("x", 0)), int(cell_data.get("y", 0)))
	var footprint_data: Variant = metadata.get("footprint", null)
	if typeof(footprint_data) == TYPE_DICTIONARY:
		footprint = Vector2i(int(footprint_data.get("width", 2)), int(footprint_data.get("height", 2)))
	return {"cell": cell, "footprint": footprint}
