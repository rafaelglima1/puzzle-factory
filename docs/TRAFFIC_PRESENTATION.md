# Traffic Presentation (AGENT-2)

> **Owner:** AGENT-2 (GAME / UX)
> **Status:** M2 presentation integration — scaffold adapted to the official M1
> event contract and M2 additive hooks prepared
> **Source of truth:** `docs/MASTER_BLUEPRINT.md`; contract in
> `docs/PRESENTATION_BRIDGE.md`; plan in `docs/UX_IMPLEMENTATION_PLAN.md`
> **Baseline:** M0 + M1 core + Traffic Presentation Scaffold (integrated)

## 1. Purpose

Presentation-only Traffic components plus a composition root
(`TrafficPresenter`) that the AGENT-1 Traffic product adapter
(`game/integration/traffic/**`) drives. Nothing here decides puzzle
correctness.

**Hard boundaries honoured:**

- No puzzle authority: no occupancy, path legality, matching, FIFO, capacity,
  staging rules, win or loss logic (blueprint §8.2, ADR-003).
- No simulation imports: presentation never references `game/core/**` or
  `game/puzzle/**` (enforced by `game/tests/presentation_boundary_test.gd`).
- Procedural art only: no third-party or binary assets (blueprint §3).

## 2. Official M1 contract alignment

Presentation consumes the **official** M1 vocabulary from
`docs/PRESENTATION_BRIDGE.md` (contract version 1). The provisional
`EntitySelected`/`EntityArrived` names are gone — there is one pathway:

```text
entity_placed, entity_move_started, entity_moved, entity_blocked, command_rejected
```

`presentation_event_router.gd` is presentation-side only. Because it must not
import core, it consumes the plain `DomainEvent.to_dictionary()` shape
(`{"type", "sequence", "data"}`) and exposes payload helpers:

```text
dispatch(event_type, payload)
dispatch_domain_event({ "type", "sequence", "data" })
payload_entity_id / payload_position / payload_footprint / payload_blockers /
payload_status / payload_code
```

Unknown event types are counted and ignored safely. `M2_EXPECTED_EVENTS`
(`entity_arrived`, `item_loaded`, `match_occurred`, `staging_changed`,
`objective_completed`, `game_completed`, `game_failed`) is **documentation
only** — not authoritative, not used to gate dispatch.

### Event → presentation mapping

| Official event | Presentation response |
|---|---|
| `entity_placed` | create/update entity view (position, footprint, orientation, color key, symbol) |
| `entity_move_started` | `animate_path` over the supplied `[from, to]`; bounded movement input lock |
| `entity_moved` | snap view to authoritative `to`; release movement lock |
| `entity_blocked` | bounded shake (≤250 ms), blocker highlight hook, `warning` haptic, blocked SFX |
| `command_rejected` | subtle generic invalid feedback; status/code kept for Debug only, never shown to users |

`TrafficPresenter.handle_event(event_type, payload, entity_provider)` performs
this mapping. M1 payloads carry no theme color/type, so an optional
`entity_provider` callable supplies richer `TrafficEntityData`; without it the
presenter synthesizes a neutral DTO from `position`/`footprint`. `bind_router`
subscribes the presenter to a router.

## 3. Presentation API (`traffic_presenter.gd`)

```text
setup(board), layout_for(viewport), set_objectives(keys)

show_entity, set_entity_state, set_entity_selected, set_entity_blocked, remove_entity
animate_path(id, cells, max_duration)
show_blocked(id, axis, blocker_ids)
show_command_rejected(id, status, code)

set_destination, remove_destination, set_queue
set_staging, set_staging_pressure

show_item_loaded, show_match, show_objective_complete
show_win, show_fail, skip_active_sequence, fail_reason_localization_key

handle_event, bind_router, advance, is_input_locked, teardown
```

All methods accept presentation DTOs or plain data. None queries the
simulation, decides legality, calculates matching, or computes win/lose.

