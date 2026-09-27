class_name M3LevelCatalogue
extends RefCounted
## M3 level catalogue — OWNER: AGENT-1.
##
## M5 CUTOVER: this class no longer owns level data. The official content pack
## (`res://content/levels/traffic/pack_001/`) is the single source of truth, and
## this is now a thin COMPATIBILITY FACADE over [TrafficLevelCatalogue] +
## [LevelValidator] so existing M3/M4 callers (session, tests, integration)
## keep their stable API without a second hardcoded copy of the ten levels.
##
## The previous hardcoded `DEFINITIONS` array has been removed deliberately: two
## authorities (JSON files + dictionaries) would silently diverge.
##
## API preserved (M3 callers):
##   count(), definition(level_index), level_ids(), level_id(level_index),
##   index_of(level_id), validate_all()
## Semantics: `definition(index)` returns the TrafficGameFactory-compatible
## dictionary (the adapter output), exactly as before.

const LEVEL_COUNT := 10


static func count() -> int:
	return TrafficLevelCatalogue.count()


static func level_ids() -> Array[StringName]:
	return TrafficLevelCatalogue.level_ids()


static func level_id(level_index: int) -> StringName:
	return TrafficLevelCatalogue.level_id(level_index)


static func index_of(level_id_value: StringName) -> int:
	return TrafficLevelCatalogue.index_of(level_id_value)


## TrafficGameFactory-compatible dictionary for [param level_index] (empty when
## the level is missing or invalid). Backed by the official content pack through
## the M5 adapter; never hardcoded here.
static func definition(level_index: int) -> Dictionary:
	var generic := TrafficLevelCatalogue.load_definition(level_index)
	if generic == null:
		return {}
	return TrafficLevelDefinitionAdapter.to_traffic_definition(generic)


## External V1 schema dictionary (the official file payload as parsed).
static func schema_definition(level_index: int) -> Dictionary:
	return TrafficLevelCatalogue.definition_dictionary(level_index)


## Full integrity check over the official pack (ten levels, unique ids, every
## level loads and passes the static validator).
static func validate_all() -> PackedStringArray:
	return TrafficLevelCatalogue.validate_all()
