extends RefCounted
## DEV-ONLY M5 "Level Lab" solution playback controller.
##
## Plays back an ALREADY SUPPLIED command sequence. It never solves, generates
## or validates a puzzle; it only walks the supplied steps and forwards each
## command to an optional externally supplied driver. The driver hook is filled
## in later by cross-integration; without one it reports driver_missing.

signal step_changed(step: int)
signal command_applied(command: Dictionary)
signal playback_finished
signal driver_missing(command: Dictionary)

const DEFAULT_TYPE := "dispatch_entity"

var _commands: Array = []
var _step: int = 0
var _driver: Variant = null


func set_commands(commands: Array) -> void:
	_commands = normalize_commands(commands)
	_step = 0
	_reset_driver()
	step_changed.emit(_step)


func commands() -> Array:
	return _commands


func command_count() -> int:
	return _commands.size()


func step() -> int:
	return _step


func current_command() -> Dictionary:
	if is_complete():
		return {}
	var command: Dictionary = _commands[_step]
	return command


func is_complete() -> bool:
	return _step >= _commands.size()


func has_driver() -> bool:
	return _driver != null and _driver is Object


func set_driver(driver: Variant) -> void:
	_driver = driver


func reset() -> void:
	_step = 0
	_reset_driver()
	step_changed.emit(_step)


func step_once() -> bool:
	if is_complete():
		return false
	var command: Dictionary = current_command()
	if has_driver() and _driver.has_method("execute"):
		_driver.execute(command)
	else:
		driver_missing.emit(command)
	command_applied.emit(command)
	_step += 1
	step_changed.emit(_step)
	if is_complete():
		playback_finished.emit()
	return true


func play_all() -> int:
	var applied: int = 0
	while step_once():
		applied += 1
	return applied


func snapshot() -> Variant:
	if has_driver() and _driver.has_method("snapshot"):
		return _driver.snapshot()
	return null


static func normalize_commands(raw: Variant) -> Array:
	var result: Array = []
	if not (raw is Array):
		return result
	for entry: Variant in raw:
		var normalized: Dictionary = _normalize_entry(entry)
		if not normalized.is_empty():
			result.append(normalized)
	return result


static func _normalize_entry(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	var source: Dictionary = entry
	if not source.has("entityId") and not source.has("entity_id") and not source.has("entity"):
		return {}
	var entity_raw: Variant = null
	if source.has("entityId"):
		entity_raw = source["entityId"]
	elif source.has("entity_id"):
		entity_raw = source["entity_id"]
	else:
		entity_raw = source["entity"]
	if not (entity_raw is String) and not (entity_raw is StringName):
		return {}
	var entity_id: StringName = StringName(String(entity_raw))
	if entity_id == &"":
		return {}
	var type_value: String = DEFAULT_TYPE
	if source.has("type") and source["type"] != null:
		type_value = String(source["type"])
	var normalized: Dictionary = {
		"type": type_value,
		"entity_id": entity_id,
	}
	return normalized


func _reset_driver() -> void:
	if has_driver() and _driver.has_method("reset"):
		_driver.reset()
