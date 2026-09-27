# Level Schema (v1)

> **Owner:** AGENT-1 (content engine)
> **Status:** M5 content platform — the official source of truth for levels
> **Authority:** `docs/MASTER_BLUEPRINT.md`; ADR-009 (versioned contracts), ADR-013

This document defines the formal, versioned level format, its loader/validator/
migration pipeline, the content-pack structure, and the authoring rules. It
replaces the M3 hardcoded catalogue; the ten Project Traffic levels now live as
data files under `game/content/levels/traffic/pack_001/`.

## 1. Where levels live

```text
game/levels/definitions/level_definition.gd    LevelDefinition value object (schema v1)
game/levels/loader/level_loader.gd             read -> parse -> migrate -> build -> validate
game/levels/validator/level_validator.gd       static validation, structured error codes
game/levels/migrations/level_migrator.gd       explicit vN -> vN+1 migration chain
game/levels/packs/level_pack.gd                pack manifest parsing

game/content/levels/traffic/pack_001/          official Project Traffic content
    manifest.json
    traffic_m3_l01_first_roll.json
    ... (ten levels)
```

`game/levels/**` is **generic**: it contains no product vocabulary
(entity/item/destination/queue/path/staging/objective only) and never imports
the product integration or content layers. Architecture guards enforce this
(`game/tests/architecture_test.gd`).

## 2. Serialized schema v1

External files use camelCase. `LevelDefinition.to_dictionary()` emits exactly
this shape, so a parsed level round-trips to identical bytes.

```json
{
  "schemaVersion": 1,
  "levelId": "traffic_m3_l01_first_roll",
  "revision": 1,
  "seed": 11,
  "themeId": "traffic",

  "board": { "width": 4, "height": 2 },

  "paths": [
    { "id": "route_v1", "cells": [ {"x":0,"y":0}, {"x":1,"y":0}, {"x":2,"y":0} ] }
  ],

  "entities": [
    { "id": "v1", "type": "compact", "colorKey": "COLOR_A", "capacity": 1,
      "position": {"x":0,"y":0}, "footprint": {"width":1,"height":1},
      "pathId": "route_v1", "destinationId": "station_a" }
  ],

  "items": [
    { "id": "p_a1", "type": "standard", "colorKey": "COLOR_A",
      "destinationId": "station_a" }
  ],

  "queues": [ { "id": "q_a", "itemIds": ["p_a1"] } ],

  "destinations": [
    { "id": "station_a", "type": "default", "acceptedKeys": ["COLOR_A"],
      "capacity": 1, "queueId": "q_a",
      "position": {"x":3,"y":0}, "footprint": {"width":1,"height":1} }
  ],

  "staging": { "slots": 4 },

  "objectives": [ { "id": "clear_all", "type": "CLEAR_ALL", "mandatory": true } ],

  "allowedBoosters": [],
  "difficultyTarget": null,
  "tags": []
}
```

### Required top-level fields

`schemaVersion`, `levelId`, `revision`, `seed`, `themeId`, `board`, `entities`,
`items`, `queues`, `destinations`, `paths`, `staging`, `objectives`.

### Optional / defaulted

| Field | Default | Notes |
|---|---|---|
| `allowedBoosters` | `[]` | metadata only in M5; recognised ids are `UNDO`, `EXTRA_SLOT`, `SHUFFLE` |
| `difficultyTarget` | `null` | reserved for the M6 generation engine |
| `tags` | `[]` | free-form string labels |

There are **no** script paths or custom-code hooks in a level file.

### Field semantics

- `levelId` is stable and is the progression key (`M3ProgressStore` persists it).
- `revision` is `>= 1`; it bumps when the same `levelId` is re-authored.
- `seed` seeds the deterministic RNG; M3/M4 gameplay consumes no randomness, so
  it is preserved for determinism/replay compatibility.
- `themeId` selects the product adapter. The only value in M5 is `traffic`.
- `board` is in cells.
- `entities[].position` must equal the **origin cell** of `entities[].pathId`.
- `items[].destinationId` and `entities[].destinationId` must reference a
  declared destination; an item must be owned by exactly one queue.
- `queues[].itemIds` order is FIFO order and is significant.
- `paths[].cells` order is significant; cells must be contiguous (4-neighbour)
  and unique within a path.

## 3. Loader

`LevelLoader`:

```gdscript
LevelLoader.load_from_json_text(text, source_path="") -> LevelLoadResult
LevelLoader.load_from_file(path) -> LevelLoadResult
LevelLoader.load_from_dictionary(data, source_path="") -> LevelLoadResult
```

Pipeline: read → parse JSON → require Dictionary → read `schemaVersion` →
migrate when the version is older → `LevelDefinition.from_dictionary` →
`LevelValidator.validate` → structured `LevelLoadResult`.

`LevelLoadResult.status`:

```text
OK
FILE_NOT_FOUND
IO_ERROR
INVALID_JSON
NOT_A_DICTIONARY
UNSUPPORTED_SCHEMA_VERSION
MIGRATION_FAILED
VALIDATION_FAILED
```

Errors are never swallowed; `errors` carries machine-readable codes and
`definition` is non-null only for `OK`. The loader never writes or rewrites the
source file.

## 4. Validator

`LevelValidator.validate(definition) -> PackedStringArray` (empty = valid). The
validator is **static**: it never solves the puzzle, so a structurally valid but
logically impossible level passes (see `docs/SOLVER.md`).

Error codes (contexts appended after `:`):

