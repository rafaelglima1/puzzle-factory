extends Control
## Traffic board presentation controller (AGENT-2-owned).
##
## Composition root for the Traffic presentation API consumed by the AGENT-1
## Traffic product adapter (`game/integration/traffic/**`). It owns views,
## effects, audio/haptic hooks and the cosmetic input gate, and maps the official
## M1 domain-event shape (`entity_placed`, `entity_move_started`, `entity_moved`,
## `entity_blocked`, `command_rejected`) onto those views.
##
## Hard rules (blueprint §8.2, ADR-003):
## - It NEVER decides correctness: no occupancy, validation, matching, queue,
##   capacity, staging, win or loss logic.
## - It NEVER imports `game/core/**` or `game/puzzle/**`; it consumes plain
##   JSON-safe event payloads, so the AGENT-1 adapter bridges domain events in.
## - It never mutates simulation state and never blocks the simulation.
##
## M2 additive events (item_loaded, match_occurred, staging_changed,
## objective_completed, game_completed, game_failed) are exposed as
## presentation hooks; unknown events are ignored safely.

const BoardData := preload("res://themes/traffic/model_board_view_data.gd")
const EntityData := preload("res://themes/traffic/model_entity_view_data.gd")
const DestinationData := preload("res://themes/traffic/model_destination_view_data.gd")
const StagingData := preload("res://themes/traffic/model_staging_view_data.gd")

const BoardViewScript := preload("res://themes/traffic/components/board_view.gd")
const StagingViewScript := preload("res://themes/traffic/components/staging_view.gd")
const HudShellScript := preload("res://themes/traffic/components/hud_shell.gd")
const BlockedIndicatorScript := preload("res://themes/traffic/components/blocked_indicator.gd")
const MovementControllerScript := preload("res://themes/traffic/components/movement_tween_controller.gd")
const MatchEffectScript := preload("res://themes/traffic/components/match_effect.gd")
const CompletionEffectScript := preload("res://themes/traffic/components/completion_effect.gd")
const FailureEffectScript := preload("res://themes/traffic/components/failure_effect.gd")
const InputGateScript := preload("res://ui/input_gate.gd")
const HapticServiceScript := preload("res://haptics/haptic_service.gd")
const PresentationAudioScript := preload("res://audio/presentation_audio.gd")
const AudioContractScript := preload("res://audio/audio_contract.gd")
const RouterScript := preload("res://themes/traffic/bridge/presentation_event_router.gd")

signal entity_presented(entity_id: StringName)
signal objective_presented(objective_id: StringName)
signal sequence_finished(kind: StringName)
signal event_ignored(event_type: StringName)

const LOCK_OWNER_MOVE := &"entity_move"
const LOCK_OWNER_RESULT := &"result_sequence"
const MOVE_LOCK_CAP := 0.6
const RESULT_LOCK_CAP := 2.0
const MAX_DURATION_WIN := 2.0
const MAX_DURATION_FAIL := 1.5

const SAFE_MARGIN := 24.0
const HUD_BAND := 120.0
const STAGING_BAND := 140.0
const MAX_BOARD_WIDTH := 720.0

var board_view: BoardViewScript = null
var staging_view: StagingViewScript = null
var hud_shell: HudShellScript = null
var effects_layer: Node2D = null
var input_gate: InputGateScript = null
var haptics: HapticServiceScript = null
var audio: PresentationAudioScript = null
var router: RouterScript = null

## Debug-only: last rejected command (never surfaced to users as raw codes).
var last_rejection: Dictionary = {}
var last_blocked_duration: float = 0.0

