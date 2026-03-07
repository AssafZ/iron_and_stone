# Feature Specification: Road-Free Company Movement & Positioning

**Feature Branch**: `004-road-free-movement`  
**Created**: March 7, 2026  
**Status**: Draft  
**Input**: User description: "Companies can move to and be positioned at any point on the road, not just road-junctions or castles. Companies cannot move or be placed on non-road points. Castles must be accessible and placed on roads."

## Clarifications

### Session 2026-03-07

- Q: How does the player initiate a proximity merge (what gesture surfaces the merge option)? → A: While one company is selected, tapping a nearby friendly company within the proximity threshold shows the same merge-prompt dialog as the existing co-location merge — no new UI chrome required.
- Q: When a marching company passes through an intermediate named node en route to a mid-road destination, does it snap to that node or glide through continuously? → A: The company snaps to the named node (node-checkpoint model). Each inter-node segment is traversed as a discrete step; the company's position is expressed as a named node plus fractional progress toward the next node, exactly as today. A mid-road stop is represented as a fractional position short of 1.0 on the final segment.
- Q: When the target company moves during a proximity merge, does the initiator chase indefinitely or is the merge cancelled if the target drifts too far? → A: The initiator re-evaluates the target's position every tick. If the road distance between initiator and target exceeds the proximity threshold at any tick, the merge is automatically cancelled and both companies revert to independent status. If the distance stays within the threshold the initiator keeps chasing until it arrives.
- Q: How should two enemy companies moving toward each other on the same road segment be handled — must they land on the exact same progress value, or is approaching-direction sufficient to trigger a battle? → A: Approaching-direction is sufficient. At each tick, if two enemy companies are on the same road segment and their progress values indicate they are moving toward each other (i.e. would cross within that tick), a battle is triggered at the midpoint of their current positions on that segment. Exact progress-value overlap is not required.
- Q: What unit is the proximity threshold for merge eligibility expressed in — map distance units or seconds of march time? → A: Map distance units (the same unit as `RoadEdge.length`). The threshold is a fixed distance value, speed-independent, and directly comparable to existing road-segment length values.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Tap Any Point on a Road to Send a Company There (Priority: P1)

Instead of only being able to march to named road junctions or castles, the player can tap any visible point along a road segment and the selected company will march to that exact position. The company stops at that point, not at the nearest junction.

**Why this priority**: This is the core continuous-movement capability. Without it, the game map feels sparse and artificial — all strategy reduces to discrete waypoint-hopping. Free positioning along roads opens up interception, flanking, and staging-area tactics.

**Independent Test**: Select a player company, then tap a point that lies along a road segment between two junctions (not on a junction or castle). The company must begin marching and stop at the tapped point — not at either adjacent junction.

**Acceptance Scenarios**:

1. **Given** a player company is stationary, **When** the player taps a point on a road segment between two junctions, **Then** the company begins marching toward that point and stops there on arrival.
2. **Given** a player company is marching to a mid-road point, **When** the company arrives, **Then** it stops at that exact position (not at either endpoint of the road segment).
3. **Given** the player taps a point that is NOT on any road, **When** the tap is registered, **Then** the tap is ignored as a movement command — the company does not move and no error message is shown.
4. **Given** a company is already marching, **When** the player taps a different road point, **Then** the company re-routes toward the new destination, stopping at the new point.
5. **Given** a player company is positioned mid-road, **When** the player selects it and taps a different road point, **Then** the company can be ordered to march from its mid-road position to the new destination via the road network.

---

### User Story 2 — Company Positioned Mid-Road Acts as a Valid Road Position (Priority: P2)

A company stopped at a mid-road point is treated as being "on the road" for all game purposes: it can be selected, ordered to march onward, intercepted by enemies, and can itself intercept enemies passing through its segment.

**Why this priority**: If mid-road positions are visually possible but mechanically broken (can't issue orders, collisions don't trigger), the feature is half-implemented and will confuse players. Full mechanical integration is required for the feature to deliver value.

**Independent Test**: Stop a player company mid-road. Verify it can be selected, ordered to march, and that an AI company marching along the same road segment triggers a battle when it reaches the player company's position.

