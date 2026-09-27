# Changelog

All notable changes to this repository are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — M4 UX / juice + presentation settings integration

- Presentation UX/juice (AGENT-2): immediate tap acknowledgement, eased movement,
  blocked/rejected caution feedback, staging-pressure feedback, match/loading/
  objective polish, bounded completion/failure sequences with a **deferred result
  reveal** (gameplay stays visible, the result appears only after the sequence
  finishes or is safely skipped), bounded screen transitions, procedural audio
  routed through a bounded 8-player pool, haptic priority/cooldown, and a
  Settings screen (Music / Sound / Haptics, each OFF-capable). The M3 350 ms
  result-input guard is preserved.
- Presentation settings infrastructure (AGENT-1): `M4PresentationSettingsStore`
  (`game/persistence/`, product-free) persisting `music_enabled`/`sound_enabled`/
  `haptics_enabled` at `user://m4_presentation_settings.json`, plus the real Godot
  audio bus layout `game/default_bus_layout.tres` (`Master → Music / SFX / UI`)
  wired from `game/project.godot`.
- M4 integration (`integration/m4`): `TrafficM3AppController` now owns the
  settings store, loads it before the shell is shown, applies the persisted
  values to the shell/presenter _before_ `show_main_menu()` (no flash of the
  enabled defaults), and persists Settings toggles through the shell's
  `music_enabled_changed` / `sound_enabled_changed` / `haptics_enabled_changed`
  intents. A persistence failure keeps the runtime choice active, records the
  error (`last_settings_save_error()`), warns, and continues (no retry queue —
  M10 owns robust persistence). Partial-start teardown is now leak-free.

### Fixed — valid-move feedback seam (M4)

- `SFX_VALID_MOVE` was declared, generated and registered but never played. It is
  now requested exactly once on the authoritative `entity_move_started` event —
  never on the pre-validation tap, and never for `entity_blocked` or
  `command_rejected`. Presentation-only; it cannot alter the simulation result.

### Added — M3 first playable integration (app composition + startup)

- `TrafficM3AppController` (`game/integration/traffic/` + `.tscn`): the app
  composition root that owns the M3 presentation shell and the session, wires
  shell intents → session calls and session signals → `show_*` calls, keeps one
  router binding for the app lifetime, lays out the real board after each level
  starts (and on resize), and tears down leak-free. It contains no puzzle
  correctness.
- Application startup now points `application/run/main_scene` at the controller
  scene, so the APK boots into **Project Traffic** (main menu, PLAY, real
  levels) instead of the M0 placeholder. `bootstrap_test.gd` now proves the M3
  composition root instead of the placeholder label (no boot validation was
  weakened).
- Presenter integration hardening: starting a level resets stale cosmetic state
  (movement target, result lock, pending removals) so NEXT/RETRY/restart are
  immediately playable and a restart cannot leave a tween pointing at a freed
  entity view.
- Cross-layer tests: `m3_app_integration_test.gd` (startup/play/real tap/win/
  next/fail+retry/restart/menu re-entry/input de-dupe/responsive real boards),
  `m3_app_resume_test.gd` (app restart resume without manual loads, missing and
  malformed saves, debug isolation end-to-end, release debug gate) and
  `m3_campaign_integration_test.gd` (all ten levels played through the real
  shell/controller with the proven sequences, unlock progression 1→10, final
  level terminal behaviour, plus a debug sweep of every level).

### Fixed — result screen skipped by the winning tap (device)

- On a phone the winning tap could land exactly where `NEXT`/`MENU` appear (the
  vehicles sit at the same height as the result buttons) and Android also
  delivers a synthetic mouse event for that same tap, which activated the button
  that had just appeared under the finger — skipping the result (on device it
  jumped a level or dropped to the main menu). `result_screen.gd` now ignores
  player presses for a short window after the result is shown; the guard lives
  at the intent boundary, so it holds regardless of how the event was routed.
  Verified on a physical device (win → result stays → `NEXT` works after the
  window). `m3_app_integration_test.gd` asserts a press during the guard does
  not advance and that the same press works once the guard elapses.

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
