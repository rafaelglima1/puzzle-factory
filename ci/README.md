# CI

## Status (M0)

- Workflow created: `.github/workflows/ci.yml`
- Locally validated: the same commands the workflow runs (headless import +
  test runner) were executed successfully on Windows with Godot 4.7.2-stable.
- Remote execution: **NOT EXECUTED** — the repository has no configured Git
  remote in this environment, so GitHub Actions has not run this workflow.
  Do not claim CI passes remotely until a real run is observed.

## Pipeline stages (M0)

1. Checkout
2. Install/cache Godot 4.7.2-stable (official GitHub release asset)
3. Verify Godot version
4. Headless project import (`scripts/import_project.ps1`)
5. Automated tests (`scripts/run_tests.ps1`)

## Deferred stages (later milestones, per blueprint §76)

- Static checks / architecture tests (M1+)
- Level validation, solver regression, generator regression (M5-M8)
- Android debug/QA export in CI (needs SDK + JDK 17 + Gradle cache on runner)
- Release signing checks, AAB generation (M16)

## Local equivalent

```powershell
pwsh -File scripts/import_project.ps1
pwsh -File scripts/run_tests.ps1
pwsh -File scripts/export_android_debug.ps1   # Android, Windows machine with Android SDK
```
