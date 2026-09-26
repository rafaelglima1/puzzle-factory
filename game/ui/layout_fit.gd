extends RefCounted
## Resolution-independent board fit maths (blueprint §62).
##
## Pure helpers (no nodes, no viewport) so they can be unit-tested headlessly
## and reused by every screen. The board keeps its cell aspect ratio, is
## centred, and never exceeds the available area; extra space becomes margin
## (20:9) instead of cropping (16:9).


## Returns the board rect (position + size) that fits `cells` inside
## `available`. `margin` is applied on all sides. `max_width` (0 = uncapped)
## constrains the board on tablets so HUD/board do not stretch edge to edge.
static func fit_board_rect(
	available: Vector2,
	cells: Vector2i,
	margin: float = 0.0,
	max_width: float = 0.0
) -> Rect2:
	var safe := Vector2(
		maxf(available.x - margin * 2.0, 1.0),
		maxf(available.y - margin * 2.0, 1.0)
	)
	var usable_width := safe.x
	if max_width > 0.0:
		usable_width = minf(usable_width, max_width)

	var cols := maxf(float(cells.x), 1.0)
	var rows := maxf(float(cells.y), 1.0)
	var cell := minf(usable_width / cols, safe.y / rows)
	var board := Vector2(cell * cols, cell * rows)
	var origin := Vector2(
		(available.x - board.x) * 0.5,
		(available.y - board.y) * 0.5
	)
	return Rect2(origin, board)


## Width of a centred content column for tablets (blueprint §5.3).
static func content_column_width(available: Vector2, max_column_width: float) -> float:
	if max_column_width <= 0.0:
		return available.x
	return minf(available.x, max_column_width)
