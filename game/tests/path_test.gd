extends "res://tests/framework/test_base.gd"
## Deterministic logical path model: validation, blockers, serialization.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_basics()
	_validation()
	_blockers()
	_serialization()


func _board(width: int = 5, height: int = 4) -> Board:
	return Board.new(BoardDimensions.new(width, height))


func _path(cells: Array) -> LogicalPath:
	var path := LogicalPath.new(&"route")
	for cell in cells:
		path.cells.append(GridPosition.new(cell[0], cell[1]))
	return path


func _basics() -> void:
	var path := _path([[0, 0], [1, 0], [2, 1]])
	check_eq(path.length(), 3, "length")
	check(path.origin().equals(GridPosition.new(0, 0)), "origin is the first cell")
	check(path.target().equals(GridPosition.new(2, 1)), "target is the last cell")
	check(path.contains_cell(GridPosition.new(1, 0)), "contains path cell")
	check(not path.contains_cell(GridPosition.new(3, 3)), "does not contain other cells")
	var empty := LogicalPath.new(&"empty")
	check_eq(empty.length(), 0, "empty path length")
	check(empty.origin() == null, "empty path has no origin")
	check(empty.target() == null, "empty path has no target")


func _validation() -> void:
	var dimensions := BoardDimensions.new(5, 4)
	check(_path([[0, 0], [1, 0], [1, 1]]).is_valid(dimensions), "straight/L path is valid")
	check(_path([[4, 3], [4, 2]]).is_valid(dimensions), "path along the border is valid")
	check(_path([[0, 0], [1, 0], [2, 0], [3, 0]]).is_valid(dimensions), "long straight path is valid")

	var too_short := _path([[0, 0]])
	check(too_short.validate(dimensions).has("path_too_short"), "single-cell path is rejected")
	var no_cells := LogicalPath.new(&"none")
	check(no_cells.validate(dimensions).has("path_too_short"), "empty path is rejected")
	var out_of_bounds := _path([[0, 0], [5, 0]])
	check(out_of_bounds.validate(dimensions).has("out_of_bounds:1"), "out-of-bounds cell reported with index")
	var diagonal := _path([[0, 0], [1, 1]])
	check(diagonal.validate(dimensions).has("non_contiguous:1"), "diagonal step is non-contiguous")
	var teleport := _path([[0, 0], [3, 0]])
	check(teleport.validate(dimensions).has("non_contiguous:1"), "teleporting step is rejected")
	var loop := _path([[0, 0], [1, 0], [0, 0]])
	check(loop.validate(dimensions).has("duplicate_cell:2"), "repeated cell is rejected")
	var unready_board := BoardDimensions.new(0, 0)
	check(_path([[0, 0], [1, 0]]).validate(unready_board).has("board_not_ready"), "unusable board reported")
	check(not _path([[0, 0], [1, 0]]).is_valid(unready_board), "is_valid mirrors validate")


func _blockers() -> void:
	var board := _board()
	var walker := Fixture.make_entity(&"walker")
	board.place_entity(walker, GridPosition.new(0, 0))
	var path := _path([[0, 0], [1, 0], [2, 0]])
	check(path.blockers_on(board, &"walker").is_empty(), "path over own cells is clear")
	check(path.first_blocked_cell(board, &"walker") == null, "no first blocker on a clear path")

	board.place_entity(Fixture.make_entity(&"z_blocker"), GridPosition.new(2, 0))
	board.place_entity(Fixture.make_entity(&"a_blocker"), GridPosition.new(1, 0))
	var blockers := path.blockers_on(board, &"walker")
	check_eq(blockers.size(), 2, "two blockers found")
	check_eq(blockers[0], &"a_blocker", "blockers sorted deterministically (1)")
	check_eq(blockers[1], &"z_blocker", "blockers sorted deterministically (2)")
	var first := path.first_blocked_cell(board, &"walker")
	check(first != null and first.equals(GridPosition.new(1, 0)), "first blocked cell follows path order")

	var other_origin := _path([[3, 3], [4, 3]])
	check(other_origin.blockers_on(board, &"walker").is_empty(), "unrelated path stays clear")
	var free_then_oob := _path([[3, 3], [4, 3], [9, 9]])
	check(free_then_oob.blockers_on(board, &"walker").is_empty(), "cells outside the board are ignored by blocker scan")
	check(_path([[9, 9], [9, 9]]).blockers_on(board, &"walker").is_empty(), "fully out-of-board path scans without blockers")


func _serialization() -> void:
	var path := _path([[0, 0], [1, 0], [1, 1]])
	var restored := LogicalPath.from_dictionary(path.to_dictionary())
	check(restored.logical_equals(path), "roundtrip preserves the path")
	check_eq(restored.id, &"route", "id restored")
	check_eq(restored.length(), 3, "cells restored")
	check(restored.target().equals(GridPosition.new(1, 1)), "target restored")
	check(Serialization.is_primitive_tree(path.to_dictionary()), "serialized path stays primitive")
	check(not path.logical_equals(null), "null comparison is safe")
