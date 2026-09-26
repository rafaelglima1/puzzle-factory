# PUZZLE FACTORY — UX / GAME PRESENTATION IMPLEMENTATION PLAN

> **Owner:** AGENT-2 (GAME / UX)
> **Status:** Preparation — implementation-ready specification
> **Created:** 2026-09-26
> **Source of truth:** `docs/MASTER_BLUEPRINT.md` (this document never overrides it)
> **Scope:** Screen flow, gameplay presentation, Traffic theme spec, visual direction,
> responsive layout, feedback contract, audio, haptics, accessibility, asset contract,
> debug UX.
> **Non-goals:** No gameplay, simulation, level system, solver, generator, monetization,
> analytics, Firebase, Android, CI or production UI is implemented by this document.
> It is a plan only.

---

## 0. Purpose and Boundaries

This document converts the blueprint's visual/game requirements (sections 3, 8, 13, 14,
31, 32, 38, 39, 59–62, 63, 64, 67, 68, 78) into an implementation-ready UX plan for
AGENT-2's milestone work (M2 presentation, M3 screens, M4 juice, later UI waves).

### Hard rules this plan must obey

| Rule | Blueprint ref |
|---|---|
| Presentation consumes simulation events; it never decides puzzle correctness | §8.2 |
| Core never knows theme words (`bus`, `passenger`, ...) — only generic concepts | §8.1 |
| Blocked feedback: small shake, short sound, optional haptic, optional blocker highlight; do not punish exploratory taps | §13.3 |
| Matching uses stable `ColorKey`s (`COLOR_A`, ...), never literal render colors; matching must not depend solely on hue | §14, §59 |
| Presentation must not delay logical correctness; player regains control quickly | §32 |
| Original visual identity; no copying of any competitor's assets, layout, sounds or identity (incl. "Bus Fever") | §3 |
| Portrait only; safe areas respected; test 16:9 / 18:9 / 19.5:9 / 20:9 / tablet | §62 |
| Audio buses `Master / Music / SFX / UI`; SFX classes fixed list; settings persisted | §60, §41.1 |
| Haptics `light / warning / success`, configurable, restrained | §61 |
| All user-facing text via localization keys (pt-BR, en-US, es) | §58 |
| Debug overlays exist (entity IDs, occupancy grid, paths, blockers, state hash, FPS, solver recommendation); production must not expose them | §68, §67 |
| 60 FPS target on mid-range, ≥30 FPS low-end; pool obviously repetitive visuals | §63, §64 |

### AGENT-2 ownership boundary (blueprint §78)

AGENT-2 owns: Godot scenes, presentation, UI, animations, particles, audio, haptics,
theme implementation, tutorial presentation, level visual composition, polish,
store-preview gameplay scenes. Cross-boundary changes (event contracts, save schema
keys, abstractions) require explicit agreement with AGENT-1 — see section 12.

---

## 1. Screen Flow

### 1.1 Core loop (in-scope screens)

```text
Boot / Splash
   ↓
Main Menu
   ↓
Level (gameplay: HUD + board + staging + controls)
   ↓
Win Result ────────── Fail Result
   ↓                     ↓
Next Level           Retry / Watch-Ad-Continue (M14, deferred)
   ↓
Main Menu (or direct next level)
```

Supporting overlay states inside Level:

```text
Pause (resume / restart / settings / quit)
Tutorial overlay (contextual, interactive — §31)
Booster tray (bottom, M11)
Result sequences (win/fail animation before result panel)
```

### 1.2 Milestone ownership

