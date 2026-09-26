extends "res://tests/framework/test_base.gd"
## Occupancy: authoritative blocking, overlap rejection, atomic movement.

const Fixture := preload("res://tests/fixtures/core_fixture.gd")


func run() -> void:
	_placement()
	_overlap_rejection()
	_blockers()
	_movement()
	_atomic_rejection()
	_removal()
	_deterministic_iteration()


func _board() -> Board:
	return Board.new(BoardDimensions.new(5, 5))


func _placement() -> void:
	var board := _board()
	check(board.is_ready(), "board is ready")
	check_eq(board.entity_count(), 0, "empty board has no entities")
	check(board.is_cell_free(GridPosition.new(0, 0)), "empty cell is free")
	check_eq(board.occupant_at(GridPosition.new(0, 0)), &"", "empty occupant is empty id")
	var entity := Fixture.make_entity(&"a")
	check(board.place_entity(entity, GridPosition.new(1, 1)), "place single-cell entity")
	check_eq(board.entity_count(), 1, "count after placement")
	check_eq(board.occupant_at(GridPosition.new(1, 1)), &"a", "occupant at placed cell")
	check(not board.is_cell_free(GridPosition.new(1, 1)), "placed cell is not free")
	check(board.position_of(&"a").equals(GridPosition.new(1, 1)), "board tracks position")
	check(entity.position.equals(GridPosition.new(1, 1)), "entity position stays in sync with board")
	check(not board.place_entity(entity, GridPosition.new(3, 3)), "re-placement of the same id is rejected")
	var multi := Fixture.make_entity(&"b", 2, 1)
	check(board.place_entity(multi, GridPosition.new(0, 3)), "multi-cell placement")
	check_eq(board.occupant_at(GridPosition.new(0, 3)), &"b", "multi-cell footprint covers first cell")
	check_eq(board.occupant_at(GridPosition.new(1, 3)), &"b", "multi-cell footprint covers second cell")
	check(board.is_cell_free(GridPosition.new(2, 3)), "cell after footprint remains free")
	var wide := Fixture.make_entity(&"c", 3, 1)
	check(not board.place_entity(wide, GridPosition.new(3, 0)), "out-of-bounds placement rejected")
	check(not board.has_entity(&"c"), "rejected placement is not registered")


func _overlap_rejection() -> void:
	var board := _board()
	board.place_entity(Fixture.make_entity(&"a", 2, 2), GridPosition.new(1, 1))
	check(not board.can_place(Footprint.new(1, 1), GridPosition.new(1, 1)), "occupied cell cannot be placed on")
	check(not board.can_place(Footprint.new(2, 1), GridPosition.new(2, 2)), "partial overlap is rejected")
	check(board.can_place(Footprint.new(2, 1), GridPosition.new(3, 3)), "free area is placeable")
	var other := Fixture.make_entity(&"b")
	check(not board.place_entity(other, GridPosition.new(2, 2)), "overlapping placement rejected")
	check(not board.has_entity(&"b"), "overlapping entity not registered")
	check_eq(board.entity_count(), 1, "board unchanged after rejected overlap")
	check(board.occupant_at(GridPosition.new(1, 1)) == &"a", "original occupant preserved")


func _blockers() -> void:
	var board := _board()
	board.place_entity(Fixture.make_entity(&"a", 2, 1), GridPosition.new(2, 2))
	board.place_entity(Fixture.make_entity(&"b"), GridPosition.new(1, 2))
	var blockers := board.blockers_for(Footprint.new(1, 1), GridPosition.new(1, 2))
	check_eq(blockers.size(), 1, "single blocker found")
	check_eq(blockers[0], &"b", "blocker id reported")
	check(board.blockers_for(Footprint.new(2, 1), GridPosition.new(2, 2), &"a").is_empty(), "own cells are ignored for self-move")
	check(board.blockers_for(Footprint.new(1, 1), GridPosition.new(4, 4)).is_empty(), "free target has no blockers")
	var two_cells := board.blockers_for(Footprint.new(2, 1), GridPosition.new(2, 2))
	check_eq(two_cells.size(), 1, "two-cell footprint over one occupant reports one blocker")
	check_eq(two_cells[0], &"a", "two-cell footprint blocker id")
	board.place_entity(Fixture.make_entity(&"z"), GridPosition.new(3, 3))
	board.place_entity(Fixture.make_entity(&"b_first"), GridPosition.new(4, 3))
	var multiple := board.blockers_for(Footprint.new(2, 1), GridPosition.new(3, 3))
	check_eq(multiple.size(), 2, "two blockers reported")
	check_eq(multiple[0], &"b_first", "blockers sorted deterministically (1)")
	check_eq(multiple[1], &"z", "blockers sorted deterministically (2)")


