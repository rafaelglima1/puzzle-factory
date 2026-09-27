extends RefCounted
## DEV-ONLY sample preview DTOs for the M5 Level Lab.
##
## These mirror the *shape* of one or two M3 levels using the generic Level Lab
## contract keys. They exist only so the debug tool has something to render in
## the editor/tests; they are NOT production content and must never be treated
## as a second level catalogue (AGENT-1 owns real content).


static func sample_previews() -> Array:
	return [level_one(), level_two()]


static func level_one() -> Dictionary:
	return {
		"level_id": "sample_lab_l01",
		"schema_version": 1,
		"revision": 1,
		"board_width": 4,
		"board_height": 2,
		"staging_slots": 4,
		"entities": [
			{
				"id": "v1", "type": "compact", "color": "COLOR_A",
				"cell": {"x": 0, "y": 0}, "footprint": {"width": 1, "height": 1},
				"route": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			},
		],
		"destinations": [
			{
				"id": "station_a", "cell": {"x": 3, "y": 0}, "footprint": {"width": 1, "height": 1},
				"accepted": ["COLOR_A"], "capacity": 1, "queue": ["COLOR_A"],
			},
		],
		"queues": [{"id": "q_a", "items": ["p_a1"]}],
		"items": [
			{"id": "p_a1", "type": "passenger_standard", "color": "COLOR_A", "destination": "station_a"},
		],
		"objectives": [{"id": "clear_all", "type": "clear_all", "mandatory": true}],
		"validation": {"valid": true, "errors": []},
		"solver": {
			"status": "SOLVABLE",
			"commands": [{"type": "dispatch_entity", "entityId": "v1"}],
			"depth": 1, "visited": 2, "expanded": 1, "dead_ends": 0,
			"branching_factor": 1.0, "runtime": 3,
		},
	}


static func level_two() -> Dictionary:
	return {
		"level_id": "sample_lab_l02",
		"schema_version": 1,
		"revision": 2,
		"board_width": 5,
		"board_height": 3,
		"staging_slots": 4,
		"entities": [
			{
				"id": "v1", "type": "compact", "color": "COLOR_A",
				"cell": {"x": 0, "y": 0}, "footprint": {"width": 1, "height": 1},
				"route": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			},
			{
				"id": "v2", "type": "van", "color": "COLOR_B",
				"cell": {"x": 0, "y": 2}, "footprint": {"width": 2, "height": 1},
				"route": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
			},
		],
		"destinations": [
			{
				"id": "station_a", "cell": {"x": 4, "y": 0}, "footprint": {"width": 1, "height": 1},
				"accepted": ["COLOR_A"], "capacity": 1, "queue": ["COLOR_A"],
			},
			{
				"id": "station_b", "cell": {"x": 4, "y": 2}, "footprint": {"width": 1, "height": 1},
				"accepted": ["COLOR_B"], "capacity": 1, "queue": ["COLOR_B"],
			},
		],
		"queues": [
			{"id": "q_a", "items": ["p_a1"]},
			{"id": "q_b", "items": ["p_b1"]},
		],
		"items": [
			{"id": "p_a1", "type": "passenger_standard", "color": "COLOR_A", "destination": "station_a"},
			{"id": "p_b1", "type": "passenger_standard", "color": "COLOR_B", "destination": "station_b"},
		],
		"objectives": [{"id": "clear_all", "type": "clear_all", "mandatory": true}],
		"validation": {"valid": true, "errors": []},
		"solver": {
			"status": "SOLVABLE",
			"commands": [
				{"type": "dispatch_entity", "entityId": "v1"},
				{"type": "dispatch_entity", "entityId": "v2"},
			],
			"depth": 2, "visited": 5, "expanded": 3, "dead_ends": 1,
			"branching_factor": 1.6, "runtime": 7,
		},
	}


static func invalid_validation() -> Dictionary:
	return {
		"status": "INVALID",
		"errors": [
			{"code": "unknown_destination", "path": "vehicles[0].station", "message": "station 'ghost' does not exist"},
			{"code": "out_of_bounds", "path": "vehicles[1].cell", "message": "entity 'v2' leaves the board"},
			{"code": "duplicate_id", "path": "entities", "message": "duplicate entity id 'v1'"},
		],
	}


static func unsolvable_solver() -> Dictionary:
	return {
		"status": "UNSOLVABLE",
		"commands": [],
		"depth": 0, "visited": 12, "expanded": 9, "dead_ends": 4,
		"branching_factor": 2.3, "runtime": 15,
	}


static func unknown_solver() -> Dictionary:
	return {"status": "UNKNOWN", "runtime": 90000}