## 4. Staging / queue / destination

- **Staging** accepts authoritative `slot_count`, occupants and
  `normal`/`warning`/`full` state; renders 3/4/5/6+ slots responsively; never
  computes fullness or triggers game-over.
- **Queue** renders an externally supplied ordered key list (color + symbol);
  no FIFO logic.
- **Destination** displays accepted keys, capacity, occupancy and queue; no
  matching rule.

## 5. Movement / loading / matching

- `animate_path` interpolates an externally supplied ordered cell path or
  `[from, to]`; it never pathfinds and never inspects occupancy. Duration is
  clamped (≤0.6 s) and drives a bounded, owner-tagged input lock.
- `show_match` / `show_item_loaded` are bounded procedural bursts with light
  haptic + SFX hooks; interrupt-safe and presentation-only.

## 6. Win / fail

- `show_win` → bounded completion effect (≤2 s), skippable, releases locks,
  emits `sequence_finished(&"win")`. No reward, no progression, no navigation.
- `show_fail(reason)` → bounded failure effect (≤1.5 s), skippable, emits
  `sequence_finished(&"fail")`. Machine reasons (`STAGING_FULL`,
  `NO_VALID_MOVES`, …) map to localization keys; raw enum names are never
  surfaced. M3 owns the retry/result flow.

## 7. Input lock safety

`PresentationInputGate` is preserved: owner + reason, bounded duration, auto
release via `tick`, manual `release`/`release_all`. Locks release on animation
completion, on skip, on teardown, and on failsafe timeout. `TrafficPresenter`
sets the gate cap to 2.0 s so result sequences fit while movement stays ≤0.6 s
by explicit request. No lock depends on an event that might never arrive.

## 8. Theme contract compatibility

`traffic_theme.gd` binds the generic `ThemeContract`
(`game/themes/base/**`, AGENT-1-owned) without modifying it:

- manifest validated by `ThemeContract.validate_manifest` (empty errors);
- all generic `PRESENTATION_SLOTS` bound by name;
- palette keys (`COLOR_A`…) validated by `ThemeContract.is_valid_color_key`;
- direction name → presentation degrees.

No missing generic capability was required for M2. Richer manifest loading
(audio/particle set ids) is deferred to the milestone that consumes it.

## 9. Accessibility

Every `ColorKey` remains symbol-backed: `COLOR_A` circle, `COLOR_B` triangle,
`COLOR_C` square, `COLOR_D` star; unknown keys fall back to a neutral color and
the circle. New queue/destination/staging/loading/match visuals all preserve
the symbol redundancy, so matching never depends on hue alone (blueprint §59).

## 10. Responsive sandbox

`game/themes/traffic/dev/traffic_sandbox.tscn` (dev-only; not the boot scene)
now demonstrates the M2 states through the presenter:

```text
entity placed / movement / blocked / command_rejected
queue populated, destination update
staging 3/4/5/6 slots, warning, full
item loaded, match effect
objective-complete flash
win effect, fail STAGING_FULL, fail NO_VALID_MOVES
```

`layout_for(viewport)` is validated at 16:9 and 20:9 headlessly; the sandbox
never becomes production startup.

## 11. Audio integration note (now implemented for M4)

`audio_contract.gd` declares the buses (`Master / Music / SFX / UI`) and the
ten required SFX classes. The real Godot Audio Bus layout now ships at
`game/default_bus_layout.tres`, referenced from `game/project.godot`
(`[audio] buses/default_bus_layout`) by the AGENT-1/integration pass, and
`game/tests/audio_bus_test.gd` asserts the runtime buses through `AudioServer`.

M4 `PresentationAudio` plays generated procedural streams (no binary assets)
through a bounded **8-player pool** hosted by the presenter, on the bus from
`Contract.bus_for(sfx)`; `Music` has a dedicated single player and a gate (no
music asset ships in M4). Requests are counted so headless tests never need a
real device; `Sound OFF` makes `play()` a safe no-op and `Haptics OFF` makes
`HapticService.trigger()` a no-op.

