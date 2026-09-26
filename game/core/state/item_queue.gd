class_name ItemQueue
extends RefCounted
## Deterministic FIFO item queue (blueprint §9.4). Theme-independent.
##
## Ordering: insertion order is authoritative and preserved exactly in
## serialization, so a reloaded queue takes items in the same order.
## Only the FIFO policy is implemented; future policies must be added as new
## enum values with their own tests (never by changing FIFO semantics).

enum Policy { FIFO }

const _POLICY_NAMES := {
	Policy.FIFO: &"fifo",
}

var id: StringName = &""
var policy: int = Policy.FIFO
## Presentation hint only (blueprint §9.4); never used for queue logic.
var visible_count: int = 0

var _item_ids: Array[StringName] = []


func _init(p_id: StringName = &"", p_policy: int = Policy.FIFO) -> void:
	id = p_id
	policy = p_policy


func enqueue(item_id: StringName) -> bool:
	if item_id == &"" or _item_ids.has(item_id):
		return false
	_item_ids.append(item_id)
	return true


## Returns the front item id without removing it; &"" when empty.
func peek() -> StringName:
	if _item_ids.is_empty():
		return &""
	return _item_ids[0]


## Removes and returns the front item id; &"" when empty (safe).
func take() -> StringName:
	if _item_ids.is_empty():
		return &""
	return _item_ids.pop_front()


func remaining_count() -> int:
	return _item_ids.size()


func is_empty() -> bool:
	return _item_ids.is_empty()


func contains(item_id: StringName) -> bool:
	return _item_ids.has(item_id)


## Returns a copy of the ids in FIFO order.
func item_ids() -> Array[StringName]:
	var copy: Array[StringName] = []
	copy.assign(_item_ids)
	return copy


func remove(item_id: StringName) -> bool:
	var index := _item_ids.find(item_id)
	if index < 0:
		return false
	_item_ids.remove_at(index)
	return true


func clear() -> void:
	_item_ids.clear()


func logical_equals(other: ItemQueue) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	var ids: Array = []
	for item_id in _item_ids:
		ids.append(String(item_id))
	return {
		"id": String(id),
		"policy": String(_POLICY_NAMES.get(policy, &"")),
		"visible_count": visible_count,
		"item_ids": ids,
	}


static func from_dictionary(data: Dictionary) -> ItemQueue:
	var queue := ItemQueue.new(StringName(str(data.get("id", ""))))
	var policy := policy_from_string_name(StringName(str(data.get("policy", "fifo"))))
	queue.policy = policy if policy != -1 else Policy.FIFO
	queue.visible_count = int(data.get("visible_count", 0))
	var ids: Variant = data.get("item_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for item_id in ids:
			queue._item_ids.append(StringName(str(item_id)))
	return queue


static func policy_to_string_name(value: int) -> StringName:
	return _POLICY_NAMES.get(value, &"")


static func policy_from_string_name(name: StringName) -> int:
	for value in _POLICY_NAMES:
		if _POLICY_NAMES[value] == name:
			return value
	return -1
