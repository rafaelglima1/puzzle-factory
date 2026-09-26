class_name GameState
extends RefCounted
## Complete logical puzzle state (blueprint §10), fully serializable.
##
## Schema history:
## - v1 (M1): board/entities/move_index/rng/completion.
## - v2 (M2): adds items, queues, destinations, paths, staging, objectives,
##   objectives_completed and fail_reason. v1 payloads are migrated
##   deterministically by [method migrate_dictionary] and remain loadable.
##
## Scope notes:
## - Logical simulation state, not the M10 save system (no file IO/checksum).
## - Only deterministic JSON-safe values are serialized ([Serialization]).
## - COMPLETED is the "won" state and FAILED the "lost" state; both names are
##   kept from M1 for serialized compatibility (see [method is_won]).

const SCHEMA_VERSION := 2

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
var fail_reason: StringName = &""

## M2 collections. Items live in [member items] and are ordered inside queues;
## a processed item leaves the registry (see ClearAllObjective).
var items: Dictionary = {}
var queues: Dictionary = {}
var destinations: Dictionary = {}
var paths: Dictionary = {}
var staging: StagingArea = null
var objectives: Array[Objective] = []
var objectives_completed: Array[StringName] = []


func _init(p_level_id: StringName = &"", p_seed: int = 0, p_dimensions: BoardDimensions = null) -> void:
	level_id = p_level_id
	seed = p_seed
	board = Board.new(p_dimensions if p_dimensions != null else BoardDimensions.new(0, 0))
	rng_state = DeterministicRng.normalize_seed(p_seed)
	staging = StagingArea.new()


# --- entities -----------------------------------------------------------------

func has_entity(entity_id: StringName) -> bool:
	return entities.has(entity_id)


func get_entity(entity_id: StringName) -> Entity:
	return entities.get(entity_id)


func entity_count() -> int:
	return entities.size()


func entity_ids() -> Array[StringName]:
	return _sorted_ids(entities)


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


# --- M2 collections -----------------------------------------------------------

func has_item(item_id: StringName) -> bool:
	return items.has(item_id)


func get_item(item_id: StringName) -> Item:
	return items.get(item_id)


func add_item(item: Item) -> bool:
	if item == null or item.id == &"" or items.has(item.id):
		return false
	items[item.id] = item
	return true


func remove_item(item_id: StringName) -> bool:
	if not items.has(item_id):
		return false
	items.erase(item_id)
	return true


func item_ids() -> Array[StringName]:
	return _sorted_ids(items)


func get_queue(queue_id: StringName) -> ItemQueue:
	return queues.get(queue_id)


func add_queue(queue: ItemQueue) -> bool:
	if queue == null or queue.id == &"" or queues.has(queue.id):
		return false
	queues[queue.id] = queue
	return true


func queue_ids() -> Array[StringName]:
	return _sorted_ids(queues)


func get_destination(destination_id: StringName) -> Destination:
	return destinations.get(destination_id)


func add_destination(destination: Destination) -> bool:
	if destination == null or destination.id == &"" or destinations.has(destination.id):
		return false
	destinations[destination.id] = destination
	return true


func destination_ids() -> Array[StringName]:
	return _sorted_ids(destinations)


func get_path(path_id: StringName) -> LogicalPath:
	return paths.get(path_id)


func add_path(path: LogicalPath) -> bool:
	if path == null or path.id == &"" or paths.has(path.id):
		return false
	paths[path.id] = path
	return true


func path_ids() -> Array[StringName]:
	return _sorted_ids(paths)


# --- objectives ---------------------------------------------------------------

func add_objective(objective: Objective) -> bool:
	if objective == null or objective.id == &"":
		return false
	for existing in objectives:
		if existing.id == objective.id:
			return false
	objectives.append(objective)
	return true


func get_objective(objective_id: StringName) -> Objective:
	for objective in objectives:
		if objective.id == objective_id:
			return objective
	return null


func is_objective_completed(objective_id: StringName) -> bool:
	return objectives_completed.has(objective_id)


func mark_objective_completed(objective_id: StringName) -> bool:
	if objective_id == &"" or objectives_completed.has(objective_id):
		return false
	objectives_completed.append(objective_id)
	return true


func mandatory_objectives() -> Array[Objective]:
	var result: Array[Objective] = []
	for objective in objectives:
		if objective.mandatory:
			result.append(objective)
	return result


func all_mandatory_objectives_completed() -> bool:
	for objective in mandatory_objectives():
		if not objectives_completed.has(objective.id):
			return false
	return true


# --- completion ---------------------------------------------------------------

func is_in_progress() -> bool:
	return completion_state == Completion.IN_PROGRESS


func is_completed() -> bool:
	return completion_state == Completion.COMPLETED


