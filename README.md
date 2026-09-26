# Puzzle Factory

Reusable casual puzzle platform (monorepo). First product: **Project
Traffic** — a deterministic congestion/ordering/capacity puzzle game for
Android (Google Play, portrait, offline-first).

**Source of truth:** [`docs/MASTER_BLUEPRINT.md`](docs/MASTER_BLUEPRINT.md).
Where anything else disagrees, the blueprint wins (unless a newer ADR
explicitly overrides a section).

## Status

**Milestone M0 — Foundation** (see blueprint §83):

- Godot 4.7.2-stable project under `game/` (portrait, mobile renderer)
- Headless validation + automated test runner
- Android Debug export (Gradle, minSdk 24 / targetSdk 36 verified)
- CI foundation, documentation skeletons, initial ADRs
- **No gameplay yet** — M1 (Puzzle Core) is next

## Repository layout

```text
game/       Godot project: core, puzzle, levels, solver, generator,
            themes, meta, persistence, monetization, analytics, ...
content/    Data: themes, levels, localization, configs (environments)
tools/      Content tooling (generator/solver/validator, M5+)
tests/      Test entry point + future non-Godot suites (see tests/README.md)
docs/       MASTER_BLUEPRINT + architecture docs + adr/
ci/         CI documentation
scripts/    Local build/test/export scripts
.github/    GitHub Actions workflows
```

## Prerequisites

| Tool | Version |
|---|---|
| Godot | 4.7.2-stable (headless-capable) |
| JDK | 17 (Android builds) |
| Android SDK | platforms;android-36, build-tools 36.0.0 |
| PowerShell | 5.1+ or pwsh (scripts) |

Godot discovery order: `GODOT_PATH` env var → `godot` on PATH → known
install locations. See `scripts/resolve_godot.ps1`.

## Commands

```powershell
# Windows PowerShell 5.1 (this repo's scripts are 5.1-compatible)
powershell -File scripts/import_project.ps1   # headless import / validation
powershell -File scripts/run_tests.ps1        # automated tests (exit 0 = pass)
powershell -File scripts/export_android_debug.ps1

# PowerShell 7+ / CI
pwsh -File scripts/run_tests.ps1
```

## Branching

`main` (production-ready) · `develop` (integrated next version) ·
`agent/core`, `agent/game`, `feature/*`, `fix/*`, `release/*`.
No direct feature development on `main` (blueprint §77).

## Documentation

| Document | Purpose |
|---|---|
| `docs/MASTER_BLUEPRINT.md` | Authoritative specification |
| `docs/ARCHITECTURE.md` | Layers, boundaries, environments |
| `docs/GAME_RULES.md` | v1 rules (scope/status) |
| `docs/ANDROID.md` | Android toolchain, export, verification |
| `docs/AGENT_RULES.md` | Agent working agreement |
| `docs/RELEASE.md` | Versioning & release process |
| `docs/adr/` | Architecture Decision Records |
