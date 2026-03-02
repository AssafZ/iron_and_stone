# Tasks: Iron & Stone MVP — Single-Player Mode

**Input**: Design documents from `/specs/001-mvp-single-player/`  
**Prerequisites**: plan.md ✅, spec.md ✅  
**Branch**: `001-mvp-single-player`  
**Generated**: 2026-03-02

**Constitution note (TDD)**: The spec and plan mandate Red-Green-Refactor TDD for all domain-layer
changes (Principle III). Test tasks are therefore **required** for every domain entity, rule, and
use-case. Widget / integration / golden tests are also required per the constitution.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (no shared-file dependency)
- **[Story]**: User story this task belongs to (US1–US6)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Bootstrap the Flutter project, install dependencies, and establish folder structure.

- [ ] T001 Initialize Flutter 3.x project at repository root with `flutter create --org com.ironandstone iron_and_stone`
- [ ] T002 Add all required dependencies to `pubspec.yaml`: `flutter_riverpod`, `drift`, `drift_flutter`, `shared_preferences`, `path_provider`, `flutter_test` (dev), `integration_test` (dev), `golden_toolkit` (dev), `build_runner` (dev), `drift_dev` (dev)
- [ ] T003 [P] Create the full `lib/` directory tree per plan.md: `lib/domain/entities/`, `lib/domain/value_objects/`, `lib/domain/rules/`, `lib/domain/use_cases/`, `lib/state/`, `lib/ui/screens/`, `lib/ui/widgets/`, `lib/ui/theme/`, `lib/data/drift/tables/`
- [ ] T004 [P] Create the full `test/` directory tree per plan.md: `test/domain/entities/`, `test/domain/rules/`, `test/domain/use_cases/`, `test/widget/`, `test/golden/`, `test/integration/`
- [ ] T005 [P] Configure `analysis_options.yaml` — enable `lints` package, set `treat_warnings_as_errors: true`, add lint rules: `avoid_dynamic_calls`, `prefer_const_constructors`, `avoid_print`
- [ ] T006 Create `lib/main.dart` — minimal `ProviderScope` + `MaterialApp` root; app entry point only, no game logic
- [ ] T007 Create `lib/ui/theme/app_theme.dart` — medieval colour palette (`ThemeData`); placeholder serif typography; `const` constructors throughout

**Checkpoint**: `flutter analyze` produces zero issues; `flutter test` runs (no tests yet) without errors.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain entities and value objects that every user story depends on. MUST be complete before any user-story phase begins.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

### Tests for Foundational Entities *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T008 [P] Write failing unit tests for `SoldierCount` in `test/domain/entities/soldier_count_test.dart`: valid range [0, 50], construction at 0 and 50, rejection of −1 and 51
- [ ] T009 [P] Write failing unit tests for `Ownership` in `test/domain/entities/ownership_test.dart`: values player/ai/neutral, equality, serialization round-trip
- [ ] T010 [P] Write failing unit tests for `UnitRole` in `test/domain/entities/unit_role_test.dart`: all five roles exist; stats match spec (HP, DMG, speed per FR-016, FR-009); special-ability tag present for Knight, Archer, Catapult, Peasant

### Implementation of Foundational Entities

- [ ] T011 [P] Implement `lib/domain/value_objects/soldier_count.dart` — validated `int` ∈ [0, 50]; throws `ArgumentError` outside range; make T008 pass
- [ ] T012 [P] Implement `lib/domain/value_objects/ownership.dart` — sealed enum `player | ai | neutral`; make T009 pass
- [ ] T013 Implement `lib/domain/entities/unit_role.dart` — enum `Peasant | Warrior | Knight | Archer | Catapult` with const fields `hp`, `damage`, `speed`, `specialAbility`; values: Peasant (10 HP, 0 DMG, speed 5), Warrior (50 HP, 15 DMG, speed 6), Knight (100 HP, 40 DMG, speed 10), Archer (30 HP, 25 DMG, speed 6), Catapult (150 HP, 60 DMG, speed 3); make T010 pass

### Tests for Foundational Compound Entities *(write first, confirm FAILING)*

