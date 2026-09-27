extends "res://tests/framework/test_base.gd"
## M5 Traffic content conversion: official V1 JSON pack vs the legacy M3
## hardcoded catalogue, plus the adapter and solver-domain seams.
##
## The M3 catalogue is read here ONLY as a legacy regression reference; the
## production content path (TrafficLevelCatalogue / JSON) never uses it.

const EXPECTED_LEVEL_IDS: Array[String] = [
	"traffic_m3_l01_first_roll",
	"traffic_m3_l02_two_lanes",
	"traffic_m3_l03_right_order",
	"traffic_m3_l04_double_pickup",
	"traffic_m3_l05_tight_parking",
	"traffic_m3_l06_the_blocker",
	"traffic_m3_l07_three_colors",
	"traffic_m3_l08_no_room_to_wait",
	"traffic_m3_l09_multi_step",
	"traffic_m3_l10_rush_hour",
]

## First proven winning move per level, mirrored from the SOLUTIONS table in
## `game/tests/m3_levels_solvable_test.gd` (legacy reference).
const FIRST_MOVES := {
	"traffic_m3_l01_first_roll": &"v1",
	"traffic_m3_l02_two_lanes": &"v1",
	"traffic_m3_l03_right_order": &"v1",
	"traffic_m3_l04_double_pickup": &"v1",
	"traffic_m3_l05_tight_parking": &"v1",
	"traffic_m3_l06_the_blocker": &"v1",
	"traffic_m3_l07_three_colors": &"v1",
	"traffic_m3_l08_no_room_to_wait": &"v1",
	"traffic_m3_l09_multi_step": &"v_block",
	"traffic_m3_l10_rush_hour": &"v_block",
}


func run() -> void:
	_manifest_shape()
	_conversion_matches_m3()
	_all_official_levels_validate()
	_adapter_builds_simulations()
	_solver_domain_clone_semantics()


func _manifest_shape() -> void:
	check_eq(TrafficLevelCatalogue.count(), 10, "official catalogue has ten levels")
	check_eq(TrafficLevelCatalogue.count(), EXPECTED_LEVEL_IDS.size(), "count matches the expected id list")

	var ids := TrafficLevelCatalogue.level_ids()
	check_eq(ids.size(), 10, "ten level ids from the manifest")
	var unique := {}
	for index in ids.size():
		var id_value := String(ids[index])
		check(not id_value.is_empty(), "level id %d is not empty" % index)
		check(not unique.has(id_value), "level id '%s' is unique" % id_value)
		unique[id_value] = true
		if index < EXPECTED_LEVEL_IDS.size():
			check_eq(id_value, EXPECTED_LEVEL_IDS[index], "manifest order matches expected id at %d" % index)

	check_eq(TrafficLevelCatalogue.index_of(&"traffic_m3_l01_first_roll"), 0, "index_of finds the first level")
	check_eq(TrafficLevelCatalogue.index_of(&"not_a_level"), -1, "index_of rejects an unknown id")
	check_eq(String(TrafficLevelCatalogue.level_id(-1)), "", "level_id of an invalid index is empty")

	check(not TrafficLevelCatalogue.pack_dir().is_empty(), "pack dir is set")
	check(TrafficLevelCatalogue.manifest_path().ends_with("manifest.json"), "manifest path resolves")

	for index in TrafficLevelCatalogue.count():
		var result := TrafficLevelCatalogue.load_load_result(index)
		check(result.is_ok(), "level %d file resolves and loads (%s)" % [index, ",".join(result.errors)])


func _conversion_matches_m3() -> void:
	for index in M3LevelCatalogue.count():
		var m3 := M3LevelCatalogue.definition(index)
		var official := TrafficLevelCatalogue.load_definition(index)
		check(official != null, "official definition %d loads" % index)
		if official == null:
			continue

		var level_id := str(m3.get("level_id", ""))
		check_eq(String(official.level_id), level_id, "%s level id preserved" % level_id)
		check_eq(official.seed, int(m3.get("seed", -1)), "%s seed preserved" % level_id)
		check_eq(official.board_width, int(m3.get("width", -1)), "%s width preserved" % level_id)
		check_eq(official.board_height, int(m3.get("height", -1)), "%s height preserved" % level_id)
		check_eq(official.staging_slots, int(m3.get("staging_slots", -1)), "%s staging preserved" % level_id)

		check_eq(official.entities.size(), (m3.get("vehicles", []) as Array).size(), "%s vehicle count preserved" % level_id)
		check_eq(official.items.size(), (m3.get("passengers", []) as Array).size(), "%s passenger count preserved" % level_id)
		check_eq(official.destinations.size(), (m3.get("stations", []) as Array).size(), "%s station count preserved" % level_id)
		check_eq(official.queues.size(), (m3.get("queues", {}) as Dictionary).size(), "%s queue count preserved" % level_id)

		_compare_queues(official, m3.get("queues", {}), level_id)
		_compare_paths(official, m3.get("paths", {}), level_id)


