# ADR-002: Deterministic logical simulation

Status: Accepted (2026-09-26)

## Context

The product requires fair, testable, replayable puzzles (blueprint §10,
§11, §22): save/load, replay, undo, solver conversion, regression tests
and analytics snapshots all depend on the same inputs producing the same
logical outputs. Rigid-body physics and uncontrolled randomness make that
impossible.

## Decision

- All gameplay randomness is **seeded, deterministic and reproducible**
  (blueprint §11). No gameplay component may instantiate uncontrolled
  random state.
- Movement and outcomes are defined by deterministic cells, paths,
  occupancy, rules, waypoints and interpolation — never by physics
  simulation (blueprint §8.3). Physics may only drive visual effects.
- Logical states expose deterministic hashes covering everything that
  affects future gameplay (blueprint §22), excluding presentation state.

## Consequences

- Solver, replay verification, undo and duplicate detection become
  feasible and trustworthy.
- Determinism is enforced by tests (see `game/tests/determinism_test.gd`
  at M0; gameplay-level determinism tests arrive with M1).
- Any feature that introduces nondeterminism (wall-clock time, device
  RNG, physics outcomes) must go through explicit design review.
