extends RefCounted
## Stable plain-data contract for the M5 Level Lab debug tooling.
##
## This is the presentation-side boundary object. The cross-integration layer
## adapts AGENT-1's LevelDefinition, LevelValidationResult and SolverResult into
## the flat, JSON-safe shapes produced here. Nothing on the simulation side is
## imported: only primitives, dictionaries and arrays cross the boundary.
##
## Every entry point is a static normalizer and is deliberately lenient:
## malformed, partial or missing input must never crash a debug surface. Unknown
## fields fall back to safe defaults (0, empty string, empty arrays) and unknown
## value shapes are ignored rather than trusted.


## Returns the fully-flat, empty normalized preview shape.
static func _empty_preview() -> Dictionary:
	var obstacles: Array[Vector2i] = []
	var result: Dictionary = {
		"level_id": "",
		"schema_version": 0,
		"revision": 0,
		"board_width": 0,
		"board_height": 0,
		"staging_slots": 0,
		"obstacles": obstacles,
		"entities": [],
		"destinations": [],
		"paths": [],
		"items": [],
		"queues": [],
		"objectives": [],
	}
	return result


## Returns the empty normalized validation shape.
static func _empty_validation() -> Dictionary:
	return {"status": "VALID", "errors": []}


## Returns the zeroed normalized solver shape.
static func _empty_solver() -> Dictionary:
	var commands: Array = []
	return {
		"status": "UNKNOWN",
		"solution_commands": commands,
		"solution_depth": 0,
		"visited_states": 0,
		"expanded_states": 0,
		"dead_end_count": 0,
		"branching_factor_avg": 0.0,
		"runtime_ms": 0,
	}


## Normalizes a raw level preview into the flat contract dictionary.
static func normalize_preview(raw: Dictionary) -> Dictionary:
	var result: Dictionary = _empty_preview()
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = raw

	result["level_id"] = _read_string(source, ["level_id", "levelId", "id"], "")
	result["schema_version"] = _read_int(source, ["schema_version", "schemaVersion"], 0)
	result["revision"] = _read_int(source, ["revision", "rev"], 0)
	result["board_width"] = _read_int(source, ["board_width", "boardWidth", "width"], 0)
	result["board_height"] = _read_int(source, ["board_height", "boardHeight", "height"], 0)
	result["staging_slots"] = _read_int(source, ["staging_slots", "stagingSlots"], 0)

	result["obstacles"] = _normalize_obstacles(_read_value(source, ["obstacles", "blocked_cells"]))
	result["entities"] = _normalize_entities(_read_value(source, ["entities", "vehicles"]))
	result["destinations"] = _normalize_destinations(_read_value(source, ["destinations", "stations"]))
	result["paths"] = _normalize_paths(_read_value(source, ["paths", "routes"]))
	result["items"] = _normalize_items(_read_value(source, ["items", "passengers"]))
	result["queues"] = _normalize_queues(_read_value(source, ["queues"]))
	result["objectives"] = _normalize_objectives(_read_value(source, ["objectives", "goals"]))
	return result


## Normalizes validation input: a result dictionary or a bare error list.
static func normalize_validation(raw: Variant) -> Dictionary:
	var status: String = "VALID"
	var errors: Array = []
	var raw_type: int = typeof(raw)
	if raw_type == TYPE_ARRAY:
		errors = _normalize_errors(raw)
		status = "VALID" if errors.is_empty() else "INVALID"
	elif raw_type == TYPE_DICTIONARY:
		var source: Dictionary = raw
		var explicit: String = _read_string(source, ["status"], "")
		var has_valid: bool = source.has("valid")
		var valid: bool = _read_bool(source, ["valid"], true)
		errors = _normalize_errors(_read_value(source, ["errors", "validation_errors"]))
		var upper: String = explicit.to_upper()
		if upper == "INVALID":
			status = "INVALID"
		elif upper == "VALID":
			status = "VALID"
		elif has_valid:
			status = "VALID" if valid else "INVALID"
		else:
			status = "VALID" if errors.is_empty() else "INVALID"
	var result: Dictionary = {"status": status, "errors": errors}
	return result


