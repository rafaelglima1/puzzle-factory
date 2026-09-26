class_name CommandResult
extends RefCounted
## Outcome of a [GameCommand] execution (blueprint §12).
##
## [enum Status] is a superset of the blueprint result set
## (SUCCESS / BLOCKED / INVALID / GAME_ALREADY_COMPLETE) with two finer
## rejection codes used by M1 validation:
## - OUT_OF_BOUNDS: target footprint leaves the board.
## - INVALID_STATE: entity/board is not in a state where the command applies.
##
## Rejection event rule (M1):
## - status BLOCKED emits exactly one [constant DomainEvent.ENTITY_BLOCKED].
## - every other rejection emits exactly one
##   [constant DomainEvent.COMMAND_REJECTED].
## A rejected result never carries a state mutation (see [Simulation]).

enum Status { SUCCESS, INVALID, BLOCKED, OUT_OF_BOUNDS, INVALID_STATE, GAME_ALREADY_COMPLETE }

const _STATUS_NAMES := {
	Status.SUCCESS: &"success",
	Status.INVALID: &"invalid",
	Status.BLOCKED: &"blocked",
	Status.OUT_OF_BOUNDS: &"out_of_bounds",
	Status.INVALID_STATE: &"invalid_state",
	Status.GAME_ALREADY_COMPLETE: &"game_already_complete",
}

var status: int = Status.SUCCESS
var code: StringName = &""
var events: Array[DomainEvent] = []


func _init(p_status: int = Status.SUCCESS, p_code: StringName = &"", p_events: Array[DomainEvent] = []) -> void:
	status = p_status
	code = p_code
	events = p_events


static func success(p_events: Array[DomainEvent] = []) -> CommandResult:
	return CommandResult.new(Status.SUCCESS, &"", p_events)


## Successful command that also reports a machine-readable outcome code
## (e.g. "staging_full", where the action was legal but the level is lost).
static func success_with_code(p_code: StringName, p_events: Array[DomainEvent] = []) -> CommandResult:
	return CommandResult.new(Status.SUCCESS, p_code, p_events)


static func rejected(p_status: int, p_code: StringName, p_events: Array[DomainEvent] = []) -> CommandResult:
	return CommandResult.new(p_status, p_code, p_events)


func is_success() -> bool:
	return status == Status.SUCCESS


func is_rejected() -> bool:
	return status != Status.SUCCESS


func status_name() -> StringName:
	return status_to_string_name(status)


static func status_to_string_name(value: int) -> StringName:
	return _STATUS_NAMES.get(value, &"")


static func status_from_string_name(name: StringName) -> int:
	for value in _STATUS_NAMES:
		if _STATUS_NAMES[value] == name:
			return value
	return -1


func to_dictionary() -> Dictionary:
	var serialized_events: Array = []
	for event in events:
		serialized_events.append(event.to_dictionary())
	return {
		"status": String(status_name()),
		"code": String(code),
		"events": serialized_events,
	}


func logical_equals(other: CommandResult) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())
