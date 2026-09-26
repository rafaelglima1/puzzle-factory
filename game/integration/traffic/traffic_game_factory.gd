class_name TrafficGameFactory
extends RefCounted
## PRODUCT INTEGRATION LAYER (Traffic) — OWNER: AGENT-1.
##
## This is the only place (besides [TrafficPresentationAdapter]) where Traffic
## vocabulary is allowed. It composes generic core concepts into a Traffic
## puzzle setup; it never re-implements rules, and no generic code knows these
## words (see ADR-013).
##
## Terminology mapping (composition, not subclassing):
##   generic Entity      -> Traffic vehicle
##   generic Item        -> Traffic passenger
##   generic Destination -> Traffic station / loading area
##   generic StagingArea -> Traffic waiting / holding area
##   generic LogicalPath -> Traffic route of a vehicle
##
## Definition format (dictionary; see docs/ARCHITECTURE.md §4):
## {
##   "level_id": "traffic_001",          # required
##   "seed": 7,                          # optional (default 0)
##   "width": 5, "height": 4,            # required board size in cells
##   "staging_slots": 4,                 # optional (default 4)
##   "paths": { "route_v1": [ {x,y}, ... ] },
##   "stations": [ { "id": "station_a", "accepted": ["COLOR_A"], "capacity": 2,
##                   "queue": "q_a", "cell": {x,y}, "footprint": {w,h} } ],
##   "queues": { "q_a": ["passenger_1", ...] },      # array order = FIFO
##   "passengers": [ { "id": "passenger_1", "color": "COLOR_A",
##                     "station": "station_a", "type": "passenger_standard" } ],
##   "vehicles": [ { "id": "v1", "type": "compact", "color": "COLOR_A",
##                   "capacity": 2, "cell": {x,y}, "footprint": {w,h},
##                   "route": "route_v1", "station": "station_a" } ],
##   "objectives": [ { "id": "clear_all", "type": "clear_all", "mandatory": true } ]  # optional, defaults to clear_all
## }
##
## Station cell/footprint are presentation anchors; they are stored in the
## generic Destination metadata (free-form, primitive) so presentation can be
## rebuilt without core knowing anything about stations.

const VEHICLE_MOVEMENT_TYPE := &"path"
const DEFAULT_PASSENGER_TYPE := &"passenger_standard"
const DEFAULT_STATION_TYPE := &"station"
const DEFAULT_VEHICLE_FOOTPRINT_WIDTH := 2
const DEFAULT_VEHICLE_FOOTPRINT_HEIGHT := 1


