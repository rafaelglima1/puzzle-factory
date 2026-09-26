# PUZZLE FACTORY — MASTER BLUEPRINT

> **Status:** Implementation Candidate  
> **Document Version:** 1.0.0  
> **Baseline Date:** 2026-09-26  
> **Initial Product Codename:** Project Traffic  
> **Primary Platform:** Android / Google Play  
> **Primary Engine:** Godot 4.7.2-stable  
> **Primary Language:** GDScript  
> **Repository Model:** Monorepo initially  
> **Source of Truth:** This document  
>
> **IMPORTANT:** Any implementation agent must read this document completely before changing production code.

---

## 0. Document Authority

This document defines the product, architecture, technical constraints, gameplay rules, content pipeline, analytics, monetization, testing, releases, milestones and future Puzzle Factory strategy.

When implementation code, old prompts, old notes and this document disagree, **this document wins**, unless a newer Architecture Decision Record (ADR) explicitly overrides a specific section.

Agents MUST NOT silently:

- change the architecture;
- introduce new infrastructure;
- change pinned platform versions;
- remove tests;
- weaken acceptance criteria;
- skip milestones;
- add backend services;
- add multiplayer;
- change the core game rules;
- add monetization mechanics not described here;
- introduce hard dependencies between the reusable core and a specific theme.

Any justified deviation must be documented in an ADR.

---

# 1. Product Vision

## 1.1 Product

Build a polished casual mobile puzzle game based on deterministic congestion, ordering, capacity, matching and limited-space decisions.

The first commercial product uses a **traffic / transportation theme**, but the technical product is larger:

> Build a reusable casual puzzle platform capable of producing multiple games from the same core.

The first game is therefore both:

1. a real commercial game; and
2. the first validation of the Puzzle Factory architecture.

## 1.2 Factory Vision

Long-term:

```text
Idea
  ↓
Select theme
  ↓
Select puzzle modules
  ↓
Generate theme package
  ↓
Generate candidate levels
  ↓
Validate levels
  ↓
Solve levels
  ↓
Classify difficulty
  ↓
Select production content
  ↓
Build game
  ↓
QA
  ↓
Soft launch
  ↓
Measure
  ↓
Kill / Improve / Scale
```

Potential products:

```text
Traffic Jam
Airport Jam
Train Station
Harbor Puzzle
Warehouse Puzzle
Taxi Queue
Animal Rescue
Space Dock
Restaurant Queue
Supermarket Cart
Robot Factory
```

The products may share infrastructure without sharing branding, art direction or exact level layouts.

---

# 2. Product Principles

The project MUST optimize for:

1. **Immediate comprehension**
2. **Short sessions**
3. **Fast restart**
4. **Satisfying feedback**
5. **Deterministic puzzle rules**
6. **Fair levels**
7. **Low operational cost**
8. **Offline-first gameplay**
9. **Data-driven iteration**
10. **Reusable infrastructure**
11. **Fast content production**
12. **Safe monetization experiments**
13. **Simple code over clever code**

The project MUST NOT optimize prematurely for:

- MMO architecture;
- backend scalability;
- multiplayer;
- social networking;
- guilds;
- live chat;
- real-time PvP;
- complicated account systems;
- subscriptions;
- battle passes;
- custom cloud infrastructure.

---

# 3. Legal / Product Originality Constraint

The project may use common puzzle genre concepts but MUST NOT copy a competitor's protected expression.

Do not copy:

- name;
- logo;
- icon;
- characters;
- art assets;
- exact UI layout;
- sounds;
- music;
- store screenshots;
- text;
- animation sequences;
- level layouts;
- branded terminology;
- unique visual identity.

The implementation must create an original visual identity, original progression presentation and original content.

---

# 4. Supported Platforms

## 4.1 Version 1

```text
Android phones: YES
Android tablets: supported where practical
Portrait orientation: YES
Landscape: NO
Offline gameplay: YES
Google Play: YES
iOS: NO
Desktop commercial release: NO
Web release: NO
```

Desktop/editor builds may exist for development tooling and QA.

## 4.2 Future

Possible after Android validation:

```text
iOS
additional stores
desktop tooling
web-based level editor
```

These are not part of 1.0.

---

# 5. Technology Baseline

Baseline is pinned to the state verified on **2026-09-26**.

| Component | Version / Rule |
|---|---|
| Godot | **4.7.2-stable** |
| Language | GDScript |
| Android targetSdk | **36** |
| Android compileSdk | **36** |
| Android minSdk | **24** |
| Android Build Tools | **36.0.0** where custom Android build requires it |
| Android Studio | **Quail 4 / 2026.1.4 Patch 1** |
| Android Gradle Plugin | **9.4.1** when custom build template is compatible |
| Gradle | **9.6.0** when using AGP 9.4.x custom build |
| JDK | **17** |
| Firebase Android BoM | **34.19.0** |
| Google Mobile Ads SDK | **25.5.0** |
| Primary VCS | Git |
| Remote repository | GitHub |
| Release format | Android App Bundle `.aab` |

### 5.1 Important Android requirement

From **2026-08-31**, new apps and updates submitted to Google Play must target Android 16 / API 36 or higher.

### 5.2 Why minSdk 24

Google Mobile Ads SDK 25.5.0 requires minimum Android API 24.

### 5.3 Dependency Update Rule

Never use floating `latest` versions in the production build.

Dependency update procedure:

```text
create branch
↓
update one dependency family
↓
build editor
↓
run tests
↓
export Android Debug
↓
smoke test physical device/emulator
↓
export QA
↓
document compatibility
↓
merge
```

If the Godot-provided Android template requires a different AGP/Gradle combination, preserve Godot compatibility and document the decision in an ADR before replacing the template.

---

# 6. Release Versioning

Semantic versioning:

```text
MAJOR.MINOR.PATCH
```

Initial plan:

```text
0.1.0 Foundation
0.2.0 Puzzle Core
0.3.0 First Playable
0.4.0 UX / Juice
0.5.0 Level Platform
0.6.0 Solver / Generator
0.7.0 Meta / Progression
0.8.0 Monetization / Analytics
0.9.0 Soft Launch
1.0.0 Production Launch
```

Android `versionCode` MUST monotonically increase and MUST never be reused.

Recommended starting sequence:

```text
100
101
102
...
```

---

# 7. Repository

Initial model:

```text
puzzle-factory/
```

Repository layout:

```text
/
├── game/
│   ├── project.godot
│   ├── core/
│   │   ├── board/
│   │   ├── entities/
│   │   ├── movement/
│   │   ├── matching/
│   │   ├── objectives/
│   │   ├── rules/
│   │   ├── state/
│   │   └── commands/
│   │
│   ├── puzzle/
│   │   ├── gameplay/
│   │   ├── simulation/
│   │   ├── validation/
│   │   └── presentation_bridge/
│   │
│   ├── levels/
│   │   ├── definitions/
│   │   ├── loader/
│   │   ├── validator/
│   │   ├── migrations/
│   │   ├── packs/
│   │   └── difficulty/
│   │
│   ├── solver/
│   ├── generator/
│   │
│   ├── themes/
│   │   ├── base/
│   │   └── traffic/
│   │
│   ├── meta/
│   │   ├── progression/
│   │   ├── economy/
│   │   ├── boosters/
│   │   ├── rewards/
│   │   └── cosmetics/
│   │
│   ├── persistence/
│   ├── monetization/
│   ├── analytics/
│   ├── remote_config/
│   ├── privacy/
│   ├── audio/
│   ├── haptics/
│   ├── localization/
│   ├── ui/
│   └── debug/
│
├── content/
│   ├── themes/
│   ├── levels/
│   ├── localization/
│   └── configs/
│
├── tools/
│   ├── level_generator/
│   ├── level_solver/
│   ├── level_validator/
│   ├── difficulty_analyzer/
│   ├── replay_runner/
│   ├── content_exporter/
│   └── theme_validator/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── levels/
│   ├── solver/
│   ├── generator/
│   ├── persistence/
│   └── smoke/
│
├── docs/
│   ├── MASTER_BLUEPRINT.md
│   ├── ARCHITECTURE.md
│   ├── GAME_RULES.md
│   ├── LEVEL_SCHEMA.md
│   ├── SOLVER.md
│   ├── GENERATOR.md
│   ├── ANALYTICS.md
│   ├── MONETIZATION.md
│   ├── ANDROID.md
│   ├── RELEASE.md
│   ├── AGENT_RULES.md
│   └── adr/
│
├── ci/
├── scripts/
├── .github/
├── README.md
└── CHANGELOG.md
```

