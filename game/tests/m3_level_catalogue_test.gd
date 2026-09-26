extends "res://tests/framework/test_base.gd"
## M3 level catalogue integrity: ten buildable, uniquely identified levels.


func run() -> void:
	_catalogue_shape()
	_definitions_are_independent_copies()
	_every_level_builds()
	_id_lookup()


func _catalogue_shape() -> void:
	check_eq(M3LevelCatalogue.count(), 10, "catalogue holds exactly ten levels")
	check_eq(M3LevelCatalogue.count(), M3LevelCatalogue.LEVEL_COUNT, "declared count matches the data")
	check_eq(M3LevelCatalogue.validate_all().size(), 0, "catalogue validates and builds (%s)" % ", ".join(M3LevelCatalogue.validate_all()))
	var ids := M3LevelCatalogue.level_ids()
	check_eq(ids.size(), 10, "ten level ids")
	var unique := {}
	for level_id in ids:
		check(not String(level_id).is_empty(), "level id is not empty")
		check(not unique.has(String(level_id)), "level id '%s' is unique" % level_id)
		unique[String(level_id)] = true


func _definitions_are_independent_copies() -> void:
	var original_width := int(M3LevelCatalogue.definition(0).get("width", 0))
	var first := M3LevelCatalogue.definition(0)
	first["width"] = 999
	first["stations"] = []
	check_eq(
		int(M3LevelCatalogue.definition(0).get("width", 0)),
		original_width,
		"mutating a returned definition does not corrupt the catalogue"
	)
	check(M3LevelCatalogue.definition(0).get("stations", []).size() > 0, "catalogue data stays intact")


func _every_level_builds() -> void:
	for index in M3LevelCatalogue.count():
		var definition := M3LevelCatalogue.definition(index)
		var level_id := str(definition.get("level_id", ""))
		check(
			TrafficGameFactory.validate_definition(definition).is_empty(),
			"level %d (%s) passes factory validation" % [index, level_id]
		)
		var simulation := TrafficGameFactory.build(definition)
		check(simulation != null, "level %d (%s) builds" % [index, level_id])
		if simulation == null:
			continue
		var state := simulation.get_state()
		check_eq(state.level_id, StringName(level_id), "level id survives the build")
		check(not state.is_won(), "level %d does not start already won" % index)
		check(not state.is_lost(), "level %d does not start already lost" % index)
		check_eq(state.entity_count() > 0, true, "level %d has vehicles" % index)
		check_eq(state.objectives.size(), 1, "level %d has the default clear_all objective" % index)
		check_eq(state.staging.slot_count, int(definition.get("staging_slots", 4)), "level %d honours staging_slots" % index)
		check(state.items.size() > 0, "level %d has passengers to carry" % index)


func _id_lookup() -> void:
	for index in M3LevelCatalogue.count():
		var level_id := M3LevelCatalogue.level_id(index)
		check_eq(M3LevelCatalogue.index_of(level_id), index, "index_of roundtrips for %s" % level_id)
	check_eq(M3LevelCatalogue.index_of(&"not_a_level"), -1, "unknown level id is not found")
	check_eq(M3LevelCatalogue.definition(-1).size(), 0, "negative index returns an empty definition")
	check_eq(M3LevelCatalogue.definition(10).size(), 0, "index beyond the catalogue returns an empty definition")
	check_eq(M3LevelCatalogue.level_id(-1), &"", "level_id of an invalid index is empty")
