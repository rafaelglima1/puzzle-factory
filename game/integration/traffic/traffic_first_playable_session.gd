class_name TrafficFirstPlayableSession
extends RefCounted
## M3 first-playable session/orchestration — OWNER: AGENT-1.
##
## Owns the traffic first-playable flow for one running app: the current
## [Simulation], the current level index, unbounded/unlock progress, restart,
## next-level progression and the presentation binding. AGENT-2's UI shell owns
## all visuals; this layer owns no layout, no copy, no buttons, no juice,
## no coins/ads/boosters.
##
## Index conventions (tested at the boundaries):
## - `level_index` is 0-based (0..9) — the list index used by the catalogue.
## - `current_level_number()` is 1-based (1..10) — what the UI shows.
## - [M3ProgressStore] persists 1-based level NUMBERS and level ids.
##
## Per-command contract (M2 integration, must stay):
## `dispatch_entity()` runs `DispatchEntityCommand`, then
## `adapter.forward_result(result)` and, when a presenter is bound,
## `adapter.sync_authoritative_state(state, presenter)`. Presentation is never
## asked to compute gameplay.
##
## UI shell usage (see docs/M3_SESSION_CONTRACT.md):
## `session.bind_presentation(presenter)` → `presenter.layout_for(viewport)` →
## on tap `session.dispatch_entity(entity_id)` → presenter advances itself in
## tree (or `presenter.advance(delta)` headless).
##
## Router lifecycle: the session owns exactly one adapter/router pair for its
## lifetime; `unbind_presentation()` clears the router subscribers so the
## RefCounted wiring cycle is released.
##
## Persistence ownership (M3 resume requirement): the session OWNS progress
## initialization. Its constructor always calls `load_progress()` on the store
## it holds, so `TrafficFirstPlayableSession.new()` recovers the persisted
## profile and `play()` resumes at the highest unlocked level. Callers (AGENT-2
## UI) never call `load_progress()`; injecting a store only redefines the
## persistence path (tests/QA).
##
## Debug isolation: levels started through [method debug_select_level] still
## emit [signal level_won] but never write production progression (see
## [method is_debug_attempt]). `next_level()` from a debug level starts a normal
## attempt.

signal level_started(level_index: int, level_id: StringName)
signal level_restarted(level_index: int, level_id: StringName)
signal level_won(level_index: int, level_id: StringName)
signal level_failed(level_index: int, level_id: StringName, fail_reason: StringName)
signal progress_changed(highest_unlocked_level: int)
signal campaign_finished()
signal session_error(code: StringName)

## Error/notice codes emitted through [signal session_error].
const ERROR_INVALID_LEVEL_INDEX := &"invalid_level_index"
const ERROR_LEVEL_BUILD_FAILED := &"level_build_failed"
const ERROR_NO_ACTIVE_LEVEL := &"no_active_level"
const ERROR_LEVEL_NOT_WON := &"level_not_won"

var _progress: M3ProgressStore = null
var _adapter: TrafficPresentationAdapter = null
var _simulation: Simulation = null
var _presenter: Variant = null
var _level_index: int = -1
var _terminal_emitted := false
## True while the current attempt was started through [method debug_select_level]:
## debug attempts never write production progression.
var _debug_attempt := false


## The session OWNS progress initialization: it always recovers the persisted
## M3 profile for the store it holds (injected or created), so callers never
## have to call `load_progress()` themselves — `TrafficFirstPlayableSession.new()`
## is enough for the app-restart resume requirement. An injected store only
## redefines the persistence PATH (tests, QA).
func _init(progress: M3ProgressStore = null) -> void:
	_progress = progress if progress != null else M3ProgressStore.new()
	_progress.load_progress()
	_adapter = TrafficPresentationAdapter.new()


# --- level catalogue / state --------------------------------------------------

func total_levels() -> int:
	return M3LevelCatalogue.count()


func current_level_index() -> int:
	return _level_index


## 1-based level number; 0 when no level is active.
func current_level_number() -> int:
	if _level_index < 0:
		return 0
	return _level_index + 1