| Screen / state | First milestone | Owner | Notes |
|---|---|---|---|
| Level board presentation (select / move / blocked / match) | M2 | AGENT-2 (on AGENT-1 events) | M2 acceptance: vehicle selected, blocked cannot move, matching processes |
| Boot / Splash | M3 | AGENT-2 | fast launch, no network (§65) |
| Main Menu | M3 | AGENT-2 | Play / level progress / settings entry |
| Level HUD (objectives, counters, pause) | M3 | AGENT-2 | localized keys only |
| Win Result / Fail Result | M3 | AGENT-2 | shows `fail_reason`-driven localized message |
| Restart / Next Level flow | M3 | AGENT-2 | fast restart (§2 principle 3) |
| Debug level select | M3 | AGENT-2 | debug/QA only (§68) |
| Full level select / progression screen | M10 | AGENT-2 | after progression system lands |
| Pause screen | M3 | AGENT-2 | |
| Tutorial overlays (finger cue, highlight, one line) | M3 basic → M4 polish | AGENT-2 | core tutorial done by level 5 (§31) |
| Settings screen | M4 | AGENT-2 | M4 requires audio settings persist + haptics disable; placeholder may exist earlier |
| Combo / score / juice layer | M4 | AGENT-2 | UX / Juice milestone |
| Booster tray + booster UI | M11 | AGENT-2 | Undo / Extra Slot / Shuffle |
| Rewarded "continue" dialog | M14 | AGENT-2 UI, AGENT-1 ads abstraction | explicit user action required |
| Interstitials | M14 | system/SDK | never during active gameplay (§52.2) |

### 1.3 Deferred screens (future, not now)

| Screen | Deferred to | Notes |
|---|---|---|
| Settings (full: audio, haptics, language, privacy links) | M4 core / grows at M15 | persisted in `settings` save block (§41.1) |
| Daily Reward | M10 wave | 7-day cycle (§36); `daily_reward_enabled` flag |
| Shop | post-1.0 | `feature_shop` flag (§49); not in 1.0 scope (§84) |
| Privacy / Consent menu | M15 | consent, ads personalization, data deletion path (§56) |
| Ads placement UI | M14 | rewarded opt-in surfaces only |
| Cloud save UI | post-1.0 | not required for 1.0 |
| Cosmetics | post-1.0 | §34.3 / §85 |
| Daily Challenge | post-1.0 | §37 |
| World / meta map | post-1.0 | no complex map for MVP (§33) |
| Store preview gameplay scenes / creative capture | M19+ (§87) | scripted replay capture, no bespoke ad levels |

**Rule:** deferred screens get a design slot (entry point hidden behind feature flag or
absent) but zero implementation until their milestone.

---

## 2. Gameplay Presentation — Simulation Event Mapping

### 2.1 Principle

The simulation emits **domain events**; presentation consumes them and produces
**visual/audio/haptic responses only**. Presentation:

- NEVER mutates `GameState`;
- NEVER gates win/lose/validity decisions;
- MAY lock input **cosmetically** and briefly (see §5.4 input-gate rules);
- MUST remain correct if animations are skipped, stalled or interrupted.

Logical state updates immediately; presentation animates *toward* the already-decided
state (catch-up model). This is what keeps §32 ("do not delay logical correctness")
satisfiable.

### 2.2 Event catalog → presentation

Generic events (core vocabulary only — no theme words, §8.1):

| # | Simulation event (generic) | Presentation response |
|---|---|---|
| 1 | `EntitySelected` (command accepted) | selection ring + slight lift; destination badge pulse; light tick |
| 2 | `EntityBlocked` (command → `BLOCKED`) | small shake along blocked axis + blocker flash highlight + short blocked sound + optional `warning` haptic (§13.3) |
| 3 | `EntityMoveStarted` | movement tween starts (anticipation → ease-out), orientation snaps to path direction |
| 4 | `EntityArrived` | settle bounce, arrival thump, release input gate |
| 5 | `EntityExited` (completed entity leaves board) | exit ramp fade + small particle puff |
| 6 | `ItemQueued` (queue contents visible) | token pops into queue slot (FIFO order visible) |
| 7 | `ItemLoaded` (item → entity) | token travels to entity, seat/hold pip fills, `loading` SFX tick per item |
| 8 | `MatchOccurred` (color_key match processed) | match flash on entity + destination, burst particles, `match` SFX |
| 9 | `StagingReceived` (entity enters staging) | entity settles into slot, slot pip fills |
| 10 | `StagingPressureChanged` (n/N slots) | pressure bar updates; at N-1: subtle warning pulse; at N: full-red flash + `warning` haptic |
| 11 | `ObjectiveProgress` | HUD counter ticks (score pop) |
| 12 | `ObjectiveCompleted` | objective banner pop, `combo`/success micro-feedback, no input lock |
| 13 | `ComboIncreased` | combo meter scale-pop + rising pitch tier of `combo` SFX |
| 14 | `ScoreChanged` | floating score text (pooled, §64) |
| 15 | `LevelCompleted` | win sequence: sweep/particles → Win Result; `level_complete` SFX; `success` haptic |
| 16 | `LevelFailed(fail_reason)` | fail sequence per reason (staging full vs no moves vs limits) → Fail Result; `level_fail` SFX; `warning` haptic |
| 17 | `BoosterApplied(type)` | per-booster effect (see §5) |
| 18 | `UndoApplied` | rewind presentation (inverse tween or crossfade to snapshot view), ≤500 ms |

