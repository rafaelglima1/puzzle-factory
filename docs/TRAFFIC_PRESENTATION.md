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

## 11. Audio integration note (integration-owned)

`audio_contract.gd` declares the buses (`Master / Music / SFX / UI`) and the
ten required SFX classes; `PresentationAudio` is a safe no-op without streams.
The actual Audio Bus layout lives in `game/project.godot`
(AGENT-1/integration-owned), so it is **documented, not modified** here.
Required M4 step: add the bus layout, register original/approved streams,
route playback through pooled players on `bus_for(sfx)`.

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
logic, commands, M3 menus/result flow, save, progression, coins, boosters,
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
