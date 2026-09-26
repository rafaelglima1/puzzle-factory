class_name M3LevelCatalogue
extends RefCounted
## M3 manual level catalogue — OWNER: AGENT-1.
##
## M3 ships exactly ten hand-authored, deterministic levels using only the M2
## mechanics (ColorKey matching, FIFO queues, vehicle/station capacity, route
## blocking, staging pressure, CLEAR_ALL). This is deliberately NOT the M5
## level framework: there is no generic loader, no schema, no validator and no
## solver here. M5 replaces this catalogue with the formal LevelSchema/loader
## and moves level data to `content/levels/`.
##
## Placement rationale: the definitions use Traffic vocabulary, so they live in
## the product integration layer (`game/integration/traffic/**`, ADR-013)
## instead of the generic `game/levels/**` tree, keeping generic folders free of
## product terminology.
##
## Level design notes (M2 rule constraints that shaped the catalogue):
## - A vehicle COMPLETES only if it loads at least one item; otherwise it is
##   STAGED, and staging has no recovery in M2 — so every winning line must
##   load at least one item per vehicle.
## - Loading inspects the queue FRONT only (strict FIFO) and requires the item's
##   color key to be accepted by the station AND to equal the vehicle color.
## - CLEAR_ALL requires the item registry empty and every vehicle COMPLETED.
## - Routes are validated (>= 2 contiguous in-bounds cells, no repeats) and must
##   start at the vehicle cell.
##
## Winning command sequences live in the tests (`game/tests/m3_levels_solvable_test.gd`),
## not in production data.

const LEVEL_COUNT := 10

