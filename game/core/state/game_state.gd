class_name GameState
extends RefCounted
## Complete logical puzzle state (blueprint §10), fully serializable.
##
## M1 scope notes:
## - This is logical simulation state, not the M10 save system. There is no
##   file IO, no checksum, no migration framework here.
## - Concepts owned by later milestones (items, queues, destinations,
##   objectives, staging, score, boosters) are added by bumping
##   [constant SCHEMA_VERSION] in the milestone that needs them.
## - Only deterministic, JSON-safe values are serialized (see [Serialization]).

const SCHEMA_VERSION := 1

enum Completion { IN_PROGRESS, COMPLETED, FAILED }

const _COMPLETION_NAMES := {
	Completion.IN_PROGRESS: &"in_progress",
	Completion.COMPLETED: &"completed",
	Completion.FAILED: &"failed",
}

var schema_version: int = SCHEMA_VERSION
var level_id: StringName = &""
var level_revision: int = 1
var seed: int = 0
var rng_state: int = 0
var board: Board = null
var entities: Dictionary = {}
var move_index: int = 0
var elapsed_ms: int = 0
var completion_state: int = Completion.IN_PROGRESS


func _init(p_level_id: StringName = &"", p_seed: int = 0, p_dimensions: BoardDimensions = null) -> void:
	level_id = p_level_id
	seed = p_seed
	board = Board.new(p_dimensions if p_dimensions != null else BoardDimensions.new(0, 0))
	rng_state = DeterministicRng.normalize_seed(p_seed)


func has_entity(entity_id: StringName) -> bool:
	return entities.has(entity_id)


func get_entity(entity_id: StringName) -> Entity:
	return entities.get(entity_id)


func entity_count() -> int:
	return entities.size()


func entity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var keys: Array = entities.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for entity_id in keys:
		ids.append(entity_id)
	return ids


func add_entity(entity: Entity) -> bool:
	if entity == null or entity.id == &"":
		return false
	if entities.has(entity.id):
		return false
	entities[entity.id] = entity
	return true


func remove_entity(entity_id: StringName) -> bool:
	if not entities.has(entity_id):
		return false
	entities.erase(entity_id)
	return true


func is_in_progress() -> bool:
	return completion_state == Completion.IN_PROGRESS


func is_completed() -> bool:
	return completion_state == Completion.COMPLETED


func is_failed() -> bool:
	return completion_state == Completion.FAILED


## Completion is terminal: a finished level cannot transition again.
func set_completion(new_state: int) -> bool:
	if not _COMPLETION_NAMES.has(new_state):
		return false
	if completion_state != Completion.IN_PROGRESS:
		return false
	if new_state == Completion.IN_PROGRESS:
		return false
	completion_state = new_state
	return true


## Creates a deterministic RNG positioned at the current [member rng_state].
## Callers must write the state back (see [CommandContext.commit]).
func create_rng() -> DeterministicRng:
	var rng := DeterministicRng.new(0)
	rng.set_state({DeterministicRng.STATE_KEY: rng_state})
	return rng


func logical_equals(other: GameState) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


