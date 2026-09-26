# M3 Session Contract (AGENT-1 → AGENT-2)

> **Owner of the contract:** AGENT-1 (`game/integration/traffic/**`,
> `game/persistence/**`)
> **Consumer:** AGENT-2 M3 presentation shell (menus, play flow, result screens)
> **Status:** implemented in M3 (First Playable)
> **Authority:** `docs/MASTER_BLUEPRINT.md` M3, `docs/ARCHITECTURE.md`,
> `docs/PRESENTATION_BRIDGE.md`, ADR-013.
>
> The session layer owns the flow, levels and progression. It contains **no**
> visual layout, no buttons, no user-facing copy, no juice, no coins, no ads and
> no boosters. The shell owns all of that and must never compute gameplay.

## 1. Intents → session API

| UI intent | Session call |
|---|---|
| play requested (main menu Play) | `play() -> bool` (new player → level 1, returning → highest unlocked) |
| entity tapped | `dispatch_entity(entity_id: StringName) -> CommandResult` |
| restart requested | `restart_current_level() -> bool` |
| next requested (after a win) | `next_level() -> bool` |
| menu requested | shell-owned: leave gameplay via `unbind_presentation()` / `dispose()` |
| debug level selected | `debug_select_level(level_index: int) -> bool` (DEBUG/DEV ONLY; bypasses unlock and never writes progression) |

`start_level(level_index)` respects the unlock rule and is the production path.

**Progression resume is session-owned.** `TrafficFirstPlayableSession.new()`
loads the persisted M3 profile itself, so the shell must NOT call
`load_progress()` (and must not know about the save file at all):

```gdscript
var session := TrafficFirstPlayableSession.new()   # recovers persisted progress
session.play()                                      # fresh install -> level 1; returning -> highest unlocked
```

Injecting a store (`new(M3ProgressStore.new(path))`) only redefines the
persistence path (tests/QA); the session still performs the load.

**Debug isolation:** a level started through `debug_select_level()` still emits
`level_won`, but its win is never persisted and never unlocks anything
(`is_debug_attempt()` reports it). `restart_current_level()` keeps the debug
flag; `next_level()` from a debug level starts a normal (persisting) attempt.

## 2. Signals (stable, documented)

```gdscript
signal level_started(level_index: int, level_id: StringName)
signal level_restarted(level_index: int, level_id: StringName)
signal level_won(level_index: int, level_id: StringName)
signal level_failed(level_index: int, level_id: StringName, fail_reason: StringName)
signal progress_changed(highest_unlocked_level: int)
signal campaign_finished()                      # next_level() at level 10
signal session_error(code: StringName)          # see the ERROR_* constants
```

Error codes: `invalid_level_index`, `level_build_failed`, `no_active_level`,
`level_not_won`.

Terminal signals fire **exactly once per level attempt**; restart/start resets
that guard.

## 3. State for a thin UI

| Purpose | Session call |
|---|---|
| current list index (0-based) | `current_level_index() -> int` |
| current level number (1-based, 0 = none) | `current_level_number() -> int` |
| total levels | `total_levels() -> int` (= 10) |
| current level id | `current_level_id() -> StringName` |
| progress/unlock | `highest_unlocked_level() -> int`, `is_level_unlocked(index) -> bool` |
| authoritative gameplay state | `get_state() -> GameState` (`is_won()`, `is_lost()`, `fail_reason`) |
| HUD counters (primitive) | `progress_snapshot() -> Dictionary` |
| progress store (persistence) | `progress() -> M3ProgressStore` |

`progress_snapshot()` returns
`queued_passengers, completed_vehicles, waiting_vehicles, staging_occupied,
staging_slots, completion_state, fail_reason, move_count`.

The shell formats and localizes; the session supplies data only. Result copy for
failures comes from the presenter's
`fail_reason_localization_key(fail_reason)` — the canonical machine ids are the
simulation's lowercase ids (`staging_full`, `no_valid_moves`).

## 4. Presentation binding (exact order matters)

```gdscript
# AGENT-2 shell, per level screen
var session := TrafficFirstPlayableSession.new(progress_store)   # AGENT-1 owns it
presenter = Presenter.new()          # the shell owns this Node
add_child(presenter)                 # _ready() builds it
session.bind_presentation(presenter) # binds the router AND calls presenter.setup(board) + sync
presenter.layout_for(viewport_size)  # AFTER bind_presentation (setup must precede layout)
session.play()                       # or start_level(i) / debug_select_level(i)
# on tap: session.dispatch_entity(entity_id_from_the_shell_hit_test)
# per frame: in-tree presenters self-drive (_process → advance); do NOT also call advance
# on resize: presenter.layout_for(size); session.refresh_presentation()
# leaving gameplay: session.unbind_presentation() (clears router subscribers), then free the presenter
```

Rules:

- `bind_presentation()` sets up the board DTO, objective chips, staging data and
  the authoritative sync; the shell must not call `setup()` itself.
- The session forwards each command result with
  `adapter.forward_result(result)` and pushes authoritative state with
  `adapter.sync_authoritative_state(state, presenter)`; the shell never mutates
  `GameState` and never computes FIFO/matching/capacity/win/lose.
- The shell owns tap hit-testing (there is no hit-test helper in presentation):
  compute the cell from `presenter.board_view.cell_center` / `cell_size` and
  match the entity DTO's `cell`/`footprint`, then call `dispatch_entity(id)`.
- M3 does not require a `project.godot` main-scene change from AGENT-1; the M3
  shell owns boot/menu scenes.

## 5. Persistence

`M3ProgressStore` writes one canonical JSON file at `user://m3_progress.json`
(injectable path for tests):

```json
{
  "version": 1,
  "highest_unlocked_level": 2,
  "completed_level_ids": ["traffic_m3_l01_first_roll"],
  "last_selected_level": 2
}
```

Level numbers are **1-based**; ids are catalogue ids. Missing or malformed files
fall back to a clean profile without crashing and without rewriting the file.
This is M3-minimal: M10 replaces it with the robust save/migration system.

## 6. Level data

The ten M3 levels live in `game/integration/traffic/m3_level_catalogue.gd`
(product data in the integration layer, ADR-013). M5 replaces this with the
formal LevelSchema/loader and moves the data to `content/levels/`. Winning
command sequences exist only in `game/tests/m3_levels_solvable_test.gd`.
