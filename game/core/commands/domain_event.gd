class_name DomainEvent
extends RefCounted
## Immutable logical fact emitted by the simulation (blueprint §8.2, §12).
##
## Contract (see docs/PRESENTATION_BRIDGE.md):
## - Events describe what already happened. They never request decisions.
## - [member data] contains JSON-safe primitives only ([Serialization]).
## - [member sequence] is the 0-based emission order inside one
##   [CommandResult]; ordering is deterministic and part of the contract.
## - Events are produced synchronously with the command result; presentation
##   may consume them asynchronously and independently of simulation speed.
##
## M1 vocabulary is intentionally small. Later milestones extend it
## additively; existing event types and payload fields are never repurposed.

const ENTITY_PLACED := &"entity_placed"
const ENTITY_MOVE_STARTED := &"entity_move_started"
const ENTITY_MOVED := &"entity_moved"
const ENTITY_BLOCKED := &"entity_blocked"
const COMMAND_REJECTED := &"command_rejected"

var event_type: StringName = &""
var sequence: int = 0
var data: Dictionary = {}


func _init(p_event_type: StringName = &"", p_data: Variant = null) -> void:
	event_type = p_event_type
	data = Serialization.canonicalize(p_data) if p_data != null else {}


func get_payload(key: String, default_value: Variant = null) -> Variant:
	return data.get(key, default_value)


func logical_equals(other: DomainEvent) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"type": String(event_type),
		"sequence": sequence,
		"data": Serialization.canonicalize(data),
	}


static func from_dictionary(entry: Dictionary) -> DomainEvent:
	var event := DomainEvent.new(
		StringName(str(entry.get("type", ""))),
		entry.get("data", {})
	)
	event.sequence = int(entry.get("sequence", 0))
	return event


static func entity_placed(entity_id: StringName, position: GridPosition, footprint: Footprint) -> DomainEvent:
	return DomainEvent.new(ENTITY_PLACED, {
		"entity_id": String(entity_id),
		"position": position.to_dictionary(),
		"footprint": footprint.to_dictionary(),
	})


static func entity_move_started(entity_id: StringName, from_position: GridPosition, to_position: GridPosition) -> DomainEvent:
	return DomainEvent.new(ENTITY_MOVE_STARTED, {
		"entity_id": String(entity_id),
		"from": from_position.to_dictionary(),
		"to": to_position.to_dictionary(),
	})


static func entity_moved(entity_id: StringName, from_position: GridPosition, to_position: GridPosition) -> DomainEvent:
	return DomainEvent.new(ENTITY_MOVED, {
		"entity_id": String(entity_id),
		"from": from_position.to_dictionary(),
		"to": to_position.to_dictionary(),
	})


static func entity_blocked(entity_id: StringName, target: GridPosition, blockers: Array[StringName]) -> DomainEvent:
	var blocker_names: Array = []
	for blocker in blockers:
		blocker_names.append(String(blocker))
	return DomainEvent.new(ENTITY_BLOCKED, {
		"entity_id": String(entity_id),
		"target": target.to_dictionary(),
		"blockers": blocker_names,
	})


static func command_rejected(status: int, code: StringName, entity_id: StringName = &"") -> DomainEvent:
	return DomainEvent.new(COMMAND_REJECTED, {
		"status": String(CommandResult.status_to_string_name(status)),
		"code": String(code),
		"entity_id": String(entity_id),
	})
