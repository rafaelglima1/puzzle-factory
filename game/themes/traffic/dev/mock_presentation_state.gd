extends RefCounted
## DEV-ONLY mock presentation state for the Traffic sandbox.
##
## This file exists purely so the scaffold is visually testable before M1
## publishes the presentation bridge. It carries NO puzzle rules: it is just
## hand-written view data. Reusable presentation components must never
## reference this path (enforced by tests/presentation_boundary_test.gd).

const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const ItemData := preload("res://themes/traffic/model_item_view_data.gd")
const DestinationData := preload("res://themes/traffic/model_destination_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")
const BoardData := preload("res://themes/traffic/model_board_view_data.gd")


static func sample_entities() -> Array:
	var list: Array = []
	# Different types, color keys and orientations for readability review.
	list.append(entity(&"e_compact_a", EntityData.TYPE_COMPACT, &"COLOR_A", Vector2i(1, 1), 0.0))
	list.append(entity(&"e_van_b", EntityData.TYPE_VAN, &"COLOR_B", Vector2i(4, 1), 180.0))
	list.append(entity(&"e_truck_c", EntityData.TYPE_TRUCK, &"COLOR_C", Vector2i(1, 4), 90.0))
	list.append(entity(&"e_compact_d", EntityData.TYPE_COMPACT, &"COLOR_D", Vector2i(5, 6), 270.0))
	return list


static func entity(
	id: StringName,
	type: StringName,
	color_key: StringName,
	cell: Vector2i,
	orientation: float
) -> RefCounted:
	var result: RefCounted = EntityData.new(id, type, color_key)
	result.cell = cell
	result.orientation = orientation
	result.footprint = footprint_for(type)
	return result


static func footprint_for(type: StringName) -> Vector2i:
	match type:
		EntityData.TYPE_TRUCK:
			return Vector2i(3, 1)
		EntityData.TYPE_VAN:
			return Vector2i(2, 1)
		_:
			return Vector2i(2, 1)


static func sample_destination() -> RefCounted:
	var destination: RefCounted = DestinationData.new(&"dest_station")
	destination.cell = Vector2i(5, 3)
	destination.footprint = Vector2i(2, 2)
	destination.capacity = 4
	destination.occupancy = 1
	destination.accepted_color_keys.append(&"COLOR_A")
	destination.accepted_color_keys.append(&"COLOR_B")
	destination.queue_color_keys.append(&"COLOR_A")
	destination.queue_color_keys.append(&"COLOR_B")
	destination.queue_color_keys.append(&"COLOR_A")
	return destination


static func sample_items() -> Array:
	var items: Array = []
	items.append(ItemData.new(&"i1", ItemData.TYPE_PASSENGER, &"COLOR_A"))
	items.append(ItemData.new(&"i2", ItemData.TYPE_PASSENGER, &"COLOR_B"))
	items.append(ItemData.new(&"i3", ItemData.TYPE_PASSENGER, &"COLOR_C"))
	return items


static func sample_staging(slots: int = 4) -> RefCounted:
	var staging: RefCounted = StagingData.new(slots)
	if slots > 0:
		staging.set_occupant(0, entity(&"e_staged", EntityData.TYPE_VAN, &"COLOR_C", Vector2i.ZERO, 0.0))
	if slots > 1:
		staging.set_occupant(1, entity(&"e_staged2", EntityData.TYPE_COMPACT, &"COLOR_B", Vector2i.ZERO, 0.0))
	return staging


static func sample_board() -> RefCounted:
	var board: RefCounted = BoardData.new(8, 10)
	board.obstacles.append(Vector2i(3, 3))
	board.obstacles.append(Vector2i(4, 3))
	board.obstacles.append(Vector2i(3, 4))
	for entity_data: Variant in sample_entities():
		board.add_entity(entity_data)
	board.add_destination(sample_destination())
	return board
