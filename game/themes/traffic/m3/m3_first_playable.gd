extends Control
## M3 first-playable presentation shell (Traffic). OWNER: AGENT-2.
##
## Orchestrates the player-facing screens and exposes player INTENTS as signals.
## It never decides gameplay: no unlock state, win/fail, valid moves, matching,
## next-level or progression logic. An integration controller drives it through
## the public `show_*` / `set_progress` / `get_traffic_presenter()` API.
##
## States (blueprint M3): MAIN_MENU, PLAYING, WIN_RESULT, FAIL_RESULT,
## DEBUG_LEVEL_SELECT.
##
## Debug gating: the level selector is only reachable when `debug_enabled` is
## true. It defaults to `OS.is_debug_build()`, so editor/Debug exports expose it
## while release exports do not (blueprint §67/§68). No project.godot or boot
## scene change is made here; the integration pass switches app startup.

const Style := preload("res://themes/traffic/m3/m3_style.gd")
const Strings := preload("res://themes/traffic/m3/m3_strings.gd")
const MainMenuScreenScript := preload("res://themes/traffic/m3/main_menu_screen.gd")
const GameplayScreenScript := preload("res://themes/traffic/m3/gameplay_screen.gd")
const ResultScreenScript := preload("res://themes/traffic/m3/result_screen.gd")
const DebugLevelSelectScript := preload("res://themes/traffic/m3/debug_level_select_screen.gd")
const PresenterScript := preload("res://themes/traffic/traffic_presenter.gd")

enum State { MAIN_MENU, PLAYING, WIN_RESULT, FAIL_RESULT, DEBUG_LEVEL_SELECT }

signal play_requested
signal entity_tapped(entity_id: StringName)
signal restart_requested
signal next_requested
signal menu_requested
signal debug_level_selected(level_index: int)

## Debug tooling gate. Production release builds hide the level selector.
var debug_enabled: bool = OS.is_debug_build()

var _state: int = State.MAIN_MENU
var _level_number := 1
var _total_levels := 10

var _bg: ColorRect = null
var _main_menu: MainMenuScreenScript = null
var _gameplay: GameplayScreenScript = null
var _result: ResultScreenScript = null
var _debug_select: DebugLevelSelectScript = null
var _built := false


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true

	# The shell is sized explicitly through `layout_for()`; normalizing anchors
	# avoids fighting the full-rect anchors of the scene root.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Style.BG
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_main_menu = MainMenuScreenScript.new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)

	_gameplay = GameplayScreenScript.new()
	_gameplay.name = "Gameplay"
	add_child(_gameplay)

	_result = ResultScreenScript.new()
	_result.name = "Result"
	add_child(_result)

	_debug_select = DebugLevelSelectScript.new()
	_debug_select.name = "DebugLevelSelect"
	add_child(_debug_select)

	_main_menu.play_pressed.connect(_on_play_pressed)
	_main_menu.level_select_pressed.connect(_on_level_select_pressed)
	_gameplay.entity_tapped.connect(_on_entity_tapped)
	_gameplay.restart_pressed.connect(_on_restart_pressed)
	_gameplay.menu_pressed.connect(_on_menu_pressed)
	_result.next_pressed.connect(_on_next_pressed)
	_result.retry_pressed.connect(_on_retry_pressed)
	_result.menu_pressed.connect(_on_menu_pressed)
	_debug_select.level_selected.connect(_on_debug_level_selected)
	_debug_select.close_pressed.connect(_on_debug_close_pressed)

	_apply_state()


# --- Public presentation API (driven by the integration controller) ---------

func show_main_menu() -> void:
	_ensure_built()
	_state = State.MAIN_MENU
	_main_menu.set_debug_visible(debug_enabled)
	_apply_state()


func show_playing(level_number: int, total_levels: int) -> void:
	_ensure_built()
	_level_number = maxi(level_number, 1)
	_total_levels = maxi(total_levels, 1)
	_gameplay.set_level_text(Strings.format_text(&"ui.level_n", [_level_number]))
	_state = State.PLAYING
	_apply_state()


func show_win_result(level_number: int, is_final_level: bool) -> void:
	_ensure_built()
	_level_number = maxi(level_number, 1)
	_result.show_win(_level_number, is_final_level, _total_levels)
	_state = State.WIN_RESULT
	_apply_state()


func show_fail_result(level_number: int, fail_reason: StringName) -> void:
	_ensure_built()
	_level_number = maxi(level_number, 1)
	var key: StringName = _gameplay.get_presenter().fail_reason_localization_key(StringName(fail_reason))
	_result.show_fail(_level_number, key, _total_levels)
	_state = State.FAIL_RESULT
	_apply_state()


func show_debug_level_select(level_entries: Array = []) -> bool:
	_ensure_built()
	if not debug_enabled:
		return false
	var entries := level_entries if not level_entries.is_empty() else default_debug_entries()
	if not _debug_select.show_entries(entries):
		return false
	_state = State.DEBUG_LEVEL_SELECT
	_apply_state()
	return true


func set_progress(level_number: int, total_levels: int) -> void:
	_ensure_built()
	_level_number = maxi(level_number, 1)
	_total_levels = maxi(total_levels, 1)
	if _state == State.PLAYING:
		_gameplay.set_level_text(Strings.format_text(&"ui.level_n", [_level_number]))


