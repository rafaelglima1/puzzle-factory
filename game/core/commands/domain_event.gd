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

## M2 additions (additive: existing names/payloads keep their M1 meaning).
const ENTITY_COMPLETED := &"entity_completed"
const ITEM_LOADED := &"item_loaded"
const MATCH_OCCURRED := &"match_occurred"
const STAGING_CHANGED := &"staging_changed"
const OBJECTIVE_COMPLETED := &"objective_completed"
const GAME_COMPLETED := &"game_completed"
const GAME_FAILED := &"game_failed"

## Staging change actions.
const STAGING_ADDED := "added"
const STAGING_REMOVED := "removed"

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


static func entity_moved(entity_id: StringName, from_position: GridPosition, to_position: GridPosition, path: Array[GridPosition] = []) -> DomainEvent:
	var path_cells: Array = []
	for cell in path:
		path_cells.append(cell.to_dictionary())
	return DomainEvent.new(ENTITY_MOVED, {
		"entity_id": String(entity_id),
		"from": from_position.to_dictionary(),
		"to": to_position.to_dictionary(),
		"path": path_cells,
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


static func entity_completed(entity_id: StringName, destination_id: StringName) -> DomainEvent:
	return DomainEvent.new(ENTITY_COMPLETED, {
		"entity_id": String(entity_id),
		"destination_id": String(destination_id),
	})


static func item_loaded(entity_id: StringName, item_id: StringName, color_key: StringName, destination_id: StringName, loaded_count: int) -> DomainEvent:
	return DomainEvent.new(ITEM_LOADED, {
		"entity_id": String(entity_id),
		"item_id": String(item_id),
		"color_key": String(color_key),
		"destination_id": String(destination_id),
		"loaded_count": loaded_count,
	})


static func match_occurred(entity_id: StringName, color_key: StringName, loaded_count: int) -> DomainEvent:
	return DomainEvent.new(MATCH_OCCURRED, {
		"entity_id": String(entity_id),
		"color_key": String(color_key),
		"loaded_count": loaded_count,
	})


static func staging_changed(action: String, entity_id: StringName, slot_index: int, staging: StagingArea) -> DomainEvent:
	return DomainEvent.new(STAGING_CHANGED, {
		"action": action,
		"entity_id": String(entity_id),
		"slot_index": slot_index,
		"slot_count": staging.slot_count,
		"occupied_count": staging.occupied_count(),
		"available_slots": staging.available_slots(),
	})


static func objective_completed(objective_id: StringName, objective_type: StringName) -> DomainEvent:
	return DomainEvent.new(OBJECTIVE_COMPLETED, {
		"objective_id": String(objective_id),
		"objective_type": String(objective_type),
	})


static func game_completed(level_id: StringName, move_count: int) -> DomainEvent:
	return DomainEvent.new(GAME_COMPLETED, {
		"level_id": String(level_id),
		"move_count": move_count,
	})


static func game_failed(fail_reason: StringName, move_count: int) -> DomainEvent:
	return DomainEvent.new(GAME_FAILED, {
		"fail_reason": String(fail_reason),
		"move_count": move_count,
	})