**Acceptance Scenarios**:

1. **Given** a company is stopped at a mid-road position, **When** the player taps it, **Then** it can be selected and ordered to march.
2. **Given** a company is stopped at a mid-road position, **When** an enemy company's route along the same road segment passes through that position, **Then** a battle is triggered at that mid-road point.
3. **Given** a company is stopped at a mid-road position, **When** a friendly company's route passes through that position, **Then** the friendly company passes through without stopping (consistent with existing same-owner pass-through rules).
4. **Given** a company is stopped mid-road and is ordered to march to a castle, **When** it departs, **Then** it travels the road correctly from its mid-road start point to the destination.
5. **Given** two companies are both stopped at the same mid-road position, **When** viewed on the map, **Then** both are individually tappable (offset rendering applies as on junctions).

---

### User Story 3 — Castles Are Always Placed on a Road and Are Road-Accessible (Priority: P3)

Every castle on the map is placed at a point that lies on a road. A castle is always reachable by marching along roads — there are no isolated or floating castles. Any map that would place a castle off-road is considered invalid.

**Why this priority**: Castles are the primary strategic objectives. If a castle is not on a road, it cannot be attacked, captured, or relieved — the game breaks. Ensuring castles are always on roads is a data-integrity constraint that must be validated at map build time.

**Independent Test**: Load the game map. Verify that all castle nodes sit on road segments (i.e., every castle has at least one road edge connected to it). Attempt to construct a map with an off-road castle — the system must reject it.

**Acceptance Scenarios**:

1. **Given** the game map is loaded, **When** any castle node is examined, **Then** it is connected to at least one road edge.
2. **Given** a map definition attempts to include a castle with no road connections, **When** the map is built, **Then** the map builder rejects the definition and reports a validation error.
3. **Given** a castle is reachable via road from the player's starting castle, **When** the player orders a company to march there, **Then** a valid road path exists and the company can march without obstruction.

---

### User Story 4 — Companies Cannot Be Placed on Non-Road Terrain (Priority: P4)

No company may ever be positioned at a point that does not lie on a road. Deployment from a castle places the company at the castle node (which is on a road). Movement destinations outside the road network are rejected. The map has no "off-road" company positions at any time.

**Why this priority**: This constraint is the counterpart to free road positioning. Without it, companies could drift off the road network entirely, breaking pathfinding, collision detection, and all game rules that depend on road topology.

**Independent Test**: Attempt to programmatically set a company's position to a coordinate not on any road edge. The system must reject the assignment and leave the company at its last valid road position.

**Acceptance Scenarios**:

1. **Given** a player attempts to order a company to a point not on any road, **When** the tap is processed, **Then** the command is silently ignored and the company retains its current position and destination.
2. **Given** a company is deployed from a castle, **When** it appears on the map, **Then** its initial position is at the castle node, which is on a road.
3. **Given** any game tick advances all companies, **When** the tick completes, **Then** every company's position lies on a road edge or a road-connected node — no company may exist off-road.

---

---

### User Story 5 — Splitting a Company Mid-Road Produces Two Individually Tappable Companies (Priority: P3)

When the player splits a company that is stopped at a mid-road position, both resulting companies appear at that same road point. Because two markers at identical coordinates would overlap and make one untappable, the system automatically offsets them visually so each has its own reachable tap target.

**Why this priority**: Mid-road splits are a natural consequence of free positioning; without offset rendering the split feature becomes broken in the most common mid-march scenario. This is a direct visual-correctness dependency of User Story 1.

**Independent Test**: Stop a player company at a mid-road position. Perform a split. Both resulting companies must appear on the map at visually distinct, individually tappable positions anchored to the same road point.

**Acceptance Scenarios**:

