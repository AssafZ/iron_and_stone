# Implementation Plan: Company Map Positioning — Stacking & Overlap Resolution

**Branch**: `002-company-map-positioning` | **Date**: 2026-03-03 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/002-company-map-positioning/spec.md`

## Summary

Companies at shared map nodes (road junctions and castles) currently stack on top of each other, making all but the topmost marker untappable. This plan resolves the problem across three complementary mechanisms:

1. **Node occupancy offset slots** (domain + UI) — stationary companies at a road junction node are assigned arrival-ordered offset positions, compacting inward when any company departs, so all markers remain individually tappable.
2. **Castle company roster** (UI) — tapping a player-owned castle opens a scrollable roster listing every garrisoned company individually; tapping an enemy/neutral castle shows a read-only soldier-count summary.
3. **Same-owner pass-through** (domain) — a company whose route crosses a node occupied only by friendly companies passes through without stopping; a company encountering an enemy-occupied node triggers a battle as before.

## Technical Context

**Language/Version**: Dart 3.x (sound null-safety)  
**Framework**: Flutter 3.x  
**Primary Dependencies**: `flutter_riverpod` (state), `drift` (SQLite persistence), `flutter_test` + `integration_test` + `golden_toolkit` (testing)  
**Storage**: Drift/SQLite for match state (`lib/data/drift/`) — offset slot assignments are transient UI state (not persisted between sessions)  
**Testing**: `flutter_test` for domain unit tests and widget tests; `integration_test` for end-to-end flows; `golden_toolkit` for visual regression on map rendering  
**Target Platform**: Android 8.0+ (API 26+), iOS 15+  
**Performance Goals**: 60 fps; game-loop tick ≤ 16 ms; offset computation is O(n) where n ≤ 5 companies per node  
**Constraints**: No new dependencies; minimum 44 × 44 pt tap target per marker; `RepaintBoundary` preserved at company marker boundaries  
**Project Type**: Mobile game (Flutter, single-player)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Domain Model First** | ✅ PASS | Pass-through logic and occupancy rules are pure-Dart domain changes (`check_collisions.dart`, new `node_occupancy.dart`). UI offset computation derives from domain state — no game rules in widgets. |
| **II. Layer Separation** | ✅ PASS | Domain layer: `NodeOccupancy` value object + `CheckCollisions` update. State layer: `CompanyNotifier` / `MatchNotifier` carry occupancy data. UI layer: `CompanyMarker` reads offset from state only. Castle roster UI lives in `castle_screen.dart` (presentation). |
| **III. Test-First for Game Rules** | ✅ PASS — GATE ENFORCED | All domain changes (pass-through collision rule, occupancy slot assignment, compaction) MUST have failing unit tests written and approved BEFORE implementation. Widget tests for roster and offset markers MUST be written before the widgets are built. |
| **IV. Performance & Frame Budget** | ✅ PASS | Offset calculation is O(n); `RepaintBoundary` already present at `CompanyMarker`. No additional per-frame computation beyond an array index lookup. DevTools screenshot required before PR merge. |
| **V. Simplicity & Incremental Complexity** | ✅ PASS | No new packages. `NodeOccupancy` is the minimum abstraction needed; offset positions are computed in the UI layer as a pure function of the ordered list. Castle roster reuses the existing `castle_screen.dart` structure. |

## Project Structure

### Documentation (this feature)

```text
specs/002-company-map-positioning/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code — files created or modified by this feature

