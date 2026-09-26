extends Control
## M3 debug level selector (development/debug only).
##
## Presentation-only: it renders caller-supplied entries and emits a ZERO-BASED
## `level_selected(index)` intent. It contains no progression/unlock business
## logic and is only reachable when the shell's debug gate is enabled (see
## m3_first_playable.gd; production hides it, blueprint §67/§68).

const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

signal level_selected(index: int)
signal close_pressed

var _scrim: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _scroll: ScrollContainer = null
var _rows_box: VBoxContainer = null
var _close: Button = null

var _rows: Array = []
var _entries: Array = []
var _enabled := true
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
	_title.text = Strings.text(&"ui.select_level")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", Style.FONT_HEADING)
	_title.add_theme_color_override("font_color", Style.TEXT)
	_panel.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "Rows"
	_rows_box.add_theme_constant_override("separation", int(Style.SPACING))
	_scroll.add_child(_rows_box)

	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = Strings.text(&"ui.menu")
	Style.apply_button(_close, &"neutral")
	_close.pressed.connect(_on_close_pressed)
	_panel.add_child(_close)


func set_enabled(value: bool) -> void:
	_enabled = value


func is_enabled() -> bool:
	return _enabled


func show_entries(entries: Array) -> bool:
	if not _enabled:
		return false
	_entries = entries
	_rebuild_rows()
	visible = true
	_refresh_layout()
	return true


func hide_panel() -> void:
	visible = false


func entry_count() -> int:
	return _rows.size()


func entries() -> Array:
	return _entries.duplicate()


## Emits `level_selected(index)` for a supplied zero-based level index.
func select_index(index: int) -> bool:
	for row: Variant in _rows:
		var button: Button = row
		if int(button.get_meta("level_index")) == index:
			level_selected.emit(index)
			return true
	return false


func close() -> void:
	close_pressed.emit()


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


func row_rect(index: int) -> Rect2:
	if index < 0 or index >= _rows.size():
		return Rect2()
	var button: Button = _rows[index]
	return Rect2(button.global_position, button.size)


func layout_for(viewport: Vector2) -> void:
	size = viewport
	_viewport = viewport
	_refresh_layout()


func _rebuild_rows() -> void:
	for row: Variant in _rows:
		var button: Button = row
		_rows_box.remove_child(button)
		button.free()
	_rows.clear()
	for entry: Variant in _entries:
		if not (entry is Dictionary):
			continue
		var dict := entry as Dictionary
		var index := int(dict.get("index", _rows.size()))
		var label := str(dict.get("label", Strings.format_text(&"ui.level_n", [index + 1])))
		var button := Button.new()
		button.text = label
		button.set_meta("level_index", index)
		Style.apply_button(button, &"neutral")
		button.custom_minimum_size = Vector2(0.0, Style.TOUCH_TARGET)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_row_pressed.bind(index))
		_rows_box.add_child(button)
		_rows.append(button)


func _refresh_layout() -> void:
	if _panel == null:
		return
	var column := Style.column_width(_viewport.x)
	var panel_w := maxf(column - Style.SAFE * 2.0, 1.0)
	var top := Style.SAFE
	var panel_h := maxf(_viewport.y - Style.SAFE - top, 1.0)
	_panel.position = Vector2((_viewport.x - panel_w) * 0.5, top)
	_panel.size = Vector2(panel_w, panel_h)

	var inner_w := panel_w - Style.SAFE * 2.0
	var title_h := 96.0
	var close_h := Style.TOUCH_TARGET
	_title.position = Vector2(Style.SAFE, Style.SAFE)
	_title.size = Vector2(inner_w, title_h)
	_close.position = Vector2(Style.SAFE, panel_h - Style.SAFE - close_h)
	_close.size = Vector2(inner_w, close_h)
	var scroll_top := Style.SAFE + title_h + Style.SPACING
	var scroll_h := panel_h - scroll_top - Style.SAFE - close_h - Style.SPACING
	_scroll.position = Vector2(Style.SAFE, scroll_top)
	_scroll.size = Vector2(inner_w, maxf(scroll_h, 1.0))
	_rows_box.custom_minimum_size = Vector2(inner_w, 0.0)


func _on_row_pressed(index: int) -> void:
	level_selected.emit(index)


func _on_close_pressed() -> void:
	close_pressed.emit()