---

# 8. Architectural Rules

## 8.1 Core independence

The reusable core MUST NOT know the words:

```text
bus
passenger
airport
train
taxi
ship
warehouse
```

The core understands generic concepts:

```text
Entity
Item
Destination
Queue
Slot
Board
Path
Position
Direction
ColorKey
Capacity
Constraint
Objective
GameState
```

Theme mapping example:

```text
Traffic:
Entity      -> Vehicle
Item        -> Passenger
Destination -> Station / Loading Area
```

```text
Airport:
Entity      -> Aircraft
Item        -> Passenger / Luggage
Destination -> Gate
```

```text
Warehouse:
Entity      -> Forklift
Item        -> Cargo
Destination -> Dock
```

## 8.2 Simulation vs presentation

Strict separation:

```text
SIMULATION
deterministic
testable
no animation dependency
no audio dependency
no ad dependency
no Firebase dependency

PRESENTATION
sprites/models
tweens
particles
camera
audio
haptics
UI
```

Presentation consumes simulation events.

Presentation MUST NOT decide puzzle correctness.

## 8.3 No physics-authoritative gameplay

Physics may be used for visual effects only.

Rigid body outcomes MUST NOT decide whether a puzzle is solvable.

Movement is defined by deterministic:

- cells;
- paths;
- occupancy;
- rules;
- waypoints;
- interpolation.

---

# 9. Core Domain Model

## 9.1 Entity

Base fields:

```text
id
entity_type
position
orientation
footprint
color_key
capacity
movement_type
allowed_directions
path_id
destination_id
state
metadata
```

Possible states:

```text
IDLE
BLOCKED
MOVING
WAITING
LOADING
UNLOADING
COMPLETED
DISABLED
```

## 9.2 Item

Generic item:

```text
id
item_type
color_key
destination_id
priority
special_type
metadata
```

Traffic theme maps this to a passenger.

## 9.3 Destination

```text
id
destination_type
accepted_color_keys
capacity
queue_id
state
```

## 9.4 Queue

```text
id
items[]
policy
visible_count
```

Initial queue policy:

```text
FIFO
```

Future policies may include:

```text
priority
grouped
masked
```

## 9.5 Staging Area

Generic temporary destination with limited capacity.

Default:

```text
slots = 4
```

Configurable per level.

---

# 10. Game State

The complete active puzzle state MUST be serializable.

Conceptual structure:

```text
GameState
├── schema_version
├── level_id
├── level_revision
├── seed
├── rng_state
├── board_state
├── entities[]
├── items[]
├── queues[]
├── destinations[]
├── staging_state
├── objectives[]
├── move_index
├── score
├── combo
├── elapsed_time
├── booster_state
└── completion_state
```

Required capabilities:

- save;
- load;
- replay;
- deterministic tests;
- undo;
- solver conversion;
- analytics snapshots;
- crash recovery.

---

# 11. Randomness

All gameplay randomness MUST be:

```text
seeded
deterministic
reproducible
```

No gameplay component may instantiate uncontrolled random state.

Given:

```text
level_id = 302
seed = 987234
```

the same gameplay input sequence MUST produce the same logical result.

---

# 12. Command System

Player actions are commands.

Example:

```text
SelectEntityCommand
MoveEntityCommand
UseBoosterCommand
UndoCommand
```

Flow:

```text
input
↓
command
↓
validate
↓
apply simulation mutation
↓
emit domain events
↓
presentation reacts
↓
persist checkpoint if required
```

A command may return:

```text
SUCCESS
BLOCKED
INVALID
GAME_ALREADY_COMPLETE
```

---

# 13. Initial Traffic Gameplay

## 13.1 Player goal

Clear the puzzle by selecting vehicles in an order that allows them to leave the congestion and correctly process waiting passengers/items without exhausting temporary capacity.

## 13.2 Primary action

```text
tap vehicle
```

The system:

1. resolves entity;
2. checks state;
3. determines path availability;
4. checks blocking;
5. validates destination/staging;
6. applies the move if valid;
7. animates;
8. processes matching/loading;
9. re-evaluates objectives;
10. evaluates win/lose state.

## 13.3 Invalid / blocked move

A blocked entity does not move.

Presentation must provide immediate feedback:

- small shake;
- short blocked sound;
- optional haptic;
- optional blocker highlight.

Do not punish a simple exploratory tap unless a future level rule explicitly adds a move limit.

---

# 14. Matching

Version 1 matching:

```text
color_key
```

Example:

```text
BLUE vehicle -> BLUE passengers
RED vehicle  -> RED passengers
```

The architecture must allow future matching rules without rewriting the core:

```text
destination
symbol
category
priority
wildcard
multi-color
```

Never rely only on literal render colors internally. Use stable keys such as:

```text
COLOR_A
COLOR_B
COLOR_C
```

---

# 15. Win Rules

Default v1:

```text
all required items processed
AND
all required entities completed
AND
all mandatory objectives completed
```

Future supported objective types:

```text
CLEAR_ALL
CLEAR_ENTITY_COUNT
PROCESS_ITEM_COUNT
PROCESS_COLOR
PROCESS_SPECIAL
MOVE_LIMIT
TIME_LIMIT
COLLECT_OBJECT
```

---

# 16. Lose Rules

Initial supported reasons:

```text
STAGING_FULL
NO_VALID_MOVES
MOVE_LIMIT_EXCEEDED
TIME_LIMIT_EXCEEDED
SPECIAL_OBJECTIVE_FAILED
```

Every failure MUST include a machine-readable `fail_reason` for analytics.

---

# 17. Undo

Undo is a first-class capability.

Requirements:

- restores exact previous logical state;
- restores deterministic RNG state;
- restores staging;
- restores queues;
- restores objective progress;
- does not duplicate rewards;
- does not duplicate analytics completion events.

Implementation may use:

```text
state snapshot
```

or:

```text
reversible state delta
```

For MVP, prefer correctness over memory micro-optimization.

---

# 18. Level Definition

No production level may require custom code.

Conceptual JSON representation:

```json
{
  "schemaVersion": 1,
  "levelId": "traffic_0042",
  "revision": 1,
  "seed": 18273,
  "themeId": "traffic",
  "board": {
    "width": 8,
    "height": 10
  },
  "entities": [],
  "items": [],
  "queues": [],
  "destinations": [],
  "obstacles": [],
  "staging": {
    "slots": 4
  },
  "objectives": [
    {
      "type": "CLEAR_ALL"
    }
  ],
  "allowedBoosters": [
    "UNDO",
    "EXTRA_SLOT",
    "SHUFFLE"
  ],
  "difficultyTarget": 0.52,
  "tags": []
}
```