- [ ] T014 [P] Write failing unit tests for `Company` in `test/domain/entities/company_test.dart`: composition map integrity, `totalSoldiers` ≤ 50 enforced, `movementSpeed` equals minimum role speed, adding soldiers beyond cap rejected
- [ ] T015 [P] Write failing unit tests for `Castle` in `test/domain/entities/castle_test.dart`: garrison reservoir initialises correctly, ownership field, base cap 250, Peasant bonus calculation (+5% per Peasant)
- [ ] T016 [P] Write failing unit tests for `MapNode` in `test/domain/entities/map_node_test.dart`: castle vs road-junction node types, position fields
- [ ] T017 [P] Write failing unit tests for `RoadEdge` in `test/domain/entities/road_edge_test.dart`: directed/undirected, connects exactly two nodes, no self-loops
- [ ] T018 [P] Write failing unit tests for `GameMap` in `test/domain/entities/game_map_test.dart`: node and edge collection, `pathBetween` returns a valid road-only sequence, returns empty/null for disconnected nodes
- [ ] T019 [P] Write failing unit tests for `Battle` in `test/domain/entities/battle_test.dart`: participants non-empty per side, initial round state is zero, outcome field starts null
- [ ] T020 [P] Write failing unit tests for `Match` in `test/domain/entities/match_test.dart`: contains valid GameMap, two distinct players, elapsed time starts at zero, win condition is `totalConquest`

### Implementation of Foundational Compound Entities

- [ ] T021 Implement `lib/domain/entities/company.dart` — `Map<UnitRole, int>` composition; `SoldierCount totalSoldiers`; derived `int movementSpeed` (min of present role speeds); immutable; `copyWith`; make T014 pass
- [ ] T022 Implement `lib/domain/entities/castle.dart` — garrison `Map<UnitRole, int>`, `Ownership ownership`, `int cap` (base 250), `double growthRateMultiplier` (1.0 + 0.05 × peasantCount); make T015 pass
- [ ] T023 [P] Implement `lib/domain/entities/map_node.dart` — sealed class variants `CastleNode` / `RoadJunctionNode`; `(double x, double y) position`; `String id`; make T016 pass
- [ ] T024 [P] Implement `lib/domain/entities/road_edge.dart` — `MapNode from`, `MapNode to`, `double length`; equality by node pair; make T017 pass
- [ ] T025 Implement `lib/domain/entities/game_map.dart` — `List<MapNode> nodes`, `List<RoadEdge> edges`, `List<MapNode> pathBetween(MapNode a, MapNode b)` (BFS/Dijkstra, road-only); make T018 pass
- [ ] T026 [P] Implement `lib/domain/entities/battle.dart` — `List<Company> attackers`, `List<Company> defenders`, `int roundNumber`, `List<String> roundLog`, `BattleOutcome? outcome`; make T019 pass
- [ ] T027 Implement `lib/domain/entities/match.dart` — `GameMap map`, `Ownership humanPlayer`, elapsed `Duration time`, `MatchPhase phase`; make T020 pass

**Checkpoint**: All T008–T027 tests pass; `flutter analyze` clean; domain entities fully exercised at unit-test level.

---

## Phase 3: User Story 1 — Launch a Match and Control the Map (Priority: P1) 🎯 MVP

**Goal**: Player can launch a match, see a medieval map with two castles, deploy a Company, and watch it march along a road.

**Independent Test**: Launch app → tap "New Game" → tap castle → deploy 1 Company of any composition → tap a road node → Company marker moves. No crash.

### Tests for US1 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T028 [P] [US1] Write failing unit tests for `MovementRules` in `test/domain/rules/movement_rules_test.dart`: `derivedSpeed` returns slowest role (Warriors + Catapults → 3), road-only path validation rejects off-road targets, movement position advances correctly per tick
- [ ] T029 [P] [US1] Write failing unit tests for `DeployCompany` use case in `test/domain/use_cases/deploy_company_test.dart`: removes units from garrison, places Company adjacent to castle on map, rejects deployment exceeding 50 soldiers (FR-008), rejects deployment when garrison lacks sufficient units
- [ ] T030 [P] [US1] Write failing unit tests for `MoveCompany` use case in `test/domain/use_cases/move_company_test.dart`: assigns destination, validates road path, position increments per tick by `movementSpeed`, Company arrives at destination node
- [ ] T031 [P] [US1] Write failing widget test for `MapScreen` in `test/widget/map_screen_test.dart`: map loads with ≥ 2 castle nodes visible, Company marker appears after deploy action, tapping a node sends movement intent to notifier
- [ ] T032 [P] [US1] Write failing widget test for `MainMenuScreen` in `test/widget/main_menu_screen_test.dart`: "New Game" button is present and tappable, routes to `MapScreen`

