# Traffic Presentation Scaffold (AGENT-2)

> **Owner:** AGENT-2 (GAME / UX)
> **Status:** Scaffold — visual components only, not connected to simulation
> **Source of truth:** `docs/MASTER_BLUEPRINT.md`; plan in `docs/UX_IMPLEMENTATION_PLAN.md`
> **Milestone:** M2-preparation (self-contained; does not depend on AGENT-1 M1)

## 1. Purpose

Reusable, original Traffic-theme presentation components, built before M1
publishes the generic presentation bridge so integration is fast once the real
event contract lands.

**Hard boundaries honoured:**

- No puzzle authority: no occupancy, move validation, blocking, matching,
  staging, win/lose or command logic (blueprint §8.2, ADR-003).
- No simulation imports: presentation never references `game/core`,
  `game/puzzle`, `game/levels`, `game/solver`, `game/generator` (enforced by
  `game/tests/presentation_boundary_test.gd`).
- Procedural art only: no third-party or binary assets, so nothing is copied
  (blueprint §3) and asset cost stays low.

## 2. Layout

```text
game/ui/
  layout_fit.gd                 resolution-independent board fit (§62)
  input_gate.gd                 bounded cosmetic input lock (§5.5)

game/audio/
  audio_contract.gd             bus + SFX id contract (§60)
  presentation_audio.gd         facade; safe no-op without streams

game/haptics/
  haptic_service.gd             light / warning / success, cooldown + toggle (§61)

game/themes/traffic/
  traffic_palette.gd            ColorKey -> color + symbol (§14, §59)
  model_*_view_data.gd          presentation DTOs (visual data only)
  bridge/presentation_event_router.gd   thin adapter boundary (provisional names)
  components/
    symbol_glyph.gd             procedural circle/triangle/square/star
    board_view.gd               grid surface, supplied dimensions + obstacles
    entity_view.gd              compact / van / truck silhouettes + orientation
    item_view.gd                passenger item token
    destination_view.gd         station, accepted symbols, capacity, queue
    staging_view.gd             arbitrary slot count + pressure state
    staging_slot_view.gd        single slot
    selection_indicator.gd      selection ring
    blocked_indicator.gd        bounded shake <= 250 ms + blocker flash
    movement_tween_controller.gd interpolates an externally supplied path
    match_effect.gd             bounded match/loading burst
    completion_effect.gd        bounded win sequence (<= 2 s, skippable)
    failure_effect.gd           bounded fail sequence (<= 1.5 s, skippable)
    hud_shell.gd / hud_chip.gd  HUD shell + color/symbol objective chips
  dev/
    mock_presentation_state.gd  DEV-ONLY mock view data
    traffic_sandbox.gd/.tscn    responsive sandbox scene
```

## 3. Running the sandbox

Not the production boot scene (`game/project.godot` is untouched).

- Editor: open `game/themes/traffic/dev/traffic_sandbox.tscn` and Run Current Scene.
- Headless check: `traffic_layout_test.gd` instantiates it, calls `build()`
  and `layout_for(size)` — no viewport required.
- Demo hooks for visual review: `demo_select`, `demo_block`, `demo_move`,
  `demo_match`, `demo_win`, `demo_fail`, `set_staging_slots`,
  `set_staging_pressure`.

## 4. Responsive contract

- Reference `1080x1920` only; layout is computed, never hard-locked.
- `LayoutFit.fit_board_rect(available, cells, margin, max_width)` keeps the
  cell ratio, centres the board and caps width on tablets.
- Targets: 16:9, 18:9, 19.5:9, 20:9, tablet. Safe areas are consumed by the
  screens that host the shell at M3.
- Touch targets / chips use `>= 48` logical px minimums.

## 5. Accessibility

Every `ColorKey` resolves to **color + symbol** (`COLOR_A` circle, `COLOR_B`
triangle, `COLOR_C` square, `COLOR_D` star). Unknown keys fall back to a
neutral color and the circle symbol, so presentation never breaks. Symbols are
drawn on vehicles, item tokens, destination badges and HUD chips; matching must
remain playable with hue removed (blueprint §59).

## 6. Input lock safety

`PresentationInputGate` clamps every request to `max_lock`, tracks owner +
reason, decrements via `tick(delta)` and **auto-releases** at zero. No
animation-dependent indefinite lock is possible. Default cap 0.6 s; a caller
may raise it (e.g. 2.0 s for result transitions) but never unbounded. It is
presentation-only and never consulted by simulation.

## 7. Audio integration note (requires AGENT-1/integration)

`audio_contract.gd` declares buses `Master / Music / SFX / UI` and the ten
required SFX classes. The actual Godot **Audio Bus layout lives in
`game/project.godot`**, which this scaffold must not modify. Required M4
integration step (documented, not done here):

1. Add the bus layout (Master -> Music, SFX, UI) to `game/project.godot`.
2. Register original/approved streams via `PresentationAudio.register_stream`.
3. Route playback through pooled `AudioStreamPlayer`s on `bus_for(sfx)`.

No copyrighted or third-party audio is included.

## 8. Presentation bridge boundary

`presentation_event_router.gd` is a deliberate thin adapter: event names are
**data** (`PROVISIONAL_EVENTS`, from `UX_IMPLEMENTATION_PLAN.md` §2.2), not a
locked enum. Callers subscribe/dispatch; unknown events are ignored safely.
When AGENT-1 publishes the M1 contract, only the producer side is re-pointed.

## 9. Debug

No production/debug build gating is implemented here (AGENT-1 owns it). The
sandbox is a development-only scene under `dev/` and the boundary test asserts
no reusable component references it.

## 10. Tests

```text
scripts/run_tests.ps1
```

New suites:

- `game/tests/traffic_presentation_test.gd` — palette fallback, orientation,
  selection, staging counts, item/destination, bounded blocked/movement/effects,
  input gate failsafe, audio contract, haptics restraint, event router.
- `game/tests/presentation_boundary_test.gd` — no simulation imports, no
  binary/third-party assets, no mock leakage, sandbox present.
- `game/tests/traffic_layout_test.gd` — aspect-ratio fit maths, board scaling,
  staging recut, HUD chips, sandbox build.

## 11. Explicitly NOT implemented

Gameplay, board/occupancy logic, move validation, blocking logic, commands,
matching/staging/win/lose rules, levels, solver, generator, save, progression,
coins, boosters, analytics, Firebase, Remote Config, AdMob, IAP, Android
config, CI, and any `project.godot` change.
