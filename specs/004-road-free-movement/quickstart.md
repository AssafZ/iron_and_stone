# Quickstart: Road-Free Company Movement & Positioning

**Branch**: `004-road-free-movement` | **Date**: 2026-03-07  
**Audience**: Developer picking up this feature. Read `research.md` and `data-model.md` first.

---

## What You're Building

Companies can now stop at *any point* on a road segment — not only at named junctions or castles. A player taps anywhere on a visible road line; the game resolves the tap to the nearest valid road coordinate; the company marches there and stops. Mid-road companies are fully playable: selectable, can march onward, collide with enemies, split, and merge. Castles are always on roads (enforced at map-build time). Two nearby friendly companies can initiate a proximity merge that auto-marches the initiator to the target.

---

## Architecture at a Glance

```
UI tap (canvas coords)
      │
      ▼
MapScreen._hitTestRoad()          ← converts pixel → RoadPosition or MapNode
      │                              (20 px road snap, 24 px node snap)
      ▼
CompanyNotifier.setMidRoadDestination()  or  .setDestination()
      │
      ▼
MoveCompany.setMidRoadDestination()      ← validates segment exists
      │
      ▼
CompanyOnMap.midRoadDestination = RoadPosition(...)
      │
   [each tick]
      ▼
MovementRules.advancePosition()          ← stops at midRoadDest.progress
      │                                    reachedMidRoad = true → clear dest
      ▼
CheckCollisions.check()                  ← node pass + NEW segment pass
      │                                    emits BattleTrigger(midRoadProgress?)
      ▼
TickMatch._resolveProximityMerges()      ← update/cancel/execute ProximityMergeIntent
      │
      ▼
MapScreen._companyVisualPos()            ← unchanged; already interpolates progress
      │
      ▼
_buildSlotMap() / _offsetForCompany()    ← extended: composite key for mid-road groups
```

---

## Step-by-Step Implementation Order

Follow TDD strictly (Red → Green → Refactor for each step).

### Step 1 — `RoadPosition` value object
**File**: `lib/domain/value_objects/road_position.dart`  
**Test first**: `test/domain/value_objects/road_position_test.dart`

```dart
final class RoadPosition {
  final String currentNodeId;
  final double progress;   // [0.0, 1.0)
  final String nextNodeId;

  RoadPosition({required this.currentNodeId, required this.progress, required this.nextNodeId}) {
    if (progress < 0.0 || progress >= 1.0) throw ArgumentError('progress must be in [0.0, 1.0)');
    if (currentNodeId == nextNodeId) throw ArgumentError('currentNodeId must differ from nextNodeId');
  }

  @override bool operator ==(Object other) => ...
  @override int get hashCode => ...
}
```

Tests to write:
- `progress = 0.0` is valid (at named node, but segment identity is explicit).
- `progress = 0.999` is valid.
- `progress = 1.0` throws `ArgumentError`.
- `progress = -0.1` throws `ArgumentError`.
- Same currentNodeId and nextNodeId throws `ArgumentError`.

---

### Step 2 — `RoadEdge.id`
**File**: `lib/domain/entities/road_edge.dart`  
**Test first**: `test/domain/entities/road_edge_test.dart` (modify existing)

