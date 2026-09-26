# ADR-001: Godot 4.7.2 and GDScript

Status: Accepted (2026-09-26)

## Context

Puzzle Factory is a 2D portrait-oriented casual mobile puzzle game for
Google Play. The blueprint pins the technology baseline (§5): Godot
**4.7.2-stable**, GDScript, Android compileSdk/targetSdk 36, minSdk 24,
JDK 17. Alternatives (Unity, custom engines, Kotlin-native) were not
evaluated at M0 because the baseline is a source-of-truth decision in
`docs/MASTER_BLUEPRINT.md`.

## Decision

- Use Godot 4.7.2-stable as the engine and editor.
- Use GDScript as the single gameplay/tooling language (headless test
  runner included).
- Keep the pinned version: upgrades follow the dependency update rule
  (blueprint §5.3), never floating versions.

## Consequences

- Free, open-source, lightweight Android export pipeline with official
  export templates.
- Headless mode supports import validation and automated tests in CI.
- Team must follow Godot/GDScript conventions; no second runtime
  language is introduced for gameplay code.
- Engine upgrades require revalidating Android export and the full test
  suite.