The actual serialized Godot resource format may differ, but the logical schema must remain equivalent and versioned.

---

# 19. Level Schema Versioning

Every level has:

```text
schemaVersion
```

Future migration:

```text
v1 -> v2
v2 -> v3
```

Required component:

```text
LevelMigrator
```

Rules:

- never silently reinterpret old levels;
- migration must be deterministic;
- migration tests required;
- source level files should be migratable in tooling;
- released content must remain reproducible.

---

# 20. Level Validation

Validator checks at minimum:

```text
valid schema
unique IDs
valid board dimensions
valid positions
valid footprints
no illegal initial overlap
valid colors/keys
valid capacities
valid path references
valid destination references
valid queue references
valid objective references
valid booster IDs
valid staging configuration
no impossible static constraints
supported schema version
supported theme
```

Validation output:

```text
VALID
INVALID
```

with detailed error codes.

Example:

```text
ENTITY_OVERLAP
UNKNOWN_DESTINATION
DUPLICATE_ID
INVALID_CAPACITY
OUT_OF_BOUNDS
```

---

# 21. Solver

## 21.1 Purpose

The solver exists to guarantee fairness and power content generation.

Input:

```text
LevelDefinition
```

Output:

```text
SOLVABLE
UNSOLVABLE
UNKNOWN
```

plus metrics.

## 21.2 Required result

```text
SolverResult
├── status
├── solution_commands[]
├── solution_depth
├── visited_states
├── expanded_states
├── dead_end_count
├── branching_factor_avg
├── runtime_ms
└── metrics
```

## 21.3 Initial algorithm

Start simple:

```text
BFS + state hashing + pruning
```

Only move to:

```text
A*
IDA*
domain-specific heuristic search
```

when measured state-space cost requires it.

Do not optimize based on speculation.

## 21.4 Solver guarantees

For every shipped production level:

```text
status == SOLVABLE
```

`UNKNOWN` is not acceptable for shipped standard content.

---

# 22. State Hashing

Logical states require deterministic hashes.

Hash inputs must include all state that affects future gameplay:

```text
entity positions/states
queue contents
staging contents
objective state
relevant modifiers
rng state where applicable
```

Do not hash presentation state.

Uses:

- solver visited set;
- replay verification;
- duplicate detection;
- regression tests.

---

# 23. Difficulty Analyzer

Difficulty estimate range:

```text
0.00 -> 1.00
```

Initial model may use:

- optimal solution depth;
- branching factor;
- number of plausible wrong moves;
- dead-end ratio;
- staging pressure;
- color entropy;
- blocker density;
- dependency depth;
- solution uniqueness.

Example conceptual formula:

```text
estimatedDifficulty =
    weighted(
        normalized_solution_depth,
        dead_end_ratio,
        staging_pressure,
        false_choice_density,
        dependency_depth
    )
```

Weights are configuration, not hardcoded constants.

---

# 24. Real Difficulty

After user telemetry, estimated difficulty must be compared with observed difficulty.

Observed signals:

```text
completion_rate
fail_rate
restart_rate
quit_rate
attempts_to_complete
median_moves
median_completion_time
booster_usage_rate
continue_ad_usage
```

The system should support future calibration:

```text
estimated difficulty
vs
observed difficulty
```

No machine-learning system is required for v1.

---

# 25. Level Generator

Generator input:

```text
theme
mechanics
difficulty_target
entity_count
item_count
color_count
staging_slots
board_dimensions
seed
constraints
```

Output:

```text
LevelDefinition
```

Pipeline:

```text
generate
↓
static validate
↓
solve
↓
difficulty analyze
↓
duplicate analyze
↓
accept / reject
```

---

# 26. Batch Generation

Tool must support:

```text
generate 10,000 candidates
```

then:

```text
validate
solve
score
dedupe
bucket by difficulty
select production candidates
```

Expected report:

```text
generated: 10000
invalid: 1210
unsolvable: 3950
duplicates: 840
accepted: 4000
easy: 900
medium: 1800
hard: 1000
expert: 300
```

Numbers above are examples, not required target ratios.

---

# 27. Duplicate Detection

Duplicate detection should eventually consider:

- normalized board topology;
- entity dependency graph;
- optimal solution sequence;
- mechanic configuration;
- symmetry;
- color renaming equivalence.

Do not overbuild this during first playable.

---

# 28. Difficulty Curve

Do not use a permanently ascending linear curve.

Use waves.

Example:

```text
EASY
EASY
MEDIUM
MEDIUM
HARD
RELIEF
MEDIUM
HARD
HARD
RELIEF
```

Goals:

- teach new mechanic;
- test it;
- combine it;
- challenge;
- relieve;
- repeat.

---

# 29. Level Packs

Production levels grouped in packs.

Example:

```text
Pack 001: levels 1-50
Pack 002: levels 51-100
Pack 003: levels 101-150
Pack 004: levels 151-200
```

A level pack has:

```text
pack_id
content_version
min_game_version
levels[]
activation_rule
```

This supports future remote activation.

---

# 30. First Content Target

Production 1.0 target:

```text
>= 200 solver-validated levels
```

MVP/first playable:

```text
10 hand-authored levels
```

Do not create 200 production levels before validating the core fun.

---

# 31. Tutorial

Tutorial is contextual and interactive.

Avoid:

```text
long text slides
forced reading
multi-screen onboarding
```

Prefer:

```text
highlight
finger cue
one short instruction
required action
immediate result
```

Target:

```text
core tutorial completed by level 5
```

Tutorial steps emit analytics.

---

# 32. UX / Juice

Every valid action should feel responsive.

Potential presentation feedback:

```text
movement tween
anticipation
small bounce
particle burst
passenger/item movement
score pop
combo feedback
sound
haptic
camera micro-feedback
```

Do not allow presentation to delay logical correctness unnecessarily.

The player should regain control quickly.

---

# 33. Meta Progression

Initial progression:

```text
complete level
↓
earn coins
↓
unlock next level
↓
continue
```

No complex world map required for MVP.

Potential post-launch progression:

```text
city restoration
airport restoration
collection book
theme districts
```

Not part of first playable.

---

# 34. Economy

## 34.1 Currency

Version 1 uses only:

```text
Coins
```

Do not add multiple soft currencies before there is measured need.

## 34.2 Earn sources

```text
level completion
daily reward
rewarded ad
event
optional bonus objective
```

## 34.3 Spend sinks

```text
boosters
cosmetics
```

The economy MUST be configurable.

---

# 35. Boosters v1

## 35.1 Undo

Restores previous valid move.

## 35.2 Extra Slot

Temporarily adds one staging slot.

## 35.3 Shuffle

Applies a rules-safe transformation defined per puzzle type.

Shuffle MUST NOT make a solvable state unsolvable unless the player explicitly accepts a risky mechanic in a future design.

## 35.4 Fairness Policy

Every standard production level must be solvable:

```text
without boosters
without purchases
without watching ads
```

Boosters make the level easier, not possible.

---

# 36. Daily Reward

Initial design:

```text
7-day cycle
```

Rewards:

```text
coins
booster
```

Must be server-independent in first version, understanding that device-clock manipulation cannot be fully prevented offline.

Do not build a custom backend solely to prevent low-value reward abuse.

---

