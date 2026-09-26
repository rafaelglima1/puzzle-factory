extends Control
## DEV-ONLY responsive presentation sandbox for the Traffic theme (AGENT-2).
##
## Purpose: open this scene in the editor (or instantiate + call build() in a
## headless check) to eyeball the scaffold: board, entity orientations,
## color/symbol groups, staging sizes, destination, queue, HUD and the win/fail
## effect hooks.
##
## It is NOT the production boot scene. `game/project.godot` startup is
## intentionally untouched. It uses mock data from dev/ only.

const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")
const BoardViewScript := preload("res://themes/traffic/components/board_view.gd")
const StagingViewScript := preload("res://themes/traffic/components/staging_view.gd")
const HudShellScript := preload("res://themes/traffic/components/hud_shell.gd")
const MatchEffectScript := preload("res://themes/traffic/components/match_effect.gd")
const CompletionEffectScript := preload("res://themes/traffic/components/completion_effect.gd")
const FailureEffectScript := preload("res://themes/traffic/components/failure_effect.gd")
const MovementControllerScript := preload("res://themes/traffic/components/movement_tween_controller.gd")
const BlockedIndicatorScript := preload("res://themes/traffic/components/blocked_indicator.gd")
const PaletteScript := preload("res://themes/traffic/traffic_palette.gd")

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)
const SAFE_MARGIN := 24.0
const HUD_BAND := 120.0
const STAGING_BAND := 140.0
const MAX_BOARD_WIDTH := 720.0

var board_view: Control = null
var staging_view: Control = null
var hud_shell: Control = null
var effects_layer: Node2D = null

var _palette: PaletteScript = PaletteScript.new()
var _viewport_size := REFERENCE_SIZE


func _ready() -> void:
	build()
	layout_for(size if size.x > 0.0 else REFERENCE_SIZE)


func build() -> void:
	_clear_built()

	hud_shell = HudShellScript.new()
	hud_shell.name = "HudShell"
	add_child(hud_shell)

	board_view = BoardViewScript.new()
	board_view.name = "BoardView"
	board_view.set_board_data(Mock.sample_board())
	add_child(board_view)

	staging_view = StagingViewScript.new()
	staging_view.name = "StagingView"
	staging_view.set_staging_data(Mock.sample_staging(4))
	add_child(staging_view)

	effects_layer = Node2D.new()
	effects_layer.name = "EffectsLayer"
	add_child(effects_layer)

	hud_shell.set_level_text("MOCK LEVEL")
	hud_shell.set_score_text("0")
	hud_shell.set_objective_chips([&"COLOR_A", &"COLOR_B", &"COLOR_C", &"COLOR_D"])


## Deterministic responsive layout for an explicit viewport size. Safe to call
## headlessly (no viewport required).
func layout_for(viewport_size: Vector2) -> void:
	if board_view == null:
		return
	_viewport_size = viewport_size
	var content_width := maxf(viewport_size.x - SAFE_MARGIN * 2.0, 1.0)

	hud_shell.position = Vector2(SAFE_MARGIN, SAFE_MARGIN)
	hud_shell.size = Vector2(content_width, HUD_BAND)

	staging_view.position = Vector2(SAFE_MARGIN, maxf(viewport_size.y - STAGING_BAND - SAFE_MARGIN, 0.0))
	staging_view.size = Vector2(content_width, STAGING_BAND)

	var stage_height := viewport_size.y - HUD_BAND - STAGING_BAND - SAFE_MARGIN * 3.0
	var board_available := Vector2(content_width, maxf(stage_height, 1.0))
	board_view.layout_for_size(board_available, 0.0, MAX_BOARD_WIDTH)
	board_view.position += Vector2(SAFE_MARGIN, SAFE_MARGIN + HUD_BAND + SAFE_MARGIN)


func set_staging_slots(count: int) -> void:
	if staging_view != null:
		staging_view.set_staging_data(Mock.sample_staging(count))


func set_staging_pressure(state: StringName) -> void:
	if staging_view != null:
		staging_view.set_pressure(state)


func demo_select(entity_id: StringName) -> bool:
	var view: Node2D = _entity_view(entity_id)
	if view == null:
		return false
	view.set_selected(true)
	return true


func demo_block(entity_id: StringName, axis: Vector2 = Vector2.RIGHT) -> bool:
	var view: Node2D = _entity_view(entity_id)
	if view == null:
		return false
	view.set_blocked(true)
	var flash: Node2D = BlockedIndicatorScript.new()
	add_child(flash)
	flash.finished.connect(func() -> void: flash.queue_free())
	flash.play(axis)
	return true


## Moves an entity along a cell path supplied by the caller (mock/demo only).
func demo_move(entity_id: StringName, cells: Array) -> bool:
	var view: Node2D = _entity_view(entity_id)
	if view == null:
		return false
	var points := PackedVector2Array()
	for cell: Variant in cells:
		points.append(Vector2(
			(float(cell.x) + 0.5) * board_view.cell_size,
			(float(cell.y) + 0.5) * board_view.cell_size
		))
	var controller: Node2D = MovementControllerScript.new()
	add_child(controller)
	controller.finished.connect(func(_target: Variant) -> void: controller.queue_free())
	controller.move_along(view, points, 0.4)
	return true


func demo_match(entity_id: StringName) -> bool:
	var view: Node2D = _entity_view(entity_id)
	if view == null:
		return false
	var effect: Node2D = MatchEffectScript.new()
	effects_layer.add_child(effect)
	effect.finished.connect(func() -> void: effect.queue_free())
	effect.play(board_view.position + view.position, view.color_key())
	return true


func demo_win() -> void:
	_spawn_effect(CompletionEffectScript.new(), "win")


func demo_fail(reason: StringName) -> void:
	var effect: Node2D = FailureEffectScript.new()
	effect.play(reason)
	effects_layer.add_child(effect)
	effect.finished.connect(func() -> void: effect.queue_free())


func palette_keys() -> Array:
	return _palette.all_keys()


func _spawn_effect(effect: Node2D, _tag: String) -> void:
	effect.position = _viewport_size * 0.5
	effects_layer.add_child(effect)
	effect.finished.connect(func() -> void: effect.queue_free())
	effect.play()


func _entity_view(entity_id: StringName) -> Node2D:
	if board_view == null:
		return null
	return board_view.entity_view(entity_id)


func _clear_built() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	board_view = null
	staging_view = null
	hud_shell = null
	effects_layer = null