### 2.3 Ordering and interruption policy

1. Events are consumed **in emission order**.
2. An entity's animations are **interruptible** by newer events about the same entity
   (arrival supersedes movement, etc.) — presentation snaps to the newest logical state.
3. Multiple entities animate concurrently; per-entity chain, global pooling.
4. If an event arrives while its predecessor animates: fast-forward predecessor to end
   (≤80 ms) then run successor — never queue unbounded animation backlog.
5. Win/Fail sequences are **skippable** by tap after 300 ms.

---

## 3. Traffic Theme — First Theme Presentation Specification

Theme-level vocabulary is allowed **here only** (§8.1/§38: core never sees these words).
All values live in the Traffic `ThemeManifest` (§39), consumed through the generic
presentation contract (section 9).

### 3.1 Vehicle visual categories (maps `entity_type`)

| Category | Footprint (typical) | Visual |
|---|---|---|
| `compact` | 2×1 | rounded body, big windshield, roof carries ColorKey symbol |
| `van` | 2×1 / 3×1 | taller box body, same color system |
| `truck` | 3×1 | cab + cargo block; cargo carries ColorKey symbol |
| `service` (contract slot, unused in v1) | — | reserved for future mechanics |

- One art silhouette per category; color applied at runtime from palette (section 4).
- Orientation: single art rotated in 90° steps (low asset cost); validate readability
  at all four rotations.
- No bespoke per-level vehicle art.

### 3.2 Passenger / item visual categories (maps `item_type`)

| Category | Visual |
|---|---|
| `passenger_standard` | small person token, ColorKey body + symbol decal |
| `passenger_priority` (contract slot, unused in v1) | reserved (future VIP-like mechanic) |
| `luggage` (contract slot, unused in v1) | reserved |

Queue display: tokens stacked in FIFO strip at the destination; visible count from
`Queue.visible_count`.

### 3.3 Destination / station

- Platform/gate structure anchored at its board edge position.
- Shows accepted `ColorKey` badges as **color + symbol** pairs (never color alone).
- Capacity pip row; queue strip; state (open/full) readable via badge, not hue only.

### 3.4 Staging area

- Bottom band (above bottom controls) with N slots (default 4, per-level configurable).
- Slot pips + occupied entity previews.
- Pressure states: **normal** → **warning** (pulse at N-1) → **full** (red frame,
  warning pulse, `warning` haptic; leads to `STAGING_FULL` fail when violated).

### 3.5 Board / background

- Flat road-grid background: low-contrast lane markings, subtle cell separators.
- Obstacle / blocked cells styled distinctly (texture + outline, not color alone).
- Background contrast kept below entities (readable congestion: entities pop).

### 3.6 Selection

- Selection: outline ring + lift (scale ≈1.05) + selected state stays visible until
  command resolves.
- No production path-preview that reveals solver answers (debug-only: section 10).

### 3.7 Blocked feedback (§13.3)

- Small shake along the attempted movement axis (~180 ms).
- Blocker cells flash highlight (outline pulse).
- Short `blocked_move` SFX.
- Optional `warning` haptic (respect toggle).
- No score/move penalty for exploratory taps unless a level rule adds a move limit.

### 3.8 Path / movement

