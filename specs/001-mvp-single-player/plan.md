# Implementation Plan: Iron & Stone MVP — Single-Player Mode│   └── entities/
│   │   ├── unit_role.dart           # Enum: Peasant|Warrior|Knight|Archer|Catapult + stats (HP, DMG, speed, range, special)
│   │   ├── company.dart             # ≤50 soldiers, role composition map, derived movement speed; garrison is flat pool Map<UnitRole,int>
│   │   ├── castle.dart              # Garrison reservoir (flat Map<UnitRole,int>), ownership, cap, growth rate, Peasant bonus
│   │   ├── map_node.dart            # Node type (castle | road_junction), position
│   │   ├── road_edge.dart           # Directed edge connecting two MapNodes
│   │   ├── game_map.dart            # Graph: nodes + edges, path resolution
│   │   ├── game_map_fixture.dart    # Hardcoded fixed match map: 4–8 castle nodes + road edges + starting positions; used by MatchNotifier.newGame()
│   │   ├── battle.dart              # Participants, round state, round log, outcome (includes draw outcome)
│   │   └── match.dart               # Session: map, players, win condition, elapsed timeh**: `001-mvp-single-player` | **Date**: 2026-03-02 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-mvp-single-player/spec.md`

## Summary

Build a complete single-player mobile match loop for Iron & Stone: a medieval macro-strategy game where one human player faces one AI opponent on a fixed medieval map. The player deploys Companies of up to 50 soldiers from a castle garrison, marches them along road paths, and fights simultaneous-round battles with unit-role–based damage until one side controls all castles (Total Conquest). The AI autonomously deploys, marches, and attacks.

Technical approach: pure Dart domain layer (game rules, entities, battle engine) written and fully unit-tested first — before any Flutter widget is written — then layered with Riverpod state management and a Flutter UI. `drift` provides local SQLite match persistence. The domain layer has zero Flutter dependencies and is fully headless-testable.

## Technical Context

**Language/Version**: Dart 3.x (sound null-safety required; no `dynamic` without justification in PR)  
**Framework**: Flutter 3.x — iOS and Android targets only; no web or desktop in v1  
**Primary Dependencies**: `flutter_riverpod` (state management), `drift` (SQLite game state), `shared_preferences` (settings)  
**Storage**: `drift` (SQLite) for match state; `shared_preferences` for app settings  
**Testing**: `flutter_test` (unit + widget), `integration_test` (end-to-end flows), `golden_toolkit` (visual regression on critical tactical UI)  
**Target Platform**: Android 8.0+ (API 26+), iOS 15+  
**Project Type**: Mobile game app  
**Performance Goals**: 60 fps on mid-range Android (Snapdragon 665, ≥2 GB RAM) and iOS (iPhone XR / iOS 15+); single game-loop tick ≤ 16 ms on the Dart VM  
**Constraints**: Asset bundle ≤ 50 MB compressed at first install; offline-only (no remote backend in v1); map rendering must not rebuild unchanged cells (`const` constructors + `RepaintBoundary` at castle/Company boundaries)  
**Scale/Scope**: Fixed single map (4–8 castles), 2 players (1 human + 1 AI), 5 unit roles, Companies of ≤ 50 soldiers, castle garrison cap 250 units

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | **Domain Model First** — all game rules (Company movement, battle resolution, castle capture, garrison growth) MUST live in pure Dart classes before any Flutter widget is written | ✅ PASS | Domain layer (`lib/domain/`) is the first deliverable; `battle_engine.dart`, `movement_rules.dart`, `growth_engine.dart`, etc. are framework-free Dart only |
| II | **Widget & Layer Separation** — domain in `lib/domain/`, state in `lib/state/`, UI in `lib/ui/`, data in `lib/data/`; game-rule logic MUST NOT appear inside widgets | ✅ PASS | Project structure below enforces all four layers with explicit directory boundaries |
| III | **Test-First for Game Rules** — Red-Green-Refactor TDD for every domain change; widget tests for every interactive screen flow; golden tests for map rendering and battle side-view | ✅ PASS | Phase 0 and Phase 1 produce test specifications before implementation; all domain entities and rules get failing unit tests before implementation code |
| IV | **Performance & Frame Budget** — 60 fps on target devices; game-loop tick ≤ 16 ms; no widget rebuilds for unchanged map cells; bundle ≤ 50 MB | ✅ PASS | Documented in constraints above; `RepaintBoundary` at castle and Company marker boundaries is an explicit design requirement captured in `map_node_widget.dart` and `company_marker.dart` |
| V | **Simplicity & Incremental Complexity** — YAGNI; no speculative abstractions; AI uses deterministic rule-based logic; each feature delivered in priority order (P1 → P6) | ✅ PASS | AI is deterministic rule-based for MVP; no generic "engine" abstraction; features are independently playable/demonstrable before the next begins |

