# Architecture

> Scope: **M1 Puzzle Core** (foundation M0 + deterministic core M1).
> Systems marked "deferred" are designed in the blueprint but intentionally
> not implemented yet. Authority: `docs/MASTER_BLUEPRINT.md` §8–§12, §78.

## 1. Layers

```text
PRESENTATION (game/themes/<theme>, game/ui, game/audio, game/haptics)
      ↑ consumes domain events (docs/PRESENTATION_BRIDGE.md)
PUZZLE / SIMULATION (game/puzzle/simulation, presentation_bridge)
      ↑ commands in, results out
CORE (game/core: board, entities, state, commands)
      ↑ pure data + deterministic rules
DATA (content/, level definitions at M5, configs)
```

- **Core** (`game/core/**`): generic, theme-independent, deterministic
  domain model — board/occupancy, entity model, RNG, game state, commands,
  domain events. Concepts: `Entity`, `Item`, `Destination`, `Queue`, `Slot`,
  `Board`, `Path`, `GridPosition`, `Direction`, `Footprint`, `ColorKey`,
  `Capacity`, `GameState`, `Command`, `DomainEvent` (blueprint §8.1).
- **Puzzle** (`game/puzzle/**`): `Simulation` facade (command execution),
  presentation bridge (event contract + queue), future gameplay orchestration.
- **Presentation**: consumes events, never decides puzzle correctness
  (ADR-003, ADR-012).

Automated guard: `game/tests/architecture_test.gd` fails the build if
theme vocabulary or presentation references leak into `game/core/**`,
`game/puzzle/**` or `game/themes/base/**`, or if simulation code touches the
scene tree.

## 2. Non-negotiable principles

| Principle | ADR / blueprint |
|---|---|
| Seeded, reproducible randomness; no physics-authoritative gameplay | ADR-002, §8.3, §11 |
| Simulation/presentation strict separation | ADR-003, ADR-012, §8.2 |
| Synchronous deterministic events; presentation-side queue | ADR-012, §12 |
| Offline-first, no custom backend | ADR-006, §66, §91 |
| Godot 4.7.2 + GDScript pinned | ADR-001, §5 |
| Theme-independent core; themes supply presentation only | §8.1, §38 |
| Data-driven levels; no custom code per production level | §18 |
| Serializable `GameState` (save/replay/undo/solver) | §10 |
| Versioned contracts: SaveSchema / LevelSchema / RemoteConfigSchema | §100 |

## 3. Deterministic core (M1)

### Board and occupancy
`Board` is authoritative for logical blocking. One cell holds at most one
entity id; the occupancy index and `Entity.position` share a single write
path (`place_entity` / `move_entity`), so they cannot diverge. All validation
happens before mutation: rejected operations are atomic and leave the board
untouched. Iteration helpers are deterministic (sorted ids, row-major cells).
`BoardDimensions`, `GridPosition`, `Footprint`, `Direction` are small value
objects with stable serialization.

### Entity model
`Entity` carries generic fields only: `id`, `entity_type`, `position`,
`orientation`, `footprint`, `color_key`, `capacity`, `movement_type`,
`allowed_directions`, `path_id`, `destination_id`, `state`, `metadata`.
`EntityState` defines the baseline state graph (`IDLE`, `BLOCKED`, `MOVING`,
`WAITING`, `LOADING`, `UNLOADING`, `COMPLETED`, `DISABLED`) with explicit,
tested transitions. Movement is instantaneous and atomic in M1; per-tick
movement, matching and staging belong to gameplay milestones.

### Deterministic RNG
`RandomSource` is the contract; `DeterministicRng` implements it with an
ANSI-C LCG (`state = (1103515245 * state + 12345) mod 2^31`). The algorithm
is pure integer math (no overflow, no engine RNG), engine-independent and
fully serializable (`GameState.rng_state`), so replays stay valid across
platforms and engine upgrades. `CommandContext` provides the RNG and commits
its state only for successful commands (AD-012 side guarantee), so rejected
commands can never advance randomness.