## Canonical, deterministic representation: two logically equal states always
## produce identical output regardless of entity insertion order.
func to_dictionary() -> Dictionary:
	var serialized_entities: Array = []
	for entity_id in entity_ids():
		serialized_entities.append(entities[entity_id].to_dictionary())
	return {
		"schema_version": schema_version,
		"level_id": String(level_id),
		"level_revision": level_revision,
		"seed": seed,
		"rng_state": rng_state,
		"move_index": move_index,
		"elapsed_ms": elapsed_ms,
		"completion_state": String(_COMPLETION_NAMES.get(completion_state, &"")),
		"board": board.to_dictionary(),
		"entities": serialized_entities,
	}


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("state_not_a_dictionary")
		return errors

	var version := int(data.get("schema_version", -1))
	if version != SCHEMA_VERSION:
		errors.append("unsupported_schema_version:%d" % version)

	if str(data.get("level_id", "")).is_empty():
		errors.append("missing_level_id")
	if int(data.get("level_revision", 0)) < 1:
		errors.append("invalid_level_revision")
	if int(data.get("move_index", -1)) < 0:
		errors.append("invalid_move_index")
	if int(data.get("elapsed_ms", -1)) < 0:
		errors.append("invalid_elapsed_ms")

	var rng_state := int(data.get("rng_state", -1))
	if rng_state < 0 or rng_state >= DeterministicRng.MODULUS:
		errors.append("invalid_rng_state")

	var completion := StringName(str(data.get("completion_state", "")))
	var completion_known := false
	for value in _COMPLETION_NAMES:
		if _COMPLETION_NAMES[value] == completion:
			completion_known = true
			break
	if not completion_known:
		errors.append("unknown_completion_state:%s" % completion)

	var board_data: Variant = data.get("board", null)
	if typeof(board_data) != TYPE_DICTIONARY:
		errors.append("missing_board")
		return errors
	errors.append_array(Board.validate_dictionary(board_data))

	var entities_data: Variant = data.get("entities", null)
	if typeof(entities_data) != TYPE_ARRAY:
		errors.append("entities_not_an_array")
		return errors

	var dimensions := BoardDimensions.from_dictionary((board_data as Dictionary).get("dimensions", {}))
	var placed_ids := {}
	for entry in board_data.get("placements", []):
		placed_ids[str(entry.get("entity_id", ""))] = true

	var seen_ids := {}
	for entry in entities_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("entity_not_a_dictionary")
			continue
		var entity_id := str(entry.get("id", ""))
		if entity_id.is_empty():
			errors.append("entity_missing_id")
			continue
		if seen_ids.has(entity_id):
			errors.append("duplicate_entity_id:%s" % entity_id)
			continue
		seen_ids[entity_id] = true

		var footprint := Footprint.from_dictionary(entry.get("footprint", {}))
		if not footprint.is_valid():
			errors.append("invalid_entity_footprint:%s" % entity_id)

		var state_name := StringName(str(entry.get("state", "")))
		if EntityState.from_string_name(state_name) == -1:
			errors.append("unknown_entity_state:%s" % entity_id)

		var orientation_name := StringName(str(entry.get("orientation", "")))
		if not Direction.is_valid(Direction.from_string_name(orientation_name)):
			errors.append("unknown_entity_orientation:%s" % entity_id)

		var position: Variant = entry.get("position")
		if position != null:
			if typeof(position) != TYPE_DICTIONARY:
				errors.append("invalid_entity_position:%s" % entity_id)
			elif not placed_ids.has(entity_id):
				errors.append("entity_position_without_board_placement:%s" % entity_id)
			else:
				var grid_position := GridPosition.from_dictionary(position)
				if not dimensions.contains_footprint(footprint, grid_position):
					errors.append("entity_out_of_bounds:%s" % entity_id)
				if not _placement_matches(board_data, entity_id, grid_position, footprint):
					errors.append("entity_placement_mismatch:%s" % entity_id)
		elif placed_ids.has(entity_id):
			errors.append("board_placement_without_entity_position:%s" % entity_id)

	for placed_id in placed_ids.keys():
		if not seen_ids.has(placed_id):
			errors.append("placement_unknown_entity:%s" % placed_id)

	return errors


static func from_dictionary(data: Dictionary) -> GameState:
	var errors := validate_dictionary(data)
	if not errors.is_empty():
		push_error("GameState.from_dictionary rejected invalid state: %s" % ", ".join(errors))
		return null

	var dimensions := BoardDimensions.from_dictionary(data["board"]["dimensions"])
	var state := GameState.new(
		StringName(str(data.get("level_id", ""))),
		int(data.get("seed", 0)),
		dimensions
	)
	state.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	state.level_revision = int(data.get("level_revision", 1))
	state.rng_state = int(data.get("rng_state", 0))
	state.move_index = int(data.get("move_index", 0))
	state.elapsed_ms = int(data.get("elapsed_ms", 0))
	state.completion_state = _completion_from_name(StringName(str(data.get("completion_state", "in_progress"))))

	for entry in data.get("entities", []):
		var entity := Entity.from_dictionary(entry)
		state.entities[entity.id] = entity

	state.board = Board.from_dictionary(data["board"])
	return state


static func _completion_from_name(name: StringName) -> int:
	for value in _COMPLETION_NAMES:
		if _COMPLETION_NAMES[value] == name:
			return value
	return Completion.IN_PROGRESS


static func _placement_matches(board_data: Dictionary, entity_id: String, position: GridPosition, footprint: Footprint) -> bool:
	for entry in board_data.get("placements", []):
		if str(entry.get("entity_id", "")) != entity_id:
			continue
		var placement_position := GridPosition.from_dictionary(entry.get("position", {}))
		var placement_footprint := Footprint.from_dictionary(entry.get("footprint", {}))
		return placement_position.equals(position) and placement_footprint.equals(footprint)
	return false
