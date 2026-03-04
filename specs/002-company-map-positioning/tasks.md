# Tasks: Company Map Positioning — Stacking & Overlap Resolution

**Input**: Design documents from `specs/002-company-map-positioning/`  
**Branch**: `002-company-map-positioning` | **Date**: 2026-03-03  
**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.  
**TDD Approach**: Tests are written **FIRST** per Constitution Principle III (Red-Green-Refactor is non-negotiable for domain changes).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1 – US4)
- Exact file paths are included in all descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify project health and confirm existing file locations before making changes.

- [X] T001 Confirm existing file locations: `lib/domain/use_cases/check_collisions.dart`, `lib/state/company_notifier.dart`, `lib/ui/screens/map_screen.dart`, `lib/ui/screens/castle_screen.dart`, `lib/ui/widgets/company_marker.dart`
- [X] T002 [P] Confirm existing test locations: `test/domain/use_cases/check_collisions_test.dart`, `test/widget/`, `test/golden/`
- [X] T003 Run `flutter analyze` from repo root and confirm zero issues before any changes

**Checkpoint**: Existing file paths confirmed — ready to begin foundational work

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain value object that ALL user stories depend on for offset slot management.

**⚠️ CRITICAL**: All user story work (especially US1 and US3) depends on `NodeOccupancy` being present and tested.

### TDD: Tests First ⚠️ — Write these BEFORE any implementation; confirm they FAIL

- [X] T004 Write failing unit test: `NodeOccupancy` construction with `nodeId` and empty `orderedIds` in `test/domain/value_objects/node_occupancy_test.dart` [NEW FILE]
- [X] T005 [P] Write failing unit test: `withArrival` appends id and is idempotent (no-op if already present) in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T006 [P] Write failing unit test: `withDeparture` removes id and compacts remaining ids (order preserved, no gaps) in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T007 [P] Write failing unit test: `slotIndex` returns correct 0-based index or `null` if absent in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T008 [P] Write failing unit test: `contains` returns `true`/`false` correctly in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T009 [P] Write failing unit test: departure and re-arrival produces correct compacted order in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T010 [P] Write failing unit test: `_deriveOccupancy` helper sorts stationary companies lexicographically by id (cold-start determinism) in `test/domain/value_objects/node_occupancy_test.dart`

### Implementation

- [X] T011 Implement `NodeOccupancy` value object (immutable, pure Dart, no Flutter imports) in `lib/domain/value_objects/node_occupancy.dart` [NEW FILE] — fields: `nodeId`, `orderedIds`; methods: `withArrival`, `withDeparture`, `slotIndex`, `contains`
- [X] T012 Run `flutter test test/domain/value_objects/node_occupancy_test.dart` and confirm ALL tests pass (Green)
- [X] T013 Add `nodeOccupancy` field (`Map<String, NodeOccupancy>`) to `CompanyListState` and update `copyWith` in `lib/state/company_notifier.dart`; default value is `const {}`
- [X] T014 Implement `_deriveOccupancy` helper and `_isStationary` predicate in `lib/state/company_notifier.dart` (these live in the state layer; `NodeOccupancy` construction via sorted-by-id approach from data-model.md §1)
- [X] T015 Run `flutter analyze` and confirm zero issues

**Checkpoint**: `NodeOccupancy` is green-tested and available in state — user stories can now proceed

---

## Phase 3: User Story 1 — Select Any Company at a Road Junction Node (Priority: P1) 🎯 MVP

**Goal**: When two or more companies are at the same road junction node, all are individually tappable — no company is hidden beneath another. Visual offset markers ensure each has its own 44 × 44 pt touch target.

**Independent Test**: Place two companies (one player, one AI) on the same road junction node. Both companies must be individually tappable and open their respective action panel.

### TDD: Tests First ⚠️ — Write these BEFORE implementation; confirm they FAIL

