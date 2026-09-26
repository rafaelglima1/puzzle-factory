class_name BoardDimensions
extends RefCounted
## Logical board size in cells with bounds math.
##
## Board cell indexing is row-major: index = y * width + x.

const MAX_SIDE := 64

var width: int
var height: int


func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height


func is_valid() -> bool:
	return width > 0 and height > 0 and width <= MAX_SIDE and height <= MAX_SIDE


func contains(position: GridPosition) -> bool:
	if position == null or not is_valid():
		return false
	return position.x >= 0 and position.y >= 0 and position.x < width and position.y < height


func contains_footprint(footprint: Footprint, origin: GridPosition) -> bool:
	if footprint == null or origin == null or not footprint.is_valid() or not is_valid():
		return false
	if origin.x < 0 or origin.y < 0:
		return false
	return origin.x + footprint.width <= width and origin.y + footprint.height <= height


func cell_count() -> int:
	return width * height


func index_of(position: GridPosition) -> int:
	@warning_ignore("integer_division")
	return position.y * width + position.x


func position_of(index: int) -> GridPosition:
	return GridPosition.new(index % width, index / width)


func equals(other: BoardDimensions) -> bool:
	if other == null:
		return false
	return width == other.width and height == other.height


func to_dictionary() -> Dictionary:
	return {"width": width, "height": height}


static func from_dictionary(data: Dictionary) -> BoardDimensions:
	return BoardDimensions.new(int(data.get("width", 0)), int(data.get("height", 0)))


func _to_string() -> String:
	return "%dx%d" % [width, height]
