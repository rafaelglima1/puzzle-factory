class_name StagingArea
extends RefCounted
## Generic limited-capacity staging/holding area (blueprint §9.5).
## Theme-independent: a product/theme layer supplies the concrete meaning.
##
## Slot assignment is deterministic: the lowest free slot index is always used
## first. Capacity is arbitrary (3, 4, 5, 6+); 0 means staging is unavailable,
## so any entity that would need staging immediately fails (STAGING_FULL).
## M2 default is [constant DEFAULT_SLOT_COUNT]; nothing in the rules assumes
## exactly four slots.

const DEFAULT_SLOT_COUNT := 4
const FREE_SLOT := &""

var slot_count: int = DEFAULT_SLOT_COUNT

var _occupants: Array[StringName] = []


func _init(p_slot_count: int = DEFAULT_SLOT_COUNT) -> void:
	slot_count = maxi(p_slot_count, 0)
	while _occupants.size() < slot_count:
		_occupants.append(FREE_SLOT)


## Resizes the area. Refuses to shrink below the number of occupants.
func set_slot_count(count: int) -> bool:
	if count < 0 or count < occupied_count():
		return false
	if count > _occupants.size():
		while _occupants.size() < count:
			_occupants.append(FREE_SLOT)
	elif count < _occupants.size():
		_occupants.resize(count)
	slot_count = count
	return true


func occupant_at(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= _occupants.size():
		return FREE_SLOT
	return _occupants[slot_index]


## Returns a copy of the occupants (slot order, FREE_SLOT for empty slots).
func occupants() -> Array[StringName]:
	var copy: Array[StringName] = []
	copy.assign(_occupants)
	return copy


func occupied_count() -> int:
	var count := 0
	for occupant in _occupants:
		if occupant != FREE_SLOT:
			count += 1
	return count


func available_slots() -> int:
	return slot_count - occupied_count()


func is_full() -> bool:
	return available_slots() <= 0


func slot_of(entity_id: StringName) -> int:
	return _occupants.find(entity_id)


func has(entity_id: StringName) -> bool:
	return slot_of(entity_id) >= 0


## Adds an entity id to the lowest free slot.
## Returns the assigned slot index, or -1 when full/duplicate/empty.
func add(entity_id: StringName) -> int:
	if entity_id == FREE_SLOT or has(entity_id):
		return -1
	var slot := _occupants.find(FREE_SLOT)
	if slot < 0:
		return -1
	_occupants[slot] = entity_id
	return slot


func remove(entity_id: StringName) -> bool:
	var slot := slot_of(entity_id)
	if slot < 0:
		return false
	_occupants[slot] = FREE_SLOT
	return true


func clear() -> void:
	for index in _occupants.size():
		_occupants[index] = FREE_SLOT


func logical_equals(other: StagingArea) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	var occupants_out: Array = []
	for occupant in _occupants:
		occupants_out.append(String(occupant))
	return {
		"slot_count": slot_count,
		"occupants": occupants_out,
	}


static func from_dictionary(data: Dictionary) -> StagingArea:
	var staging := StagingArea.new(int(data.get("slot_count", DEFAULT_SLOT_COUNT)))
	var occupants: Variant = data.get("occupants", [])
	if typeof(occupants) == TYPE_ARRAY:
		for index in occupants.size():
			if index >= staging._occupants.size():
				break
			var occupant := StringName(str(occupants[index]))
			staging._occupants[index] = occupant
	return staging