M4 interaction feedback boundary (presentation only):

```text
tap                 → acknowledge_tap        → tap (UI)         + light haptic
entity_move_started → animate_path           → valid_move (SFX) [exactly once]
entity_moved        → settle to authoritative cell
entity_blocked      → show_blocked           → blocked_move     + warning haptic
command_rejected    → show_command_rejected  → blocked_move (softer pitch)
item_loaded/match/objective_completed → loading / match / combo (+ light haptic)
game_completed/game_failed → bounded completion/failure sequence, then the result
```

`valid_move` is requested only on the authoritative `entity_move_started` event —
never on the pre-validation tap, the blocked case or a rejected command.

## 12. Tests

```text
scripts/run_tests.ps1
```

- `game/tests/traffic_m2_presentation_test.gd` — official M1 event mapping,
  placement, movement/settle/blocked, command rejection, unknown-event safety,
  staging authoritative state (3/4/5/6), queue/destination, match/loading hooks,
  win/fail bounded+skippable+lock-release, input-lock failsafe/teardown,
  ThemeContract compatibility.
- `game/tests/traffic_presentation_test.gd` — router official vocabulary and
  payload helpers, plus the scaffold component tests.
- `game/tests/presentation_boundary_test.gd` — no core/puzzle imports, no
  binary assets, no dev-mock leakage in reusable components.
- `game/tests/traffic_layout_test.gd` — aspect-ratio fit and sandbox build.

## 13. Explicitly NOT implemented

Gameplay/board/occupancy/validation/matching/queue/capacity/staging/win/lose
logic, commands, save, progression, coins, boosters,
solver, generator, Firebase, AdMob, IAP, Remote Config, and any
`project.godot` change. The M2 simulation and its Traffic product adapter live
in `game/integration/traffic/**` (AGENT-1 owned) — see section 14.

## 14. M2 integration alignment (AGENT-1 adapter)

The M2 cross-integration remediation aligned simulation and presentation on a
single contract:

- **One event vocabulary.** The presenter/router consume the official
  snake_case names (`entity_placed`, `entity_move_started`, `entity_moved`,
  `entity_blocked`, `command_rejected`, `entity_completed`, `item_loaded`,
  `match_occurred`, `staging_changed`, `objective_completed`, `game_completed`,
  `game_failed`). The provisional PascalCase proposal names are obsolete.
  `bind_router()` subscribes `Router.ALL_EVENTS` (M1 + M2).
- **Full path.** `entity_move_started` presentation payloads are enriched with
  the official `path` from the matching `entity_moved`, and the presenter uses
  it for interpolation (falling back to `[from, to]`).
- **Sequencing.** `entity_moved` arriving during an active tween no longer
  snaps backwards or releases the lock early: the authoritative target is
  applied when the tween ends, and the movement lock stays bounded by
  `MOVE_LOCK_CAP`.
- **Visual lifecycle.** `entity_completed` and `staging_changed(action=added)`
  remove the entity view only after its movement finishes, so an active
  animation is never cut.
- **Orientation.** The adapter projects `orientation` in **degrees**
  (north 0, east 90, south 180, west 270), matching
  `traffic_theme.DIRECTION_DEGREES` and `EntityView.orientation_degrees`.
- **Fail reasons.** Canonical machine ids are the simulation's lowercase ids
  (`staging_full`, `no_valid_moves`); the failure effect maps them to
  `level.fail.*` keys and still accepts the uppercase aliases.
- **Authoritative sync.** `TrafficPresentationAdapter.sync_authoritative_state()`
  refreshes destination occupancy/queue, staging occupancy and staging pressure
  through the presenter's public setters after a command. Presentation performs
  no FIFO, matching, capacity or game-over computation.
