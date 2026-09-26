# Android

> Scope: **M0 Foundation** — Debug export configuration and verification.
> Production signing, AAB release, AdMob/Firebase and store submission
> belong to M12–M16. Authority: `docs/MASTER_BLUEPRINT.md` §5.

## 1. Pinned baseline (as verified 2026-09-26)

| Component | Value | Verified |
|---|---|---|
| Godot | 4.7.2-stable | yes (`--version`) |
| compileSdk | 36 | APK: `compileSdkVersion='36'` |
| targetSdk | 36 | APK: `targetSdkVersion:'36'` |
| minSdk | 24 | APK: `minSdkVersion:'24'` |
| Build Tools | 36.0.0 (aapt2/apksigner) | yes |
| JDK | 17 | yes (JDK 17 used for Gradle build) |
| Android Gradle Plugin | **8.6.1** (Godot template) | see ADR-011 |
| Gradle | **8.11.1** (Godot wrapper) | see ADR-011 |
| Orientation | portrait (`screenOrientation=1`) | yes |
| Release format | AAB supported by Gradle build (used from M16) | config only |

The blueprint pins AGP 9.4.1 / Gradle 9.6.0 *when compatible*; Godot's
bundled template is used instead per blueprint §5.3 → **ADR-011**.

## 2. Export configuration

Preset: `game/export_presets.cfg` → preset **`Android Debug`**

- `gradle_build/use_gradle_build = true` — **required**: Godot only
  honors `min_sdk`/`target_sdk` overrides with Gradle builds.
- `gradle_build/min_sdk = 24`, `gradle_build/target_sdk = 36`
- `version/code = 100`, `version/name = 0.1.0` (blueprint §6 start
  sequence; versionCode monotonically increases, never reused)
- `package/unique_name = com.puzzlefactory.game` — **development
  placeholder**; final package id is set in M16.
- Portrait comes from the project setting
  `display/window/handheld/orientation = 1` (Godot 4.7 reads orientation
  from project settings, not from the preset).
- No production signing keys, no AdMob IDs, no Firebase config.
- Debug signing uses Godot's auto-generated debug keystore
  (`CN=Godot` debug certificate) — machine-local, never committed.

## 3. Commands

```powershell
# Full path: installs build template if missing, exports, verifies APK
pwsh -File scripts/export_android_debug.ps1

# Explicit JDK
pwsh -File scripts/export_android_debug.ps1 -JavaHome "C:\path\to\jdk-17"
```

Environment overrides: `GODOT_PATH` (Godot binary), `JAVA_HOME` /
`PFACTORY_JDK` (JDK ≥ 17), `ANDROID_HOME` (SDK).

## 4. How the Gradle build template works (Godot 4.7.2)

- Template source: `<Godot app data>/export_templates/4.7.2.stable/
  android_source.zip`.
- `scripts/export_android_debug.ps1` extracts it to `game/android/build/`
  and writes:
  - `game/android/.build_version` — template identifier
    (content of `version.txt`, e.g. `4.7.2.stable`); Godot refuses to
    export if missing/mismatched;
  - `game/android/build/.gdignore` — keeps the editor from scanning the
    template sources.
- `game/android/` is **generated and gitignored** — never hand-edit it
  (ADR-011).

## 5. Additional export requirements discovered at M0

- `rendering/textures/vram_compression/import_etc2_astc = true` and
  `import_s3tc_bptc = true` — cmdline Android export fails otherwise
  (ETC2/ASTC requirement).
- `application/config/icon` must be set (otherwise export logs an icon
  error).
- First Gradle run downloads Gradle 8.11.1 + dependencies → network
  required once per machine.

## 6. Verification (what "Android PASS" means)

`scripts/export_android_debug.ps1` runs `aapt2 dump badging` on the
produced APK and asserts:

```text
package  = com.puzzlefactory.game  (versionCode 100)
minSdkVersion     = '24'
targetSdkVersion  = '36'
```

plus `apksigner verify` for signature sanity, and manifest
`screenOrientation = 1` (portrait) is checked during M0 validation.

## 7. M0 result (2026-09-26, local machine)

- Export command: `godot --headless --path game --export-debug
  "Android Debug" build/android/puzzle_factory_debug.apk`
- Output: `build/android/puzzle_factory_debug.apk` (~80 MB), 0 errors in
  export log, signed with debug keystore, verified with aapt2 as above.

## 8. Deferred

- Release keystore, AAB release build, store config (M16)
- Production package id, production Firebase/AdMob credentials (M12–M16)
- Android export job in CI (see `ci/README.md`)