var _movement_controller: MovementControllerScript = null
var _movement_active := false
var _movement_has_target := false
var _movement_entity_id: StringName = &""
var _movement_target_cell := Vector2i.ZERO
var _active_effect: Node2D = null
var _active_sequence: StringName = &""
var _blocker_ids: Array[StringName] = []
var _blocker_flash_remaining := 0.0
var _built := false


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true

	input_gate = InputGateScript.new()
	input_gate.set_max_lock(RESULT_LOCK_CAP)
	haptics = HapticServiceScript.new()
	audio = PresentationAudioScript.new()
	router = RouterScript.new()

	board_view = BoardViewScript.new()
	board_view.name = "BoardView"
	add_child(board_view)

	staging_view = StagingViewScript.new()
	staging_view.name = "StagingView"
	add_child(staging_view)

	hud_shell = HudShellScript.new()
	hud_shell.name = "HudShell"
	add_child(hud_shell)

	effects_layer = Node2D.new()
	effects_layer.name = "EffectsLayer"
	add_child(effects_layer)

	_movement_controller = MovementControllerScript.new()
	_movement_controller.name = "MovementController"
	add_child(_movement_controller)
	_movement_controller.finished.connect(_on_movement_finished)

	set_process(true)


# --- Setup -----------------------------------------------------------------

func setup(board_data: BoardData) -> void:
	_ensure_built()
	board_view.set_board_data(board_data)


func layout_for(viewport_size: Vector2) -> void:
	_ensure_built()
	size = viewport_size
	var content_width := maxf(viewport_size.x - SAFE_MARGIN * 2.0, 1.0)
	hud_shell.position = Vector2(SAFE_MARGIN, SAFE_MARGIN)
	hud_shell.size = Vector2(content_width, HUD_BAND)
	staging_view.position = Vector2(SAFE_MARGIN, maxf(viewport_size.y - STAGING_BAND - SAFE_MARGIN, 0.0))
	staging_view.size = Vector2(content_width, STAGING_BAND)
	var stage_height := viewport_size.y - HUD_BAND - STAGING_BAND - SAFE_MARGIN * 3.0
	board_view.layout_for_size(Vector2(content_width, maxf(stage_height, 1.0)), 0.0, MAX_BOARD_WIDTH)
	board_view.position += Vector2(SAFE_MARGIN, SAFE_MARGIN + HUD_BAND + SAFE_MARGIN)


func set_objectives(color_keys: Array) -> void:
	_ensure_built()
	hud_shell.set_objective_chips(color_keys)


# --- Entity presentation ----------------------------------------------------

func show_entity(entity_data: EntityData) -> Node2D:
	_ensure_built()
	var view: Node2D = board_view.add_or_update_entity(entity_data)
	entity_presented.emit(entity_data.id)
	return view


func set_entity_state(entity_id: StringName, state: StringName) -> void:
	_ensure_built()
	var key := StringName(state)
	board_view.set_entity_selected(entity_id, key == &"selected")
	board_view.set_entity_blocked(entity_id, key == &"blocked")


func set_entity_selected(entity_id: StringName, on: bool) -> bool:
	_ensure_built()
	return board_view.set_entity_selected(entity_id, on)


func set_entity_blocked(entity_id: StringName, on: bool) -> bool:
	_ensure_built()
	return board_view.set_entity_blocked(entity_id, on)


func remove_entity(entity_id: StringName) -> bool:
	_ensure_built()
	return board_view.remove_entity(entity_id)


## Interpolates along an externally supplied cell path. Never validates it.
func animate_path(entity_id: StringName, path_cells: Array, max_duration: float = -1.0) -> float:
	_ensure_built()
	var view: Node2D = board_view.entity_view(entity_id)
	if view == null or path_cells.is_empty():
		return 0.0
	var points := PackedVector2Array()
	var last_cell := Vector2i.ZERO
	for cell: Variant in path_cells:
		if cell is Vector2i:
			last_cell = cell
			points.append(board_view.cell_center(cell))
		elif cell is Vector2:
			last_cell = Vector2i(cell)
			points.append(board_view.cell_center(last_cell))
	if points.is_empty():
		return 0.0
	_movement_target_cell = last_cell
	_movement_entity_id = entity_id
	_movement_has_target = true
	var duration: float = _movement_controller.move_along(view, points, max_duration)
	_movement_active = duration > 0.0
	if _movement_active:
		input_gate.request(LOCK_OWNER_MOVE, &"move_animation", duration)
	return duration


