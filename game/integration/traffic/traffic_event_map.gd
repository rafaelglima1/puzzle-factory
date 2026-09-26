class_name TrafficEventMap
extends RefCounted
## Maps generic domain events to the Traffic presentation vocabulary.
##
## PRODUCT INTEGRATION LAYER (Traffic) — OWNER: AGENT-1.
##
## Presentation names prefer the provisional names published by AGENT-2 in
## `game/themes/traffic/bridge/presentation_event_router.gd`
## (`PROVISIONAL_EVENTS`, from docs/UX_IMPLEMENTATION_PLAN.md §2.2). Where no
## provisional name exists, an adapter-side name is used (documented below).
## The router treats names as data and ignores unknown ones safely, so this
## table can evolve without breaking presentation.
##
## Mapping (generic -> presentation):
##   entity_placed       -> EntityPlaced        (adapter-side; no proposal)
##   entity_move_started -> EntityMoveStarted   (proposal)
##   entity_moved        -> EntityArrived       (proposal; payload adds `path`)
##   entity_blocked      -> EntityBlocked       (proposal)
##   command_rejected    -> CommandRejected     (adapter-side; proposal maps statuses)
##   entity_completed    -> EntityExited        (proposal; entity left the board)
##   item_loaded         -> ItemLoaded          (proposal)
##   match_occurred      -> MatchOccurred       (proposal)
##   staging_changed     -> StagingReceived / StagingChanged + StagingPressureChanged
##   objective_completed -> ObjectiveCompleted  (proposal)
##   game_completed      -> LevelCompleted      (proposal)
##   game_failed         -> LevelFailed         (proposal; payload carries fail_reason)
##
## The translation is pure (no state access, no decisions) and preserves the
## generic payload verbatim, adding only derived presentation values such as
## staging pressure. Unknown event types translate to nothing.

const NAMES := {
	DomainEvent.ENTITY_PLACED: &"EntityPlaced",
	DomainEvent.ENTITY_MOVE_STARTED: &"EntityMoveStarted",
	DomainEvent.ENTITY_MOVED: &"EntityArrived",
	DomainEvent.ENTITY_BLOCKED: &"EntityBlocked",
	DomainEvent.COMMAND_REJECTED: &"CommandRejected",
	DomainEvent.ENTITY_COMPLETED: &"EntityExited",
	DomainEvent.ITEM_LOADED: &"ItemLoaded",
	DomainEvent.MATCH_OCCURRED: &"MatchOccurred",
	DomainEvent.OBJECTIVE_COMPLETED: &"ObjectiveCompleted",
	DomainEvent.GAME_COMPLETED: &"LevelCompleted",
	DomainEvent.GAME_FAILED: &"LevelFailed",
}

const NAME_STAGING_RECEIVED := &"StagingReceived"
const NAME_STAGING_CHANGED := &"StagingChanged"
const NAME_STAGING_PRESSURE := &"StagingPressureChanged"

## Pressure labels match the AGENT-2 staging view-data constants.
const PRESSURE_NORMAL := &"normal"
const PRESSURE_WARNING := &"warning"
const PRESSURE_FULL := &"full"


static func is_mapped(event_type: StringName) -> bool:
	return event_type == DomainEvent.STAGING_CHANGED or NAMES.has(event_type)


## Returns the presentation name for a generic event type (&"" when unmapped).
static func presentation_name(event_type: StringName) -> StringName:
	if event_type == DomainEvent.STAGING_CHANGED:
		return NAME_STAGING_CHANGED
	return NAMES.get(event_type, &"")


## Deterministic staging pressure from occupancy.
static func pressure_for(occupied_count: int, slot_count: int) -> StringName:
	if slot_count <= 0 or occupied_count >= slot_count:
		return PRESSURE_FULL
	var free_slots := slot_count - occupied_count
	if free_slots == 1:
		return PRESSURE_WARNING
	return PRESSURE_NORMAL


## Translates one event into 0..2 presentation entries, each
## { "name": StringName, "payload": Dictionary }.
static func translate(event: DomainEvent) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if event == null:
		return entries
	var payload: Dictionary = Serialization.canonicalize(event.data)

	match event.event_type:
		DomainEvent.STAGING_CHANGED:
			var action := str(payload.get("action", ""))
			var staging_payload := payload.duplicate(true)
			var name: StringName = NAME_STAGING_RECEIVED if action == DomainEvent.STAGING_ADDED else NAME_STAGING_CHANGED
			entries.append({"name": name, "payload": staging_payload})
			var occupied := int(payload.get("occupied_count", 0))
			var slot_count := int(payload.get("slot_count", 0))
			entries.append({
				"name": NAME_STAGING_PRESSURE,
				"payload": {
					"occupied_count": occupied,
					"slot_count": slot_count,
					"available_slots": int(payload.get("available_slots", 0)),
					"pressure": String(pressure_for(occupied, slot_count)),
				},
			})
		_:
			var name: StringName = NAMES.get(event.event_type, &"")
			if name == &"":
				return entries
			entries.append({"name": name, "payload": payload})
	return entries


## Translates every event of a command result, in emission order.
static func translate_result(result: CommandResult) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if result == null:
		return entries
	for event in result.events:
		entries.append_array(translate(event))
	return entries
