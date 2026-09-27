class_name TrafficLevelLabAdapter
extends RefCounted
## M5 CROSS-INTEGRATION adapter — OWNER: M5-INTEGRATOR.
##
## Translates REAL AGENT-1 content-engine objects into the plain DTO contract
## that AGENT-2's Level Lab consumes (`game/themes/traffic/dev/m5/level_lab_contract.gd`).
##
## This is the ONLY place that knows both sides. The Level Lab never imports
## `LevelDefinition`, `LevelValidator`, `SolverResult`, `SolverDomain`,
## `Simulation` or any core/puzzle/solver/levels module; it only receives the
## flat dictionaries produced here (see `traffic_level_lab_controller.gd` for the
## wiring).
##
## Mappings:
##   LevelDefinition          -> flat preview dictionary (contract keys)
##   PackedStringArray errors -> { status, errors:[{code,path,message}] }
##   SolverResult             -> flat solver dictionary (real values preserved)
##   command descriptors      -> the Level Lab's normalized { type, entity_id }

const ValidationStatusCode := "VALIDATION"


# --- preview ------------------------------------------------------------------

## Maps a real [LevelDefinition] to the Level Lab flat preview contract.
## Preserves ids, positions, footprints, color keys, capacities, path/queue
## ordering and destination relationships exactly; it never renames ids and
## never reconstructs gameplay semantics.
static func definition_to_preview(definition: LevelDefinition) -> Dictionary:
	if definition == null:
		return {}
	return {
		"level_id": String(definition.level_id),
		"schema_version": definition.schema_version,
		"revision": definition.revision,
		"board_width": definition.board_width,
		"board_height": definition.board_height,
		"staging_slots": definition.staging_slots,
		"obstacles": [],
		"entities": _entities(definition),
		"items": _items(definition),
		"queues": _queues(definition),
		"destinations": _destinations(definition),
		"paths": _paths(definition),
		"objectives": _objectives(definition),
	}


static func _entities(definition: LevelDefinition) -> Array:
	var result: Array = []
	for entity in definition.entities:
		result.append({
			"id": String(entity.id),
			"type": String(entity.entity_type),
			"colorKey": String(entity.color_key),
			"capacity": entity.capacity,
			"cell": _cell(entity.position),
			"footprint": _footprint(entity.footprint),
			"pathId": String(entity.path_id),
			"destinationId": String(entity.destination_id),
		})
	return result


static func _items(definition: LevelDefinition) -> Array:
	var result: Array = []
	for item in definition.items:
		result.append({
			"id": String(item.id),
			"type": String(item.item_type),
			"colorKey": String(item.color_key),
			"destinationId": String(item.destination_id),
		})
	return result


static func _queues(definition: LevelDefinition) -> Array:
	var result: Array = []
	for queue in definition.queues:
		var item_ids: Array = []
		for item_id in queue.item_ids:
			item_ids.append(String(item_id))
		result.append({"id": String(queue.id), "itemIds": item_ids})
	return result


static func _destinations(definition: LevelDefinition) -> Array:
	var result: Array = []
	for destination in definition.destinations:
		var accepted: Array = []
		for key in destination.accepted_keys:
			accepted.append(String(key))
		result.append({
			"id": String(destination.id),
			"type": String(destination.destination_type),
			"acceptedKeys": accepted,
			"capacity": destination.capacity,
			"queueId": String(destination.queue_id),
			"cell": _cell(destination.position),
			"footprint": _footprint(destination.footprint),
		})
	return result


static func _paths(definition: LevelDefinition) -> Array:
	var result: Array = []
	for path in definition.paths:
		var cells: Array = []
		for cell in path.cells:
			cells.append(_cell(cell))
		# The Level Lab path overlay colors by entity, so carry the owning
		# entity id (looked up from the entity that references this path).
		result.append({"id": String(path.id), "cells": cells, "entityId": _entity_for_path(definition, path.id)})
	return result


static func _objectives(definition: LevelDefinition) -> Array:
	var result: Array = []
	for objective in definition.objectives:
		result.append({
			"id": String(objective.id),
			"type": String(objective.objective_type),
			"mandatory": objective.mandatory,
		})
	return result


static func _entity_for_path(definition: LevelDefinition, path_id: StringName) -> String:
	for entity in definition.entities:
		if entity.path_id == path_id:
			return String(entity.id)
	return ""


static func _cell(value: Variant) -> Dictionary:
	if value == null:
		return {"x": 0, "y": 0}
	return value.to_dictionary()


static func _footprint(value: Variant) -> Dictionary:
	if value == null:
		return {"width": 1, "height": 1}
	return value.to_dictionary()


# --- validation ---------------------------------------------------------------

## Maps the real `PackedStringArray` returned by [LevelValidator] to the Level
## Lab validation contract. The machine-readable code is preserved verbatim; a
## concise developer-facing message and an optional `path` are derived from it
## (code format is `CODE` or `CODE:context...`).
static func validation_to_contract(errors: PackedStringArray) -> Dictionary:
	var entries: Array = []
	for raw in errors:
		entries.append(_validation_entry(String(raw)))
	return {
		"status": "VALID" if entries.is_empty() else "INVALID",
		"errors": entries,
	}


static func _validation_entry(code_text: String) -> Dictionary:
	var parts := code_text.split(":", true, 1)
	var code := parts[0] if parts.size() > 0 else code_text
	var context := parts[1] if parts.size() > 1 else ""
	return {
		"code": code,
		"path": context,
		"message": code_text,
	}


# --- solver -------------------------------------------------------------------

## Maps a real [SolverResult] to the Level Lab flat solver contract. Real values
## (status, depth, metrics, runtime) are preserved exactly and the command order
## is unchanged; commands are normalized to `{ type, entity_id }`.
static func solver_to_contract(result: SolverResult) -> Dictionary:
	if result == null:
		return {}
	var commands: Array = []
	for descriptor in result.solution_commands:
		commands.append(normalize_command(descriptor))
	return {
		"status": result.status_name(),
		"solution_commands": commands,
		"solution_depth": result.solution_depth,
		"visited_states": result.visited_states,
		"expanded_states": result.expanded_states,
		"dead_end_count": result.dead_end_count,
		"branching_factor_avg": result.branching_factor_avg,
		"runtime_ms": result.runtime_ms,
	}


## Normalizes a command descriptor from either spelling (AGENT-1 `entityId` or
## AGENT-2 `entity_id`) to the Level Lab form `{ "type", "entity_id" }`.
static func normalize_command(descriptor: Dictionary) -> Dictionary:
	var entity_id := ""
	if descriptor.has("entityId"):
		entity_id = str(descriptor["entityId"])
	elif descriptor.has("entity_id"):
		entity_id = str(descriptor["entity_id"])
	elif descriptor.has("entity"):
		entity_id = str(descriptor["entity"])
	var command_type := "dispatch_entity"
	if descriptor.has("type") and descriptor["type"] != null:
		command_type = str(descriptor["type"])
	return {"type": command_type, "entity_id": entity_id}


## Convenience: build the complete Level Lab preview entry (preview + the
## `validation` and `solver` sub-dictionaries the lab reads on `show_levels`).
static func build_lab_entry(preview: Dictionary, validation: Dictionary, solver: Dictionary) -> Dictionary:
	var entry := preview.duplicate(true)
	entry["validation"] = validation
	entry["solver"] = solver
	return entry
