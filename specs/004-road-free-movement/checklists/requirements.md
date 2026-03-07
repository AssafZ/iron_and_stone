# Specification Quality Checklist: Road-Free Company Movement & Positioning

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: March 7, 2026
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- All items pass. Specification is ready for `/speckit.plan`.
- Snap-radius constant and proximity-merge threshold are intentionally deferred to the planning phase (noted in Assumptions).
- The `RoadPosition` entity concept replaces the current `currentNode + progress` model — this scope decision is documented in Assumptions and Functional Requirements.
- **Updated March 7, 2026**: Added User Story 5 (mid-road split offset rendering, FR-013, SC-007) and User Story 6 (proximity merge with march-to-merge, FR-014–FR-017, SC-008) following user feedback. `ProximityMergeIntent` entity added to Key Entities. All checklist items remain passing.

## Success Criteria Completion (Phase 9)

| Criterion | Description | Status |
|-----------|-------------|--------|
| SC-001 | Player taps road segment, company reaches exact point within snap tolerance | ✅ Satisfied — `setMidRoadDestination` + tap-to-road-position in `map_screen.dart`; verified by T017–T020 widget tests |
| SC-002 | 100% of castle nodes have ≥1 road edge | ✅ Satisfied — `GameMapFixture` and `MovementRules.isValidPath` enforce this; verified by T003, T005 |
| SC-003 | 0% of companies at off-road positions | ✅ Satisfied — all positions are either `progress=0` (at node) or `(currentNode, nextNodeId, progress)` on a valid edge; invariant upheld by `MoveCompany.advance` |
| SC-004 | Collision/battle-trigger extends to mid-road positions | ✅ Satisfied — `CheckCollisions` handles mid-road segment collisions; verified by T025–T030 |
| SC-005 | Mid-road position survives full save/restore cycle with zero drift | ✅ Satisfied — `midRoadCurrentNodeId`, `midRoadNextNodeId`, `midRoadProgress` columns added in schema v3; verified by T040, T040-b |
| SC-006 | 60 fps with 10 marching companies on mid-range device | ⏳ Pending — manual Flutter DevTools profiling (T044, requires physical device) |
| SC-007 | Both split companies individually tappable after road split | ✅ Satisfied — slot-based offset system + `roadSlotKey`; verified by golden tests T041, T031–T033 widget tests |
| SC-008 | Proximity merge completes correctly in 100% of cases without battle intervention | ✅ Satisfied — `_resolveProximityMerges` in `TickMatch`; verified by T034 (a)–(e) |