## Normalizes solver output into the flat metrics contract.
static func normalize_solver(raw: Variant) -> Dictionary:
	var result: Dictionary = _empty_solver()
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var source: Dictionary = raw

	result["status"] = _normalize_solver_status(_read_string(source, ["status", "result", "solver_status"], ""))
	result["solution_commands"] = normalize_commands(
		_read_value(source, ["solution_commands", "solutionCommands", "solution", "commands"])
	)
	result["solution_depth"] = _read_int(
		source, ["solution_depth", "solutionDepth", "depth", "solution_length"], 0
	)
	result["visited_states"] = _read_int(source, ["visited_states", "visitedStates", "visited"], 0)
	result["expanded_states"] = _read_int(source, ["expanded_states", "expandedStates", "expanded"], 0)
	result["dead_end_count"] = _read_int(source, ["dead_end_count", "deadEndCount", "dead_ends"], 0)
	result["branching_factor_avg"] = _read_float(
		source, ["branching_factor_avg", "branchingFactorAvg", "branching_factor", "branching"], 0.0
	)
	result["runtime_ms"] = _read_int(source, ["runtime_ms", "runtimeMs", "runtime"], 0)
	return result


## Normalizes a raw command list into `{ "type": String, "entity_id": StringName }`.
static func normalize_commands(raw: Variant) -> Array:
	var commands: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return commands
	for entry: Variant in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var command_type: String = _read_string(source, ["type", "command_type", "commandType"], "")
		if command_type == "":
			command_type = "dispatch_entity"
		var entity_id: StringName = _read_key(source, ["entityId", "entity_id", "entity"], &"")
		if entity_id == &"":
			continue
		commands.append({"type": command_type, "entity_id": entity_id})
	return commands


## Reads the first present key from `keys` and returns its value, else null.
static func _read_value(source: Dictionary, keys: Array) -> Variant:
	for key: Variant in keys:
		var key_string: String = str(key)
		if source.has(key_string):
			return source[key_string]
	return null


## Coerces a value to int when possible, else returns the supplied default.
static func _read_int(source: Dictionary, keys: Array, default_value: int = 0) -> int:
	for key: Variant in keys:
		var key_string: String = str(key)
		if not source.has(key_string):
			continue
		var value: Variant = source[key_string]
		var value_type: int = typeof(value)
		if value_type == TYPE_INT:
			return int(value)
		if value_type == TYPE_FLOAT:
			return int(value)
		if value_type == TYPE_BOOL:
			return 1 if value else 0
		if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
			var text: String = str(value)
			if text.is_valid_int():
				return text.to_int()
			if text.is_valid_float():
				return int(text.to_float())
	return default_value


## Coerces a value to float when possible, else returns the supplied default.
static func _read_float(source: Dictionary, keys: Array, default_value: float = 0.0) -> float:
	for key: Variant in keys:
		var key_string: String = str(key)
		if not source.has(key_string):
			continue
		var value: Variant = source[key_string]
		var value_type: int = typeof(value)
		if value_type == TYPE_FLOAT:
			return float(value)
		if value_type == TYPE_INT:
			return float(value)
		if value_type == TYPE_BOOL:
			return 1.0 if value else 0.0
		if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
			var text: String = str(value)
			if text.is_valid_float():
				return text.to_float()
	return default_value


