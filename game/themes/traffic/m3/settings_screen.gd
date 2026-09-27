extends Control
## M4 settings screen (presentation only): Music / Sound / Haptics toggles.
##
## It emits change intents and renders supplied state; it never persists
## anything (AGENT-1 owns the settings store and the M4 cross-integration pass
## wires the save/load loop). The screen stays fully usable when Sound is OFF
## because it makes no audio calls.
##
## Toggle buttons are labelled explicitly (ON/OFF) as well as by state, so the
## control does not rely on color alone.

const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")

signal music_toggled(value: bool)
signal sound_toggled(value: bool)
signal haptics_toggled(value: bool)
signal closed

var _scrim: ColorRect = null
var _panel: Panel = null
var _title: Label = null
var _music: Button = null
var _sound: Button = null
var _haptics: Button = null
var _back: Button = null

var _music_on := true
var _sound_on := true
var _haptics_on := true

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
	_title.text = Strings.text(&"ui.settings")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", Style.FONT_HEADING)
	_title.add_theme_color_override("font_color", Style.TEXT)
	_panel.add_child(_title)

	_music = _make_toggle("MusicToggle")
	_music.pressed.connect(_on_music_pressed)
	_sound = _make_toggle("SoundToggle")
	_sound.pressed.connect(_on_sound_pressed)
	_haptics = _make_toggle("HapticsToggle")
	_haptics.pressed.connect(_on_haptics_pressed)

	_back = Button.new()
	_back.name = "BackButton"
	_back.text = Strings.text(&"ui.back")
	Style.apply_button(_back, &"primary")
	_back.pressed.connect(_on_back_pressed)
	_panel.add_child(_back)

	_refresh_labels()


## Applies the supplied state to the controls (inbound path; no intent emitted).
func set_state(music: bool, sound: bool, haptics: bool) -> void:
	_music_on = music
	_sound_on = sound
	_haptics_on = haptics
	_refresh_labels()


func music_enabled() -> bool:
	return _music_on


func sound_enabled() -> bool:
	return _sound_on


func haptics_enabled() -> bool:
	return _haptics_on


# --- intent helpers (buttons and tests share one path) ----------------------

func press_music() -> void:
	_on_music_pressed()


func press_sound() -> void:
	_on_sound_pressed()


func press_haptics() -> void:
	_on_haptics_pressed()


func press_back() -> void:
	_on_back_pressed()


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


func layout_for(viewport: Vector2) -> void:
	size = viewport
	_viewport = viewport
	_refresh_layout()


func _make_toggle(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	Style.apply_button(button, &"neutral")
	_panel.add_child(button)
	return button


func _refresh_labels() -> void:
	_music.text = "%s: %s" % [Strings.text(&"ui.music"), _state_word(_music_on)]
	_sound.text = "%s: %s" % [Strings.text(&"ui.sound"), _state_word(_sound_on)]
	_haptics.text = "%s: %s" % [Strings.text(&"ui.haptics"), _state_word(_haptics_on)]


func _state_word(value: bool) -> String:
	return Strings.text(&"ui.on") if value else Strings.text(&"ui.off")


func _refresh_layout() -> void:
	if _panel == null:
		return
	var column := Style.column_width(_viewport.x)
	var panel_w := maxf(column - Style.SAFE * 2.0, 1.0)
	var title_h := 96.0
	var controls := [_music, _sound, _haptics, _back]
	var content_h := Style.SAFE * 2.0 + title_h + Style.SPACING \
		+ float(controls.size()) * Style.TOUCH_TARGET \
		+ float(maxi(controls.size() - 1, 0)) * Style.SPACING
	var panel_h := maxf(content_h, 1.0)
	var top_bound := Style.SAFE
	var bottom_bound := maxf(_viewport.y - Style.SAFE, top_bound)
	var y := clampf(_viewport.y * 0.5 - panel_h * 0.5, top_bound, maxf(bottom_bound - panel_h, top_bound))
	_panel.position = Vector2((_viewport.x - panel_w) * 0.5, y)
	_panel.size = Vector2(panel_w, panel_h)

	var inner_w := panel_w - Style.SAFE * 2.0
	_title.position = Vector2(Style.SAFE, Style.SAFE)
	_title.size = Vector2(inner_w, title_h)
	var cursor := Style.SAFE + title_h + Style.SPACING
	for control: Variant in controls:
		var button: Button = control
		button.position = Vector2(Style.SAFE, cursor)
		button.size = Vector2(inner_w, Style.TOUCH_TARGET)
		cursor += Style.TOUCH_TARGET + Style.SPACING


func _on_music_pressed() -> void:
	_music_on = not _music_on
	_refresh_labels()
	music_toggled.emit(_music_on)


func _on_sound_pressed() -> void:
	_sound_on = not _sound_on
	_refresh_labels()
	sound_toggled.emit(_sound_on)


func _on_haptics_pressed() -> void:
	_haptics_on = not _haptics_on
	_refresh_labels()
	haptics_toggled.emit(_haptics_on)


func _on_back_pressed() -> void:
	closed.emit()