# 37. Daily Challenge

Post-1.0 candidate.

Concept:

```text
same challenge seed/content per day
```

Can initially use Remote Config/content packages.

Not required for 1.0.

---

# 38. Themes

Theme interface concept:

```text
ITheme
```

Theme provides:

```text
theme_id
terminology
entity visuals
item visuals
destination visuals
environment
UI skin
audio set
particle set
animation bindings
iconography
```

Core never loads `traffic` assets directly.

---

# 39. Theme Manifest

Conceptual example:

```json
{
  "themeId": "traffic",
  "themeVersion": 1,
  "entityPresentation": "vehicle",
  "itemPresentation": "passenger",
  "destinationPresentation": "station",
  "assetBundleVersion": 1
}
```

---

# 40. Mechanics Modules

Core architecture should eventually support reusable modules.

Initial:

```text
ColorMatching
Capacity
LimitedStaging
Blocking
PathMovement
```

Future:

```text
LockedEntity
KeyUnlock
Timer
MoveLimit
VIPItem
Wildcard
OneWayPath
Teleport
Switch
TrafficLight
FrozenEntity
Bomb
PriorityQueue
ChainMovement
MultiDestination
HiddenQueue
```

Do not implement future modules until required by a milestone/product.

---

# 41. Save System

## 41.1 Save content

```text
saveVersion
installationId
playerProgress
levelProgress
currencies
inventory
settings
dailyRewardState
tutorialState
experiments
lastSessionMetadata
```

Do not persist secrets.

## 41.2 Atomic writes

Procedure:

```text
serialize
↓
write temp
↓
validate temp
↓
replace current
↓
retain previous backup
```

Files conceptually:

```text
save.dat
save.bak
```

## 41.3 Save migrations

Required:

```text
SaveMigrator
```

Migration examples:

```text
v1 -> v2
v2 -> v3
```

Tests mandatory.

## 41.4 Corruption recovery

If current save cannot be parsed:

1. try backup;
2. validate backup;
3. restore backup;
4. log recovery;
5. do not silently reset if recovery is possible.

---

# 42. Crash Recovery

Active level state may be checkpointed so reopening the app can restore the current puzzle where practical.

The feature must not duplicate:

- coins;
- purchase rewards;
- ad rewards;
- level completion reward.

Idempotent reward handling is required.

---

# 43. Cloud Save

Not required for MVP or initial 1.0.

Candidate after product validation.

Potential implementation:

```text
Google Play Games Services / supported cloud mechanism
```

or another justified provider.

Do not add Firebase database solely for save before needed.

---

# 44. Analytics

Analytics are required before external beta.

Recommended initial provider:

```text
Firebase Analytics
```

No gameplay logic may depend on analytics availability.

## 44.1 Core events

```text
app_open
session_start
session_end

tutorial_step
tutorial_complete

level_start
level_move
level_complete
level_fail
level_restart
level_quit

booster_offer
booster_used

rewarded_offer
rewarded_start
rewarded_complete
rewarded_fail

interstitial_eligible
interstitial_show
interstitial_fail

purchase_view
purchase_start
purchase_complete
purchase_fail
purchase_restore

daily_reward_view
daily_reward_claim

settings_change
save_recovery
```

Do not emit `level_move` at massive unbounded volume in production unless cost/cardinality has been validated. Sampling or aggregated move telemetry may be used.

---

# 45. Analytics Properties

Common properties where appropriate:

```text
app_version
build_number
platform
device_tier
locale
country
session_id
level_id
level_revision
attempt_number
estimated_difficulty
experiment_ids
```

Level completion:

```text
elapsed_seconds
move_count
optimal_move_count
booster_count
rewarded_count
staging_peak
remaining_capacity
```

Failure:

```text
fail_reason
move_count
elapsed_seconds
staging_peak
booster_count
```

Never send PII unnecessarily.

---

# 46. KPI Dashboard

Minimum product dashboard:

```text
DAU
WAU
MAU

D1 retention
D3 retention
D7 retention
D30 retention

sessions per user
average session duration
levels per session

tutorial completion
level completion funnel

fail rate by level
restart rate by level
quit rate by level
booster usage by level

rewarded opt-in
rewarded impressions/user
interstitial impressions/user

ad ARPDAU
IAP ARPDAU
total ARPDAU

crash-free users
crash-free sessions
```

---

# 47. Initial Product Gates

These are internal decision gates, not universal promises.

Desired indicators:

```text
Tutorial completion > 80%

D1:
>= 25% = worth investigating
>= 30% = strong early signal

D7:
>= 7-10% = useful early signal

Crash-free sessions:
>= 99.5%
target >= 99.8%
```

Do not scale paid acquisition solely because revenue exists if retention is weak.

---

# 48. Remote Config

Recommended:

```text
Firebase Remote Config
```

Gameplay must have safe local defaults if Remote Config is unavailable.

## 48.1 Required keys

```text
config_schema_version

ads_enabled
rewarded_enabled
interstitial_enabled

first_interstitial_level
min_levels_between_interstitials
min_seconds_between_interstitials
max_interstitials_per_session

rewarded_continue_enabled
rewarded_extra_slot_enabled
rewarded_coin_enabled
rewarded_coin_amount

starting_coins

undo_coin_cost
extra_slot_coin_cost
shuffle_coin_cost

daily_reward_enabled

difficulty_override_enabled

level_pack_active_version

feature_daily_challenge
feature_shop
feature_cosmetics

maintenance_message_enabled
maintenance_message_text
```

Every config must have:

- type;
- default;
- valid range;
- owner;
- description.

---

# 49. Feature Flags

Use flags for risky/optional features.

Example:

```text
FEATURE_INTERSTITIALS
FEATURE_REWARDED_CONTINUE
FEATURE_DAILY_REWARD
FEATURE_DAILY_CHALLENGE
FEATURE_SHOP
FEATURE_COSMETICS
FEATURE_CLOUD_SAVE
```

Flags must not create save corruption when toggled.

---

# 50. Crash Reporting

Recommended:

```text
Firebase Crashlytics
```

Include non-sensitive context:

```text
game_version
level_id
level_revision
last_command_type
save_version
theme_id
```

Never attach:

- secrets;
- full purchase tokens unless required and protected;
- personal user text.

---

# 51. Monetization Principles

Monetization must not make standard levels intentionally impossible.

Priority:

```text
1. rewarded ads
2. remove-ads purchase
3. light interstitial usage
4. simple IAP
```

Avoid in v1:

```text
subscription
battle pass
loot boxes
aggressive energy system
paywall progression
```

---

# 52. Ads

Initial formats:

```text
Rewarded
Interstitial
```

Initial format NOT used:

```text
Banner
```

## 52.1 Rewarded placements

Potential placements:

```text
continue after failure
temporary extra slot
bonus coins
booster
double level reward
```

Every rewarded ad requires explicit user action.

## 52.2 Interstitial policy

Never:

```text
every level
every restart
during active gameplay
```

Eligibility must consider:

```text
level threshold
levels since last ad
time since last ad
session ad cap
current experiment
premium/remove-ads state
```

## 52.3 Service abstraction

```text
IAdsService
```

Conceptual API:

```text
initialize()
is_rewarded_ready()
show_rewarded(placement)
is_interstitial_ready()
show_interstitial(placement)
```

Gameplay must not import AdMob-specific types.

---

# 53. Ads State Machine

```text
UNINITIALIZED
INITIALIZING
READY
LOADING
SHOWING
FAILED
COOLDOWN
DISABLED
```