### Game state and serialization
`GameState` holds `schema_version`, `level_id`, `level_revision`, `seed`,
`rng_state`, `board`, `entities`, `move_index`, `elapsed_ms`,
`completion_state`. `Serialization` produces a canonical representation
(sorted keys, StringName→String, integral floats→int) that is stable across
insertion orders; `GameState.to_dictionary()` is the stable comparable
representation used by roundtrip tests. Logical **state hashing** is deferred
to M6 (blueprint §22) rather than implemented prematurely.

### Command system and events
`GameCommand` → `CommandContext` → `CommandResult { status, code, events[] }`.
`Simulation.execute()` is the single entry point, usable headlessly with no
scene tree. M1 commands: `PlaceEntityCommand` (setup/level-load path) and
`MoveEntityCommand` (movement). Result statuses: `success`, `invalid`,
`blocked`, `out_of_bounds`, `invalid_state`, `game_already_complete`
(superset of blueprint §12). See `docs/PRESENTATION_BRIDGE.md` for the event
contract, ordering guarantee and payload conventions.

## 4. Build environments

Defined in `content/configs/environments/*.json` (contract only until the
services exist):

| | Debug | QA | Production |
|---|---|---|---|
| Debug menu | yes | no | no |
| Verbose logs | yes | no | no |
| Ads | disabled (test at M14) | test | production |
| Analytics | disabled (M12) | marked QA | production |
| Signing | debug | debug → release (M16) | release |

No Firebase/AdMob/IAP code or credentials exist in the repository.

## 5. Ownership boundaries (blueprint §78)

| Path | Owner |
|---|---|
| `game/core/**`, `game/puzzle/**`, `game/levels/**`, `game/solver/**`, `game/generator/**`, `game/persistence/**` | AGENT-1 |
| `game/themes/base/**` (generic contracts) | AGENT-1 |
| `game/themes/traffic/**` (concrete theme) | AGENT-2 |
| `game/ui/**`, `game/audio/**`, `game/haptics/**`, presentation, animations, particles | AGENT-2 |
| `tests/**` core suites | AGENT-1 |

Cross-boundary changes (event contracts, save schema keys, shared
abstractions) require explicit coordination; disagreements are resolved by
ADR, never silent divergence.

## 6. Reference resolution decision

`1080 × 1920` is an approved **design reference only** (and the current
project viewport default). It is **not** a fixed logical rendering
requirement: responsive presentation, safe areas and the device matrix
(16:9 / 18:9 / 19.5:9 / 20:9 / tablet, blueprint §62) remain AGENT-2's
responsibility at M3+.

## 7. Current state vs deferred

Implemented:

- **M0:** Godot project + portrait config + boot placeholder, headless test
  runner, Android Debug export (Gradle, minSdk 24 / targetSdk 36), CI
  skeleton, docs, ADRs.
- **M1:** board/occupancy/positions/footprints, entity model + states,
  deterministic RNG, `GameState` + canonical serialization, command system,
  domain events, presentation bridge contract, theme base contract.

Deferred:

| Concern | Milestone |
|---|---|
| Gameplay rules (matching, staging, win/lose), theme behavior | M2 |
| Play flow, save system, result screens | M3 |
| Level schema/loader/validator/migrations | M5 |
| Solver + state hashing, difficulty analyzer, generator | M6–M8 |
| Progression/coins/save migrations | M10 |
| Boosters / undo | M11 |
| Analytics/remote config/monetization abstractions | M12–M14 |
| Production signing, AAB release, Firebase credentials | M16 |

## 8. Module placement rules

- New gameplay logic goes to `game/core/**` or `game/puzzle/**` — never into
  scenes or UI.
- Theme assets/terminology belong to `game/themes/<theme>` and
  `content/themes/<theme>`; generic contracts stay in `game/themes/base/**`.
- Presentation consumes events through the documented contract; it never
  mutates state or decides correctness.
- Cross-boundary changes require explicit justification (blueprint §78).