- Tween along cell centers; orientation snap to direction.
- Timing: anticipation 60 ms → travel ease-out; budget in section 5.
- Deterministic waypoints only — physics never authoritative (§8.3).

### 3.9 Loading

- Item token travels to entity; fill pips appear one per item; `loading` SFX tick
  (pitch tiers to avoid fatigue).
- Match flash when `color_key` processing succeeds.

### 3.10 Completion

- Win: entities cleared → sweep + particles → `level_complete` + `success` haptic →
  Win Result (rewards line localized; coins come from core/meta, not UX-decided).
- Per-objective banner pops as they complete (before final sequence).

### 3.11 Failure

- Localized headline + human explanation derived from machine `fail_reason`
  (`STAGING_FULL`, `NO_VALID_MOVES`, `MOVE_LIMIT_EXCEEDED`,
  `TIME_LIMIT_EXCEEDED`, `SPECIAL_OBJECTIVE_FAILED`).
- Distinct visuals: staging-full = red bay flash + micro camera shake;
  no-moves = board desaturate; limits = HUD counter flash.
- Never fabricate a reason presentation-side; map only known `fail_reason` values,
  fallback string for unknown.

### 3.12 Color + symbol accessibility

| ColorKey | Color (illustrative, deuteranopia-safe target) | Symbol |
|---|---|---|
| `COLOR_A` | blue | circle |
| `COLOR_B` | amber/orange | triangle |
| `COLOR_C` | violet | square |
| `COLOR_D` | teal/green | star |

- Symbol decal appears on: vehicle roof/cargo, passenger token, destination badge,
  HUD objective chips.
- Luminance separation between adjacent keys; verify with simulation of common CVD.
- Matching MUST be playable with hue information removed (blueprint §59).

**Originality:** the above defines an original identity (flat top-down vector system,
symbol-coded keys). No competitor names, layouts, assets, sounds or terminology are
referenced or copied (§3).

---

## 4. Visual Direction

Design language working name: **"Flat Grid City"** (internal only, not store-facing).

| Principle | Rule |
|---|---|
| Clarity on small screens | one glance = one fact; large silhouettes; ≥2 visual layers of separation (value + outline) |
| Portrait mobile | vertical stacking: HUD → board → staging → controls; board is the hero |
| Satisfying movement | anticipation + ease-out + settle bounce; consistent timing curves; particles only on meaningful beats |
| Readable congestion | entities: high contrast on muted road; blocked cells outlined; no busy textures behind board |
| Strong ad creatives | readable at thumbnail scale: big color blocks + silhouettes; supports §87 scripted-replay capture |
| Low asset cost | modular: silhouette per `entity_type` × runtime palette × symbol decal; no per-level art |
| Future theme replacement | every theme-specific value behind `ThemeManifest`; generic layers consume contracts only |

Concrete direction:

- Top-down orthographic, flat vector, rounded geometry, thick consistent outlines,
  two-tone shading (no gradients required).
- Reference design: **1080 × 1920 logical portrait** — a *reference*, not a lock
  (section 6).
- HUD: high-contrast chips, minimal text, icons + localized labels via keys.
- Fonts: single family, weight contrast for hierarchy; theme-scalable.

---

## 5. Responsive UI

### 5.1 Target matrix (§62)

```text
16:9   (1080×1920)      ← reference
18:9   (1080×2160)
19.5:9 (1080×2340)
20:9   (1080×2400)
tablet (e.g. 1600×2560 and 1280×800-class portrait)
```