Ad failure never blocks gameplay.

---

# 54. Google Mobile Ads

Baseline:

```text
Google Mobile Ads SDK 25.5.0
```

Use Google test ad units in Debug/QA.

Production IDs MUST never be used for automated ad interaction.

Keep production ad identifiers outside generic gameplay code.

---

# 55. IAP

Initial candidates:

```text
remove_ads
starter_pack
coin_pack_small
coin_pack_medium
```

Do not implement all products until monetization milestone.

## 55.1 Purchase abstraction

```text
IPurchaseService
```

Conceptual operations:

```text
query_products()
purchase(product_id)
restore()
acknowledge_if_required()
```

## 55.2 Idempotency

Purchase grant must be idempotent.

A transaction must never grant twice because of:

```text
retry
app restart
callback duplication
restore
network recovery
```

---

# 56. Privacy / Consent

Requirements must be reviewed again before store submission because policies change.

Architecture must support:

```text
consent collection
ads personalization choice
analytics consent where required
privacy settings access
data deletion path if accounts are introduced later
```

Use current Google consent tooling when AdMob is enabled.

Do not collect unnecessary personal data.

---

# 57. Age Strategy

Initial product is not designed as a child-directed app.

Do not intentionally market specifically to children without a dedicated compliance review.

Use current SDK age/privacy APIs as required by store policy and jurisdiction.

---

# 58. Localization

Launch languages:

```text
pt-BR
en-US
es
```

All user-facing text must use localization keys.

Never hardcode production strings in scenes.

Example keys:

```text
ui.play
ui.settings
ui.continue
level.complete
level.failed
ads.watch_to_continue
booster.undo
booster.extra_slot
booster.shuffle
```

---

# 59. Accessibility

Minimum:

- readable text;
- adequate touch targets;
- UI scaling;
- do not rely solely on color;
- optional symbols/patterns for match groups;
- vibration can be disabled;
- sound can be disabled.

Color matching can combine:

```text
color + icon/symbol
```

---

# 60. Audio

Buses:

```text
Master
Music
SFX
UI
```

Persist settings.

Required SFX classes:

```text
tap
valid_move
blocked_move
loading
match
combo
level_complete
level_fail
reward
button
```

---

# 61. Haptics

Configurable.

Candidates:

```text
light: tap / valid move
warning: blocked / fail
success: combo / level complete
```

Avoid excessive vibration.

---

# 62. Screen / UI Targets

Primary:

```text
portrait
```

Test at least:

```text
16:9
18:9
19.5:9
20:9
representative tablet
```

Respect safe areas and cutouts.

---

# 63. Performance

Target:

```text
60 FPS on representative mid-range Android
>= 30 FPS stable on supported low-end devices
```

Avoid gameplay spikes from:

- synchronous large loads;
- repeated resource instantiation;
- excessive particles;
- uncontrolled allocations;
- physics overload.

---

# 64. Object Pooling

Use where measured or obviously repetitive:

```text
passengers/items
particles
floating texts
temporary markers
repeated effects
```

Do not build a universal pooling framework before needed.

---

# 65. Loading

First playable target:

```text
launch -> usable menu quickly
level load target < 3 s on representative device
```

Do not require network to start gameplay.

---

# 66. Offline-First

Without internet, player must still be able to:

```text
launch
play downloaded/bundled levels
progress
save
use owned non-network features
change settings
```

Unavailable services degrade gracefully:

```text
ads
analytics
remote config fetch
store purchase
```

---

# 67. Build Environments

Required:

```text
Debug
QA
Production
```

## Debug

```text
debug menu
test ads
verbose logs
developer overlays
cheats
```

## QA

```text
release-like behavior
test/staging configuration
test ads
analytics marked as QA
```

## Production

```text
production IDs
debug menu inaccessible
no verbose developer logs
release signing
```

---

# 68. Debug Menu

Debug/QA only.

Capabilities:

```text
select level
unlock level
reset progression
add coins
clear inventory
grant booster
simulate rewarded success
simulate rewarded failure
toggle ads
simulate purchase
restore test purchase
change difficulty override
show FPS
show entity IDs
show occupancy grid
show paths
show blockers
show state hash
show solver recommendation
reload current level
corrupt test save
restore backup save
```

Production build must not expose debug capabilities.

---

# 69. Logging

Levels:

```text
DEBUG
INFO
WARN
ERROR
```

Production rules:

- no secrets;
- no unnecessary PII;
- no huge per-frame logs;
- no full save dumps by default.

Use structured context where practical.

---

# 70. Testing Strategy

Required categories:

```text
unit
integration
architecture
level validation
solver regression
generator regression
persistence
migration
UI smoke
Android smoke
```

---

# 71. Unit Tests

Mandatory for:

```text
movement
blocking
occupancy
matching
capacity
queue behavior
staging
win rules
lose rules
command validation
undo
state hashing
serialization
difficulty calculations
config parsing
```

---

# 72. Solver Tests

Test corpus includes:

```text
trivially solvable
multi-step solvable
known dead-end
unsolvable
symmetry
duplicate state paths
staging pressure
large search
```

Required property:

```text
same level + same solver config -> same classification and canonical solution behavior
```

---

# 73. Generator Tests

Required:

```text
same seed -> same generated level
generated schema valid
generated references valid
accepted level -> solver says SOLVABLE
difficulty distribution within configured tolerance
```

---

# 74. Persistence Tests

Required:

```text
save/load roundtrip
backup recovery
invalid checksum/invalid data
unknown future version handling
v1->v2 migration
reward idempotency
level completion idempotency
```

---

# 75. Content Gate

Every production level must pass:

```text
schema validation
static validation
solver
difficulty analysis
duplicate checks
content version checks
```

A production build MUST fail CI if any required level fails.

---

# 76. CI Pipeline

For relevant pull requests:

```text
checkout
↓
dependency/setup validation
↓
static checks
↓
unit tests
↓
architecture tests
↓
level validation
↓
solver regression
↓
generator regression (bounded sample)
↓
headless Godot build/test
↓
Android debug/QA export
↓
artifact report
```

Production release adds:

```text
release signing checks
AAB generation
version checks
store-config checks
```

---

# 77. Git Strategy

Branches:

```text
main
develop
agent/core
agent/game
feature/*
fix/*
release/*
```

Rules:

```text
main = production-ready
develop = integrated next version
```

No direct feature development on `main`.

Agents work on assigned branches/worktrees.

---

# 78. Agent Responsibilities

## AGENT 1 — CORE

Owns:

```text
architecture
simulation
game state
commands
rules
level schema
validator
solver
generator
difficulty
persistence
analytics abstractions
remote config abstractions
ads/IAP abstractions
Android integrations
tests
CI
```

## AGENT 2 — GAME / UX

Owns:

```text
Godot scenes
presentation
UI
animations
particles
audio
haptics
theme implementation
tutorial presentation
level visual composition
polish
store-preview gameplay scenes
```

Cross-boundary changes require explicit justification.

---

# 79. Agent Rules

Agents MUST:

1. read this blueprint;
2. inspect current repository state;
3. execute only assigned milestone;
4. preserve public contracts unless change is required;
5. add/update tests;
6. run the full relevant test suite;
7. run build/export checks;
8. report all failures honestly;
9. commit only validated work if instructed.

Agents MUST NOT:

```text
delete failing tests
disable validation to get green
silently rewrite architecture
add future milestone scope
introduce secrets
invent external credentials
claim Android validation without an actual export/test
```

---