- [X] T016 [US1] Write failing widget test: two companies at the same node each render at distinct `Positioned` offsets (not identical `left`/`top`) in `test/widget/map_screen_offset_test.dart` [NEW FILE]
- [X] T017 [P] [US1] Write failing widget test: tapping the first company fires `onTap` for company A and NOT company B in `test/widget/map_screen_offset_test.dart`
- [X] T018 [P] [US1] Write failing widget test: tapping the second company fires `onTap` for company B and NOT company A in `test/widget/map_screen_offset_test.dart`
- [X] T019 [P] [US1] Write failing widget test: three companies at the same node each have distinct offset positions in `test/widget/map_screen_offset_test.dart`
- [X] T020 [P] [US1] Write failing golden test: 2 companies at same node render at correct slot-0 (centre) and slot-1 (right) positions in `test/golden/map_node_offset_golden_test.dart` [NEW FILE]
- [X] T021 [P] [US1] Write failing golden test: 3 companies at same node render at slot-0, slot-1, slot-2 positions in `test/golden/map_node_offset_golden_test.dart`
- [X] T022 [P] [US1] Write failing golden test: 5 companies at same node render at all 5 slot positions in `test/golden/map_node_offset_golden_test.dart`
- [X] T022a [P] [US1] Write failing widget test: an in-transit company at a node renders with the in-transit visual style (distinct from stationary — e.g., reduced opacity, dashed border, or motion indicator) in `test/widget/map_screen_offset_test.dart` — covers FR-008
- [X] T022b [P] [US1] Write failing widget test: when a player company is already selected and the player taps a second same-owner company at the same node, the merge prompt is presented (not suppressed by offset UI) in `test/widget/map_screen_offset_test.dart` — covers FR-011

### Implementation

- [X] T023 [US1] Update `CompanyMarker` to enforce 44 × 44 pt minimum tap target: wrap existing `RepaintBoundary > GestureDetector > _buildMarker()` in `SizedBox(width: 44, height: 44)`; set `HitTestBehavior.opaque` on `GestureDetector`; centre the 36 × 36 visual circle with `Center` in `lib/ui/widgets/company_marker.dart`
- [X] T023a [US1] Implement in-transit visual distinction in `lib/ui/widgets/company_marker.dart`: when `company.destination != null && company.destination!.id != company.currentNode.id`, render the marker with a distinct style (e.g., `Opacity(opacity: 0.65)` wrapper or dashed border) to satisfy FR-008; update `_buildMarker()` to branch on transit state
- [X] T024 [US1] Add `_kSlotOffsets` compile-time constant list (`List<(double dx, double dy)>`) with entries for slots 0–4 **plus a slot-5+ spiral extension** (additional entries at Δ20 increments: `(-20,-20)`, `(20,-20)`, `(-20,20)`, `(20,20)`, continuing outward) to `lib/ui/screens/map_screen.dart` — satisfies FR-003 (≥5 companies, extended pattern)
- [X] T025 [US1] Add `_offsetForCompany` private pure function to `lib/ui/screens/map_screen.dart`: accepts `CompanyOnMap` and `Map<String, NodeOccupancy>`, returns `(double dx, double dy)` from the slot table (returns `(0, 0)` for in-transit companies)
- [X] T026 [US1] Update `_buildMap` company marker loop in `lib/ui/screens/map_screen.dart` to: call `_offsetForCompany`, wrap `CompanyMarker` in `SizedBox(width: 44, height: 44)`, apply offset to `Positioned` (`left: cx + ox - 22`, `top: cy + oy - 22`)
- [X] T027 [US1] Implement `nodeOccupancy` lifecycle events in `lib/state/company_notifier.dart`: `deployCompany` calls `withArrival`; `setDestination` (when company was stationary) calls `withDeparture`; update `advanceTick` to call `_deriveOccupancy` at the end of its tick pass for all nodes that had stationary changes (this is the `_onTickReconcile` step — it is NOT a new public method; it augments `advanceTick` inline)
- [X] T028 [US1] Run `flutter test test/widget/map_screen_offset_test.dart` and confirm all tests pass
- [X] T029 [US1] Run `flutter test test/golden/map_node_offset_golden_test.dart` and update goldens if needed (`--update-goldens`); confirm visual output matches spec slot table
- [X] T030 [US1] Run `flutter analyze` and confirm zero issues

**Checkpoint**: US1 complete — all companies at a road junction node are individually tappable ✅

---

## Phase 4: User Story 2 — Select Any Company Inside a Castle (Priority: P2)

**Goal**: Tapping a player-owned castle shows a roster of all garrisoned companies; each is individually selectable to become the active (front) company. Tapping an enemy/neutral castle shows a read-only defender count.

**Independent Test**: Place two or more player companies inside one castle. A visible roster must allow individual selection of each. Tapping an enemy castle must show total soldier count only — no action options.

### TDD: Tests First ⚠️ — Write these BEFORE implementation; confirm they FAIL

