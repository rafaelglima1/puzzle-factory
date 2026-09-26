# Architecture

> Scope: **M0 Foundation**. This document describes the architecture
> *contracts* established at M0. Systems marked "deferred" are designed
> in the blueprint but intentionally not implemented yet.
> Authority: `docs/MASTER_BLUEPRINT.md` §8, §78.

## 1. Layers

```text
PRESENTATION (game/ui, game/themes, audio, haptics, animations)
      ↑ consumes domain events
SIMULATION / CORE (game/core, game/puzzle/simulation)
      ↑ pure data
DATA (content/, levels schemas, configs)
```

- **Core** (`game/core/**`): board, entities, movement, matching,
  objectives, rules, state, commands — generic concepts only
  (`Entity`, `Item`, `Destination`, `Queue`, `Slot`, `Board`, `Path`,
  `Position`, `Direction`, `ColorKey`, `Capacity`, `Constraint`,
  `Objective`, `GameState`). The core MUST NOT know theme words like
  `bus`, `passenger`, `airport`, `train`, `taxi`, `ship`, `warehouse`
  (blueprint §8.1).
- **Puzzle** (`game/puzzle/**`): gameplay orchestration, deterministic
  simulation loop, validation, presentation bridge.
- **Presentation** (`game/themes`, `game/ui`, `game/audio`,
  `game/haptics`): consumes simulation events; never decides puzzle
  correctness (ADR-003).

## 2. Non-negotiable principles

| Principle | ADR / blueprint |
|---|---|
| Seeded, reproducible randomness; no physics-authoritative gameplay | ADR-002, §8.3, §11 |
| Simulation/presentation strict separation | ADR-003, §8.2 |
| Offline-first, no custom backend | ADR-006, §66, §91 |
| Godot 4.7.2 + GDScript pinned | ADR-001, §5 |
| Theme-independent core; themes map generic concepts | §8.1, §38 |
| Data-driven levels; no custom code per production level | §18 |
| Serializable `GameState` (save/replay/undo/solver) | §10 |
| Versioned contracts: SaveSchema / LevelSchema / RemoteConfigSchema | §100 |

## 3. Build environments

Defined in `content/configs/environments/*.json` (contract only at M0):

| | Debug | QA | Production |
|---|---|---|---|
| Debug menu | yes | no | no |
| Verbose logs | yes | no | no |
| Ads | disabled (test at M14) | test | production |
| Analytics | disabled (M12) | marked QA | production |
| Signing | debug | debug → release (M16) | release |

Service integration flags stay `disabled` until their milestones; no
Firebase/AdMob/IAP code or credentials exist in the repository at M0.

## 4. Current state (M0) vs deferred

Implemented:

- Godot project + portrait configuration + boot placeholder
- Headless test runner and foundation tests
- Android Debug export configuration and verification
- Scripts + CI workflow skeleton + docs + ADRs

Deferred (milestone ownership):

| Concern | Milestone |
|---|---|
| Board/entity/commands/state/RNG | M1 |
| Traffic gameplay, matching, win/lose | M2 |
| Play flow, save, result screen | M3 |
| Level schema/loader/validator/migrations | M5 |
| Solver, state hashing, difficulty, generator | M6–M8 |
| Progression/coins/save migrations | M10 |
| Analytics/remote config/monetization abstractions | M12–M14 |
| Production signing, AAB release, Firebase credentials | M16 |

## 5. Module placement rules

- New gameplay logic goes to `game/core/**` or `game/puzzle/**` — never
  into scenes or UI.
- Theme-specific assets/terminology go to `game/themes/<theme>` and
  `content/themes/<theme>`.
- Cross-boundary changes (core ↔ presentation) require explicit
  justification (blueprint §78).
