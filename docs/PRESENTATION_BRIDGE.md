# Presentation Bridge Contract

> **Owner:** AGENT-1 (`game/core`, `game/puzzle`, `game/integration/traffic`)
> **Consumer:** AGENT-2 (presentation, UX)
> **Version:** 1 — additively extended in M2 (no breaking change; see §7)
> **Authority:** `docs/MASTER_BLUEPRINT.md` §8.2, §12.
> Companion of `docs/UX_IMPLEMENTATION_PLAN.md` §2/§12 and
> `docs/TRAFFIC_PRESENTATION.md` (AGENT-2 scaffold).

## 1. Model

```text
input → GameCommand → validate → apply logical mutation
      → CommandResult { status, code, events[] }   (synchronous, deterministic)
      → [adapter] TrafficEventMap → presentation names/payloads
      → [presentation] router/queue → animation/audio/haptics
```

Rules:

1. **The simulation decides; presentation reacts.** Events describe facts.
2. Logical state is updated *before* events are observed (catch-up model);
   animation can never change outcomes (§8.2, §32).
3. Presentation never writes `GameState`, never gates validity, and locks input
   only cosmetically with hard caps (UX plan §5.4/§5.5).
4. The simulation never waits for animation and has no scene-tree dependency.
5. Presentation (`game/themes/traffic`, `game/ui`, `game/audio`,
   `game/haptics`) must not import `game/core/**` or `game/puzzle/**`; the
   product integration layer is the translation point (ADR-013).

## 2. Event structure

`DomainEvent` (`game/core/commands/domain_event.gd`):

| Field | Type | Meaning |
|---|---|---|
| `event_type` | `StringName` | Stable event name (§3) |
| `sequence` | `int` | 0-based emission order inside one `CommandResult` |
| `data` | `Dictionary` | Payload, JSON-safe primitives only |

Payload conventions: ids are `String`; positions `{ "x": int, "y": int }`;
sizes `{ "width": int, "height": int }`; cell lists are arrays of positions;
id lists are sorted `Array[String]`; statuses/codes/fail reasons are stable
snake_case `String`s. Events are treated as immutable once emitted and support
`to_dictionary()` / `from_dictionary()` / `logical_equals()`.

## 3. Event catalog (contract version 1)

### M1 (unchanged semantics)

| Event | Emitted by | Payload |
|---|---|---|
| `entity_placed` | `PlaceEntityCommand` success | `entity_id`, `position`, `footprint` |
| `entity_move_started` | movement success (first) | `entity_id`, `from`, `to` |
| `entity_moved` | movement success (second) | `entity_id`, `from`, `to`, `path` (M2 additive field) |
| `entity_blocked` | any command rejected as `BLOCKED` | `entity_id`, `target`, `blockers[]` |
| `command_rejected` | every other rejection | `status`, `code`, `entity_id` |

### M2 additions (additive)

| Event | Emitted by | Payload |
|---|---|---|
| `item_loaded` | arrival loading (per item, FIFO order) | `entity_id`, `item_id`, `color_key`, `destination_id`, `loaded_count` |
| `match_occurred` | arrival loading summary (≥1 item) | `entity_id`, `color_key`, `loaded_count` |
| `entity_completed` | entity filled/served and left the board | `entity_id`, `destination_id` |
| `staging_changed` | entity staged | `action` (`added`/`removed`), `entity_id`, `slot_index`, `slot_count`, `occupied_count`, `available_slots` |
| `objective_completed` | objective satisfied (once per objective) | `objective_id`, `objective_type` |
| `game_completed` | all mandatory objectives complete | `level_id`, `move_count` |
| `game_failed` | loss (`staging_full`, `no_valid_moves`) | `fail_reason`, `move_count` |

`staging_changed(action="removed")` is defined but **not emitted by M2 rules**
(nothing un-stages an entity yet; M11 boosters/undo may).

### Rejection rule

A rejected command emits *either* exactly one `entity_blocked` (status
`BLOCKED`) *or* exactly one `command_rejected` (all other statuses) — never
both. Statuses: `success`, `invalid`, `blocked`, `out_of_bounds`,
`invalid_state`, `game_already_complete`.

Dispatch rejection codes (stable): `game_not_in_progress`, `unknown_entity`,
`board_not_ready`, `entity_not_placed`, `entity_not_movable`, `unknown_path`,
`invalid_path`, `path_start_mismatch`, `unknown_destination`, `cell_occupied`,
`move_failed`.

`STAGING_FULL` is **not** a rejection: the move was legal and loses the level.
The command returns status `success` with code `staging_full` plus a
`game_failed` event (see `docs/GAME_RULES.md` §4).

## 4. Ordering guarantee

- Inside one `CommandResult`, events are ordered exactly as emitted;
  `sequence` equals the array index (`0..n-1`).
- Identical state + identical command ⇒ identical event list and payloads
  (proved by `tests/events_test.gd` and `tests/traffic_gameplay_test.gd`).
- Dispatch order for a completing move (stable):

```text
entity_move_started → entity_moved → item_loaded* → match_occurred?
→ entity_completed | staging_changed → objective_completed* → game_completed?
```

  For a staging loss: `entity_move_started → entity_moved → game_failed`.
  For a blocked dispatch: `entity_blocked` only.
- Per-entity animation interruption/fast-forward is presentation's business
  (UX plan §2.3); the core imposes no animation waits.

## 5. Synchronous emission, queued consumption

