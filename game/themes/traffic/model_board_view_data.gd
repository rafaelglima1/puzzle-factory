extends RefCounted
## Presentation-only view data for the board surface (Traffic theme).
##
## The board view draws a grid and places entity/destination views at supplied
## cells. It does NOT own occupancy or legality: `obstacles` and `entities`
## are provided by the caller (blueprint §8.2, ADR-003).

var width: int = 8
var height: int = 10
var obstacles: Array[Vector2i] = []
var entities: Array = []
var destinations: Array = []


func _init(p_width: int = 8, p_height: int = 10) -> void:
	width = maxi(p_width, 1)
	height = maxi(p_height, 1)


func add_entity(entity_data: Variant) -> void:
	entities.append(entity_data)


func add_destination(destination_data: Variant) -> void:
	destinations.append(destination_data)


func entity_count() -> int:
	return entities.size()


func destination_count() -> int:
	return destinations.size()


func cells() -> Vector2i:
	return Vector2i(width, height)
