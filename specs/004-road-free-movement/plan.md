# Implementation Plan: Road-Free Company Movement & Positioning

**Branch**: `004-road-free-movement` | **Date**: 2026-03-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-road-free-movement/spec.md`

## Summary

Companies can move to and be positioned at any point on a road segment — not only at named junctions or castles. A tap on any visible road pixel resolves to the nearest valid road coordinate; the company marches there and stops at the exact fractional progress value. A company stopped mid-road is fully playable: it is selectable, can be ordered onward, collides with enemies on the same segment, and participates in merges and splits. Castles are validated to always have road connections at map-build time. The feature extends the existing `currentNode + progress` model rather than replacing it — the destination field is widened to accept either a `MapNode` (existing path) or a mid-road `RoadPosition` (new fractional anchor). Proximity-based merge (initiating company auto-marches to meet the target) and mid-road split offset rendering complete the story.

## Technical Context

**Language/Version**: Dart 3.x (sound null-safety, no `dynamic`)  
**Primary Dependencies**: Flutter 3.x, flutter_riverpod (state), drift/SQLite (persistence), flutter_test + golden_toolkit (testing)  
**Storage**: `drift` (SQLite) for game state persistence (mid-road position stored as segment ID + fractional progress); `shared_preferences` for settings  
**Testing**: `flutter_test` for unit + widget tests; `integration_test` for end-to-end; `golden_toolkit` for visual regression  
**Target Platform**: Android 8.0+ (API 26+), iOS 15+  
**Project Type**: Mobile game (Flutter)  
**Performance Goals**: 60 fps on mid-range Android (Snapdragon 665) and iPhone XR; single tick ≤ 16 ms  
**Constraints**: Asset bundle ≤ 50 MB compressed; all tests pass on `flutter test`; zero `flutter analyze` warnings  
**Scale/Scope**: Single-player match; up to ~20 companies on map simultaneously; 6-node MVP map

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Notes |
|-----------|-------|-------|
| **I. Domain Model First** | ✅ PASS | All new entities (`RoadPosition`, `ProximityMergeIntent`, `RoadEdge.id`) and rules (`mid-road collision`, `proximity merge`) are pure Dart domain objects. Flutter widgets consume, never define, these rules. |
| **II. Layer Separation** | ✅ PASS | New types land in `lib/domain/entities/`, `lib/domain/rules/`, `lib/domain/use_cases/`. Hit-test coordinate resolution (screen → road point) lives in `lib/ui/` only. No game-rule logic enters any widget. |
| **III. Test-First (TDD)** | ✅ PASS | Red-Green-Refactor applies to every domain change. Failing tests for `RoadPosition`, mid-road `MovementRules`, `CheckCollisions` mid-road scenarios, `MoveCompany.setMidRoadDestination`, proximity-merge lifecycle, and `GameMap` castle validation must be written before implementation. |
| **IV. Frame Budget** | ✅ PASS | Hit-testing runs once per tap (not per frame); `_companyVisualPos` already interpolates fractional positions linearly — no structural change to the render loop required. `RepaintBoundary` guards remain in place. |
| **V. Simplicity & YAGNI** | ✅ PASS | Destination widening reuses the existing `currentNode + progress` representation. No new framework dependency introduced. Proximity threshold and snap radius are simple `const` values, not configurable systems. |

**Post-Design Re-evaluation**: ✅ PASS — See `research.md` and `data-model.md`. No new dependencies required beyond what already exists. All design decisions fit within current architecture.

## Project Structure

### Documentation (this feature)

```text
specs/004-road-free-movement/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
├── contracts/           ← Phase 1 output (internal — no public API; see note)
└── tasks.md             ← Phase 2 output (created by /speckit.tasks — NOT this command)
```

> **Contracts note**: Iron and Stone is a self-contained mobile game with no external API surface. The `contracts/` directory is intentionally omitted per the plan agent instructions ("Skip if project is purely internal").

### Source Code (repository root)

```text
lib/
├── domain/
│   ├── entities/
│   │   ├── road_edge.dart          MODIFY  add stable `id` field for persistence
│   │   └── game_map.dart           MODIFY  add castle-on-road validation + mid-road hit-test
│   │   └── game_map_fixture.dart   NO CHANGE  RoadEdge.id is computed in the constructor; no call-site edits needed
│   ├── value_objects/
│   │   └── road_position.dart      NEW     fractional road coordinate value object
│   ├── rules/
│   │   └── movement_rules.dart     MODIFY  extend advancePosition for mid-road destinations
│   └── use_cases/
│       ├── check_collisions.dart   MODIFY  add CompanyOnMap.roadSegmentId; mid-road collision
│       ├── move_company.dart       MODIFY  setMidRoadDestination; ProximityMergeIntent support
│       ├── merge_companies.dart    AUDIT   same-node precondition (line 52) is satisfied when proximity-merge initiator arrives; confirm in T039 — no code change anticipated
│       └── split_company.dart      no change (position is inherited)
│
├── state/
│   └── company_notifier.dart       MODIFY  proximity merge tick; mid-road slot map
│
└── ui/
    └── screens/
        └── map_screen.dart         MODIFY  road hit-test on tap; mid-road slot offsets;
                                            move-mode banner text update; proximity merge

test/
├── domain/
│   ├── entities/
│   │   └── game_map_test.dart      MODIFY  castle-validation tests (new)
│   ├── value_objects/
│   │   └── road_position_test.dart NEW     RoadPosition invariant tests
│   └── use_cases/
│       ├── move_company_test.dart  MODIFY  mid-road destination, FR-004, FR-005
│       ├── check_collisions_test.dart MODIFY mid-road collision scenarios, FR-006
│       └── merge_companies_test.dart  MODIFY proximity merge lifecycle, FR-014–FR-017
├── widget/
│   └── map_screen_road_tap_test.dart NEW   road tap → company marches to mid-road point
└── golden/
    └── mid_road_company_marker_test.dart NEW offset rendering at mid-road position
```

**Structure Decision**: Single Flutter mobile project. All domain changes follow existing `lib/domain/` layout. New value object `RoadPosition` is the only new file in the domain layer; all other changes are additive modifications to existing files.

## Complexity Tracking

> **No Constitution violations to justify.** All principles pass without exception.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | N/A — all 5 principles pass | — |
