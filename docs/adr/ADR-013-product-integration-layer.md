# ADR-013: Product Integration Layer

Status: Accepted (2026-09-26)

## Context

Blueprint §8.1 requires the reusable core to be theme-independent, and
`docs/PRESENTATION_BRIDGE.md` requires presentation to consume simulation
events without deciding correctness. The first product (Traffic) needs
product vocabulary (vehicles, passengers, stations, holding area) *somewhere*,
plus a concrete wiring between generic mechanics and the Traffic presentation
contracts published by AGENT-2 (`game/themes/traffic/**`,
`docs/TRAFFIC_PRESENTATION.md`).

Three forces conflict if handled naively:

1. The core must never know product words (enforced by
   `game/tests/architecture_test.gd`).
2. Presentation must not import `game/core/**` or `game/puzzle/**`
   (enforced by `game/tests/presentation_boundary_test.gd`).
3. A product still needs to map generic concepts to product concepts and to
   translate domain events into presentation calls/DTOs.

## Decision

Introduce a dedicated **product integration layer**:

```text
game/integration/traffic/**        OWNER: AGENT-1
```

It is the only code allowed to know both sides:

```text
generic core + generic puzzle mechanics
        ↓
product composition (Traffic)        game/integration/traffic/**
        ↓
presentation adapter (Traffic)       game/integration/traffic/**
        ↓
Traffic presentation                 game/themes/traffic/**  (AGENT-2)
```

Rules:

- `game/core/**`, `game/puzzle/**`, `game/themes/base/**` stay free of product
  vocabulary and must not reference `res://integration/**`.
- `game/integration/traffic/**` may use product vocabulary and may import
  generic layers *and* the Traffic presentation contracts.
- Product composition prefers **mapping/composition over subclassing**: generic
  `Entity` becomes a vehicle, `Item` a passenger, `Destination` a station,
  `StagingArea` the holding area; no duplicated rule logic.
- The adapter never decides legality, never changes matching/staging rules,
  never grants rewards and never waits for animation. It translates events and
  projects state into view data.
- Presentation components continue to receive data; they do not import core or
  puzzle. Training M3 screens may call the adapter through the game layer.

## Consequences

- Automated guards enforce the direction: generic layers cannot depend on the
  integration layer, and the integration layer is verified to be the place
  that carries product terminology.
- A second product (airport, warehouse, ... per blueprint §1.2) adds
  `game/integration/<product>/**` plus its own theme package without touching
  the generic core.
- Generic mechanics stay testable in isolation (no product fixtures needed),
  and product behaviour is tested through the integration layer.
- Contract changes on the presentation side are absorbed by the adapter's
  mapping table (`TrafficEventMap`), keeping the generic event catalog stable.
