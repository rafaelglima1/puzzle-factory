extends "res://tests/framework/test_base.gd"
## Generic item: defaults, serialization, logical equality.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_defaults()
	_serialization()
	_equality()


func _defaults() -> void:
	var item := Item.new(&"i1", &"unit_item", &"COLOR_A")
	check_eq(item.id, &"i1", "id")
	check_eq(item.item_type, &"unit_item", "item type")
	check_eq(item.color_key, &"COLOR_A", "color key")
	check_eq(item.destination_id, &"", "destination defaults to empty")
	check_eq(item.priority, 0, "priority default")
	check_eq(item.special_type, &"", "special type default")
	check(item.metadata.is_empty(), "metadata empty by default")
	var generic := Item.new(&"i2")
	check_eq(generic.item_type, Item.TYPE_GENERIC, "default item type is generic")


func _serialization() -> void:
	var item := Item.new(&"i1", &"unit_item", &"COLOR_B")
	item.destination_id = &"destination_1"
	item.priority = 3
	item.special_type = &"fragile"
	item.metadata = {"nested": {"b": 2, "a": 1}, "tags": ["x"]}
	var restored := Item.from_dictionary(item.to_dictionary())
	check(restored.logical_equals(item), "roundtrip preserves the item")
	check_eq(restored.id, item.id, "id restored")
	check_eq(restored.color_key, item.color_key, "color key restored")
	check_eq(restored.destination_id, item.destination_id, "destination restored")
	check_eq(restored.priority, item.priority, "priority restored")
	check_eq(restored.special_type, item.special_type, "special type restored")
	check(restored.metadata.has("nested"), "metadata restored")
	check(Serialization.is_primitive_tree(item.to_dictionary()), "serialized item stays primitive")


func _equality() -> void:
	var first := Item.new(&"i1", &"unit_item", &"COLOR_A")
	var second := Item.new(&"i1", &"unit_item", &"COLOR_A")
	check(first.logical_equals(second), "identical items are logically equal")
	second.priority = 1
	check(not first.logical_equals(second), "priority difference breaks equality")
	check(not first.logical_equals(null), "null comparison is safe")
	check(first.logical_equals(first), "self equality")
