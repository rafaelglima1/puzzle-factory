extends RefCounted
## DEV-ONLY M6 Generator Lab sample data.
##
## Mirrors the shape of generation-engine output using the generic Generator
## Lab contract keys. Dev fixtures only: NOT production content and not a second
## catalogue (AGENT-1 owns the real generator/solver results).


static func sample_candidates() -> Array:
	return [
		_accepted_easy(),
		_accepted_medium(),
		_rejected_invalid(),
		_rejected_unsolvable(),
		_duplicate(),
	]


static func sample_batch() -> Dictionary:
	return {
		"generated": 10000,
		"invalid": 1210,
		"unsolvable": 3950,
		"duplicates": 840,
		"accepted": 4000,
		"buckets": {"EASY": 900, "MEDIUM": 1800, "HARD": 1000, "EXPERT": 300},
	}


static func _base_preview(level_id: String, width: int, height: int) -> Dictionary:
	return {
		"level_id": level_id, "schema_version": 1, "revision": 1,
		"board_width": width, "board_height": height, "staging_slots": 4,
		"entities": [{
			"id": "v1", "type": "compact", "color": "COLOR_A",
			"cell": {"x": 0, "y": 0}, "footprint": {"width": 1, "height": 1},
			"route": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
		}],
		"destinations": [{
			"id": "station_a", "cell": {"x": width - 1, "y": 0},
			"footprint": {"width": 1, "height": 1},
			"accepted": ["COLOR_A"], "capacity": 1, "queue": ["COLOR_A"],
		}],
		"queues": [{"id": "q_a", "items": ["p_a1"]}],
		"items": [{"id": "p_a1", "type": "passenger_standard", "color": "COLOR_A", "destination": "station_a"}],
		"objectives": [{"id": "clear_all", "type": "clear_all", "mandatory": true}],
	}


static func _accepted_easy() -> Dictionary:
	return {
		"candidate_id": "cand_0001", "seed": 101,
		"preview": _base_preview("cand_0001_level", 4, 2),
		"generation": {"constraints": {"entity_count": 1, "item_count": 1, "color_count": 1, "staging_slots": 4}},
		"validation": {"valid": true, "errors": []},
		"solver": {"status": "SOLVABLE", "commands": [{"entityId": "v1"}], "depth": 1, "visited": 2, "expanded": 1, "dead_ends": 0, "branching_factor": 1.0, "runtime": 3},
		"difficulty": {"score": 0.12, "bucket": "EASY", "components": {"depth": 0.1, "dead_ends": 0.0, "staging": 0.2}},
		"dedupe": {"fingerprint": "fp_0001", "duplicate": false, "of": ""},
		"decision": {"status": "ACCEPTED", "reasons": []},
	}


static func _accepted_medium() -> Dictionary:
	return {
		"candidate_id": "cand_0002", "seed": 202,
		"preview": _base_preview("cand_0002_level", 5, 3),
		"generation": {"constraints": {"entity_count": 2, "item_count": 3, "color_count": 2, "staging_slots": 4}},
		"validation": {"valid": true, "errors": []},
		"solver": {"status": "SOLVABLE", "commands": [{"entityId": "v1"}, {"entityId": "v2"}], "depth": 4, "visited": 12, "expanded": 7, "dead_ends": 2, "branching_factor": 1.9, "runtime": 18},
		"difficulty": {"score": 0.52, "bucket": "MEDIUM", "components": {"depth": 0.5, "dead_ends": 0.3, "staging": 0.6}},
		"dedupe": {"fingerprint": "fp_0002", "duplicate": false, "of": ""},
		"decision": {"status": "ACCEPTED", "reasons": []},
	}


static func _rejected_invalid() -> Dictionary:
	return {
		"candidate_id": "cand_0003", "seed": 303,
		"preview": _base_preview("cand_0003_level", 4, 2),
		"generation": {"constraints": {"entity_count": 1, "staging_slots": 0}},
		"validation": {
			"status": "INVALID",
			"errors": [
				{"code": "OUT_OF_BOUNDS", "path": "vehicles[0].cell", "message": "entity leaves the board"},
				{"code": "UNKNOWN_DESTINATION", "path": "vehicles[0].station", "message": "unknown station"},
			],
		},
		"solver": {"status": "UNKNOWN"},
		"difficulty": {"score": 0.0, "bucket": "UNKNOWN", "components": {}},
		"dedupe": {"fingerprint": "fp_0003", "duplicate": false, "of": ""},
		"decision": {"status": "REJECTED", "reasons": ["validation_failed", "out_of_bounds"]},
	}


static func _rejected_unsolvable() -> Dictionary:
	return {
		"candidate_id": "cand_0004", "seed": 404,
		"preview": _base_preview("cand_0004_level", 5, 3),
		"generation": {"constraints": {"entity_count": 2, "staging_slots": 4}},
		"validation": {"valid": true, "errors": []},
		"solver": {"status": "UNSOLVABLE", "commands": [], "depth": 0, "visited": 40, "expanded": 22, "dead_ends": 9, "branching_factor": 2.4, "runtime": 55},
		"difficulty": {"score": 0.0, "bucket": "UNKNOWN", "components": {}},
		"dedupe": {"fingerprint": "fp_0004", "duplicate": false, "of": ""},
		"decision": {"status": "REJECTED", "reasons": ["unsolvable"]},
	}


static func _duplicate() -> Dictionary:
	return {
		"candidate_id": "cand_0005", "seed": 505,
		"preview": _base_preview("cand_0005_level", 4, 2),
		"generation": {"constraints": {"entity_count": 1, "staging_slots": 4}},
		"validation": {"valid": true, "errors": []},
		"solver": {"status": "SOLVABLE", "commands": [{"entityId": "v1"}], "depth": 1, "visited": 2, "expanded": 1, "dead_ends": 0, "branching_factor": 1.0, "runtime": 2},
		"difficulty": {"score": 0.15, "bucket": "EASY", "components": {"depth": 0.1}},
		"dedupe": {"fingerprint": "fp_0001", "duplicate": true, "of": "cand_0001"},
		"decision": {"status": "REJECTED", "reasons": ["duplicate"]},
	}
