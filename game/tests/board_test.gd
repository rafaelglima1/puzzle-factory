extends "res://tests/framework/test_base.gd"
## Board foundation: dimensions, positions, footprints, bounds.


func run() -> void:
	_dimensions()
	_positions()
	_footprints()
	_bounds()


func _dimensions() -> void:
	check(not BoardDimensions.new(0, 5).is_valid(), "zero width is invalid")
	check(not BoardDimensions.new(-3, 4).is_valid(), "negative side is invalid")
	check(not BoardDimensions.new(BoardDimensions.MAX_SIDE + 1, 4).is_valid(), "side above MAX_SIDE is invalid")
	var dimensions := BoardDimensions.new(4, 3)
	check(dimensions.is_valid(), "4x3 board is valid")
	check_eq(dimensions.cell_count(), 12, "cell count")
	check_eq(dimensions.index_of(GridPosition.new(0, 0)), 0, "index of origin")
	check_eq(dimensions.index_of(GridPosition.new(3, 2)), 11, "index of last cell")
	check(dimensions.position_of(11).equals(GridPosition.new(3, 2)), "position_of roundtrip")
	check(dimensions.contains(GridPosition.new(3, 2)), "contains last cell")
	check(not dimensions.contains(GridPosition.new(4, 2)), "x == width is out of bounds")
	check(not dimensions.contains(GridPosition.new(2, 3)), "y == height is out of bounds")
	check(not dimensions.contains(GridPosition.new(-1, 0)), "negative x is out of bounds")
	check(dimensions.equals(BoardDimensions.from_dictionary(dimensions.to_dictionary())), "dimensions roundtrip")
	check(not dimensions.equals(null), "null comparison is safe")


func _positions() -> void:
	var position := GridPosition.new(2, 3)
	check(position.offset(1, -1).equals(GridPosition.new(3, 2)), "offset applies deltas")
	check(not position.equals(GridPosition.new(3, 2)), "different positions are not equal")
	check(not position.equals(null), "null comparison is safe")
	check(GridPosition.from_dictionary(position.to_dictionary()).equals(position), "position roundtrip")
	check_eq(str(position), "(2,3)", "debug string form")


func _footprints() -> void:
	check(Footprint.new(1, 1).is_valid(), "1x1 footprint is valid")
	check(not Footprint.new(0, 3).is_valid(), "zero width footprint is invalid")
	var footprint := Footprint.new(2, 3)
	check_eq(footprint.cell_count(), 6, "footprint cell count")
	var offsets := footprint.cell_offsets()
	check_eq(offsets.size(), 6, "offset count")
	check(offsets[0].equals(GridPosition.new(0, 0)), "first offset is origin")
	check(offsets[1].equals(GridPosition.new(1, 0)), "offsets are row-major (dx inner)")
	check(offsets[2].equals(GridPosition.new(0, 1)), "offsets advance rows after width")
	check(offsets[5].equals(GridPosition.new(1, 2)), "last offset")
	var cells := footprint.cell_positions(GridPosition.new(2, 1))
	check_eq(cells.size(), 6, "cell positions count")
	check(cells[0].equals(GridPosition.new(2, 1)), "first cell uses origin")
	check(cells[5].equals(GridPosition.new(3, 3)), "last cell respects origin")
	check(footprint.equals(Footprint.from_dictionary(footprint.to_dictionary())), "footprint roundtrip")


func _bounds() -> void:
	var dimensions := BoardDimensions.new(4, 4)
	check(dimensions.contains_footprint(Footprint.new(3, 1), GridPosition.new(1, 0)), "3x1 fits at x=1")
	check(not dimensions.contains_footprint(Footprint.new(3, 1), GridPosition.new(2, 0)), "3x1 does not fit at x=2")
	check(dimensions.contains_footprint(Footprint.new(2, 2), GridPosition.new(2, 2)), "2x2 fits at the far corner")
	check(not dimensions.contains_footprint(Footprint.new(2, 2), GridPosition.new(3, 3)), "2x2 out of bounds at far corner")
	check(not dimensions.contains_footprint(Footprint.new(1, 1), GridPosition.new(-1, 0)), "negative origin out of bounds")
	check(not dimensions.contains_footprint(Footprint.new(0, 1), GridPosition.new(0, 0)), "invalid footprint never fits")
