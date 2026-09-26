# Architecture

> Scope: **M2 Traffic Gameplay (simulation)** — foundation M0, deterministic
> core M1, generic mechanics + product integration M2. Systems marked
> "deferred" are designed in the blueprint but intentionally not implemented.
> Authority: `docs/MASTER_BLUEPRINT.md` §8–§18, §78; ADR-013.

## 1. Layers

```text
PRESENTATION (game/themes/<theme>, game/ui, game/audio, game/haptics)
      ↑ presentation DTOs + event names (docs/TRAFFIC_PRESENTATION.md)
PRODUCT INTEGRATION (game/integration/<product>)            ADR-013
      ↑ adapter: DomainEvent -> presentation, state -> view data
GENERIC PUZZLE (game/puzzle: simulation, gameplay, presentation_bridge)
      ↑ commands in, results out
CORE (game/core: board, entities, state, movement, matching,
      objectives, rules, commands)
      ↑ pure data + deterministic rules
DATA (content/, level definitions at M5, configs)
```

Dependency direction is enforced by tests:

- `game/core/**`, `game/puzzle/**`, `game/themes/base/**` must not contain
  product vocabulary and must not reference `res://integration/**`
  (`game/tests/architecture_test.gd`).
- `game/themes/traffic/**`, `game/ui/**`, `game/audio/**`, `game/haptics/**`
  must not import `game/core/**` or `game/puzzle/**`
  (`game/tests/presentation_boundary_test.gd`, AGENT-2 owned).
- The integration layer may import both sides and is the only translation
  point (ADR-013).

## 2. Non-negotiable principles

| Principle | ADR / blueprint |
|---|---|
| Seeded, reproducible randomness; no physics-authoritative gameplay | ADR-002, §8.3, §11 |
| Simulation/presentation strict separation | ADR-003, ADR-012, §8.2 |
| Synchronous deterministic events; presentation-side queue | ADR-012, §12 |
| Product vocabulary only in the integration/theme layers | ADR-013, §8.1 |
| Offline-first, no custom backend | ADR-006, §66, §91 |
| Godot 4.7.2 + GDScript pinned | ADR-001, §5 |
| Data-driven levels; no custom code per production level | §18 |
| Serializable, versioned `GameState` (save/replay/undo/solver) | §10, §100 |
| Versioned contracts: SaveSchema / LevelSchema / RemoteConfigSchema | §100 |

## 3. Deterministic core (M1)

- **Board/occupancy.** `Board` is authoritative for blocking; one cell holds at
  most one entity id. `Entity.position` is written only through board
  placement/movement, so the index and the entity cannot diverge. Removing an
  entity (completed or staged) clears its position. All validation precedes
  mutation, so rejections are atomic. Iteration is deterministic (sorted ids,
  row-major cells).
- **Entity model.** Generic fields only (`id`, `entity_type`, `position`,
  `orientation`, `footprint`, `color_key`, `capacity`, `movement_type`,
  `allowed_directions`, `path_id`, `destination_id`, `state`, `metadata`) with
  an explicit state graph (`EntityState`).
- **RNG.** `RandomSource` contract + `DeterministicRng` (ANSI-C LCG, engine
  independent, fully serializable). `CommandContext` commits RNG state only for
  successful commands. M2 gameplay consumes no randomness (tested).
- **State.** `GameState` with canonical `Serialization` (sorted keys,
  StringName→String, integral-float normalization). Logical state hashing stays
  deferred to M6; the canonical dictionary is the stable identity for now.
- **Commands/events.** `GameCommand` → `CommandContext` → `CommandResult`
  {status, code, events}. `Simulation.execute()` is the single headless entry
  point; rejected commands never mutate state.

## 4. Generic puzzle mechanics (M2)

| Concern | Implementation |
|---|---|
| Item | `game/core/entities/item.gd` |
| Destination | `game/core/entities/destination.gd` (accepted keys, capacity, processed counter, state) |
| FIFO queue | `game/core/state/item_queue.gd` |
| Staging area | `game/core/state/staging_area.gd` (arbitrary capacity, lowest-free-slot) |
| Matching rule | `game/core/matching/matching_rule.gd`, `color_key_matching_rule.gd` |
| Logical path | `game/core/movement/logical_path.gd` |
| Objectives | `game/core/objectives/objective.gd`, `clear_all_objective.gd`, `objective_factory.gd` |
| Failure reasons | `game/core/rules/fail_reason.gd` |
| Arrival resolution | `game/puzzle/gameplay/arrival_resolver.gd` |
| Win/lose evaluation | `game/puzzle/gameplay/progress_evaluator.gd` |
| Player action | `game/core/commands/dispatch_entity_command.gd` |

