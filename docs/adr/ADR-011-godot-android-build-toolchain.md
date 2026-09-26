# ADR-011: Use Godot's bundled Android build toolchain

Status: Accepted (2026-09-26)

## Context

The blueprint (§5) pins Android Build Tools 36.0.0, AGP 9.4.1 and Gradle
9.6.0 *when a custom build template is compatible*, and §5.3 requires:
"If the Godot-provided Android template requires a different AGP/Gradle
combination, preserve Godot compatibility and document the decision in
an ADR before replacing the template."

Facts found while producing the M0 Android Debug export with Godot
4.7.2-stable:

1. `gradle_build/min_sdk` / `gradle_build/target_sdk` export options can
   only be overridden when **Use Gradle Build** is enabled (verified in
   engine source and by export validation). A plain (non-Gradle) APK
   repack cannot pin minSdk/targetSdk.
2. Godot 4.7.2's bundled Android build template ships **AGP 8.6.1**,
   **Kotlin 2.1.21** and a **Gradle 8.11.1** wrapper, with template
   defaults `compileSdk 36`, `minSdk 24`, `targetSdk 36` — exactly the
   blueprint baseline versions.
3. Android export in cmdline mode requires ETC2/ASTC texture import
   (`rendering/textures/vram_compression/import_etc2_astc = true`).

## Decision

- Use the **Godot-provided Android build template unchanged**
  (`android_source.zip` → `game/android/build/`), i.e. AGP 8.6.1 /
  Gradle 8.11.1 — preserving Godot compatibility over the pinned
  AGP 9.4.1 / Gradle 9.6.0, per blueprint §5.3.
- Keep Gradle build enabled for Android exports so minSdk 24 and
  targetSdk 36 are explicitly enforced (not merely inherited).
- `game/android/` is generated (gitignored) and reproducible via
  `scripts/export_android_debug.ps1`; it is not hand-edited.
- Revisit AGP/Gradle only through the dependency update rule
  (blueprint §5.3) with a follow-up ADR.

## Consequences

- M0 Android Debug export succeeds with targetSdk 36 / minSdk 24
  verified by `aapt2 dump badging`.
- The blueprint's AGP 9.4.1 / Gradle 9.6.0 combination is **not** used
  until a compatible custom template is validated.
- First export downloads the Gradle distribution and Android
  dependencies (network required once per machine).