### Implementation for US1

- [ ] T033 [US1] Implement `lib/domain/rules/movement_rules.dart` — `int derivedSpeed(Company c)` returns `min` over roles present; `bool isValidPath(GameMap map, MapNode from, MapNode to)` road-only check; make T028 pass
- [ ] T034 [US1] Implement `lib/domain/use_cases/deploy_company.dart` — validate garrison has enough units, validate total ≤ 50, remove from `Castle.garrison`, return new `Company` placed at castle's adjacent start node; make T029 pass
- [ ] T035 [US1] Implement `lib/domain/use_cases/move_company.dart` — accept `Company`, `MapNode destination`, `GameMap`; validate road path; return updated `Company` with position advanced by `movementSpeed` per tick; make T030 pass
- [ ] T036 [US1] Implement `lib/state/match_notifier.dart` — `MatchNotifier extends AsyncNotifier<MatchState>`; `newGame()` initialises map + garrisons; 10-second periodic tick; exposes `MatchState` (map snapshot, companies, castles, phase)
- [ ] T037 [US1] Implement `lib/state/company_notifier.dart` — `CompanyNotifier extends AsyncNotifier<List<CompanyState>>`; `deployCompany(...)`, `setDestination(...)`, tick-driven position update via `MoveCompany` use case
- [ ] T038 [US1] Implement `lib/state/castle_notifier.dart` (garrison/ownership only — growth in US3) — `CastleNotifier extends AsyncNotifier<List<CastleState>>`; exposes garrison counts and ownership per castle id
- [ ] T039 [P] [US1] Implement `lib/ui/screens/main_menu_screen.dart` — `ConsumerWidget`; "New Game" `ElevatedButton` navigates to `MapScreen`; no game logic; make T032 pass
- [ ] T040 [US1] Implement `lib/ui/widgets/map_node_widget.dart` — `const` constructor; `RepaintBoundary` wrapper; renders castle icon or road-junction dot; tappable; dispatches node-tap event upward
- [ ] T041 [US1] Implement `lib/ui/widgets/company_marker.dart` — `AnimatedPositioned` for smooth movement; `RepaintBoundary`; displays unit count badge; tappable for detail
- [ ] T042 [US1] Implement `lib/ui/screens/map_screen.dart` — `ConsumerWidget`; `InteractiveViewer` for scroll/zoom; renders `MapNodeWidget` for each node; `CompanyMarker` for each in-transit Company; wires deploy and move intent to notifiers; make T031 pass
- [ ] T043 [P] [US1] Write failing golden test in `test/golden/map_rendering_test.dart`: map renders with two castle nodes and one Company marker matching golden baseline; verify `RepaintBoundary` boundaries
- [ ] T044 [US1] Run golden test (T043) — capture baseline screenshot; confirm test passes

**Checkpoint**: User Story 1 independently testable — deploy + march works end-to-end. `flutter test test/domain/rules/movement_rules_test.dart test/domain/use_cases/deploy_company_test.dart test/widget/map_screen_test.dart` all green.

---

## Phase 4: User Story 2 — Battle Resolution Between Opposing Forces (Priority: P2)

**Goal**: When opposing Companies meet, the Battle Detail Screen opens, rounds resolve with correct damage and terrain bonuses, and a win/loss summary is shown.

**Independent Test**: Guide a player Company into the AI's Company on a road → Battle Detail Screen opens → battle resolves → winner declared; survivor counts match unit balance sheet.

