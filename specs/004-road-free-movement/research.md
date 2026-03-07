# Research: Road-Free Company Movement & Positioning

**Branch**: `004-road-free-movement` | **Date**: 2026-03-07  
**Purpose**: Resolve all NEEDS CLARIFICATION items from Technical Context; capture best-practice decisions for the design phase.

---

## R-001 — Mid-Road Position Representation

**Question**: Should the existing `currentNode + progress` model be extended or replaced with a fully general 2D coordinate?

**Decision**: Extend, not replace. A mid-road stop is a `(currentNode: MapNode, progress: double ∈ [0.0, 1.0))` pair — the same fields that already exist on `CompanyOnMap`. A new value object `RoadPosition` wraps these two fields and the `nextNodeId` (needed for persistence). The destination field on `CompanyOnMap` is widened from `MapNode?` to `RoadPosition?` so it can express either "march to a named node" or "stop at a fractional position on this segment".

**Rationale**: The visual interpolation in `map_screen.dart._companyVisualPos` already consumes `currentNode` and `progress` to render smooth movement. Keeping the same fields means zero rendering changes. Replacing with 2D coordinates would require rewriting `pathBetween`, the A\* routing, and all tests.

**Alternatives considered**:
- Pure 2D target coordinate: rejected — pathfinding requires graph nodes; a floating target would require a separate "nearest road point" step at every tick, not just at command time.
- Introduce a virtual "mid-road node" inserted into the graph: rejected — mutating the graph per tap violates YAGNI and complicates BFS pathing.

---

## R-002 — Hit-Testing: Resolving a Screen Tap to a Road Point

**Question**: How does the UI convert a pixel tap coordinate (within the `InteractiveViewer` canvas) into a `RoadPosition`?

**Decision**: A single `_hitTestRoad` helper in `map_screen.dart` iterates the `GameMap.edges` list and computes the perpendicular distance from the tapped canvas point to each edge segment. If the closest edge is within `_kRoadSnapPixels` (= 20 canvas-pixels), the helper projects the tap point onto that edge and returns a `RoadPosition` (segment + progress). If the closest edge is farther than `_kRoadSnapPixels`, the tap is not on a road and the command is silently ignored (FR-003). If the projection falls within `_kNodeSnapPixels` (= 24 canvas-pixels) of either endpoint node, it snaps to the node directly instead of returning a mid-road position.

**Rationale**: Linear projection onto each edge is O(E) with E ≤ 20 edges — trivially fast per tap. The snap constants are UI tuning values expressed in canvas pixels (independent of game distance units). The spec explicitly defers these constants to the planning phase; 20 px road snap and 24 px node snap are generous for a 44 × 44 pt tap target and will be refined during widget testing.

**Alternatives considered**:
- Spatial index (k-d tree, quad-tree): overkill for E ≤ 20; adds a dependency with no benefit at this scale.
- Snap exclusively to nodes; no mid-road support: explicitly contradicts the feature requirement.

---

## R-003 — Proximity Threshold for Merge Eligibility

**Question**: What numeric value should the proximity threshold be?

**Decision**: `kProximityMergeThreshold = 30.0` map distance units. This is approximately 30% of the shortest road segment length in the MVP fixture (100 units) — meaning companies must be quite close before a merge is offered. The value is a top-level `const` in `lib/domain/rules/movement_rules.dart` so it can be tuned without hunting through the codebase.

**Rationale**: At 30 units, the threshold is small enough that the player must intentionally manoeuvre companies near each other to trigger the merge UI, yet large enough to be practical without pixel-perfect positioning. It is measured in road-graph distance (shortest path via `_roadDistance`), not Euclidean straight-line distance, as specified in the clarifications.

**Alternatives considered**:
- 50 units (half a full segment): too large — would offer merges for companies that are visually far apart on the map.
- 10 units: too small — frustrating in practice; hard to stop mid-road within such a narrow window.
- Per-segment percentage: more adaptive but adds complexity with no clear player benefit.

---

## R-004 — Persistence: RoadEdge Stable ID

**Question**: How should mid-road positions be persisted? `RoadEdge` currently has no stable identifier.

**Decision**: Add a `final String id` field to `RoadEdge`. The ID is constructed as `"${from.id}__${to.id}"` by convention (unique given directed edges). `GameMapFixture` does not need to change its call sites because the `RoadEdge` constructor gets a default derived `id` via a factory or by the fixture explicitly passing the conventional string. A `RoadPosition` is persisted as a three-column drift row: `segmentId TEXT`, `progress REAL`, `nextNodeId TEXT`.

**Rationale**: Using `"${from.id}__${to.id}"` as the ID makes every existing edge implicitly addressable without changing fixture code. The string is stable across app restarts because node IDs are hard-coded string constants in `GameMapFixture`.

**Alternatives considered**:
- UUID per edge at runtime: not stable across restarts; persistence would break every time the map is reconstructed.
- Derive from sorted node pair: would make directed edges ambiguous (A→B and B→A would have the same ID).

---

## R-005 — Mid-Road Collision Detection

**Question**: How should `CheckCollisions` detect enemy encounters when neither company is at a named node?

**Decision**: After the existing node-grouping collision pass, add a second pass that groups free companies **by their road segment** (using `"${currentNode.id}__${nextNode.id}"` as the key, normalised to canonical direction so A→B and B→A are the same segment). For each segment group containing enemies:

