extends Control
## A single staging slot. Receives occupancy + pressure; never decides them.

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const GlyphScript := preload("res://themes/traffic/components/symbol_glyph.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")

const FRAME_NORMAL := Color(0.32, 0.36, 0.44, 1.0)
const FRAME_WARNING := Color(0.95, 0.63, 0.13, 1.0)
const FRAME_FULL := Color(0.92, 0.24, 0.24, 1.0)
const SLOT_BG := Color(0.13, 0.15, 0.19, 1.0)

var occupied: bool = false
var entity_data: EntityData = null
var pressure: StringName = StagingData.PRESSURE_NORMAL

var _palette: PaletteScript = PaletteScript.new()
var _pulse := 0.0


## Bounded pressure pulse strength in [0, 1] (driven by StagingView.advance).
func set_pulse(strength: float) -> void:
	_pulse = clampf(strength, 0.0, 1.0)
	queue_redraw()


func set_pressure_state(state: StringName) -> void:
	pressure = state
	queue_redraw()


func set_occupied(on: bool) -> void:
	occupied = on
	queue_redraw()


func set_entity(value: EntityData) -> void:
	entity_data = value
	occupied = value != null
	queue_redraw()


func color_key() -> StringName:
	return entity_data.color_key if entity_data != null else &"COLOR_A"


func symbol_kind() -> StringName:
	return _palette.symbol_for(color_key())


func _frame_color() -> Color:
	match pressure:
		StagingData.PRESSURE_WARNING:
			return FRAME_WARNING
		StagingData.PRESSURE_FULL:
			return FRAME_FULL
		_:
			return FRAME_NORMAL


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, SLOT_BG)
	var frame := _frame_color()
	var width := 3.0
	if _pulse > 0.0:
		frame = frame.lightened(0.35 * _pulse)
		width = 3.0 + 2.5 * _pulse
	draw_rect(rect.grow(-2.0), frame, false, width)
	if not occupied:
		return
	var center := rect.get_center()
	var radius := minf(size.x, size.y) * 0.28
	draw_circle(center, radius * 1.15, _palette.color_for(color_key()))
	draw_arc(center, radius * 1.15, 0.0, TAU, 20, Color(0.07, 0.09, 0.13), 2.0, true)
	GlyphScript.draw_symbol(self, symbol_kind(), center, radius * 0.6, Color(1, 1, 1, 0.96))