const DEFINITIONS: Array[Dictionary] = [
	{
		"level_id": "traffic_m3_l01_first_roll",
		"seed": 11,
		"width": 4, "height": 2, "staging_slots": 4,
		"paths": {"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]},
		"stations": [{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 1, "queue": "q_a",
			"cell": {"x": 3, "y": 0}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_a": ["p_a1"]},
		"passengers": [{"id": "p_a1", "color": "COLOR_A", "station": "station_a"}],
		"vehicles": [{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
			"footprint": {"width": 1, "height": 1},
			"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"}],
	},
	{
		"level_id": "traffic_m3_l02_two_lanes",
		"seed": 12,
		"width": 5, "height": 3, "staging_slots": 4,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
		},
		"stations": [
			{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 1, "queue": "q_a",
				"cell": {"x": 4, "y": 0}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_b", "accepted": ["COLOR_B"], "capacity": 1, "queue": "q_b",
				"cell": {"x": 4, "y": 2}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_a": ["p_a1"], "q_b": ["p_b1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_b"},
		],
		"vehicles": [
			{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"},
			{"id": "v2", "type": "van", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 2, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_v2", "station": "station_b"},
		],
	},
	{
		"level_id": "traffic_m3_l03_right_order",
		"seed": 13,
		"width": 5, "height": 2, "staging_slots": 4,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}],
		},
		"stations": [{"id": "station_c", "accepted": ["COLOR_A", "COLOR_B"], "capacity": 0, "queue": "q_c",
			"cell": {"x": 4, "y": 0}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_c": ["p_a1", "p_b1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_c"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_c"},
		],
		"vehicles": [
			{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_c"},
			{"id": "v2", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_c"},
		],
	},
	{
		"level_id": "traffic_m3_l04_double_pickup",
		"seed": 14,
		"width": 6, "height": 3, "staging_slots": 4,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
		},
		"stations": [
			{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 0, "queue": "q_a",
				"cell": {"x": 5, "y": 0}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_b", "accepted": ["COLOR_B"], "capacity": 0, "queue": "q_b",
				"cell": {"x": 5, "y": 2}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_a": ["p_a1", "p_a2"], "q_b": ["p_b1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_a2", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_b"},
		],
		"vehicles": [
			{"id": "v1", "type": "van", "color": "COLOR_A", "capacity": 2,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"},
			{"id": "v2", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_v2", "station": "station_b"},
		],
	},
	{
		"level_id": "traffic_m3_l05_tight_parking",
		"seed": 15,
		"width": 6, "height": 3, "staging_slots": 1,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}],
			"route_v3": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
		},
		"stations": [{"id": "station_shared", "accepted": ["COLOR_A", "COLOR_B", "COLOR_C"],
			"capacity": 0, "queue": "q_shared",
			"cell": {"x": 5, "y": 1}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_shared": ["p_a1", "p_b1", "p_c1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_shared"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_shared"},
			{"id": "p_c1", "color": "COLOR_C", "station": "station_shared"},
		],
		"vehicles": [
			{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_shared"},
			{"id": "v2", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_shared"},
			{"id": "v3", "type": "compact", "color": "COLOR_C", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_v3", "station": "station_shared"},
		],
	},
	{
		"level_id": "traffic_m3_l06_the_blocker",
		"seed": 16,
		"width": 6, "height": 2, "staging_slots": 4,
		"paths": {
			"route_v1": [{"x": 2, "y": 1}, {"x": 2, "y": 0}, {"x": 3, "y": 0}, {"x": 4, "y": 0}],
			"route_v2": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}],
		},
		"stations": [
			{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 1, "queue": "q_a",
				"cell": {"x": 5, "y": 0}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_b", "accepted": ["COLOR_B"], "capacity": 1, "queue": "q_b",
				"cell": {"x": 5, "y": 1}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_a": ["p_a1"], "q_b": ["p_b1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_b"},
		],
		"vehicles": [
			{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 2, "y": 1}, "route": "route_v1", "station": "station_a"},
			{"id": "v2", "type": "truck", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_b"},
		],
	},
	{
		"level_id": "traffic_m3_l07_three_colors",
		"seed": 17,
		"width": 6, "height": 4, "staging_slots": 4,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
			"route_v3": [{"x": 0, "y": 3}, {"x": 1, "y": 3}, {"x": 2, "y": 3}],
		},
		"stations": [
			{"id": "station_a", "accepted": ["COLOR_A"], "capacity": 0, "queue": "q_a",
				"cell": {"x": 5, "y": 0}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_b", "accepted": ["COLOR_B"], "capacity": 0, "queue": "q_b",
				"cell": {"x": 5, "y": 2}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_c", "accepted": ["COLOR_C"], "capacity": 0, "queue": "q_c",
				"cell": {"x": 5, "y": 3}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_a": ["p_a1", "p_a2"], "q_b": ["p_b1"], "q_c": ["p_c1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_a2", "color": "COLOR_A", "station": "station_a"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_b"},
			{"id": "p_c1", "color": "COLOR_C", "station": "station_c"},
		],
		"vehicles": [
			{"id": "v1", "type": "van", "color": "COLOR_A", "capacity": 2,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_a"},
			{"id": "v2", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_v2", "station": "station_b"},
			{"id": "v3", "type": "compact", "color": "COLOR_C", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 3}, "route": "route_v3", "station": "station_c"},
		],
	},
	{
		"level_id": "traffic_m3_l08_no_room_to_wait",
		"seed": 18,
		"width": 6, "height": 3, "staging_slots": 0,
		"paths": {
			"route_v1": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}],
			"route_v2": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}],
			"route_v3": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}],
		},
		"stations": [{"id": "station_shared", "accepted": ["COLOR_A", "COLOR_B", "COLOR_C"],
			"capacity": 0, "queue": "q_shared",
			"cell": {"x": 5, "y": 1}, "footprint": {"width": 1, "height": 1}}],
		"queues": {"q_shared": ["p_a1", "p_b1", "p_c1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_shared"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_shared"},
			{"id": "p_c1", "color": "COLOR_C", "station": "station_shared"},
		],
		"vehicles": [
			{"id": "v1", "type": "compact", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 0}, "route": "route_v1", "station": "station_shared"},
			{"id": "v2", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_v2", "station": "station_shared"},
			{"id": "v3", "type": "compact", "color": "COLOR_C", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_v3", "station": "station_shared"},
		],
	},
	{
		"level_id": "traffic_m3_l09_multi_step",
		"seed": 19,
		"width": 6, "height": 4, "staging_slots": 2,
		"paths": {
			"route_block": [{"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}],
			"route_vb": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}],
			"route_vc": [{"x": 0, "y": 3}, {"x": 1, "y": 3}, {"x": 2, "y": 3}],
		},
		"stations": [
			{"id": "station_ab", "accepted": ["COLOR_A", "COLOR_B"], "capacity": 0, "queue": "q_ab",
				"cell": {"x": 5, "y": 0}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_c", "accepted": ["COLOR_C"], "capacity": 1, "queue": "q_c",
				"cell": {"x": 5, "y": 3}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_ab": ["p_a1", "p_b1"], "q_c": ["p_c1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_ab"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_ab"},
			{"id": "p_c1", "color": "COLOR_C", "station": "station_c"},
		],
		"vehicles": [
			{"id": "v_block", "type": "van", "color": "COLOR_A", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 2, "y": 1}, "route": "route_block", "station": "station_ab"},
			{"id": "v_b", "type": "compact", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_vb", "station": "station_ab"},
			{"id": "v_c", "type": "compact", "color": "COLOR_C", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 3}, "route": "route_vc", "station": "station_c"},
		],
	},
	{
		"level_id": "traffic_m3_l10_rush_hour",
		"seed": 20,
		"width": 7, "height": 4, "staging_slots": 1,
		"paths": {
			"route_block": [{"x": 3, "y": 1}, {"x": 4, "y": 1}, {"x": 5, "y": 1}],
			"route_vb": [{"x": 0, "y": 1}, {"x": 1, "y": 1}, {"x": 2, "y": 1}, {"x": 3, "y": 1}, {"x": 4, "y": 1}, {"x": 5, "y": 1}],
			"route_vc": [{"x": 0, "y": 2}, {"x": 1, "y": 2}, {"x": 2, "y": 2}, {"x": 3, "y": 2}],
			"route_vd": [{"x": 0, "y": 3}, {"x": 1, "y": 3}, {"x": 2, "y": 3}],
		},
		"stations": [
			{"id": "station_main", "accepted": ["COLOR_A", "COLOR_B", "COLOR_C"],
				"capacity": 0, "queue": "q_main",
				"cell": {"x": 6, "y": 1}, "footprint": {"width": 1, "height": 1}},
			{"id": "station_d", "accepted": ["COLOR_D"], "capacity": 1, "queue": "q_d",
				"cell": {"x": 6, "y": 3}, "footprint": {"width": 1, "height": 1}},
		],
		"queues": {"q_main": ["p_a1", "p_b1", "p_c1"], "q_d": ["p_d1"]},
		"passengers": [
			{"id": "p_a1", "color": "COLOR_A", "station": "station_main"},
			{"id": "p_b1", "color": "COLOR_B", "station": "station_main"},
			{"id": "p_c1", "color": "COLOR_C", "station": "station_main"},
			{"id": "p_d1", "color": "COLOR_D", "station": "station_d"},
		],
		"vehicles": [
			{"id": "v_block", "type": "truck", "color": "COLOR_A", "capacity": 2,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 3, "y": 1}, "route": "route_block", "station": "station_main"},
			{"id": "v_b", "type": "van", "color": "COLOR_B", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 1}, "route": "route_vb", "station": "station_main"},
			{"id": "v_c", "type": "compact", "color": "COLOR_C", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 2}, "route": "route_vc", "station": "station_main"},
			{"id": "v_d", "type": "compact", "color": "COLOR_D", "capacity": 1,
				"footprint": {"width": 1, "height": 1},
				"cell": {"x": 0, "y": 3}, "route": "route_vd", "station": "station_d"},
		],
	},
]