func current_level_id() -> StringName:
	if _level_index < 0:
		return &""
	return M3LevelCatalogue.level_id(_level_index)


func has_active_level() -> bool:
	return _simulation != null and _level_index >= 0


func get_simulation() -> Simulation:
	return _simulation


func get_state() -> GameState:
	return _simulation.get_state() if _simulation != null else null


func get_adapter() -> TrafficPresentationAdapter:
	return _adapter


func progress() -> M3ProgressStore:
	return _progress


## 1-based highest unlocked level number, clamped to the catalogue size.
func highest_unlocked_level() -> int:
	return clampi(_progress.highest_unlocked_level(), 1, maxi(total_levels(), 1))


func is_level_unlocked(level_index: int) -> bool:
	return clampi(level_index + 1, 1, maxi(total_levels(), 1)) <= highest_unlocked_level()


# --- flow ---------------------------------------------------------------------

## Main-menu Play: new players start at level 1, returning players continue at
## their highest unlocked level.
func play() -> bool:
	return start_level(highest_unlocked_level() - 1)


## Starts a level by 0-based index. Respects the unlock rule; use
## [method debug_select_level] for debug access to any level.
func start_level(level_index: int) -> bool:
	if level_index < 0 or level_index >= total_levels():
		session_error.emit(ERROR_INVALID_LEVEL_INDEX)
		return false
	if not is_level_unlocked(level_index):
		session_error.emit(ERROR_INVALID_LEVEL_INDEX)
		return false
	return _begin_level(level_index, false, false)


## DEBUG/DEVELOPER ONLY (blueprint M3 debug level select): starts any level
## regardless of unlock state. Production progression UI must use
## [method start_level] / [method play].
##
## Debug attempts are intentionally isolated from production progression: a
## debug-selected level still emits [signal level_won], but its win is never
## persisted and never unlocks anything. See [method is_debug_attempt].
func debug_select_level(level_index: int) -> bool:
	if level_index < 0 or level_index >= total_levels():
		session_error.emit(ERROR_INVALID_LEVEL_INDEX)
		return false
	return _begin_level(level_index, false, true)


## True while the active attempt came from [method debug_select_level].
## The M3 shell may use it to show a debug badge; it is not progression state.
func is_debug_attempt() -> bool:
	return _debug_attempt


## Rebuilds the current level from its original deterministic definition:
## move count, entities, queues, staging and completion reset. Progress and
## unlocks are untouched (a debug attempt stays a debug attempt).
func restart_current_level() -> bool:
	if not has_active_level():
		session_error.emit(ERROR_NO_ACTIVE_LEVEL)
		return false
	return _begin_level(_level_index, true, _debug_attempt)


## Only valid after a legitimate win. Starts the next level when one exists;
## at the final level emits [signal campaign_finished] and returns false
## (never indexes beyond the catalogue).
func next_level() -> bool:
	if not has_active_level():
		session_error.emit(ERROR_NO_ACTIVE_LEVEL)
		return false
	var state := get_state()
	if state == null or not state.is_won():
		session_error.emit(ERROR_LEVEL_NOT_WON)
		return false
	var next_index := _level_index + 1
	if next_index >= total_levels():
		campaign_finished.emit()
		return false
	# Advancing explicitly from a debug level starts a normal attempt.
	return _begin_level(next_index, false, false)


## The player's gameplay action. Returns null when no level is active.
func dispatch_entity(entity_id: StringName) -> CommandResult:
	if not has_active_level():
		session_error.emit(ERROR_NO_ACTIVE_LEVEL)
		return null
	var result := _simulation.execute(DispatchEntityCommand.new(entity_id))
	_adapter.forward_result(result)
	_sync_presentation()
	_evaluate_terminal()
	return result


# --- presentation seam ---------------------------------------------------------