func show_blocked(entity_id: StringName, axis: Vector2 = Vector2.RIGHT, blocker_ids: Array = []) -> float:
	_ensure_built()
	var view: Node2D = board_view.entity_view(entity_id)
	var indicator: Node2D = BlockedIndicatorScript.new()
	indicator.name = "BlockedIndicator"
	add_child(indicator)
	if view != null:
		indicator.position = board_view.position + view.position
	indicator.connect(&"finished", func() -> void: indicator.queue_free())
	last_blocked_duration = indicator.play(axis)
	_flash_blockers(blocker_ids)
	haptics.trigger(HapticServiceScript.WARNING)
	audio.play(AudioContractScript.SFX_BLOCKED_MOVE)
	return last_blocked_duration


## Generic invalid-action feedback. Raw status/code are kept for debug only and
## are never shown to users (blueprint §58).
func show_command_rejected(entity_id: StringName, status: StringName, code: StringName) -> void:
	_ensure_built()
	last_rejection = {"entity_id": String(entity_id), "status": String(status), "code": String(code)}
	var view: Node2D = board_view.entity_view(entity_id) if entity_id != &"" else null
	if view != null:
		var indicator: Node2D = BlockedIndicatorScript.new()
		indicator.name = "RejectedIndicator"
		add_child(indicator)
		indicator.position = board_view.position + view.position
		indicator.connect(&"finished", func() -> void: indicator.queue_free())
		indicator.play(Vector2.RIGHT, BlockedIndicatorScript.MAX_DURATION)
	audio.play(AudioContractScript.SFX_BLOCKED_MOVE)


# --- Destination / queue ----------------------------------------------------

func set_destination(destination_data: DestinationData) -> Node2D:
	_ensure_built()
	return board_view.add_or_update_destination(destination_data)


func remove_destination(destination_id: StringName) -> bool:
	_ensure_built()
	return board_view.remove_destination(destination_id)


func set_queue(destination_id: StringName, color_keys: Array) -> bool:
	_ensure_built()
	return board_view.set_destination_queue(destination_id, color_keys)


# --- Staging ----------------------------------------------------------------

func set_staging(staging_data: StagingData) -> void:
	_ensure_built()
	staging_view.set_staging_data(staging_data)


func set_staging_pressure(state: StringName) -> void:
	_ensure_built()
	staging_view.set_pressure(state)


# --- Loading / matching -----------------------------------------------------

func show_item_loaded(destination_id: StringName, color_key: StringName = &"COLOR_A") -> bool:
	_ensure_built()
	var view: Node2D = board_view.destination_view(destination_id)
	if view == null:
		return false
	_spawn_match_at(board_view.position + view.position, color_key)
	audio.play(AudioContractScript.SFX_LOADING)
	return true


func show_match(target_id: StringName, color_key: StringName = &"") -> bool:
	_ensure_built()
	var view: Node2D = board_view.entity_view(target_id)
	var resolved_key := color_key
	if view == null:
		view = board_view.destination_view(target_id)
	if view == null:
		return false
	if resolved_key == &"":
		var data: Variant = view.get_data()
		resolved_key = data.color_key if data != null and "color_key" in data else &"COLOR_A"
	_spawn_match_at(board_view.position + view.position, resolved_key)
	haptics.trigger(HapticServiceScript.LIGHT)
	audio.play(AudioContractScript.SFX_MATCH)
	return true


func show_objective_complete(objective_id: StringName = &"") -> bool:
	_ensure_built()
	hud_shell.flash_objective()
	objective_presented.emit(objective_id)
	return true


# --- Win / fail -------------------------------------------------------------

