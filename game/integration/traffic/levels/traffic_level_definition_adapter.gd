class_name TrafficLevelDefinitionAdapter
extends RefCounted
## PRODUCT INTEGRATION LAYER (Traffic) — OWNER: AGENT-1 (M5 content conversion).
##
## The single translation seam between the generic M5 [LevelDefinition] schema
## (product-free) and the Traffic dictionary that [TrafficGameFactory] consumes.
## Product vocabulary (vehicle/passenger/station/route) is confined here; generic
## gameplay rules stay in the core/puzzle layers and are never duplicated.
##
## Mapping (generic -> Traffic):
##   Entity      -> vehicle   (position -> cell, path_id -> route,
##                             destination_id -> station)
##   Item        -> passenger (destination_id -> station)
##   Queue       -> queue
##   Destination -> station   (accepted_keys -> accepted, queue_id -> queue,
##                             position -> cell)
##   Path        -> route     (paths[id] -> paths[route_id])
##   Objective   -> objective (CLEAR_ALL -> "clear_all")
##
## [method from_traffic_definition] is the inverse, kept for tests and legacy
## migration of the pre-M5 hardcoded catalogue shape.

const DEFAULT_ITEM_TYPE := &"standard"
const DEFAULT_DESTINATION_TYPE := &"default"
const TRAFFIC_CLEAR_ALL := &"clear_all"


## Maps a generic [LevelDefinition] into the TrafficGameFactory dictionary.
static func to_traffic_definition(definition: LevelDefinition) -> Dictionary:
	if definition == null:
		return {}

	var paths: Dictionary = {}
	for path in definition.paths:
		paths[String(path.id)] = _cells_to_dictionaries(path.cells)

	var queues: Dictionary = {}
	for queue in definition.queues:
		queues[String(queue.id)] = _string_names_to_strings(queue.item_ids)

	var stations: Array = []
	for destination in definition.destinations:
		stations.append({
			"id": String(destination.id),
			"accepted": _string_names_to_strings(destination.accepted_keys),
			"capacity": destination.capacity,
			"queue": String(destination.queue_id),
			"cell": _position_to_dictionary(destination.position),
			"footprint": _footprint_to_dictionary(destination.footprint),
		})

	var passengers: Array = []
	for item in definition.items:
		passengers.append({
			"id": String(item.id),
			"type": String(item.item_type) if item.item_type != &"" else String(DEFAULT_ITEM_TYPE),
			"color": String(item.color_key),
			"station": String(item.destination_id),
		})

	var vehicles: Array = []
	for entity in definition.entities:
		vehicles.append({
			"id": String(entity.id),
			"type": String(entity.entity_type),
			"color": String(entity.color_key),
			"capacity": entity.capacity,
			"cell": _position_to_dictionary(entity.position),
			"footprint": _footprint_to_dictionary(entity.footprint),
			"route": String(entity.path_id),
			"station": String(entity.destination_id),
		})

	var objectives: Array = []
	for objective in definition.objectives:
		objectives.append({
			"id": String(objective.id),
			"type": _to_traffic_objective_type(objective.objective_type),
			"mandatory": objective.mandatory,
		})

	return {
		"level_id": String(definition.level_id),
		"seed": definition.seed,
		"width": definition.board_width,
		"height": definition.board_height,
		"staging_slots": definition.staging_slots,
		"paths": paths,
		"stations": stations,
		"queues": queues,
		"passengers": passengers,
		"vehicles": vehicles,
		"objectives": objectives,
	}


## Builds a ready-to-play [Simulation] from a generic definition through the
## Traffic factory (validate + compose). Returns null when the definition cannot
## be built.
static func build_simulation(definition: LevelDefinition) -> Simulation:
	return TrafficGameFactory.build(to_traffic_definition(definition))


## Inverse mapping: Traffic dictionary -> external V1 dictionary -> [LevelDefinition].
## Returns null for a non-dictionary input.
static func from_traffic_definition(traffic_definition: Dictionary) -> LevelDefinition:
	if traffic_definition == null or typeof(traffic_definition) != TYPE_DICTIONARY:
		return null
	return LevelDefinition.from_dictionary(_to_v1_dictionary(traffic_definition))


