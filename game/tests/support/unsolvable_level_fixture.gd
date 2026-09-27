extends RefCounted
## Test-only fixture: a STATICALLY VALID level that cannot be won.
##
## It is a real Traffic composition (two entities, one destination, one queued
## item) that passes [LevelValidator] but dead-ends logically:
## - the destination holds a single item accepted only by entity A;
## - both entities route to that single destination and share the accepted key;
## - the staging area has zero slots, so whichever entity arrives without a
##   matching front item is staged and immediately loses (staging_full);
## - entity B can never load the one item (A consumes it, or B is first and
##   stages), so CLEAR_ALL can never be satisfied.
##
## This distinguishes INVALID (validator) from UNSOLVABLE (solver).

const LEVEL_ID := &"m5_unsolvable_fixture"


static func build_definition() -> LevelDefinition:
	var data := {
		"schemaVersion": LevelDefinition.SCHEMA_VERSION,
		"levelId": String(LEVEL_ID),
		"revision": 1,
		"seed": 99,
		"themeId": "traffic",
		"board": {"width": 4, "height": 1},
		"paths": [
			{"id": "route_a", "cells": [{"x": 0, "y": 0}, {"x": 1, "y": 0}, {"x": 2, "y": 0}]},
			{"id": "route_b", "cells": [{"x": 1, "y": 0}, {"x": 2, "y": 0}, {"x": 3, "y": 0}]},
		],
		# Two entities cannot both start on the route; A starts at (0,0) and B at
		# (1,0), each the origin of its own path (validator requirement). They
		# share a destination whose queue holds ONE item.
		"entities": [
			{"id": "ent_a", "type": "compact", "colorKey": "COLOR_A", "capacity": 1,
				"position": {"x": 0, "y": 0}, "footprint": {"width": 1, "height": 1},
				"pathId": "route_a", "destinationId": "dest_shared"},
			{"id": "ent_b", "type": "compact", "colorKey": "COLOR_A", "capacity": 1,
				"position": {"x": 1, "y": 0}, "footprint": {"width": 1, "height": 1},
				"pathId": "route_b", "destinationId": "dest_shared"},
		],
		"items": [
			{"id": "item_a", "type": "standard", "colorKey": "COLOR_A", "destinationId": "dest_shared"},
		],
		"queues": [
			{"id": "queue_shared", "itemIds": ["item_a"]},
		],
		"destinations": [
			{"id": "dest_shared", "type": "default", "acceptedKeys": ["COLOR_A"], "capacity": 1,
				"queueId": "queue_shared", "position": {"x": 3, "y": 0},
				"footprint": {"width": 1, "height": 1}},
		],
		"staging": {"slots": 0},
		"objectives": [{"id": "clear_all", "type": "CLEAR_ALL", "mandatory": true}],
		"allowedBoosters": [],
		"difficultyTarget": null,
		"tags": [],
	}
	return LevelDefinition.from_dictionary(data)
