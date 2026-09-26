# ADR-003: Presentation separated from simulation

Status: Accepted (2026-09-26)

## Context

The same simulation must power gameplay correctness, solver analysis and
tests, while sprites, tweens, particles, audio and haptics change
constantly without affecting outcomes (blueprint §8.2).

## Decision

- Strict two-layer split:

  - **Simulation**: deterministic, testable, with no dependency on
    animation, audio, ads, Firebase or any presentation system.
  - **Presentation**: sprites, tweens, particles, camera, audio,
    haptics, UI.

- Presentation **consumes** simulation events; it never decides puzzle
  correctness.
- Presentation feedback (shake, blocked sound, haptics) is allowed for
  invalid moves, but cannot alter logical state (blueprint §13.3).

## Consequences

- Headless tests can validate gameplay without a viewport.
- Blocked/valid feedback can be iterated freely without risking
  regressions in rules.
- Requires discipline at module boundaries: `game/puzzle/simulation`
  and `game/core/**` must not reference presentation code. Architecture
  tests for this boundary are deferred to M1+.