Rules are documented in detail in `docs/GAME_RULES.md`. Highlights: strict FIFO
front-only loading bounded by entity and destination capacity; loaded ≥1 item ⇒
complete and leave the board; loaded 0 items ⇒ staged, and a full staging area
loses the level with `staging_full`; `no_valid_moves` is evaluated after every
successful action.

### State schema

`GameState.SCHEMA_VERSION` is **2**. v2 adds `items`, `queues`, `destinations`,
`paths`, `staging`, `objectives`, `objectives_completed`, `fail_reason`.
v1 payloads are migrated deterministically (`GameState.migrate_dictionary`) and
remain loadable and validatable; migration is covered by tests. Completion names
keep M1 spellings (`completed` = won, `failed` = lost) for serialized
compatibility, with `is_won()`/`is_lost()` aliases.

## 5. Product integration layer (M2)

`game/integration/traffic/**` (AGENT-1):

- `traffic_game_factory.gd` — composes generic concepts into a Traffic level
  definition (vehicle → entity, passenger → item, station → destination,
  holding → staging, route → logical path) and validates the definition.
- `traffic_event_map.gd` — pure mapping of generic events to presentation
  names/payloads (prefers AGENT-2 provisional names) plus derived staging
  pressure.
- `traffic_presentation_adapter.gd` — forwards events to the AGENT-2 router and
  projects state into AGENT-2 view DTOs; read-only for simulation state.

Station board anchors (cell/footprint) live in generic `Destination.metadata`
as product composition data, so core stays agnostic while presentation gets
what it needs.

## 6. Build environments

Defined in `content/configs/environments/*.json` (contract only until the
services exist):

| | Debug | QA | Production |
|---|---|---|---|
| Debug menu | yes | no | no |
| Verbose logs | yes | no | no |
| Ads | disabled (test at M14) | test | production |
| Analytics | disabled (M12) | marked QA | production |
| Signing | debug | debug → release (M16) | release |

## 7. Ownership boundaries (blueprint §78, ADR-013)

| Path | Owner |
|---|---|
| `game/core/**`, `game/puzzle/**`, `game/levels/**`, `game/solver/**`, `game/generator/**`, `game/persistence/**` | AGENT-1 |
| `game/integration/traffic/**` | AGENT-1 |
| `game/themes/base/**` (generic contracts) | AGENT-1 |
| `game/themes/traffic/**` (concrete theme) | AGENT-2 |
| `game/ui/**`, `game/audio/**`, `game/haptics/**`, presentation, animations, particles | AGENT-2 |
| Core/gameplay/integration test suites | AGENT-1 |

Cross-boundary changes require coordination; disagreements are resolved by ADR,
never silent divergence.

## 8. Reference resolution decision

`1080 × 1920` is an approved **design reference only** (and the current project
viewport default), not a fixed logical rendering requirement. Responsive
behaviour across the §62 device matrix remains AGENT-2's responsibility.

## 9. Current state vs deferred

Implemented:

- **M0:** Godot project, portrait config, headless tests, Android Debug export
  (minSdk 24 / targetSdk 36), CI skeleton, docs, ADRs.
- **M1:** board/occupancy, entity model, deterministic RNG, `GameState` +
  canonical serialization, command system, domain events, presentation bridge.
- **M2:** items/queues/destinations/staging/matching/capacity/paths/objectives,
  dispatch + arrival + win/lose rules, additive event catalog, Traffic product
  integration layer (factory + event map + presentation adapter), schema v2
  with v1 migration, architecture guards.

Deferred:

| Concern | Milestone |
|---|---|
| Main menu, play flow, HUD, result screens, level select | M3 |
| Juice/audio/haptics implementation, settings persistence | M4 |
| Level schema/loader/validator/migrations, obstacles | M5 |
| Solver + state hashing, difficulty analyzer, generator | M6–M8 |
| Progression/coins/save system | M10 |
| Boosters / undo | M11 |
| Analytics/remote config/monetization abstractions | M12–M14 |
| Production signing, AAB release, Firebase credentials | M16 |

## 10. Module placement rules

- New gameplay logic goes to `game/core/**` or `game/puzzle/**` — never into
  scenes, UI or the integration layer.
- Product vocabulary belongs to `game/integration/<product>/**` and
  `game/themes/<theme>/**`; generic contracts to `game/themes/base/**`.
- Presentation consumes events/view data; it never mutates state or decides
  correctness.
- Cross-boundary changes require explicit justification (blueprint §78).
