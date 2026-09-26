extends RefCounted
## Procedural symbol decals shared by Traffic presentation components.
##
## Symbols are DRAWN, never loaded, so accessibility dual-coding (blueprint §59)
## costs no assets and cannot introduce third-party content (blueprint §3).
## A future theme may override glyph drawing, but the generic contract remains
## "a symbol exists for every color key".

const SYMBOL_CIRCLE := &"circle"
const SYMBOL_TRIANGLE := &"triangle"
const SYMBOL_SQUARE := &"square"
const SYMBOL_STAR := &"star"


## Draws a symbol centred at `center`. `rotation` is in radians.
static func draw_symbol(
	canvas: CanvasItem,
	kind: StringName,
	center: Vector2,
	radius: float,
	color: Color,
	rotation: float = 0.0
) -> void:
	if canvas == null or radius <= 0.0:
		return
	match kind:
		SYMBOL_TRIANGLE:
			canvas.draw_colored_polygon(_place(center, _triangle_points(radius), rotation), color)
		SYMBOL_SQUARE:
			canvas.draw_colored_polygon(_place(center, _square_points(radius), rotation), color)
		SYMBOL_STAR:
			var star := star_points(Vector2.ZERO, radius, radius * 0.45)
			canvas.draw_colored_polygon(_place(center, star, rotation), color)
		_:
			canvas.draw_circle(center, radius, color)


static func star_points(center: Vector2, outer: float, inner: float, points: int = 5) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := maxi(points, 3) * 2
	for i in count:
		var r := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + PI * float(i) / float(points)
		result.append(center + Vector2(cos(angle), sin(angle)) * r)
	return result


static func _triangle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 3:
		var angle := -PI * 0.5 + TAU * float(i) / 3.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _square_points(radius: float) -> PackedVector2Array:
	var half := radius * 0.82
	return PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])


static func _place(center: Vector2, points: PackedVector2Array, rotation: float) -> PackedVector2Array:
	if is_zero_approx(rotation):
		var moved := PackedVector2Array()
		for point in points:
			moved.append(center + point)
		return moved
	var out := PackedVector2Array()
	var c := cos(rotation)
	var s := sin(rotation)
	for point in points:
		var rotated := Vector2(point.x * c - point.y * s, point.x * s + point.y * c)
		out.append(center + rotated)
	return out
