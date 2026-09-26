extends Node2D
## Vehicle presentation for the Traffic theme. VISUAL ONLY.
##
## Reads a TrafficEntityData DTO (generic fields: id, entity_type, color_key,
## footprint, cell, orientation). It never validates movement, occupancy or
## matching (blueprint §8.2, ADR-003). Silhouettes are procedural so no
## third-party art is required (blueprint §3) and cost stays low.

const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")
const DataScript := preload("res://themes/traffic/model_entity_view_data.gd")
const GlyphScript := preload("res://themes/traffic/components/symbol_glyph.gd")
const SelectionIndicatorScript := preload("res://themes/traffic/components/selection_indicator.gd")

const OUTLINE_COLOR := Color(0.07, 0.09, 0.13, 1.0)
const OUTLINE_WIDTH := 3.0
const WINDOW_COLOR := Color(0.88, 0.93, 0.98, 0.92)
const WHEEL_COLOR := Color(0.10, 0.11, 0.13, 1.0)
const BLOCKED_TINT := Color(0.94, 0.24, 0.24, 0.95)

var data: DataScript = null
var cell_size: float = 64.0
var selected: bool = false
var blocked: bool = false

var _palette: PaletteScript = null
var _selection_indicator: SelectionIndicatorScript = null


## Orientation in degrees. Node2D rotation is presentation transform only.
var orientation_degrees: float = 0.0:
	set(value):
		orientation_degrees = value
		rotation_degrees = value
		queue_redraw()


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
		orientation_degrees = data.orientation
	queue_redraw()


func get_data() -> DataScript:
	return data


func set_selected(on: bool) -> void:
	selected = on
	if on and _selection_indicator == null:
		_selection_indicator = SelectionIndicatorScript.new()
		_selection_indicator.name = "SelectionIndicator"
		add_child(_selection_indicator)
	if _selection_indicator != null:
		_selection_indicator.set_radius(_ring_radius() + 6.0)
		_selection_indicator.set_active(on)
	queue_redraw()


func is_selected() -> bool:
	return selected


func get_selection_indicator() -> SelectionIndicatorScript:
	return _selection_indicator


func set_blocked(on: bool) -> void:
	blocked = on
	queue_redraw()


func is_blocked() -> bool:
	return blocked


func color_key() -> StringName:
	return data.color_key if data != null else &"COLOR_A"


func entity_type() -> StringName:
	return data.entity_type if data != null else DataScript.TYPE_COMPACT


func body_color() -> Color:
	return get_palette().color_for(color_key())


func symbol_kind() -> StringName:
	return get_palette().symbol_for(color_key())


func footprint() -> Vector2i:
	return data.footprint if data != null else Vector2i(2, 1)


## Pixel extent after applying orientation (axes swap on side orientations).
func presentation_extent() -> Vector2:
	var fp := footprint()
	var extent := Vector2(float(fp.x), float(fp.y)) * cell_size
	if _is_sideways():
		extent = Vector2(extent.y, extent.x)
	return extent


func _is_sideways() -> bool:
	var degrees := fposmod(orientation_degrees, 180.0)
	return degrees > 45.0 and degrees < 135.0


func _ring_radius() -> float:
	var fp := footprint()
	return maxf(float(fp.x), float(fp.y)) * cell_size * 0.5


func _draw() -> void:
	if data == null:
		return
	var fp := footprint()
	var length := float(fp.x) * cell_size
	var width := float(fp.y) * cell_size
	var body := Rect2(Vector2(-length * 0.5, -width * 0.5), Vector2(length, width))
	_draw_body_shape(body, body_color())
	if blocked:
		draw_rect(body.grow(4.0), BLOCKED_TINT, false, OUTLINE_WIDTH + 1.0)
	_draw_symbol(body)


func _draw_body_shape(body: Rect2, base: Color) -> void:
	match entity_type():
		DataScript.TYPE_TRUCK:
			_draw_truck(body, base)
		DataScript.TYPE_VAN:
			_draw_van(body, base)
		_:
			_draw_compact(body, base)


func _draw_compact(body: Rect2, base: Color) -> void:
	var inset := body.grow(-body.size.y * 0.16)
	draw_rect(inset, base)
	draw_rect(inset, OUTLINE_COLOR, false, OUTLINE_WIDTH)
	var window_width := inset.size.x * 0.16
	draw_rect(
		Rect2(
			Vector2(inset.position.x + inset.size.x - window_width, inset.position.y + inset.size.y * 0.18),
			Vector2(window_width, inset.size.y * 0.64)
		),
		WINDOW_COLOR
	)
	_draw_wheels(inset)


func _draw_van(body: Rect2, base: Color) -> void:
	var inset := body.grow(-body.size.y * 0.14)
	draw_rect(inset, base)
	draw_rect(inset, OUTLINE_COLOR, false, OUTLINE_WIDTH)
	var cab_ratio := 0.32
	var cab := Rect2(inset.position, Vector2(inset.size.x * cab_ratio, inset.size.y))
	draw_rect(Rect2(cab.position, Vector2(cab.size.x * 0.55, cab.size.y * 0.5)).grow(-4.0), WINDOW_COLOR)
	_draw_wheels(inset)


func _draw_truck(body: Rect2, base: Color) -> void:
	var inset := body.grow(-body.size.y * 0.14)
	var cab_width := inset.size.x * 0.28
	var cab := Rect2(inset.position, Vector2(cab_width, inset.size.y))
	var cargo := Rect2(
		Vector2(inset.position.x + cab_width + 3.0, inset.position.y),
		Vector2(inset.size.x - cab_width - 3.0, inset.size.y)
	)
	draw_rect(cab, base.darkened(0.12))
	draw_rect(cab, OUTLINE_COLOR, false, OUTLINE_WIDTH)
	draw_rect(cargo, base)
	draw_rect(cargo, OUTLINE_COLOR, false, OUTLINE_WIDTH)
	draw_rect(
		Rect2(cab.position + Vector2(cab.size.x * 0.2, cab.size.y * 0.25), Vector2(cab.size.x * 0.45, cab.size.y * 0.5)),
		WINDOW_COLOR
	)
	_draw_wheels(inset)


func _draw_wheels(body: Rect2) -> void:
	var wheel_height := maxf(body.size.y * 0.14, 2.0)
	var wheel_width := maxf(body.size.x * 0.16, 3.0)
	var offsets := [0.18, 0.62]
	for ratio: float in offsets:
		var x := body.position.x + body.size.x * ratio
		draw_rect(Rect2(Vector2(x, body.position.y - wheel_height), Vector2(wheel_width, wheel_height)), WHEEL_COLOR)
		draw_rect(Rect2(Vector2(x, body.position.y + body.size.y), Vector2(wheel_width, wheel_height)), WHEEL_COLOR)


func _draw_symbol(body: Rect2) -> void:
	var radius := minf(body.size.x, body.size.y) * 0.24
	var center := body.get_center()
	if entity_type() == DataScript.TYPE_TRUCK:
		center = Vector2(body.position.x + body.size.x * 0.60, body.get_center().y)
	GlyphScript.draw_symbol(self, symbol_kind(), center, radius, Color(1, 1, 1, 0.96))