func _compare_queues(official: LevelDefinition, m3_queues: Dictionary, level_id: String) -> void:
	for queue_id in m3_queues:
		var expected: Array = m3_queues[queue_id]
		var actual: Variant = _find_queue(official, String(queue_id))
		check(actual != null, "%s queue '%s' present" % [level_id, queue_id])
		if actual == null:
			continue
		var actual_ids: Array = actual.item_ids
		check_eq(actual_ids.size(), expected.size(), "%s queue '%s' size preserved" % [level_id, queue_id])
		for position in mini(actual_ids.size(), expected.size()):
			check_eq(String(actual_ids[position]), str(expected[position]), "%s queue '%s' FIFO order at %d" % [level_id, queue_id, position])


func _compare_paths(official: LevelDefinition, m3_paths: Dictionary, level_id: String) -> void:
	for path_id in m3_paths:
		var expected: Array = m3_paths[path_id]
		var actual: Variant = _find_path(official, String(path_id))
		check(actual != null, "%s path '%s' present" % [level_id, path_id])
		if actual == null:
			continue
		var actual_cells: Array = actual.cells
		check_eq(actual_cells.size(), expected.size(), "%s path '%s' cell count preserved" % [level_id, path_id])
		for position in mini(actual_cells.size(), expected.size()):
			var expected_cell: Dictionary = expected[position]
			check_eq(actual_cells[position].x, int(expected_cell.get("x", -1)), "%s path '%s' cell %d x" % [level_id, path_id, position])
			check_eq(actual_cells[position].y, int(expected_cell.get("y", -1)), "%s path '%s' cell %d y" % [level_id, path_id, position])


func _all_official_levels_validate() -> void:
	var errors := TrafficLevelCatalogue.validate_all()
	check_eq(errors.size(), 0, "official catalogue validate_all is empty (%s)" % ", ".join(errors))
	for index in TrafficLevelCatalogue.count():
		var definition := TrafficLevelCatalogue.load_definition(index)
		check(definition != null, "official definition %d parses" % index)
		if definition == null:
			continue
		check(LevelValidator.validate(definition).is_empty(), "official definition %d passes the validator" % index)


func _adapter_builds_simulations() -> void:
	for index in TrafficLevelCatalogue.count():
		var definition := TrafficLevelCatalogue.load_definition(index)
		if definition == null:
			check(false, "cannot build adapter simulation for missing definition %d" % index)
			continue
		var simulation := TrafficLevelDefinitionAdapter.build_simulation(definition)
		check(simulation != null, "adapter builds a simulation for %s" % definition.level_id)
		if simulation == null:
			continue
		var state := simulation.get_state()
		check_eq(state.entity_count(), definition.entities.size(), "%s entity count preserved through the adapter" % definition.level_id)
		check_eq(state.items.size(), definition.items.size(), "%s item count preserved through the adapter" % definition.level_id)
		check_eq(state.queues.size(), definition.queues.size(), "%s queue count preserved through the adapter" % definition.level_id)
		check_eq(state.destinations.size(), definition.destinations.size(), "%s destination count preserved through the adapter" % definition.level_id)


func _solver_domain_clone_semantics() -> void:
	for index in TrafficLevelCatalogue.count():
		var definition := TrafficLevelCatalogue.load_definition(index)
		if definition == null:
			check(false, "cannot build solver domain for missing definition %d" % index)
			continue
		var domain := TrafficSolverDomain.for_definition(definition)
		var first: Variant = domain.initial_state()
		check(first != null, "%s solver initial_state is a Simulation" % definition.level_id)
		if first == null:
			continue

		var fresh: Variant = domain.initial_state()
		check(first != fresh, "%s initial_state returns a fresh handle each call" % definition.level_id)
		check((first as Simulation).get_state().move_index == 0, "%s initial state starts at move_index 0" % definition.level_id)
		check((first as Simulation).get_state().is_in_progress(), "%s initial state is in progress" % definition.level_id)

		var level_key := String(definition.level_id)
		var entity_id: StringName = FIRST_MOVES.get(level_key, &"")
		check(entity_id != &"", "%s has a known first move" % level_key)
		if entity_id == &"":
			continue

		var command := {"type": "dispatch_entity", "entityId": String(entity_id)}
		check(_has_candidate(domain.candidate_commands(first), String(entity_id)), "%s candidate list contains the first move" % level_key)

		var before := domain.state_snapshot(first)
		var next_state: Variant = domain.apply_command(first, command)
		check(next_state != null, "%s first move applies to a non-null state" % level_key)
		if next_state == null:
			continue
		check(next_state is Simulation, "%s apply_command returns a Simulation" % level_key)
		check_eq((next_state as Simulation).get_state().move_index, 1, "%s move_index advanced after the first move" % level_key)
		check(
			Serialization.values_equal(before, domain.state_snapshot(first)),
			"%s apply_command does not mutate the input state" % level_key
		)


func _find_queue(definition: LevelDefinition, queue_id: String) -> Variant:
	for queue in definition.queues:
		if String(queue.id) == queue_id:
			return queue
	return null


func _find_path(definition: LevelDefinition, path_id: String) -> Variant:
	for path in definition.paths:
		if String(path.id) == path_id:
			return path
	return null


func _has_candidate(candidates: Array, entity_id: String) -> bool:
	for candidate in candidates:
		if str(candidate.get("entityId", "")) == entity_id:
			return true
	return false