- **Real cross-layer tests.** `game/tests/traffic_integration_test.gd` wires
  `TrafficGameFactory -> Simulation -> DispatchEntityCommand ->
  TrafficPresentationAdapter -> PresentationEventRouter -> TrafficPresenter`
  (happy path with a turning path, staging, both failure reasons, orientation
  and movement synchronization).

## 15. M3 first-playable shell (AGENT-2)

`game/themes/traffic/m3/**` adds the player-facing shell (presentation only).
It never decides gameplay: it renders supplied state and emits player intents.

```text
m3_first_playable.gd + .tscn   orchestrator: states + intents + API
main_menu_screen.gd            Project Traffic + PLAY (+ debug LEVEL SELECT)
gameplay_screen.gd             board (TrafficPresenter) + Level/Restart/Menu
result_screen.gd               win / fail overlay + NEXT/RETRY/MENU
debug_level_select_screen.gd   10 entries; ZERO-BASED level_selected(index)
m3_strings.gd                  temporary English key catalog (localization seam)
m3_style.gd                    procedural style tokens/StyleBoxes (no assets)
```

**States:** `MAIN_MENU`, `PLAYING`, `WIN_RESULT`, `FAIL_RESULT`,
`DEBUG_LEVEL_SELECT`.

**Shared intent contract (signals):** `play_requested`,
`entity_tapped(entity_id)`, `restart_requested`, `next_requested`,
`menu_requested`, `debug_level_selected(level_index)` (zero-based).

**Presentation API:** `show_main_menu()`, `show_playing(level_number,
total_levels)`, `show_win_result(level_number, is_final_level)`,
`show_fail_result(level_number, fail_reason)`, `show_debug_level_select(entries)`
(returns false when debug is disabled), `set_progress(level_number,
total_levels)`, `get_traffic_presenter()`.

**Entity taps.** `BoardView.entity_at(point, min_touch)` performs a geometric,
orientation-aware hit test over the entity views (short axis expanded to a
reachable touch size; deterministic tie-break). `TrafficPresenter.
entity_at_board_point()` forwards it and `GameplayScreen.handle_tap_at()`
emits `entity_tapped` only when the presenter is neither input-locked nor
mid-sequence. Presentation identifies *what* was tapped; the simulation decides
whether the move is legal. Touch and mouse both work (400 ms de-dupe).

**Result / fail copy.** `show_fail_result` maps the supplied machine reason
through the failure effect to a `level.fail.*` key and resolves it with the
temporary English catalog; raw reason names are never shown. Win shows
`LEVEL COMPLETE` + NEXT/MENU, final level shows `ALL N LEVELS COMPLETE` + MENU,
fail shows `TRY AGAIN` + RETRY/MENU. No rewards, coins, progression or revive.

**Debug gating.** The level selector is only reachable while `debug_enabled`
(default `OS.is_debug_build()`) is true, so editor/Debug exports expose it and
release exports do not (blueprint §67/§68). The shell makes no `project.godot` /
boot-scene change itself; the M3 integration pass (AGENT-1,
`game/integration/traffic/traffic_m3_app_controller.gd` + `.tscn`) switched
`application/run/main_scene` to that controller, owns the shell Node, supplies
the real session wiring and explicitly calls `show_main_menu()` at startup so
gating is deterministic. Debug-selected attempts are isolated from production
progression by the session.

**Responsive.** Header is a separate `Style.HEADER_HEIGHT` band; the presenter
is offset below it and re-laid-out, so board/staging keep their own margins.
Reference 1080×1920, validated headlessly at 16:9, 20:9 and a tablet viewport
(board/staging/header buttons/result panel/debug panel all inside the viewport).

**Tests:** `game/tests/m3_first_playable_test.gd` (menu/play intent, level
indicator, entity tap + empty tap + locked input, restart/next/menu intents,
win/final/fail results, debug selector zero-based + gating, responsive).

Not implemented in M3 (M4+): production juice, new audio/haptics systems,
settings persistence, transitions framework, final particles, coins, boosters,
ads, IAP, daily rewards, analytics, store SDKs.

