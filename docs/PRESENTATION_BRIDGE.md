# Presentation Bridge Contract

> **Owner:** AGENT-1 (`game/puzzle/presentation_bridge/**`)
> **Consumer:** AGENT-2 (presentation, UX)
> **Version:** 1 (established in M1, 2026-09-26)
> **Authority:** `docs/MASTER_BLUEPRINT.md` §8.2, §12.
> Companion of `docs/UX_IMPLEMENTATION_PLAN.md` §2 (event proposal) and
> §12 (cross-boundary contracts). Where the UX plan proposed names, this
> document defines the implemented generic contract; proposals map onto it
> (see §3).

## 1. Model

```text
input → GameCommand → validate → apply logical mutation
      → CommandResult { status, code, events[] }  (synchronous, deterministic)
      → [presentation] SimulationEventQueue → animation/audio/haptics
```

Rules:

1. **The simulation decides; presentation reacts.** Events describe facts
   that already happened. They never request decisions.
2. Logical state is updated *before* events are observed (catch-up model).
   Presentation animates toward an already-decided state, so animations can
   never change puzzle outcomes (blueprint §8.2, §32).
3. Presentation may not write `GameState`, may not gate win/lose or
   validity, and may lock input only cosmetically with hard caps
   (UX plan §5.4/§5.5).
4. Simulation never waits for an animation. Core has no scene-tree,
   audio or analytics dependency.

## 2. Event structure

`DomainEvent` (`game/core/commands/domain_event.gd`):

| Field | Type | Meaning |
|---|---|---|
| `event_type` | `StringName` | Stable event name (see §3) |
| `sequence` | `int` | 0-based emission order inside one `CommandResult` |
| `data` | `Dictionary` | Payload, JSON-safe primitives only |

Payload conventions (enforced by tests and `PresentationContract`):

| Value kind | Representation |
|---|---|
| entity id | `String` (e.g. `"e1"`) |
| position | `{ "x": int, "y": int }` |
| size / footprint | `{ "width": int, "height": int }` |
| id list | `Array[String]`, **sorted** deterministically |
| status / code | stable snake_case `String` |

Events support `to_dictionary()` / `from_dictionary()` (roundtrip-tested) and
`logical_equals()`. They are treated as immutable once emitted.

## 3. Event catalog (contract version 1 / M1)

| Event | Emitted by | Payload | UX plan proposal |
|---|---|---|---|
| `entity_placed` | `PlaceEntityCommand` success | `entity_id`, `position`, `footprint` | (spawn visual) |
| `entity_move_started` | `MoveEntityCommand` success (1st) | `entity_id`, `from`, `to` | `EntityMoveStarted` |
| `entity_moved` | `MoveEntityCommand` success (2nd) | `entity_id`, `from`, `to` | `EntityArrived` |
| `entity_blocked` | any command with status `BLOCKED` | `entity_id`, `target`, `blockers[]` | `EntityBlocked` |
| `command_rejected` | every other rejection | `status`, `code`, `entity_id` | (map from `status`/`code`) |

**Rejection rule (M1):** a rejected command emits *either* exactly one
`entity_blocked` (status `BLOCKED`) *or* exactly one `command_rejected`
(all other statuses) — never both.

**Command statuses** (superset of blueprint §12; stable strings):
`success`, `invalid`, `blocked`, `out_of_bounds`, `invalid_state`,
`game_already_complete`.

**Rejection codes currently used** (stable, machine-readable): 
`game_not_in_progress`, `missing_target`, `unknown_entity`, `board_not_ready`,
`entity_not_placed`, `entity_not_movable`, `out_of_bounds`, `no_op_move`,
`cell_occupied`, `move_failed`, `missing_arguments`, `duplicate_entity_id`,
`placement_failed`, `entity_rejected`, `not_implemented`, `null_command`.

## 4. Ordering guarantee

- Inside one `CommandResult`, events are ordered exactly as emitted and
  `sequence` equals the array index (`0..n-1`).
- The same state + same command always produces the same event list,
  including payload values (proved in `tests/events_test.gd`).
- Across commands, results are returned in command order; a player action
  maps to one result.
- Per-entity animation interruption, fast-forward and pooling policies are
  presentation concerns (UX plan §2.3). The core imposes no animation waits.

## 5. Synchronous emission, queued consumption

- `Simulation.execute(command)` returns the result synchronously; the events
  exist immediately after the call returns.
- `SimulationEventQueue` (presentation-side, `game/puzzle/presentation_bridge/`)
  accepts a result and is drained at presentation speed. Draining or clearing
  the queue never mutates simulation state (tested).
- Multiple consumers should each own a queue, or the game layer owns one
  queue and fans out to sub-systems.

## 6. What presentation may / may not do

**May:** enqueue and drain events, animate freely, play audio/haptics,
apply cosmetic input gates with hard caps, ignore unknown event types,
run debug overlays (Debug/QA builds only, blueprint §68).

**May not:** mutate `GameState`, decide correctness, require the core to
wait for animation, assume the event vocabulary is closed (must ignore
unknown types), hardcode theme asset paths (use `game/themes/base`
contracts only), or emit/consume analytics through anything but the
AGENT-1 abstraction (M12).

## 7. Extension policy

- Contract changes are **additive**: new event types and new payload fields
  are appended; existing names/fields are never repurposed.
- `PresentationContract.CONTRACT_VERSION` increments on any breaking change.
- M2 adds gameplay events: matching/loading, staging, objectives, combo/
  score, `level_completed` / `level_failed(fail_reason)` (see UX plan §2.2;
  `fail_reason` ids follow blueprint §16).
- Debug overlays may expose read-only accessors (state hash arrives with M6).

## 8. Code entry points

| Purpose | File |
|---|---|
| Event definition + factories | `game/core/commands/domain_event.gd` |
| Result statuses/codes | `game/core/commands/command_result.gd` |
| Simulation facade | `game/puzzle/simulation/simulation.gd` |
| Presentation FIFO queue | `game/puzzle/presentation_bridge/event_queue.gd` |
| Machine-readable contract + validation | `game/puzzle/presentation_bridge/presentation_contract.gd` |
| Contract tests | `game/tests/events_test.gd`, `game/tests/presentation_bridge_test.gd` |

```gdscript
var simulation := Simulation.create(&"level_001", seed_value, BoardDimensions.new(6, 6))
var queue := SimulationEventQueue.new()

queue.enqueue_result(simulation.execute(PlaceEntityCommand.new(entity, GridPosition.new(0, 0))))
queue.enqueue_result(simulation.execute(MoveEntityCommand.new(&"e1", GridPosition.new(1, 0))))

while not queue.is_empty():
    var event: DomainEvent = queue.dequeue()
    match event.event_type:
        DomainEvent.ENTITY_MOVE_STARTED:
            _animate_move_start(event)
        DomainEvent.ENTITY_MOVED:
            _animate_arrival(event)
        DomainEvent.ENTITY_BLOCKED:
            _animate_blocked(event)   # event.get_payload("blockers")
        DomainEvent.COMMAND_REJECTED:
            _log_rejection(event)     # event.get_payload("status"), ("code")
        _:
            pass  # unknown event types must be ignored, never crash
```

## 9. Not in v1

Items/queues/destinations/objectives/staging gameplay, win/lose and
`fail_reason` (M2/M5), score/combo (M4), booster/undo events (M11),
state-hash exposure (M6), analytics event emission (M12). These extend the
contract additively when their milestone lands.