## Binds a presentation target (the AGENT-2 presenter) through the adapter.
## Returns false when the target cannot bind. The caller keeps ownership of the
## presenter Node; this layer only drives it.
func bind_presentation(presenter: Variant) -> bool:
	if presenter == null:
		return false
	if not _adapter.bind_presenter(presenter, _entity_provider()):
		return false
	_presenter = presenter
	if has_active_level():
		_present_level()
	return true


## Clears the router subscribers and forgets the presenter (does not free it).
func unbind_presentation() -> void:
	if _adapter.router != null and _adapter.router.has_method("clear_subscribers"):
		_adapter.router.clear_subscribers()
	_presenter = null


func has_presentation() -> bool:
	return _presenter != null


## Authoritative refresh for the caller (e.g. after a resize or level rebuild).
func refresh_presentation() -> void:
	_sync_presentation()


## Primitive counters for a thin HUD (presentation formats them; it computes
## no gameplay).
func progress_snapshot() -> Dictionary:
	var state := get_state()
	if state == null:
		return {}
	return _adapter.build_progress_snapshot(state)


## Releases session-owned references. The presenter Node is NOT freed here.
func dispose() -> void:
	unbind_presentation()
	_simulation = null
	_level_index = -1
	_terminal_emitted = false
	_debug_attempt = false


# --- internals -----------------------------------------------------------------

func _begin_level(level_index: int, is_restart: bool, is_debug: bool) -> bool:
	var definition := M3LevelCatalogue.definition(level_index)
	if definition.is_empty():
		session_error.emit(ERROR_INVALID_LEVEL_INDEX)
		return false
	var simulation := TrafficGameFactory.build(definition)
	if simulation == null:
		session_error.emit(ERROR_LEVEL_BUILD_FAILED)
		return false

	_simulation = simulation
	_level_index = level_index
	_terminal_emitted = false
	_debug_attempt = is_debug

	_progress.set_last_selected_level(level_index + 1, total_levels())
	if _presenter != null:
		_present_level()

	if is_restart:
		level_restarted.emit(_level_index, current_level_id())
	else:
		level_started.emit(_level_index, current_level_id())
	return true


func _present_level() -> void:
	if _presenter == null or not has_active_level():
		return
	var state := get_state()
	_presenter.call("setup", _adapter.build_board_view(state))
	_presenter.call("set_objectives", _objective_color_keys(state))
	_sync_presentation()


func _sync_presentation() -> void:
	if _presenter == null or not has_active_level():
		return
	_adapter.sync_authoritative_state(get_state(), _presenter)


## Objective chip keys for the HUD: the accepted color keys of the level's
## stations (authoritative data; presentation only renders it).
func _objective_color_keys(state: GameState) -> Array:
	var keys: Array[StringName] = []
	for destination_id in state.destination_ids():
		var destination: Destination = state.destinations[destination_id]
		for color_key in destination.accepted_color_keys:
			if not keys.has(color_key):
				keys.append(color_key)
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var output: Array = []
	for color_key in keys:
		output.append(color_key)
	return output


## Presentation resolves richer entity DTOs through the adapter for the CURRENT
## simulation (looked up per call so level switches are picked up).
func _entity_provider() -> Callable:
	var session := self
	return func(entity_id: StringName, _payload: Dictionary) -> Variant:
		var state := session.get_state()
		if state == null:
			return null
		var entity: Entity = state.get_entity(entity_id)
		if entity == null:
			return null
		return session.get_adapter().build_entity_view(entity)


func _evaluate_terminal() -> void:
	if _terminal_emitted:
		return
	var state := get_state()
	if state == null:
		return
	if state.is_won():
		_terminal_emitted = true
		# Debug attempts are isolated from production progression: the win is
		# announced but never persisted and never unlocks anything.
		if not _debug_attempt:
			_progress.mark_level_completed(current_level_id(), current_level_number(), total_levels())
			_progress.save()
			progress_changed.emit(highest_unlocked_level())
		level_won.emit(_level_index, current_level_id())
		return
	if state.is_lost():
		_terminal_emitted = true
		level_failed.emit(_level_index, current_level_id(), state.fail_reason)
