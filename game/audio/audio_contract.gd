extends RefCounted
## Audio contract for Puzzle Factory presentation (blueprint §60).
##
## IMPORTANT (integration note): the Godot Audio Bus layout (Master -> Music,
## SFX, UI) lives in `game/project.godot`, which is AGENT-1/integration-owned.
## This scaffold therefore only declares the NAMES and routing rules. Adding
## the bus layout + real streams is an M4 integration step and requires editing
## the shared project file — documented in docs/TRAFFIC_PRESENTATION.md, not
## done here.

const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
const BUS_UI := &"UI"

const SFX_TAP := &"tap"
const SFX_VALID_MOVE := &"valid_move"
const SFX_BLOCKED_MOVE := &"blocked_move"
const SFX_LOADING := &"loading"
const SFX_MATCH := &"match"
const SFX_COMBO := &"combo"
const SFX_LEVEL_COMPLETE := &"level_complete"
const SFX_LEVEL_FAIL := &"level_fail"
const SFX_REWARD := &"reward"
const SFX_BUTTON := &"button"

const MUSIC_MENU := &"menu_loop"
const MUSIC_LEVEL := &"level_loop"

const _BUS_BY_SFX := {
	SFX_TAP: BUS_UI,
	SFX_BUTTON: BUS_UI,
	SFX_VALID_MOVE: BUS_SFX,
	SFX_BLOCKED_MOVE: BUS_SFX,
	SFX_LOADING: BUS_SFX,
	SFX_MATCH: BUS_SFX,
	SFX_COMBO: BUS_SFX,
	SFX_LEVEL_COMPLETE: BUS_SFX,
	SFX_LEVEL_FAIL: BUS_SFX,
	SFX_REWARD: BUS_SFX,
}


static func bus_for(sfx: StringName) -> StringName:
	return _BUS_BY_SFX.get(sfx, BUS_SFX)


static func is_known(sfx: StringName) -> bool:
	return _BUS_BY_SFX.has(sfx)


static func all_sfx() -> Array:
	var keys: Array = _BUS_BY_SFX.keys()
	keys.sort()
	return keys


static func expected_buses() -> Array:
	return [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI]
