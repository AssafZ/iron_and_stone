# Tasks: Road-Free Company Movement & Positioning

**Input**: Design documents from `/specs/004-road-free-movement/`  
**Branch**: `004-road-free-movement`  
**Prerequisites**: plan.md ✅ spec.md ✅ research.md ✅ data-model.md ✅ quickstart.md ✅ analysis.md ✅

**Tests**: Test tasks are **REQUIRED** — Constitution Principle III (Test-First for Game Rules) is NON-NEGOTIABLE. All domain tasks follow Red-Green-Refactor: failing test first, then implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: Which user story this task belongs to (US1–US6)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify branch, tooling, and confirm existing tests are green before any changes

- [ ] T001 Confirm branch is `004-road-free-movement` and `flutter test` passes with zero failures
- [ ] T002 [P] Confirm `flutter analyze` reports zero issues (baseline before changes)
- [ ] T003 [P] Read `specs/004-road-free-movement/quickstart.md` to confirm implementation order and constants

**Checkpoint**: All existing tests green, analysis clean, constants known → ready for foundational work

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core new types and modifications that every user story depends on. MUST be complete before any user story phase begins.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### 2A — `RoadPosition` value object (blocks US1–US6)

- [ ] T004 Write failing unit tests for `RoadPosition` value object in `test/domain/value_objects/road_position_test.dart` — cover: valid progress `[0.0, 1.0)` (any `double < 1.0` is accepted, e.g. `0.9999` must pass), `progress = 1.0` throws `ArgumentError`, `progress < 0.0` throws `ArgumentError`, `currentNodeId == nextNodeId` throws `ArgumentError`
- [ ] T005 Create `lib/domain/value_objects/road_position.dart` — implement `final class RoadPosition` with fields `currentNodeId`, `progress`, `nextNodeId`; constructor validates `progress >= 1.0 || progress < 0.0` throws `ArgumentError` (half-open range `[0.0, 1.0)`) and `currentNodeId != nextNodeId`; implement `==` and `hashCode`; confirm T004 tests pass

### 2B — `RoadEdge.id` stable identifier (blocks US1, US3, persistence)

- [ ] T006 Write failing unit test in `test/domain/entities/road_edge_test.dart` — assert that a `RoadEdge(from: nodeA, to: nodeB, length: 100)` has `id == "nodeA_id__nodeB_id"`; assert reverse edge has `id == "nodeB_id__nodeA_id"`
- [ ] T007 Modify `lib/domain/entities/road_edge.dart` — add `final String id;` derived as `"${from.id}__${to.id}"` in the constructor body (computed, not a required parameter); confirm T006 passes and all existing tests still compile

### 2C — `CompanyOnMap` extended fields (blocks US1, US2, US5, US6)

- [ ] T008 Modify `lib/domain/use_cases/check_collisions.dart` — add two nullable fields to `CompanyOnMap`: `midRoadDestination: RoadPosition?` and `proximityMergeIntent: ProximityMergeIntent?`; update `copyWith` to handle both with sentinel pattern; confirm all existing tests compile and pass (fields default to `null`)

### 2D — `ProximityMergeIntent` entity (blocks US6)

- [ ] T009 [P] Create `lib/domain/entities/proximity_merge_intent.dart` — implement `final class ProximityMergeIntent` with `final String targetCompanyId`; constructor throws `ArgumentError` if `targetCompanyId` is empty

### 2E — `GameMap` castle validation + `roadDistance` (blocks US3, US6)