# 80. Required Agent Completion Report

Every milestone prompt should require:

```text
AGENT:
MODEL:

STATUS:
PASS | PASS_WITH_FINDINGS | FAIL

BASELINE:
branch
starting commit
worktree state

IMPLEMENTED:
...

FILES_CHANGED:
...

TESTS:
commands
passed
failed

BUILD:
editor/headless
Android
result

ACCEPTANCE_CRITERIA:
criterion -> PASS/FAIL

RISKS:
...

FINDINGS:
...

NEXT:
...

COMMIT:
hash or NOT_CREATED
```

---

# 81. Definition of Done

A feature is not done because "the code exists".

Done means:

```text
implementation complete
tests added/updated
tests pass
relevant content validation passes
documentation updated if contract changed
no known P0/P1 introduced
Android build/export remains valid
acceptance criteria satisfied
```

---

# 82. Bug Severity

```text
P0 = data loss, payment issue, security issue, widespread crash
P1 = gameplay blocker, cannot progress, major broken feature
P2 = incorrect but workaround exists
P3 = cosmetic/minor
```

P0/P1 block release.

---

# 83. Milestone Roadmap

---

## M0 — Foundation

### Scope

- create repository structure;
- pin Godot baseline;
- create base Godot project;
- Android export configuration;
- test framework;
- CI skeleton;
- docs skeleton;
- build environments;
- initial ADRs;
- branch conventions.

### Deliverables

```text
project opens
headless validation works
Debug Android export works
test command works
CI works
```

### Acceptance

- [ ] Godot 4.7.2 project opens without import errors
- [ ] headless test command exits 0
- [ ] Android Debug build/export succeeds
- [ ] targetSdk 36 confirmed
- [ ] minSdk 24 confirmed
- [ ] no secrets committed
- [ ] `docs/MASTER_BLUEPRINT.md` present
- [ ] CI passes

---

## M1 — Puzzle Core

### Scope

- board;
- positions;
- entity model;
- occupancy;
- commands;
- movement validation;
- state serialization;
- deterministic RNG;
- domain events.

### Acceptance

- [ ] entity placement works
- [ ] illegal overlap rejected
- [ ] blocked movement detected
- [ ] deterministic state generated from same seed
- [ ] state roundtrip serialization works
- [ ] core has no traffic-theme dependency
- [ ] unit tests pass

---

## M2 — Traffic Gameplay

### Scope

- Traffic theme;
- vehicle presentation mapping;
- passenger/item queues;
- color matching;
- staging;
- loading/completion;
- win/lose.

### Acceptance

- [ ] vehicle can be selected
- [ ] blocked vehicle cannot move
- [ ] free vehicle moves logically
- [ ] matching processes correctly
- [ ] staging capacity respected
- [ ] win detected
- [ ] loss detected
- [ ] simulation remains deterministic
- [ ] tests pass

---

## M3 — First Playable

### Scope

- main menu;
- play flow;
- 10 manual levels;
- level select for debug;
- restart;
- next level;
- basic save;
- result screen.

### Acceptance

- [ ] 10/10 levels playable on Android
- [ ] all 10 levels completable
- [ ] restart works
- [ ] progress survives app restart
- [ ] no P0/P1
- [ ] acceptable frame pacing
- [ ] Android device smoke test PASS

**Gate:** Do not build large content systems if the core puzzle is not fun enough to continue.

---

## M4 — UX / Juice

### Scope

- production-quality interaction feedback;
- tweens;
- particles;
- audio;
- haptic;
- transitions;
- blocked feedback;
- completion sequence.

### Acceptance

- [ ] valid action feedback clear
- [ ] invalid action feedback clear
- [ ] no input lock bug
- [ ] animations do not alter simulation result
- [ ] audio settings persist
- [ ] haptics can be disabled
- [ ] performance target maintained

---

## M5 — Level Framework

### Scope

- formal schema;
- level loader;
- validator;
- schema version;
- content pack structure;
- migration infrastructure.

### Acceptance

- [ ] no production level requires custom code
- [ ] malformed level rejected with useful error
- [ ] level schema documented
- [ ] schema migration test exists
- [ ] 10 first-playable levels converted to official format

---

## M6 — Solver

### Scope

- state conversion;
- state hashing;
- BFS baseline;
- pruning;
- solution reconstruction;
- CLI/tool entry.

### Acceptance

- [ ] all known solvable test levels SOLVABLE
- [ ] all known impossible test levels UNSOLVABLE
- [ ] official levels SOLVABLE
- [ ] solution replay completes level
- [ ] deterministic result
- [ ] bounded performance report produced

---

## M7 — Difficulty Analyzer

### Scope

- metrics;
- normalized score;
- report generation;
- difficulty buckets.

### Acceptance

- [ ] difficulty score 0..1
- [ ] report includes key solver metrics
- [ ] manually obvious easy/hard fixtures ordered sensibly
- [ ] thresholds configurable
- [ ] no gameplay dependency on analyzer

---

## M8 — Generator

### Scope

- seeded generation;
- generation constraints;
- validation;
- solver integration;
- difficulty targeting;
- batch tool;
- basic dedupe.

### Acceptance

- [ ] same seed reproduces same candidate
- [ ] 1,000 candidate batch supported
- [ ] invalid candidates rejected automatically
- [ ] accepted candidates SOLVABLE
- [ ] difficulty buckets produced
- [ ] batch report generated

---

## M9 — Production Content

### Scope

- produce/select 200+ levels;
- curate difficulty curve;
- introduce mechanics gradually;
- level pack metadata.

### Acceptance

- [ ] >= 200 production levels
- [ ] 100% schema valid
- [ ] 100% solver SOLVABLE
- [ ] no known accidental duplicates above configured threshold
- [ ] tutorial curve reviewed
- [ ] relief levels included
- [ ] pack manifests valid

---

## M10 — Progression / Save

### Scope

- level unlock;
- coins;
- player progression;
- robust save;
- backup;
- migration;
- crash recovery checkpoint.

### Acceptance

- [ ] progression persists
- [ ] coin grants idempotent
- [ ] corrupted primary save recovers from backup
- [ ] migration tests pass
- [ ] replaying completion cannot duplicate reward
- [ ] no internet required

---

## M11 — Boosters

### Scope

- Undo;
- Extra Slot;
- Shuffle;
- inventory;
- economy costs;
- UI.

### Acceptance

- [ ] three boosters functional
- [ ] boosters cannot corrupt level state
- [ ] Undo exact
- [ ] booster use persists correctly
- [ ] every standard level remains solvable without boosters
- [ ] analytics hooks present

---

## M12 — Analytics / Crash Reporting

### Scope

- Firebase Analytics;
- Crashlytics;
- event abstraction;
- environments;
- event catalog.

### Acceptance

- [ ] analytics unavailable does not block gameplay
- [ ] Debug/QA identifiable
- [ ] level funnel visible
- [ ] failure reasons visible
- [ ] crash test appears in Crashlytics
- [ ] no PII in event payload audit

---

## M13 — Remote Config

### Scope

- local defaults;
- Firebase Remote Config;
- config schema;
- feature flags;
- validation.

### Acceptance

- [ ] app works without successful fetch
- [ ] invalid remote values rejected/fallback
- [ ] ad frequency configurable
- [ ] reward values configurable
- [ ] feature flags configurable
- [ ] config version logged

---

## M14 — Monetization

### Scope

- Google Mobile Ads;
- rewarded;
- interstitial;
- frequency controls;
- IAP foundation;
- remove ads;
- purchase idempotency.