func show_win(max_duration: float = MAX_DURATION_WIN) -> float:
	_ensure_built()
	_clear_active_effect()
	var effect: Node2D = CompletionEffectScript.new()
	effect.name = "CompletionEffect"
	effects_layer.add_child(effect)
	effect.position = _center()
	_active_effect = effect
	_active_sequence = &"win"
	effect.connect(&"finished", _on_sequence_finished.bind(&"win"))
	var duration: float = effect.call(&"play", clampf(max_duration, 0.2, MAX_DURATION_WIN))
	input_gate.request(LOCK_OWNER_RESULT, &"win_sequence", duration)
	haptics.trigger(HapticServiceScript.SUCCESS)
	audio.play(AudioContractScript.SFX_LEVEL_COMPLETE)
	return duration


func show_fail(fail_reason: StringName = &"", max_duration: float = MAX_DURATION_FAIL) -> float:
	_ensure_built()
	_clear_active_effect()
	var effect: Node2D = FailureEffectScript.new()
	effect.name = "FailureEffect"
	effects_layer.add_child(effect)
	effect.position = _center()
	_active_effect = effect
	_active_sequence = &"fail"
	effect.connect(&"finished", _on_sequence_finished.bind(&"fail"))
	var duration: float = effect.call(&"play", fail_reason, clampf(max_duration, 0.2, MAX_DURATION_FAIL))
	input_gate.request(LOCK_OWNER_RESULT, &"fail_sequence", duration)
	haptics.trigger(HapticServiceScript.WARNING)
	audio.play(AudioContractScript.SFX_LEVEL_FAIL)
	return duration


func fail_reason_localization_key(fail_reason: StringName) -> StringName:
	return FailureEffectScript.localization_key_for(fail_reason)


func skip_active_sequence() -> bool:
	if _active_effect == null:
		return false
	var skipped: Variant = _active_effect.call(&"skip")
	return skipped == true


func active_sequence() -> StringName:
	return _active_sequence


# --- Event mapping (official M1 contract) -----------------------------------

## Maps one official-shaped event (generic names, JSON-safe payload) onto the
## presentation API. Returns false for unknown events (ignored safely).
## `entity_provider` (optional) resolves richer presentation DTOs by entity id,
## since M1 payloads carry no theme color/type.
func handle_event(event_type: StringName, payload: Dictionary, entity_provider: Callable = Callable()) -> bool:
	_ensure_built()
	match event_type:
		RouterScript.ENTITY_PLACED:
			var placed_id := RouterScript.payload_entity_id(payload)
			show_entity(_resolve_entity(placed_id, payload, entity_provider))
			return true
		RouterScript.ENTITY_MOVE_STARTED:
			var started_id := RouterScript.payload_entity_id(payload)
			animate_path(started_id, [
				RouterScript.payload_position(payload, "from"),
				RouterScript.payload_position(payload, "to"),
			])
			return true
		RouterScript.ENTITY_MOVED:
			var moved_id := RouterScript.payload_entity_id(payload)
			board_view.move_entity_to(moved_id, RouterScript.payload_position(payload, "to"))
			_release_move_lock()
			return true
		RouterScript.ENTITY_BLOCKED:
			var blocked_id := RouterScript.payload_entity_id(payload)
			var target := RouterScript.payload_position(payload, "target")
			show_blocked(blocked_id, _axis_toward(blocked_id, target), RouterScript.payload_blockers(payload))
			return true
		RouterScript.COMMAND_REJECTED:
			show_command_rejected(
				RouterScript.payload_entity_id(payload),
				RouterScript.payload_status(payload),
				RouterScript.payload_code(payload)
			)
			return true
		_:
			event_ignored.emit(event_type)
			return false


## Subscribes the presenter to a router's official M1 events.
func bind_router(router_instance: RouterScript, entity_provider: Callable = Callable()) -> void:
	for event_type in RouterScript.M1_EVENTS:
		router_instance.subscribe(
			event_type,
			func(name: StringName, payload: Dictionary) -> void:
				handle_event(name, payload, entity_provider)
		)


# --- Frame driving ----------------------------------------------------------