- `Simulation.execute(command)` returns synchronously; events exist
  immediately afterwards.
- `SimulationEventQueue` (`game/puzzle/presentation_bridge/`) buffers results
  for presentation; draining/clearing never mutates simulation state.
- Each consumer owns a queue, or the game layer owns one and fans out.

## 6. What presentation may / may not do

**May:** enqueue/drain events, animate, play audio/haptics, apply cosmetic
input gates with hard caps, ignore unknown event types, run debug overlays
(Debug/QA only), read projected view data from the adapter.

**May not:** mutate `GameState`, decide correctness, require the core to wait
for animation, assume the vocabulary is closed, or reference core/puzzle
internals (ADR-013).

## 7. Extension policy

- Changes are **additive**: new event types and new payload keys are appended;
  existing names and fields are never repurposed.
- `PresentationContract.CONTRACT_VERSION` increments only on a breaking change.
  M2 added seven event types and one payload field (`entity_moved.path`)
  additively, so the version stays **1** (documented decision, ADR-012 §rules).
- Consumers must ignore unknown event types and unknown payload keys.
- M11/M12 may add booster/undo/analytics-related events the same way.

## 8. Traffic adapter (product integration layer)

`game/integration/traffic/**` (AGENT-1) is the single translation point. There
is **one** event vocabulary: the official snake_case names above. The adapter
never renames an official event — the earlier PascalCase proposal vocabulary
(`EntityArrived`, `LevelCompleted`, `StagingReceived`, …) is obsolete and must
not reappear anywhere.

What the adapter adds is presentation-side **enrichment of the payload copy**
(it never mutates a `DomainEvent` or simulation state):

| Official event | Enrichment | Notes |
|---|---|---|
| `entity_move_started` | `path` (array of `{x, y}` cells) | copied from the matching `entity_moved` in the same result so presentation interpolates the real route; falls back to `[from, to]` |
| `staging_changed` | `pressure` (`normal` / `warning` / `full`) | derived from the authoritative `occupied_count` / `slot_count` |

`entity_moved` keeps its official `path` field unchanged, so the presenter can
consume either event.

Adapter API (`TrafficPresentationAdapter`):

```gdscript
var adapter := TrafficPresentationAdapter.new()      # owns the real router
adapter.bind_presenter(presenter)                    # presenter.bind_router(router)
adapter.forward_result(simulation.execute(DispatchEntityCommand.new(&"v1")))
adapter.sync_authoritative_state(state, presenter)   # authoritative refresh
adapter.build_board_view(state)      # state -> AGENT-2 board DTO
adapter.build_staging_view(state)    # slots + occupants + pressure
adapter.build_entity_view(entity)    # cell/footprint Vector2i, orientation in DEGREES
adapter.build_destination_view(destination, state)
adapter.build_progress_snapshot(state)   # primitive HUD counters
```

Rules enforced by the cross-layer tests (`game/tests/traffic_integration_test.gd`):

- the adapter dispatches only official names (checked against
  `PresentationContract` and the router's `ALL_EVENTS`), and no PascalCase name
  reaches the router;
- forwarding and projection are read-only for simulation state;
- `sync_authoritative_state()` refreshes destination occupancy/queue, staging
  occupancy and staging pressure using only the presenter's public setters —
  presentation never computes FIFO, matching, capacity or game-over rules;
- orientation is projected in **degrees** (north 0, east 90, south 180, west
  270), matching `traffic_theme.DIRECTION_DEGREES`;
- fail reasons keep the simulation's canonical lowercase machine ids
  (`staging_full`, `no_valid_moves`); presentation maps them to localization
  keys and still tolerates the older uppercase aliases.

Presentation-side movement contract (implemented in `traffic_presenter.gd`):
because `entity_move_started` and `entity_moved` are emitted back-to-back
synchronously, presentation animates from `entity_move_started` (using the full
`path`), never snaps backwards when `entity_moved` arrives mid-animation (the
authoritative target is applied when the tween ends), defers the visual removal
of completed/staged entities until their movement finishes, and keeps the
movement lock bounded by `MOVE_LOCK_CAP`.

## 9. Code entry points

| Purpose | File |
|---|---|
| Event definition/factories | `game/core/commands/domain_event.gd` |
| Result statuses/codes | `game/core/commands/command_result.gd` |
| Simulation facade | `game/puzzle/simulation/simulation.gd` |
| Arrival/loading rules | `game/puzzle/gameplay/arrival_resolver.gd` |
| Objectives/win/lose | `game/puzzle/gameplay/progress_evaluator.gd` |
| Presentation FIFO queue | `game/puzzle/presentation_bridge/event_queue.gd` |
| Machine-readable contract | `game/puzzle/presentation_bridge/presentation_contract.gd` |
| Traffic translation table | `game/integration/traffic/traffic_event_map.gd` |
| Traffic adapter | `game/integration/traffic/traffic_presentation_adapter.gd` |
| Contract tests | `game/tests/events_test.gd`, `presentation_bridge_test.gd`, `traffic_integration_test.gd` |
| AGENT-2 contract docs | `docs/TRAFFIC_PRESENTATION.md`, `docs/UX_IMPLEMENTATION_PLAN.md` §2 |

## 10. Not implemented yet

Score/combo events (M4), booster/undo events (M11), analytics emission (M12),
state-hash exposure (M6), obstacles/level metadata (M5), the
`staging_changed(action="removed")` path (M11 — nothing un-stages an entity in
M2).
