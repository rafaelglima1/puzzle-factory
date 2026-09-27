class_name TrafficLevelLabController
extends RefCounted
## M5 CROSS-INTEGRATION controller — OWNER: M5-INTEGRATOR.
##
## Builds AGENT-2's Level Lab from the REAL official content pack and drives real
## solution playback through the real simulation:
##
##   manifest -> LevelLoader -> LevelDefinition -> LevelValidator
##            -> TrafficSolverDomain -> BfsSolver -> SolverResult
##            -> TrafficLevelLabAdapter -> plain DTO -> Level Lab
##
## Playback:
##   solver commands -> Level Lab playback controller
##            -> TrafficSolutionPlaybackDriver -> real Simulation
##
## The Level Lab receives only plain dictionaries. This controller is dev-only:
## `debug_enabled` gates everything, and it is never referenced by production
## navigation or `run/main_scene`.

const Adapter := preload("res://integration/traffic/dev/m5/traffic_level_lab_adapter.gd")
const Driver := preload("res://integration/traffic/dev/m5/traffic_solution_playback_driver.gd")

var debug_enabled: bool = OS.is_debug_build()

var _lab: Variant = null
var _driver: Variant = null
var _entries: Array = []
var _definitions: Array = []
var _index := 0
var _loaded := false


func _init(lab: Variant = null) -> void:
	_lab = lab


## True when the controller may drive a lab. Without a lab (headless tests) the
## data path still works; `feed_lab` simply has nowhere to push.
func is_enabled() -> bool:
	return debug_enabled


func level_count() -> int:
	return _entries.size()


func current_index() -> int:
	return _index


func current_level_id() -> StringName:
	if _index < 0 or _index >= _definitions.size():
		return &""
	return _definitions[_index].level_id


func get_driver() -> Variant:
	return _driver


# --- build --------------------------------------------------------------------

## Loads, validates and solves all official levels in manifest order, adapts them
## to the Level Lab contract, and (when enabled and a lab is present) feeds the
## lab. Returns the number of official levels loaded. Never touches sample data.
func load_official_levels() -> int:
	_entries.clear()
	_definitions.clear()
	var count := TrafficLevelCatalogue.count()
	for index in count:
		var load_result := TrafficLevelCatalogue.load_load_result(index)
		if not load_result.is_ok():
			continue
		var definition := load_result.definition
		var validation := Adapter.validation_to_contract(LevelValidator.validate(definition))
		var solver_result := BfsSolver.new().solve(TrafficSolverDomain.for_definition(definition))
		var solver := Adapter.solver_to_contract(solver_result)
		var preview := Adapter.definition_to_preview(definition)
		_entries.append(Adapter.build_lab_entry(preview, validation, solver))
		_definitions.append(definition)
	_loaded = true
	_index = 0
	if _entries.is_empty():
		return 0
	_apply_current()
	return _entries.size()


## Feeds the built entries to the attached lab (no-op without a lab or when the
## debug gate is off). Returns false when the lab refused the content.
func feed_lab() -> bool:
	if _lab == null or _entries.is_empty():
		return false
	if not debug_enabled:
		return false
	# The lab keeps (and may mutate) the array it is given while refreshing
	# runtime state. Hand it a defensive copy so the controller's authoritative
	# entries — including their validation/solver payloads — can never be
	# replaced by a preview-only refresh slot.
	return bool(_lab.call("show_levels", _entries.duplicate(true), _index))


# --- navigation ---------------------------------------------------------------

func select_index(index: int) -> bool:
	if index < 0 or index >= _entries.size():
		return false
	_index = index
	_apply_current()
	return true


func next() -> bool:
	return select_index(_index + 1)


func previous() -> bool:
	return select_index(_index - 1)


# --- playback -----------------------------------------------------------------

## Builds a fresh playback driver for the current level and installs it into the
## lab. Must be called after a level switch so no stale driver/step survives.
func prepare_playback() -> Variant:
	if _index < 0 or _index >= _definitions.size():
		_driver = null
		return null
	_driver = Driver.for_definition(_definitions[_index])
	if _lab != null and debug_enabled:
		_lab.call("set_playback_driver", _driver)
	return _driver


