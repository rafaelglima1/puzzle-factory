# Changelog

All notable changes to this repository are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
