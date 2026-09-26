extends Node2D
## Destination/station presentation for the Traffic theme. DISPLAY ONLY.
##
## Shows accepted color keys (color + symbol), capacity pips and a queue strip
## from supplied data. It never decides acceptance, capacity or queue order
## (blueprint §8.2, §9.3).

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const DataScript := preload("res://themes/traffic/model_destination_view_data.gd")
const GlyphScript := preload("res://themes/traffic/components/symbol_glyph.gd")

const OUTLINE_COLOR := Color(0.07, 0.09, 0.13, 1.0)
const BASE_COLOR := Color(0.30, 0.34, 0.42, 1.0)
const BADGE_BG := Color(0.12, 0.14, 0.18, 0.9)

var data: DataScript = null
var cell_size: float = 64.0

var _palette: PaletteScript = null
var _queue_color_keys: Array[StringName] = []


func set_palette(palette: PaletteScript) -> void:
	_palette = palette
	queue_redraw()


func get_palette() -> PaletteScript:
	if _palette == null:
		_palette = PaletteScript.new()
	return _palette


func set_cell_size(px: float) -> void:
	cell_size = maxf(px, 1.0)
	queue_redraw()


func set_data(value: DataScript) -> void:
	data = value
	if data != null:
		set_queue(data.queue_color_keys)
	queue_redraw()


func get_data() -> DataScript:
	return data


func set_queue(color_keys: Array) -> void:
	_queue_color_keys.clear()
	for key: Variant in color_keys:
		_queue_color_keys.append(StringName(key))
	queue_redraw()


func queue_size() -> int:
	return _queue_color_keys.size()


func accepted_symbols() -> Array:
	var symbols: Array = []
	if data == null:
		return symbols
	for key: StringName in data.accepted_color_keys:
		symbols.append(get_palette().symbol_for(key))
	return symbols


func capacity() -> int:
	return data.capacity if data != null else 0


func occupancy() -> int:
	return data.occupancy if data != null else 0


func _draw() -> void:
	if data == null:
		return
	var fp: Vector2i = data.footprint
	var board_size := Vector2(float(fp.x), float(fp.y)) * cell_size
	var platform := Rect2(-board_size * 0.5, board_size)
	draw_rect(platform, BASE_COLOR)
	draw_rect(platform, OUTLINE_COLOR, false, 3.0)
	_draw_accepted(platform)
	_draw_capacity(platform)
	_draw_queue(platform)


func _draw_accepted(platform: Rect2) -> void:
	var count: int = data.accepted_color_keys.size()
	if count == 0:
		return
	var badge_radius := minf(platform.size.y * 0.16, cell_size * 0.22)
	var spacing := badge_radius * 2.4
	var start_x := platform.get_center().x - spacing * float(count - 1) * 0.5
	var y := platform.position.y + badge_radius * 1.6
	for i in count:
		var center := Vector2(start_x + spacing * float(i), y)
		draw_circle(center, badge_radius * 1.25, BADGE_BG)
		GlyphScript.draw_symbol(
			self,
			get_palette().symbol_for(data.accepted_color_keys[i]),
			center,
			badge_radius,
			get_palette().color_for(data.accepted_color_keys[i])
		)


func _draw_capacity(platform: Rect2) -> void:
	if data.capacity <= 0:
		return
	var pip_radius := minf(cell_size * 0.08, 6.0)
	var spacing := pip_radius * 3.0
	var total_width := spacing * float(data.capacity - 1)
	var start_x := platform.get_center().x - total_width * 0.5
	var y := platform.position.y + platform.size.y - pip_radius * 1.8
	for i in data.capacity:
		var center := Vector2(start_x + spacing * float(i), y)
		var filled: bool = i < data.occupancy
		draw_circle(center, pip_radius, Color(1, 1, 1, 0.85) if filled else Color(1, 1, 1, 0.22))


func _draw_queue(platform: Rect2) -> void:
	if _queue_color_keys.is_empty():
		return
	var token_radius := minf(cell_size * 0.18, 12.0)
	var spacing := token_radius * 2.4
	var total_width := spacing * float(_queue_color_keys.size())
	var start_x := platform.get_center().x - total_width * 0.5 + spacing * 0.5
	var y := platform.position.y - token_radius * 1.4
	for i in _queue_color_keys.size():
		var key: StringName = _queue_color_keys[i]
		var center := Vector2(start_x + spacing * float(i), y)
		draw_circle(center, token_radius, get_palette().color_for(key))
		draw_arc(center, token_radius, 0.0, TAU, 16, OUTLINE_COLOR, 1.5, true)
		GlyphScript.draw_symbol(self, get_palette().symbol_for(key), center, token_radius * 0.5, Color(1, 1, 1, 0.95))