- [X] T031 [US2] Write failing widget test: tapping a player castle with two garrisoned companies shows a roster widget listing both companies in `test/widget/castle_screen_roster_test.dart` [NEW FILE]
- [X] T032 [P] [US2] Write failing widget test: selecting a company from the roster triggers selection of that company (not the other) in `test/widget/castle_screen_roster_test.dart`
- [X] T033 [P] [US2] Write failing widget test: dismissing the roster without selection triggers no company action in `test/widget/castle_screen_roster_test.dart`
- [X] T034 [P] [US2] Write failing widget test: tapping an enemy castle shows a read-only summary with total soldier count (no roster, no action buttons) in `test/widget/castle_screen_roster_test.dart`
- [X] T035 [P] [US2] Write failing widget test: garrisoned companies and defending companies are visually distinguishable in the roster in `test/widget/castle_screen_roster_test.dart`

### Implementation

- [X] T036 [US2] Update `castle_screen.dart` — player-owned castle path: update `_CompaniesCard` (or equivalent widget) to make each garrisoned company row individually tappable; tapping a row selects that company as the "front" company (navigates back to map with that company selected, or opens deploy/compose sheet); highlight the currently active front company with a visual indicator (e.g., gold border); use ephemeral local `int _frontIndex` state (no Riverpod) in `lib/ui/screens/castle_screen.dart`
- [X] T037 [US2] Update `map_screen.dart` — enemy/neutral castle path in `_showCastleSheet`: in the non-`isPlayerCastle` branch, replace the `'Companies stationed: $stationedCount'` text with an explicit `totalDefenders` calculation (sum of `totalSoldiers.value` for all stationary companies at the castle node) displayed as `"Defenders: $totalDefenders soldiers"`; the branch already has no action buttons — do NOT add or remove any in `lib/ui/screens/map_screen.dart`
- [X] T038 [US2] Run `flutter test test/widget/castle_screen_roster_test.dart` and confirm all tests pass
- [X] T039 [US2] Run `flutter analyze` and confirm zero issues

**Checkpoint**: US2 complete — castle garrison roster is functional; enemy castle shows read-only summary ✅

---

## Phase 5: User Story 3 — Companies Arriving Later at an Occupied Node Are Offset (Priority: P3)

**Goal**: When a company arrives at a node already occupied by stationary companies, it is placed at a visually offset position (not stacked). All companies remain individually tappable at all times.

**Independent Test**: Send a second player company to a node already occupied by a first company. The second company's marker must appear at a visually distinct offset position. Both must be tappable.

*Note*: The core rendering mechanism for this story is already delivered by Phase 2 (NodeOccupancy) + Phase 3 (offset rendering in map_screen). This phase focuses on validating the **dynamic arrival/departure lifecycle** — that markers reflow correctly as companies arrive and depart at runtime.

### TDD: Tests First ⚠️ — Write these BEFORE implementation; confirm they FAIL

- [X] T040 [US3] Write failing unit test (state layer) [MODIFY EXISTING FILE]: calling `deployCompany` for a second company at an already-occupied node results in `nodeOccupancy[nodeId].orderedIds` containing both company IDs with the second at index 1 in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T041 [P] [US3] Write failing unit test (state layer) [MODIFY EXISTING FILE]: when the first company departs (setDestination called), the second company compacts to slot 0 in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T042 [P] [US3] Write failing unit test (state layer) [MODIFY EXISTING FILE]: three companies arrive sequentially; after the middle one departs, the remaining two occupy slots 0 and 1 (no gaps) in `test/domain/value_objects/node_occupancy_test.dart`
- [X] T043 [P] [US3] Write failing widget test: a company marker that has compacted from slot 1 to slot 0 renders at `(0, 0)` offset in `test/widget/map_screen_offset_test.dart`

### Implementation

- [X] T044 [US3] Update `mergeCompanies` in `lib/state/company_notifier.dart` to call `withDeparture(b)` (absorbed company) and `withArrival(a)` (merged company) on the node's `NodeOccupancy` entry; run `test/domain/value_objects/node_occupancy_test.dart` to confirm T040–T042 lifecycle tests pass after merge
- [X] T045 [US3] Update `splitCompany` in `lib/state/company_notifier.dart` to call `withDeparture(original)` and two `withArrival` calls for the two new company IDs on the node's `NodeOccupancy` entry; run `test/domain/value_objects/node_occupancy_test.dart` to confirm both new companies receive distinct, non-overlapping slots
- [X] T046 [US3] Run `flutter test test/domain/value_objects/node_occupancy_test.dart` and confirm all arrival/departure lifecycle tests pass
- [X] T047 [US3] Run `flutter test test/widget/map_screen_offset_test.dart` and confirm compaction rendering tests pass
- [X] T048 [US3] Run `flutter analyze` and confirm zero issues