## 16. M4 UX / juice + integration (AGENT-2 implementation, AGENT-1 wiring)

AGENT-2 added the M4 presentation layer: tap/valid/blocked/rejected feedback,
eased movement, staging-pressure feedback, match/loading/objective polish,
bounded completion/failure sequences with a **deferred result reveal** (gameplay
stays visible, the result appears only after the sequence finishes or is safely
skipped), bounded screen transitions, procedural audio with the 8-player pool,
haptic priority/cooldown, and a Settings screen (Music / Sound / Haptics). The
M3 350 ms result-input guard in `result_screen.gd` is preserved.

The M4 integration pass (AGENT-1, `integration/m4`) wired persistence into the
real app: `TrafficM3AppController` owns `M4PresentationSettingsStore`, loads it
before the shell is shown, applies the persisted values to the shell/presenter
_before_ `show_main_menu()`, and persists the Settings toggles. See
`docs/M4_PRESENTATION_SETTINGS.md` §6 and `game/tests/m4_cross_integration_test.gd`.

Not implemented in M4: production music, volume sliders, locale, coins,
boosters, ads, IAP, analytics, store SDKs, robust save/migration (M10).

## 16. M4 UX / juice (AGENT-2)

M4 makes the same M3 flow feel responsive and coherent. Everything stays
cosmetic and deterministic: presentation may interpolate authoritative A → B,
never invent B, and never touches simulation state.

**Tap acknowledgement.** `TrafficPresenter.acknowledge_tap(id)` shows an
immediate bounded highlight (selection ring, ~0.1 s) plus a tap sound and a
light haptic, before the logical result is known. It does not imply legality;
the simulation still decides, and blocked/rejected feedback follows.

**Movement.** `movement_tween_controller` now applies an ease-out curve
(`1 - (1-t)^3`) for a fast response and soft arrival. Duration stays bounded by
`MAX_DURATION = 0.6 s`; the entity always settles exactly on the authoritative
target (`t=1 → 1.0`) and the movement lock is released on arrival.

**Blocked / rejected.** Blocked = axis-aware shake (≤250 ms) + the blocked
entity and its blockers briefly outlined + warning haptic + blocked SFX.
Generic `command_rejected` is softer and distinct (short 0.12 s nudge, lower
sound, no haptic); raw status/code remain debug-only. Staging `full` keeps its
pressure pulse and is not a per-tap error flash.

**Staging pressure.** `staging_view` pulses the slots (bounded ~0.35 s) when the
supplied pressure becomes `warning`/`full`; it never recomputes capacity.

**Match / loading.** The procedural match burst is unchanged in spirit, now with
a short scale pulse on the target view. Effect nodes are capped
(`MAX_ACTIVE_MATCH_EFFECTS = 6`, `MAX_ACTIVE_BLOCKED_INDICATORS = 4`) so event
spam cannot churn nodes without bound.

**Objective.** Completing an objective flashes the HUD chips and plays a soft
success accent; no large interruption.

**Completion / failure.** `completion_effect` gained a board glow, two rings and
16 fixed confetti dots (≤2 s, skippable after 0.3 s). `failure_effect` gained a
staging warning band and brief impact bars (≤1.5 s, skippable). Both are bounded
procedural draws, not emitters.

**Result sequencing (key M4 fix).** Previously the M3 result overlay could cover
the board in the same frame the win/fail sequence started, hiding it. Now the
shell records a **pending** result and keeps gameplay visible while
`TrafficPresenter.active_sequence()` is active; it reveals the result on the
presenter's `sequence_finished` (skip or natural end), with a bounded fallback
timeout (`RESULT_REVEAL_TIMEOUT = 2.5 s`). The simulation is already complete
throughout; the delay is cosmetic only and never affects persistence.

**Result input guard.** The device-derived `ResultScreen.INPUT_GUARD_MS = 350`
is preserved unchanged and covered by an M4 regression check.