func play_all() -> int:
	if _driver == null:
		return 0
	if _lab == null:
		return 0
	var applied := int(_lab.call("play_solution"))
	refresh_visual_state()
	return applied


func step_once() -> bool:
	if _driver == null or _lab == null:
		return false
	var stepped := bool(_lab.call("step_solution"))
	refresh_visual_state()
	return stepped


func reset_playback() -> void:
	if _lab == null:
		return
	_lab.call("reset_preview")
	refresh_visual_state()


# --- visual refresh -----------------------------------------------------------

## Pushes the driver's latest authoritative snapshot back into the Level Lab as
## an updated preview, WITHOUT resetting solver metrics, the command list or the
## current playback step. The lab's `refresh_runtime_preview` re-renders the
## board/runtime debug data only.
func refresh_visual_state() -> void:
	if _lab == null or _driver == null:
		return
	var preview := _runtime_preview()
	if preview.is_empty():
		return
	_lab.call("refresh_runtime_preview", preview)


## Builds the live preview: the original definition mapping with entity/item/
## queue/destination state replaced by the driver's authoritative snapshot. The
## mapping stays in the adapter; only the dynamic values are overlaid here.
func _runtime_preview() -> Dictionary:
	if _index < 0 or _index >= _definitions.size() or _driver == null:
		return {}
	var snapshot: Dictionary = _driver.snapshot()
	if snapshot.is_empty():
		return {}
	var preview: Dictionary = Adapter.definition_to_preview(_definitions[_index])
	_overlay_snapshot(preview, snapshot)
	return preview


## Overlays authoritative dynamic state on the static preview. Entities that
## left the board (completed/staged) are dropped; destinations/queues reflect
## the real occupancy and remaining queue contents.
func _overlay_snapshot(preview: Dictionary, snapshot: Dictionary) -> void:
	var placements := {}
	for placement in snapshot.get("board", {}).get("placements", []):
		placements[str(placement.get("entity_id", ""))] = placement

	var live_entities: Array = []
	for entity in preview.get("entities", []):
		var entity_id := str(entity.get("id", ""))
		if placements.has(entity_id):
			var placement: Dictionary = placements[entity_id]
			var live: Dictionary = entity.duplicate(true)
			live["cell"] = placement.get("position", entity.get("cell", {"x": 0, "y": 0}))
			live["footprint"] = placement.get("footprint", entity.get("footprint", {"width": 1, "height": 1}))
			live_entities.append(live)
	preview["entities"] = live_entities

	# Live item registry: keep only items still present.
	var live_items := {}
	for item in snapshot.get("items", []):
		live_items[str(item.get("id", ""))] = item

	# Live queue contents (ordered) + destination queue color keys.
	var queue_items := {}
	for queue in snapshot.get("queues", []):
		var ids: Array = []
		for item_id in queue.get("item_ids", []):
			if live_items.has(str(item_id)):
				ids.append(str(item_id))
		queue_items[str(queue.get("id", ""))] = ids

	for queue in preview.get("queues", []):
		queue["itemIds"] = queue_items.get(str(queue.get("id", "")), [])

	var destination_by_id := {}
	for destination in snapshot.get("destinations", []):
		destination_by_id[str(destination.get("id", ""))] = destination

	for destination in preview.get("destinations", []):
		var live_destination: Variant = destination_by_id.get(str(destination.get("id", "")))
		if live_destination == null:
			continue
		destination["occupancy"] = int(live_destination.get("processed_count", 0))
		var queue_id := str(destination.get("queueId", ""))
		var color_keys: Array = []
		for item_id in queue_items.get(queue_id, []):
			color_keys.append(str(live_items[item_id].get("color_key", "")))
		destination["queue"] = color_keys


# --- internals ----------------------------------------------------------------

func _apply_current() -> void:
	if _lab == null or not debug_enabled:
		return
	# Re-feeding the whole list at the new index resets held validation/solver/
	# playback for the selected level, so PREV/NEXT never shows stale data.
	_lab.call("show_levels", _entries.duplicate(true), _index)
	prepare_playback()
	refresh_visual_state()
