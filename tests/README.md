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
├── fixtures/               # test-only fixtures (deterministic sample generator)
├── bootstrap_test.gd       # project bootstrap validation
├── determinism_test.gd     # seeded reproducibility + golden vector
└── framework_self_test.gd  # test framework self-test
```

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