func is_failed() -> bool:
	return completion_state == Completion.FAILED


## Alias of [method is_completed] in game terms (M2 vocabulary).
func is_won() -> bool:
	return is_completed()


## Alias of [method is_failed] in game terms (M2 vocabulary).
func is_lost() -> bool:
	return is_failed()


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


func set_victory() -> bool:
	return set_completion(Completion.COMPLETED)


## Marks the level as lost with a stable machine-readable reason.
func set_failure(reason: StringName) -> bool:
	if not FailReason.is_known_name(reason):
		return false
	if not set_completion(Completion.FAILED):
		return false
	fail_reason = reason
	return true


## Stable serialized name of a completion value (&"" when unknown).
static func completion_state_name(value: int) -> StringName:
	return _COMPLETION_NAMES.get(value, &"")


static func completion_state_from_name(name: StringName) -> int:
	return _completion_from_name(name)


# --- rng ----------------------------------------------------------------------

## Creates a deterministic RNG positioned at the current [member rng_state].
## Callers must write the state back (see [CommandContext.commit]).
func create_rng() -> DeterministicRng:
	var rng := DeterministicRng.new(0)
	rng.set_state({DeterministicRng.STATE_KEY: rng_state})
	return rng


# --- serialization ------------------------------------------------------------

func logical_equals(other: GameState) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


## Canonical, deterministic representation: two logically equal states always
## produce identical output regardless of insertion order.
func to_dictionary() -> Dictionary:
	var serialized_entities: Array = []
	for entity_id in entity_ids():
		serialized_entities.append(entities[entity_id].to_dictionary())

	var serialized_items: Array = []
	for item_id in item_ids():
		serialized_items.append(items[item_id].to_dictionary())

	var serialized_queues: Array = []
	for queue_id in queue_ids():
		serialized_queues.append(queues[queue_id].to_dictionary())

	var serialized_destinations: Array = []
	for destination_id in destination_ids():
		serialized_destinations.append(destinations[destination_id].to_dictionary())

	var serialized_paths: Array = []
	for path_id in path_ids():
		serialized_paths.append(paths[path_id].to_dictionary())

	var serialized_objectives: Array = []
	for objective in objectives:
		serialized_objectives.append(objective.to_dictionary())

	var completed_objectives: Array = []
	for objective_id in objectives_completed:
		completed_objectives.append(String(objective_id))

	return {
		"schema_version": schema_version,
		"level_id": String(level_id),
		"level_revision": level_revision,
		"seed": seed,
		"rng_state": rng_state,
		"move_index": move_index,
		"elapsed_ms": elapsed_ms,
		"completion_state": String(_COMPLETION_NAMES.get(completion_state, &"")),
		"fail_reason": String(fail_reason),
		"board": board.to_dictionary(),
		"entities": serialized_entities,
		"items": serialized_items,
		"queues": serialized_queues,
		"destinations": serialized_destinations,
		"paths": serialized_paths,
		"staging": staging.to_dictionary(),
		"objectives": serialized_objectives,
		"objectives_completed": completed_objectives,
	}