```text
lib/
├── domain/
│   ├── value_objects/
│   │   └── node_occupancy.dart          [NEW] Ordered slot assignment + compaction
│   ├── use_cases/
│   │   └── check_collisions.dart        [MODIFY] Pass-through owner-scoped rule (FR-006/007)
│   └── entities/
│       └── (no changes — CompanyOnMap already has ownership + destination)
├── state/
│   └── company_notifier.dart            [MODIFY] Compute + expose NodeOccupancy per-node
├── ui/
│   ├── screens/
│   │   ├── map_screen.dart              [MODIFY] Use occupancy offsets when placing CompanyMarker Positioned widgets; enemy castle read-only summary
│   │   └── castle_screen.dart           [MODIFY] Company roster UI for player castles; read-only summary for enemy/neutral
│   └── widgets/
│       └── company_marker.dart          [MODIFY] Enforce 44 × 44 pt minimum tap target; in-transit visual distinction

test/
├── domain/
│   ├── value_objects/
│   │   └── node_occupancy_test.dart     [NEW] TDD: slot assignment, compaction, overflow
│   └── use_cases/
│       └── check_collisions_test.dart   [MODIFY] TDD: same-owner pass-through, enemy intercept
├── widget/
│   ├── map_screen_offset_test.dart      [NEW] Widget test: multiple companies at same node are all tappable
│   └── castle_screen_roster_test.dart   [NEW] Widget test: roster lists all companies; enemy summary shows count
└── golden/
    └── map_node_offset_golden_test.dart [NEW] Golden: 2, 3, 5 companies at same node with correct offsets
```

---

## Phase 0: Research

See [research.md](./research.md).

---

## Phase 1: Design

### 1. Domain Value Object — `NodeOccupancy`

**File**: `lib/domain/value_objects/node_occupancy.dart`

`NodeOccupancy` is a pure-Dart immutable value object that owns the arrival-ordered list of company IDs at a single node and computes their offset slot index.

```
NodeOccupancy {
  nodeId: String
  orderedIds: List<String>   // arrival order; index 0 = centre slot
}

+ withArrival(id) → NodeOccupancy   // appends id; no-op if already present
+ withDeparture(id) → NodeOccupancy // removes id; remaining IDs compact
+ slotIndex(id) → int?              // index in orderedIds, or null if absent
+ contains(id) → bool
}
```

**Offset geometry** (UI layer, not domain): The UI derives an `(dx, dy)` pixel displacement from the slot index using a fixed slot table. The table is defined in `map_screen.dart` as a compile-time constant — no domain dependency:

```
Slot 0 → (  0,   0)   centre
Slot 1 → (+20,   0)   right
Slot 2 → (-20,   0)   left
Slot 3 → (  0, -20)   above
Slot 4 → (  0, +20)   below
Slot 5+ → spiral continuation at Δ20 increments
```

Each `CompanyMarker` is wrapped in a `SizedBox(width: 44, height: 44)` with `GestureDetector` covering the full box, ensuring the 44 × 44 pt minimum tap target (FR-001) regardless of the 36 × 36 visual circle size.

### 2. Domain Rule Change — `CheckCollisions`

**File**: `lib/domain/use_cases/check_collisions.dart`

**Current behaviour** (FR-014): Any two opposing companies on the same node → `roadCollision` trigger.

**New behaviour** (FR-006 / FR-007):
- A company at a node with `destination != null` AND `destination.id != node.id` is **in transit** — it should not be treated as stationary occupying that node for collision purposes.
- **Same-owner pass-through**: if a company in transit passes through a node occupied only by friendly companies → **no trigger**.
- **Enemy intercept**: if a company in transit passes through a node where at least one opposing company is stationary OR also in transit at the same node → `roadCollision` trigger as before.

The determination of "in transit vs stationary" uses `CompanyOnMap.destination`:
- `destination == null` OR `destination.id == currentNode.id` → **stationary**
- `destination != null` AND `destination.id != currentNode.id` → **in transit**

This is a pure-Dart rule change with zero Flutter imports.

### 3. State Layer — `NodeOccupancy` map in `CompanyNotifier` / `MatchNotifier`

`NodeOccupancy` assignments are **transient UI state** — not persisted. They are maintained in `CompanyNotifier` as a `Map<String, NodeOccupancy>` keyed by node ID.

