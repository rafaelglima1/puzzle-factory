# M4 Presentation Settings Contract

> **Owner:** AGENT-1 (core / persistence / integration)
> **Consumers:** AGENT-2 (presentation), M4 cross-integration (`integration/m4`)
> **Status:** infrastructure only — presentation polish is AGENT-2's; final wiring
> is the M4 integration pass
> **Authority:** `docs/MASTER_BLUEPRINT.md` §M4, §41.1, §60; ADR-003, ADR-013

This document is the handoff contract for the **player preference
infrastructure** required by M4 acceptance:

```text
audio settings persist          (MASTER_BLUEPRINT §M4)
haptics can be disabled         (MASTER_BLUEPRINT §M4)
```

It covers only persistence + the real audio bus layout. It does **not** describe
how anything looks, sounds or vibrates — that is AGENT-2's M4 work.

## 1. Player-facing settings model

Exactly three switches, all default **ON**:

| Setting | Player label | Default | Controls |
|---|---|---|---|
| `music_enabled` | Music | `true` | music playback |
| `sound_enabled` | Sound | `true` | SFX + UI interaction sounds |
| `haptics_enabled` | Haptics | `true` | presentation vibration |

There is no volume slider, no locale, no graphics quality, no account or cloud
setting in M4. Those are deferred (see §7).

The store is product-free infrastructure (`game/persistence/**`), so it never
mentions any theme or product vocabulary.

## 2. Store API

`game/persistence/m4_presentation_settings_store.gd` —
`class_name M4PresentationSettingsStore extends RefCounted`.

```text
# construction
M4PresentationSettingsStore.new(path := DEFAULT_PATH)   # path injectable for tests

# read
load_settings() -> int            # returns a LoadError value
music_enabled() -> bool
sound_enabled() -> bool
haptics_enabled() -> bool
version() -> int
snapshot() -> Dictionary           # canonical, primitive-only
to_dictionary() -> Dictionary      # same payload (serialization view)

# write
set_music_enabled(value) -> Error
set_sound_enabled(value) -> Error
set_haptics_enabled(value) -> Error
apply(music, sound, haptics) -> Error
save() -> Error
reset() -> void
delete_settings_file() -> bool

# diagnostics
last_load_error: int      # LoadError
last_save_error: Error
settings_path: String
```

`LoadError` values (same vocabulary as `M3ProgressStore`):
`NONE, FILE_MISSING, INVALID_JSON, INVALID_FORMAT, UNSUPPORTED_VERSION, IO_ERROR`.

### Persistence model

**Toggles persist immediately.** Each `set_*` (and `apply`) that actually changes
a value writes the document before returning; setting the value it already has is
a no-op that does not touch the file. This is the UI-facing path — a toggle can
never be "lost" because a caller forgot to save. `save()` remains available for
callers that prefer an explicit write, and repeated saves are byte-identical.

Setters return the `Error` of the write (`OK` when nothing changed), so a
presentation toggle handler can react to an I/O failure without reading fields.

## 3. Storage

```text
path:     user://m4_presentation_settings.json     (DEFAULT_PATH)
injectable via constructor (tests use user://... paths)
```

Canonical JSON via `Serialization.to_json` (sorted keys, primitive-only), so the
document is byte-stable:

```json
{
  "version": 1,
  "haptics_enabled": true,
  "music_enabled": true,
  "sound_enabled": true
}
```

It does **not** share `user://m3_progress.json`. Progress and preferences are
separate documents in M4.

## 4. Load policy

| Input | Result | File |
|---|---|---|
| missing file | enabled defaults, `FILE_MISSING` | never created by a read |
| valid file | values restored, `NONE` | untouched |
| invalid JSON | enabled defaults, `INVALID_JSON` | never rewritten |
| non-object root / missing `version` | enabled defaults, `INVALID_FORMAT` | never rewritten |
| wrong field type (string/number/missing toggle) | enabled defaults, `INVALID_FORMAT` | never rewritten |
| `version > 1` | enabled defaults, `UNSUPPORTED_VERSION` | untouched |
| empty path | enabled defaults, `IO_ERROR` | — |

Booleans are strict: `1`/`"yes"` are rejected, never coerced. A load never
writes, renames or deletes; a later `save()` is what repairs a bad file.

**Explicitly out of scope (M10):** backup file, atomic temp+rename, checksum,
migration framework, recovery chain. See §7.

## 5. Audio bus layout

The real Godot bus layout ships at `game/default_bus_layout.tres`
(`res://default_bus_layout.tres`), referenced explicitly from
`game/project.godot` (`[audio] buses/default_bus_layout`).

```text
Master
├── Music
├── SFX
└── UI
```

