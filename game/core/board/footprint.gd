class_name Footprint
extends RefCounted
## Logical cell footprint of an entity (rectangular, 1x1 or larger).
##
## The origin is the top-left cell. Cell offsets are generated row-major
## (dy outer, dx inner) so occupancy math is deterministic everywhere.

const MAX_SIDE := 64

var width: int
var height: int


func _init(p_width: int = 1, p_height: int = 1) -> void:
	width = p_width
	height = p_height


func is_valid() -> bool:
	return width > 0 and height > 0 and width <= MAX_SIDE and height <= MAX_SIDE


func cell_count() -> int:
	return width * height


func cell_offsets() -> Array[GridPosition]:
	var offsets: Array[GridPosition] = []
	if not is_valid():
		return offsets
	for dy in height:
		for dx in width:
			offsets.append(GridPosition.new(dx, dy))
	return offsets


func cell_positions(origin: GridPosition) -> Array[GridPosition]:
	var cells: Array[GridPosition] = []
	if origin == null:
		return cells
	for offset in cell_offsets():
		cells.append(origin.offset(offset.x, offset.y))
	return cells


func equals(other: Footprint) -> bool:
	if other == null:
		return false
	return width == other.width and height == other.height


func to_dictionary() -> Dictionary:
	return {"width": width, "height": height}


static func from_dictionary(data: Dictionary) -> Footprint:
	return Footprint.new(int(data.get("width", 0)), int(data.get("height", 0)))


func _to_string() -> String:
	return "%dx%d" % [width, height]
