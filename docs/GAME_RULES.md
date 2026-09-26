# Game Rules

> **Status:** Rules defined, **not yet implemented**. M1 (Puzzle Core)
> provides only the generic deterministic foundations (board/occupancy,
> entity model, commands, state, seeded RNG). Gameplay behaviour starts at
> M2; booster/economy rules at M11.
> This is a summary for orientation; the authoritative text is
> `docs/MASTER_BLUEPRINT.md` §13–§17, §34–§35. Do not treat this file as
> a second source of truth.

## Scope

Deterministic congestion puzzle: select entities in an order that clears
them while correctly processing waiting items without exhausting
temporary capacity.

## v1 rules (summary of blueprint §13–§17)

- **Primary action:** tap a vehicle (entity). The system resolves it,
  checks state/blocking/destination, applies the move if valid, then
  processes matching/loading and re-evaluates objectives.
- **Blocked move:** the entity does not move; presentation gives
  immediate feedback (shake, short sound, optional haptic/highlight).
  No punishment for exploratory taps unless a level rule adds a move
  limit.
- **Matching (v1):** by stable `color_key` (`COLOR_A`, `COLOR_B`, ...)
  — never literal render colors internally. Architecture must allow
  future matching rules (destination, symbol, wildcard...) without core
  rewrites.
- **Win (default v1):** all required items processed AND all required
  entities completed AND all mandatory objectives completed.
- **Lose reasons:** `STAGING_FULL`, `NO_VALID_MOVES`,
  `MOVE_LIMIT_EXCEEDED`, `TIME_LIMIT_EXCEEDED`,
  `SPECIAL_OBJECTIVE_FAILED` — each with a machine-readable
  `fail_reason` for analytics.
- **Undo:** first-class; restores exact previous logical state
  (including RNG, staging, queues, objectives) without duplicating
  rewards or analytics.
- **Staging:** generic temporary destination, default 4 slots,
  configurable per level.
- **Boosters (M11):** Undo, Extra Slot, Shuffle. Every standard level
  must be solvable **without** boosters, purchases or ads (§35.4).

## Fairness

Every shipped production level must be solver-validated as
`SOLVABLE` (§21.4, §75).

## Implementation mapping

| Rule area | Milestone |
|---|---|
| Board, entities, occupancy, commands, state, RNG (generic only) | M1 (done) |
| Traffic theme behavior, matching, staging, win/lose | M2 |
| Boosters | M11 |
| Full level/objective catalog (MOVE_LIMIT, TIME_LIMIT, ...) | M5+ |
