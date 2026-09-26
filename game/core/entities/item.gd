class_name Item
extends RefCounted
## Generic puzzle item (blueprint §9.2). Theme-independent.
##
## The core never interprets [member item_type] or [member color_key] beyond
## equality: those values are supplied by the product/theme layer, and the core
## does not know which concrete concept an item represents.

const TYPE_GENERIC := &"generic"

var id: StringName = &""
var item_type: StringName = TYPE_GENERIC
var color_key: StringName = &""
var destination_id: StringName = &""
var priority: int = 0
var special_type: StringName = &""
var metadata: Dictionary = {}


func _init(p_id: StringName = &"", p_item_type: StringName = TYPE_GENERIC, p_color_key: StringName = &"") -> void:
	id = p_id
	item_type = p_item_type
	color_key = p_color_key


func logical_equals(other: Item) -> bool:
	if other == null:
		return false
	return Serialization.values_equal(to_dictionary(), other.to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"item_type": String(item_type),
		"color_key": String(color_key),
		"destination_id": String(destination_id),
		"priority": priority,
		"special_type": String(special_type),
		"metadata": Serialization.canonicalize(metadata),
	}


static func from_dictionary(data: Dictionary) -> Item:
	var item := Item.new(
		StringName(str(data.get("id", ""))),
		StringName(str(data.get("item_type", String(TYPE_GENERIC)))),
		StringName(str(data.get("color_key", "")))
	)
	item.destination_id = StringName(str(data.get("destination_id", "")))
	item.priority = int(data.get("priority", 0))
	item.special_type = StringName(str(data.get("special_type", "")))
	var metadata: Variant = data.get("metadata", {})
	item.metadata = Serialization.canonicalize(metadata) if metadata != null else {}
	return item
