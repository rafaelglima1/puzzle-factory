class_name LevelValidator
extends RefCounted
## Static structural validator for [LevelDefinition] (M5 schema v1).
##
## Validation returns machine-readable codes instead of booleans so callers can
## surface diagnostics. It is static only: it never solves the puzzle, so a
## structurally valid but unsolvable level still passes.

const KNOWN_BOOSTERS: Array[StringName] = [&"UNDO", &"EXTRA_SLOT", &"SHUFFLE"]
const CANONICAL_CLEAR_ALL := &"CLEAR_ALL"


static func validate(definition: LevelDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("MISSING_DEFINITION")
		return errors
	if definition.schema_version != LevelDefinition.SCHEMA_VERSION:
		errors.append("UNSUPPORTED_SCHEMA_VERSION")
	if definition.level_id == &"":
		errors.append("INVALID_LEVEL_ID")
	if definition.revision < 1:
		errors.append("INVALID_REVISION")
	if definition.theme_id == &"":
		errors.append("INVALID_THEME_ID")
	if definition.board_width < 1 or definition.board_height < 1:
		errors.append("INVALID_BOARD")
	if definition.staging_slots < 0:
		errors.append("INVALID_STAGING_SLOTS")

	var board := BoardDimensions.new(definition.board_width, definition.board_height)
	var path_ids := _id_set(definition.paths)
	var destination_ids := _id_set(definition.destinations)
	var queue_ids := _id_set(definition.queues)
	var item_ids := _id_set(definition.items)

	_check_duplicate_ids(definition, errors)
	_check_paths(definition, board, errors)
	_check_entities(definition, board, path_ids, destination_ids, errors)
	_check_items(definition, destination_ids, errors)
	_check_queues(definition, item_ids, errors)
	_check_destinations(definition, board, queue_ids, errors)
	_check_objectives(definition, errors)
	_check_boosters(definition, errors)
	return errors


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	return validate(LevelDefinition.from_dictionary(data))


static func _id_set(collection: Array) -> Dictionary:
	var ids := {}
	for entry in collection:
		var entry_id: StringName = entry.id
		if entry_id != &"":
			ids[entry_id] = true
	return ids


static func _paths_by_id(collection: Array) -> Dictionary:
	var result := {}
	for path in collection:
		result[path.id] = path
	return result


static func _check_duplicate_ids(definition: LevelDefinition, errors: PackedStringArray) -> void:
	var seen := {}
	var namespaces: Array = [
		definition.paths,
		definition.entities,
		definition.items,
		definition.queues,
		definition.destinations,
		definition.objectives,
	]
	for collection in namespaces:
		for entry in collection:
			var entry_id: StringName = entry.id
			if entry_id == &"":
				continue
			if seen.has(entry_id):
				errors.append("DUPLICATE_ID:%s" % String(entry_id))
			else:
				seen[entry_id] = true


static func _check_paths(definition: LevelDefinition, board: BoardDimensions, errors: PackedStringArray) -> void:
	for path in definition.paths:
		var path_id: StringName = path.id
		var cells: Array = path.cells
		if cells.size() < 2:
			errors.append("INVALID_PATH:%s:too_short" % String(path_id))
		var seen := {}
		for index in cells.size():
			var cell: Variant = cells[index]
			if cell == null or not board.contains(cell):
				errors.append("OUT_OF_BOUNDS:path:%s:%d" % [String(path_id), index])
				continue
			var cell_key := board.index_of(cell)
			if seen.has(cell_key):
				errors.append("INVALID_PATH:%s:duplicate_cell:%d" % [String(path_id), index])
			seen[cell_key] = true
			if index == 0:
				continue
			var previous: Variant = cells[index - 1]
			if previous == null or not board.contains(previous):
				continue
			var distance := absi(cell.x - previous.x) + absi(cell.y - previous.y)
			if distance != 1:
				errors.append("INVALID_PATH:%s:non_contiguous:%d" % [String(path_id), index])


static func _check_entities(
	definition: LevelDefinition,
	board: BoardDimensions,
	path_ids: Dictionary,
	destination_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var paths_by_id := _paths_by_id(definition.paths)
	var occupants := {}
	for entity in definition.entities:
		var entity_id: StringName = entity.id
		var position: Variant = entity.position
		var footprint: Variant = entity.footprint
		var valid_position := false
		if position == null:
			errors.append("INVALID_POSITION:%s" % String(entity_id))
		elif not board.contains(position):
			errors.append("OUT_OF_BOUNDS:entity:%s" % String(entity_id))
		else:
			valid_position = true
		if footprint == null or not footprint.is_valid():
			errors.append("INVALID_FOOTPRINT:%s" % String(entity_id))
		elif valid_position and not board.contains_footprint(footprint, position):
			errors.append("OUT_OF_BOUNDS:entity:%s" % String(entity_id))
		if entity.capacity < 1:
			errors.append("INVALID_CAPACITY:%s" % String(entity_id))
		var path_id: StringName = entity.path_id
		if not path_ids.has(path_id):
			errors.append("UNKNOWN_PATH:%s" % String(path_id))
		var destination_id: StringName = entity.destination_id
		if not destination_ids.has(destination_id):
			errors.append("UNKNOWN_DESTINATION:%s" % String(destination_id))
		if paths_by_id.has(path_id) and valid_position:
			var path: Variant = paths_by_id[path_id]
			var origin: GridPosition = path.origin()
			if origin != null and not origin.equals(position):
				errors.append("ROUTE_START_MISMATCH:%s" % String(entity_id))
		if valid_position and footprint != null and footprint.is_valid():
			for cell in footprint.cell_positions(position):
				if not board.contains(cell):
					continue
				var cell_key := board.index_of(cell)
				if occupants.has(cell_key):
					errors.append("ENTITY_OVERLAP:%s:%s" % [String(occupants[cell_key]), String(entity_id)])
				else:
					occupants[cell_key] = entity_id


static func _check_items(definition: LevelDefinition, destination_ids: Dictionary, errors: PackedStringArray) -> void:
	for item in definition.items:
		var item_id: StringName = item.id
		if item.color_key == &"":
			errors.append("MISSING_COLOR_KEY:%s" % String(item_id))
		var destination_id: StringName = item.destination_id
		if not destination_ids.has(destination_id):
			errors.append("UNKNOWN_DESTINATION:%s" % String(destination_id))


static func _check_queues(definition: LevelDefinition, item_ids: Dictionary, errors: PackedStringArray) -> void:
	var ownership := {}
	for queue in definition.queues:
		for item_id in queue.item_ids:
			if not item_ids.has(item_id):
				errors.append("UNKNOWN_ITEM:%s" % String(item_id))
			var count: int = int(ownership.get(item_id, 0)) + 1
			ownership[item_id] = count
			if count == 2:
				errors.append("DUPLICATE_ITEM_OWNERSHIP:%s" % String(item_id))
	for item in definition.items:
		var item_id: StringName = item.id
		if item_id != &"" and not ownership.has(item_id):
			errors.append("UNREFERENCED_ITEM:%s" % String(item_id))


static func _check_destinations(
	definition: LevelDefinition,
	board: BoardDimensions,
	queue_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	for destination in definition.destinations:
		var destination_id: StringName = destination.id
		if not queue_ids.has(destination.queue_id):
			errors.append("UNKNOWN_QUEUE:%s" % String(destination.queue_id))
		if destination.capacity < 0:
			errors.append("INVALID_CAPACITY:%s" % String(destination_id))
		if destination.accepted_keys.is_empty():
			errors.append("INVALID_ACCEPTED_KEYS:%s" % String(destination_id))
		var position: Variant = destination.position
		var footprint: Variant = destination.footprint
		var valid_position := false
		if position == null:
			errors.append("INVALID_POSITION:%s" % String(destination_id))
		elif not board.contains(position):
			errors.append("OUT_OF_BOUNDS:destination:%s" % String(destination_id))
		else:
			valid_position = true
		if footprint == null or not footprint.is_valid():
			errors.append("INVALID_FOOTPRINT:%s" % String(destination_id))
		elif valid_position and not board.contains_footprint(footprint, position):
			errors.append("OUT_OF_BOUNDS:destination:%s" % String(destination_id))


static func _check_objectives(definition: LevelDefinition, errors: PackedStringArray) -> void:
	var seen := {}
	for objective in definition.objectives:
		var objective_id: StringName = objective.id
		if objective_id == &"":
			errors.append("INVALID_OBJECTIVE:empty_id")
		elif seen.has(objective_id):
			errors.append("INVALID_OBJECTIVE:%s:duplicate" % String(objective_id))
		else:
			seen[objective_id] = true
		var objective_type: StringName = objective.objective_type
		if not _is_known_objective_type(objective_type):
			errors.append("INVALID_OBJECTIVE:%s:unknown_type" % String(objective_id))


static func _is_known_objective_type(objective_type: StringName) -> bool:
	if objective_type == &"":
		return false
	if String(objective_type).to_upper() == String(CANONICAL_CLEAR_ALL):
		return true
	return ObjectiveFactory.is_known_type(objective_type)


static func _check_boosters(definition: LevelDefinition, errors: PackedStringArray) -> void:
	for booster in definition.allowed_boosters:
		var normalized := StringName(String(booster).to_upper())
		if not KNOWN_BOOSTERS.has(normalized):
			errors.append("INVALID_BOOSTER:%s" % String(booster))
