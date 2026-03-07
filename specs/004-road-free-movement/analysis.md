<!-- speckit.analyze output — generated 2026-03-07 | remediated 2026-03-07 -->
# Specification Analysis Report
**Feature**: `004-road-free-movement`  
**Artifacts analysed**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `tasks.md`, `constitution.md`  
**Scope**: 17 functional requirements (FR-001–FR-017), 8 success criteria (SC-001–SC-008), 6 user stories (US1–US6), 45 tasks (T001–T045) + T040-b, 5 constitution principles

---

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation | Status |
|----|----------|----------|-------------|---------|----------------|--------|
| A-001 | **Duplication** | Low | T026 / T012-b | T026 is explicitly described as "already included in T012-b". It adds no new test logic — it only asks the implementer to confirm the prior test is still red. This is not a standalone task; it inflates the count and could cause confusion about whether a new test file must be opened. | Merge T026 into the Phase 6 checkpoint note. Remove T026 as a numbered task. Mark T012-b as also satisfying US4's off-road-segment guard. | Open |
| A-002 | **Duplication** | Low | T032 / T023 | T023 (Phase 4) and T032 (Phase 7) both say they modify `_buildSlotMap` in `company_notifier.dart` to add the composite mid-road grouping key. The descriptions are functionally identical. Implementing T032 after T023 would be a no-op, or worse, a conflicting double-edit. | Consolidate: T023 owns `_buildSlotMap` composite key. T032 is narrowed to `splitCompany` inheritance (the `midRoadDestination = null` reset) — that is genuinely separate work. Update T032 description to remove the `_buildSlotMap` change. | Open |
| A-003 | **Ambiguity** | Medium | T028 / T012-b / T016 | T028 was conditional — two possible outcomes depending on whether T016 already covered the validation. A task cannot be conditional. | Converted T028 to a checkpoint bullet under Phase 6. T026 converted to a confirmation-only gate (no new test file). | ✅ Fixed in `tasks.md` |
| A-004 | **Ambiguity** | Medium | plan.md `Complexity Tracking` | The Complexity Tracking table contained unedited template placeholder rows. | Removed placeholder rows; replaced with a single N/A row. | ✅ Fixed in `plan.md` |
| A-005 | **Underspecification** | High | T040 / FR-010 / plan.md | T040 lacked a specific drift file path, migration version, and had a column-naming conflict (`segment_id` conflated two concepts). | T040 expanded with exact file paths (`lib/data/tables/company_table.dart`, `lib/data/app_database.dart`, `test/data/company_dao_test.dart`), migration version bump instruction, and corrected column names (`road_edge_id`, `mid_road_progress`, `mid_road_next_node_id`). `data-model.md` persistence schema updated to match. | ✅ Fixed in `tasks.md` + `data-model.md` |
| A-006 | **Underspecification** | Medium | T044 / SC-006 | T044 had no device model, no pass/fail metric, and no reproducible scenario. | T044 expanded: device = Snapdragon 665 / Pixel 4a; metric = p99 raster frame time ≤ 16 ms in Flutter DevTools Timeline; scenario = integration test that deploys 10 companies simultaneously. | ✅ Fixed in `tasks.md` |
| A-007 | **Coverage Gap** | High | FR-010 / SC-005 | No task tested the full save → restore → resume-tick cycle. T040 only covered DAO insert/read. | Added T040-b: integration test in `test/integration/mid_road_persistence_test.dart` covering full game-state round-trip including a post-restore tick continuation assertion. | ✅ Fixed in `tasks.md` |
| A-008 | **Coverage Gap** | Medium | FR-016 / T039 | T039 did not specify that `_resolveProximityMerges` must run before `MoveCompany.advance`, risking a one-tick lag in destination re-evaluation. | T039 updated with explicit tick pipeline order: `_updateProximityMergeDestinations` → `_resolveProximityMerges` → `MoveCompany.advance`. | ✅ Fixed in `tasks.md` |
| A-009 | **Coverage Gap** | Low | plan.md Project Structure | `game_map_fixture.dart` was marked `MODIFY` but `RoadEdge.id` is computed automatically — no call-site edit is needed. | Annotation changed to `NO CHANGE` with explanatory note. | ✅ Fixed in `plan.md` |
| A-010 | **Coverage Gap** | Medium | plan.md / tasks.md | `merge_companies.dart` was marked `MODIFY` but no task modified it. The same-node precondition on line 52 of `merge_companies.dart` could reject proximity-merge arrivals at mid-road positions. | T039 updated with explicit note: both companies share `currentNode.id` on arrival so the precondition is satisfied; arrival-detection logic must assert this. plan.md annotation changed from `MODIFY` to `AUDIT`. | ✅ Fixed in `tasks.md` + `plan.md` |
| A-011 | **Constitution Alignment** | Low | T015 / `movement_rules.dart` | `kProximityMergeThreshold` in `movement_rules.dart` governs merge eligibility, not movement — semantic mismatch. | Low priority — no change required now. If a `MergeRules` type is introduced later, move the constant there. Add a one-line comment when implementing T015. | Open |
| A-012 | **Inconsistency** | Medium | data-model.md §1 / T004 | T004 described the valid progress range as `[0.0, 0.999]` (closed at 0.999), which would reject `progress = 0.9999` — wrong. Spec and data-model both say `[0.0, 1.0)`. | T004 updated to `[0.0, 1.0)`. T005 updated to use `progress >= 1.0 || progress < 0.0` as the rejection condition. | ✅ Fixed in `tasks.md` |
| A-013 | **Inconsistency** | Low | data-model.md §1 persistence | `segment_id` naming conflated `RoadEdge.id` semantics; `next_node_id` denormalisation was undocumented. | Columns renamed to `road_edge_id`, `mid_road_progress`, `mid_road_next_node_id` with explicit denormalisation comment. | ✅ Fixed in `data-model.md` (covered by A-005) |