**Pre-Phase-0 verdict**: All five gates pass. No violations to justify.

**Post-Phase-1 re-check**: See bottom of this document after Phase 1 artifacts are complete.

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-single-player/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ui-contracts.md  # Screen interaction contracts
└── tasks.md             # Phase 2 output (created by /speckit.tasks — NOT by /speckit.plan)
```

### Source Code (repository root)

```text
lib/
├── domain/                          # Pure Dart — ZERO Flutter imports
│   ├── entities/
│   │   ├── unit_role.dart           # Enum: Peasant|Warrior|Knight|Archer|Catapult + stats (HP, DMG, speed, special)
│   │   ├── company.dart             # ≤50 soldiers, role composition map, derived movement speed
│   │   ├── castle.dart              # Garrison reservoir, ownership, cap, growth rate, Peasant bonus
│   │   ├── map_node.dart            # Node type (castle | road_junction), position
│   │   ├── road_edge.dart           # Directed edge connecting two MapNodes
│   │   ├── game_map.dart            # Graph: nodes + edges, path resolution
│   │   ├── battle.dart              # Participants, round state, round log, outcome
│   │   └── match.dart               # Session: map, players, win condition, elapsed time
│   ├── value_objects/
│   │   ├── soldier_count.dart       # Validated int ∈ [0, 50]
│   │   └── ownership.dart           # player | ai | neutral
│   ├── rules/
│   │   ├── movement_rules.dart      # Speed derivation (slowest role), path validation (road-only)
│   │   ├── battle_engine.dart       # Simultaneous-round resolver: melee advances, ranged holds, damage applied end-of-round
│   │   ├── terrain_bonus.dart       # Knight road 2× bonus; Archer High Ground 2×/75% DR; Catapult Wall Breaker
│   │   ├── growth_engine.dart       # Castle tick (1 unit/role/10 s), Peasant +5% multiplier, cap enforcement
│   │   ├── merge_split_rules.dart   # Overflow Company logic; role-based split validation
│   │   ├── victory_checker.dart     # Total Conquest: all castles same ownership → match end
│   │   └── ai_controller.dart       # Pure Dart — deterministic AI: deploy → march → engage decision tree (NO Flutter/state imports)
│   └── use_cases/
│       ├── deploy_company.dart      # Validate + remove from garrison; place Company on map
│       ├── move_company.dart        # Assign destination; validate road path; update position per tick; detect reinforcement-wave routing to active battle
│       ├── resolve_battle.dart      # Orchestrate battle_engine rounds; return outcome + survivors; handle draw; transfer castle ownership
│       ├── merge_companies.dart     # Combine two Companies; spawn overflow if >50
│       ├── split_company.dart       # Role-slider split; validate counts sum to original
│       ├── tick_castle_growth.dart  # Apply one growth tick to a castle; respect cap
│       ├── tick_match.dart          # Per-tick orchestrator: growth → collision detection → AI decisions → victory check (called by MatchNotifier; contains NO Flutter logic)
│       └── check_collisions.dart    # Detect opposing Companies on same road segment or Company arriving at enemy castle; return list of BattleTrigger events
│
├── state/                           # Riverpod providers — no direct UI rendering logic; MUST NOT contain game-rule logic
│   ├── match_notifier.dart          # MatchState, game-loop timer (10 s tick); delegates ALL rule evaluation to TickMatch use case
│   ├── castle_notifier.dart         # Per-castle garrison + ownership state
│   ├── company_notifier.dart        # Company positions, movement targets, in-transit state; selectedCompanyId for two-step tap-to-select/tap-to-move UX
│   ├── battle_notifier.dart         # Active battle state, round log, spectator stream
│   └── ai_controller_notifier.dart  # Thin Riverpod wrapper; calls AiController (lib/domain/rules/ai_controller.dart) — NO decision logic here
│
├── ui/                              # Flutter widgets only — NO business logic or model mutation
│   ├── screens/
│   │   ├── main_menu_screen.dart    # New Game button → match setup
│   │   ├── map_screen.dart          # Scrollable/zoomable map; Company markers; castle icons
│   │   ├── castle_screen.dart       # Garrison view; deployment panel; unit composition sliders
│   │   ├── battle_screen.dart       # Side-view 2D spectator display (melee front / ranged rear)
│   │   ├── victory_screen.dart      # Total Conquest victory; dismiss → main menu
│   │   └── defeat_screen.dart       # Defeat; dismiss → main menu
│   ├── widgets/
│   │   ├── map_node_widget.dart     # const constructor; RepaintBoundary per node
│   │   ├── company_marker.dart      # Animated position marker; RepaintBoundary
│   │   ├── battle_side_view.dart    # Melee units at front, ranged at rear; unit HP bars
│   │   ├── deployment_panel.dart    # Per-role quantity selectors; total ≤ 50 enforced in UI
│   │   └── split_slider.dart        # Role-based split slider; live preview of resulting Companies
│   └── theme/
│       └── app_theme.dart           # Medieval colour palette, typography
│
├── data/                            # Persistence + platform adapters
│   ├── drift/
│   │   ├── app_database.dart        # drift database root
│   │   ├── match_dao.dart           # CRUD for match state
│   │   └── tables/
│   │       ├── matches_table.dart
│   │       ├── companies_table.dart
│   │       └── castles_table.dart
│   └── settings_repository.dart     # shared_preferences wrapper (sound/display settings)
│
└── main.dart                        # ProviderScope root; app entry point