1. **Head-on**: If company A has `progress` advancing toward B and company B has `progress` advancing toward A such that they would cross within this tick, trigger a battle at the midpoint progress = `(A.progress + B.progress) / 2`.
2. **Overtake**: If company A is behind company B (lower progress), both moving in the same direction, and A's new progress would exceed B's current progress this tick, trigger at B's progress position.
3. **Stationary hit**: If one company is stationary mid-road (destination is null or same segment anchor) and a moving enemy's progress reaches or passes it, trigger at the stationary company's progress.

The `BattleTrigger` emitted for mid-road battles gains a `midRoadProgress: double?` field so the battle indicator can be rendered at the correct canvas position between the two nodes.

**Rationale**: The spec (FR-006) explicitly requires head-on crossing detection within a tick. Adding a mid-road segment pass after the node-grouping pass is additive — it does not disturb the existing castle-assault and node-collision paths.

**Alternatives considered**:
- Continuous collision detection (sub-tick interpolation): more accurate but breaks the tick-based architecture; deferred to a future performance/fidelity upgrade.
- Check only node arrivals: misses all mid-road encounters; directly contradicts FR-006.

---

## R-006 — ProximityMergeIntent Lifecycle

**Question**: Where does `ProximityMergeIntent` live and how is it cancelled?

**Decision**: `ProximityMergeIntent` is a value object stored as an optional field on `CompanyOnMap`:

```dart
final ProximityMergeIntent? proximityMergeIntent;
```

It records `{ targetCompanyId: String }`. The initiating company's destination is set to the target's current `RoadPosition` each tick. Cancellation conditions (checked in `TickMatch._resolveProximityMerges`):
- Target no longer exists in the company list.
- Road distance between initiator and target exceeds `kProximityMergeThreshold`.
- Either company has `battleId != null`.
- Initiator's `currentNode` + `progress` == target's `currentNode` + `progress` (arrival → merge executes).

On cancellation: initiator's `proximityMergeIntent` is cleared; destination set to null (stops at current road position).

On merge execution: standard `MergeCompanies.merge` is invoked at the target's position; initiator is removed from the company list.

**Rationale**: Storing intent on `CompanyOnMap` keeps the domain model self-contained and immutable (every tick produces a new list). `TickMatch` already iterates all companies; the proximity-merge resolution fits naturally as a post-movement, pre-collision step.

**Alternatives considered**:
- Separate `ProximityMergeTable` in the state layer: requires the state layer to orchestrate domain logic, violating Principle II.
- Store on `MatchState` as a separate list: equivalent but more indirection; inline on `CompanyOnMap` is simpler.

---

## R-007 — Slot Offset Rendering for Mid-Road Companies

**Question**: Does the existing `_buildSlotMap` / `_offsetForCompany` logic in `map_screen.dart` need a new algorithm for mid-road positions?

**Decision**: No new algorithm. The existing approach (group stationary companies by `currentNode.id`, assign lexicographic slots, apply `_kSlotOffsets`) is extended by also grouping companies that are **stationary mid-road** using a composite key of `"${currentNode.id}_${nextNodeId}_${progress.toStringAsFixed(3)}"`. Because two companies at exactly the same mid-road position share this key, the same slot-offset table applies verbatim.

The visual anchor for a mid-road company is its fractional canvas position (already computed by `_companyVisualPos`) — the offset is applied as a `dx`/`dy` from that anchor, identically to how it is applied from a node centre.

**Rationale**: The spec's Assumptions section explicitly states "The offset rendering for co-located companies introduced in feature 002 is directly reused for mid-road positions; no new offset algorithm is required — only the position anchor changes." This research confirms that is the correct approach.

---

## R-008 — GameMap Castle Validation

**Question**: When and where should the castle-on-road constraint be enforced?

**Decision**: Add a validation pass to the `GameMap` constructor (after the existing immutability wrappers). For each `CastleNode` in `nodes`, verify that at least one `RoadEdge` in `edges` has `from.id == castle.id` or `to.id == castle.id`. If any castle fails, throw an `ArgumentError` with a descriptive message listing the offending castle IDs.

This is a build-time check — it fires when `GameMapFixture.build()` or any test-fixture constructor runs. There is no runtime performance cost during gameplay.

**Rationale**: FR-008 requires that an invalid map is "rejected by the map builder with a validation error." The `GameMap` constructor is the map builder; throwing `ArgumentError` is idiomatic Dart for invalid construction arguments.

**Alternatives considered**:
- Separate `MapValidator` class: more indirection for a single constraint; YAGNI.
- Validate only in tests: does not catch regressions in production map data.

---

## Summary of Decisions

| ID | Decision | Value / Constant |
|----|----------|-----------------|
| R-001 | Extend `currentNode + progress`; add `RoadPosition` value object | — |
| R-002 | Linear edge projection hit-test in UI | `_kRoadSnapPixels = 20`, `_kNodeSnapPixels = 24` |
| R-003 | Proximity merge threshold | `kProximityMergeThreshold = 30.0` map units |
| R-004 | `RoadEdge.id = "${from.id}__${to.id}"` | Derived at construction |
| R-005 | Segment-keyed collision pass added to `CheckCollisions` | — |
| R-006 | `ProximityMergeIntent` on `CompanyOnMap`; resolved in `TickMatch` | — |
| R-007 | Reuse slot-offset algorithm; composite key for mid-road group | — |
| R-008 | `GameMap` constructor validates castle connectivity | Throws `ArgumentError` |