---

## Coverage Summary

| User Story | FR Coverage | SC Coverage | Tasks | Status |
|------------|-------------|-------------|-------|--------|
| US1 — Road tap destination | FR-001, FR-002, FR-003, FR-004, FR-005 | SC-001, SC-003 | T012–T018 | ✅ Fully covered |
| US2 — Mid-road validity | FR-006, FR-007, FR-011, FR-012 | SC-003, SC-004 | T019–T023 | ✅ Fully covered |
| US3 — Castle road constraint | FR-008, FR-009 | SC-002 | T010, T011, T024, T025 | ✅ Fully covered (see A-009) |
| US4 — No off-road positions | FR-001, FR-003 | SC-003 | T026–T029 | ✅ Covered (A-003 reduces T026/T028 to checkpoints) |
| US5 — Mid-road split offsets | FR-012, FR-013 | SC-007 | T030–T033 | ✅ Fully covered (A-002 adjusts T032 scope) |
| US6 — Proximity merge | FR-014–FR-017 | SC-008 | T034–T039 | ✅ Covered (A-008 adds tick-order note) |
| Cross-cutting | FR-010, FR-011 | SC-005, SC-006 | T040–T045 | ⚠️ Partially covered (A-005, A-006, A-007) |

---

## Constitution Alignment

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain Model First | ✅ PASS | All new types (`RoadPosition`, `ProximityMergeIntent`) are pure Dart. Hit-test logic stays in `lib/ui/`. No domain-layer Flutter imports introduced. |
| II. Layer Separation | ✅ PASS | `_hitTestRoad` and snap constants live in `map_screen.dart`; domain types have no awareness of canvas pixels. |
| III. Test-First (TDD) | ✅ PASS | Every domain phase has a dedicated failing-test task preceding implementation. Red-Green-Refactor sequence is explicit. See A-007 for the one coverage gap in integration testing. |
| IV. Frame Budget | ✅ PASS | Hit-test runs once per tap. `_companyVisualPos` interpolation unchanged. No per-frame allocation added. See A-006 for underspecified profiling methodology. |
| V. Simplicity & YAGNI | ✅ PASS | Existing model extended, not replaced. One new value object (`RoadPosition`), one new entity (`ProximityMergeIntent`). No new dependencies. See A-011 (constant placement) — low risk. |

---

## Unmapped Tasks

All 45 tasks map to at least one requirement, user story, or success criterion. No orphan tasks detected.

| Task | Mapped To |
|------|-----------|
| T001–T003 | Setup / quality gate (no FR, cross-cutting SC) |
| T040 | FR-010, SC-005 |
| T041 | SC-007 (golden regression) |
| T042–T043 | Constitution quality gates |
| T044 | SC-006 |
| T045 | All SC-001–SC-008 (requirements checklist) |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total functional requirements | 17 (FR-001–FR-017) |
| Total success criteria | 8 (SC-001–SC-008) |
| Total tasks | 46 (T001–T045 + T040-b) |
| FR coverage | 17 / 17 = **100%** |
| SC coverage | 8 / 8 = **100%** |
| Constitution principles | 5 / 5 PASS |
| Findings total | 13 (A-001–A-013) |
| Findings resolved | 9 (A-003, A-004, A-005, A-006, A-007, A-008, A-009, A-010, A-012, A-013) |
| Findings open | 3 (A-001, A-002, A-011 — all Low severity) |

---

## Next Actions

**All High and Medium findings have been remediated.** The following Low-severity findings remain open for optional cleanup:

1. **[A-001 — Low]** T026 is still a numbered task (now a confirmation-only gate). Can be removed entirely and folded into the T012-b annotation if preferred.
2. **[A-002 — Low]** T032 still mentions `_buildSlotMap` — narrow its scope to `splitCompany` inheritance only (remove the `_buildSlotMap` change already owned by T023).
3. **[A-011 — Low]** Add a one-line comment to `kProximityMergeThreshold` in `movement_rules.dart` at implementation time of T015 noting it drives merge eligibility, not movement.

---

*Offer*: I can apply the remaining Low-severity remediations (A-001, A-002). Reply with the finding IDs or say "fix all remaining".
