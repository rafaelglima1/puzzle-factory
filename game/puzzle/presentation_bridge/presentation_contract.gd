class_name PresentationContract
extends RefCounted
## Stable presentation/event contract for milestone M1.
##
## Machine-readable companion of docs/PRESENTATION_BRIDGE.md. AGENT-2 (game /
## presentation) consumes the domain event stream through this contract and
## through [SimulationEventQueue].
##
## Rules this contract encodes:
## - Only the simulation decides puzzle correctness; presentation reacts.
## - Event payloads are JSON-safe primitives (never engine objects or paths).
## - Payload shapes are fixed per event type; new fields/types are added
##   additively in later milestones (consumers must ignore unknown keys).
## - Emission order inside a [CommandResult] is deterministic and meaningful.
##
## Version history (additive changes keep the version; see docs/PRESENTATION_BRIDGE.md §7):
## - 1 (M1): entity_placed, entity_move_started, entity_moved, entity_blocked,
##   command_rejected.
## - 1 + M2 (no breaking change): entity_completed, item_loaded,
##   match_occurred, staging_changed, objective_completed, game_completed,
##   game_failed; entity_moved gained an additive `path` field.

const CONTRACT_VERSION := 1

const SHAPE_STRING := "string"
const SHAPE_INT := "int"
const SHAPE_POSITION := "position"
const SHAPE_POSITION_ARRAY := "position_array"
const SHAPE_SIZE := "size"
const SHAPE_STRING_ARRAY := "string_array"

const EVENTS := {
	DomainEvent.ENTITY_PLACED: {
		"entity_id": SHAPE_STRING,
		"position": SHAPE_POSITION,
		"footprint": SHAPE_SIZE,
	},
	DomainEvent.ENTITY_MOVE_STARTED: {
		"entity_id": SHAPE_STRING,
		"from": SHAPE_POSITION,
		"to": SHAPE_POSITION,
	},
	DomainEvent.ENTITY_MOVED: {
		"entity_id": SHAPE_STRING,
		"from": SHAPE_POSITION,
		"to": SHAPE_POSITION,
		"path": SHAPE_POSITION_ARRAY,
	},
	DomainEvent.ENTITY_BLOCKED: {
		"entity_id": SHAPE_STRING,
		"target": SHAPE_POSITION,
		"blockers": SHAPE_STRING_ARRAY,
	},
	DomainEvent.COMMAND_REJECTED: {
		"status": SHAPE_STRING,
		"code": SHAPE_STRING,
		"entity_id": SHAPE_STRING,
	},
	DomainEvent.ENTITY_COMPLETED: {
		"entity_id": SHAPE_STRING,
		"destination_id": SHAPE_STRING,
	},
	DomainEvent.ITEM_LOADED: {
		"entity_id": SHAPE_STRING,
		"item_id": SHAPE_STRING,
		"color_key": SHAPE_STRING,
		"destination_id": SHAPE_STRING,
		"loaded_count": SHAPE_INT,
	},
	DomainEvent.MATCH_OCCURRED: {
		"entity_id": SHAPE_STRING,
		"color_key": SHAPE_STRING,
		"loaded_count": SHAPE_INT,
	},
	DomainEvent.STAGING_CHANGED: {
		"action": SHAPE_STRING,
		"entity_id": SHAPE_STRING,
		"slot_index": SHAPE_INT,
		"slot_count": SHAPE_INT,
		"occupied_count": SHAPE_INT,
		"available_slots": SHAPE_INT,
	},
	DomainEvent.OBJECTIVE_COMPLETED: {
		"objective_id": SHAPE_STRING,
		"objective_type": SHAPE_STRING,
	},
	DomainEvent.GAME_COMPLETED: {
		"level_id": SHAPE_STRING,
		"move_count": SHAPE_INT,
	},
	DomainEvent.GAME_FAILED: {
		"fail_reason": SHAPE_STRING,
		"move_count": SHAPE_INT,
	},
}


static func known_event_types() -> Array[StringName]:
	var types: Array[StringName] = []
	for event_type in EVENTS.keys():
		types.append(event_type)
	types.sort_custom(func(a, b): return String(a) < String(b))
	return types


static func is_known_event(event_type: StringName) -> bool:
	return EVENTS.has(event_type)


static func payload_schema(event_type: StringName) -> Dictionary:
	return EVENTS.get(event_type, {})


## Validates one event against the contract; empty result means valid.
static func validate_event(event: DomainEvent) -> PackedStringArray:
	var errors := PackedStringArray()
	if event == null:
		errors.append("null_event")
		return errors
	if not is_known_event(event.event_type):
		errors.append("unknown_event_type:%s" % event.event_type)
		return errors
	if not Serialization.is_primitive_tree(event.data):
		errors.append("payload_not_primitive:%s" % event.event_type)
	for key in payload_schema(event.event_type).keys():
		if not event.data.has(key):
			errors.append("missing_payload_key:%s:%s" % [event.event_type, key])
		elif not _matches_shape(payload_schema(event.event_type)[key], event.data[key]):
			errors.append("payload_shape_mismatch:%s:%s" % [event.event_type, key])
	return errors


static func _matches_shape(shape: String, value: Variant) -> bool:
	match shape:
		SHAPE_STRING:
			return typeof(value) == TYPE_STRING
		SHAPE_INT:
			return typeof(value) == TYPE_INT
		SHAPE_STRING_ARRAY:
			if typeof(value) != TYPE_ARRAY:
				return false
			for item in value:
				if typeof(item) != TYPE_STRING:
					return false
			return true
		SHAPE_POSITION_ARRAY:
			if typeof(value) != TYPE_ARRAY:
				return false
			for item in value:
				if not _is_position(item):
					return false
			return true
		SHAPE_POSITION:
			return _is_position(value)
		SHAPE_SIZE:
			return typeof(value) == TYPE_DICTIONARY and typeof(value.get("width")) == TYPE_INT and typeof(value.get("height")) == TYPE_INT
	return false


static func _is_position(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY and typeof(value.get("x")) == TYPE_INT and typeof(value.get("y")) == TYPE_INT