All children route to `Master`; all buses start at 0 dB, unmuted, no effects.
The names are the ones already declared by AGENT-2's `game/audio/audio_contract.gd`
(`bus_for(sfx)`, `expected_buses()`), which is now backed by real runtime buses.
`game/tests/audio_bus_test.gd` asserts existence and routing through
`AudioServer` (not by grepping).

## 6. AGENT-2 surface (intents + apply)

The presentation settings screen exposes player intents equivalent to:

```text
music_enabled_changed(value)        music_enabled_changed(false)  -> set_music_enabled(false)
sound_enabled_changed(value)        sound_enabled_changed(false)  -> set_sound_enabled(false)
haptics_enabled_changed(value)      haptics_enabled_changed(false)-> set_haptics_enabled(false)
```

and consumes a settings snapshot through a method equivalent to:

```text
apply_presentation_settings(music_enabled, sound_enabled, haptics_enabled)
```

Do not depend on exact names: the M4 integration pass adapts whatever
AGENT-2 ships to the store in §2. AGENT-2 may keep its own internal
representation; the store is the durable side.

The presentation layer must **not** import `game/persistence/**`
(`presentation_boundary_test.gd`). Wiring goes through the integration layer,
which reads the store and calls presentation with plain values.

### Wired integration (M4)

`TrafficM3AppController` (`game/integration/traffic/`) is the app composition
root and now **owns the settings store** (`M4PresentationSettingsStore`). The
tree is:

```text
M4PresentationSettingsStore (persistence, product-free)
        │  startup: load_settings()  →  music_enabled()/sound_enabled()/haptics_enabled()
        ▼
TrafficM3AppController (integration, ADR-013)
        │  startup: shell.apply_presentation_settings(music, sound, haptics) BEFORE show_main_menu()
        │  toggles:  music_enabled_changed/sound_enabled_changed/haptics_enabled_changed
        │            → store.set_*_enabled(value)  (persist only; the shell already applied runtime)
        ▼
M3FirstPlayable shell → TrafficPresenter → PresentationAudio / HapticService
```

Startup order (no flash of the enabled defaults, so a persisted OFF choice can
never emit a sound or a vibration):

```text
controller.start()
  → store = M4PresentationSettingsStore.new(presentation_settings_path)
  → store.load_settings()
  → shell built
  → shell.apply_presentation_settings(store.music_enabled(), store.sound_enabled(), store.haptics_enabled())
  → shell.show_main_menu()
```

`presentation_settings_path` is injectable (defaults to
`M4PresentationSettingsStore.DEFAULT_PATH`) exactly like `progress_path`, so the
integration tests use temporary files.

The controller does **not** connect `settings_requested`: the shell navigates the
settings screen itself, so wiring it would double-fire one intent.

**I/O failure semantics.** The store mutates memory first and then writes, so a
non-OK setter result means the runtime keeps the player's choice while disk may
still hold the old value. The controller keeps the choice active, records the
error (`last_settings_save_error()`), warns, and continues — never a crash,
never a silent success claim, no retry queue (M10 owns robust persistence).
Load diagnostics are available through `last_settings_load_error()` and are
never surfaced to the player in M4.

## 7. Explicit deferrals

- **Volumes / locale.** `docs/UX_IMPLEMENTATION_PLAN.md` §8 defines a richer
  future set (`settings.music_volume`, `settings.sfx_volume`, `settings.locale`,
  names `music_enabled`/`sfx_enabled`/`haptics_enabled`). M4 intentionally ships
  only the three on/off switches required by M4 acceptance. When volumes/locale
  land, they extend this schema under a new `version` with a real migration.
- **M10 consolidation.** The robust save system (blueprint §41) stores a
  `settings` block inside the versioned save with backup/migration/recovery.
  This file is expected to be folded into that block at M10; the store is
  deliberately small so the fold is trivial.
- **Volumes / locale / graphics.** Not shipped in M4 (see the first bullet).
- **Actual haptic disable.** The persistence + runtime gate are wired and proven
  headlessly here; that physical hardware feedback obeys the setting is
  validated by the M4 integration device smoke test.

## 8. Tests

```text
game/tests/m4_presentation_settings_store_test.gd   defaults, immediate + explicit
                                                    persistence, malformed/wrong-type/
                                                    future-version safety, byte-unchanged
                                                    fixtures, deterministic serialization
game/tests/audio_bus_test.gd                        Master/Music/SFX/UI exist at runtime,
                                                    children route to Master, 0 dB, unmuted
game/tests/m4_cross_integration_test.gd             real controller/session/shell/presenter:
                                                    defaults, toggle+persist via the Settings
                                                    UI, app-restart restore, malformed settings,
                                                    I/O failure, accepted-move valid-move SFX
                                                    once, blocked move with Sound/Haptics off,
                                                    deferred completion/failure, 350 ms result
                                                    guard, bus routing, recreate/no-growth
```

Run: `powershell -File scripts/run_tests.ps1`.
