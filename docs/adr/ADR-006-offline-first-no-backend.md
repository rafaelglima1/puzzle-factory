# ADR-006: Offline-first, no custom backend

Status: Accepted (2026-09-26)

## Context

Blueprint §66 requires full offline gameplay (launch, play, progress,
save, settings) and §91 prohibits a custom backend by default. A backend
would add cost, security burden and operational complexity for a casual
puzzle game whose core loop needs no authoritative server (blueprint
§2: low operational cost, offline-first).

## Decision

- Gameplay, saves, progression and levels are fully local/offline.
- No custom backend services, no PostgreSQL/Redis/web services, no
  mandatory accounts (blueprint §102).
- External services (Firebase analytics/crash/remote config, AdMob, IAP)
  are optional integrations that must degrade gracefully when
  unavailable (blueprint §66) and are introduced only in their
  milestones (M12-M14).
- A backend may only be reconsidered via a new ADR driven by a validated
  feature that truly requires it (blueprint §91).

## Consequences

- Near-zero operating cost for the core product; simple architecture.
- Device-clock manipulation cannot be fully prevented for offline daily
  rewards — accepted and documented in the blueprint (§36).
- Cloud save is explicitly out of scope for 1.0 (blueprint §43).
