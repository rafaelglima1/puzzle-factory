extends RefCounted
## Thin presentation-side event router, aligned with the official M1 contract
## (docs/PRESENTATION_BRIDGE.md, contract version 1).
##
## Boundary rule (blueprint §8.2, ADR-003): presentation must not import
## `game/core/**` or `game/puzzle/**`, so this file never references
## `DomainEvent`. It consumes plain, JSON-safe dictionaries whose `type` and
## payload shapes mirror the official contract, so the AGENT-1 Traffic product
## adapter (`game/integration/traffic/**`) can feed it without a second,
## competing event system.
##
## Unknown event types are ignored safely: the vocabulary is open and additive.

signal event_forwarded(event_type: StringName, payload: Dictionary)

# Official M1 vocabulary (contract version 1).
const ENTITY_PLACED := &"entity_placed"
const ENTITY_MOVE_STARTED := &"entity_move_started"
const ENTITY_MOVED := &"entity_moved"
const ENTITY_BLOCKED := &"entity_blocked"
const COMMAND_REJECTED := &"command_rejected"

const M1_EVENTS: Array[StringName] = [
	ENTITY_PLACED,
	ENTITY_MOVE_STARTED,
	ENTITY_MOVED,
	ENTITY_BLOCKED,
	COMMAND_REJECTED,
]

## Additive event names M2 may publish. Documentation only: NOT authoritative
## and NOT used to gate dispatch. Unknown events must always remain harmless.
const M2_EXPECTED_EVENTS: Array[StringName] = [
	&"entity_arrived",
	&"item_loaded",
	&"match_occurred",
	&"staging_changed",
	&"objective_completed",
	&"game_completed",
	&"game_failed",
]

var forwarded_count := 0
var ignored_count := 0

var _subscribers: Dictionary = {}


func subscribe(event_type: StringName, callback: Callable) -> bool:
	if not callback.is_valid():
		return false
	if not _subscribers.has(event_type):
		_subscribers[event_type] = []
	var callbacks: Array = _subscribers[event_type]
	if callbacks.has(callback):
		return false
	callbacks.append(callback)
	return true


func unsubscribe(event_type: StringName, callback: Callable) -> bool:
	if not _subscribers.has(event_type):
		return false
	var callbacks: Array = _subscribers[event_type]
	var index := callbacks.find(callback)
	if index < 0:
		return false
	callbacks.remove_at(index)
	if callbacks.is_empty():
		_subscribers.erase(event_type)
	return true


func subscriber_count(event_type: StringName = &"") -> int:
	if event_type == &"":
		var total := 0
		for callbacks: Array in _subscribers.values():
			total += callbacks.size()
		return total
	if not _subscribers.has(event_type):
		return 0
	return _subscribers[event_type].size()


## Returns how many subscribers received the event.
func dispatch(event_type: StringName, payload: Dictionary = {}) -> int:
	if not _subscribers.has(event_type):
		ignored_count += 1
		return 0
	var delivered := 0
	var callbacks: Array = _subscribers[event_type]
	for callback: Callable in callbacks:
		if callback.is_valid():
			callback.call(event_type, payload)
			delivered += 1
	forwarded_count += 1
	event_forwarded.emit(event_type, payload)
	return delivered


## Accepts the `DomainEvent.to_dictionary()` shape without importing core:
## `{ "type": String, "sequence": int, "data": Dictionary }`.
func dispatch_domain_event(entry: Dictionary) -> int:
	if typeof(entry) != TYPE_DICTIONARY:
		ignored_count += 1
		return 0
	var event_type := event_type_of(entry)
	if event_type == &"":
		ignored_count += 1
		return 0
	return dispatch(event_type, event_payload_of(entry))


func is_known_m1_event(event_type: StringName) -> bool:
	return M1_EVENTS.has(event_type)


static func is_m1_event(event_type: StringName) -> bool:
	return M1_EVENTS.has(event_type)


static func event_type_of(entry: Dictionary) -> StringName:
	return StringName(str(entry.get("type", "")))


static func event_payload_of(entry: Dictionary) -> Dictionary:
	var payload: Variant = entry.get("data", {})
	if payload is Dictionary:
		return payload
	return {}


static func payload_entity_id(payload: Dictionary) -> StringName:
	return StringName(str(payload.get("entity_id", "")))


static func payload_has_position(payload: Dictionary, key: String) -> bool:
	var value: Variant = payload.get(key, null)
	return value is Dictionary


## Reads `{ "x": int, "y": int }`; returns Vector2i.ZERO when absent.
static func payload_position(payload: Dictionary, key: String) -> Vector2i:
	var value: Variant = payload.get(key, null)
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return Vector2i.ZERO


## Reads `{ "width": int, "height": int }`; returns Vector2i.ONE when absent.
static func payload_footprint(payload: Dictionary) -> Vector2i:
	var value: Variant = payload.get("footprint", null)
	if value is Dictionary:
		return Vector2i(int(value.get("width", 1)), int(value.get("height", 1)))
	return Vector2i.ONE


static func payload_blockers(payload: Dictionary) -> Array:
	var value: Variant = payload.get("blockers", [])
	if value is Array:
		var blockers: Array = []
		for blocker: Variant in value:
			blockers.append(StringName(str(blocker)))
		return blockers
	return []


static func payload_status(payload: Dictionary) -> StringName:
	return StringName(str(payload.get("status", "")))


static func payload_code(payload: Dictionary) -> StringName:
	return StringName(str(payload.get("code", "")))