1. **Given** a company is stopped at a mid-road position, **When** the player splits it, **Then** both resulting companies are rendered at offset positions from the same road point — neither overlaps the other.
2. **Given** two companies exist at the same mid-road point after a split, **When** the player taps each separately, **Then** each company is individually selectable and both respond to tap correctly.
3. **Given** one of the post-split companies is ordered to march onward, **When** it departs, **Then** the remaining company stays at the mid-road position and its marker is no longer offset (it is centred on the road point as the sole company there).
4. **Given** three or more companies accumulate at the same mid-road position (e.g. multiple consecutive splits), **When** viewed on the map, **Then** all are rendered at distinct offset positions — none are stacked on top of each other.

---

### User Story 6 — Merging Two Friendly Companies That Are Close (But Not Co-Located) on a Road (Priority: P4)

The player does not need to march both companies to exactly the same road point before merging. When two friendly companies are within a defined proximity on the road network, the player can initiate a merge. The company that initiated the merge then automatically marches to the second company's position; once it arrives, the merge executes and a single combined company remains at that position.

**Why this priority**: Requiring pixel-perfect co-location before merging is an artificial friction that is especially painful with continuous positioning. Proximity-based merge makes the feature discoverable and reduces micromanagement. It is lower priority than the core positioning stories because the existing merge mechanic still works for co-located companies.

**Independent Test**: Place two friendly player companies close to each other on the same road (but not at exactly the same point). Select one company, then tap the nearby friendly company. The same merge-prompt dialog that appears for co-located companies must be shown; confirming it must cause the first company to visibly march toward the second; when it arrives, a single merged company must appear at the second company's position.

**Acceptance Scenarios**:

1. **Given** two friendly companies are within the proximity threshold on the same road, **When** the player selects one and taps the other, **Then** the merge-prompt dialog is shown — identical to the dialog shown for co-located companies.
2. **Given** the initiating company is marching toward the merge target, **When** the initiating company arrives at the target's road position, **Then** the two companies are merged into one at that position — the initiating company ceases to exist as a separate entity.
3. **Given** two friendly companies are farther apart than the proximity threshold, **When** the player attempts to initiate a proximity merge, **Then** the merge option is not offered — the companies must be marched closer before a merge can be triggered.
4. **Given** a merge is in progress (initiator is marching to target), **When** the target company moves but the road distance between them remains within the proximity threshold, **Then** the initiating company updates its destination each tick and the merge executes on arrival.
5. **Given** a merge is in progress, **When** the target company moves such that the road distance between the two exceeds the proximity threshold, **Then** the merge is automatically cancelled and both companies revert to independent status — the initiator stops at its current road position.
6. **Given** a merge is in progress, **When** a battle is triggered involving either company before the merge completes, **Then** the merge is cancelled and both companies are treated as independent for battle purposes.
7. **Given** two friendly companies are co-located (same road point), **When** the player initiates a merge, **Then** the merge executes immediately without any march step — preserving the existing co-location merge behaviour.
8. **Given** a proximity merge would produce a combined total exceeding the 50-soldier company cap, **When** the merge is initiated, **Then** the system handles overflow in the same way as the existing merge rules (primary company of 50 + overflow remainder company).

---

### Edge Cases

