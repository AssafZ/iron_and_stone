# Research: Company Map Positioning — Stacking & Overlap Resolution

**Feature**: `002-company-map-positioning`  
**Date**: 2026-03-03

---

## R-001: Offset Slot Layout Strategy for Multi-Company Nodes

**Question**: How should multiple company markers be arranged around a node centre to avoid overlap while keeping all markers individually tappable on a small mobile screen?

**Decision**: Centre-anchored radial slot table with fixed pixel offsets.

| Slot | dx  | dy  | Direction |
|------|-----|-----|-----------|
| 0    |   0 |   0 | centre    |
| 1    | +20 |   0 | right     |
| 2    | -20 |   0 | left      |
| 3    |   0 | -20 | above     |
| 4    |   0 | +20 | below     |
| 5+   | spiral continuation at Δ20 increments |

**Rationale**: A fixed 5-slot radial table keeps all slots within a 40×40 px radius of the node centre — well within the canvas area of any node. The centre-anchored, arrival-ordered approach (first company = centre) means the single-company case is visually identical to today (no regression). Radial slots of Δ20 px provide 44 px edge-to-edge distance between adjacent 36 px circles (20 px centre distance × 2 − 36 px = 4 px gap), which satisfies the 44 × 44 pt tap target requirement without visual overlap. The table is a compile-time constant in the UI layer with no domain dependency.

**Alternatives considered**:
- _Dynamic force-directed layout_: Too expensive per frame; unnecessary complexity for ≤5 entities.
- _Scrollable list overlay on node tap_: Requires an extra tap to access companies; disrupts existing two-step select-and-move UX.
- _Per-node fixed cardinal grid_: Equivalent to the chosen approach but less extensible beyond 4 slots.

---

## R-002: In-Transit vs Stationary Classification

**Question**: How does the system distinguish a company that is passing through a node from one that has stopped there, given that `CompanyOnMap.currentNode` is updated to the node in both cases?

**Decision**: Use `CompanyOnMap.destination`:
- `destination == null` → stationary (no movement orders).
- `destination.id == currentNode.id` → arrived at final destination, now stationary.
- `destination.id != currentNode.id` → in transit; `currentNode` is the most recently passed node.

**Rationale**: `destination` is already present on `CompanyOnMap` and is the authoritative movement intent field. No new field is needed. `MovementRules.advancePosition` already uses `destination` to determine whether to move; the same field can drive the collision and occupancy rules. This keeps the domain model minimal (Constitution Principle V).

**Alternatives considered**:
- _New `isStationary` boolean field on `CompanyOnMap`_: Redundant — derivable from `destination`; risks inconsistency.
- _Separate `passingThrough` set in `CheckCollisions`_: Would require the use case to carry extra state across calls; avoidable.

---

## R-003: Collision Rule — Same-Owner Pass-Through

**Question**: How should `CheckCollisions` distinguish a same-owner pass-through (no trigger) from an enemy intercept (trigger)?

**Decision**: Before the existing node-grouping loop, classify each company as stationary or in-transit using the R-002 rule. When checking a node group for opposing companies:
- In-transit companies of the **same owner** as the node's stationary occupants → ignored (no trigger).
- In-transit companies of the **opposing owner** → treated as present for collision purposes, triggering a `roadCollision`.

**Rationale**: The rule maps directly onto the spec: FR-006 says same-owner transit is unblocked; FR-007 says enemy-occupied nodes must trigger battle. The implementation is a single additional predicate in the existing collision loop — minimal change, no new use case class required (Constitution Principle V).

**Alternatives considered**:
- _New `PassThroughCheck` use case_: Unnecessary abstraction; the rule belongs in `CheckCollisions` since that is the authoritative collision detector.
- _Preventing enemy in-transit companies from sharing a node in `MoveCompany`_: Movement rules should not incorporate combat logic; concerns must stay separated (Constitution Principle II).

---

## R-004: NodeOccupancy Persistence Scope

**Question**: Should offset slot assignments be persisted to SQLite so they survive app restarts?

**Decision**: Offset slot assignments are **transient, session-only** state. They are not persisted.

**Rationale**: Slot positions are a presentation convenience — they have no effect on game rules, save files, or match outcomes. On cold start, the slot table is re-derived from the current stationary company list (sorted by company ID for determinism). This avoids adding new Drift table columns/migrations for a purely cosmetic concern (Constitution Principle V: YAGNI).

**Re-derivation rule on cold start / post-tick reconciliation**: Sort stationary companies at each node by `id` (lexicographic), assign slots 0..n in that order. This produces a stable layout across restarts.

**Alternatives considered**:
- _Persist slot order in Drift_: Adds schema complexity and a migration for zero gameplay benefit.
- _Persist `arrivalTimestamp` on CompanyOnMap_: Useful for arrival ordering but adds a field to the domain entity that has no gameplay purpose.

---

## R-005: Castle Roster — "Front Company" State

**Question**: Where should the "front company" selection state for a castle live — domain, state, or UI?

**Decision**: **UI / ephemeral state only** (a local `int frontIndex` in the castle screen widget, reset to 0 on open). It is not stored in `CompanyNotifier` or `MatchNotifier`.

**Rationale**: The spec (Assumption: "A 'front' company in a castle is a presentation concept only — it does not confer any in-game stat advantage") confirms this is a UI concern. Storing it in a Riverpod notifier would require plumbing a per-castle selection index through match state for zero gameplay benefit. A `StatefulWidget` local integer is the simplest correct solution (Constitution Principle V).

**Alternatives considered**:
- _Per-castle `frontCompanyId` in `CastleNotifier`_: Over-engineered for a pure UI preference.
- _Selected company persisted in `SharedPreferences`_: Not worth the complexity; front selection should reset between sessions.

---

## R-006: Minimum Tap Target Implementation

**Question**: What is the correct Flutter idiom for guaranteeing a 44 × 44 pt logical pixel tap target around a smaller visual widget?

**Decision**: Wrap each `CompanyMarker` usage site in a `SizedBox(width: 44, height: 44)` and ensure the `GestureDetector` inside `CompanyMarker` covers the full box. Use `HitTestBehavior.opaque` on the `GestureDetector` so the transparent padding area around the 36 × 36 visual circle still receives taps.

**Rationale**: Flutter's `GestureDetector` only intercepts touches within the widget's bounding box. Without `SizedBox` + `HitTestBehavior.opaque`, the gap between the 36 px circle edge and the 44 pt logical minimum is dead space. This pattern is idiomatic Flutter for accessible touch targets and requires no new package (Constitution Principle V).

**Alternatives considered**:
- _`Padding` widget around `GestureDetector`_: Works, but `SizedBox` with `HitTestBehavior.opaque` is more explicit and testable.
- _Flutter `MaterialTapTargetSize`_: Only applies to Material widgets (`ElevatedButton`, etc.); not available on custom `GestureDetector`.
