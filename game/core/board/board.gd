class_name Board
extends RefCounted
## Authoritative logical grid: occupancy, placement and movement validation.
##
## Invariants:
## - Occupancy is authoritative for logical blocking. A cell holds at most one
##   entity id.
## - [Board] is the single write path for [member Entity.position]: placement
##   and movement go through [method place_entity] / [method move_entity],
##   which keep the occupancy index and the entity in sync.
## - All validation happens before any mutation, so rejected operations leave
##   the board untouched (atomic rejection).
## - Iteration helpers return deterministic (sorted / row-major) results.

var dimensions: BoardDimensions
var _cells: Dictionary = {}
var _placements: Dictionary = {}


func _init(p_dimensions: BoardDimensions = null) -> void:
	dimensions = p_dimensions if p_dimensions != null else BoardDimensions.new(0, 0)


func is_ready() -> bool:
	return dimensions != null and dimensions.is_valid()


func entity_count() -> int:
	return _placements.size()


func has_entity(entity_id: StringName) -> bool:
	return _placements.has(entity_id)


func position_of(entity_id: StringName) -> GridPosition:
	var placement: Variant = _placements.get(entity_id)
	if placement == null:
		return null
	return placement["position"]


func footprint_of(entity_id: StringName) -> Footprint:
	var placement: Variant = _placements.get(entity_id)
	if placement == null:
		return null
	return placement["footprint"]


func occupant_at(position: GridPosition) -> StringName:
	if not dimensions.contains(position):
		return &""
	return _cells.get(dimensions.index_of(position), &"")


func is_cell_free(position: GridPosition) -> bool:
	return occupant_at(position) == &""


func occupant_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entity_id in _sorted_placement_ids():
		ids.append(entity_id)
	return ids


func cells_for(entity_id: StringName) -> Array[GridPosition]:
	var cells: Array[GridPosition] = []
	var footprint := footprint_of(entity_id)
	var position := position_of(entity_id)
	if footprint == null or position == null:
		return cells
	return footprint.cell_positions(position)


func is_in_bounds(footprint: Footprint, position: GridPosition) -> bool:
	return dimensions.contains_footprint(footprint, position)


func can_place(footprint: Footprint, position: GridPosition, ignored_id: StringName = &"") -> bool:
	if not is_ready() or footprint == null or position == null or not footprint.is_valid():
		return false
	if not dimensions.contains_footprint(footprint, position):
		return false
	for cell in footprint.cell_positions(position):
		var occupant: StringName = _cells.get(dimensions.index_of(cell), &"")
		if occupant != &"" and occupant != ignored_id:
			return false
	return true


func blockers_for(footprint: Footprint, position: GridPosition, ignored_id: StringName = &"") -> Array[StringName]:
	var seen := {}
	if not is_ready() or footprint == null or position == null or not footprint.is_valid():
		return []
	for cell in footprint.cell_positions(position):
		if not dimensions.contains(cell):
			continue
		var occupant: StringName = _cells.get(dimensions.index_of(cell), &"")
		if occupant != &"" and occupant != ignored_id:
			seen[occupant] = true
	var blockers: Array[StringName] = []
	var keys: Array = []
	for entity_id in seen.keys():
		keys.append(entity_id)
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for entity_id in keys:
		blockers.append(entity_id)
	return blockers


func place_entity(entity: Entity, position: GridPosition) -> bool:
	if entity == null or position == null:
		return false
	if _placements.has(entity.id):
		return false
	if not can_place(entity.footprint, position, entity.id):
		return false
	_write_placement(entity.id, entity.footprint, position)
	entity.position = position
	return true


func move_entity(entity: Entity, target: GridPosition) -> bool:
	if entity == null or target == null:
		return false
	var current: Variant = _placements.get(entity.id)
	if current == null:
		return false
	var footprint: Footprint = current["footprint"]
	if not dimensions.contains_footprint(footprint, target):
		return false
	if not can_place(footprint, target, entity.id):
		return false
	_clear_placement(entity.id, footprint, current["position"])
	_write_placement(entity.id, footprint, target)
	entity.position = target
	return true


func remove_entity(entity: Entity) -> bool:
	if entity == null:
		return false
	var current: Variant = _placements.get(entity.id)
	if current == null:
		return false
	_clear_placement(entity.id, current["footprint"], current["position"])
	return true


func to_dictionary() -> Dictionary:
	var placements: Array = []
	for entity_id in _sorted_placement_ids():
		var placement: Dictionary = _placements[entity_id]
		placements.append({
			"entity_id": String(entity_id),
			"position": placement["position"].to_dictionary(),
			"footprint": placement["footprint"].to_dictionary(),
		})
	return {
		"dimensions": dimensions.to_dictionary(),
		"placements": placements,
	}


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("board_not_a_dictionary")
		return errors
	var dims := BoardDimensions.from_dictionary(data.get("dimensions", {}))
	if not dims.is_valid():
		errors.append("invalid_board_dimensions")
		return errors
	var placements: Variant = data.get("placements", [])
	if typeof(placements) != TYPE_ARRAY:
		errors.append("placements_not_an_array")
		return errors
	var seen_ids := {}
	var seen_cells := {}
	for entry in placements:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("placement_not_a_dictionary")
			continue
		var entity_id := str(entry.get("entity_id", ""))
		if entity_id.is_empty():
			errors.append("placement_missing_entity_id")
			continue
		if seen_ids.has(entity_id):
			errors.append("duplicate_placement:%s" % entity_id)
			continue
		seen_ids[entity_id] = true
		var position := GridPosition.from_dictionary(entry.get("position", {}))
		var footprint := Footprint.from_dictionary(entry.get("footprint", {}))
		if not footprint.is_valid():
			errors.append("invalid_footprint:%s" % entity_id)
			continue
		if not dims.contains_footprint(footprint, position):
			errors.append("placement_out_of_bounds:%s" % entity_id)
			continue
		for cell in footprint.cell_positions(position):
			var index := dims.index_of(cell)
			if seen_cells.has(index):
				errors.append("placement_overlap:%s" % entity_id)
				break
			seen_cells[index] = true
	return errors


static func from_dictionary(data: Dictionary) -> Board:
	if not validate_dictionary(data).is_empty():
		return null
	var dims := BoardDimensions.from_dictionary(data.get("dimensions", {}))
	var board := Board.new(dims)
	for entry in data.get("placements", []):
		var entity_id := StringName(str(entry.get("entity_id", "")))
		var position := GridPosition.from_dictionary(entry.get("position", {}))
		var footprint := Footprint.from_dictionary(entry.get("footprint", {}))
		board._write_placement(entity_id, footprint, position)
	return board


func _sorted_placement_ids() -> Array:
	var ids: Array = _placements.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


func _write_placement(entity_id: StringName, footprint: Footprint, position: GridPosition) -> void:
	for cell in footprint.cell_positions(position):
		_cells[dimensions.index_of(cell)] = entity_id
	_placements[entity_id] = {"position": position, "footprint": footprint}


func _clear_placement(entity_id: StringName, footprint: Footprint, position: GridPosition) -> void:
	for cell in footprint.cell_positions(position):
		var index := dimensions.index_of(cell)
		if _cells.get(index, &"") == entity_id:
			_cells.erase(index)
	_placements.erase(entity_id)
