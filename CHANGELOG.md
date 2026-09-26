# Changelog

All notable changes to this repository are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed — M3 session progress resume

- `TrafficFirstPlayableSession` now owns progress initialization: its
  constructor loads the persisted profile, so
  `TrafficFirstPlayableSession.new()` + `play()` resumes at the highest
  unlocked level without any caller touching `load_progress()` (blueprint M3
  "progress survives app restart"). Missing or malformed saves fall back to a
  clean level-1 profile without crashing; injecting a store only redefines the
  persistence path.
- Debug level selection is isolated from production progression: a
  `debug_select_level()` win still emits `level_won` but never persists and
  never unlocks anything (`is_debug_attempt()` reports it;
  `restart_current_level()` keeps the flag). `next_level()` from a debug level
  starts a normal, persisting attempt.
- Tests: new `m3_session_resume_test.gd` (resume without a manual load, fresh
  install, malformed save, debug isolation) and the session suite no longer
  calls `load_progress()` itself, so the production initialization path is what
  the suite exercises.

### Added — M3 First Playable (AGENT-1: session, levels, basic save)

- `TrafficFirstPlayableSession` (`game/integration/traffic/`): play/start/
  restart/next/debug-select flow, entity dispatch with the M2
  `forward_result` + `sync_authoritative_state` contract, terminal signals
  (`level_started`, `level_restarted`, `level_won`, `level_failed`,
  `progress_changed`, `campaign_finished`, `session_error`), presentation
  binding with clean router lifecycle. UI contract documented in
  `docs/M3_SESSION_CONTRACT.md`.
- `M3LevelCatalogue`: ten original, deterministic, manually authored levels
  (product data in the integration layer) using only M2 mechanics, validated
  against `TrafficGameFactory`; each level has a scripted winning sequence
  proven in tests (10/10 completable). M5 replaces the catalogue.
- `M3ProgressStore` (`game/persistence/`): minimal offline progress persistence
  (version, highest unlocked level, completed level ids, last selected level),
  canonical JSON under `user://` with an injectable path, corruption-safe
  defaults, no coins/economy/cloud/backup/migration (all M10).
- Tests: catalogue integrity, 10/10 scripted solvability with determinism and
  negative paths, progress store (defaults, unlock, idempotency, corruption,
  clamping, atomic serialization), session flow (restart equivalence, next,
  terminal level, debug select, blocked-dispatch atomicity, disposal without
  leaks), plus a persistence architecture guard.

### Fixed — M2 cross-integration (simulation ↔ traffic presentation)

- One official snake_case event vocabulary end to end: `TrafficEventMap` no
  longer renames domain events into the obsolete PascalCase proposal names and
  instead forwards the official names, enriching presentation payloads only
  (`entity_move_started.path`, `staging_changed.pressure`).
- `TrafficPresenter.bind_router()` now subscribes the additive M2 events
  (`entity_completed`, `item_loaded`, `match_occurred`, `staging_changed`,
  `objective_completed`, `game_completed`, `game_failed`) and maps them onto
  the presentation hooks; unknown events stay safely ignorable.
- Movement sequencing fixed: no backwards snap when `entity_moved` arrives
  during an active tween (authoritative target applied when it ends), the full
  logical `path` is used for interpolation, completed/staged entity views are
  removed only after their animation finishes, and the movement lock stays
  bounded by `MOVE_LOCK_CAP`.
- Orientation is projected in degrees (north 0 / east 90 / south 180 /
  west 270) to match the Traffic DTO and theme.
- Fail reasons use the simulation's canonical lowercase ids (`staging_full`,
  `no_valid_moves`); uppercase aliases remain accepted for compatibility.
- Added `TrafficPresentationAdapter.bind_presenter()` and
  `sync_authoritative_state()` — authoritative destination occupancy/queue,
  staging occupancy and staging pressure refresh for the caller/M3 layer.
- Replaced the self-consistent mock-router assertions with real cross-layer
  tests (`traffic_integration_test.gd`) covering the happy path with a turning
  path, staging, both failure reasons, orientation and movement
  synchronization.

### Added — M2 Traffic Gameplay (simulation)

- Generic puzzle mechanics under `game/core/`:
  - `entities/item.gd`, `entities/destination.gd` (accepted color keys,
    capacity, processed counter, state)
  - `state/item_queue.gd` (deterministic FIFO, serializable),
    `state/staging_area.gd` (arbitrary slot count, lowest-free-slot,
    overflow refusal)
  - `matching/` contract + `ColorKeyMatchingRule`
  - `movement/logical_path.gd` (validated deterministic waypoint list)
  - `objectives/` (`Objective`, `ClearAllObjective`, `ObjectiveFactory`),
    `rules/fail_reason.gd` (`staging_full`, `no_valid_moves`)
