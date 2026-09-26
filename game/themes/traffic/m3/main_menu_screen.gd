extends Control
## M3 main menu screen (presentation only). Emits player intents; it never
## decides progression, unlocks or what "Play" means.

const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

signal play_pressed
signal level_select_pressed

var _title: Label = null
var _play: Button = null
var _level_select: Button = null
var _debug_visible := false


func _init() -> void:
	build()


func build() -> void:
	if _title != null:
		return
	_title = Label.new()
	_title.name = "Title"
	_title.text = Strings.text(&"ui.project_title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	_title.add_theme_color_override("font_color", Style.TEXT)
	add_child(_title)

	_play = Button.new()
	_play.name = "PlayButton"
	_play.text = Strings.text(&"ui.play")
	Style.apply_button(_play, &"primary")
	_play.pressed.connect(_on_play_pressed)
	add_child(_play)

	_level_select = Button.new()
	_level_select.name = "LevelSelectButton"
	_level_select.text = Strings.text(&"ui.level_select")
	Style.apply_button(_level_select, &"neutral")
	_level_select.pressed.connect(_on_level_select_pressed)
	_level_select.visible = _debug_visible
	add_child(_level_select)


## Debug entry point visibility. Production keeps it hidden (blueprint §67/§68).
func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	if _level_select != null:
		_level_select.visible = value


func is_debug_visible() -> bool:
	return _debug_visible


func press_play() -> void:
	play_pressed.emit()


func press_level_select() -> void:
	level_select_pressed.emit()


func play_button_visible() -> bool:
	return _play != null and _play.visible


func level_select_visible() -> bool:
	return _level_select != null and _level_select.visible


func title_text() -> String:
	return _title.text if _title != null else ""


func layout_for(viewport: Vector2) -> void:
	size = viewport
	var column := Style.column_width(viewport.x)
	var left := Style.column_left(viewport.x)
	var button_width := maxf(column - Style.SAFE * 2.0, 1.0)
	var center_y := viewport.y * 0.42
	_title.position = Vector2(left, maxf(center_y - 220.0, 0.0))
	_title.size = Vector2(column, 140.0)
	_play.position = Vector2(left + Style.SAFE, center_y)
	_play.size = Vector2(button_width, Style.TOUCH_TARGET)
	_level_select.position = Vector2(left + Style.SAFE, center_y + Style.TOUCH_TARGET + Style.SPACING)
	_level_select.size = Vector2(button_width, Style.TOUCH_TARGET)


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_level_select_pressed() -> void:
	level_select_pressed.emit()