func advance(delta: float) -> void:
	if not _built:
		return
	if input_gate.is_locked():
		input_gate.tick(delta)
	hud_shell.advance(delta)
	_tick_blocker_flash(delta)
	if not is_inside_tree():
		if _movement_active:
			_movement_controller.update(delta)
		if _active_effect != null:
			_active_effect.call(&"update", delta)


func _process(delta: float) -> void:
	advance(delta)


# --- Input lock / teardown --------------------------------------------------

func is_input_locked() -> bool:
	return _built and input_gate.is_locked()


func input_lock_remaining() -> float:
	return input_gate.remaining() if _built else 0.0


func teardown() -> void:
	if not _built:
		return
	input_gate.release_all()
	_movement_controller.stop()
	_movement_active = false
	_active_effect = null
	_active_sequence = &""
	_blocker_ids.clear()
	_blocker_flash_remaining = 0.0
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_built = false


# --- Internals --------------------------------------------------------------

func _ensure_built() -> void:
	if not _built:
		build()


func _center() -> Vector2:
	return size * 0.5


func _resolve_entity(entity_id: StringName, payload: Dictionary, provider: Callable) -> EntityData:
	if provider.is_valid():
		var provided: Variant = provider.call(entity_id, payload)
		if provided is EntityData:
			return provided
	var data: EntityData = EntityData.new(entity_id)
	if payload.has("position"):
		data.cell = RouterScript.payload_position(payload, "position")
	data.footprint = RouterScript.payload_footprint(payload)
	return data


func _axis_toward(entity_id: StringName, target: Vector2i) -> Vector2:
	var view: Node2D = board_view.entity_view(entity_id)
	if view == null:
		return Vector2.RIGHT
	var data: EntityData = view.get_data()
	if data == null:
		return Vector2.RIGHT
	var delta := target - data.cell
	if delta == Vector2i.ZERO:
		return Vector2.RIGHT
	return Vector2(float(delta.x), float(delta.y)).normalized()


func _on_movement_finished(_target: Variant = null) -> void:
	if _movement_has_target:
		# Correct harmless visual drift to the authoritative supplied target.
		board_view.move_entity_to(_movement_entity_id, _movement_target_cell)
		_movement_has_target = false
	_movement_entity_id = &""
	_movement_active = false
	_release_move_lock()


func _release_move_lock() -> void:
	if _built:
		input_gate.release(LOCK_OWNER_MOVE)


func _on_sequence_finished(kind: StringName) -> void:
	var effect := _active_effect
	_active_effect = null
	_active_sequence = &""
	if effect != null:
		effect.queue_free()
	input_gate.release(LOCK_OWNER_RESULT)
	sequence_finished.emit(kind)


func _clear_active_effect() -> void:
	if _active_effect != null:
		var effect := _active_effect
		_active_effect = null
		effect.queue_free()
	_active_sequence = &""
	input_gate.release(LOCK_OWNER_RESULT)


func _spawn_match_at(world_position: Vector2, color_key: StringName) -> void:
	var effect: Node2D = MatchEffectScript.new()
	effect.name = "MatchEffect"
	effects_layer.add_child(effect)
	effect.connect(&"finished", func() -> void: effect.queue_free())
	effect.call(&"play", world_position, color_key)


func _flash_blockers(blocker_ids: Array) -> void:
	_blocker_ids.clear()
	for blocker: Variant in blocker_ids:
		var id := StringName(str(blocker))
		if board_view.set_entity_blocked(id, true):
			_blocker_ids.append(id)
	if not _blocker_ids.is_empty():
		_blocker_flash_remaining = BlockedIndicatorScript.MAX_DURATION


func _tick_blocker_flash(delta: float) -> void:
	if _blocker_flash_remaining <= 0.0:
		return
	_blocker_flash_remaining = maxf(_blocker_flash_remaining - delta, 0.0)
	if _blocker_flash_remaining <= 0.0:
		for id in _blocker_ids:
			board_view.set_entity_blocked(id, false)
		_blocker_ids.clear()