static func _to_v1_dictionary(traffic_definition: Dictionary) -> Dictionary:
	var paths: Array = []
	var raw_paths: Variant = traffic_definition.get("paths", {})
	if typeof(raw_paths) == TYPE_DICTIONARY:
		for route_id in raw_paths:
			paths.append({"id": String(route_id), "cells": _cells_from_traffic(raw_paths[route_id])})

	var queues: Array = []
	var raw_queues: Variant = traffic_definition.get("queues", {})
	if typeof(raw_queues) == TYPE_DICTIONARY:
		for queue_id in raw_queues:
			queues.append({"id": String(queue_id), "itemIds": _strings_from_traffic(raw_queues[queue_id])})

	var entities: Array = []
	for vehicle in traffic_definition.get("vehicles", []):
		entities.append({
			"id": str(vehicle.get("id", "")),
			"type": str(vehicle.get("type", "")),
			"colorKey": str(vehicle.get("color", "")),
			"capacity": int(vehicle.get("capacity", 0)),
			"position": _position_from_traffic(vehicle.get("cell", null)),
			"footprint": _footprint_from_traffic(vehicle.get("footprint", null)),
			"pathId": str(vehicle.get("route", "")),
			"destinationId": str(vehicle.get("station", "")),
		})

	var items: Array = []
	for passenger in traffic_definition.get("passengers", []):
		items.append({
			"id": str(passenger.get("id", "")),
			"type": str(passenger.get("type", String(DEFAULT_ITEM_TYPE))),
			"colorKey": str(passenger.get("color", "")),
			"destinationId": str(passenger.get("station", "")),
		})

	var destinations: Array = []
	for station in traffic_definition.get("stations", []):
		destinations.append({
			"id": str(station.get("id", "")),
			"type": str(station.get("type", String(DEFAULT_DESTINATION_TYPE))),
			"acceptedKeys": _strings_from_traffic(station.get("accepted", [])),
			"capacity": int(station.get("capacity", 0)),
			"queueId": str(station.get("queue", "")),
			"position": _position_from_traffic(station.get("cell", null)),
			"footprint": _footprint_from_traffic(station.get("footprint", null)),
		})

	var objectives: Array = []
	var raw_objectives: Variant = traffic_definition.get("objectives", [])
	if typeof(raw_objectives) == TYPE_ARRAY and not (raw_objectives as Array).is_empty():
		for objective in raw_objectives:
			objectives.append({
				"id": str(objective.get("id", "")),
				"type": _to_v1_objective_type(str(objective.get("type", ""))),
				"mandatory": bool(objective.get("mandatory", true)),
			})
	else:
		objectives.append({"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true})

	return {
		"schemaVersion": LevelDefinition.SCHEMA_VERSION,
		"levelId": str(traffic_definition.get("level_id", "")),
		"revision": 1,
		"seed": int(traffic_definition.get("seed", 0)),
		"themeId": "traffic",
		"board": {
			"width": int(traffic_definition.get("width", 0)),
			"height": int(traffic_definition.get("height", 0)),
		},
		"paths": paths,
		"entities": entities,
		"items": items,
		"queues": queues,
		"destinations": destinations,
		"staging": {"slots": int(traffic_definition.get("staging_slots", 0))},
		"objectives": objectives,
		"allowedBoosters": [],
		"difficultyTarget": null,
		"tags": [],
	}


static func _to_traffic_objective_type(objective_type: StringName) -> String:
	if objective_type == &"":
		return ""
	return String(objective_type).to_lower()


static func _to_v1_objective_type(objective_type: String) -> String:
	if objective_type.to_lower() == String(TRAFFIC_CLEAR_ALL):
		return "CLEAR_ALL"
	return objective_type.to_upper()


static func _cells_to_dictionaries(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		result.append(cell.to_dictionary())
	return result


static func _cells_from_traffic(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for cell in raw:
		if typeof(cell) == TYPE_DICTIONARY:
			result.append({"x": int(cell.get("x", 0)), "y": int(cell.get("y", 0))})
	return result


static func _string_names_to_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	return result


static func _strings_from_traffic(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for value in raw:
		result.append(str(value))
	return result


static func _position_to_dictionary(position: GridPosition) -> Dictionary:
	if position == null:
		return {}
	return position.to_dictionary()


static func _position_from_traffic(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return GridPosition.from_dictionary(raw).to_dictionary()


static func _footprint_to_dictionary(footprint: Footprint) -> Dictionary:
	if footprint == null:
		return {}
	return footprint.to_dictionary()


static func _footprint_from_traffic(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	return Footprint.from_dictionary(raw).to_dictionary()
