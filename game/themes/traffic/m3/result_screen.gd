extends Control
## M3 result screen (presentation only): win or fail overlay.
##
## Renders supplied state. It never grants rewards, unlocks levels, navigates or
## restarts the simulation; it only emits player intents.

const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

## The winning tap can land exactly where a result button appears (the vehicles
## sit at the same height as NEXT/MENU on a phone). Android also delivers a
## synthetic mouse event for that same tap, which would press the button that
## just appeared under the finger and skip the result. Player presses arriving
## right after the result is shown are therefore ignored. The guard lives at the
## intent boundary, so it holds no matter how the event was routed.
const INPUT_GUARD_MS := 350

var _input_guard_until_msec := -1

signal next_pressed
signal retry_pressed
signal menu_pressed

var _scrim: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _message: Label = null
var _next: Button = null
var _retry: Button = null
var _menu: Button = null

var _mode: StringName = &""
var _viewport := Vector2(1080.0, 1920.0)


func _init() -> void:
	build()


func build() -> void:
	if _scrim != null:
		return
	visible = false

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Style.SCRIM
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", Style.panel_style())
	add_child(_panel)

	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", Style.FONT_HEADING)
	_title.add_theme_color_override("font_color", Style.TEXT)
	_panel.add_child(_title)

	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_font_size_override("font_size", Style.FONT_BODY)
	_message.add_theme_color_override("font_color", Style.TEXT_MUTED)
	_panel.add_child(_message)

	_next = _make_button("NextButton", &"ui.next", &"primary")
	_next.pressed.connect(_on_next_pressed)
	_retry = _make_button("RetryButton", &"ui.retry", &"warning")
	_retry.pressed.connect(_on_retry_pressed)
	_menu = _make_button("MenuButton", &"ui.menu", &"neutral")
	_menu.pressed.connect(_on_menu_pressed)
	_next.visible = false
	_retry.visible = false
	_menu.visible = false


func show_win(level_number: int, is_final_level: bool, total_levels: int = 10) -> void:
	_mode = &"win"
	if is_final_level:
		_title.text = Strings.format_text(&"ui.all_n_levels_complete", [total_levels])
	else:
		_title.text = Strings.text(&"ui.level_complete")
	_message.text = Strings.format_text(&"ui.level_of", [level_number, total_levels])
	_next.visible = not is_final_level
	_retry.visible = false
	_menu.visible = true
	visible = true
	_refresh_layout()
	_arm_input_guard()


func show_fail(level_number: int, fail_message_key: StringName, total_levels: int = 10) -> void:
	_mode = &"fail"
	_title.text = Strings.text(&"ui.try_again")
	_message.text = "%s\n%s" % [
		Strings.text(fail_message_key),
		Strings.format_text(&"ui.level_of", [level_number, total_levels]),
	]
	_next.visible = false
	_retry.visible = true
	_menu.visible = true
	visible = true
	_refresh_layout()
	_arm_input_guard()


## True while a result press must still be ignored (see `INPUT_GUARD_MS`).
func input_guard_active() -> bool:
	return Time.get_ticks_msec() < _input_guard_until_msec


func _arm_input_guard() -> void:
	_input_guard_until_msec = Time.get_ticks_msec() + INPUT_GUARD_MS


func press_next() -> void:
	next_pressed.emit()


func press_retry() -> void:
	retry_pressed.emit()


func press_menu() -> void:
	menu_pressed.emit()


func mode() -> StringName:
	return _mode


func title_text() -> String:
	return _title.text if _title != null else ""


func message_text() -> String:
	return _message.text if _message != null else ""


func next_visible() -> bool:
	return _next != null and _next.visible


func retry_visible() -> bool:
	return _retry != null and _retry.visible


func menu_visible() -> bool:
	return _menu != null and _menu.visible


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


func layout_for(viewport: Vector2) -> void:
	size = viewport
	_viewport = viewport
	_refresh_layout()


func _make_button(node_name: String, text_key: StringName, kind: StringName) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = Strings.text(text_key)
	Style.apply_button(button, kind)
	_panel.add_child(button)
	return button


func _refresh_layout() -> void:
	if _panel == null:
		return
	var column := Style.column_width(_viewport.x)
	var panel_w := maxf(column - Style.SAFE * 2.0, 1.0)
	var title_h := 110.0
	var message_h := 120.0
	var button_h := Style.TOUCH_TARGET
	var visible_buttons := 0
	if _next.visible:
		visible_buttons += 1
	if _retry.visible:
		visible_buttons += 1
	if _menu.visible:
		visible_buttons += 1
	var content_h := Style.SAFE * 2.0 + title_h + 8.0 + message_h + Style.SPACING \
		+ float(visible_buttons) * button_h + float(maxi(visible_buttons - 1, 0)) * Style.SPACING
	var panel_h := maxf(content_h, 1.0)
	var top_bound := Style.HEADER_HEIGHT + Style.SAFE
	var bottom_bound := maxf(_viewport.y - Style.SAFE, top_bound)
	var y := clampf(_viewport.y * 0.5 - panel_h * 0.5, top_bound, maxf(bottom_bound - panel_h, top_bound))
	_panel.position = Vector2((_viewport.x - panel_w) * 0.5, y)
	_panel.size = Vector2(panel_w, panel_h)

	var inner_w := panel_w - Style.SAFE * 2.0
	_title.position = Vector2(Style.SAFE, Style.SAFE)
	_title.size = Vector2(inner_w, title_h)
	_message.position = Vector2(Style.SAFE, Style.SAFE + title_h + 8.0)
	_message.size = Vector2(inner_w, message_h)
	var cursor := Style.SAFE + title_h + 8.0 + message_h + Style.SPACING
	for button: Variant in [_next, _retry, _menu]:
		var control: Button = button
		if not control.visible:
			continue
		control.position = Vector2(Style.SAFE, cursor)
		control.size = Vector2(inner_w, button_h)
		cursor += button_h + Style.SPACING


func _on_next_pressed() -> void:
	if input_guard_active():
		return
	next_pressed.emit()


func _on_retry_pressed() -> void:
	if input_guard_active():
		return
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	if input_guard_active():
		return
	menu_pressed.emit()