func _movement() -> void:
	var board := _board()
	var entity := Fixture.make_entity(&"a")
	board.place_entity(entity, GridPosition.new(0, 0))
	check(board.move_entity(entity, GridPosition.new(4, 4)), "single-cell move succeeds")
	check(board.is_cell_free(GridPosition.new(0, 0)), "old cell freed")
	check_eq(board.occupant_at(GridPosition.new(4, 4)), &"a", "new cell occupied")
	check(entity.position.equals(GridPosition.new(4, 4)), "entity position synced after move")
	check_eq(board.entity_count(), 1, "entity count unchanged by move")
	var wide := Fixture.make_entity(&"w", 2, 1)
	board.place_entity(wide, GridPosition.new(0, 1))
	check(board.move_entity(wide, GridPosition.new(1, 1)), "move overlapping own footprint is allowed")
	check(board.is_cell_free(GridPosition.new(0, 1)), "vacated part freed")
	check_eq(board.occupant_at(GridPosition.new(2, 1)), &"w", "trailing cell occupied after slide")
	check(board.move_entity(wide, GridPosition.new(1, 1)), "same-position move keeps placement")
	check_eq(board.occupant_at(GridPosition.new(1, 1)), &"w", "still occupied after same-position move")


func _atomic_rejection() -> void:
	var board := _board()
	var first := Fixture.make_entity(&"a")
	var second := Fixture.make_entity(&"b", 2, 1)
	board.place_entity(first, GridPosition.new(0, 0))
	board.place_entity(second, GridPosition.new(1, 0))
	var before := board.to_dictionary()
	check(not board.move_entity(first, GridPosition.new(1, 0)), "blocked move rejected")
	check(Serialization.values_equal(before, board.to_dictionary()), "board unchanged after blocked move")
	check(first.position.equals(GridPosition.new(0, 0)), "entity position unchanged after blocked move")
	check_eq(board.occupant_at(GridPosition.new(0, 0)), &"a", "origin cell still owned")
	check(not board.move_entity(second, GridPosition.new(4, 0)), "out-of-bounds move rejected")
	check(Serialization.values_equal(before, board.to_dictionary()), "board unchanged after out-of-bounds move")
	check_eq(board.entity_count(), 2, "entity count unchanged after rejections")


func _removal() -> void:
	var board := _board()
	var entity := Fixture.make_entity(&"a", 2, 2)
	board.place_entity(entity, GridPosition.new(0, 0))
	check(board.remove_entity(entity), "placed entity removed")
	check_eq(board.entity_count(), 0, "count after removal")
	check(board.is_cell_free(GridPosition.new(0, 0)), "removed cells freed")
	check(board.is_cell_free(GridPosition.new(1, 1)), "all footprint cells freed")
	check(not board.remove_entity(entity), "double removal rejected")
	check(board.occupant_ids().is_empty(), "no occupants remain")


func _deterministic_iteration() -> void:
	var board := _board()
	board.place_entity(Fixture.make_entity(&"zeta"), GridPosition.new(0, 0))
	board.place_entity(Fixture.make_entity(&"alpha"), GridPosition.new(1, 0))
	board.place_entity(Fixture.make_entity(&"mid"), GridPosition.new(2, 0))
	var ids := board.occupant_ids()
	check_eq(ids.size(), 3, "occupant id count")
	check_eq(ids[0], &"alpha", "occupant ids sorted (1)")
	check_eq(ids[1], &"mid", "occupant ids sorted (2)")
	check_eq(ids[2], &"zeta", "occupant ids sorted (3)")
	var cells := board.cells_for(&"mid")
	check_eq(cells.size(), 1, "cells_for single-cell footprint")
	check(cells[0].equals(GridPosition.new(2, 0)), "cells_for reports the position")
	var wide := Fixture.make_entity(&"wide", 2, 1)
	board.place_entity(wide, GridPosition.new(0, 2))
	var wide_cells := board.cells_for(&"wide")
	check_eq(wide_cells.size(), 2, "cells_for multi-cell footprint")
	check(wide_cells[0].equals(GridPosition.new(0, 2)), "multi-cell order (1)")
	check(wide_cells[1].equals(GridPosition.new(1, 2)), "multi-cell order (2)")
	check(board.cells_for(&"missing").is_empty(), "cells_for unknown entity is empty")
