extends Node2D
## Passenger/item token presentation for the Traffic theme. VISUAL ONLY.
##
## No queue (FIFO) or matching logic lives here (blueprint §8.2, §14).

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const DataScript := preload("res://themes/traffic/model_item_view_data.gd")
const GlyphScript := preload("res://themes/traffic/components/symbol_glyph.gd")

const OUTLINE_COLOR := Color(0.07, 0.09, 0.13, 1.0)
const HIGHLIGHT_COLOR := Color(1.0, 0.92, 0.35, 0.95)

var data: DataScript = null
var cell_size: float = 48.0
var highlight: bool = false

var _palette: PaletteScript = null


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
	queue_redraw()


func get_data() -> DataScript:
	return data


func set_highlight(on: bool) -> void:
	highlight = on
	queue_redraw()


func color_key() -> StringName:
	return data.color_key if data != null else &"COLOR_A"


func body_color() -> Color:
	return get_palette().color_for(color_key())


func symbol_kind() -> StringName:
	return get_palette().symbol_for(color_key())


func _draw() -> void:
	var radius := cell_size * 0.5
	draw_circle(Vector2.ZERO, radius * 0.78, body_color())
	draw_arc(Vector2.ZERO, radius * 0.78, 0.0, TAU, 24, OUTLINE_COLOR, 2.0, true)
	draw_circle(Vector2(0, -radius * 0.28), radius * 0.3, body_color().lightened(0.18))
	draw_arc(Vector2(0, -radius * 0.28), radius * 0.3, 0.0, TAU, 20, OUTLINE_COLOR, 2.0, true)
	GlyphScript.draw_symbol(self, symbol_kind(), Vector2(0, radius * 0.22), radius * 0.26, Color(1, 1, 1, 0.96))
	if highlight:
		draw_arc(Vector2.ZERO, radius * 0.9, 0.0, TAU, 32, HIGHLIGHT_COLOR, 3.0, true)