static func count() -> int:
	return DEFINITIONS.size()


## Deep copy so callers can never mutate the catalogue.
static func definition(level_index: int) -> Dictionary:
	if level_index < 0 or level_index >= DEFINITIONS.size():
		return {}
	return DEFINITIONS[level_index].duplicate(true)


static func level_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in DEFINITIONS:
		ids.append(StringName(str(entry.get("level_id", ""))))
	return ids


static func level_id(level_index: int) -> StringName:
	var entry := definition(level_index)
	return StringName(str(entry.get("level_id", "")))


static func index_of(level_id_value: StringName) -> int:
	for index in DEFINITIONS.size():
		if str(DEFINITIONS[index].get("level_id", "")) == String(level_id_value):
			return index
	return -1


## Catalogue-level integrity check: every definition must pass factory
## validation AND build (build catches overlapping footprints and other
## placement failures that validation does not cover).
static func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	if DEFINITIONS.size() != LEVEL_COUNT:
		errors.append("catalogue_size:%d" % DEFINITIONS.size())
	var seen_ids := {}
	for index in DEFINITIONS.size():
		var entry := DEFINITIONS[index]
		var level_id_value := str(entry.get("level_id", ""))
		if level_id_value.is_empty():
			errors.append("level_missing_id:%d" % index)
		elif seen_ids.has(level_id_value):
			errors.append("duplicate_level_id:%s" % level_id_value)
		seen_ids[level_id_value] = true
		for error in TrafficGameFactory.validate_definition(entry):
			errors.append("%s:%s" % [level_id_value, error])
		if TrafficGameFactory.build(entry) == null:
			errors.append("%s:build_failed" % level_id_value)
	return errors