- Gameplay pipeline in `game/puzzle/gameplay/`: `ArrivalResolver`
  (strict FIFO loading bounded by entity/destination capacity, complete vs
  stage) and `ProgressEvaluator` (objectives, win, `no_valid_moves`).
- `DispatchEntityCommand` — the product player action (move along a validated
  logical path, resolve arrival, evaluate progress) with stable rejection codes
  and atomic rejections.
- `GameState` schema **v2**: items, queues, destinations, paths, staging,
  objectives, objectives_completed, fail_reason; deterministic v1 → v2
  migration with compatibility tests.
- Seven additive domain events: `item_loaded`, `match_occurred`,
  `entity_completed`, `staging_changed`, `objective_completed`,
  `game_completed`, `game_failed`; `entity_moved` gained an additive `path`
  field. `PresentationContract` stays version 1 (additive change).
- Product integration layer (`game/integration/traffic/`, ADR-013):
  `TrafficGameFactory` (level composition/validation),
  `TrafficEventMap` (event/presentation mapping + pressure),
  `TrafficPresentationAdapter` (router forwarding + AGENT-2 view DTO
  projection, read-only).
- Tests: item, queue, destination, staging, matching, path, objective,
  traffic gameplay, traffic integration; extended architecture guards,
  GameState migration/validation and event catalog coverage (1157 checks).

### Added — M1 Puzzle Core

- Deterministic, theme-independent core under `game/core/`:
  - `board/`: `Board` (authoritative occupancy, atomic
    placement/movement, deterministic iteration), `BoardDimensions`,
    `GridPosition`, `Footprint`, `Direction`.
  - `entities/`: generic `Entity` model and `EntityState` transition graph.
  - `state/`: `RandomSource` contract, `DeterministicRng` (engine-independent
    ANSI-C LCG with serializable state), `GameState` (schema_version 1) and
    canonical `Serialization` (sorted keys, JSON-safe, integral-float
    normalization).
  - `commands/`: `GameCommand`, `CommandContext`, `CommandResult`,
    `DomainEvent`, `PlaceEntityCommand`, `MoveEntityCommand`.
- `game/puzzle/simulation/simulation.gd`: headless `Simulation` facade
  (rejected commands never mutate state, RNG committed only on success).
- Presentation bridge: `SimulationEventQueue` + `PresentationContract`
  (version 1) and `docs/PRESENTATION_BRIDGE.md` (event model, ordering
  guarantee, payload conventions, rejection rule, extension policy).
- Theme base contract: `game/themes/base/theme_contract.gd` (manifest
  validation, presentation slot names, ColorKey format) — ownership
  recorded (AGENT-1 base, AGENT-2 concrete themes).
- Tests: `board_test`, `occupancy_test`, `entity_test`, `rng_test`,
  `game_state_test`, `command_test`, `events_test`,
  `presentation_bridge_test`, `architecture_test` (446 checks total).
- ADR-012: synchronous domain event emission with a presentation-side queue.
- Architecture guard: automated test preventing theme vocabulary,
  presentation references or scene-tree usage in generic layers.

### Added — M0 Foundation

- Repository structure per blueprint §7 (`game/`, `content/`, `tools/`,
  `tests/`, `docs/`, `docs/adr/`, `ci/`, `scripts/`, `.github/`).
- Godot 4.7.2-stable project (`game/`): portrait 1080×1920, mobile
  renderer, ETC2/ASTC + S3TC/BPTC import, placeholder boot scene showing
  "Puzzle Factory", placeholder project icon.
- Headless test foundation: runner (`game/tests/run_tests.gd`) with
  bootstrap, determinism and framework self-tests (26 checks).
- Android Debug export preset (Gradle build): package
  `com.puzzlefactory.game`, versionCode 100, versionName 0.1.0,
  minSdk 24, targetSdk 36, portrait, debug signing only.
- Build environment contracts: `content/configs/environments/
  {debug,qa,production}.json` (structure only, no credentials).
- Scripts: `import_project.ps1`, `run_tests.ps1`,
  `export_android_debug.ps1`, `resolve_godot.ps1`.
- CI foundation: `.github/workflows/ci.yml` (checkout, Godot install,
  headless import, tests).
- Documentation: README, ARCHITECTURE, GAME_RULES, ANDROID, AGENT_RULES,
  RELEASE; ADR-001, ADR-002, ADR-003, ADR-006, ADR-011.

[Unreleased]: https://keepachangelog.com/en/1.1.0/