**Checkpoint**: US3 complete — arriving/departing companies reflow correctly; all offset positions remain tappable ✅

---

## Phase 6: User Story 4 — Friendly Companies Passing Through an Occupied Node Are Not Blocked (Priority: P4)

**Goal**: A player company whose route passes through a node occupied only by friendly (same-owner) companies moves through without stopping or triggering a collision. Enemy companies still trigger a battle.

**Independent Test**: Park a player company at an intermediate node. Order a second player company to march through to a further destination — it must pass through unblocked. Verify an AI company marching through a player-occupied node triggers a battle.

### TDD: Tests First ⚠️ — Write these BEFORE implementation; confirm they FAIL

- [X] T049 [US4] Write failing unit test: `CheckCollisions` — in-transit same-owner company at a node occupied only by friendly stationary companies → no `roadCollision` returned in `test/domain/use_cases/check_collisions_test.dart` [MODIFY EXISTING]
- [X] T050 [P] [US4] Write failing unit test: `CheckCollisions` — in-transit enemy company at a node occupied by a stationary player company → `roadCollision` triggered in `test/domain/use_cases/check_collisions_test.dart`
- [X] T051 [P] [US4] Write failing unit test: `CheckCollisions` — in-transit player company at a node occupied by a stationary enemy company → `roadCollision` triggered in `test/domain/use_cases/check_collisions_test.dart`
- [X] T052 [P] [US4] Write failing unit test: stationary company at a node is NOT displaced/merged when a friendly in-transit company passes through in `test/domain/use_cases/check_collisions_test.dart`
- [X] T053 [P] [US4] Write failing unit test: `_isStationary` correctly classifies companies (null destination → stationary; destination == currentNode → stationary; destination ≠ currentNode → in transit) in `test/domain/use_cases/check_collisions_test.dart`

### Implementation

- [X] T054 [US4] Update `CheckCollisions` use case in `lib/domain/use_cases/check_collisions.dart`: add `_isStationary(CompanyOnMap)` and `_isInTransit(CompanyOnMap)` private helpers; update the node-grouping collision loop to skip triggering `roadCollision` when an in-transit company shares a node **only** with same-owner companies; retain `roadCollision` trigger when an in-transit company shares a node with any opposing company (stationary or in-transit)
- [X] T055 [US4] Run `flutter test test/domain/use_cases/check_collisions_test.dart` and confirm ALL tests pass (including pre-existing tests — no regressions)
- [X] T056 [US4] Run `flutter test` (full suite) and confirm all tests pass
- [X] T057 [US4] Run `flutter analyze` and confirm zero issues

**Checkpoint**: US4 complete — same-owner pass-through works; enemy intercept still triggers battle ✅

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final integration validation, performance check, and cleanup across all stories.

- [X] T058 [P] Run full test suite `flutter test` and confirm all tests pass (domain, widget, golden, integration)
- [X] T059 [P] Run `flutter analyze` — zero issues (treat warnings as errors per CI gate)
- [ ] T060 Profile map rendering with Flutter DevTools: confirm 60 fps on target device; capture DevTools screenshot as PR evidence (Constitution Principle IV)
- [X] T061 [P] Verify `RepaintBoundary` is still present at `CompanyMarker` boundaries after all widget changes in `lib/ui/widgets/company_marker.dart`
- [X] T062 [P] Verify all `CompanyMarker` instances have `SizedBox(width: 44, height: 44)` — no instance uses a smaller box in `lib/ui/screens/map_screen.dart`
- [X] T063 Update `specs/002-company-map-positioning/checklists/requirements.md` to mark implementation complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — **BLOCKS all user stories**
- **US1 (Phase 3)**: Depends on Phase 2 — renders `NodeOccupancy` slot indices
- **US2 (Phase 4)**: Depends on Phase 2 — independent of US1
- **US3 (Phase 5)**: Depends on Phase 2 + Phase 3 — validates dynamic lifecycle of offset rendering
- **US4 (Phase 6)**: Depends on Phase 2 — fully independent of US1/US2/US3 (pure domain change)
- **Polish (Phase 7)**: Depends on all desired stories complete

