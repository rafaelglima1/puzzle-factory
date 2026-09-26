extends RefCounted
## Presentation-only view data for the staging area (Traffic theme).
##
## The component receives slot count, occupants and pressure state. It never
## decides warning/full: pressure is supplied externally (blueprint §8.2).

const PRESSURE_NORMAL := &"normal"
const PRESSURE_WARNING := &"warning"
const PRESSURE_FULL := &"full"

var slot_count: int = 4
var occupants: Array = []
var pressure: StringName = PRESSURE_NORMAL


func _init(p_slot_count: int = 4) -> void:
	set_slot_count(p_slot_count)


func set_slot_count(count: int) -> void:
	slot_count = maxi(count, 0)
	_resize_occupants()


func occupant_at(index: int) -> Variant:
	if index < 0 or index >= occupants.size():
		return null
	return occupants[index]


func set_occupant(index: int, entity_data: Variant) -> void:
	while occupants.size() <= index:
		occupants.append(null)
	occupants[index] = entity_data


func _resize_occupants() -> void:
	while occupants.size() < slot_count:
		occupants.append(null)
	while occupants.size() > slot_count:
		occupants.pop_back()
