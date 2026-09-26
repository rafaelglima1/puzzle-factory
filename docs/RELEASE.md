# Release

> Scope: **process contracts only at M0** — no release has been cut.
> Authority: `docs/MASTER_BLUEPRINT.md` §6, §67, §93.

## Versioning

Semantic versioning `MAJOR.MINOR.PATCH`. Roadmap mapping (§6):

```text
0.1.0 Foundation   ← current milestone (M0)
0.2.0 Puzzle Core
0.3.0 First Playable
... through 1.0.0 Production Launch
```

Android `versionCode`:

- monotonically increasing, never reused;
- start at **100**, then 101, 102, ... (M0 export uses 100);
- `versionName` mirrors the semver (`0.1.0` at M0).

Godot project version lives in `game/project.godot`
(`application/config/version`) and the export preset
(`version/code`, `version/name`) — keep them in sync.

## Environments (§67)

Defined in `content/configs/environments/*.json`:

- **Debug** — debug menu, test ads, verbose logs, developer overlays.
- **QA** — release-like behavior, test/staging configuration, analytics
  marked as QA.
- **Production** — production IDs, debug menu inaccessible, no verbose
  developer logs, release signing.

Credentials for QA/Production are injected during M12–M16 and must
**never** be committed (blueprint §92).

## Release checklist

Full checklist: `docs/MASTER_BLUEPRINT.md` §93 (tests, level
validation, solver regression, migrations, no open P0/P1, AAB builds,
targetSdk 36+, production signing/Firebase/ad IDs verified, privacy
review, physical-device smoke test, release notes, rollback plan).

Release procedure (contract):

```text
release/* branch
↓
version + versionCode bump
↓
full test + content gate pass
↓
signed AAB (M16)
↓
pre-launch checks + smoke test
↓
tag + merge to main
```

## Current status

No releases yet. CI workflow exists but has not run remotely (no remote
configured at M0) — see `ci/README.md`.