## Upgrades older payloads to [constant SCHEMA_VERSION]. Only v1 -> v2 exists;
## other versions are returned unchanged so validation reports them.
static func migrate_dictionary(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return data
	var version := int(data.get("schema_version", -1))
	if version != 1:
		return data
	var migrated: Dictionary = data.duplicate(true)
	migrated["schema_version"] = SCHEMA_VERSION
	migrated["fail_reason"] = ""
	migrated["items"] = []
	migrated["queues"] = []
	migrated["destinations"] = []
	migrated["paths"] = []
	migrated["staging"] = {"slot_count": 0, "occupants": []}
	migrated["objectives"] = []
	migrated["objectives_completed"] = []
	return migrated


static func validate_dictionary(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("state_not_a_dictionary")
		return errors

	# v1 payloads are validated in their migrated (v2) form so M1 serialized
	# state stays loadable and checkable.
	data = migrate_dictionary(data)
	var version := int(data.get("schema_version", -1))
	if version != SCHEMA_VERSION:
		errors.append("unsupported_schema_version:%d" % version)
		return errors

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

	var reason := StringName(str(data.get("fail_reason", "")))
	if reason != &"" and not FailReason.is_known_name(reason):
		errors.append("unknown_fail_reason:%s" % reason)

	var board_data: Variant = data.get("board", null)
	if typeof(board_data) != TYPE_DICTIONARY:
		errors.append("missing_board")
		return errors
	errors.append_array(Board.validate_dictionary(board_data))

	var dimensions := BoardDimensions.from_dictionary((board_data as Dictionary).get("dimensions", {}))
	var placed_ids := {}
	for entry in board_data.get("placements", []):
		placed_ids[str(entry.get("entity_id", ""))] = true

	var entities_data: Variant = data.get("entities", null)
	if typeof(entities_data) != TYPE_ARRAY:
		errors.append("entities_not_an_array")
		return errors

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
		var state_value := EntityState.from_string_name(state_name)
		if state_value == -1:
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

		if state_value == EntityState.Value.COMPLETED and position != null:
			errors.append("completed_entity_on_board:%s" % entity_id)

	for placed_id in placed_ids.keys():
		if not seen_ids.has(placed_id):
			errors.append("placement_unknown_entity:%s" % placed_id)

	errors.append_array(_validate_items(data.get("items", [])))
	errors.append_array(_validate_queues(data.get("queues", []), data.get("items", [])))
	errors.append_array(_validate_destinations(data.get("destinations", []), data.get("queues", [])))
	errors.append_array(_validate_paths(data.get("paths", []), dimensions))
	errors.append_array(_validate_staging(data.get("staging", {}), seen_ids))
	errors.append_array(_validate_objectives(data.get("objectives", []), data.get("objectives_completed", [])))

	return errors


static func from_dictionary(data: Dictionary) -> GameState:
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GameState.from_dictionary rejected non-dictionary state")
		return null
	var migrated := migrate_dictionary(data)
	var errors := validate_dictionary(migrated)
	if not errors.is_empty():
		push_error("GameState.from_dictionary rejected invalid state: %s" % ", ".join(errors))
		return null

	var dimensions := BoardDimensions.from_dictionary(migrated["board"]["dimensions"])
	var state := GameState.new(
		StringName(str(migrated.get("level_id", ""))),
		int(migrated.get("seed", 0)),
		dimensions
	)
	state.schema_version = int(migrated.get("schema_version", SCHEMA_VERSION))
	state.level_revision = int(migrated.get("level_revision", 1))
	state.rng_state = int(migrated.get("rng_state", 0))
	state.move_index = int(migrated.get("move_index", 0))
	state.elapsed_ms = int(migrated.get("elapsed_ms", 0))
	state.completion_state = _completion_from_name(StringName(str(migrated.get("completion_state", "in_progress"))))
	state.fail_reason = StringName(str(migrated.get("fail_reason", "")))

	for entry in migrated.get("entities", []):
		var entity := Entity.from_dictionary(entry)
		state.entities[entity.id] = entity
	for entry in migrated.get("items", []):
		var item := Item.from_dictionary(entry)
		state.items[item.id] = item
	for entry in migrated.get("queues", []):
		var queue := ItemQueue.from_dictionary(entry)
		state.queues[queue.id] = queue
	for entry in migrated.get("destinations", []):
		var destination := Destination.from_dictionary(entry)
		state.destinations[destination.id] = destination
	for entry in migrated.get("paths", []):
		var path := LogicalPath.from_dictionary(entry)
		state.paths[path.id] = path
	for entry in migrated.get("objectives", []):
		var objective := ObjectiveFactory.from_dictionary(entry)
		if objective != null:
			state.objectives.append(objective)
	for objective_id in migrated.get("objectives_completed", []):
		state.objectives_completed.append(StringName(str(objective_id)))

	state.staging = StagingArea.from_dictionary(migrated.get("staging", {}))
	state.board = Board.from_dictionary(migrated["board"])
	return state


static func _sorted_ids(collection: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	var keys: Array = collection.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key in keys:
		ids.append(key)
	return ids


static func _validate_items(items_data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(items_data) != TYPE_ARRAY:
		errors.append("items_not_an_array")
		return errors
	var seen := {}
	for entry in items_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("item_not_a_dictionary")
			continue
		var item_id := str(entry.get("id", ""))
		if item_id.is_empty():
			errors.append("item_missing_id")
			continue
		if seen.has(item_id):
			errors.append("duplicate_item_id:%s" % item_id)
			continue
		seen[item_id] = true
	return errors


static func _validate_queues(queues_data: Variant, items_data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(queues_data) != TYPE_ARRAY:
		errors.append("queues_not_an_array")
		return errors
	var item_ids := {}
	var queue_ids := {}
	var known_items := {}
	for entry in items_data:
		if typeof(entry) == TYPE_DICTIONARY:
			known_items[str(entry.get("id", ""))] = true
	for entry in queues_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("queue_not_a_dictionary")
			continue
		var queue_id := str(entry.get("id", ""))
		if queue_id.is_empty():
			errors.append("queue_missing_id")
			continue
		if queue_ids.has(queue_id):
			errors.append("duplicate_queue_id:%s" % queue_id)
			continue
		queue_ids[queue_id] = true
		var policy := StringName(str(entry.get("policy", "")))
		if ItemQueue.policy_from_string_name(policy) == -1:
			errors.append("unknown_queue_policy:%s" % queue_id)
		var ids: Variant = entry.get("item_ids", [])
		if typeof(ids) != TYPE_ARRAY:
			errors.append("queue_item_ids_not_an_array:%s" % queue_id)
			continue
		for item_id_value in ids:
			var item_id := str(item_id_value)
			if item_ids.has(item_id):
				errors.append("item_in_multiple_queues:%s" % item_id)
			item_ids[item_id] = true
			if not known_items.has(item_id):
				errors.append("queue_unknown_item:%s" % item_id)
	for entry in items_data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := str(entry.get("id", ""))
		if not item_id.is_empty() and not item_ids.has(item_id):
			errors.append("unreferenced_item:%s" % item_id)
	return errors


static func _validate_destinations(destinations_data: Variant, queues_data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(destinations_data) != TYPE_ARRAY:
		errors.append("destinations_not_an_array")
		return errors
	var queue_ids := {}
	for entry in queues_data:
		if typeof(entry) == TYPE_DICTIONARY:
			queue_ids[str(entry.get("id", ""))] = true
	var seen := {}
	for entry in destinations_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("destination_not_a_dictionary")
			continue
		var destination_id := str(entry.get("id", ""))
		if destination_id.is_empty():
			errors.append("destination_missing_id")
			continue
		if seen.has(destination_id):
			errors.append("duplicate_destination_id:%s" % destination_id)
			continue
		seen[destination_id] = true
		if int(entry.get("capacity", 0)) < 0:
			errors.append("invalid_destination_capacity:%s" % destination_id)
		if int(entry.get("processed_count", 0)) < 0:
			errors.append("invalid_destination_processed_count:%s" % destination_id)
		var state_name := StringName(str(entry.get("state", "")))
		if Destination.state_from_string_name(state_name) == -1:
			errors.append("unknown_destination_state:%s" % destination_id)
		var queue_id := str(entry.get("queue_id", ""))
		if not queue_id.is_empty() and not queue_ids.has(queue_id):
			errors.append("unknown_destination_queue:%s" % destination_id)
	return errors


static func _validate_paths(paths_data: Variant, dimensions: BoardDimensions) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(paths_data) != TYPE_ARRAY:
		errors.append("paths_not_an_array")
		return errors
	var seen := {}
	for entry in paths_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("path_not_a_dictionary")
			continue
		var path_id := str(entry.get("id", ""))
		if path_id.is_empty():
			errors.append("path_missing_id")
			continue
		if seen.has(path_id):
			errors.append("duplicate_path_id:%s" % path_id)
			continue
		seen[path_id] = true
		var path := LogicalPath.from_dictionary(entry)
		for error in path.validate(dimensions):
			errors.append("invalid_path:%s:%s" % [path_id, error])
	return errors


static func _validate_staging(staging_data: Variant, entity_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(staging_data) != TYPE_DICTIONARY:
		errors.append("staging_not_a_dictionary")
		return errors
	var slot_count := int(staging_data.get("slot_count", -1))
	if slot_count < 0:
		errors.append("invalid_staging_slot_count")
		return errors
	var occupants: Variant = staging_data.get("occupants", [])
	if typeof(occupants) != TYPE_ARRAY:
		errors.append("staging_occupants_not_an_array")
		return errors
	if occupants.size() != slot_count:
		errors.append("staging_occupant_count_mismatch")
	var seen := {}
	for value in occupants:
		var occupant := str(value)
		if occupant.is_empty():
			continue
		if not entity_ids.has(occupant):
			errors.append("staged_unknown_entity:%s" % occupant)
		if seen.has(occupant):
			errors.append("staged_entity_twice:%s" % occupant)
		seen[occupant] = true
	return errors


static func _validate_objectives(objectives_data: Variant, completed_data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(objectives_data) != TYPE_ARRAY:
		errors.append("objectives_not_an_array")
		return errors
	if typeof(completed_data) != TYPE_ARRAY:
		errors.append("objectives_completed_not_an_array")
		return errors
	var seen := {}
	for entry in objectives_data:
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("objective_not_a_dictionary")
			continue
		var objective_id := str(entry.get("id", ""))
		if objective_id.is_empty():
			errors.append("objective_missing_id")
			continue
		if seen.has(objective_id):
			errors.append("duplicate_objective_id:%s" % objective_id)
			continue
		seen[objective_id] = true
		var objective_type := StringName(str(entry.get("objective_type", "")))
		if not ObjectiveFactory.is_known_type(objective_type):
			errors.append("unknown_objective_type:%s" % objective_id)
	if seen.is_empty() and not completed_data.is_empty():
		errors.append("objectives_completed_without_objectives")
	for value in completed_data:
		var objective_id := str(value)
		if not seen.has(objective_id):
			errors.append("completed_unknown_objective:%s" % objective_id)
	return errors


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