test/
├── domain/
│   ├── entities/                    # Unit tests: Company cap, UnitRole stats, Castle growth math
│   ├── rules/                       # TDD unit tests for every rule in lib/domain/rules/
│   │   ├── battle_engine_test.dart  # Simultaneous round resolution, terrain bonuses, High Ground
│   │   ├── movement_rules_test.dart # Speed derivation, road-only constraint
│   │   ├── growth_engine_test.dart  # Tick rate, Peasant bonus, cap enforcement
│   │   ├── merge_split_test.dart    # Overflow Company, role-split sum invariant
│   │   ├── victory_checker_test.dart
│   │   └── ai_controller_test.dart  # Pure Dart AI decision logic: deploy threshold, target selection, no-action on empty garrison
│   └── use_cases/                   # Unit tests for each use-case class
├── widget/
│   ├── map_screen_test.dart
│   ├── castle_screen_test.dart
│   └── battle_screen_test.dart
├── golden/
│   ├── map_rendering_test.dart      # Map node + Company marker visual regression
│   └── battle_side_view_test.dart   # Battle layout visual regression
└── integration/
    ├── full_match_test.dart         # Launch → deploy → march → battle → win/lose end-to-end
    └── ai_opponent_test.dart        # AI deploys + marches within 30 s; no player input
```

**Structure Decision**: Flutter mobile app with strict four-layer separation per Constitution Principle II. The `lib/domain/` layer is delivered and fully tested first. Riverpod is the single state-management approach for all feature areas (no Bloc — single-approach rule applies). `drift` is the persistence adapter for match state; `shared_preferences` for lightweight settings only.

## Complexity Tracking

> Constitution violations identified by `/speckit.analyze` (2026-03-02) and resolved in this plan revision:
>
> **C1 — Principle II violation (resolved)**: `AiController` was initially placed in `lib/state/`. Corrected: AI decision logic moved to `lib/domain/rules/ai_controller.dart` (pure Dart, zero Flutter imports). A thin `lib/state/ai_controller_notifier.dart` wraps it for Riverpod integration only.
>
> **C2 — Principle II violation (resolved)**: `MatchNotifier` was initially written to contain battle-trigger detection, victory checking, growth orchestration, and AI wiring. Corrected: a `lib/domain/use_cases/tick_match.dart` orchestrator now owns all per-tick rule evaluation (growth → collision detection → AI decisions → victory check). `MatchNotifier` calls `TickMatch` and applies the returned state delta — no game-rule logic remains in the state layer.
>
> **A4 — Missing map fixture (resolved)**: Added `lib/domain/entities/game_map_fixture.dart` as the hardcoded fixed map data source for `MatchNotifier.newGame()`.
>
> **A1 — Firing range undefined (resolved)**: `UnitRole` now includes a `range` field. Archer range = 3, Catapult range = 5 (in battle-field distance units). All other roles have range = 1 (melee only). Defined in `lib/domain/entities/unit_role.dart`.
