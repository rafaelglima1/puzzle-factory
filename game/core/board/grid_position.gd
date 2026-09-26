class_name GridPosition
extends RefCounted
## Logical integer board coordinate (one cell).
##
## Value object: identity comes from [member x]/[member y] values, not from
## object identity. Board coordinates are row-major with y increasing
## downwards (north = -y), matching the serialized grid layout.

var x: int
var y: int


func _init(p_x: int = 0, p_y: int = 0) -> void:
	x = p_x
	y = p_y


func equals(other: GridPosition) -> bool:
	if other == null:
		return false
	return x == other.x and y == other.y


func offset(dx: int, dy: int) -> GridPosition:
	return GridPosition.new(x + dx, y + dy)


func to_dictionary() -> Dictionary:
	return {"x": x, "y": y}


static func from_dictionary(data: Dictionary) -> GridPosition:
	return GridPosition.new(int(data.get("x", 0)), int(data.get("y", 0)))


func _to_string() -> String:
	return "(%d,%d)" % [x, y]