Never design to a single pixel resolution. Godot setup (to be applied by AGENT-2 at
M3, after AGENT-1's project exists): viewport 1080×1920, `canvas_items` stretch,
`expand` aspect, so extra height/width is *available space*, not distortion.

### 5.2 Vertical zone layout (portrait)

```text
┌─────────────────────┐
│ safe-area inset      │ ← DisplayServer safe area / cutout
├─────────────────────┤
│ TOP HUD              │ level id, objectives, coins, pause   (fixed height band)
├─────────────────────┤
│                      │
│ GAMEPLAY BOARD       │ flexible; letterboxed by min(w, h/aspect) rule
│ (fit-to-content)     │
│                      │
├─────────────────────┤
│ STAGING AREA         │ N slots + pressure bar (fixed band, scales with slots)
├─────────────────────┤
│ BOTTOM CONTROLS      │ boosters (M11), restart, hints
├─────────────────────┤
│ safe-area inset      │
└─────────────────────┘
```

### 5.3 Fit rules

- Board pixel size = `min(availableWidth, availableHeight × (boardCellsW / boardCellsH))`,
  centered; surplus space becomes breathing margin (20:9) instead of cropping (16:9).
- Tablet: constrain whole app column to `maxColumnWidth` (≈ 720 reference px) centered;
  do not stretch HUD elements to full tablet width.
- Safe areas: read `DisplayServer.get_display_safe_area()`; top/bottom controls and
  HUD must sit inside insets; board may use full area but interactive elements may not.
- All placement via anchors/containers/theme units — no absolute screen coordinates.

### 5.4 Touch targets

- Minimum interactive target **≥ 48 dp** (≈120 px at reference density) for controls,
  boosters, pause, menu buttons.
- Board entity tap: hit box = cell footprint expanded to ≥48 dp equivalent on the
  smaller axis; cells smaller than that on tablets/16:9 must use expanded hitboxes,
  not shrunk targets.
- Inter-target gap ≥ 8 dp.
- No edge-adjacent critical controls within the gesture/inset margin.

### 5.5 Input gate (prevents M4 "no input lock bug")

- Presentation owns a single `InputGate` (cosmetic only; simulation never sees it).
- Every lock has: a **hard auto-release timer** = its max duration + 100 ms safety,
  and release on event-stream idle.
- Locked caps (also section 5.6 table): move ≤600 ms; shuffle ≤700 ms; win/fail
  sequence ≤2000 ms (skippable after 300 ms); blocked tap never locks (>100 ms
  debounce only).
- Overflowing any cap is a **P1 bug** by definition.

### 5.6 UX feedback contract

| ACTION | SIMULATION EVENT | VISUAL RESPONSE | AUDIO RESPONSE | HAPTIC | INPUT LOCK? | MAX DURATION |
|---|---|---|---|---|---|---|
| Tap (generic UI) | — | press state (scale 0.96) | `button` (UI bus) | none | no | 100 ms |
| Tap entity → valid select | `EntitySelected` | ring + lift + badge pulse | `tap` (UI bus) | `light` | no | 150 ms |
| Valid move | `EntityMoveStarted` → `EntityArrived` | movement tween + settle bounce | `valid_move` | `light` (start only) | YES — board, ≤ move duration | 600 ms hard cap |
| Blocked tap | `EntityBlocked` | shake + blocker flash | `blocked_move` | `warning` (optional, setting) | no (100 ms debounce) | 250 ms |
| Matching / loading | `ItemLoaded`, `MatchOccurred` | token travel + pip fill + match flash + particles | `loading` per item, `match` on resolve | none (or `light` at match if combo=1) | no (rides move lock) | 350 ms per token; 500 ms flash |
| Staging pressure high | `StagingPressureChanged` | pressure bar + warning pulse | none (or soft tick) | none (reserve warning for full/fail) | no | 400 ms pulse |
| Staging received entity | `StagingReceived` | slot settle + pip | `loading` tail | none | no | 300 ms |
| Combo | `ComboIncreased` | combo meter pop + floating text | `combo` (rising pitch tier) | `light` (cap 1 per 500 ms) | no | 600 ms |
| Objective complete | `ObjectiveCompleted` | banner pop + HUD tick | `combo` soft tier | none | no | 900 ms |
| Booster: Undo | `UndoApplied` | rewind/crossfade ≤500 ms | `button` + `valid_move` tail | `light` | YES ≤500 ms | 500 ms |
| Booster: Extra Slot | `BoosterApplied` | slot expands in | `reward` soft | `light` | no | 300 ms |
| Booster: Shuffle | `BoosterApplied` | FLIP reflow of moved entities | `button` + `match` tail | `warning` soft | YES ≤700 ms | 700 ms |
| Win | `LevelCompleted` | sweep + particles → Win Result | `level_complete` | `success` | YES (skippable ≥300 ms) | 2000 ms |
| Fail | `LevelFailed` | reason-specific vignette → Fail Result | `level_fail` | `warning` | YES (skippable ≥300 ms) | 1500 ms |

Rules: audio/HMI fire only if their settings are enabled; every response is optional
gracefully (muted + haptics-off must still be fully playable); animations never decide
or delay logical outcomes.

---

## 6. Audio Plan

### 6.1 Buses (§60)

```text
Master
├── Music   (loops, stingers)
├── SFX     (gameplay)
└── UI      (buttons, taps, menu)
```

- Bus volumes + mute persisted in save `settings` (§41.1); M4 acceptance requires it.
- Master mute = software mute of all children (fast toggle).

### 6.2 Required initial SFX classes (§60, fixed list)

| Class | Bus | Notes |
|---|---|---|
| `tap` | UI | entity select; 2–3 pitch variants |
| `button` | UI | menu/UI press |
| `valid_move` | SFX | move start |
| `blocked_move` | SFX | short, non-punishing |
| `loading` | SFX | per-item tick, pitch tiering |
| `match` | SFX | color match resolve |
| `combo` | SFX | rising tier by combo index |
| `level_complete` | SFX | stinger |
| `level_fail` | SFX | short, non-harsh |
| `reward` | SFX | coins/booster grant (M10+) |

Music: `menu_loop`, `level_loop` (seamless, low-fatigue), optional `result_sting`
variants for win/fail. One loop per context for v1.

### 6.3 Implementation constraints

- Preload streams at boot/level load — no runtime file IO during gameplay (§63).
- `AudioStreamPlayer` pool for overlapping SFX (cap ≈8 simultaneous; oldest stolen).
- Deterministic gameplay is unaffected by audio (audio never gates logic).
- **Assets:** original, commissioned, or explicitly approved permissive-license only.
  No copyrighted material. No third-party asset packs downloaded without explicit
  approval.

---

## 7. Haptic Plan (§61)

| Pattern | Definition | Triggers |
|---|---|---|
| `light` | 10–20 ms single tick | entity select; valid move start; combo (rate-limited); booster light uses |
| `warning` | double short tick | blocked tap; staging full; fail; shuffle soft |
| `success` | single medium burst | combo milestone (tiers); level complete (once) |

Restraint rules:

- At most **one haptic per player action**; global min cooldown 150 ms.
- Never on passive/ambient events; never loops.
- Master toggle `haptics_enabled` persisted; respects Android system-wide vibration
  setting (graceful no-op if unavailable, e.g., editor/desktop).
- Any device/API failure = silent degradation, never a crash.

---

## 8. Accessibility Plan (§59)

| Requirement | Plan |
|---|---|
| Color + symbol | mandatory dual coding for every `ColorKey` (vehicle, token, destination, HUD chips) — section 3.12; playable with color channel removed |
| Readable text | min body ≈14 sp equivalent; HUD labels ≥16 sp equivalent; theme text-scale factor; contrast ≥4.5:1 (normal) / ≥3:1 (large); all strings from localization keys (§58), no hardcoded scene text |
| Touch size | ≥48 dp targets + ≥8 dp gaps (section 5.4); expanded hitboxes where cells are smaller |
| Disable vibration | `haptics_enabled` toggle in Settings, persisted, immediate effect |
| Disable music | `music_enabled` + music volume, persisted |
| Disable SFX | `sfx_enabled` + SFX volume (UI sounds follow SFX or separate `ui_enabled` if needed), persisted |
| Non-hue failure/selection cues | shake/outline/icon accompany every color-coded state; blocked = outline + motion + sound |
| Motion sensitivity | keep camera micro-feedback subtle; (optional future: `reduced_motion` toggle — not required by blueprint, note only) |

Settings keys (UX defines; AGENT-1 persists — see section 12):

```text
settings.music_volume  (0..1)
settings.sfx_volume    (0..1)
settings.music_enabled (bool)
settings.sfx_enabled   (bool)
settings.haptics_enabled (bool)
settings.locale        (default = system)
```

---

## 9. Asset Contract and Directory Structure

### 9.1 Principle

Simulation/core emits **only generic fields** (`entity_type`, `item_type`,
`destination_type`, `color_key`, `footprint`, `path`, `state`, `fail_reason`) — never
asset paths (§8.1, §38). The UX layer resolves them through the **ThemeManifest**
(§39) living in the theme package. A future theme replaces the package, not core or
generic UI code.

### 9.2 Proposed directories (consistent with blueprint §7)

```text
game/
├── themes/
│   ├── base/                  # generic presentation contracts (theme-agnostic code)
│   │   ├── theme_manifest.gd      # schema + loader
│   │   ├── presentation_bindings/ # entity/item/destination visual slots
│   │   └── palette_contract.gd    # ColorKey -> color + symbol resolution
│   └── traffic/               # Traffic bindings only (no core imports of it)
│       ├── traffic_theme.gd
│       └── traffic_manifest.json  # themeId, themeVersion, presentation mapping (§39)
├── ui/                        # generic screens/HUD/widgets (theme-agnostic)
├── audio/                     # bus layout, SFX registry, player pools
├── haptics/                   # haptic service (light/warning/success)
├── localization/              # runtime i18n code
└── debug/                     # debug overlays + debug menu (excluded in Production)

content/
├── themes/
│   └── traffic/
│       ├── manifest.json
│       ├── palette/           # color_key -> {hex, symbol, cvd_safe}
│       ├── entities/vehicles/ # per entity_type silhouettes (+ orientation variants)
│       ├── items/passengers/  # per item_type tokens
│       ├── destinations/      # stations/platforms
│       ├── staging/           # bay, slots, pressure frames
│       ├── board/             # road grid, cells, obstacles
│       ├── ui/skin/           # 9-slice, icons, frames
│       ├── audio/music/
│       ├── audio/sfx/
│       └── particles/
└── localization/              # strings: pt-BR, en-US, es
```

(Engine/code under `game/`, data/assets under `content/` — matches blueprint layout.)

### 9.3 Contract rules

1. Generic UI and presentation bind by **slot name** (`entity.body`,
   `item.token`, `destination.badge`, `staging.slot`, `fx.match`), never by file path.
2. Manifest declares `themeId`, `themeVersion`, presentation mapping, audio set ids,
   particle set ids, iconography ids (§38/§39).
3. Missing required asset → **theme validation error** at content-gate time (future
   `tools/theme_validator`, M23), never a silent runtime fallback in Production.
4. Fallback for dev builds only: base placeholder silhouette + warning log.
5. Terminology: theme provides *localization key stems* only; strings themselves come
   from `content/localization/`.

---

## 10. Debug Presentation (§68)

### 10.1 Overlay inventory

| Overlay | Content | Available from |
|---|---|---|
| Entity IDs | id + state + footprint label per entity | M1 event data available |
| Occupancy grid | cell fill by occupant / free / obstacle | M1 |
| Paths | current path waypoints + direction arrows | M1/M2 |
| Blockers | why-tapped-entity-blocked highlighting | M2 |
| State hash | current logical state hash (§22) | M6 (hash) / earlier if core exposes |
| FPS | frame time + FPS graph | M3 |
| Solver recommendation | next optimal command from solver | M6+ (shows `n/a` before) |

### 10.2 Implementation plan

- `DebugOverlay` = single `CanvasLayer` under `game/debug/`, immediate-mode drawing
  (`_draw`), `_process` disabled unless a toggle is active → zero cost when off (§63).
- Toggles come from the Debug Menu (§68); each overlay independently switchable.
- Debug visuals use magenta/cyan wireframes deliberately distinct from theme palette so
  they can never be mistaken for production art.

### 10.3 Production-safety gate (impossible to expose accidentally)

Defense in depth, all four required:

1. **Export feature gate:** debug/QA export presets define custom features `env_debug`
   / `env_qa`; Production preset defines `env_production`. Debug autoloads
   (`DebugMenu`, `DebugOverlay`) are registered only when `OS.has_feature("env_debug")
   or OS.has_feature("env_qa")`.
2. **Resource exclusion:** Production export preset excludes `game/debug/**` resources.
3. **CI architecture check:** a test fails Production export if any debug scene/script
   string appears in the production export configuration or packaged manifest.
4. **Runtime smoke assertion:** production smoke test asserts no node of debug classes
   exists in the scene tree at runtime.

No hidden gesture exists in Production builds — the entry point itself is compiled out
of the environment. QA keeps debug (release-like behavior + test config, §67).

---

## 11. Milestone Checklist for AGENT-2 (presentation side only)

- **M2 (with AGENT-1 core):** event consumption layer; entity/item/destination
  visuals; select/blocked/move/match/staging/win/fail presentation; determinism
  unaffected (animation skip test).
- **M3:** Boot, Main Menu, Level HUD, Result screens, Restart/Next, debug level
  select, pause, basic tutorial cues, safe-area responsive pass on the §62 matrix.
- **M4:** full juice (tweens, particles, transitions, camera micro-feedback), audio
  implementation + persisted settings, haptics + disable toggle, input-gate caps
  verified, performance pass (60/30 FPS), animation-never-alters-simulation test.
- **M11:** booster tray/UX.
- **M14/M15:** rewarded dialog UI; privacy menu (screens built, logic via AGENT-1).
- **M10:** level select/progression screens; daily reward screen (when flagged).

---

## 12. Cross-Boundary Contracts with AGENT-1 (must be confirmed, not assumed)

| # | Contract | Needed by | Proposal |
|---|---|---|---|
| 1 | Domain event bus API + payload schemas | M2 presentation | AGENT-1 owns `puzzle/presentation_bridge/`; AGENT-2 consumes documented event names from section 2.2. Payload fields = generic vocabulary only. |
| 2 | Command result codes | M2 | presentation maps `SUCCESS/BLOCKED/INVALID/GAME_ALREADY_COMPLETE` (§12 of blueprint) |
| 3 | `fail_reason` enumeration | M3 result screens | stable string ids; UX owns localized copy per id |
| 4 | State hash exposure | debug overlay | read-only accessor from `GameState` snapshot (§22) |
| 5 | Settings persistence | M4 | AGENT-1 persists `settings` block; UX defines keys (section 8) |
| 6 | Analytics emission | tutorial/analytics events | UX triggers through AGENT-1 abstraction only — never direct SDK calls (§44) |
| 7 | Booster effects | M11 | presentation reacts to `BoosterApplied`/`UndoApplied` events only |
| 8 | Theme contract ownership | M2 | `game/themes/base/` interface co-defined; core must not import `themes/traffic` |

Any disagreement on these → ADR (blueprint §0), not silent divergence.

---

## 13. Risks and Findings

- **F1:** Repository is not yet a git repository (no `.git`) at time of writing;
  baseline commit unavailable. AGENT-1 (M0) is expected to initialize it.
- **F2:** `presentation_bridge` event contract does not exist yet (M1 pending) —
  section 2.2 event names are a *proposal* to align on, not an implemented API.
- **F3:** Ownership of `game/themes/base/` (generic contract) straddles both agents;
  needs explicit assignment before M2 (section 12, #8).
- **F4:** Blueprint does not fix a reference resolution — section 5.1 proposes
  1080×1920 as *reference only*; confirm at M3.
- **R1:** Animation locks risk violating "player regains control quickly" — mitigated
  by hard caps + auto-release in section 5.5 (P1 if exceeded).
- **R2:** Rotation-based vehicle art may hurt readability at some angles — validate
  early in M2 with a 4-rotation legibility check before mass-producing silhouettes.
- **R3:** Audio/haptic asset sourcing requires explicit approval (no packs without
  sign-off); plan budgets original/CC0-cleared material only.

---

## 14. What this document deliberately does NOT do

No gameplay code, no scenes, no assets, no `project.godot` edits, no Android/CI
changes, no AGENT-1 files touched, no `MASTER_BLUEPRINT.md` modification, no future
milestone implementation.