### Tests for US2 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T045 [P] [US2] Write failing unit tests for `BattleEngine` in `test/domain/rules/battle_engine_test.dart`: simultaneous-round resolution; melee units advance and target nearest melee first; ranged units hold position and fire; damage applied end-of-round; units at 0 HP removed before next round; mutual-destruction draw; all five unit-role damage values exercised
- [ ] T046 [P] [US2] Write failing unit tests for `TerrainBonus` in `test/domain/rules/terrain_bonus_test.dart`: Knight road 2× DMG (80 total); Archer High Ground 2× + 75% DR when no Warriors present; High Ground negated when Warriors present; Catapult Wall Breaker removes Archer bonus for subsequent rounds
- [ ] T047 [P] [US2] Write failing unit tests for `ResolveBattle` use case in `test/domain/use_cases/resolve_battle_test.dart`: returns survivors and `BattleOutcome`; reinforcement waves join mid-battle; castle-ownership transfer on defender elimination (FR-022a)
- [ ] T048 [P] [US2] Write failing widget test for `BattleScreen` in `test/widget/battle_screen_test.dart`: melee units appear at front, ranged + Peasants at rear; HP bars update per round; victory/defeat summary dismisses to map
- [ ] T049 [P] [US2] Write failing widget test for `VictoryScreen`/`DefeatScreen` in `test/widget/victory_defeat_screen_test.dart`: summary stats shown; dismiss button routes back to `MapScreen`

### Implementation for US2

- [ ] T050 [US2] Implement `lib/domain/rules/terrain_bonus.dart` — `int applyBonus(UnitRole role, BattleContext ctx)` returning modified damage; `bool highGroundActive(List<Company> attackers)` (false if Warriors present); `void applyWallBreaker(Battle battle)` removes Archer bonus flag; make T046 pass
- [ ] T051 [US2] Implement `lib/domain/rules/battle_engine.dart` — `BattleRoundResult resolveRound(Battle battle)`: melee units advance toward nearest enemy melee (FR-016b); ranged units hold + fire nearest enemy in range; apply `TerrainBonus`; compute simultaneous damage; remove 0-HP units; append round to log; make T045 pass
- [ ] T052 [US2] Implement `lib/domain/use_cases/resolve_battle.dart` — orchestrate `BattleEngine.resolveRound` until one side empty; handle reinforcement waves (FR-021); transfer castle ownership on defender elimination; return `BattleOutcome` + survivors; make T047 pass
- [ ] T053 [US2] Implement `lib/state/battle_notifier.dart` — `BattleNotifier extends AsyncNotifier<BattleState>`; `startBattle(...)` initialises battle; `advanceRound()` calls `ResolveBattle`; streams round log; exposes `BattleOutcome?`
- [ ] T054 [P] [US2] Implement `lib/ui/widgets/battle_side_view.dart` — side-view 2D layout: melee at front advancing, ranged + Peasants at rear; `AnimatedPositioned` melee units; HP bar per unit; `const` where possible; make T048 pass
- [ ] T055 [US2] Implement `lib/ui/screens/battle_screen.dart` — `ConsumerWidget`; renders `BattleSideView`; watches `BattleNotifier`; shows round log; transitions to victory/defeat summary on `BattleOutcome` non-null
- [ ] T056 [P] [US2] Implement `lib/ui/screens/victory_screen.dart` — summary stats (survivors, rounds); "Return to Map" button navigates back to `MapScreen`; make T049 pass
- [ ] T057 [P] [US2] Implement `lib/ui/screens/defeat_screen.dart` — same structure as `VictoryScreen`; different copy; make T049 pass
- [ ] T058 [US2] Wire battle trigger into `lib/state/match_notifier.dart` — detect when opposing Companies occupy same road segment; transition `MatchPhase` to `inBattle`; push `BattleScreen`
- [ ] T059 [P] [US2] Write failing golden test in `test/golden/battle_side_view_test.dart`: battle layout with melee front / ranged rear matches golden baseline
- [ ] T060 [US2] Run golden test (T059) — capture baseline; confirm test passes

**Checkpoint**: User Story 2 independently testable. `flutter test test/domain/rules/battle_engine_test.dart test/domain/rules/terrain_bonus_test.dart test/widget/battle_screen_test.dart` all green.

---

## Phase 5: User Story 3 — Castle Growth and Deployment Management (Priority: P3)

**Goal**: Castles grow units automatically over time; player can open the castle screen and deploy a custom-composition Company; growth halts at Castle Cap.

**Independent Test**: Observe castle unit counts rising every 10 s without player input; open deployment panel; deploy a hand-picked composition; verify garrison decremented by exactly those amounts.