**Transitions.** State changes fade the incoming screen in over a bounded 0.18 s
(`TRANSITION_DURATION`); navigation intents are emitted exactly once and the
animation never creates duplicate callbacks.

**Audio (real runtime).** `presentation_audio.gd` now plays through a bounded
pool of 8 `AudioStreamPlayer`s hosted in the presenter's `AudioHost`. Streams are
**generated in code** (`procedural_sfx.gd`) for all ten required SFX classes —
original short tones/clicks, no binary assets. Routing uses
`AudioContract.bus_for()`, and a missing bus (isolated branch/tests) falls back
to `Master`. Headless hosts stay silent but count requests; Sound OFF is a safe
no-op; unknown SFX or missing stream returns false. Music support exists as a
gate (`set_music_enabled`) without shipping a placeholder loop.

**Haptics.** `light / warning / success` with a 150 ms cooldown; a strictly
higher-priority pattern may upgrade within the cooldown (blocked WARNING right
after a tap LIGHT still fires). Disable via `set_enabled(false)` /
`set_haptics_enabled(false)`; no puzzle dependency.

**Settings UI.** `m3/settings_screen.gd` exposes Music/Sound/Haptics toggles with
signals `music_enabled_changed` / `sound_enabled_changed` /
`haptics_enabled_changed` and `apply_presentation_settings(music, sound,
haptics)`. Applying settings updates the runtime services and the controls
immediately; **persistence is integration-owned** and wired in the M4
cross-integration pass.

**Tests:** `game/tests/m4_presentation_juice_test.gd` covers procedural audio,
runtime playback/pool/bus fallback, sound/haptics gates, tap acknowledgement,
eased movement + authoritative settlement, blocked/rejected, match/loading pulse,
objective feedback, completion/fail sequencing, the 350 ms result guard,
settings UI intents + apply, bounded transitions, and effect caps.

## 17. M5 Level Lab (AGENT-2 debug tooling)

`game/themes/traffic/dev/m5/**` is a **developer-only** content inspector built
while AGENT-1 implements the M5 Content Engine. It renders plain supplied data;
it never validates, solves, generates or mutates gameplay, and it imports no
core/puzzle/solver/levels/persistence code.

```text
level_lab_contract.gd          flat plain-data contract + lenient normalizers
level_lab_model.gd             holds normalized preview/validation/solver; builds Traffic DTOs
level_lab_view.gd              visual inspector (reuses BoardView) + text panels
level_lab_path_overlay.gd      debug path drawing (start marker, numbered nodes, arrowhead)
solution_playback_controller.gd supplied-command playback with an optional driver
level_lab.gd + level_lab.tscn  orchestrator + dev entry scene
m5_samples.gd                  1–2 sample previews (dev fixtures only)
```

**Contract (boundary).** `normalize_preview` produces a flat dictionary:
`level_id`, `schema_version`, `revision`, `board_width/height`, `staging_slots`,
`obstacles`, `entities`, `destinations`, `paths`, `items`, `queues`,
`objectives`. It is deliberately lenient (accepts `width`/`board_width`,
`vehicles`/`entities`, `stations`/`destinations`, `color`/`color_key`, cell
dicts/`Vector2i`, footprint dicts/`Vector2i`, routes/paths) and never crashes on
malformed input. `normalize_validation` yields `VALID`/`INVALID` + errors
(`code`, `path`, `message`); `normalize_solver` yields
`SOLVABLE`/`UNSOLVABLE`/`UNKNOWN` + metrics; `normalize_commands` yields
`{type, entity_id}` (entity-less entries dropped).

**API.** `show_level(preview)`, `show_levels(levels, index)`,
`set_validation_result(raw)`, `set_solver_result(raw)`, `set_playback_driver(d)`,
`play_solution()`, `step_solution()`, `reset_preview()`, `next_level()`,
`previous_level()`, `layout_for(viewport)`, plus `model()/view()/playback()`
accessors. Cross-integration adapts `LevelDefinition`, `LevelValidationResult`
and `SolverResult` into these plain shapes.

