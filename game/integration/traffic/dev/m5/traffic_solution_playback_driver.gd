class_name TrafficSolutionPlaybackDriver
extends RefCounted
## M5 CROSS-INTEGRATION solution playback driver — OWNER: M5-INTEGRATOR.
##
## An INTEGRATION object: it may know `LevelDefinition`, the Traffic adapter,
## `Simulation` and `DispatchEntityCommand`, because it bridges AGENT-1's real
## simulation to AGENT-2's playback controller. The Level Lab / playback
## controller never gain those imports.
##
## It plays back ALREADY-SUPPLIED commands only: it never solves, validates or
## decides legality. Every command runs through the REAL simulation; a rejected
## command does not advance logical state and is reported as not accepted.

const Adapter := preload("res://integration/traffic/levels/traffic_level_definition_adapter.gd")

var _definition: LevelDefinition = null
var _simulation: Simulation = null
var _applied_count := 0
var _last_command: Dictionary = {}
var _last_accepted := false


static func for_definition(definition: LevelDefinition) -> TrafficSolutionPlaybackDriver:
	return TrafficSolutionPlaybackDriver.new(definition)


func _init(definition: LevelDefinition = null) -> void:
	_definition = definition
	reset()


## Rebuilds a fresh simulation from the original definition. Deterministic and
## idempotent: repeated resets yield the identical initial logical state.
func reset() -> void:
	_applied_count = 0
	_last_command = {}
	_last_accepted = false
	_simulation = null
	if _definition != null:
		_simulation = Adapter.build_simulation(_definition)


## Executes ONE normalized command (`{ type, entity_id }`, tolerating the
## AGENT-1 `entityId` spelling) through the real simulation. Returns true when
## the real command was accepted; a rejected/blocked/no-op command never
## advances logical state.
func execute(command: Dictionary) -> bool:
	_last_command = command
	_last_accepted = false
	if _simulation == null:
		return false
	var entity_id := ""
	if command.has("entity_id"):
		entity_id = str(command["entity_id"])
	elif command.has("entityId"):
		entity_id = str(command["entityId"])
	if entity_id.is_empty():
		return false
	var result := _simulation.execute(DispatchEntityCommand.new(StringName(entity_id)))
	_last_accepted = result != null and result.is_success()
	if _last_accepted:
		_applied_count += 1
	return _last_accepted


## Authoritative logical snapshot (never exposes mutable Simulation internals).
func snapshot() -> Dictionary:
	if _simulation == null:
		return {}
	return _simulation.snapshot()


func is_ready() -> bool:
	return _simulation != null


func is_won() -> bool:
	if _simulation == null:
		return false
	return _simulation.get_state().is_won()


func is_lost() -> bool:
	if _simulation == null:
		return false
	return _simulation.get_state().is_lost()


func applied_count() -> int:
	return _applied_count


func last_result() -> Dictionary:
	return {"command": _last_command.duplicate(), "accepted": _last_accepted}


func move_index() -> int:
	if _simulation == null:
		return 0
	return _simulation.get_state().move_index
