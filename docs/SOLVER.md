# Solver

> **Owner:** AGENT-1 (content engine)
> **Status:** M5 — generic BFS solver over a product adapter
> **Authority:** `docs/MASTER_BLUEPRINT.md`; ADR-002 (determinism), ADR-007 (solver), ADR-013

The solver proves whether a level is completable and, when it is, produces a
replayable solution. It is **generic**: it searches logical states and never
knows the product. Product correctness (movement, matching, staging, win/lose)
stays in the simulation, reached only through an adapter.

## 1. Architecture

```text
BfsSolver (game/solver/bfs_solver.gd)          generic breadth-first search
    │  drives
    ▼
SolverDomain (game/solver/solver_domain.gd)     abstract adapter contract
    │  implemented by
    ▼
TrafficSolverDomain (game/integration/traffic/solver/traffic_solver_domain.gd)
    │  wraps the real simulation
    ▼
Simulation / DispatchEntityCommand (game/puzzle, game/core)
```

`game/solver/**` contains no product vocabulary, is scene-tree-free, and never
imports `res://integration/**`, `res://themes/**` or `res://content/**`
(enforced by `game/tests/architecture_test.gd`).

### Adapter contract (`SolverDomain`)

```gdscript
func initial_state() -> Variant
func state_snapshot(state) -> Dictionary            # canonical, primitive-only
func state_key(state) -> String                     # default: SolverStateHasher.hash_snapshot
func is_terminal(state) -> bool                     # default: is_won or is_lost
func is_won(state) -> bool
func is_lost(state) -> bool
func candidate_commands(state) -> Array             # deterministic descriptors
func apply_command(state, command: Dictionary) -> Variant   # NEW handle or null; never mutates input
func command_from_descriptor(descriptor) -> Variant
```

The Traffic adapter enumerates every entity still placed on the board as a
candidate `{"type":"dispatch_entity","entityId":<id>}` and applies a candidate by
cloning the state (`GameState.from_dictionary(snapshot)`) and running the real
`DispatchEntityCommand`. It returns `null` for rejected/blocked/no-op commands,
so the solver never re-implements movement or path legality.

## 2. State hashing

`SolverStateHasher` (game/solver/state_hasher.gd):

- canonical input: `Serialization.canonicalize(GameState.to_dictionary())` —
  sorted keys, primitive-only, `StringName → String`, integral-float
  normalization;
- digest: `Serialization.to_json(canonical).sha256_text()` — a stable 64-char
  lowercase hex SHA-256. Process-randomized `hash()` is never used.

Hashed state includes every field that can affect future play: entity
positions/states, items, queue contents and order, staging, destinations,
paths, objectives and completion, `objectives_completed`, `fail_reason`,
`move_index`, `rng_state`, `seed`, board. **Exclusions:** presentation, audio,
haptics, animation and screen state — `GameState` contains none of these today,
so the canonical form is complete for the current schema. If such fields are
ever added they must not enter the canonical form.

Equal states hash identically (including after a serialize/deserialize
round-trip); any future-relevant mutation changes the digest.

## 3. Search (BFS)

`BfsSolver.solve(domain, max_visited = 200000, max_depth = 64) -> SolverResult`.

```text
initial state -> hash -> visited
enumerate candidate descriptors (deterministic order)
apply to a CLONE; null result => not an accepted next state
terminal-losing / no candidates => dead end (not enqueued)
already visited => skip
won => reconstruct + verify => SOLVABLE
frontier emptied => UNSOLVABLE
bounds exceeded before proof => UNKNOWN (bounds_hit)
```

Reconstruction uses a predecessor table (`parents` + the command that produced
each node) and walks back — no per-node path copies, memory linear in visited
states.

### Pruning (conservative)

- visited-state pruning (by hash);
- terminal losing-state pruning;
- invalid/blocked/no-op command pruning (`apply_command == null`).

No heuristic pruning is applied; nothing is pruned on an unproven guess.

### Bounds

`max_visited` and `max_depth` are deterministic search-shape limits, not
wall-clock. `runtime_ms` is measured for reporting only and is **never** a
correctness bound. Hitting a bound before proof yields `UNKNOWN`.

### Status model

```text
SOLVABLE    a solution was found, reconstructed AND independently replayed to WON
UNSOLVABLE  the reachable state space was exhausted without a win
UNKNOWN     a bound was reached before proof (or verification failed)
```

`SOLVABLE` is returned only after `verify_solution` replays the command list
from a fresh initial state and reaches WON.

## 4. Command format

Commands are serializable descriptors, never live references:

```json
{ "type": "dispatch_entity", "entityId": "v1" }
```

`solution_commands.size == solution_depth`, and the list replays against a fresh
initial state (`SolutionReplay.replay`).

## 5. Replay validation

```gdscript
SolutionReplay.replay(domain, commands)
  -> { ok, won, applied, failed_at, failure_command }
```

Flow: fresh `initial_state()` → apply each command (each must yield a non-null
state) → final state must be `is_won()`. The solver does not claim SOLVABLE
unless this passes.

## 6. Metrics

`SolverResult` reports: `status`, `solution_commands`, `solution_depth`,
`visited_states`, `expanded_states`, `dead_end_count`, `branching_factor_avg`,
`runtime_ms`, `bounds_hit`, `metrics`.

- `visited_states`: distinct hashed states seen;
- `expanded_states`: nodes whose candidates were enumerated;
- `dead_end_count`: expanded states with no accepted successor or a terminal
  loss;
- `branching_factor_avg`: accepted successor edges / expanded states.

Determinism: for the same input and bounds, `status`, `solution_commands`,
`solution_depth`, `visited_states` and `expanded_states` are identical across
runs; `runtime_ms` may vary and is excluded from equality.

## 7. CLI

```text
powershell -File scripts/solve_level.ps1 traffic_m3_l10_rush_hour
powershell -File scripts/solve_level.ps1 --all
powershell -File scripts/solve_level.ps1 --all --json
powershell -File scripts/solve_level.ps1 path/to/level.json
powershell -File scripts/solve_level.ps1 <unsolvable.json> --expect-unsolvable
```

Exit codes:

```text
0  every requested level proven SOLVABLE (or UNSOLVABLE with --expect-unsolvable)
1  invalid input / load or validation failure
2  UNSOLVABLE (without --expect-unsolvable)
3  UNKNOWN (bounds) / tooling error
```

`--json` emits `{"levels": [ { level, status, depth, visited, expanded,
dead_ends, branching_avg, runtime_ms, bounds_hit, solution } ]}`.

## 8. Known limitations

- BFS is exponential in the worst case; M5's ten official levels are tiny (max
  13 visited states), so bounds are never approached. Larger future levels may
  require better pruning (new M6+ concern, only with measured evidence).
- `apply_command` clones the whole state per candidate (correctness over
  micro-optimization). For the current levels this is far below any practical
  threshold.
- The solver proves existence of a solution; it does not rank difficulty
  (that is the new M6 generation engine).

## 9. Results

See `docs/SOLVER_PERFORMANCE.md`. All ten official levels are `SOLVABLE` and
replay to WON; the valid-but-impossible fixture is `UNSOLVABLE`.

## 10. Tests

```text
game/tests/solver_state_hash_test.gd      hashing determinism / roundtrip / mutation
game/tests/solver_bfs_test.gd             solvable / unsolvable / bounds / determinism
game/tests/m5_solver_integration_test.gd  official 10 SOLVABLE + replay + determinism
                                          + valid-but-impossible UNSOLVABLE
```