**Rendering.** Reuses `BoardView` (no second gameplay renderer). Paths are drawn
by the overlay with a start marker, ordered numbered nodes and a direction
arrowhead. Queues show ordered `1→COLOR_A(circle)` entries (color + symbol, never
color alone). Staging and objectives are listed. Validation shows `VALID` or
`INVALID (N)` with each `code @path: message`. Solver shows status, depth,
visited/expanded/dead-ends/branching/runtime and the numbered command list.

**Playback.** `solution_playback_controller` walks a supplied command array
exactly once per step, never overflows past the end, and resets to step 0. An
optional driver (`reset()`/`execute(command)`/`snapshot()`) is supplied later by
cross-integration; without one the controller emits `driver_missing`. It never
solves.

**Debug gating.** `debug_enabled` defaults to `OS.is_debug_build()`; when off the
lab hides itself, refuses levels, and disables its controls. The dev scene
(`level_lab.tscn`) is never referenced by production startup, and the normal Main
Menu is unchanged.

**Tests:** `game/tests/m5_tooling_test.gd` covers contract normalization
(including malformed input), model counts/board mapping/queue order/path
synthesis, view rendering + texts + responsive layout + invalid preview safety,
path overlay, playback step/reset/bounds + driver hook, lab navigation, level
switch state clearing + bounded node count, validation/solver UI, play/reset,
the debug gate, and scene loading.

## 18. M6 Generator Lab (AGENT-2 debug tooling)

`game/themes/traffic/dev/m6/**` is a developer-only inspector for generation
output, built alongside AGENT-1's generation engine. Like the M5 Level Lab it
renders plain supplied data only: it never generates, solves, validates or
mutates anything, and imports no generator/solver/levels/core/puzzle code.

```text
generator_lab_contract.gd      lenient plain-data normalizers (candidate/batch/...)
generator_lab_model.gd         normalized candidates + batch + filtering; builds board DTOs
generator_lab_view.gd          visual inspector (reuses BoardView + M5 path overlay)
generator_lab.gd + .tscn       orchestrator + dev entry scene
m6_samples.gd                  candidate/batch fixtures (dev only)
```

**Candidate contract.** `candidate_id`, `seed`, `preview` (normalized through the
M5 preview contract), `generation` (constraints), `validation`, `solver`,
`difficulty` (`score` clamped 0..1, `bucket` in EASY/MEDIUM/HARD/EXPERT/UNKNOWN,
`components`), `dedupe` (`fingerprint`, `duplicate`, `of`), `decision`
(ACCEPTED/REJECTED + reasons). `normalize_batch` yields
`generated/invalid/unsolvable/duplicates/accepted` + a bucket histogram. All
normalizers are lenient and never crash on malformed input.

**Capabilities.** Candidate board preview and paths; info (id/seed/board/entities);
generation constraints; validation status + errors; solver status + depth/
visited/expanded/dead-ends/branching/runtime; difficulty score/bucket/components;
dedupe fingerprint + duplicate origin; accept/reject decision + reasons; batch
counts with a small text histogram. Navigation: previous/next within the
filtered list; filters by bucket and decision (ALL/EASY/MEDIUM/HARD/EXPERT and
ALL/ACCEPTED/REJECTED).

**Debug gating.** `debug_enabled` defaults to `OS.is_debug_build()`; when off the
lab hides itself, refuses candidates, and disables controls. The dev scene is
never referenced by production startup.

**Tests:** `game/tests/m6_tooling_test.gd` covers normalization (candidate/
difficulty/bucket/dedupe/decision/batch), malformed-input safety, model
counts/board mapping/histogram, filter behavior, view rendering + responsive
layout, lab navigation, difficulty/rejection/dedupe/batch display, empty-filter
state, repeated-load node stability, the debug gate, and scene loading.
