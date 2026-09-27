class_name TrafficM3AppController
extends Node
## M3 production composition root — OWNER: AGENT-1 (product integration layer).
##
## This is the app entry point for Project Traffic. It is the ONLY place that
## knows both sides (ADR-013):
##
##   app boot -> this controller
##       owns -> M3 presentation shell (game/themes/traffic/m3, AGENT-2)
##       owns -> [TrafficFirstPlayableSession] (simulation + progress, AGENT-1)
##
## Responsibilities:
## - instantiate + lay out the shell and show the main menu;
## - bind the shell's real [TrafficPresenter] through the session
##   (router/adapter wiring stays in the M2/M3 contract);
## - translate shell INTENTS into session calls and session SIGNALS into shell
##   `show_*` calls (0-based index <-> 1-based level number conversions);
## - own product navigation (menu/play/next/retry) and the debug gate;
## - drive the shell for headless callers only (in-tree presenters self-drive).
##
## It contains NO puzzle correctness: no rules, no matching, no win/lose, no
## unlock computation beyond forwarding session results to the shell.
##
## Flow: boot -> MAIN_MENU -> Play -> session.play() -> level 1 or resumed
## unlocked level -> real shell tap -> entity_tapped -> session.dispatch_entity
## -> simulation/events -> adapter -> presenter -> Win/Fail -> result screen ->
## Retry/Next -> levels 1..10.

const SHELL_SCENE := preload("res://themes/traffic/m3/m3_first_playable.tscn")

## Persistence path for the M3 profile (tests inject a temporary path).
var progress_path: String = M3ProgressStore.DEFAULT_PATH
## Persistence path for the M4 presentation preferences (Music/Sound/Haptics).
## Separate document from the progress profile; tests inject a temporary path.
var presentation_settings_path: String = M4PresentationSettingsStore.DEFAULT_PATH
## Debug tooling gate applied to the shell. Defaults to the build type so the
## level selector is hidden in release exports (blueprint §67/§68).
var debug_enabled: bool = OS.is_debug_build()
## Viewport used when the controller is not inside a tree (headless tests).
var fallback_viewport: Vector2 = Vector2(1080, 1920)

var _shell: Node = null
var _session: TrafficFirstPlayableSession = null
## M4 player preferences. Owned here (the app composition root): presentation
## reads none of it directly and persistence imports none of the presentation.
var _settings: M4PresentationSettingsStore = null
var _last_settings_save_error: Error = OK
var _started := false
var _last_session_error: StringName = &""
var _last_unlock_notice := 0


func _ready() -> void:
	start()


func _exit_tree() -> void:
	shutdown()


# --- lifecycle -----------------------------------------------------------------

## Builds the shell, wires intents/signals and binds presentation. Idempotent.
func start() -> bool:
	if _started:
		return true
	# M4 preferences load before the shell is shown so the menu never flashes the
	# enabled defaults: the persisted values are applied to the shell (and through
	# it to the presenter) before the first screen appears, so a persisted OFF
	# choice can never emit a sound or a haptic. Missing/malformed files fall back
	# to defaults with a retained diagnostic — never a crash, never shown to the
	# player (M4 scope).
	_settings = M4PresentationSettingsStore.new(presentation_settings_path)
	_settings.load_settings()

	_shell = SHELL_SCENE.instantiate()
	if _shell == null:
		push_error("TrafficM3AppController: M3 shell scene failed to instantiate")
		return false
	_shell.name = "M3Shell"
	add_child(_shell)
	# `_ready` builds the shell when it enters a tree; headless callers are not
	# in a tree, so build explicitly (build() is idempotent).
	_shell.call("build")
	_shell.set("debug_enabled", debug_enabled)
	_shell.call(
		"apply_presentation_settings",
		_settings.music_enabled(),
		_settings.sound_enabled(),
		_settings.haptics_enabled()
	)

	_session = TrafficFirstPlayableSession.new(M3ProgressStore.new(progress_path))
	_wire()
	if not _session.bind_presentation(_shell.call("get_traffic_presenter")):
		push_error("TrafficM3AppController: presenter binding failed")
		_teardown()
		return false

	# Production start-up always initializes the shell through show_main_menu()
	# so debug visibility and state gating are deterministic.
	_shell.call("show_main_menu")
	_started = true
	_layout()
	if is_inside_tree():
		get_viewport().size_changed.connect(_on_viewport_resized)
	return true


## Releases session wiring and frees the shell. Safe to call more than once.
func shutdown() -> void:
	if _shell == null and _session == null:
		return
	_teardown()
	_started = false


## Shared teardown for both shutdown and a failed start (so a partially started
## controller never leaks the shell/session or the viewport subscription).
func _teardown() -> void:
	if is_inside_tree() and _shell != null and get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.disconnect(_on_viewport_resized)
	if _session != null:
		_session.dispose()
		_session = null
	if _shell != null:
		_shell.call("teardown")
		if _shell.get_parent() == self:
			remove_child(_shell)
		_shell.free()
		_shell = null


func is_started() -> bool:
	return _started


# --- accessors (tests / menus / level select) ----------------------------------

func get_shell() -> Node:
	return _shell


func get_session() -> TrafficFirstPlayableSession:
	return _session


func get_presenter() -> Variant:
	if _shell == null:
		return null
	return _shell.call("get_traffic_presenter")


func highest_unlocked_level() -> int:
	return _session.highest_unlocked_level() if _session != null else 1


func last_session_error() -> StringName:
	return _last_session_error


func last_unlock_notice() -> int:
	return _last_unlock_notice


## M4 presentation preferences store (read-only view for tests/diagnostics).
func get_settings_store() -> M4PresentationSettingsStore:
	return _settings


