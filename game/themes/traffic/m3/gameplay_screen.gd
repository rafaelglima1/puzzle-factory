extends Control
## M3 gameplay screen (presentation only): Traffic board + thin header.
##
## It embeds an existing [TrafficPresenter] and exposes a level label plus
## Restart / Menu intents. Entity taps are detected geometrically against the
## board's entity views and re-emitted as `entity_tapped(entity_id)`; the
## screen NEVER decides whether a move is legal (the simulation does), and it
## respects the presenter's cosmetic input lock.

const PresenterScript := preload("res://themes/traffic/traffic_presenter.gd")
const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

signal entity_tapped(entity_id: StringName)
signal restart_pressed
signal menu_pressed

var presenter: PresenterScript = null

var _header: Control = null
var _level_label: Label = null
var _restart: Button = null
var _menu: Button = null
var _tap_catcher: Control = null
var _last_touch_msec := -1000


func _init() -> void:
	build()


func build() -> void:
	if presenter != null:
		return
	presenter = PresenterScript.new()
	presenter.name = "Presenter"
	add_child(presenter)
	presenter.build()

	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_tap_catcher)
	_tap_catcher.gui_input.connect(_on_tap_catcher_gui_input)

	_header = Control.new()
	_header.name = "Header"
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_header)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", Style.FONT_HEADING)
	_level_label.add_theme_color_override("font_color", Style.TEXT)
	_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_header.add_child(_level_label)

	_restart = Button.new()
	_restart.name = "RestartButton"
	_restart.text = Strings.text(&"ui.restart")
	Style.apply_button(_restart, &"neutral")
	_restart.add_theme_font_size_override("font_size", 32)
	_restart.pressed.connect(_on_restart_pressed)
	_header.add_child(_restart)

	_menu = Button.new()
	_menu.name = "MenuButton"
	_menu.text = Strings.text(&"ui.menu")
	Style.apply_button(_menu, &"neutral")
	_menu.add_theme_font_size_override("font_size", 32)
	_menu.pressed.connect(_on_menu_pressed)
	_header.add_child(_menu)


func get_presenter() -> PresenterScript:
	return presenter


func set_level_text(text: String) -> void:
	if _level_label != null:
		_level_label.text = text


func level_text() -> String:
	return _level_label.text if _level_label != null else ""


func set_objectives(color_keys: Array) -> void:
	presenter.set_objectives(color_keys)


func press_restart() -> void:
	restart_pressed.emit()


func press_menu() -> void:
	menu_pressed.emit()


## Board-local point -> entity id, or &"" when nothing is tapped / input is
## locked / a result sequence is active. Public so tests and the input catcher
## share exactly one path.
func handle_tap_at(board_point: Vector2) -> StringName:
	if presenter == null:
		return &""
	if presenter.is_input_locked():
		return &""
	if presenter.active_sequence() != &"":
		return &""
	var entity_id: StringName = presenter.entity_at_board_point(board_point, Style.TOUCH_TARGET)
	if entity_id == &"":
		return &""
	entity_tapped.emit(entity_id)
	return entity_id


func board_rect() -> Rect2:
	return Rect2(presenter.position + presenter.board_view.position, presenter.board_view.size)


func staging_rect() -> Rect2:
	return Rect2(presenter.position + presenter.staging_view.position, presenter.staging_view.size)


func header_buttons_rect() -> Rect2:
	if _restart == null or _menu == null:
		return Rect2()
	var left := minf(_restart.position.x, _menu.position.x)
	var right := maxf(_restart.position.x + _restart.size.x, _menu.position.x + _menu.size.x)
	var top := minf(_restart.position.y, _menu.position.y)
	var bottom := maxf(_restart.position.y + _restart.size.y, _menu.position.y + _menu.size.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func advance(delta: float) -> void:
	if presenter != null:
		presenter.advance(delta)


func teardown() -> void:
	if presenter != null:
		presenter.teardown()


func layout_for(viewport: Vector2) -> void:
	size = viewport
	presenter.position = Vector2(0.0, Style.HEADER_HEIGHT)
	presenter.layout_for(Vector2(viewport.x, maxf(viewport.y - Style.HEADER_HEIGHT, 1.0)))

	_header.position = Vector2.ZERO
	_header.size = Vector2(viewport.x, Style.HEADER_HEIGHT)

	var column := Style.column_width(viewport.x)
	var left := Style.column_left(viewport.x)
	var button := Style.TOUCH_TARGET
	var button_y := (Style.HEADER_HEIGHT - button) * 0.5
	_menu.position = Vector2(left + column - Style.SAFE - button, button_y)
	_menu.size = Vector2(button, button)
	_restart.position = Vector2(left + column - Style.SAFE - button - Style.SPACING - button, button_y)
	_restart.size = Vector2(button, button)

	_level_label.position = Vector2(left + Style.SAFE, (Style.HEADER_HEIGHT - 64.0) * 0.5)
	_level_label.size = Vector2(maxf(_restart.position.x - (left + Style.SAFE) - Style.SPACING, 1.0), 64.0)

	# Tap catcher exactly covers the board so header buttons stay untouched.
	_tap_catcher.position = presenter.position + presenter.board_view.position
	_tap_catcher.size = presenter.board_view.size


func _on_tap_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_last_touch_msec = Time.get_ticks_msec()
			handle_tap_at(touch.position)
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			if Time.get_ticks_msec() - _last_touch_msec < 400:
				return
			handle_tap_at(mouse.position)


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _on_menu_pressed() -> void:
	menu_pressed.emit()
