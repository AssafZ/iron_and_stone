# Data Model: Road-Free Company Movement & Positioning

**Branch**: `004-road-free-movement` | **Date**: 2026-03-07  
**Source**: `spec.md` → Key Entities + Functional Requirements + research.md decisions

---

## Entity Catalogue

### 1. `RoadPosition` *(new — `lib/domain/value_objects/road_position.dart`)*

Represents any valid location on the road network using the node-checkpoint model.

```
RoadPosition
├── currentNodeId : String          — the named node (castle or junction) most recently passed
├── progress      : double [0.0, 1.0) — fraction along the segment toward nextNodeId
└── nextNodeId    : String          — the node at the far end of the segment
```

**Validation rules**:
- `progress` must be in `[0.0, 1.0)`. A value of `0.0` means the company is exactly at `currentNodeId`.
- `currentNodeId != nextNodeId` (no self-segment).
- Both IDs must refer to nodes that are connected by a `RoadEdge` in the map (validated at use-case level, not at value-object construction — the value object itself is a lightweight record).

**State transitions**:
- Created when a player taps a mid-road point: `progress` is the projection of the tap onto the edge.
- Progress advances each tick via `MovementRules.advancePosition`.
- When `progress` reaches the destination's `progress` value on the segment, the company stops (FR-004).
- When `progress` reaches `1.0`, the company snaps to the next named node (existing behaviour preserved).

**Persistence** (drift column triple):
```
road_edge_id         TEXT  — stores RoadEdge.id = "${from.id}__${to.id}"; uniquely identifies
                             the directed segment; is the authoritative persistence key
mid_road_progress    REAL  — stored with full double precision
mid_road_next_node_id TEXT — intentionally denormalised from road_edge_id for query performance;
                             equals the second token of road_edge_id (split on "__");
                             must be kept in sync with road_edge_id on every write
```

---

### 2. `RoadEdge` *(modified — `lib/domain/entities/road_edge.dart`)*

Adds a stable string identifier used to anchor `RoadPosition` persistence references.

```
RoadEdge (modified)
├── id     : String   NEW — derived as "${from.id}__${to.id}" at construction
├── from   : MapNode  (unchanged)
├── to     : MapNode  (unchanged)
└── length : double   (unchanged)
```

**Derivation rule**: `id = "${from.id}__${to.id}"`. Unique for directed edges; the reverse edge has `id = "${to.id}__${from.id}"`.

**No breaking change**: existing constructors gain the `id` field as a computed value (no call-site changes required).

---

### 3. `CompanyOnMap` *(modified — `lib/domain/use_cases/check_collisions.dart`)*

Two additive fields:

```
CompanyOnMap (modified)
├── ... (all existing fields unchanged)
├── midRoadDestination  : RoadPosition?  NEW — non-null when company is marching to
│                                             a fractional point on a segment rather
│                                             than a named MapNode
└── proximityMergeIntent: ProximityMergeIntent?  NEW — non-null while this company
                                                       is marching to merge with target
```

**Invariant**: `destination` and `midRoadDestination` are mutually exclusive destinations. When `midRoadDestination != null`, the company is heading for a fractional segment point. When `destination != null` (existing field), the company is heading for a named node. Both null = stationary.

**State transitions for `midRoadDestination`**:
- Set by `MoveCompany.setMidRoadDestination`.
- Cleared when the company's `(currentNode.id, progress)` matches `(midRoadDestination.currentNodeId, midRoadDestination.progress)` within a tick (FR-004 — stop at mid-road point).
- Replaced by `MoveCompany.setDestination` (player issues a new move order).

---

### 4. `ProximityMergeIntent` *(new — `lib/domain/entities/proximity_merge_intent.dart`)*

A transient value object attached to the initiating company during a proximity merge.

```
ProximityMergeIntent
└── targetCompanyId : String — the ID of the friendly company being merged into
```

**Validation rule**: `targetCompanyId` must not equal the company's own `id`.

**Lifecycle** (managed by `TickMatch._resolveProximityMerges`):
1. **Created**: when the player confirms the merge-prompt dialog for two non-co-located friendly companies within `kProximityMergeThreshold`.
2. **Active**: initiator's destination is updated to the target's current road position every tick.
3. **Cancelled** (any of):
   - Target no longer in company list.
   - Road distance between initiator and target exceeds `kProximityMergeThreshold`.
   - Either company's `battleId != null`.
4. **Executed**: initiator reaches the target's position → `MergeCompanies.merge` fires → initiator entity is removed.

---

### 5. `GameMap` *(modified — `lib/domain/entities/game_map.dart`)*

**New validation** in constructor:

```
GameMap.constructor
  FOR EACH node IN nodes WHERE node IS CastleNode:
    ASSERT at least one edge in edges connects to node.id
    IF violated: throw ArgumentError("Castle '${node.id}' has no road connections.")
```

**New method** `nearestRoadPosition(Offset canvasPoint, double scale, double offsetX, double offsetY) → RoadPosition?`:
- Iterates all edges, projects the canvas point onto each segment.
- Returns `RoadPosition` for the nearest segment within `kRoadSnapPixels` canvas pixels.
- Returns `null` if no segment is within range.
- Snaps to the endpoint node (returns `null` for mid-road) if the projection is within `kNodeSnapPixels` of a node.

> Note: this method takes display constants as parameters so the domain stays Flutter-free (the constants are passed in from the UI layer).

