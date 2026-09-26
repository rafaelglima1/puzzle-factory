# Changelog

All notable changes to this repository are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
