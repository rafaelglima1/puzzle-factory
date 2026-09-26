# ADR-012: Synchronous domain event emission with a presentation-side queue

Status: Accepted (2026-09-26)

## Context

Blueprint §12 defines the command flow as
`input → command → validate → apply → emit domain events → presentation
reacts`, and §8.2 requires presentation to consume simulation events
without ever deciding puzzle correctness. The M1 puzzle core must also be
usable by solver/replay/tests, which need deterministic, order-stable
output from a single command.

Options considered:

1. **Engine signals / global event bus inside the core** — couples the
   simulation to the scene tree, makes ordering implicit, and is hard to
   test headlessly.
2. **Callbacks/subscribers registered in core** — hidden global state,
   ordering depends on subscription order, complicates determinism.
3. **Asynchronous/threaded event stream** — unnecessary complexity for a
   turn-based puzzle; makes headless tests flaky.
4. **Events returned synchronously as part of the command result**, with
   presentation owning its own queue for animation pacing.

## Decision

- Commands emit `DomainEvent`s into a `CommandContext`; `Simulation.execute()`
  returns `CommandResult { status, code, events[] }` **synchronously**.
- Event order inside a result is deterministic and part of the public
  contract (`sequence` = array index). See `docs/PRESENTATION_BRIDGE.md`.
- Presentation consumes results through `SimulationEventQueue` and animates
  at its own pace. The core never waits for animation.
- No engine signals and no global bus exist inside `game/core/**` or
  `game/puzzle/simulation/**`.
- A rejected command emits either one `entity_blocked` (status `BLOCKED`)
  or one `command_rejected` (all other rejections), and never mutates state
  (including RNG state).

## Consequences

- Core simulation is fully headless-testable and deterministic; ordering and
  payloads are covered by automated tests.
- Presentation must poll/drain a queue instead of waiting on callbacks; this
  is the intended decoupling and matches the UX plan's catch-up model.
- Multiple presentation consumers must not share a single drain point: each
  system owns a queue, or the game layer owns one queue and fans out.
- Any future asynchronous/threaded execution would require a new ADR, since
  it changes the ordering guarantee this contract relies on.