```text
MISSING_DEFINITION
UNSUPPORTED_SCHEMA_VERSION
INVALID_LEVEL_ID
INVALID_REVISION
INVALID_THEME_ID
INVALID_BOARD
INVALID_STAGING_SLOTS
DUPLICATE_ID:<id>
INVALID_PATH:<pathId>:too_short
INVALID_PATH:<pathId>:duplicate_cell:<index>
INVALID_PATH:<pathId>:non_contiguous:<index>
OUT_OF_BOUNDS:path:<pathId>:<index>
INVALID_POSITION:<id>
OUT_OF_BOUNDS:entity:<id>
OUT_OF_BOUNDS:destination:<id>
INVALID_FOOTPRINT:<id>
INVALID_CAPACITY:<id>
UNKNOWN_PATH:<pathId>
ROUTE_START_MISMATCH:<entityId>
UNKNOWN_DESTINATION:<destinationId>
ENTITY_OVERLAP:<first>:<other>
MISSING_COLOR_KEY:<itemId>
UNKNOWN_ITEM:<itemId>
DUPLICATE_ITEM_OWNERSHIP:<itemId>
UNREFERENCED_ITEM:<itemId>
UNKNOWN_QUEUE:<queueId>
INVALID_ACCEPTED_KEYS:<destinationId>
INVALID_OBJECTIVE:<id>:unknown_type
INVALID_BOOSTER:<name>
```

## 5. Migration policy

`LevelMigrator` upgrades payloads one version at a time through an explicit
registry (`vN -> vN+1`). Rules:

- migration is **explicit** by version; unknown transitions are refused;
- deterministic: identical input → identical output bytes (canonical JSON);
- never silently reinterprets a field;
- never downgrades;
- a chain step may not be skipped: an unregistered version fails rather than
  guessing.

Current official schema is **v1**. The registry is `MIGRATION_TARGETS` and the
generic legacy-shape conversion is
`LevelMigrator.from_legacy_dictionary(generic_legacy_dictionary)`. The
Traffic-specific legacy conversion (the pre-M5 `vehicles/passengers/stations`
dictionary) lives with the product adapter in
`game/integration/traffic/levels/traffic_level_definition_adapter.gd`
(`from_traffic_definition`).

## 6. Content pack

```text
game/content/levels/traffic/pack_001/manifest.json
```

```json
{
  "packId": "traffic_pack_001",
  "contentVersion": 1,
  "minGameVersion": 1,
  "levels": [
    "traffic_m3_l01_first_roll.json",
    "traffic_m3_l02_two_lanes.json",
    "..."
  ]
}
```

- `levels` order defines progression order and is preserved exactly.
- The manifest is the single source of truth for membership and order.
- Remote activation is out of scope in M5 (M13 owns Remote Config).

## 7. Example: a complete valid level

The smallest ten-cell starter (this is L01's real shape; **not** a fictional
snippet):

```json
{
  "schemaVersion": 1,
  "levelId": "traffic_m3_l01_first_roll",
  "revision": 1,
  "seed": 11,
  "themeId": "traffic",
  "board": { "width": 4, "height": 2 },
  "paths": [
    { "id": "route_v1", "cells": [ {"x":0,"y":0}, {"x":1,"y":0}, {"x":2,"y":0} ] }
  ],
  "entities": [
    { "id": "v1", "type": "compact", "colorKey": "COLOR_A", "capacity": 1,
      "position": {"x":0,"y":0}, "footprint": {"width":1,"height":1},
      "pathId": "route_v1", "destinationId": "station_a" }
  ],
  "items": [
    { "id": "p_a1", "type": "standard", "colorKey": "COLOR_A", "destinationId": "station_a" }
  ],
  "queues": [ { "id": "q_a", "itemIds": ["p_a1"] } ],
  "destinations": [
    { "id": "station_a", "type": "default", "acceptedKeys": ["COLOR_A"],
      "capacity": 1, "queueId": "q_a",
      "position": {"x":3,"y":0}, "footprint": {"width":1,"height":1} }
  ],
  "staging": { "slots": 4 },
  "objectives": [ { "id": "clear_all", "type": "CLEAR_ALL", "mandatory": true } ],
  "allowedBoosters": [],
  "difficultyTarget": null,
  "tags": []
}
```

Product mapping (Traffic): Entity → vehicle, Item → passenger, Destination →
station. The mapping is implemented only in
`TrafficLevelDefinitionAdapter`; the schema itself stays generic.

## 8. Authoring rules

1. Author against this schema; never add custom code or script paths.
2. Every item must be owned by exactly one queue, and every entity must
   reference a declared path and destination.
3. An entity's `position` must be the origin cell of its path.
4. Paths are contiguous and non-self-intersecting; queue order is FIFO and is
   significant.
5. Keep `levelId` stable once shipped — it is the progression key; bump
   `revision` for re-authoring.
6. A new level must pass `LevelValidator` **and** be proven completable by the
   solver (`scripts/solve_level.ps1 <levelId>`) before shipping.
7. Run `TrafficLevelCatalogue.validate_all()` / the test suite after editing the
   pack.

## 9. Tests

```text
game/tests/level_schema_test.gd              parse / roundtrip / required / defaults
game/tests/level_loader_test.gd              ok / malformed / missing / migration / validation
game/tests/level_validator_test.gd           one check per error family
game/tests/level_migration_test.gd           deterministic / explicit chain / legacy
game/tests/traffic_content_conversion_test.gd official content matches the legacy semantics
```