- What happens when a player taps very close to a junction but intends a mid-road point? The tap resolves to the nearest valid road point; if within a small snap radius of the junction, it snaps to the junction node.
- What happens when two companies meet mid-road (neither at a named node)? The collision detection handles mid-road positions: a battle trigger fires at the mid-road point. If both companies are moving toward each other on the same segment, the battle is triggered at the midpoint of their positions even if they did not reach the same progress value within the tick.
- What happens when two enemy companies are moving in the same direction on a segment and the faster one overtakes the slower? The faster company's progress passes the slower's progress within a tick — this is treated identically to a stationary-vs-moving collision; a battle is triggered at the overtaking position.
- What happens when the map is saved and restored while a company is mid-road? The company's exact road-segment position (segment ID + fractional offset) is persisted and restored correctly on reload.
- What happens when a road segment is very short and the tapped point is extremely close to one endpoint? The tap snaps to the endpoint node if the distance is within the snap threshold; otherwise the mid-road point is used.
- What happens when a company at a mid-road position is split? Both resulting companies share the same road position and are immediately rendered at offset positions so both are tappable (see User Story 5).
- What happens when the merge initiator is destroyed in battle before it reaches the merge target? The merge is cancelled; the target company remains independent at its road position.
- What happens when the target company moves during a proximity merge and the distance grows beyond the threshold? The merge is automatically cancelled every tick the distance exceeds the threshold; both companies become independent — the initiator stops at its current road position.
- What happens when the proximity threshold for merge spans two different road segments? The proximity is measured as road distance (not straight-line distance), so companies on different segments can be within threshold if the road path between them is short enough.
- What happens when a player tries to proximity-merge with an enemy company by mistake? The merge option is only shown for friendly (same-owner) companies; the system must not offer a merge action against an enemy company.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A company's valid positions MUST be restricted to points that lie on a road segment or at a road-connected node (castle or junction). No company may exist at any position not on the road network.
- **FR-002**: A player MUST be able to assign a destination to a company by tapping any point along a visible road segment — not only named junction or castle nodes. The system MUST resolve the tapped screen coordinate to the nearest valid road point.
- **FR-003**: When the player taps a point that does not lie on any road segment, the tap MUST be ignored as a movement destination. No error message is required; the company retains its current orders.
- **FR-004**: A company that arrives at a mid-road destination MUST stop at that exact road-segment position. It MUST NOT automatically continue to the next junction.
- **FR-005**: A company stopped at a mid-road position MUST be selectable and orderable in the same way as a company stopped at a named node.
- **FR-006**: The collision and battle-trigger rules MUST apply at mid-road positions under two conditions: (a) a moving enemy company's progress along a segment reaches or passes a stationary enemy company's progress on the same segment within a tick; or (b) two enemy companies are on the same segment and moving toward each other such that their progress values would cross within that tick. In case (b) the battle is triggered at the midpoint of their two progress positions on that segment. Exact progress-value equality is NOT required to trigger a battle.
- **FR-007**: The same-owner pass-through rule (from feature 002) MUST apply at mid-road positions: a friendly company marching along a segment MUST pass through a friendly company's mid-road position without stopping.
- **FR-008**: Every castle node in any valid game map MUST be connected to at least one road edge. A map definition that includes a castle with no road connections MUST be rejected by the map builder with a validation error.
- **FR-009**: A deployed company's initial position MUST be at the castle node from which it was deployed. Since castles are always on roads (FR-008), this guarantees the company starts at a valid road position.
- **FR-010**: A company's mid-road position MUST be persistable and restorable. It is stored as a (named-node ID, fractional-progress, next-node ID) triple. This triple MUST survive a save/restore cycle with zero drift — the company reappears at exactly the same road position after reload.
- **FR-011**: The visual representation of a mid-road position MUST be smooth and continuous: a company marker MUST be rendered at any fractional position along a road segment, not snapped to junction coordinates during transit.
- **FR-012**: When multiple companies occupy the same mid-road position, the offset-rendering and tap-target rules (from feature 002, FR-001 through FR-003) MUST apply equally to mid-road positions as to named nodes.
- **FR-013**: When a company is split at any road position (node or mid-road), the two resulting companies MUST be rendered at visually distinct offset positions so that each has its own individually reachable tap target. They MUST NOT overlap.
- **FR-014**: When a company is selected and the player taps a friendly company whose road distance from the selected company is within the proximity threshold (measured in map distance units, the same unit as `RoadEdge.length`), the system MUST present the merge-prompt dialog — the same dialog used for co-located companies — even though the two companies are not at the same road position. No additional UI affordance (button, menu, etc.) is required.
- **FR-015**: When a proximity merge is initiated, the company that triggered the merge (the initiator) MUST automatically begin marching toward the target company's current road position. The merge MUST NOT execute until the initiator arrives at the target's position.
- **FR-016**: While a proximity merge is in progress, the initiator MUST re-evaluate the target's road position every game tick and update its march destination to the target's current position. If at any tick the road distance (in map distance units) between the initiator and the target exceeds the proximity threshold, the merge MUST be automatically cancelled and both companies revert to independent status — no merge executes.
- **FR-017**: If either company involved in a proximity merge is engaged in a battle before the merge completes, the merge MUST be cancelled and both companies revert to independent status. No merge action may execute while either participant is in a battle.

