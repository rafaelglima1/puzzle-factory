extends Control
## HUD visual shell (blueprint §5.2).
##
## Presentation-only: shows level/score text and objective chips (color +
## symbol). Text is supplied by the caller after localization resolution; this
## component never stores production copy (blueprint §58) and never computes
## objectives.

const ChipScript := preload("res://themes/traffic/components/hud_chip.gd")

const TOP_BAR_HEIGHT := 88.0
const OBJECTIVE_FLASH_DURATION := 0.9

var level_label: Label = null
var score_label: Label = null

var _root: VBoxContainer = null
var _chip_row: HBoxContainer = null
var _chips: Array = []
var _flash_remaining := 0.0


func _init() -> void:
	_build()


func set_level_text(text: String) -> void:
	if level_label != null:
		level_label.text = text


func set_score_text(text: String) -> void:
	if score_label != null:
		score_label.text = text


func set_objective_chips(color_keys: Array) -> void:
	for chip: Variant in _chips:
		if is_instance_valid(chip):
			_chip_row.remove_child(chip)
			chip.free()
	_chips.clear()
	for key: Variant in color_keys:
		var chip: Control = ChipScript.new()
		chip.set_color_key(StringName(key))
		_chip_row.add_child(chip)
		_chips.append(chip)


func chip_count() -> int:
	return _chips.size()


func chip_color_keys() -> Array:
	var keys: Array = []
	for chip: Variant in _chips:
		if is_instance_valid(chip):
			keys.append(chip.get_color_key())
	return keys


## Bounded objective-completion flash. Display only: it never evaluates
## objectives (blueprint §8.2). Returns the bounded duration.
func flash_objective(duration: float = OBJECTIVE_FLASH_DURATION) -> float:
	_flash_remaining = clampf(duration, 0.1, 2.0)
	_apply_flash()
	return _flash_remaining


func advance(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining = maxf(_flash_remaining - delta, 0.0)
	_apply_flash()


func is_flashing() -> bool:
	return _flash_remaining > 0.0


func _apply_flash() -> void:
	if _chip_row == null:
		return
	var strength := minf(_flash_remaining / OBJECTIVE_FLASH_DURATION, 1.0)
	_chip_row.modulate = Color(1.0 + 0.35 * strength, 1.0 + 0.22 * strength, 1.0, 1.0)


func _build() -> void:
	_root = VBoxContainer.new()
	_root.name = "HudRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0.0, TOP_BAR_HEIGHT)
	top_bar.add_theme_constant_override("separation", 12)

	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = ""
	top_bar.add_child(level_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = ""
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(score_label)

	_root.add_child(top_bar)

	_chip_row = HBoxContainer.new()
	_chip_row.name = "ObjectiveChipRow"
	_chip_row.add_theme_constant_override("separation", 8)
	_root.add_child(_chip_row)
