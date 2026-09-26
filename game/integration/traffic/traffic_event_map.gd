class_name TrafficEventMap
extends RefCounted
## PRODUCT INTEGRATION LAYER (Traffic) — OWNER: AGENT-1.
##
## There is exactly ONE event vocabulary: the official snake_case domain event
## names from `docs/PRESENTATION_BRIDGE.md` (contract version 1, additively
## extended in M2). This layer forwards them **unchanged** and must never
## rename them into a second, competing (provisional) vocabulary — the AGENT-2
## router/presenter consumes the official names directly.
##
## What this layer does add is presentation-side ENRICHMENT. It never mutates a
## DomainEvent and never mutates simulation state; it only builds a payload
## copy:
## - `entity_move_started` gains `path` (copied from the matching `entity_moved`
##   in the same command result) so presentation can interpolate the real route
##   instead of a straight line, with `[from, to]` as fallback.
## - `staging_changed` gains `pressure` (`normal` / `warning` / `full`) derived
##   from the authoritative occupancy counts.
##
## Unknown event types produce no entry and stay safely ignorable.

const PRESSURE_NORMAL := &"normal"
const PRESSURE_WARNING := &"warning"
const PRESSURE_FULL := &"full"

## Official vocabulary: domain event -> official presentation name (identity).
## Kept explicit so tests can assert that no rename is introduced.
const OFFICIAL_NAMES := {
	DomainEvent.ENTITY_PLACED: &"entity_placed",
	DomainEvent.ENTITY_MOVE_STARTED: &"entity_move_started",
	DomainEvent.ENTITY_MOVED: &"entity_moved",
	DomainEvent.ENTITY_BLOCKED: &"entity_blocked",
	DomainEvent.COMMAND_REJECTED: &"command_rejected",
	DomainEvent.ENTITY_COMPLETED: &"entity_completed",
	DomainEvent.ITEM_LOADED: &"item_loaded",
	DomainEvent.MATCH_OCCURRED: &"match_occurred",
	DomainEvent.STAGING_CHANGED: &"staging_changed",
	DomainEvent.OBJECTIVE_COMPLETED: &"objective_completed",
	DomainEvent.GAME_COMPLETED: &"game_completed",
	DomainEvent.GAME_FAILED: &"game_failed",
}


static func is_mapped(event_type: StringName) -> bool:
	return OFFICIAL_NAMES.has(event_type)


## Official presentation name for a domain event type (&"" when unknown).
static func presentation_name(event_type: StringName) -> StringName:
	return OFFICIAL_NAMES.get(event_type, &"")


## Official vocabulary as a sorted list (used by tests and diagnostics).
static func official_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for event_type in OFFICIAL_NAMES:
		names.append(OFFICIAL_NAMES[event_type])
	names.sort_custom(func(a, b): return String(a) < String(b))
	return names


## Deterministic staging pressure from authoritative occupancy counts.
static func pressure_for(occupied_count: int, slot_count: int) -> StringName:
	if slot_count <= 0 or occupied_count >= slot_count:
		return PRESSURE_FULL
	var free_slots := slot_count - occupied_count
	if free_slots == 1:
		return PRESSURE_WARNING
	return PRESSURE_NORMAL


## Translates ONE event into 0..1 entries, each
## `{ "name": StringName, "payload": Dictionary }`, using the official name.
static func translate(event: DomainEvent) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if event == null:
		return entries
	var name: StringName = OFFICIAL_NAMES.get(event.event_type, &"")
	if name == &"":
		return entries
	var payload: Dictionary = Serialization.canonicalize(event.data)
	if event.event_type == DomainEvent.STAGING_CHANGED:
		var occupied := int(payload.get("occupied_count", 0))
		var slot_count := int(payload.get("slot_count", 0))
		payload["pressure"] = String(pressure_for(occupied, slot_count))
	entries.append({"name": name, "payload": payload})
	return entries


## Translates a whole command result in emission order, enriching
## `entity_move_started` with the path of the matching `entity_moved`.
static func translate_result(result: CommandResult) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if result == null:
		return entries

	# Index authoritative paths by entity id (deterministic: first occurrence).
	var paths := {}
	for event in result.events:
		if event.event_type != DomainEvent.ENTITY_MOVED:
			continue
		var entity_id := str(event.data.get("entity_id", ""))
		var path: Variant = event.data.get("path", [])
		if typeof(path) == TYPE_ARRAY and not (path as Array).is_empty():
			paths[entity_id] = path

	for event in result.events:
		for entry in translate(event):
			if event.event_type == DomainEvent.ENTITY_MOVE_STARTED:
				var started_id := str(entry["payload"].get("entity_id", ""))
				if paths.has(started_id):
					entry["payload"]["path"] = paths[started_id]
			entries.append(entry)
	return entries