### Tests for US3 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T061 [P] [US3] Write failing unit tests for `GrowthEngine` in `test/domain/rules/growth_engine_test.dart`: base tick adds 1 unit per role every 10 s; Peasant multiplier stacks (+5% per Peasant, FR-006); per-Company cap of 50 halts that Company's growth; total Castle Cap (250 × multiplier) halts all growth when reached; growth resumes after units are deployed
- [ ] T062 [P] [US3] Write failing unit tests for `TickCastleGrowth` use case in `test/domain/use_cases/tick_castle_growth_test.dart`: single tick produces correct counts; cap enforcement at Company and castle levels; Peasant bonus computed before cap check
- [ ] T063 [P] [US3] Write failing unit tests for `DeployCompany` edge cases in `test/domain/use_cases/deploy_company_test.dart` (extend existing file): exceeding 50 blocked with error (FR-008); deploying exactly 50 accepted; deploying 0 of a role is ignored, not blocked
- [ ] T064 [P] [US3] Write failing widget test for `CastleScreen` in `test/widget/castle_screen_test.dart`: displays live garrison counts; `DeploymentPanel` rejects total > 50; deploying valid composition updates CompanyNotifier; Peasant bonus and cap values displayed correctly

### Implementation for US3

- [ ] T065 [US3] Implement `lib/domain/rules/growth_engine.dart` — `CastleGrowthResult tick(Castle castle)`: compute effective rate (1 × multiplier per role); apply per-Company 50 cap; apply Castle Cap; return updated `Castle`; make T061 pass
- [ ] T066 [US3] Implement `lib/domain/use_cases/tick_castle_growth.dart` — wrap `GrowthEngine.tick`; accepts `Castle`, returns `Castle`; make T062 pass
- [ ] T067 [US3] Wire `TickCastleGrowth` into `lib/state/match_notifier.dart` 10-second tick — call `TickCastleGrowth` for every castle on each tick; propagate updated `CastleState` through `CastleNotifier`
- [ ] T068 [US3] Update `lib/state/castle_notifier.dart` — add `tickGrowth()` action wired to `TickCastleGrowth`; expose `effectiveCap` and `growthRateMultiplier` to UI
- [ ] T069 [P] [US3] Implement `lib/ui/widgets/deployment_panel.dart` — per-role integer steppers (± buttons); running total badge; "Deploy" button disabled when total > 50 or garrison insufficient; dispatches `deployCompany(...)` on confirm; make T064 pass
- [ ] T070 [US3] Implement `lib/ui/screens/castle_screen.dart` — `ConsumerWidget`; watches `CastleNotifier` for live garrison; shows Castle Cap, growth rate, Peasant bonus; embeds `DeploymentPanel`; make T064 pass

**Checkpoint**: User Story 3 independently testable. `flutter test test/domain/rules/growth_engine_test.dart test/widget/castle_screen_test.dart` all green.

---

## Phase 6: User Story 4 — Company Merging and Splitting on the Map (Priority: P4)

**Goal**: Two friendly Companies on the same node can be merged (with overflow handling); a single Company can be split by role using a slider.

**Independent Test**: Send two Companies to same node → merge → confirm combined count; then split by role → verify two Companies with correct compositions sum to original.

### Tests for US4 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T071 [P] [US4] Write failing unit tests for `MergeSplitRules` in `test/domain/rules/merge_split_test.dart`: merge ≤ 50 produces single Company; merge > 50 produces primary Company of 50 + overflow Company with remainder; split produces two Companies summing to original; split with zero-count role rejected
- [ ] T072 [P] [US4] Write failing unit tests for `MergeCompanies` use case in `test/domain/use_cases/merge_companies_test.dart`: happy path ≤ 50; overflow ≥ 50 (SC-005); both Companies on same node required; result Companies placed on same node
- [ ] T073 [P] [US4] Write failing unit tests for `SplitCompany` use case in `test/domain/use_cases/split_company_test.dart`: output counts sum to original; new Company placed on same node; role selection validated against available composition
- [ ] T074 [P] [US4] Write failing widget test for `SplitSlider` widget in `test/widget/split_slider_test.dart`: live preview updates as slider moves; "Confirm Split" dispatches correct split action; original minus split count shown correctly

### Implementation for US4

