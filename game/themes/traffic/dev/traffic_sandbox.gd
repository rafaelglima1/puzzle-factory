extends Control
## DEV-ONLY responsive presentation sandbox for the Traffic theme (AGENT-2).
##
## Demonstrates the M2 presentation API with presentation-only demo data:
## entity placed / movement / blocked, queue + destination updates, staging
## 3/4/5/6 slots (normal/warning/full), item loading, match effect, objective
## flash, and the win / fail(STAGING_FULL, NO_VALID_MOVES) hooks.
##
## It is NOT the production boot scene: `game/project.godot` startup is
## intentionally untouched. Demo data lives under `dev/` only and reusable
## presentation components never reference it.

const PresenterScript := preload("res://themes/traffic/traffic_presenter.gd")
const Mock := preload("res://themes/traffic/dev/mock_presentation_state.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")

const REFERENCE_SIZE := Vector2(1080.0, 1920.0)

var presenter: PresenterScript = null
var board_view: Control = null
var staging_view: Control = null
var hud_shell: Control = null


func _ready() -> void:
	build()
	layout_for(size if size.x > 0.0 else REFERENCE_SIZE)


func build() -> void:
	_clear_built()
	presenter = PresenterScript.new()
	presenter.name = "Presenter"
	add_child(presenter)
	presenter.build()

	board_view = presenter.board_view
	staging_view = presenter.staging_view
	hud_shell = presenter.hud_shell

	presenter.setup(Mock.sample_board())
	presenter.set_staging(Mock.sample_staging(4))
	presenter.set_objectives([&"COLOR_A", &"COLOR_B", &"COLOR_C", &"COLOR_D"])
	hud_shell.set_level_text("MOCK LEVEL")
	hud_shell.set_score_text("0")


func layout_for(viewport_size: Vector2) -> void:
	if presenter == null:
		return
	presenter.layout_for(viewport_size)


# --- M1 event demos ---------------------------------------------------------

func demo_entity_placed(entity_data: Variant = null) -> bool:
	if presenter == null:
		return false
	var data: Variant = entity_data if entity_data != null else Mock.entity(
		&"e_spawned", EntityData.TYPE_VAN, &"COLOR_D", Vector2i(2, 8), 0.0
	)
	presenter.show_entity(data)
	return true


func demo_select(entity_id: StringName) -> bool:
	return presenter != null and presenter.set_entity_selected(entity_id, true)


func demo_block(entity_id: StringName, axis: Vector2 = Vector2.RIGHT) -> bool:
	if presenter == null:
		return false
	presenter.show_blocked(entity_id, axis, [&"e_compact_a"])
	return true


func demo_move(entity_id: StringName, cells: Array) -> float:
	if presenter == null:
		return 0.0
	return presenter.animate_path(entity_id, cells)


func demo_command_rejected(entity_id: StringName, status: StringName = &"invalid", code: StringName = &"no_op_move") -> bool:
	if presenter == null:
		return false
	presenter.show_command_rejected(entity_id, status, code)
	return true


# --- M2 additive demos ------------------------------------------------------

func demo_queue(destination_id: StringName, color_keys: Array) -> bool:
	return presenter != null and presenter.set_queue(destination_id, color_keys)


func demo_destination_update() -> bool:
	if presenter == null:
		return false
	presenter.set_destination(Mock.sample_destination())
	return true


func demo_staging_slots(slot_count: int) -> void:
	if presenter != null:
		presenter.set_staging(Mock.sample_staging(slot_count))


func demo_staging_pressure(state: StringName) -> void:
	if presenter != null:
		presenter.set_staging_pressure(state)


func demo_item_loaded(destination_id: StringName, color_key: StringName = &"COLOR_A") -> bool:
	return presenter != null and presenter.show_item_loaded(destination_id, color_key)


func demo_match(entity_id: StringName) -> bool:
	return presenter != null and presenter.show_match(entity_id)


func demo_objective_complete(objective_id: StringName = &"objective_mock") -> bool:
	return presenter != null and presenter.show_objective_complete(objective_id)


func demo_win() -> float:
	return presenter.show_win() if presenter != null else 0.0


func demo_fail(fail_reason: StringName) -> float:
	return presenter.show_fail(fail_reason) if presenter != null else 0.0


func demo_fail_staging_full() -> float:
	return demo_fail(&"STAGING_FULL")


func demo_fail_no_valid_moves() -> float:
	return demo_fail(&"NO_VALID_MOVES")


## Drives bounded effects/locks when the sandbox is used headlessly.
func advance(delta: float) -> void:
	if presenter != null:
		presenter.advance(delta)


func _clear_built() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	presenter = null
	board_view = null
	staging_view = null
	hud_shell = null