Add: `final String id;` derived as `"${from.id}__${to.id}"` in the constructor.  
No call-site changes (existing fixtures don't pass `id`; derive it automatically).

---

### Step 3 — `GameMap` castle validation
**File**: `lib/domain/entities/game_map.dart`  
**Test first**: `test/domain/entities/game_map_test.dart`

Tests to write:
- Map with all castles connected → builds without error.
- Map with a castle node having no edges → throws `ArgumentError`.
- `GameMapFixture.build()` succeeds (regression guard).

---

### Step 4 — `GameMap.roadDistance`
**File**: `lib/domain/entities/game_map.dart`  
**Test first**: `test/domain/entities/game_map_test.dart` (add to Step 3 test file)

Tests to write:
- Same segment, `from.progress = 0.2`, `to.progress = 0.7`, edge length 100 → distance = 50.0.
- Cross-segment distance uses BFS path.
- Reverse direction (from.progress > to.progress on same segment) uses absolute difference.

---

### Step 5 — `CompanyOnMap` extended fields
**File**: `lib/domain/use_cases/check_collisions.dart`  
**Test first**: existing tests must still pass (no regression).

Add `midRoadDestination: RoadPosition?` and `proximityMergeIntent: ProximityMergeIntent?` to `CompanyOnMap`. Update `copyWith`. All existing tests must still compile and pass with the new optional fields defaulting to `null`.

---

### Step 6 — `ProximityMergeIntent`
**File**: `lib/domain/entities/proximity_merge_intent.dart`  
**Test first**: inline in `merge_companies_test.dart` (proximity lifecycle tests)

```dart
final class ProximityMergeIntent {
  final String targetCompanyId;
  ProximityMergeIntent({required this.targetCompanyId});
}
```

---

### Step 7 — `MoveCompany.setMidRoadDestination`
**File**: `lib/domain/use_cases/move_company.dart`  
**Test first**: `test/domain/use_cases/move_company_test.dart` (add group)

Tests to write:
- Sets `midRoadDestination` on the company; `destination` becomes null.
- Throws `MoveCompanyException` if the segment does not exist in the map.
- A company already in a battle cannot have mid-road destination set.

---

### Step 8 — `MovementRules.advancePosition` — mid-road stop
**File**: `lib/domain/rules/movement_rules.dart`  
**Test first**: `test/domain/rules/movement_rules_test.dart` (modify)

Tests to write:
- Company reaches `midRoadDest.progress` within a tick → `reachedMidRoad = true`, progress clamped to `midRoadDest.progress`.
- Company does not yet reach `midRoadDest.progress` → `reachedMidRoad = false`, progress advances normally.
- Company on wrong segment (must traverse named node first) → still advances toward `midRoadDest.currentNodeId`.

---

### Step 9 — `CheckCollisions` mid-road segment pass
**File**: `lib/domain/use_cases/check_collisions.dart`  
**Test first**: `test/domain/use_cases/check_collisions_test.dart` (add group)

Tests to write (all FR-006 scenarios):
- Head-on crossing: two enemies on same segment moving toward each other → trigger at midpoint.
- Overtake: faster enemy passes slower enemy on same segment → trigger at slower's progress.
- Stationary hit: stationary mid-road company hit by moving enemy → trigger at stationary progress.
- Friendly pass-through: friendly company passes through friendly mid-road position → no trigger.
- Node-collision path unaffected (regression).

---

### Step 10 — `TickMatch._resolveProximityMerges`
**File**: `lib/domain/use_cases/tick_match.dart`  
**Test first**: `test/domain/use_cases/tick_match_test.dart` (add group)

Tests to write (FR-015–FR-017):
- Initiator marches to target's position → merge executes; initiator removed.
- Target moves during merge; initiator re-routes; merge still completes.
- Target moves beyond threshold → merge cancelled; both companies independent.
- Battle on either company → merge cancelled.

---

### Step 11 — `CompanyNotifier` proximity merge + mid-road slot map
**File**: `lib/state/company_notifier.dart`  
**Test first**: `test/state/company_notifier_test.dart` (modify)

Changes:
- `initiateProximityMerge(String initiatorId, String targetId)`: validates distance ≤ threshold; sets `proximityMergeIntent` on initiator; sets destination to target's current position.
- `setMidRoadDestination(...)`: delegates to `MoveCompany.setMidRoadDestination`.
- `_buildSlotMap` extension: mid-road stationary companies grouped by composite key.

---

### Step 12 — `MapScreen` road hit-test + UI wiring
**File**: `lib/ui/screens/map_screen.dart`  
**Test first**: `test/widget/map_screen_road_tap_test.dart` (new)

Changes:
- Wrap `InteractiveViewer` child with `GestureDetector.onTapDown` that calls `_hitTestRoad`.
- `_hitTestRoad`: convert global → canvas coords via `_transformController.toScene`; iterate edges; return `RoadPosition?` or `MapNode?`.
- `_onCanvasTap`: if hit-test returns `RoadPosition`, call `notifier.setMidRoadDestination`; if `MapNode`, call existing `_onNodeTap`.
- `showMoveBanner` text updated to: `'Company selected — tap any road point or node to march there'`.
- Proximity merge: `_onCompanyTap` checks distance if a different company is selected; if within threshold, shows existing merge-prompt dialog.

Widget tests to write:
- Tap on road segment between nodes → company marker moves toward mid-road point (verify `midRoadDestination` set).
- Tap off all roads → company does not move (FR-003).
- Move banner text contains "road point".

---

### Step 13 — Persistence (drift)
**File**: `lib/data/` (drift schema update)  
**Test first**: `test/data/`

Add `roadPosition` columns to the companies drift table. `RoadPosition` serialises as three columns: `segment_id TEXT`, `progress REAL`, `next_node_id TEXT`. Validate round-trip in a drift unit test (SC-005).

---

## Key Constants

| Constant | Location | Value | Rationale |
|----------|----------|-------|-----------|
| `kProximityMergeThreshold` | `lib/domain/rules/movement_rules.dart` | `30.0` | ~30% of shortest segment; requires intentional proximity |
| `_kRoadSnapPixels` | `lib/ui/screens/map_screen.dart` | `20.0` | Generous for 44 pt tap target |
| `_kNodeSnapPixels` | `lib/ui/screens/map_screen.dart` | `24.0` | Slightly wider than road snap to prefer node over mid-road near endpoints |

---

## Running Tests

```bash
# All tests (must pass before PR)
flutter test

# Domain only (fast, no device needed)
flutter test test/domain/

# Specific new tests
flutter test test/domain/value_objects/road_position_test.dart
flutter test test/domain/entities/game_map_test.dart
flutter test test/domain/use_cases/check_collisions_test.dart

# Static analysis (zero warnings required)
flutter analyze
```

---

## Definition of Done

- [ ] All 13 steps implemented with TDD (Red → Green → Refactor confirmed).
- [ ] `flutter test` — all passing, including existing regression suite.
- [ ] `flutter analyze` — zero issues.
- [ ] `SC-001`–`SC-008` acceptance criteria verified (see `spec.md`).
- [ ] Frame-budget profiling screenshot attached to PR (SC-006).
- [ ] No `[TODO]` tokens remaining in plan, research, or data-model documents.