- [ ] T075 [US4] Implement `lib/domain/rules/merge_split_rules.dart` — `MergeResult merge(Company a, Company b)` returning primary + optional overflow; `SplitResult split(Company c, Map<UnitRole, int> toSplit)` with sum-invariant check; make T071 pass
- [ ] T076 [US4] Implement `lib/domain/use_cases/merge_companies.dart` — validate same-node, call `MergeSplitRules.merge`, update map state; make T072 pass
- [ ] T077 [US4] Implement `lib/domain/use_cases/split_company.dart` — validate composition, call `MergeSplitRules.split`, place both Companies on node; make T073 pass
- [ ] T078 [US4] Update `lib/state/company_notifier.dart` — add `mergeCompanies(String idA, String idB)` and `splitCompany(String id, Map<UnitRole, int> splitMap)` actions wired to respective use cases
- [ ] T079 [US4] Implement `lib/ui/widgets/split_slider.dart` — per-role sliders bounded by current composition; live preview of resulting Company A and Company B counts; "Confirm Split" button; make T074 pass
- [ ] T080 [US4] Update `lib/ui/screens/map_screen.dart` — show merge prompt when two friendly Companies are on the same node; open split-slider sheet when a Company is long-pressed; dispatch actions to `CompanyNotifier`

**Checkpoint**: User Story 4 independently testable. `flutter test test/domain/rules/merge_split_test.dart test/widget/split_slider_test.dart` all green.

---

## Phase 7: User Story 5 — AI Opponent Plays Autonomously (Priority: P5)

**Goal**: The AI deploys at least one Company within 30 seconds of match start, marches toward a player castle or unoccupied castle, and engages in battle when Companies meet.

**Independent Test**: Start a match and take no action for 60 seconds — AI has deployed ≥ 1 Company and moved it toward an objective.

### Tests for US5 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T081 [P] [US5] Write failing unit tests for `AiController` in `test/domain/rules/ai_controller_test.dart` (pure Dart): `chooseDeployment(MatchState)` returns a valid Company within 30 s game-time; `chooseTarget(MatchState, Company)` returns player-owned or neutral castle node; returns no action when garrison empty
- [ ] T082 [P] [US5] Write failing integration test in `test/integration/ai_opponent_test.dart`: start match with `MatchNotifier` in test harness; advance clock 30 s; assert AI has ≥ 1 Company on map; advance to 60 s; assert Company has moved toward a player castle
- [ ] T083 [P] [US5] Write failing widget test verifying `MapScreen` shows AI Company markers after 30-second tick without player interaction

### Implementation for US5

- [ ] T084 [US5] Implement deterministic AI decision logic in `lib/state/ai_controller.dart` — `AiController`; `decideDeployment(MatchState)`: deploy a mixed Company when garrison ≥ 10 units; `decideMovement(MatchState)`: march each AI Company toward nearest non-AI castle; `decideReaction(MatchState)`: no special reaction needed (battle auto-triggers); make T081 pass
- [ ] T085 [US5] Wire `AiController` into `lib/state/match_notifier.dart` 10-second tick — after growth tick, call `AiController.decideDeployment` and `decideMovement` for AI castles and companies; update state; make T082 pass
- [ ] T086 [US5] Verify `MapScreen` reflects AI Company markers by running T083 widget test — fix any watch/rebuild issues

**Checkpoint**: User Story 5 independently testable. Start match, wait 30 s, AI acts. `flutter test test/domain/rules/ai_controller_test.dart test/integration/ai_opponent_test.dart` green.

---

## Phase 8: User Story 6 — Victory and Defeat Conditions (Priority: P6)

**Goal**: Game correctly detects Total Conquest (all castles same ownership), shows Victory or Defeat screen, and returns player to main menu on dismiss.

**Independent Test**: Use a test harness to set all castles to player ownership → victory screen appears. Set all to AI ownership → defeat screen appears.

### Tests for US6 *(Red-Green-Refactor — write first, confirm FAILING)*

- [ ] T087 [P] [US6] Write failing unit tests for `VictoryChecker` in `test/domain/rules/victory_checker_test.dart`: all-player castles → `MatchOutcome.playerWins`; all-AI castles → `MatchOutcome.aiWins`; mixed → `null`; single-castle map edge case
- [ ] T088 [P] [US6] Write failing integration test in `test/integration/full_match_test.dart`: full match from launch to Total Conquest; verify `MatchPhase` transitions `setup → playing → ended`; verify correct `MatchOutcome` written