func get_traffic_presenter() -> PresenterScript:
	_ensure_built()
	return _gameplay.get_presenter()


## Default 10 debug entries (ZERO-BASED `index`: 0..9). Integration may supply
## richer entries via `show_debug_level_select`.
func default_debug_entries() -> Array:
	var entries: Array = []
	for index in 10:
		entries.append({"index": index, "label": Strings.format_text(&"ui.level_n", [index + 1])})
	return entries


func handle_tap_at(board_point: Vector2) -> StringName:
	_ensure_built()
	if _state != State.PLAYING:
		return &""
	return _gameplay.handle_tap_at(board_point)


# --- Intent helpers (used by buttons and tests) -----------------------------

func press_play() -> void:
	_ensure_built()
	play_requested.emit()


func press_restart() -> void:
	_ensure_built()
	restart_requested.emit()


func press_next() -> void:
	_ensure_built()
	next_requested.emit()


func press_retry() -> void:
	_ensure_built()
	restart_requested.emit()


func press_menu() -> void:
	_ensure_built()
	menu_requested.emit()


func press_level_select() -> void:
	_ensure_built()
	_on_level_select_pressed()


func press_debug_index(index: int) -> bool:
	_ensure_built()
	return _debug_select.select_index(index)


# --- State / accessors ------------------------------------------------------

func current_state() -> int:
	return _state


func state_name() -> StringName:
	match _state:
		State.MAIN_MENU:
			return &"MAIN_MENU"
		State.PLAYING:
			return &"PLAYING"
		State.WIN_RESULT:
			return &"WIN_RESULT"
		State.FAIL_RESULT:
			return &"FAIL_RESULT"
		State.DEBUG_LEVEL_SELECT:
			return &"DEBUG_LEVEL_SELECT"
	return &"UNKNOWN"


func main_menu_visible() -> bool:
	return _main_menu != null and _main_menu.visible


func gameplay_visible() -> bool:
	return _gameplay != null and _gameplay.visible


func result_visible() -> bool:
	return _result != null and _result.visible


func debug_select_visible() -> bool:
	return _debug_select != null and _debug_select.visible


func gameplay_level_text() -> String:
	return _gameplay.level_text() if _gameplay != null else ""


func result_title_text() -> String:
	return _result.title_text() if _result != null else ""


func result_message_text() -> String:
	return _result.message_text() if _result != null else ""


func result_next_visible() -> bool:
	return _result != null and _result.next_visible()


func result_retry_visible() -> bool:
	return _result != null and _result.retry_visible()


func result_menu_visible() -> bool:
	return _result != null and _result.menu_visible()


func debug_entry_count() -> int:
	return _debug_select.entry_count() if _debug_select != null else 0


func main_menu_level_select_visible() -> bool:
	return _main_menu != null and _main_menu.level_select_visible()


# --- Layout accessors (responsive validation / integration) -----------------

func board_rect() -> Rect2:
	return _gameplay.board_rect() if _gameplay != null else Rect2()


func staging_rect() -> Rect2:
	return _gameplay.staging_rect() if _gameplay != null else Rect2()


func header_buttons_rect() -> Rect2:
	return _gameplay.header_buttons_rect() if _gameplay != null else Rect2()


func result_panel_rect() -> Rect2:
	return _result.panel_rect() if _result != null else Rect2()


func debug_panel_rect() -> Rect2:
	return _debug_select.panel_rect() if _debug_select != null else Rect2()


# --- Lifecycle --------------------------------------------------------------

func layout_for(viewport: Vector2) -> void:
	_ensure_built()
	size = viewport
	_main_menu.layout_for(viewport)
	_gameplay.layout_for(viewport)
	_result.layout_for(viewport)
	_debug_select.layout_for(viewport)


func advance(delta: float) -> void:
	_ensure_built()
	_gameplay.advance(delta)


func teardown() -> void:
	if not _built:
		return
	_gameplay.teardown()
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_bg = null
	_main_menu = null
	_gameplay = null
	_result = null
	_debug_select = null
	_built = false


# --- Internals --------------------------------------------------------------

func _ensure_built() -> void:
	if not _built:
		build()


func _apply_state() -> void:
	if _main_menu != null:
		_main_menu.visible = _state == State.MAIN_MENU
	if _gameplay != null:
		_gameplay.visible = _state == State.PLAYING
	if _result != null:
		_result.visible = _state == State.WIN_RESULT or _state == State.FAIL_RESULT
	if _debug_select != null:
		_debug_select.visible = _state == State.DEBUG_LEVEL_SELECT


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_level_select_pressed() -> void:
	show_debug_level_select()


func _on_entity_tapped(entity_id: StringName) -> void:
	entity_tapped.emit(entity_id)


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_menu_pressed() -> void:
	menu_requested.emit()


func _on_next_pressed() -> void:
	next_requested.emit()


func _on_retry_pressed() -> void:
	restart_requested.emit()


func _on_debug_level_selected(index: int) -> void:
	debug_level_selected.emit(index)


func _on_debug_close_pressed() -> void:
	show_main_menu()