### User Story Dependencies

| Story | Depends On | Independent Of |
|-------|-----------|----------------|
| US1 (P1) | Phase 2 (`NodeOccupancy`) | US2, US4 |
| US2 (P2) | Phase 2 (`NodeOccupancy`) | US1, US3, US4 |
| US3 (P3) | Phase 2 + Phase 3 (rendering in map_screen) | US2, US4 |
| US4 (P4) | Phase 2 (`_isStationary` predicate) | US1, US2, US3 |

### Within Each User Story

1. Tests MUST be written and confirmed **FAILING** before implementation (Constitution III)
2. Domain changes before state changes before UI changes
3. Confirm all story tests pass (Green) before moving to next phase
4. Run `flutter analyze` — zero issues before each checkpoint

---

## Parallel Opportunities

### Phase 2 (Foundational) — TDD tests in parallel

```
T004  → T011 (implement NodeOccupancy) — sequential
T005, T006, T007, T008, T009, T010 — all parallel after T004
```

### Phase 3 (US1) — after T015 (foundation green)

```
T016  → T023 (CompanyMarker tap target) — parallel with T024, T025
T017, T018, T019, T022a, T022b — parallel (same test file, different test cases)
T020, T021, T022 — parallel (golden tests, same file)
T023a (in-transit visual) — parallel with T023, T024, T025
T024 (_kSlotOffsets, incl. slot 5+ extension) — parallel with T023
T025 (_offsetForCompany) — parallel with T023
T026 (_buildMap update) — depends on T024, T025
T027 (state lifecycle, advanceTick reconcile) — parallel with T023–T025
```

### Phase 4 (US2) — parallel with Phase 3 after Phase 2

```
T031, T032, T033, T034, T035 — parallel (widget tests)
T036 (castle roster) — parallel with T037 (enemy summary)
```

### Phase 6 (US4) — parallel with Phase 4 after Phase 2

```
T049–T053 — all parallel (unit tests, same file)
T054 — implement after tests fail
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational — `NodeOccupancy` (T004–T015) — **CRITICAL**
3. Complete Phase 3: US1 — offset rendering on map (T016–T030)
4. **STOP and VALIDATE**: tap both companies at a shared node independently
5. Deploy/demo as MVP

### Incremental Delivery

| Stage | Phases | Deliverable |
|-------|--------|-------------|
| Foundation | 1–2 | `NodeOccupancy` tested; state ready |
| MVP | +3 | All companies tappable at road nodes ✅ |
| Castle UX | +4 | Garrison roster + enemy read-only summary ✅ |
| Arrival reflow | +5 | Dynamic compaction on arrival/departure ✅ |
| Pass-through | +6 | Friendly pass-through; enemy battle intercept ✅ |
| Polish | +7 | Full CI green; performance evidence ✅ |

### Single-Developer Sequence

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → Phase 7
```

### Two-Developer Parallel Strategy

```
Developer A: Phase 1 → Phase 2 → Phase 3 → Phase 5 → Phase 7
Developer B:           (wait Phase 2) → Phase 4 (parallel) → Phase 6 (parallel) → Phase 7
```

---

## Notes

- **[P]** tasks operate on different files or independent test cases — safe to run in parallel
- **[USn]** label maps each task to its spec user story for traceability
- Constitution Principle III is non-negotiable: every test task MUST produce a **failing** test before its paired implementation task begins
- All `flutter analyze` gates are mandatory — zero warnings, zero issues; per-phase gates are development checkpoints; T058/T059 are the PR merge gate
- Commit after each checkpoint (one commit per phase or per logical group within a phase)
- The `_kSlotOffsets` table and `_offsetForCompany` function are UI-layer only; `NodeOccupancy` must never import Flutter
- Golden tests may require `--update-goldens` on first run; review output against `_kSlotOffsets` visually before accepting; then run `--update-goldens` and commit baselines
- **Enemy/neutral castle read-only summary** lives exclusively in `_showCastleSheet` in `map_screen.dart` (T037). `castle_screen.dart` is modified only for the player-owned roster (T036) — there is no enemy path in `castle_screen.dart`
- **`_onTickReconcile`** is not a new public method — it refers to the occupancy re-derivation step added inside `advanceTick` (T027)
- T040–T042 add tests to the existing `test/domain/value_objects/node_occupancy_test.dart` file created in T004 — they do NOT create a new file
