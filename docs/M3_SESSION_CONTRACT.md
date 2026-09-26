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
# Production: TrafficM3AppController owns this wiring (see section 7).
var session := TrafficFirstPlayableSession.new(progress_store)   # AGENT-1 owns it
presenter = shell.get_traffic_presenter()    # the shell owns this Node
session.bind_presentation(presenter)         # binds the router + presenter.setup()
session.play()                               # level starts -> presenter.setup(board) ran
shell.layout_for(viewport)                   # AFTER play(): the board DTO must exist first
# on tap: session.dispatch_entity(entity_id_from_the_shell_hit_test)
# per frame: in-tree presenters self-drive (_process → advance); do NOT also call advance
# on resize: shell.layout_for(size); session.refresh_presentation()
# leaving gameplay: session.unbind_presentation() (clears router subscribers), then free the presenter
```

Rules:

- `bind_presentation()` binds the router and, once a level is active, calls
  `presenter.setup(board)` + objective chips + authoritative sync; the shell must
  not call `setup()` itself.
- `layout_for()` must run **after** the level started (presenter setup), because
  the board cannot be sized before its DTO exists.
- The session forwards each command result with
  `adapter.forward_result(result)` and pushes authoritative state with
  `adapter.sync_authoritative_state(state, presenter)`; the shell never mutates
  `GameState` and never computes FIFO/matching/capacity/win/lose.
- The shell owns tap hit-testing through `handle_tap_at(board_point)` (board-local
  point, same path as the input catcher); the controller forwards the returned id.
- Starting a level resets stale cosmetic state (movement target, result lock,
  pending removals) so NEXT/RETRY/restart are immediately playable.

## 7. Production composition (M3 integration)

`game/integration/traffic/traffic_m3_app_controller.gd` (+ `.tscn`) is the app
entry point (`application/run/main_scene`). It owns the shell, the session and
product navigation, and is the only layer that may know both sides (ADR-013):

```text
boot -> TrafficM3AppController -> M3FirstPlayable shell (AGENT-2)
                               -> TrafficFirstPlayableSession (AGENT-1)
```

Public API for menus/level select/tests:

```gdscript
var app := TrafficM3AppController.new()
app.progress_path = "user://m3_progress.json"   # injectable (tests/QA)
app.debug_enabled = OS.is_debug_build()         # applied to the shell's debug gate
app.start()                                     # shell + session + binding + MAIN_MENU
app.get_shell() / app.get_session() / app.get_presenter()
app.highest_unlocked_level() / app.last_session_error()
app.advance(delta)                              # headless only (in-tree presenters self-drive)
app.layout_for(viewport)                        # explicit layout (tests / non-tree callers)
app.shutdown()                                  # unbind + clear subscribers + free the shell
```

Wiring guarantees encoded in the controller:

- shell intents → `play()` / `dispatch_entity()` / `restart_current_level()` /
  `next_level()` / `debug_select_level()` / menu;
- session signals → `show_main_menu` / `show_playing` / `show_win_result`
  (`is_final_level` computed from the session) / `show_fail_result`;
- one tap produces exactly one command (the shell de-dupes synthetic
  mouse-after-touch within 400 ms);
- one router binding for the app lifetime: Menu → Play → Menu never re-binds, so
  no duplicated callbacks or subscriptions;
- `shutdown()` clears subscribers and frees the shell, leaving no leaks.

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
command sequences exist only in `game/tests/m3_levels_solvable_test.gd` and are
reused by the campaign integration test.

## 8. Cross-layer tests (M3 integration)

| Test | Covers |
|---|---|
| `m3_app_integration_test.gd` | boot → MAIN_MENU/Project Traffic/PLAY, play → real board, real shell tap → win → WIN_RESULT + persistence, NEXT → level 2, debug fail → RETRY, restart, Menu→Play loop (no duplicate subscriptions), touch/mouse de-dupe (one tap = one command), responsive real boards (1080×1920 / 1080×2400 / 1600×2560) |
| `m3_app_resume_test.gd` | app restart resumes the persisted unlock without any manual `load_progress()`, missing/malformed saves boot clean, debug isolation end-to-end (debug win shows the result, never unlocks, save bytes untouched, normal Play unaffected), release gate hides the debug selector |
| `m3_campaign_integration_test.gd` | full normal campaign: all ten levels played through the real shell/controller to WIN_RESULT with the proven sequences, unlock progression 1→10, progress persisted; final level hides NEXT and stays terminal; plus a debug sweep presenting every level |
| `bootstrap_test.gd` | the project boots into the M3 app composition root (`main_scene` = controller scene, script = controller, `start`/`shutdown` API present) |
