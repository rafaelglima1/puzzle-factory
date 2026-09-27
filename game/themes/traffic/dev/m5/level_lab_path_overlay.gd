extends Control
## DEV-ONLY debug overlay: draws supplied entity paths over the board (AGENT-2).
##
## Read-only visualization of plain data. It never reads simulation state and
## never decides anything: `paths` are supplied dictionaries of
## `{"id": StringName, "cells": Array[Vector2i], "color": Color}` and are drawn
## exactly as received. Cells are interpreted in board-local coordinates and
## converted to pixel centres with the supplied `cell_size`.
##
## Rendered intentionally "debug-like" (semi-transparent + dashed) so paths stay
## visually distinct from the theme art underneath.

const DEFAULT_COLOR := Color(0.95, 0.85, 0.3, 0.9)

const NODE_BG := Color(0.06, 0.07, 0.10, 0.85)
const NUMBER_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const START_RING := Color(1.0, 1.0, 1.0, 0.9)

var _paths: Array = []
var _cell_size: float = 0.0
var _board_origin: Vector2 = Vector2.ZERO


func set_paths(paths: Array, cell_size: float) -> void:
	_paths = paths
	_cell_size = cell_size
	queue_redraw()


func set_board_origin(origin: Vector2) -> void:
	_board_origin = origin
	queue_redraw()


func clear_paths() -> void:
	_paths = []
	queue_redraw()


func path_count() -> int:
	return _paths.size()


func _draw() -> void:
	if _cell_size <= 0.0:
		return
	if _paths.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var node_radius: float = maxf(_cell_size * 0.16, 3.0)
	var font_size: int = int(maxf(_cell_size * 0.34, 9.0))
	var line_width: float = maxf(_cell_size * 0.10, 2.0)
	var dash_width: float = maxf(_cell_size * 0.045, 1.5)
	var dash_len: float = maxf(_cell_size * 0.18, 4.0)
	for path_variant: Variant in _paths:
		if not (path_variant is Dictionary):
			continue
		var path: Dictionary = path_variant
		var color: Color = _path_color(path)
		var points: PackedVector2Array = _points_for(path)
		if points.is_empty():
			continue
		if points.size() >= 2:
			var soft := Color(color.r, color.g, color.b, color.a * 0.45)
			draw_polyline(points, soft, line_width, true)
			for index: int in range(points.size() - 1):
				draw_dashed_line(points[index], points[index + 1], color, dash_width, dash_len)
			_draw_arrow(points[points.size() - 2], points[points.size() - 1], color)
		_draw_start(points[0], color)
		for index: int in range(points.size()):
			_draw_number(font, points[index], index + 1, font_size, node_radius, color)


func _path_color(path: Dictionary) -> Color:
	var value: Variant = path.get("color", DEFAULT_COLOR)
	if value is Color:
		return value
	return DEFAULT_COLOR


func _points_for(path: Dictionary) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var cells_variant: Variant = path.get("cells", [])
	if not (cells_variant is Array):
		return points
	var cells: Array = cells_variant
	for cell_variant: Variant in cells:
		var cell: Vector2i
		if cell_variant is Vector2i:
			cell = cell_variant
		elif cell_variant is Vector2:
			var vec: Vector2 = cell_variant
			cell = Vector2i(vec)
		else:
			continue
		var center: Vector2 = Vector2(
			(float(cell.x) + 0.5) * _cell_size + _board_origin.x,
			(float(cell.y) + 0.5) * _cell_size + _board_origin.y
		)
		points.append(center)
	return points


func _draw_start(point: Vector2, color: Color) -> void:
	var radius: float = maxf(_cell_size * 0.24, 4.0)
	draw_circle(point, radius, color)
	draw_arc(point, radius, 0.0, TAU, 24, START_RING, maxf(_cell_size * 0.05, 1.5), true)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var dir: Vector2 = to - from
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var length: float = maxf(_cell_size * 0.34, 8.0)
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var base: Vector2 = to - dir * length
	var head: PackedVector2Array = PackedVector2Array([
		to,
		base + perp * length * 0.5,
		base - perp * length * 0.5,
	])
	draw_colored_polygon(head, color)


func _draw_number(font: Font, point: Vector2, number: int, font_size: int, radius: float, color: Color) -> void:
	draw_circle(point, radius, NODE_BG)
	draw_arc(point, radius, 0.0, TAU, 20, color, maxf(_cell_size * 0.035, 1.0), true)
	var text: String = str(number)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent: float = font.get_ascent(font_size)
	var descent: float = font.get_descent(font_size)
	var pos: Vector2 = Vector2(point.x - text_size.x * 0.5, point.y + (ascent - descent) * 0.5)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, NUMBER_COLOR)