### Implementation for US6

- [ ] T089 [US6] Implement `lib/domain/rules/victory_checker.dart` — `MatchOutcome? check(List<Castle> castles)`: returns `playerWins` if all `Ownership.player`, `aiWins` if all `Ownership.ai`, else `null`; make T087 pass
- [ ] T090 [US6] Wire `VictoryChecker` into `lib/state/match_notifier.dart` after every castle-ownership change — if outcome non-null, transition `MatchPhase` to `ended` and store outcome; navigate to `VictoryScreen` or `DefeatScreen`
- [ ] T091 [US6] Verify `VictoryScreen` and `DefeatScreen` dismiss-to-main-menu flow (already implemented in T056/T057) — run T049 widget tests; confirm they pass end-to-end

**Checkpoint**: User Story 6 independently testable. Full match loop closable. `flutter test test/domain/rules/victory_checker_test.dart test/integration/full_match_test.dart` all green.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Persistence layer, settings, end-to-end integration, performance validation, and final CI gate.

- [ ] T092 [P] Implement `lib/data/drift/tables/matches_table.dart`, `companies_table.dart`, `castles_table.dart` — Drift `Table` classes matching domain entity fields
- [ ] T093 Implement `lib/data/drift/app_database.dart` — Drift `Database` root; register all three tables; generate code via `build_runner`
- [ ] T094 Implement `lib/data/drift/match_dao.dart` — CRUD for match state: `saveMatch`, `loadMatch`, `deleteMatch`; map domain `Match` ↔ Drift rows
- [ ] T095 [P] Implement `lib/data/settings_repository.dart` — `shared_preferences` wrapper; persist sound on/off, display brightness preference
- [ ] T096 Wire `MatchDao` into `lib/state/match_notifier.dart` — persist `MatchState` snapshot after each 10-second tick; restore on cold start
- [ ] T097 [P] Write end-to-end integration test in `test/integration/full_match_test.dart` (extend T088): launch → deploy → march → battle → total conquest; assert no crash, correct final `MatchOutcome`
- [ ] T098 [P] Profile game-loop tick in Flutter DevTools: confirm single tick ≤ 16 ms on Dart VM; document results in `specs/001-mvp-single-player/performance-notes.md`
- [ ] T099 [P] Profile `MapScreen` scroll/zoom in Flutter DevTools on a 4-node map: confirm 60 fps; verify no widget rebuilds for unchanged `MapNodeWidget` cells (RepaintBoundary validation)
- [ ] T100 Run `flutter analyze` — assert zero issues (treat warnings as errors per CI gate)
- [ ] T101 Run `flutter test` — assert all tests pass; capture final test-count report
- [ ] T102 [P] Update `README.md` with quickstart instructions: clone → `flutter pub get` → `flutter test` → `flutter run`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Requires Phase 1 complete. **Blocks all user-story phases.**
- **US1 Phase 3**: Requires Phase 2 complete. No other story dependency.
- **US2 Phase 4**: Requires Phase 2 complete. Integrates with Phase 3 (`MatchNotifier`, map triggers) but is independently testable at the domain + widget level.
- **US3 Phase 5**: Requires Phase 2 complete. Extends `CastleNotifier` and `MatchNotifier` introduced in Phase 3.
- **US4 Phase 6**: Requires Phase 2 complete. Extends `CompanyNotifier` from Phase 3.
- **US5 Phase 7**: Requires Phases 3–5 complete (needs `MatchNotifier` with full tick, castle growth, company movement).
- **US6 Phase 8**: Requires Phases 3–5 complete (castle ownership set by battle resolution from Phase 4).
- **Polish (Phase 9)**: Requires all user-story phases complete.

### User Story Dependency Graph

```
Phase 1 (Setup)
    └─► Phase 2 (Foundational)
            ├─► Phase 3 (US1 — Map + Deploy + Move)
            │       └─► Phase 4 (US2 — Battle)  ─┐
            │       └─► Phase 5 (US3 — Growth)   ─┤─► Phase 7 (US5 — AI)
            │       └─► Phase 6 (US4 — Merge/Split)│     └─► Phase 8 (US6 — Victory)
            │                                       │           └─► Phase 9 (Polish)
            └──────────────────────────────────────┘
```