**New method** `roadDistance(RoadPosition from, RoadPosition to) → double`:
- Computes road graph distance between two `RoadPosition` values.
- Handles same-segment case: `|to.progress - from.progress| * edge.length`.
- Handles cross-segment case: distance from `from` to `from.nextNode` + BFS path distance + distance from `to.currentNode` to `to`.

---

### 6. `MovementRules` *(modified — `lib/domain/rules/movement_rules.dart`)*

**Extended `advancePosition`** signature:

```
advancePosition({
  required MapNode currentNode,
  required MapNode? destination,        — existing: named-node destination
  required RoadPosition? midRoadDest,   — new: fractional-point destination
  required double progress,
  required Company company,
  required GameMap map,
  required double tickSeconds,
}) → MovementPositionResult
```

**New `MovementPositionResult` fields**:
```
MovementPositionResult
├── currentNode   : MapNode   (unchanged)
├── progress      : double    (unchanged)
└── reachedMidRoad: bool      NEW — true when the company has stopped at midRoadDest
```

**Mid-road stop logic** (when `midRoadDest != null`):
1. If `currentNode.id != midRoadDest.currentNodeId`, advance toward `midRoadDest.currentNodeId` as usual (named-node path).
2. Once `currentNode.id == midRoadDest.currentNodeId`, advance progress toward `midRoadDest.progress`:
   - `newProgress = progress + (speed * tickSeconds) / edge.length`
   - If `newProgress >= midRoadDest.progress`: clamp to `midRoadDest.progress`, set `reachedMidRoad = true`.
3. Company stops: `midRoadDestination` is cleared; company is stationary at `(currentNode, midRoadDest.progress)`.

---

### 7. `CheckCollisions` *(modified — `lib/domain/use_cases/check_collisions.dart`)*

**New mid-road collision pass** (added after the existing node-grouping pass):

```
// Group free companies by canonical segment key (lower-id node first)
segmentGroups: Map<String, List<CompanyOnMap>>
  key = canonicalSegmentKey(co.currentNode.id, nextNodeId(co))
  value = [companies on that segment that are in transit OR stationary mid-road]

FOR EACH segmentGroup WITH length >= 2:
  IF group has enemy pair:
    FOR EACH (enemy_a, enemy_b) pair:
      IF head-on crossing within tick → trigger at midpoint progress
      IF overtake within tick → trigger at passed company's progress
      IF stationary mid-road hit → trigger at stationary company's progress
    EMIT BattleTrigger(kind=roadCollision, midRoadProgress: double)
```

**`BattleTrigger` modification**:
```
BattleTrigger (modified)
├── kind              : BattleTriggerKind (unchanged)
├── location          : MapNode (unchanged — set to currentNode of segment start)
├── companyIds        : List<String> (unchanged)
└── midRoadProgress   : double?  NEW — non-null for mid-road trigger; null for node triggers
```

**`BattleIndicator` rendering**: when `midRoadProgress != null`, the battle indicator is positioned between the two nodes at the fractional canvas coordinate (computed the same way as `_companyVisualPos`).

---

### 8. Constants *(new — `lib/domain/rules/movement_rules.dart`)*

```dart
/// Road distance (in map distance units, same unit as RoadEdge.length) within
/// which two friendly companies are eligible for a proximity merge.
const double kProximityMergeThreshold = 30.0;
```

```dart
// In lib/ui/screens/map_screen.dart (UI layer, not domain)
/// Max canvas-pixel distance from a road segment for a tap to be registered as
/// a road tap.
const double _kRoadSnapPixels = 20.0;

/// Canvas-pixel distance from a node within which a road tap snaps to the node
/// rather than returning a mid-road position.
const double _kNodeSnapPixels = 24.0;
```

---

## Relationship Diagram

```
GameMap ──has-many──> MapNode (CastleNode | RoadJunctionNode)
GameMap ──has-many──> RoadEdge (id, from, to, length)
                            │
                            └──anchors──> RoadPosition (currentNodeId, progress, nextNodeId)

CompanyOnMap ──has-optional──> RoadPosition           (midRoadDestination)
CompanyOnMap ──has-optional──> MapNode                (destination — named node)
CompanyOnMap ──has-optional──> ProximityMergeIntent   (targetCompanyId)

TickMatch ──resolves──> ProximityMergeIntent ──triggers──> MergeCompanies
CheckCollisions ──emits──> BattleTrigger (with optional midRoadProgress)
MovementRules ──consumes──> RoadPosition (midRoadDest) ──produces──> MovementPositionResult
```

---

## Validation Rules Summary

| Rule | Location | Enforcement |
|------|----------|-------------|
| `RoadPosition.progress ∈ [0.0, 1.0)` | `RoadPosition` constructor | `ArgumentError` |
| `RoadPosition.currentNodeId ≠ nextNodeId` | `RoadPosition` constructor | `ArgumentError` |
| Every `CastleNode` has ≥ 1 road edge | `GameMap` constructor | `ArgumentError` |
| `MidRoadDestination` segment exists in map | `MoveCompany.setMidRoadDestination` | `MoveCompanyException` |
| `ProximityMergeIntent.targetId ≠ own id` | `ProximityMergeIntent` constructor | `ArgumentError` |
| Companies off-road: forbidden | `TickMatch` post-tick invariant | `assert` (debug) |