## Returns validation errors; empty result means the definition can be built.
static func validate_definition(definition: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(definition) != TYPE_DICTIONARY:
		errors.append("definition_not_a_dictionary")
		return errors
	if str(definition.get("level_id", "")).is_empty():
		errors.append("missing_level_id")

	var dimensions := BoardDimensions.new(int(definition.get("width", 0)), int(definition.get("height", 0)))
	if not dimensions.is_valid():
		errors.append("invalid_board_dimensions")

	if int(definition.get("staging_slots", StagingArea.DEFAULT_SLOT_COUNT)) < 0:
		errors.append("invalid_staging_slots")

	var queues: Variant = definition.get("queues", {})
	if typeof(queues) != TYPE_DICTIONARY:
		errors.append("queues_not_a_dictionary")
		queues = {}

	var passengers: Variant = definition.get("passengers", [])
	if typeof(passengers) != TYPE_ARRAY:
		errors.append("passengers_not_an_array")
		passengers = []
	var passenger_ids := {}
	for passenger in passengers:
		if typeof(passenger) != TYPE_DICTIONARY:
			errors.append("passenger_not_a_dictionary")
			continue
		var passenger_id := str(passenger.get("id", ""))
		if passenger_id.is_empty():
			errors.append("passenger_missing_id")
			continue
		if passenger_ids.has(passenger_id):
			errors.append("duplicate_passenger_id:%s" % passenger_id)
			continue
		passenger_ids[passenger_id] = true
		if str(passenger.get("color", "")).is_empty():
			errors.append("passenger_missing_color:%s" % passenger_id)

	# Queues must reference known passengers and must not share items.
	var queued_items := {}
	for queue_id in queues:
		var queue_items: Variant = queues[queue_id]
		if typeof(queue_items) != TYPE_ARRAY:
			errors.append("queue_items_not_an_array:%s" % queue_id)
			continue
		for item_id_value in queue_items:
			var item_id := str(item_id_value)
			if not passenger_ids.has(item_id):
				errors.append("queue_unknown_passenger:%s" % item_id)
			if queued_items.has(item_id):
				errors.append("passenger_in_multiple_queues:%s" % item_id)
			queued_items[item_id] = true
	for passenger_id in passenger_ids.keys():
		if not queued_items.has(passenger_id):
			errors.append("unreferenced_passenger:%s" % passenger_id)

	var stations: Variant = definition.get("stations", [])
	if typeof(stations) != TYPE_ARRAY or (stations as Array).is_empty():
		errors.append("stations_missing")
		stations = []
	var station_ids := {}
	for station in stations:
		if typeof(station) != TYPE_DICTIONARY:
			errors.append("station_not_a_dictionary")
			continue
		var station_id := str(station.get("id", ""))
		if station_id.is_empty():
			errors.append("station_missing_id")
			continue
		if station_ids.has(station_id):
			errors.append("duplicate_station_id:%s" % station_id)
			continue
		station_ids[station_id] = true
		if int(station.get("capacity", 0)) < 0:
			errors.append("invalid_station_capacity:%s" % station_id)
		var queue_id := str(station.get("queue", ""))
		if queue_id.is_empty():
			errors.append("station_missing_queue:%s" % station_id)
		elif not queues.has(queue_id):
			errors.append("station_unknown_queue:%s" % station_id)
		var accepted: Variant = station.get("accepted", [])
		if typeof(accepted) != TYPE_ARRAY or (accepted as Array).is_empty():
			errors.append("station_missing_accepted_keys:%s" % station_id)

	var routes: Variant = definition.get("paths", {})
	if typeof(routes) != TYPE_DICTIONARY:
		errors.append("paths_not_a_dictionary")
		routes = {}

	var vehicles: Variant = definition.get("vehicles", [])
	if typeof(vehicles) != TYPE_ARRAY or (vehicles as Array).is_empty():
		errors.append("vehicles_missing")
		vehicles = []
	var vehicle_ids := {}
	for vehicle in vehicles:
		if typeof(vehicle) != TYPE_DICTIONARY:
			errors.append("vehicle_not_a_dictionary")
			continue
		var vehicle_id := str(vehicle.get("id", ""))
		if vehicle_id.is_empty():
			errors.append("vehicle_missing_id")
			continue
		if vehicle_ids.has(vehicle_id):
			errors.append("duplicate_vehicle_id:%s" % vehicle_id)
			continue
		vehicle_ids[vehicle_id] = true
		if str(vehicle.get("type", "")).is_empty():
			errors.append("vehicle_missing_type:%s" % vehicle_id)
		if str(vehicle.get("color", "")).is_empty():
			errors.append("vehicle_missing_color:%s" % vehicle_id)
		var capacity := int(vehicle.get("capacity", 0))
		if capacity < 1:
			errors.append("vehicle_invalid_capacity:%s" % vehicle_id)
		var station_id := str(vehicle.get("station", ""))
		if not station_ids.has(station_id):
			errors.append("vehicle_unknown_station:%s" % vehicle_id)
		var route_id := str(vehicle.get("route", ""))
		if not routes.has(route_id):
			errors.append("vehicle_unknown_route:%s" % vehicle_id)
			continue
		var cell := GridPosition.from_dictionary(vehicle.get("cell", {}))
		var footprint := _vehicle_footprint(vehicle)
		if not dimensions.contains_footprint(footprint, cell):
			errors.append("vehicle_out_of_bounds:%s" % vehicle_id)
			continue
		var route := _route_from_definition(routes[route_id])
		if not route.validate(dimensions).is_empty():
			errors.append("vehicle_invalid_route:%s" % vehicle_id)
			continue
		if not route.origin().equals(cell):
			errors.append("vehicle_route_start_mismatch:%s" % vehicle_id)

	var objectives: Variant = definition.get("objectives", [])
	if typeof(objectives) != TYPE_ARRAY:
		errors.append("objectives_not_an_array")
		objectives = []
	var objective_ids := {}
	for objective in objectives:
		if typeof(objective) != TYPE_DICTIONARY:
			errors.append("objective_not_a_dictionary")
			continue
		var objective_id := str(objective.get("id", ""))
		if objective_id.is_empty():
			errors.append("objective_missing_id")
			continue
		if objective_ids.has(objective_id):
			errors.append("duplicate_objective_id:%s" % objective_id)
			continue
		objective_ids[objective_id] = true
		var objective_type := StringName(str(objective.get("type", "")))
		if not ObjectiveFactory.is_known_type(objective_type):
			errors.append("unknown_objective_type:%s" % objective_id)
	return errors


## Builds a ready-to-play simulation, or null when the definition is invalid.
static func build(definition: Dictionary) -> Simulation:
	var errors := validate_definition(definition)
	if not errors.is_empty():
		push_error("TrafficGameFactory rejected definition: %s" % ", ".join(errors))
		return null

	var dimensions := BoardDimensions.new(int(definition["width"]), int(definition["height"]))
	var state := GameState.new(StringName(str(definition["level_id"])), int(definition.get("seed", 0)), dimensions)
	state.staging = StagingArea.new(int(definition.get("staging_slots", StagingArea.DEFAULT_SLOT_COUNT)))

	# Routes.
	for route_id in definition.get("paths", {}):
		var route := _route_from_definition(definition["paths"][route_id])
		route.id = StringName(str(route_id))
		state.add_path(route)

	# Stations (generic destinations) with presentation anchors in metadata.
	for station in definition.get("stations", []):
		var destination := Destination.new(StringName(str(station["id"])), StringName(str(station.get("type", DEFAULT_STATION_TYPE))))
		for color_key in station.get("accepted", []):
			destination.accepted_color_keys.append(StringName(str(color_key)))
		destination.capacity = int(station.get("capacity", 0))
		destination.queue_id = StringName(str(station.get("queue", "")))
		destination.metadata = Serialization.canonicalize({
			"cell": GridPosition.from_dictionary(station.get("cell", {})).to_dictionary(),
			"footprint": _footprint_dictionary(station.get("footprint", {})),
		})
		state.add_destination(destination)

	# Passengers (generic items) and their queues (FIFO order preserved).
	for queue_id in definition.get("queues", {}):
		var queue := ItemQueue.new(StringName(str(queue_id)))
		for item_id_value in definition["queues"][queue_id]:
			queue.enqueue(StringName(str(item_id_value)))
		state.add_queue(queue)

	for passenger in definition.get("passengers", []):
		var item := Item.new(
			StringName(str(passenger["id"])),
			StringName(str(passenger.get("type", DEFAULT_PASSENGER_TYPE))),
			StringName(str(passenger.get("color", "")))
		)
		item.destination_id = StringName(str(passenger.get("station", "")))
		state.add_item(item)

	# Vehicles (generic entities) placed on the board.
	for vehicle in definition.get("vehicles", []):
		var entity := Entity.new(
			StringName(str(vehicle["id"])),
			StringName(str(vehicle["type"])),
			_vehicle_footprint(vehicle)
		)
		entity.color_key = StringName(str(vehicle["color"]))
		entity.capacity = int(vehicle["capacity"])
		entity.movement_type = VEHICLE_MOVEMENT_TYPE
		entity.path_id = StringName(str(vehicle["route"]))
		entity.destination_id = StringName(str(vehicle["station"]))
		entity.metadata = Serialization.canonicalize({"origin": "traffic"})
		var cell := GridPosition.from_dictionary(vehicle.get("cell", {}))
		if not state.board.place_entity(entity, cell):
			push_error("TrafficGameFactory could not place vehicle '%s'" % entity.id)
			return null
		state.add_entity(entity)

	# Objectives (default: clear_all).
	var objectives: Variant = definition.get("objectives", [])
	if typeof(objectives) != TYPE_ARRAY or (objectives as Array).is_empty():
		state.add_objective(ClearAllObjective.new(&"clear_all", true))
	else:
		for objective in objectives:
			state.add_objective(ObjectiveFactory.create(
				StringName(str(objective.get("type", ""))),
				StringName(str(objective.get("id", ""))),
				bool(objective.get("mandatory", true))
			))

	return Simulation.new(state)


## Maps a generic state back to Traffic view models for presentation.
## Implemented by [TrafficPresentationAdapter]; kept here as documentation of
## the composition boundary.

static func _vehicle_footprint(vehicle: Dictionary) -> Footprint:
	var footprint: Variant = vehicle.get("footprint", null)
	if typeof(footprint) != TYPE_DICTIONARY:
		return Footprint.new(DEFAULT_VEHICLE_FOOTPRINT_WIDTH, DEFAULT_VEHICLE_FOOTPRINT_HEIGHT)
	return Footprint.from_dictionary(footprint)


static func _footprint_dictionary(footprint: Variant) -> Dictionary:
	if typeof(footprint) != TYPE_DICTIONARY:
		return {"width": 2, "height": 2}
	return Footprint.from_dictionary(footprint).to_dictionary()


static func _route_from_definition(cells_data: Variant) -> LogicalPath:
	var route := LogicalPath.new()
	if typeof(cells_data) != TYPE_ARRAY:
		return route
	for cell in cells_data:
		route.cells.append(GridPosition.from_dictionary(cell))
	return route
