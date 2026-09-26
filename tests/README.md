# Tests

## How to run

```powershell
pwsh -File scripts/run_tests.ps1
```

This runs the Godot headless test runner:

```text
godot --headless --path game --script res://tests/run_tests.gd
```

Exit code `0` = all tests passed; non-zero = failures. Suitable for CI.

## Layout

Godot-runnable test code MUST live inside the Godot project (`game/`),
because GDScript can only load `res://` paths:

```text
game/tests/
├── run_tests.gd            # headless runner (discovers *_test.gd)
├── framework/test_base.gd  # minimal assertion base class
├── fixtures/               # test-only fixtures (shared core fixture)
├── bootstrap_test.gd       # project bootstrap validation
├── determinism_test.gd     # seeded reproducibility + golden vector
├── framework_self_test.gd  # test framework self-test
├── board_test.gd           # M1 board/positions/footprints/bounds
├── occupancy_test.gd       # M1 occupancy/blockers/atomic movement
├── entity_test.gd          # M1 entity model + states
├── rng_test.gd             # M1 deterministic RNG
├── game_state_test.gd      # M1/M2 state, serialization, validation, migration
├── command_test.gd         # M1 command system + atomicity
├── events_test.gd          # M1 domain events + ordering + contract fit
├── presentation_bridge_test.gd  # M1 event queue + contract surface
├── architecture_test.gd    # architecture guards (generic layers)
├── item_test.gd            # M2 generic item
├── queue_test.gd           # M2 FIFO queue
├── destination_test.gd     # M2 destination capacity/acceptance
├── staging_test.gd         # M2 staging area (arbitrary capacity)
├── matching_test.gd        # M2 matching contract + color-key rule
├── path_test.gd            # M2 logical path validation/blockers
├── objective_test.gd       # M2 objectives (CLEAR_ALL)
├── traffic_gameplay_test.gd    # M2 Traffic rules end to end
└── traffic_integration_test.gd # M2 event map + presentation adapter
```

Presentation suites are owned by AGENT-2
(`presentation_boundary_test.gd`, `traffic_layout_test.gd`,
`traffic_presentation_test.gd`).

The repository-root categories from the blueprint hold runner entry points
and future non-Godot suites:

```text
tests/
├── README.md               # this file
├── run_tests.ps1           # entry point (delegates to scripts/run_tests.ps1)
├── unit/                   # future tool/unit suites
├── integration/
├── levels/                 # level validation suites (M5+)
├── solver/                 # solver regression suites (M6+)
├── generator/              # generator regression suites (M8+)
├── persistence/            # save/migration suites (M10+)
└── smoke/                  # UI/Android smoke (M3+/M17+)
```

## Conventions

- Test files are named `<name>_test.gd` and extend
  `res://tests/framework/test_base.gd`.
- Implement `run()`; use `check()` / `check_eq()`. Never use GDScript
  `assert()` (it aborts the whole runner instead of recording a failure).
- No gameplay tests before gameplay exists (M1+).
