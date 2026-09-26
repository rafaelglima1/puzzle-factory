# Game Rules

> **Status:** M2 gameplay simulation implemented (logical rules only; no M3
> screens/play flow). The authoritative specification is
> `docs/MASTER_BLUEPRINT.md` §13–§17, §34–§35; this file documents how those
> rules are implemented and is not a second source of truth.

## 1. Product flow (implementation view)

```text
player dispatches an entity (Traffic: taps a vehicle)
↓
DispatchEntityCommand: validate entity / state / path / blockers
↓
blocked?               → reject (entity_blocked), state untouched
↓
apply logical move     → entity_move_started + entity_moved (with path)
↓
resolve arrival        → load matching items / complete / stage
↓
evaluate objectives    → objective_completed
↓
evaluate completion    → game_completed | game_failed
```

The simulation never waits for animation; presentation consumes the event
stream at its own pace (`docs/PRESENTATION_BRIDGE.md`).

## 2. Generic mechanics (M2)

| Concept | Implementation | Notes |
|---|---|---|
| Item | `game/core/entities/item.gd` | id, item_type, color_key, destination_id, priority, special_type, metadata |
| Queue | `game/core/state/item_queue.gd` | FIFO only; strict front-order processing; serializable |
| Destination | `game/core/entities/destination.gd` | accepted_color_keys, capacity (0 = unlimited), queue_id, processed_count, state (open/full) |
| Staging area | `game/core/state/staging_area.gd` | arbitrary slot count; lowest-free-slot assignment; refuses overflow |
| Matching | `game/core/matching/matching_rule.gd` + `color_key_matching_rule.gd` | color-key equality; empty keys never match; new rules are new subclasses |
| Path | `game/core/movement/logical_path.gd` | ordered cells, validated (≥2, in bounds, contiguous, no repeats) |
| Objectives | `game/core/objectives/*` | `CLEAR_ALL` only; evaluated on demand |
| Failure reasons | `game/core/rules/fail_reason.gd` | `staging_full`, `no_valid_moves` (stable ids) |

## 3. Matching and loading (deterministic)

When an entity arrives at its destination:

1. Inspect the **front** item of the destination queue only.
2. Load it when **all** of these hold:
   - the destination accepts the item's color key,
   - the matching rule matches (M2: `entity.color_key == item.color_key`),
   - the entity capacity is not exhausted (capacity 0 = unlimited),
   - the destination capacity is not exhausted (capacity 0 = unlimited).
3. Otherwise **stop**. Items are never skipped or reordered: a mismatching
   front item blocks the rest of the queue (strict FIFO).
4. Repeat until a stop condition.

Processed items leave the item registry; the destination's `processed_count`
increases and its state becomes `full` when a positive capacity is reached.

## 4. Entity outcome after arrival

- **Loaded at least one item → COMPLETED.** The entity leaves the board
  (its cells are freed) and counts as completed for objectives.
- **Loaded zero items → STAGED** (it waits for service):
  - the staging area assigns the lowest free slot, the entity leaves the board
    and enters `WAITING`;
  - **if staging is full → the level is lost with `staging_full`.**
    The move itself was legal (the player's action caused the loss); the
    command reports success with code `staging_full`, and no further
    objective/progress evaluation runs.

Rationale: capacity limits how much an entity takes, not whether it can leave;
the staging area absorbs entities that cannot be served, which is what makes
ordering decisions matter.

## 5. Win and loss

- **Win (`CLEAR_ALL`):** every item processed AND every entity completed AND
  all mandatory objectives complete, with at least one mandatory objective
  present. Emits `objective_completed` per objective then `game_completed`.
- **`STAGING_FULL`:** an entity needed staging while staging was full (see §4).
- **`NO_VALID_MOVES`:** after a successful action no placed, operable entity
  has a valid, unblocked path. Emits `game_failed` with
  `fail_reason = no_valid_moves`.
  A level that starts with *no* valid move at all is a level-design error
  (the M5 validator / M6 solver must reject it); rejected commands never mutate
  state, so the simulation does not declare a loss from a rejection.
- A move that would immediately lose (dispatching into a full staging area)
  still counts as an available move; the loss happens when it is taken.

## 6. Blocking

- Occupancy is authoritative; a path is dispatchable only when every path cell
  is free of other entities (the mover's own cells are ignored).
- Blocked dispatches emit `entity_blocked` with the blocking ids and the first
  blocked cell, and leave the state completely untouched.

## 7. Boosters (M11, not implemented)

Undo / Extra Slot / Shuffle remain deferred. Every standard level must stay
solvable without boosters, purchases or ads (§35.4).

## 8. Fairness

Every shipped production level must be solver-validated as `SOLVABLE` (§21.4,
§75) — the solver arrives in M6. M2 provides the rules the solver will use.

## 9. Implementation mapping

| Rule area | Milestone |
|---|---|
| Board, entities, occupancy, commands, state, RNG | M1 (done) |
| Items, queues, destinations, staging, matching, capacity, path, objectives, win/lose | M2 (done) |
| Production levels, obstacles, full objective catalog | M5 |
| Solver / difficulty / generator | M6–M8 |
| Boosters | M11 |
