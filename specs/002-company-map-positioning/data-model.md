# Data Model: Company Map Positioning

**Feature**: `002-company-map-positioning`  
**Date**: 2026-03-03

---

## Overview

This document describes every new or modified domain/state data type introduced by the feature, their invariants, and their lifecycle. No database schema changes are made (all new state is session-transient).

---

## 1. New: `NodeOccupancy` (value object)

**File**: `lib/domain/value_objects/node_occupancy.dart`  
**Layer**: Domain (pure Dart, no Flutter dependency)

### Purpose

Tracks which companies are currently **stationary** at a given node, and in which order they arrived. The ordered list drives the slot-index computation used by the UI to position markers without overlap.

### Fields

| Field       | Type            | Description                                                                    |
|-------------|-----------------|--------------------------------------------------------------------------------|
| `nodeId`    | `String`        | ID of the `MapNode` this occupancy record belongs to.                          |
| `orderedIds`| `List<String>`  | Company IDs in arrival order (index 0 = first arrival = centre slot). Immutable copy stored. |

### Invariants

- `orderedIds` contains no duplicates.
- `orderedIds` contains only IDs of **stationary** companies (companies whose `destination == null` or `destination.id == currentNode.id`).
- `orderedIds[0]` always occupies slot 0 (centre) on the node.
- The list compacts on departure: if the company at index `k` departs, companies at indices `k+1..n` shift down by 1, preserving relative arrival order (no gaps, no re-centering of inner companies).

### Constructor

```dart
const NodeOccupancy({
  required String nodeId,
  required List<String> orderedIds,  // defensive copy taken
});
```

### Methods

| Method                              | Returns          | Description                                                                                          |
|-------------------------------------|------------------|------------------------------------------------------------------------------------------------------|
| `withArrival(String id)`            | `NodeOccupancy`  | Returns a new `NodeOccupancy` with `id` appended at the end of `orderedIds`. No-op if already present. |
| `withDeparture(String id)`          | `NodeOccupancy`  | Returns a new `NodeOccupancy` with `id` removed and remaining IDs compacted (order preserved).       |
| `slotIndex(String id)`              | `int?`           | Returns the slot index (0-based) for `id`, or `null` if not present.                                 |
| `contains(String id)`               | `bool`           | Returns `true` if `id` is in `orderedIds`.                                                           |

### Cold-Start / Post-Tick Derivation

When the occupancy map is rebuilt from scratch (app restart, or after a game tick), stationary companies at each node are sorted by `id` (lexicographic) to produce a deterministic `orderedIds` list. This ensures stable rendering across restarts without persisting arrival order.

```dart
// Derivation helper (lives in state layer, not domain):
NodeOccupancy _deriveOccupancy(String nodeId, List<CompanyOnMap> allCompanies) {
  final stationary = allCompanies
      .where((c) => c.currentNode.id == nodeId && _isStationary(c))
      .map((c) => c.id)
      .toList()
    ..sort();
  return NodeOccupancy(nodeId: nodeId, orderedIds: stationary);
}

bool _isStationary(CompanyOnMap c) =>
    c.destination == null || c.destination!.id == c.currentNode.id;
```

### Slot Index → Visual Offset Mapping

The slot-index-to-pixel-offset table lives **in the UI layer only** (not in the domain value object):

| Slot | dx (logical px) | dy (logical px) |
|------|-----------------|-----------------|
| 0    |  0              |  0              |
| 1    | +20             |  0              |
| 2    | −20             |  0              |
| 3    |  0              | −20             |
| 4    |  0              | +20             |
| 5+   | spiral at Δ20   |                 |

---

## 2. Modified: `CompanyListState` (state layer)

**File**: `lib/state/company_notifier.dart`  
**Layer**: State (Riverpod)

### Existing Fields (unchanged)

| Field               | Type                 | Description                             |
|---------------------|----------------------|-----------------------------------------|
| `companies`         | `List<CompanyOnMap>` | Authoritative list of all companies.    |
| `selectedCompanyId` | `String?`            | ID of the currently selected company.  |