### Acceptance

- [ ] only test ad units in Debug/QA
- [ ] rewarded callback grants exactly once
- [ ] ad failure never blocks player
- [ ] remove-ads respected
- [ ] interstitial cap respected
- [ ] purchases restorable where platform supports
- [ ] purchase grants idempotent
- [ ] offline gameplay unaffected

---

## M15 — Privacy / Compliance

### Scope

- consent flow;
- privacy menu;
- store data inventory;
- age strategy;
- policy audit.

### Acceptance

- [ ] consent integration functional where required
- [ ] privacy settings reachable
- [ ] data collected documented
- [ ] store Data Safety answers prepared
- [ ] production SDK versions reviewed
- [ ] Google Play target API requirement satisfied

---

## M16 — Production Android

### Scope

- package/application ID finalization;
- signing;
- AAB;
- production Firebase;
- production ads;
- store service config;
- build reproducibility.

### Acceptance

- [ ] signed AAB generated
- [ ] target API 36
- [ ] release starts on physical device
- [ ] production debug tools inaccessible
- [ ] release logging appropriate
- [ ] release version metadata correct
- [ ] signing backup procedure documented

---

## M17 — Internal QA

### Scope

- device matrix;
- Play internal testing;
- regression;
- save upgrade tests;
- ad/IAP tests;
- performance.

### Acceptance

- [ ] no open P0
- [ ] no open P1
- [ ] crash-free target trend acceptable
- [ ] installation/update path tested
- [ ] low/mid-range Android smoke tested
- [ ] restore/reinstall scenarios documented

---

## M18 — Closed Beta

### Scope

- real external testers;
- analytics validation;
- difficulty telemetry;
- UX feedback;
- retention baseline.

### Acceptance

- [ ] analytics data trustworthy
- [ ] top blocking UX problems identified
- [ ] high-fail levels reviewed
- [ ] save/data-loss incidents = 0 unresolved
- [ ] prioritized beta findings produced

---

## M19 — Soft Launch Brazil

### Scope

- Brazilian Google Play listing;
- ASO baseline;
- controlled acquisition;
- monetization measurement;
- retention measurement.

### Acceptance

- [ ] store listing live
- [ ] D1/D7 measured with valid cohort
- [ ] level funnel monitored
- [ ] ad metrics monitored
- [ ] crash metrics monitored
- [ ] no uncontrolled ad frequency
- [ ] initial CPI/organic signal captured where applicable

---

## M20 — Optimization

### Scope

Iterate:

```text
tutorial
difficulty
ad frequency
reward value
booster economy
store creatives
level order
```

### Rule

One clear hypothesis per experiment whenever possible.

### Acceptance

- [ ] experiments documented
- [ ] primary metric defined before launch
- [ ] guardrail metrics defined
- [ ] losing experiment removable remotely when possible
- [ ] decisions based on data

---

## M21 — Production Scale

### Scope

- broader rollout;
- content cadence;
- live monitoring;
- operational runbooks;
- creative testing.

### Acceptance

- [ ] release process repeatable
- [ ] monitoring documented
- [ ] P0 response procedure documented
- [ ] content pack release process validated
- [ ] monetization safe under scale

---

## M22 — Factory Extraction

### Scope

Refactor proven reusable components only after product evidence.

Extract:

```text
core simulation
level platform
solver
generator
save foundation
analytics abstraction
monetization abstraction
remote-config abstraction
theme contracts
tooling
```

### Acceptance

- [ ] Project Traffic still passes all tests
- [ ] reusable modules contain no Traffic-specific assets/terminology
- [ ] dependency graph documented
- [ ] second-theme bootstrap possible

---

## M23 — Theme / Game Bootstrap Tooling

### Scope

- new-game scaffold;
- theme manifest;
- asset validation;
- config generation;
- level tool integration.

Target workflow concept:

```text
factory create-game airport
```

### Acceptance

- [ ] scaffold produces valid project configuration
- [ ] missing required theme assets reported
- [ ] new theme can map generic entities without core edits
- [ ] docs generated/template available

---

## M24 — Game #2

### Scope

Build a second game using the factory.

Requirements:

- new theme;
- original branding;
- at least 1-2 mechanic differences;
- different content;
- reused core.

### Factory Success Criterion

A meaningful majority of infrastructure is reused without copying the first game's visual identity or level set.

---

# 84. Release Scope — Version 1.0

Expected 1.0 feature set:

```text
Traffic theme
200+ validated levels

deterministic puzzle core
staging mechanic
matching
blocking
capacity

tutorial
progression
coins

Undo
Extra Slot
Shuffle

daily reward

save + backup + migration
settings

pt-BR
en-US
es

audio
haptics

analytics
crash reporting
remote config

rewarded ads
interstitial ads
remove ads
basic IAP

privacy/consent flow
Android production AAB
```

Not required for 1.0:

```text
cloud save
daily challenge
seasonal event engine
city restoration meta
iOS
custom backend
leaderboards
multiplayer
battle pass
subscription
```

---

# 85. Post-1.0 Candidate Backlog

Possible sequence:

```text
1. additional level packs
2. daily challenge
3. cosmetics
4. lightweight meta progression
5. seasonal events
6. additional mechanics
7. cloud save
8. additional languages
9. iOS
10. second game
```

Data determines priority.

---

# 86. Live Ops

Post-validation content cadence target:

```text
weekly:
challenge / tuning / experiment

monthly:
new level pack or meaningful content

seasonal:
optional themed event
```

Do not commit to live-ops cadence before operation capacity exists.

---

# 87. Creative Factory

Future tooling can generate ad candidates from actual gameplay.

Pipeline:

```text
select level
↓
run scripted replay
↓
capture video
↓
render hook overlay
↓
export variants
```

Possible hooks:

```text
Which one moves first?
Can you solve this?
Don't make this move.
Only 1 path works.
```

Creative content must reflect actual gameplay capabilities.

---

# 88. ASO

Store experiment candidates:

```text
icon
feature graphic
screenshots
short description
promo video
```

Do not hardcode store-facing name in reusable core packages.

---

# 89. Business Decision Model

The company strategy is portfolio-oriented.

Goal is not:

```text
one giant game at any cost
```

Goal:

```text
cheap experiments
reusable technology
fast measurement
kill weak products
scale strong products
```

A future portfolio might contain:

```text
several weak/neutral products
several profitable products
occasional breakout product
```

No numerical success guarantee is assumed.

---

# 90. Kill / Pivot Criteria

A product may be stopped or reskinned if, after sufficient controlled iteration:

- retention remains structurally weak;
- acquisition cost is not economically viable;
- ads required to monetize destroy retention;
- content production cost is too high;
- the core loop has no strong user response.

Do not hide bad product signals by adding more systems.

---

# 91. Backend Trigger

A custom backend is prohibited by default.

Backend becomes eligible only when a validated feature truly requires it, such as:

```text
cross-device authoritative economy
server-side competitive events
account-based progression
server-authoritative leaderboard
fraud-sensitive economy
```

If introduced, write an ADR with:

- requirement;
- alternatives;
- cost;
- security;
- operational burden;
- migration plan.

---

# 92. Security

Never commit:

```text
private signing keys
service-account secrets
production private credentials
API secrets
store private keys
```

Production signing material must have secure backup.

Use least privilege for CI credentials.

---

# 93. Release Checklist

Before any production release:

