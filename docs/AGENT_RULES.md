# Agent Rules

> Authority: `docs/MASTER_BLUEPRINT.md` §77–§80, §97. This file is the
> operational summary agents must follow.

## Before changing anything

1. Read `docs/MASTER_BLUEPRINT.md` completely (it is the source of
   truth; when prompts/notes/code disagree, it wins unless a newer ADR
   overrides a specific section).
2. Inspect the repository: `git status`, branches, recent commits, the
   files you are about to touch.
3. Confirm the technical baseline (§5) against the actual environment.
4. Execute **only** the assigned milestone and its minimum
   prerequisites. Do not start the next milestone.

## Must

- Preserve public contracts unless a change is required.
- Add/update tests for the change; run the full relevant suite
  (`scripts/run_tests.ps1`).
- Run build/export checks relevant to the change
  (`scripts/import_project.ps1`, `scripts/export_android_debug.ps1`).
- Report all failures honestly — distinguish **locally validated**,
  **workflow created**, and **remotely executed**.
- Commit only validated work, and only when instructed.
- Document justified deviations as ADRs (§0, §5.3).

## Must not

```text
delete failing tests
disable validation to get green
silently rewrite architecture
add future milestone scope
introduce secrets / invent external credentials
claim Android validation without an actual export
force-push, rewrite history, or delete unrelated work
weaken acceptance criteria or skip milestones
```

## Branches (§77)

`main` = production-ready · `develop` = integrated next version ·
`agent/core`, `agent/game`, `feature/*`, `fix/*`, `release/*`.
Agents work on their assigned branch; no direct development on `main`.

## Ownership map (recorded decision, 2026-09-26)

| Path | Owner |
|---|---|
| `game/core/**`, `game/puzzle/**`, `game/levels/**`, `game/solver/**`, `game/generator/**`, `game/persistence/**` | AGENT-1 |
| `game/themes/base/**` (generic contracts) | AGENT-1 |
| `game/themes/traffic/**` (concrete theme) | AGENT-2 |
| `game/ui/**`, `game/audio/**`, `game/haptics/**`, presentation/animations/particles | AGENT-2 |
| `tests/**` core suites | AGENT-1 |

Cross-boundary changes require coordination (event contracts, state/save
schema keys, shared abstractions). Disagreements are resolved with an ADR,
never by silent divergence. `game/tests/architecture_test.gd` automatically
enforces that generic layers stay free of theme vocabulary, presentation
asset references and scene-tree usage.

## Design reference (recorded decision, 2026-09-26)

`1080 × 1920` is an approved **design reference only** — not a fixed logical
rendering requirement. Responsive behaviour across the §62 device matrix
remains AGENT-2's responsibility (see `docs/ARCHITECTURE.md` §6).

## Completion report (§80 / §97)

```text
AGENT / MODEL / STATUS (PASS | PASS_WITH_FINDINGS | FAIL)
BASELINE (branch, starting/ending commit, worktree, toolchain)
IMPLEMENTED / REPOSITORY_STRUCTURE / FILES_CHANGED
TESTS (command, result, passed, failed)
BUILD (editor/headless, Android, result)
ACCEPTANCE_CRITERIA (criterion -> PASS/FAIL)
SECURITY / RISKS / FINDINGS / DEFERRED_CORRECTLY
NEXT / COMMIT
```

## Severity (§82)

P0 data loss/payment/security/widespread crash · P1 gameplay blocker ·
P2 incorrect with workaround · P3 cosmetic. P0/P1 block release.