### New Field

| Field           | Type                          | Description                                                                                                              |
|-----------------|-------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `nodeOccupancy` | `Map<String, NodeOccupancy>`  | Maps node ID → occupancy record. Only contains entries for nodes that have ≥1 stationary company. Transient, not persisted. |

### Lifecycle Events

| Event                        | Effect on `nodeOccupancy`                                                                                                   |
|------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `deployCompany(nodeId, ...)`  | `withArrival(companyId)` on the target node's `NodeOccupancy`.                                                              |
| `setDestination(id, dest)`   | If company was stationary: `withDeparture(companyId)` on `currentNode`'s occupancy. Remove entry if `orderedIds` becomes empty. |
| `_onTickReconcile(newList)`  | Full re-derivation: group newly-stationary companies by `currentNode`, sort by id, rebuild all occupancy entries.            |
| `mergeCompanies(a, b)`       | `withDeparture(b)` (absorbed company departs); `withArrival(a)` (merged company re-arrives at same node, to front if was centre). |
| `splitCompany(id, ...)`      | `withDeparture(id)` (original departs); two `withArrival` calls for the two new company IDs at the same node.               |

### `copyWith` Extension

```dart
CompanyListState copyWith({
  List<CompanyOnMap>? companies,
  String? Function()? selectedCompanyId,
  Map<String, NodeOccupancy>? nodeOccupancy,
});
```

---

## 3. Unchanged: `CompanyOnMap` — In-Transit Semantics

**File**: `lib/domain/use_cases/check_collisions.dart`  
**Layer**: Domain

No fields are added. The existing `destination` field is the sole discriminator for in-transit vs stationary classification.

### Stationary Classification (formal definition)

```
isStationary(c) ⟺ c.destination == null ∨ c.destination.id == c.currentNode.id
```

### Pass-Through Classification (used by `CheckCollisions`)

```
isInTransit(c) ⟺ ¬isStationary(c)
             ⟺ c.destination != null ∧ c.destination.id ≠ c.currentNode.id
```

A company is **in transit through** a node when `isInTransit(c)` and `c.currentNode.id == targetNode.id`.

---

## 4. UI-Only: Slot Offset Table

**File**: `lib/ui/screens/map_screen.dart`  
**Layer**: UI (Flutter, no domain/state dependency)

```dart
/// Pixel offsets for each occupancy slot index relative to the node centre.
/// Slot 0 = centre (first arrival). Subsequent slots radiate outward.
const List<(double dx, double dy)> _kSlotOffsets = [
  (0,   0),   // slot 0 — centre
  (20,  0),   // slot 1 — right
  (-20, 0),   // slot 2 — left
  (0,  -20),  // slot 3 — above
  (0,   20),  // slot 4 — below
  // slot 5+: add as needed; spiral at Δ20 increments
];
```

This constant is a compile-time literal; the domain value object `NodeOccupancy` has no knowledge of it.

---

## 5. Unchanged: `CastleNotifier`, `MatchNotifier`, `BattleTrigger`

- `CastleNotifier` — no changes. Castle occupancy (which companies are garrisoned) is derived from `companies` list in `CompanyNotifier`.
- `MatchNotifier` — no changes. Tick orchestration is unaffected; `nodeOccupancy` reconciliation happens inside `CompanyNotifier._onTickReconcile`.
- `BattleTrigger` / `BattleTriggerKind` — no new enum values. `roadCollision` is reused for enemy-intercept-during-transit.

---

## 6. Not Persisted

The following are **not** added to any Drift table or `SharedPreferences` key:

| Item                        | Reason                                             |
|-----------------------------|----------------------------------------------------|
| `NodeOccupancy.orderedIds`  | Cosmetic only; re-derived deterministically on load. |
| Castle "front company" index| UI ephemeral state; reset to 0 on each open.       |