- [ ] intended commit tagged
- [ ] version updated
- [ ] Android `versionCode` incremented
- [ ] all unit tests PASS
- [ ] integration tests PASS
- [ ] level validation PASS
- [ ] solver regression PASS
- [ ] all production levels SOLVABLE
- [ ] migration tests PASS
- [ ] no open P0/P1
- [ ] release AAB builds
- [ ] targetSdk = 36+
- [ ] production signing verified
- [ ] production Firebase config verified
- [ ] production ad IDs verified
- [ ] test ad IDs absent from Production
- [ ] privacy/consent checked
- [ ] Data Safety reviewed
- [ ] release notes written
- [ ] physical-device smoke test PASS
- [ ] Play pre-launch checks reviewed
- [ ] rollback/mitigation plan known

---

# 94. Architecture Decision Records

Initial ADRs recommended:

```text
ADR-001 — Godot 4.7.2 and GDScript
ADR-002 — Deterministic logical simulation
ADR-003 — Presentation separated from simulation
ADR-004 — Data-driven levels
ADR-005 — Solver required for production content
ADR-006 — Offline-first / no custom backend
ADR-007 — Theme-independent core
ADR-008 — Rewarded-first monetization
ADR-009 — Versioned save and level schemas
ADR-010 — Firebase for analytics/crash/remote config
```

---

# 95. Required Supporting Documentation

By the relevant milestones, repository should contain:

```text
README.md
docs/MASTER_BLUEPRINT.md
docs/ARCHITECTURE.md
docs/GAME_RULES.md
docs/LEVEL_SCHEMA.md
docs/SOLVER.md
docs/GENERATOR.md
docs/ANALYTICS.md
docs/MONETIZATION.md
docs/ANDROID.md
docs/RELEASE.md
docs/AGENT_RULES.md
docs/adr/*
```

Do not write empty documents merely to satisfy a checklist.

---

# 96. Implementation Order — Non-Negotiable

```text
M0
Foundation
↓
M1-M3
FUN
↓
M4
POLISH
↓
M5-M8
CONTENT MACHINE
↓
M9
CONTENT
↓
M10-M11
RETENTION FOUNDATION
↓
M12-M14
DATA + MONETIZATION
↓
M15-M19
RELEASE / SOFT LAUNCH
↓
M20
OPTIMIZE
↓
M21
SCALE
↓
M22-M24
FACTORY
```

Do not build a sophisticated factory before the first game's core loop has passed the First Playable gate.

---

# 97. Standard OpenCode Milestone Prompt Contract

Every implementation prompt should begin with the equivalent of:

```text
Read docs/MASTER_BLUEPRINT.md completely.

Inspect the repository before modifying anything.

Execute ONLY milestone Mx and the minimum prerequisites required by it.

Do not implement future milestones.
Do not silently change architecture.
Do not weaken tests or acceptance criteria.
Do not commit secrets.
Do not claim PASS without running the required validation.

At completion report:

AGENT
MODEL
STATUS
BASELINE
IMPLEMENTED
FILES_CHANGED
TESTS
BUILD
ACCEPTANCE_CRITERIA
RISKS
FINDINGS
NEXT
COMMIT
```

If the repository already contains later functionality, the agent must preserve it unless it conflicts with the blueprint.

---

# 98. Product Review Gates

## Gate A — First Playable

Question:

> Is the basic puzzle enjoyable enough to continue?

Evidence:

- 10 working levels;
- responsive input;
- clear goal;
- understandable failure;
- no major friction.

If NO: iterate gameplay before building the factory.

## Gate B — Content Machine

Question:

> Can we produce fair content economically?

Evidence:

- validator;
- solver;
- generator;
- difficulty classification.

If NO: fix tooling before creating hundreds of levels.

## Gate C — Beta

Question:

> Do real users understand and return?

Evidence:

- tutorial completion;
- level funnel;
- early retention;
- qualitative feedback.

## Gate D — Monetization

Question:

> Can monetization coexist with retention?

Evidence:

- rewarded opt-in;
- ad ARPDAU;
- retention changes;
- session changes.

## Gate E — Scale

Question:

> Does acquisition have a plausible path to sustainable economics?

Only then increase spend.

## Gate F — Factory

Question:

> Is the reusable model validated by the first product?

Only then spend meaningful effort generalizing for game #2.

---

# 99. Configuration Ownership

Maintain a configuration catalog containing:

```text
key
type
default
minimum
maximum
environment
remote/local
description
owner
introduced_version
```

No "magic numbers" for major economic/monetization parameters.

Examples:

```text
staging_default_slots
starting_coins
undo_coin_cost
extra_slot_coin_cost
shuffle_coin_cost
rewarded_coin_amount
first_interstitial_level
min_levels_between_interstitials
min_seconds_between_interstitials
max_interstitials_per_session
```

Gameplay constants that define fundamental rules may remain code/config constants but must be named and tested.

---

# 100. Data Compatibility Contract

Released users must not lose progress because internal schemas evolve.

Three separately versioned contracts:

```text
SaveSchema
LevelSchema
RemoteConfigSchema
```

Each must define:

- current version;
- compatibility behavior;
- migration strategy;
- fallback strategy.

---

# 101. Factory Success Definition

The Puzzle Factory is considered technically validated only when all are true:

1. Project Traffic has shipped;
2. the core has real production evidence;
3. a second theme can be created without changing fundamental core code;
4. level generation/validation is reused;
5. analytics/monetization/persistence abstractions are reused;
6. new-game setup is materially faster than the first game;
7. second game remains visually/product-wise original.

---

# 102. Explicit Non-Goals

Unless this blueprint is intentionally revised, do not add:

```text
multiplayer
PvP
guilds
chat
user-generated content
NFTs
crypto
real-money gambling
subscription
battle pass
mandatory account
custom backend
microservices
PostgreSQL
Redis
real-time WebSockets
```

These are not "future-proofing"; they are unnecessary scope.

---

# 103. Baseline External References

These references were used to pin the initial technical baseline on 2026-09-26.

- Godot official archive — Godot 4.7.2 stable, released 2026-08-18:  
  https://godotengine.org/download/archive/

- Google Play target API requirements — new apps and updates require Android 16 / API 36 from 2026-08-31:  
  https://support.google.com/googleplay/android-developer/answer/11926878

- Firebase Android release notes — BoM 34.19.0 released 2026-09-09:  
  https://firebase.google.com/support/release-notes/android

- Google Mobile Ads Android release notes — 25.5.0 released 2026-09-17; minimum Android API 24:  
  https://developers.google.com/admob/android/rel-notes

- Android Studio Quail 4 / 2026.1.4 Patch 1 and AGP 9.4.1:  
  https://developer.android.com/studio/releases/fixed-bugs/studio/2026.1.4.html

- Android Gradle Plugin 9.4 compatibility:  
  https://developer.android.com/build/releases/agp-9-4-0-release-notes

---

# 104. Final Source-of-Truth Rule

Implementation agents should prefer:

```text
working, tested, boring code
```

over:

```text
clever abstraction
premature generalization
future speculation
```

The first objective is a **fun, stable, measurable commercial Android puzzle game**.

The second objective is to extract from proven code a **repeatable puzzle-game factory**.

The order matters.

---

# 105. Immediate Next Step

Start **M0 — Foundation** only.

Do not start M1 in the same task unless M0 is fully complete and a separate prompt explicitly authorizes M1.

Required M0 completion report must include:

```text
Godot version
Android SDK configuration
branch
commit
repository tree
test command
test result
Android export command/process
Android export result
CI result
known risks
```

**END OF MASTER BLUEPRINT**
