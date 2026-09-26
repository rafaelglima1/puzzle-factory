extends RefCounted
## Original M3 presentation style tokens and procedural StyleBox factories.
##
## No assets are used: styles are built in code (blueprint §3 originality, §63
## low asset cost). M3 targets functional first-playable quality, not M4 polish.
## The accent colors intentionally mirror the accessibility palette family used
## by the board symbols.

const BG := Color(0.09, 0.10, 0.13, 1.0)
const PANEL := Color(0.15, 0.17, 0.21, 1.0)
const SCRIM := Color(0.03, 0.04, 0.06, 0.72)
const TEXT := Color(0.95, 0.96, 0.98, 1.0)
const TEXT_MUTED := Color(0.73, 0.77, 0.83, 1.0)
const PRIMARY := Color(0.24, 0.47, 0.90, 1.0)
const WARNING := Color(0.95, 0.63, 0.13, 1.0)
const NEUTRAL := Color(0.28, 0.32, 0.38, 1.0)

const SAFE := 24.0
const TOUCH_TARGET := 120.0
const COLUMN_MAX_WIDTH := 720.0
const HEADER_HEIGHT := 160.0
const SPACING := 16.0
const FONT_TITLE := 76
const FONT_HEADING := 54
const FONT_BODY := 40
const FONT_BUTTON := 44


## Applies a full button skin. `kind` is `primary`, `warning` or `neutral`.
static func apply_button(button: Button, kind: StringName = &"primary") -> void:
	var base := PRIMARY
	if kind == &"warning":
		base = WARNING
	elif kind == &"neutral":
		base = NEUTRAL
	button.add_theme_stylebox_override("normal", _box(base))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.14)))
	button.add_theme_stylebox_override("focus", _box(base.lightened(0.05)))
	button.add_theme_stylebox_override("disabled", _box(NEUTRAL.darkened(0.25)))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_font_size_override("font_size", FONT_BUTTON)


static func panel_style() -> StyleBoxFlat:
	var style := _box(PANEL)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.30, 0.34, 0.40, 1.0)
	return style


static func column_left(viewport_width: float) -> float:
	return maxf((viewport_width - minf(viewport_width, COLUMN_MAX_WIDTH)) * 0.5, 0.0)


static func column_width(viewport_width: float) -> float:
	return minf(viewport_width, COLUMN_MAX_WIDTH)


static func _box(base: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
