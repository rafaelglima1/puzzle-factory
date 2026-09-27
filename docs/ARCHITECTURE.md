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

M3 adds, in the same layer:

- `m3_level_catalogue.gd` — COMPATIBILITY FACADE (M5 cutover): the ten levels
  no longer live here; the official content pack is the single source of truth
  and this class delegates to `TrafficLevelCatalogue` + `LevelValidator` so M3
  callers keep their API without a second hardcoded copy;
- `traffic_first_playable_session.gd` — first-playable orchestration: owns the
  current `Simulation`, level index, restart/next flow, progress updates,
  presentation binding and the per-command `forward_result` +
  `sync_authoritative_state` contract. It contains no layout, copy, juice,
  coins, ads or boosters.
- `traffic_m3_app_controller.gd` (+ `.tscn`) — **the app composition root**
  (`application/run/main_scene` since the M3 integration pass). It owns the M3
  presentation shell (AGENT-2) and the session, translates shell intents into
  session calls and session signals into `show_*` calls, keeps a single
  router binding for the app lifetime, layouts the real board after each level
  starts, and tears everything down leak-free. It is the only place allowed to
  know both sides, exactly as ADR-013 requires; presentation still never imports
  `game/core/**` or `game/puzzle/**`.

Startup flow:

```text
project.godot (main_scene) -> TrafficM3AppController
    -> M3FirstPlayable shell (MAIN_MENU, "Project Traffic", PLAY)
    -> TrafficFirstPlayableSession (reloads the persisted M3 profile)
    -> presenter binding (adapter/router, official event vocabulary)
```

Persistence (`game/persistence/**`) is generic infrastructure (product-free,
guarded by `architecture_test.gd`): canonical JSON in `user://`, injectable
paths, corruption-safe defaults. M3 ships `m3_progress_store.gd`
(`user://m3_progress.json`, unlock/completion) and M4 adds
`m4_presentation_settings_store.gd`
(`user://m4_presentation_settings.json`, Music/Sound/Haptics switches) — two
separate documents read only by the integration layer. M10 replaces both with
the robust save/migration system and a consolidated `settings` block.

Station board anchors (cell/footprint) live in generic `Destination.metadata`
as product composition data, so core stays agnostic while presentation gets
what it needs.

### M5 content platform + solver

`game/levels/**` (generic, product-free, guarded by `architecture_test.gd`):

- `definitions/` — `LevelDefinition` (schema v1) + `LevelLoadResult`;
- `loader/` — `LevelLoader` (read → parse → migrate → build → validate);
- `validator/` — `LevelValidator` (static, structured error codes; never solves);
- `migrations/` — `LevelMigrator` (explicit vN→vN+1 chain, deterministic);
- `packs/` — `LevelPack` (manifest).

`game/solver/**` (generic, product-free, scene-tree-free):

- `state_hasher.gd` — canonical SHA-256 logical-state identity;
- `solver_domain.gd` — the product adapter contract;
- `bfs_solver.gd` — BFS + visited/losing/no-op pruning + predecessor
  reconstruction; `SOLVABLE` only after an independent replay;
- `solution_replay.gd`, `solver_result.gd`.

Official content lives in `game/content/levels/traffic/pack_001/` (JSON). The
product adapter `game/integration/traffic/levels/traffic_level_definition_adapter.gd`
maps generic definitions to the Traffic factory, and
`game/integration/traffic/solver/traffic_solver_domain.gd` drives the real
simulation through the generic solver. Production startup resolves levels
through the official pack (no hardcoded catalogue). Contracts:
`docs/LEVEL_SCHEMA.md`, `docs/SOLVER.md`.

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
- **M3 (AGENT-1 half):** `TrafficFirstPlayableSession` orchestration (play /
  start / restart / next / debug select / dispatch + presentation binding and
  authoritative sync), the ten-level catalogue (now the M5 official content
  pack; `M3LevelCatalogue` is a compatibility facade), and
  `M3ProgressStore` (`game/persistence/`, minimal unlock persistence under
  `user://`). Contract for the UI shell: `docs/M3_SESSION_CONTRACT.md`.
- **M3 (integration, both halves):** `TrafficM3AppController` composes the
  AGENT-2 presentation shell with the AGENT-1 session and becomes the app
  entry point, so the APK boots into **Project Traffic** (main menu → Play →
  real tapping → win/fail → retry/next over ten levels) instead of the M0
  placeholder. The shell owns all presentation; the controller owns product
  navigation and forwards intents/signals only.
- **M4 (both halves + integration):** presentation UX/juice (feedback, eased
  movement, bounded completion/failure sequences with a deferred result reveal,
  transitions, procedural audio through a bounded 8-player pool, haptic
  priority/cooldown, Settings screen) plus the infrastructure it needs:
  `M4PresentationSettingsStore` (`game/persistence/`, product-free) and the real
  `game/default_bus_layout.tres` (`Master → Music / SFX / UI`). The integration
  pass wires persistence into the composition root: the controller owns the
  settings store, loads it before the shell is shown, applies the persisted
  values before `show_main_menu()`, and persists Settings toggles. Presentation
  still imports no persistence; the store imports no presentation.
- **M5 (content engine):** the formal versioned level platform
  (`game/levels/**`: schema v1, loader, static validator, deterministic
  migration, pack manifest), the official Project Traffic content pack
  (`game/content/levels/traffic/pack_001/`, ten levels), the generic BFS solver
  with deterministic state hashing and replay validation (`game/solver/**`),
  the Traffic adapters (`game/integration/traffic/levels/**`,
  `game/integration/traffic/solver/**`), and the runtime cutover so the session
  and app start levels from the official pack. Contracts:
  `docs/LEVEL_SCHEMA.md`, `docs/SOLVER.md`, `docs/SOLVER_PERFORMANCE.md`.

Deferred:

| Concern | Milestone |
|---|---|
| Production music/SFX assets, volume sliders, locale | M4 polish / later |
| Difficulty score/buckets/weights, level generator, batch generation, dedupe (new M6 generation engine) | M6 |
| Robust progression/coins/save/migration (replaces `M3ProgressStore`) | M10 |
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