## Coerces a value to String when sensible, else returns the supplied default.
static func _read_string(source: Dictionary, keys: Array, default_value: String = "") -> String:
	for key: Variant in keys:
		var key_string: String = str(key)
		if not source.has(key_string):
			continue
		var value: Variant = source[key_string]
		var value_type: int = typeof(value)
		if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
			return str(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT or value_type == TYPE_BOOL:
			return str(value)
		return default_value
	return default_value


## Coerces a value to StringName when sensible, else returns the supplied default.
static func _read_key(source: Dictionary, keys: Array, default_value: StringName = &"") -> StringName:
	return StringName(_read_string(source, keys, str(default_value)))


## Coerces a value to bool when possible, else returns the supplied default.
static func _read_bool(source: Dictionary, keys: Array, default_value: bool = false) -> bool:
	for key: Variant in keys:
		var key_string: String = str(key)
		if not source.has(key_string):
			continue
		var value: Variant = source[key_string]
		var value_type: int = typeof(value)
		if value_type == TYPE_BOOL:
			return bool(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT:
			return int(value) != 0
		if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
			var text: String = str(value).to_lower()
			return text == "true" or text == "1" or text == "yes"
	return default_value


## Reads a cell from a Dictionary `{ "x", "y" }`, Vector2i, or `[x, y]` array.
static func _read_cell(value: Variant) -> Vector2i:
	var value_type: int = typeof(value)
	if value_type == TYPE_VECTOR2I:
		var cell: Vector2i = value
		return cell
	if value_type == TYPE_DICTIONARY:
		var source: Dictionary = value
		return Vector2i(int(source.get("x", 0)), int(source.get("y", 0)))
	if value_type == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO


## Reads a cell field by key, defaulting to Vector2i.ZERO.
static func _read_cell_field(source: Dictionary, keys: Array) -> Vector2i:
	for key: Variant in keys:
		var key_string: String = str(key)
		if source.has(key_string):
			return _read_cell(source[key_string])
	return Vector2i.ZERO


## Reads a footprint from a Dictionary `{ "width", "height" }`, Vector2i or array.
## Components are clamped to at least 1; default is Vector2i(1, 1).
static func _read_footprint(value: Variant) -> Vector2i:
	var value_type: int = typeof(value)
	if value_type == TYPE_VECTOR2I:
		var vector: Vector2i = value
		return Vector2i(maxi(1, vector.x), maxi(1, vector.y))
	if value_type == TYPE_DICTIONARY:
		var source: Dictionary = value
		return Vector2i(maxi(1, int(source.get("width", 1))), maxi(1, int(source.get("height", 1))))
	if value_type == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2i(maxi(1, int(arr[0])), maxi(1, int(arr[1])))
	return Vector2i.ONE


## Reads a footprint field by key, defaulting to Vector2i(1, 1).
static func _read_footprint_field(source: Dictionary, keys: Array) -> Vector2i:
	for key: Variant in keys:
		var key_string: String = str(key)
		if source.has(key_string):
			return _read_footprint(source[key_string])
	return Vector2i.ONE


## Reads a list of cells, skipping malformed entries.
static func _read_cells(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return cells
	for entry: Variant in value:
		var entry_type: int = typeof(entry)
		if entry_type == TYPE_VECTOR2I or entry_type == TYPE_DICTIONARY or entry_type == TYPE_ARRAY:
			cells.append(_read_cell(entry))
	return cells


## Reads a color-key list from a String, StringName, or Array of entries.
static func _read_keys(value: Variant) -> Array[StringName]:
	var keys: Array[StringName] = []
	var value_type: int = typeof(value)
	if value_type == TYPE_STRING or value_type == TYPE_STRING_NAME:
		keys.append(StringName(str(value)))
		return keys
	if value_type != TYPE_ARRAY:
		return keys
	for entry: Variant in value:
		var entry_type: int = typeof(entry)
		if entry_type == TYPE_STRING or entry_type == TYPE_STRING_NAME:
			keys.append(StringName(str(entry)))
		elif entry_type == TYPE_INT:
			keys.append(StringName(str(entry)))
		elif entry_type == TYPE_DICTIONARY:
			var source: Dictionary = entry
			keys.append(_read_key(source, ["id", "color_key", "colorKey", "color"], &""))
	return keys


static func _normalize_obstacles(value: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if typeof(value) != TYPE_ARRAY:
		return cells
	for entry: Variant in value:
		var entry_type: int = typeof(entry)
		if entry_type == TYPE_VECTOR2I or entry_type == TYPE_DICTIONARY or entry_type == TYPE_ARRAY:
			cells.append(_read_cell(entry))
	return cells


static func _normalize_entities(value: Variant) -> Array:
	var entities: Array = []
	if typeof(value) != TYPE_ARRAY:
		return entities
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "entity_id", "entityId"], &""),
			"entity_type": _read_key(source, ["entity_type", "entityType", "type"], &""),
			"color_key": _read_key(source, ["color_key", "colorKey", "color"], &""),
			"cell": _read_cell_field(source, ["cell", "position", "pos"]),
			"footprint": _read_footprint_field(source, ["footprint", "size"]),
			"orientation": _read_float(source, ["orientation", "rotation", "angle"], 0.0),
			"path": _read_cells(_read_value(source, ["path", "route"])),
		}
		entities.append(normalized)
	return entities


static func _normalize_destinations(value: Variant) -> Array:
	var destinations: Array = []
	if typeof(value) != TYPE_ARRAY:
		return destinations
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "destination_id", "destinationId"], &""),
			"cell": _read_cell_field(source, ["cell", "position", "pos"]),
			"footprint": _read_footprint_field(source, ["footprint", "size"]),
			"accepted_color_keys": _read_keys(
				_read_value(source, ["accepted_color_keys", "acceptedColorKeys", "accepted"])
			),
			"capacity": _read_int(source, ["capacity"], 0),
			"occupancy": _read_int(source, ["occupancy", "occupied"], 0),
			"queue_color_keys": _read_keys(
				_read_value(source, ["queue_color_keys", "queueColorKeys", "queue"])
			),
			"state": _read_key(source, ["state", "status"], &""),
		}
		destinations.append(normalized)
	return destinations