- [ ] T010 Write failing unit tests in `test/domain/entities/game_map_test.dart` — cover: (a) map with all castles connected builds without error; (b) map with castle having no edges throws `ArgumentError` naming the offending castle; (c) `GameMapFixture.build()` succeeds (regression guard); (d) `roadDistance` same-segment case: progress 0.2→0.7 on a length-100 edge = 50.0; (e) `roadDistance` cross-segment uses shortest BFS path
- [ ] T011 Modify `lib/domain/entities/game_map.dart` — add constructor validation loop over `CastleNode` entries: assert each has ≥ 1 matching edge; add `roadDistance(RoadPosition from, RoadPosition to) → double` method (same-segment: `|to.progress - from.progress| * edge.length`; cross-segment: distance from `from` to `from.currentNodeId`'s nextNode + BFS + distance to `to`); confirm T010 passes

**Checkpoint**: Foundational types exist, all tests green → user story phases can now begin

---

## Phase 3: User Story 1 — Tap Any Point on a Road to Send a Company There (Priority: P1) 🎯 MVP

**Goal**: Player taps anywhere on a visible road segment; the selected company marches to that exact fractional position and stops there. Taps off-road are silently ignored.

**Independent Test**: Select a player company, tap a canvas point mid-segment between `j1` and `j2`. Verify the company's `midRoadDestination` is set to the correct `RoadPosition` and is cleared (company stationary) after the tick when it arrives.

### Tests for User Story 1 ⚠️ Write and confirm FAILING before implementation

- [ ] T012 [P] [US1] Write failing tests for `MoveCompany.setMidRoadDestination` in `test/domain/use_cases/move_company_test.dart` — group `setMidRoadDestination`: (a) sets `midRoadDestination` on company and clears `destination`; (b) throws `MoveCompanyException` when the segment does not exist in the map; (c) company locked in battle cannot have mid-road destination set
- [ ] T013 [P] [US1] Write failing tests for `MovementRules.advancePosition` mid-road stop in `test/domain/rules/movement_rules_test.dart` — (a) company reaches `midRoadDest.progress` within a tick → `reachedMidRoad = true`, progress clamped; (b) company does not yet reach → `reachedMidRoad = false`, progress advances; (c) company still on wrong segment advances toward `midRoadDest.currentNodeId` first
- [ ] T014 [P] [US1] Write failing widget test for road tap → destination in `test/widget/map_screen_road_tap_test.dart` — (a) tap canvas point on road segment → company `midRoadDestination` is set; (b) tap off all road segments → company does not move; (c) move banner text contains "road point"

### Implementation for User Story 1

- [ ] T015 [US1] Modify `lib/domain/rules/movement_rules.dart` — extend `advancePosition` signature with `RoadPosition? midRoadDest`; add `reachedMidRoad: bool` to `MovementPositionResult`; implement mid-road stop logic: advance progress toward `midRoadDest.progress` when on correct segment, clamp and set `reachedMidRoad = true` on arrival; add `const double kProximityMergeThreshold = 30.0`; confirm T013 passes
- [ ] T016 [US1] Modify `lib/domain/use_cases/move_company.dart` — add `setMidRoadDestination({required CompanyOnMap company, required RoadPosition dest, required GameMap map}) → CompanyOnMap`; validate segment exists; set `midRoadDestination`, clear `destination`; update `advance` to pass `midRoadDest` to `MovementRules.advancePosition`; clear `midRoadDestination` when `reachedMidRoad == true`; confirm T012 passes
- [ ] T017 [US1] Modify `lib/ui/screens/map_screen.dart` — add `const double _kRoadSnapPixels = 20.0` and `const double _kNodeSnapPixels = 24.0`; add `_hitTestRoad(Offset canvasPoint) → ({RoadPosition? road, MapNode? node})` helper using linear edge projection; wrap the `InteractiveViewer` child with `GestureDetector.onTapDown` that converts global coords via `_transformController.toScene` then calls `_hitTestRoad`; wire result to `companyNotifier.setMidRoadDestination` (road) or existing `_onNodeTap` (node); update move-mode banner text to `'Company selected — tap any road point or node to march there'`; confirm T014 passes
- [ ] T018 [US1] Modify `lib/state/company_notifier.dart` — add `setMidRoadDestination({required String companyId, required RoadPosition dest, required GameMap map})` action delegating to `MoveCompany.setMidRoadDestination`; call `ref.read(matchNotifierProvider.notifier).updateCompanies`

**Checkpoint**: Player can tap a road segment; company marches to the mid-road point and stops. US1 is fully playable and testable independently.

---

## Phase 4: User Story 2 — Mid-Road Position Is a Fully Valid Game Position (Priority: P2)

**Goal**: A company stopped mid-road is selectable, orderable, and participates in all collision/battle rules — including being hit by a passing enemy and passing through a friendly.

**Independent Test**: Stop a player company mid-road. Confirm it is selectable via `_onCompanyTap`. Send an AI company along the same segment; confirm `CheckCollisions` emits a `BattleTrigger` with `midRoadProgress` set. Send a friendly company; confirm no trigger.

### Tests for User Story 2 ⚠️ Write and confirm FAILING before implementation

- [ ] T019 [P] [US2] Write failing tests for `CheckCollisions` mid-road segment pass in `test/domain/use_cases/check_collisions_test.dart` — group `mid-road collisions`: (a) head-on crossing: two enemies moving toward each other on same segment → trigger at midpoint progress; (b) overtake: faster enemy passes slower → trigger at slower's progress; (c) stationary mid-road hit: moving enemy reaches stationary enemy's progress → trigger at stationary's progress; (d) friendly pass-through → no trigger; (e) existing node-collision tests remain unaffected (regression group)
- [ ] T020 [P] [US2] Write failing test in `test/domain/use_cases/move_company_test.dart` — group `mid-road ordering`: company with `midRoadDestination` set can receive a new `setDestination` to a named node (clears `midRoadDestination`, sets `destination`)

### Implementation for User Story 2

- [ ] T021 [US2] Modify `lib/domain/use_cases/check_collisions.dart` — add second pass after existing node-grouping loop: group free companies by canonical segment key `"${lowerNodeId}__${higherNodeId}"`; for each enemy pair on same segment detect (a) head-on crossing, (b) overtake, (c) stationary hit; add `midRoadProgress: double?` field to `BattleTrigger`; emit triggers with correct `midRoadProgress`; confirm T019 passes
- [ ] T022 [US2] Modify `lib/ui/screens/map_screen.dart` — update `BattleIndicator` positioning to use `midRoadProgress` when non-null (lerp between the two node canvas positions at that fraction); update `_companyVisualPos` to use `midRoadDestination` for stationary mid-road anchor (company is stationary but not at a node)
- [ ] T023 [US2] Modify `lib/state/company_notifier.dart` — ensure `_buildSlotMap` uses composite key `"${co.currentNode.id}__${nextNodeId(co)}_${co.progress.toStringAsFixed(3)}"` for stationary mid-road companies so offset rendering groups them correctly; add `nextNodeId` helper that resolves from `midRoadDestination?.nextNodeId ?? destination?.id ?? co.currentNode.id`

**Checkpoint**: Mid-road companies trigger battles, pass-through works, and are individually selectable/tappable with offsets. US2 independently testable.

---

## Phase 5: User Story 3 — Castles Are Always Placed on a Road (Priority: P3)

**Goal**: Every castle in any valid `GameMap` is connected to at least one road edge. A map that violates this rule is rejected at construction time with a clear error.

**Independent Test**: Call `GameMapFixture.build()` — succeeds. Construct a `GameMap` with a `CastleNode` that has no edges in the list — `ArgumentError` is thrown with the castle ID in the message.

### Tests for User Story 3 ⚠️ Write and confirm FAILING before implementation

- [ ] T024 [US3] Tests already written in T010 (foundational). Confirm the `ArgumentError` test (T010-b) is still failing before T025.

### Implementation for User Story 3

- [ ] T025 [US3] Implementation already delivered in T011 (foundational). Run `flutter test test/domain/entities/game_map_test.dart` and confirm all castle-validation tests pass including T010-b.

**Checkpoint**: `GameMap` rejects off-road castles. `GameMapFixture` passes. US3 is complete.

---

## Phase 6: User Story 4 — Companies Cannot Be Placed on Non-Road Terrain (Priority: P4)

**Goal**: No code path can produce a `CompanyOnMap` at an off-road position. Taps off-road are silently ignored. Post-tick invariant holds: every company is on a road.

**Independent Test**: Call `MoveCompany.setMidRoadDestination` with a `RoadPosition` whose `currentNodeId` does not match any edge in the map — `MoveCompanyException` is thrown. Verify `MapScreen._hitTestRoad` returns `null` for an off-road canvas point.

### Tests for User Story 4 ⚠️ Write and confirm FAILING before implementation

- [ ] T026 [P] [US4] *(Confirmation only — no new test file)* Verify the failing test in T012-b (`setMidRoadDestination` throws `MoveCompanyException` for a segment not in the map) is still red before T016 is implemented. T012-b is the canonical test; this task is a pre-implementation gate, not a separate test.
- [ ] T027 [P] [US4] Write failing test in `test/domain/use_cases/tick_match_test.dart` — after any tick, assert every `CompanyOnMap` in the result satisfies: either `progress == 0.0` (at a node) or there exists a `RoadEdge` with `from.id == co.currentNode.id`

### Implementation for User Story 4

> **Checkpoint (no task)**: T016's `setMidRoadDestination` already validates that the supplied `RoadPosition` references a segment present in the map (segment-existence guard from T012-b / T016 implementation). Before starting T029, confirm this guard is in place; if not, tighten the validation in `lib/domain/use_cases/move_company.dart` as part of T016.

- [ ] T029 [US4] Modify `lib/domain/use_cases/tick_match.dart` — add a post-tick `assert` (debug-mode invariant) that every company in `updatedCompanies` satisfies the off-road invariant; confirm T027 passes

**Checkpoint**: Off-road positions are impossible via any public API. US4 invariant holds.

---

## Phase 7: User Story 5 — Splitting Mid-Road Produces Two Individually Tappable Companies (Priority: P3)

**Goal**: A split at a mid-road position produces two `CompanyOnMap` entries with the same `(currentNode, progress)`. The slot-map assigns them distinct offset positions so each has its own 44 × 44 pt tap target.

**Independent Test**: Create two `CompanyOnMap` entities at identical `(currentNode, progress = 0.5)`. Call `_buildSlotMap`. Assert they receive different offsets. Assert each is individually tappable in a widget test.

### Tests for User Story 5 ⚠️ Write and confirm FAILING before implementation

- [ ] T030 [P] [US5] Write failing unit test for mid-road slot grouping in `test/state/company_notifier_test.dart` — two companies at same `(currentNode, progress = 0.5)` receive different offsets from `_buildSlotMap`; three companies at same position all receive distinct offsets
- [ ] T031 [P] [US5] Write failing widget test in `test/widget/map_screen_road_tap_test.dart` — perform a split on a mid-road company; assert two markers appear at distinct canvas positions; assert each marker responds to a tap independently

### Implementation for User Story 5

- [ ] T032 [US5] Modify `lib/state/company_notifier.dart` (`_rebuildOccupancyMap` helper) and `lib/ui/screens/map_screen.dart` (`_buildSlotMap`) — extend grouping key to include mid-road composite `"${currentNode.id}__${nextNodeId}_${progress.toStringAsFixed(3)}"` for stationary mid-road companies; confirm T030 passes
- [ ] T033 [US5] Modify `lib/state/company_notifier.dart` (`splitCompany`) — when the original company has a non-null `midRoadDestination`, both `kept` and `splitOff` inherit the same `(currentNode, progress)` with `midRoadDestination` cleared (they are now stationary); confirm T031 passes

**Checkpoint**: Mid-road splits produce two offset, individually tappable markers. US5 complete.

---

## Phase 8: User Story 6 — Proximity Merge Between Nearby Friendly Companies (Priority: P4)

**Goal**: Two friendly companies within `kProximityMergeThreshold = 30.0` map-distance units trigger the existing merge-prompt dialog. The initiator auto-marches to the target; on arrival the merge executes. The merge cancels if either party enters battle or they drift beyond threshold.

**Independent Test**: Place two friendly companies 25 units apart on the same segment. Select one; tap the other. Confirm merge-prompt dialog appears. Confirm on dialog confirm the initiator has `proximityMergeIntent` set. Advance ticks until arrival; confirm one merged company exists at the target's position.

### Tests for User Story 6 ⚠️ Write and confirm FAILING before implementation

- [ ] T034 [P] [US6] Write failing tests for `ProximityMergeIntent` lifecycle in `test/domain/use_cases/tick_match_test.dart` — group `proximity merge`: (a) initiator arrives at target position → `MergeCompanies.merge` fires, initiator removed; (b) target moves within threshold each tick → initiator re-routes, merge eventually completes; (c) road distance exceeds threshold → merge cancelled, both independent; (d) either company gets `battleId` → merge cancelled; (e) co-located companies (progress match) → immediate merge, no march
- [ ] T035 [P] [US6] Write failing unit test in `test/domain/entities/game_map_test.dart` — `roadDistance` between two `RoadPosition` values on adjacent segments returns correct sum (already partially covered by T010-d/e; add cross-segment case explicitly)
- [ ] T036 [P] [US6] Write failing widget test in `test/widget/map_screen_road_tap_test.dart` — select company A (25 units from company B on same segment); tap company B → merge-prompt dialog appears; tap company B that is 50 units away → no dialog

### Implementation for User Story 6

- [ ] T037 [US6] Modify `lib/ui/screens/map_screen.dart` (`_onCompanyTap`) — when a company is already selected and the tapped company is friendly and on the road, compute `map.roadDistance` between them; if within `kProximityMergeThreshold` show `_showMergePrompt`; if beyond threshold do not show dialog (existing co-location check already covers `== 0` distance); confirm T036 passes
- [ ] T038 [US6] Modify `lib/state/company_notifier.dart` — add `initiateProximityMerge(String initiatorId, String targetId)` action: validates distance ≤ threshold, sets `proximityMergeIntent` on initiator, calls `setMidRoadDestination` to target's current road position; update `mergeCompanies` to handle proximity case (march destination set; do not execute merge immediately)
- [ ] T039 [US6] Modify `lib/domain/use_cases/tick_match.dart` — add `_resolveProximityMerges` step. **Tick pipeline order (critical)**: this step runs AFTER `_updateProximityMergeDestinations` (re-routes initiator to target's current position) and BEFORE `MoveCompany.advance`, so updated destinations are consumed in the same tick they are computed. Within `_resolveProximityMerges`: for each company with `proximityMergeIntent` check cancellation conditions (target gone, distance > threshold, either party in battle); on cancellation clear intent + set `destination = null`; on arrival call `MergeCompanies.merge` — **note**: `MergeCompanies.merge` currently requires `companyA.currentNode.id == companyB.currentNode.id`; when the initiator arrives at the target's mid-road position both companies share `currentNode` (the initiator snapped to the same node-checkpoint), so the precondition is satisfied. If the target is stationary mid-road at `progress > 0.0`, both companies will have the same `currentNode.id` after the initiator arrives — confirm this in the arrival-detection logic and add an assertion. Remove initiator after merge; confirm T034 passes

**Checkpoint**: Proximity merge complete, cancellable, and battle-safe. US6 complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Persistence, visual regression, analysis, and final validation

- [ ] T040 [P] Modify drift schema — add three new columns to the company table in `lib/data/tables/company_table.dart` (or the equivalent drift `.drift` file under `lib/data/`): `road_edge_id TEXT` (stores `RoadEdge.id = "${from.id}__${to.id}"`), `mid_road_progress REAL`, `mid_road_next_node_id TEXT` (intentionally denormalised from `road_edge_id` for query clarity — must stay in sync on write). Bump the drift schema migration to the next version number in `lib/data/app_database.dart` and add a migration step that defaults new columns to `NULL` for existing rows. Write a DAO round-trip test in `test/data/company_dao_test.dart` that inserts a `CompanyOnMap` with a non-null `midRoadDestination`, reads it back, and asserts `(road_edge_id, mid_road_progress, mid_road_next_node_id)` are bit-for-bit equal (SC-005 partial — DAO layer only)
- [ ] T040-b [P] Write integration test in `test/integration/mid_road_persistence_test.dart` — (1) create a `Match` with one company holding a non-null `midRoadDestination` at `progress = 0.4` on a known edge; (2) save the full game state via drift; (3) cold-rebuild `TickMatch` from the saved rows; (4) assert the company's `(currentNode.id, progress, midRoadDestination.currentNodeId, midRoadDestination.progress, midRoadDestination.nextNodeId)` is identical before and after; (5) advance one tick and confirm the company continues marching from the correct fractional position (SC-005 — full game-state round-trip)
- [ ] T041 [P] Create golden test in `test/golden/mid_road_company_marker_test.dart` — render two company markers at offset mid-road positions; assert pixel-level golden matches (SC-007 visual regression)
- [ ] T042 Run full `flutter test` suite — confirm zero failures across all 9 phases
- [ ] T043 Run `flutter analyze` — confirm zero issues (treat warnings as errors per constitution)
- [ ] T044 [P] Performance profiling — confirm 60 fps during 10 simultaneously marching companies (SC-006). Steps: (a) run `flutter run --profile` on a Snapdragon 665 device or emulator (or physical Pixel 4a as specified in plan.md); (b) use the reproducible scenario in `test/integration/` that deploys 10 player companies and issues mid-road march orders to all of them simultaneously; (c) open Flutter DevTools → Performance tab → record ≥ 10 seconds of active movement; (d) confirm **p99 raster frame time ≤ 16 ms** (no missed frames at 60 fps budget); (e) attach a DevTools Timeline screenshot to the PR description. Fail criterion: any raster frame > 16 ms at the p99 level during steady-state 10-company movement.
- [ ] T045 [P] Update `specs/004-road-free-movement/checklists/requirements.md` — mark all items complete; confirm SC-001 through SC-008 are satisfied

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └─▶ Phase 2 (Foundational — T004–T011)
        ├─▶ Phase 3 (US1 P1) ← START HERE for MVP
        ├─▶ Phase 4 (US2 P2) — depends on US1 complete (mid-road position must exist)
        ├─▶ Phase 5 (US3 P3) — independent of US1/US2 (castle validation only)
        ├─▶ Phase 6 (US4 P4) — depends on US1 (setMidRoadDestination must exist)
        ├─▶ Phase 7 (US5 P3) — depends on US1 + US2 (mid-road position + slot map)
        └─▶ Phase 8 (US6 P4) — depends on US1 + US2 (mid-road movement + roadDistance)
              └─▶ Phase 9 (Polish)
```

### User Story Dependencies

| Story | Depends On | Can Parallelise With |
|-------|-----------|---------------------|
| US1 (P1) | Phase 2 only | US3 |
| US2 (P2) | US1 | US3, US5 (after US1) |
| US3 (P3) | Phase 2 only | US1, US4 |
| US4 (P4) | US1 | US3 |
| US5 (P3) | US1 + US2 | US6 |
| US6 (P4) | US1 + US2 | US5 |

### Within Each Phase

- Tests MUST be written first and confirmed FAILING before implementation begins (Constitution Principle III)
- Within a phase, tasks marked `[P]` (tests and model files) can run in parallel
- Implementation tasks follow tests in each phase

---

## Parallel Execution Examples

### Foundational Phase (Phase 2) — Parallel Opportunities

```
Launch simultaneously:
  T004 road_position_test.dart (failing)
  T006 road_edge_test.dart (failing)
  T009 proximity_merge_intent.dart (new file)
  T010 game_map_test.dart (failing)

Then sequentially:
  T005 road_position.dart (makes T004 pass)
  T007 road_edge.dart (makes T006 pass)
  T008 check_collisions.dart CompanyOnMap fields
  T011 game_map.dart (makes T010 pass)
```

### User Story 1 (Phase 3) — Parallel Opportunities

```
Launch simultaneously (all failing tests):
  T012 move_company_test.dart (new group)
  T013 movement_rules_test.dart (new group)
  T014 map_screen_road_tap_test.dart (new file)

Then sequentially:
  T015 movement_rules.dart (makes T013 pass)
  T016 move_company.dart (makes T012 pass)
  T017 map_screen.dart (makes T014 pass)
  T018 company_notifier.dart
```

### User Stories 3 & 4 (Phases 5–6) — Fully Parallel with Each Other

```
After Phase 2:
  Developer A: Phase 5 (US3) — T024, T025
  Developer B: Phase 6 (US4) — T026, T027, T028, T029
```

---

## Implementation Strategy

### MVP Scope (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T011)
3. Complete Phase 3: User Story 1 (T012–T018)
4. **STOP and VALIDATE**: Player can tap a road segment; company marches to mid-road point; taps off-road are ignored
5. Demo / merge MVP branch

### Full Incremental Delivery

| Milestone | Phases | Deliverable |
|-----------|--------|-------------|
| MVP | 1–3 | Road tap → mid-road stop |
| Playable mid-road | 1–4 | Collision, selection, pass-through |
| Data integrity | 1–5 | Castle validation |
| Off-road guard | 1–6 | No company escapes road network |
| Split UX | 1–7 | Offset split markers |
| Proximity merge | 1–8 | Auto-march merge |
| Shippable | 1–9 | Persistence, golden tests, 60 fps |

---

## Notes

- All `[P]` tasks touch different files — no concurrent write conflicts
- Constitution Principle III is NON-NEGOTIABLE: tests MUST fail before implementation in every domain phase
- Commit after each task or logical group for clean git history
- Each story checkpoint is a valid demo/review point
- `kProximityMergeThreshold = 30.0`, `_kRoadSnapPixels = 20.0`, `_kNodeSnapPixels = 24.0` are the tuning constants from `research.md`; adjust after playtesting without touching logic