### Within Each Phase

1. Write failing tests → confirm they fail → implement → confirm they pass → refactor.
2. Models before services; services before state notifiers; notifiers before widgets.
3. Golden tests captured after widget implementation.
4. Commit after each completed task or logical group.

---

## Parallel Opportunities

### Phase 2 — Foundational Entities (all [P] tasks can run concurrently)

```
T008  Write SoldierCount tests          ─┐
T009  Write Ownership tests              ├─ all in parallel
T010  Write UnitRole tests               │
T011  Implement SoldierCount            ─┘ (after T008)
T012  Implement Ownership                  (after T009)
T013  Implement UnitRole                   (after T010)

T014  Write Company tests               ─┐
T015  Write Castle tests                 ├─ all in parallel (after T011-T013)
T016  Write MapNode tests                │
T017  Write RoadEdge tests               │
T018  Write GameMap tests                │
T019  Write Battle tests                 │
T020  Write Match tests                 ─┘
```

### Phase 3 — US1 (models + tests [P] tasks can run concurrently)

```
T028  Write MovementRules tests         ─┐
T029  Write DeployCompany tests          ├─ all in parallel
T030  Write MoveCompany tests            │
T031  Write MapScreen widget test        │
T032  Write MainMenuScreen widget test  ─┘
T033  Implement MovementRules              (after T028)
T034  Implement DeployCompany              (after T029)
T035  Implement MoveCompany                (after T030)
T039  Implement MainMenuScreen          ─┐ (after T032)
T040  Implement MapNodeWidget            ├─ in parallel
T041  Implement CompanyMarker           ─┘
```

### Phase 4 — US2 (battle engine tests [P] can run concurrently)

```
T045  Write BattleEngine tests          ─┐
T046  Write TerrainBonus tests           ├─ in parallel
T047  Write ResolveBattle tests          │
T048  Write BattleScreen tests           │
T049  Write Victory/DefeatScreen tests  ─┘
T054  Implement BattleSideView          ─┐ (after T048)
T056  Implement VictoryScreen            ├─ in parallel
T057  Implement DefeatScreen            ─┘ (after T049)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (CRITICAL — blocks everything).
3. Complete Phase 3: User Story 1.
4. **STOP AND VALIDATE**: Deploy + march loop is end-to-end playable; no crashes.
5. Demo the skeleton — a Company marches a road. This alone constitutes the MVP skeleton per spec.

### Incremental Delivery

| Step | Phases | What's Playable |
|------|--------|-----------------|
| 1 | 1–2 | Project runs; domain entities pass all unit tests |
| 2 | 3 | Deploy a Company and march it on a map (P1 MVP) |
| 3 | 4 | March into enemy Company → battle resolves (full game loop) |
| 4 | 5 | Castles grow; custom composition deployment |
| 5 | 6 | Merge/split Companies mid-game |
| 6 | 7 | AI acts autonomously; true single-player game |
| 7 | 8 | Victory/defeat screens; complete match session |
| 8 | 9 | Persistence, performance sign-off, CI green |

### Parallel Team Strategy (if multiple developers)

- **Developer A**: Phase 3 (US1 map + move + deploy)
- **Developer B**: Phase 4 (US2 battle engine) — can build domain layer independently of Flutter UI
- **Developer C**: Phase 5 (US3 growth + deployment panel)
- All three converge for Phase 7 (AI) once their foundational stories are complete.

---

## Notes

- `[P]` tasks write to different files with no shared in-progress dependency — they are safe to parallelise.
- `[Story]` labels map directly to user stories in `spec.md` for full traceability.
- All domain tasks follow Red-Green-Refactor; do **not** write implementation before the failing test exists.
- Stop at each **Checkpoint** to validate the story's independent test criteria before advancing.
- No `[TODO]` tokens may be left open in implementation code without a `TODO(<FIELD>): explanation` annotation.
- Commit convention: `feat(domain): ...`, `test(rules): ...`, `feat(ui): ...`, etc. per constitution.
- `flutter analyze` must remain at zero issues after every committed task.