static func _normalize_paths(value: Variant) -> Array:
	var paths: Array = []
	if typeof(value) != TYPE_ARRAY:
		return paths
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "path_id", "pathId"], &""),
			"cells": _read_cells(_read_value(source, ["cells", "path", "route"])),
			"entity_id": _read_key(source, ["entity_id", "entityId", "entity"], &""),
		}
		paths.append(normalized)
	return paths


static func _normalize_items(value: Variant) -> Array:
	var items: Array = []
	if typeof(value) != TYPE_ARRAY:
		return items
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "item_id", "itemId"], &""),
			"item_type": _read_key(source, ["item_type", "itemType", "type"], &""),
			"color_key": _read_key(source, ["color_key", "colorKey", "color"], &""),
			"destination_id": _read_key(
				source, ["destination_id", "destinationId", "destination"], &""
			),
		}
		items.append(normalized)
	return items


static func _normalize_queues(value: Variant) -> Array:
	var queues: Array = []
	if typeof(value) != TYPE_ARRAY:
		return queues
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "queue_id", "queueId"], &""),
			"items": _read_keys(_read_value(source, ["items", "item_ids", "queue"])),
		}
		queues.append(normalized)
	return queues


static func _normalize_objectives(value: Variant) -> Array:
	var objectives: Array = []
	if typeof(value) != TYPE_ARRAY:
		return objectives
	for entry: Variant in value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var source: Dictionary = entry
		var normalized: Dictionary = {
			"id": _read_key(source, ["id", "objective_id", "objectiveId"], &""),
			"objective_type": _read_key(source, ["objective_type", "objectiveType", "type"], &""),
			"mandatory": _read_bool(source, ["mandatory", "required"], false),
		}
		objectives.append(normalized)
	return objectives


static func _normalize_errors(value: Variant) -> Array:
	var errors: Array = []
	if typeof(value) != TYPE_ARRAY:
		return errors
	for entry: Variant in value:
		var entry_type: int = typeof(entry)
		if entry_type == TYPE_DICTIONARY:
			var source: Dictionary = entry
			errors.append({
				"code": _read_string(source, ["code", "error_code", "errorCode"], ""),
				"path": _read_string(source, ["path", "field", "location"], ""),
				"message": _read_string(source, ["message", "msg", "description"], ""),
			})
		elif entry_type == TYPE_STRING or entry_type == TYPE_STRING_NAME:
			errors.append({"code": str(entry), "path": "", "message": str(entry)})
	return errors


static func _normalize_solver_status(value: String) -> String:
	var upper: String = value.to_upper()
	if upper == "SOLVABLE" or upper == "SOLVED" or upper == "SUCCESS":
		return "SOLVABLE"
	if upper == "UNSOLVABLE" or upper == "UNSOLVED" or upper == "FAILED" or upper == "FAILURE":
		return "UNSOLVABLE"
	return "UNKNOWN"