### Key Entities

- **RoadPosition**: Represents any valid location on the road network using the node-checkpoint model: a named node (castle or junction) plus a fractional progress value [0.0, 1.0) toward the next node along the current route. A fractional value of 0.0 means the company is exactly at the named node; any value > 0.0 and < 1.0 means the company is mid-segment. A mid-road stop is stored as progress < 1.0 on the final segment toward the destination. The company always snaps to a named node when passing through one, even if its final destination is mid-road. This extends (rather than replaces) the current `currentNode + progress` model by allowing the destination to be a mid-road fractional position rather than always a named node.
- **RoadSegment**: The directed connection between two consecutive nodes (equivalent to the current `RoadEdge`), with a stable identifier used to anchor mid-road positions for persistence.
- **MapNode (CastleNode)**: A castle node — must always have ≥ 1 road edge connected to it (enforced at map build time).
- **GameMap**: The road network graph — must validate that all CastleNodes are road-connected at construction time.
- **ProximityMergeIntent**: A transient state attached to the initiating company recording the target company's identity and the fact that this company is marching for the purpose of merging — distinct from a normal march so the merge can be cancelled by battle and resolved on arrival.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player can tap any point along a road segment and the selected company reaches that exact point — measurable by verifying the company's final position matches the tapped road coordinate within the snap tolerance.
- **SC-002**: 100% of castle nodes in any valid game map have at least one road edge — verifiable by the map builder validation rule.
- **SC-003**: 0% of companies exist at off-road positions at any point in any game tick — verifiable by a post-tick invariant check across all companies.
- **SC-004**: Collision and battle-trigger coverage extends to mid-road positions — measurable by running the existing battle-trigger test suite extended with mid-road scenarios, with all tests passing.
- **SC-005**: A company's mid-road position survives a full save/restore cycle with zero positional drift — verifiable by comparing saved and restored position values.
- **SC-006**: The game maintains 60 fps during continuous road movement with up to 10 simultaneously marching companies on a standard mid-range device — measurable via Flutter DevTools frame-time profiling.
- **SC-007**: After any split at any road position, both resulting companies are individually tappable within 1 tap attempt — verifiable by automated widget tests asserting distinct tap targets after a split action.
- **SC-008**: A proximity merge completes correctly (single merged company at target's position) in 100% of cases where the initiator reaches the target before any battle intervention — verifiable by domain unit tests covering the merge-on-arrival rule.

## Assumptions

- The current node-to-node movement model (`currentNode` + `progress`) is extended rather than replaced. A mid-road stop is represented as a `(currentNode, progress < 1.0)` pair where `progress` is the fraction along the segment from `currentNode` toward the next node. The company always snaps to a named node when it arrives at one during transit (even if its destination is mid-road on a later segment); this keeps collision detection and persistence aligned with the existing tick-based architecture. The visual interpolation already present in `map_screen.dart` is the correct foundation for this.
- Road segments are treated as straight lines between node coordinates for hit-testing purposes. Curved road rendering (if introduced later) would require a separate hit-test model.
- The snap radius for resolving a tap to a junction node (rather than a mid-road point) is a UI constant chosen to avoid accidental mid-road stops when the player intends to tap a node; the exact value is a UX tuning parameter deferred to the planning phase.
- The existing `RoadEdge` model is sufficient to represent a road segment; a stable `id` field will be added to enable persistence references.
- Map fixture validation (castles on roads) applies to the current `GameMapFixture` and any future map definitions; it does not retroactively affect saved game states that predate this feature.
- The proximity threshold for merge eligibility is measured as road distance (sum of remaining segment lengths along the shortest path) in **map distance units** — the same unit as `RoadEdge.length`. It is speed-independent and directly comparable to segment-length values in the model. The specific numeric value is a game-balance parameter deferred to the planning phase.
- The offset rendering for co-located companies introduced in feature 002 is directly reused for mid-road positions; no new offset algorithm is required — only the position anchor changes from "node centre" to "road-segment fractional coordinate".
