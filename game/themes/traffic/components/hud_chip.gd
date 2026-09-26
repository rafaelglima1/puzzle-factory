extends Control
## Objective chip: color + symbol dual-coded indicator for the HUD (blueprint
## §59). Label text is optional and supplied externally (no hardcoded strings,
## blueprint §58).

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const GlyphScript := preload("res://themes/traffic/components/symbol_glyph.gd")

const MIN_SIZE := Vector2(48.0, 48.0)

var color_key: StringName = &"COLOR_A"
var label_text: String = ""

var _palette: PaletteScript = PaletteScript.new()


func _ready() -> void:
	custom_minimum_size = MIN_SIZE


func set_color_key(key: StringName) -> void:
	color_key = key
	queue_redraw()


func get_color_key() -> StringName:
	return color_key


func set_label(text: String) -> void:
	label_text = text
	queue_redraw()


func symbol_kind() -> StringName:
	return _palette.symbol_for(color_key)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var base: Color = _palette.color_for(color_key)
	draw_rect(rect, base.darkened(0.25))
	draw_rect(rect.grow(-2.0), base, false, 3.0)
	var icon_center := Vector2(size.y * 0.5, size.y * 0.5)
	GlyphScript.draw_symbol(self, symbol_kind(), icon_center, size.y * 0.26, Color(1, 1, 1, 0.96))
	if not label_text.is_empty():
		var font := ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(size.y * 0.92, size.y * 0.66),
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			int(size.y * 0.4),
			Color(1, 1, 1, 0.95)
		)