**Lifecycle**:
- A company becomes stationary (`destination` set to null or company arrives): call `occupancy[nodeId]!.withArrival(co.id)`.
- A company departs (destination assigned, or company destroyed): call `occupancy[nodeId]!.withDeparture(co.id)`.
- After a tick, `MatchNotifier` reconciles the current stationary company set against occupancy — any company no longer stationary is removed from its slot; any newly stationary company that lacks a slot is inserted.

The `CompanyListState` gains a `Map<String, NodeOccupancy> nodeOccupancy` field (defaults to `{}`). The `companyNotifierProvider` state is the single source of truth for slot assignments.

### 4. Presentation Layer — Map Screen Offset Positioning

**File**: `lib/ui/screens/map_screen.dart`

In `_buildMap`, the company markers loop changes from:

```
...companies.map((co) {
  final (cx, cy) = _companyVisualPos(co, matchState);
  return Positioned(left: cx - 18, top: cy - 18, child: CompanyMarker(...));
})
```

To:

```
...companies.map((co) {
  final (cx, cy) = _companyVisualPos(co, matchState);
  // For stationary companies, apply the offset slot displacement.
  final (ox, oy) = _offsetForCompany(co, companyState.nodeOccupancy);
  return Positioned(
    left: cx + ox - 22,   // centred on 44×44 box
    top:  cy + oy - 22,
    child: SizedBox(
      width: 44, height: 44,
      child: CompanyMarker(...),
    ),
  );
})
```

`_offsetForCompany` is a private pure function that looks up the company's slot index in `nodeOccupancy`, then maps slot index → `(dx, dy)` using the constant slot table. In-transit companies (non-null destination) always get `(0, 0)` offset and render on their interpolated path position.

### 5. Presentation Layer — Castle Screen Roster & Enemy Summary

**File**: `lib/ui/screens/castle_screen.dart`

**Player-owned castle** (existing `CastleScreen` entry point — navigated from `_showCastleSheet`):
- The existing `_CompaniesCard` widget already renders a list of all companies at the castle node. It needs to be updated to:
  - Show only **stationary** companies (those with `destination == null`) in the "garrison" section.
  - Make each row individually tappable to select that company as the "front" company (navigates back to map with that company selected, or opens compose/deploy sheet directly).
  - Label the currently selected front company visually (e.g., gold border).

**Enemy / neutral castle** (new path in `_showCastleSheet` in `map_screen.dart`):
- Currently `_showCastleSheet` already branches on `isPlayerCastle`. The non-player branch currently shows only the castle name and company count.
- Update to explicitly compute `totalDefenders` = sum of `totalSoldiers.value` for all companies at that node, and display: `"Defenders: $totalDefenders soldiers"`.

### 6. `CompanyMarker` — Minimum Tap Target

**File**: `lib/ui/widgets/company_marker.dart`

Wrap the existing `RepaintBoundary > GestureDetector > _buildMarker()` in a `SizedBox(width: 44, height: 44)` with the `GestureDetector` covering the full box. The 36 × 36 visual circle is centred within the 44 × 44 touch area using `Center` or symmetric padding.

---

## Complexity Tracking

*No constitution violations — no entries required.*

---

## Constitution Check (Post-Design)

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Domain Model First** | ✅ PASS | `NodeOccupancy` is pure Dart. Pass-through rule is in `check_collisions.dart`. No game logic in widgets. |
| **II. Layer Separation** | ✅ PASS | Slot geometry (pixel offsets) is UI-only constant table. Domain owns only ordered IDs. State layer owns the `Map<nodeId, NodeOccupancy>`. UI reads and renders. |
| **III. Test-First** | ✅ PASS — RED TESTS FIRST | `node_occupancy_test.dart` and updated `check_collisions_test.dart` must be written and reviewed before any implementation. Widget tests before widget changes. |
| **IV. Performance** | ✅ PASS | Slot table lookup is O(1). No per-frame computation added. `RepaintBoundary` retained. DevTools screenshot required at PR. |
| **V. Simplicity** | ✅ PASS | Zero new packages. `NodeOccupancy` has 4 methods. Slot table is a 5-element list constant. No speculative abstractions. |