## Load diagnostic for the startup read (M4 never surfaces it to the player).
func last_settings_load_error() -> int:
	if _settings == null:
		return M4PresentationSettingsStore.LoadError.NONE
	return _settings.last_load_error


## Result of the most recent settings persistence attempt (OK when the last
## toggle wrote successfully or was a no-op).
func last_settings_save_error() -> Error:
	return _last_settings_save_error


## Frame drive for headless callers. In a tree the presenter self-drives
## through `_process`, so this is a no-op there (never double-advance).
func advance(delta: float) -> void:
	if not _started or _shell == null:
		return
	if is_inside_tree():
		return
	_shell.call("advance", delta)


## Explicit layout (tests and non-tree callers). Production also relayouts on
## viewport resize.
func layout_for(viewport: Vector2) -> void:
	fallback_viewport = viewport
	_layout()


# --- intent wiring (shell -> session) ------------------------------------------

func _wire() -> void:
	_shell.connect(&"play_requested", _on_play_requested)
	_shell.connect(&"entity_tapped", _on_entity_tapped)
	_shell.connect(&"restart_requested", _on_restart_requested)
	_shell.connect(&"next_requested", _on_next_requested)
	_shell.connect(&"menu_requested", _on_menu_requested)
	_shell.connect(&"debug_level_selected", _on_debug_level_selected)
	# M4: the shell already applied the player's choice to the runtime; the
	# controller only persists it. `settings_requested` is intentionally NOT
	# connected — the shell navigates the settings screen itself, and wiring it
	# here would double-fire that navigation.
	_shell.connect(&"music_enabled_changed", _on_music_enabled_changed)
	_shell.connect(&"sound_enabled_changed", _on_sound_enabled_changed)
	_shell.connect(&"haptics_enabled_changed", _on_haptics_enabled_changed)

	_session.level_started.connect(_on_level_started)
	_session.level_restarted.connect(_on_level_restarted)
	_session.level_won.connect(_on_level_won)
	_session.level_failed.connect(_on_level_failed)
	_session.progress_changed.connect(_on_progress_changed)
	_session.campaign_finished.connect(_on_campaign_finished)
	_session.session_error.connect(_on_session_error)


func _on_play_requested() -> void:
	_session.play()


func _on_entity_tapped(entity_id: StringName) -> void:
	_session.dispatch_entity(entity_id)


func _on_restart_requested() -> void:
	if _session.has_active_level():
		_session.restart_current_level()


func _on_next_requested() -> void:
	_session.next_level()


func _on_menu_requested() -> void:
	# Keep the single app-lifetime binding; just finish cosmetic feedback so the
	# menu (and the next level) never inherits a stale lock or sequence.
	_release_presenter_sequence()
	_shell.call("show_main_menu")


func _on_debug_level_selected(level_index: int) -> void:
	_session.debug_select_level(level_index)


# --- M4 settings persistence (shell intent -> store) ---------------------------

func _on_music_enabled_changed(value: bool) -> void:
	if _settings == null:
		return
	_record_settings_save(_settings.set_music_enabled(value))


func _on_sound_enabled_changed(value: bool) -> void:
	if _settings == null:
		return
	_record_settings_save(_settings.set_sound_enabled(value))


func _on_haptics_enabled_changed(value: bool) -> void:
	if _settings == null:
		return
	_record_settings_save(_settings.set_haptics_enabled(value))


## The store mutates memory first and then attempts the write, so a non-OK
## result means: runtime keeps the player's choice, disk may still hold the old
## value. M4 keeps the choice active and retains the error for diagnostics —
## never a crash, never a silent success claim, no retry queue (M10 owns robust
## persistence).
func _record_settings_save(error: Error) -> void:
	_last_settings_save_error = error
	if error != OK:
		push_warning("TrafficM3AppController: M4 presentation settings save failed (error %d)" % error)


# --- session wiring (session -> shell) -----------------------------------------

func _on_level_started(_level_index: int, _level_id: StringName) -> void:
	_show_playing()


func _on_level_restarted(_level_index: int, _level_id: StringName) -> void:
	_show_playing()


func _on_level_won(level_index: int, _level_id: StringName) -> void:
	var is_final_level := level_index + 1 >= _session.total_levels()
	_shell.call("show_win_result", _session.current_level_number(), is_final_level)


func _on_level_failed(_level_index: int, _level_id: StringName, fail_reason: StringName) -> void:
	_shell.call("show_fail_result", _session.current_level_number(), StringName(fail_reason))


func _on_progress_changed(highest_unlocked_level: int) -> void:
	# The M3 shell shows only the current level; unlock state is exposed through
	# highest_unlocked_level() for menus/level select (M3 has no unlock surface).
	_last_unlock_notice = highest_unlocked_level


func _on_campaign_finished() -> void:
	# Terminal state: keep the final win surface (is_final_level hides NEXT).
	_shell.call("show_win_result", _session.total_levels(), true)


func _on_session_error(code: StringName) -> void:
	_last_session_error = code


# --- internals -----------------------------------------------------------------

func _show_playing() -> void:
	_shell.call("show_playing", _session.current_level_number(), _session.total_levels())
	# The board DTO is created inside session.play()/start_level (presenter
	# setup), so layout must run after the level started to size the real board.
	_layout()


func _layout() -> void:
	if _shell == null:
		return
	var size := fallback_viewport
	if is_inside_tree():
		size = get_viewport().get_visible_rect().size
	_shell.call("layout_for", size)


func _on_viewport_resized() -> void:
	_layout()


func _release_presenter_sequence() -> void:
	var presenter: Variant = get_presenter()
	if presenter != null:
		presenter.call("skip_active_sequence")
