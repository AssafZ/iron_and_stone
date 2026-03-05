---
description: "Task list for Battle Trigger & Live Battle View"
---

# Tasks: Battle Trigger & Live Battle View

**Feature Branch**: `003-battle-trigger-and-live-battle`  
**Input**: Design documents from `/specs/003-battle-trigger-and-live-battle/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**TDD**: This project follows Red-Green-Refactor. All domain-layer tasks include a failing test that must be written **first** and confirmed failing before implementation begins. Widget tests cover every interactive screen flow.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths are included in every description

---

## Phase 1: Setup

**Purpose**: Confirm working baseline before any changes are made.

- [X] T001 Confirm `flutter test` passes green (zero failures) before touching any file
- [X] T002 Confirm `flutter analyze` reports zero issues before touching any file
  <!-- Baseline: 428 tests pass. flutter analyze has 21 pre-existing issues (4 warnings, 17 infos) — logged for awareness; no regressions introduced. -->

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain and data-layer pieces that MUST exist before any user story can be
implemented. Nothing in Phase 3+ can start until this phase is complete.

**⚠️ CRITICAL**: All user story phases depend on this phase being fully complete.

### 2a — `battleId` field on `CompanyOnMap` (domain)

- [X] T003 Write **failing** unit test: `CompanyOnMap.copyWith` clears `battleId` when explicit `null` is passed — extend `test/domain/use_cases/check_collisions_test.dart`
- [X] T004 Add `String? battleId` field and sentinel `copyWith` support to `CompanyOnMap` in `lib/domain/use_cases/check_collisions.dart` (mirror the existing `destination` sentinel pattern — see `copyWith` at line 80); confirm T003 turns green

### 2b — `ActiveBattle` entity (domain)

- [X] T005 [P] Write **failing** unit test: `ActiveBattle.id` equals `"battle_<nodeId>"` — create `test/domain/entities/active_battle_test.dart`
- [X] T006 [P] Create `ActiveBattle` entity — new file `lib/domain/entities/active_battle.dart`; fields: `id` (`String`), `nodeId` (`String`), `attackerCompanyIds` (`List<String>`), `defenderCompanyIds` (`List<String>`), `attackerOwnership` (`Ownership`), `battle` (`Battle`); add `factory`, `copyWith`, `toString`; confirm T005 turns green

### 2c — Drift schema migration (data)

- [X] T007 [P] Create `BattlesTable` drift table — new file `lib/data/drift/tables/battles_table.dart`; columns: `id` (TEXT PK), `matchId` (TEXT), `nodeId` (TEXT), `attackerCompanyIds` (TEXT, JSON array), `defenderCompanyIds` (TEXT, JSON array), `attackerOwnership` (TEXT), `battleJson` (TEXT)
- [X] T008 [P] Add nullable `battleId` column (TEXT, default `''`) to `CompaniesTable` in `lib/data/drift/tables/companies_table.dart`
- [X] T009 Register `BattlesTable` in `@DriftDatabase` annotation and bump `schemaVersion` to `2` with `MigrationStrategy.onUpgrade` (`ALTER TABLE companies ADD COLUMN battle_id` + `createTable(battlesTable)`) in `lib/data/drift/app_database.dart` — **depends on T007, T008**
- [X] T010 Run drift codegen: `dart run build_runner build --delete-conflicting-outputs` — **depends on T009**; verify `.g.dart` files regenerate without errors

**Checkpoint**: Foundation ready — domain entity exists, `CompanyOnMap` carries `battleId`, DB schema is at v2. User story phases can now begin.

---

## Phase 3: User Story 1 — Road-Junction Collision Triggers a Battle (Priority: P1) 🎯 MVP

**Goal**: Detect when two opposing companies occupy the same road-junction node (including mid-edge pass-through), halt both companies, create an `ActiveBattle`, tag companies with `battleId`, and advance the battle one round per game tick.

**Independent Test**: Deploy a player company and an AI company on opposite ends of the same road. Run the game loop. When both arrive at the shared junction, both must halt (`battleId != null`) and an `ActiveBattle` must be in `MatchState.activeBattles`. Neither company may advance past the node in the same tick.

### Tests for User Story 1 (TDD — write before implementation)

- [X] T011 Write **failing** unit test: a company with progress that would carry it past an enemy-occupied node is clamped to that node (`progress = 0.0`, `currentNode = nextNode`) — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T012 Write **failing** unit test: `tick()` creates an `ActiveBattle` and freezes both companies (`battleId != null`) when a `roadCollision` trigger is detected — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T013 Write **failing** unit test: `tick()` advances an existing `ActiveBattle` by one round per tick via `BattleEngine.resolveRound` — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T014 Write **failing** unit test: `tick()` applies post-battle cleanup when `battle.outcome != null` — update survivor compositions, clear `battleId`, remove zero-soldier companies, remove `ActiveBattle` from list — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T015 [US1] Write **failing** unit tests: (a) two same-owner companies at the same junction do NOT emit a battle trigger; (b) three or more opposing companies at the same junction produce exactly ONE `BattleTrigger` containing all company IDs — not one trigger per pair (FR-007) — extend `test/domain/use_cases/check_collisions_test.dart`

### Implementation for User Story 1

- [X] T016 Fix FR-003 mid-edge pass-through: add enemy-occupation guard in `TickMatch._advance()` before the `newProgress >= 1.0` branch in `lib/domain/use_cases/tick_match.dart`; confirm T011 turns green
- [X] T017 Add `required List<ActiveBattle> activeBattles` parameter to `TickMatch.tick()` and add `List<ActiveBattle> activeBattles` to `TickResult` in `lib/domain/use_cases/tick_match.dart`
- [X] T018 Implement Phase A of `TickMatch.tick()` (after existing step 5): process `roadCollision` triggers — create `ActiveBattle`, tag company `battleId`s, add to `activeBattles` list in `lib/domain/use_cases/tick_match.dart`; confirm T012 turns green
- [X] T019 Implement Phase B of `TickMatch.tick()`: advance each existing `ActiveBattle` one round via `BattleEngine.resolveRound` in `lib/domain/use_cases/tick_match.dart`; confirm T013 turns green
- [X] T020 Implement Phase C of `TickMatch.tick()`: post-battle cleanup for resolved battles (update compositions, remove zero-soldier companies, clear `battleId` on survivors, remove `ActiveBattle`) in `lib/domain/use_cases/tick_match.dart`; confirm T014 turns green
- [X] T021 Update `MatchState` in `lib/state/match_notifier.dart`: add `List<ActiveBattle> activeBattles = const []` field and update `copyWith`
- [X] T022 Wire `TickMatch` battle loop in `MatchNotifier.tick()` in `lib/state/match_notifier.dart`: pass `state.activeBattles` to `TickMatch.tick(activeBattles: ...)` and store `result.activeBattles` back into state; **before** removing the `MatchPhase.inBattle` trigger-based transition, audit every consumer of `MatchPhase.inBattle` in `lib/ui/` and `lib/state/` (search for `inBattle` across the codebase) and replace each phase-gate check with `activeBattles.isNotEmpty`; only then remove the old transition to avoid breaking phase-gated UI (fix I2)
- [X] T023a Write **failing** unit test: `AdvanceBattle.advance(activeBattle)` returns an updated `ActiveBattle` with one more round resolved; if `battle.outcome != null` after the round, the returned `ActiveBattle` carries the resolved `Battle` — new file `test/domain/use_cases/advance_battle_test.dart`
- [X] T023b Create `AdvanceBattle` use case — new file `lib/domain/use_cases/advance_battle.dart`; pure Dart, zero Flutter imports; single method `ActiveBattle advance(ActiveBattle activeBattle)` that calls `BattleEngine.resolveRound(activeBattle.battle)` and returns `activeBattle.copyWith(battle: roundResult.updatedBattle)`; confirm T023a turns green
- [X] T023c Add `MatchNotifier.advanceBattleRound(String battleId)` action in `lib/state/match_notifier.dart`: finds the matching `ActiveBattle` in `state.activeBattles`; delegates entirely to `AdvanceBattle.advance(activeBattle)` (no game-rule logic in this method); if the returned battle is resolved (`outcome != null`), calls a private `_applyPostBattleCleanup` helper (also delegating to domain) to produce the updated `MatchState`; stores result back into state
- [X] T024 Update `MatchDao.saveMatch` and `loadMatch` in `lib/data/drift/match_dao.dart` to persist and restore `activeBattles` using `BattlesTable`; map `battleId` column on companies (empty string → `null` on load); implement `_encodeBattle(Battle) → String` and `_decodeBattle(String) → Battle` JSON helpers in `lib/data/drift/match_dao.dart` (or extract to `lib/data/drift/battle_serialiser.dart`) to handle `Battle` HP maps, round log, and outcome fields; add a `// TODO(cleanup): growthRemainder persistence not yet implemented` comment in `saveMatch` to track the pre-existing gap (fix U2)

**Checkpoint**: Road-junction collision detection is fully working. Running the game loop with opposing companies on the same road results in both halting, a battle progressing round-by-round, and post-battle state cleanup. All T011–T015 are green.

---

## Phase 4: User Story 2 — Castle-Entry with Garrison Triggers a Battle (Priority: P2)

**Goal**: When an attacking company arrives at an enemy castle that contains garrison companies, a `castleAssault` battle is triggered. An empty enemy castle is captured immediately (no battle). Reinforcements from either side join the active battle.

**Independent Test**: Place an AI company inside a player-owned castle. Send a player company to that castle. When the player company arrives, a `castleAssault` `ActiveBattle` must be created and both companies must have `battleId != null`. Separately, send a player company to an empty neutral castle — no battle fires and ownership transfers.

### Tests for User Story 2 (TDD — write before implementation)

- [X] T025 [US2] Write **failing** unit test: `tick()` emits a `castleAssault` trigger when an attacking company arrives at an enemy castle with garrison companies (only companies with `destination == null` at the castle node count as garrison) — extend `test/domain/use_cases/check_collisions_test.dart`
- [X] T025b [US2] Write **failing** unit test: a company that is **transiting through** (non-null `destination`) a castle node does NOT count as garrison and does NOT trigger a `castleAssault` — extend `test/domain/use_cases/check_collisions_test.dart`
- [X] T026 [US2] Write **failing** unit test: `tick()` does NOT emit a battle trigger when attacking company arrives at an empty enemy castle, and castle ownership transfers immediately — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T027 [US2] Write **failing** unit test: `tick()` transfers castle ownership after `castleAssault` resolves with attacker win; separately, write a draw-case variant confirming ownership does NOT transfer when both sides are eliminated simultaneously — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T028 [US2] Write **failing** unit test: a company arriving at a node where a `castleAssault` battle is already in progress joins as a reinforcement on the appropriate side — extend `test/domain/use_cases/tick_match_test.dart`

### Implementation for User Story 2

- [X] T029 [US2] Add `castleAssault` variant to `CheckCollisions.check()` in `lib/domain/use_cases/check_collisions.dart`: detect arriving company at enemy castle; only companies with `destination == null` at the castle node count as garrison defenders (fix I3); emit `BattleTrigger(kind: castleAssault)` with all defending garrison company IDs; skip battle if castle has no stationary garrison; also update the existing in-code doc comments from legacy `FR-014`/`FR-015` to the canonical `FR-001`/`FR-003`/`FR-004` references (fix I1)
- [X] T030 [US2] Handle `castleAssault` triggers in Phase A of `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`: include all garrison companies as defenders when creating the `ActiveBattle`; set `attackerOwnership` correctly on `ActiveBattle`; for the initial trigger, include all companies already at the node at construction time (not via `addReinforcement`) to handle same-tick arrivals (fix I5); confirm T025 turns green
- [X] T031 [US2] Before implementing, verify `ResolveBattle.addReinforcement` exists in `lib/domain/use_cases/resolve_battle.dart`; if absent, add it as a domain function first. Then implement reinforcement joining in Phase A of `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`: if an `ActiveBattle` already exists at the node, call `ResolveBattle.addReinforcement` and tag the new company with `battleId`; confirm T028 turns green
- [X] T032 [US2] Implement castle ownership transfer in Phase C (post-battle cleanup) of `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`: if `battle.kind == castleAssault` and outcome is `attackersWin`, transfer `Castle.ownership` to `activeBattle.attackerOwnership`; if outcome is `draw`, ownership MUST remain unchanged (FR-024); confirm T027 turns green (both attacker-win and draw variants)
- [X] T033 [US2] Confirm empty-castle capture path is unaffected (no regression) — run `flutter test test/domain/` and verify T026 is green

**Checkpoint**: Castle-entry battle is fully working. Garrisoned castles trigger a battle; empty castles are captured immediately. Reinforcements join correctly. Castle ownership transfers on attacker win. All T025–T033 are green.

---

## Phase 4b: User Story 5 — Post-Battle State: Soldier Counts Updated, Eliminated Companies Removed (Priority: P5)

**Goal**: After any battle resolves, surviving companies have their `composition` updated to match the final HP map, zero-soldier companies are removed from the map, castle ownership transfers on attacker win (or stays on draw), the battle indicator is removed, and surviving companies resume movement automatically on the next tick.

**Independent Test**: Trigger a battle. Resolve all rounds until `battle.outcome` is non-null. Verify: (1) surviving companies' `composition` equals the final round's HP counts; (2) companies with 0 soldiers are absent from `MatchState.companies`; (3) if the battle was a `castleAssault` and attackers won, `Castle.ownership` has changed; (4) if it was a draw-case castle assault, ownership is unchanged; (5) survivors have `battleId == null`; (6) the `ActiveBattle` is absent from `MatchState.activeBattles`.

### Tests for User Story 5 (TDD — write before implementation)

- [X] T056 [US5] Write **failing** unit test: after battle resolves with attacker win, surviving attacker `composition` matches final HP map counts; zero-soldier companies absent from result — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T057 [US5] Write **failing** unit test: after battle resolves with defender win, surviving defender `composition` is updated; attacker companies removed — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T058 [US5] Write **failing** unit test: after a draw (both sides reach 0 soldiers in the same round), both companies are removed from the result — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T059 [US5] Write **failing** unit test: after a `castleAssault` draw, castle ownership does NOT change (FR-024) — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T060 [US5] Write **failing** unit test: after cleanup, a surviving company's `battleId` is `null` and its `destination` is preserved unchanged — extend `test/domain/use_cases/tick_match_test.dart`
- [X] T061 [US5] Write **failing** unit test: edge case — garrison companies all have 0 soldiers: attacking company captures the castle without a battle (castle has no living garrison); extend `test/domain/use_cases/check_collisions_test.dart` (fix I4)
- [X] T062 [US5] Write **failing** unit test: edge case — survivor's `destination` equals the battle node; after cleanup, the company remains stationary and does NOT re-trigger collision on the next tick (quickstart Gotcha #5) — extend `test/domain/use_cases/tick_match_test.dart`

### Implementation for User Story 5

- [X] T063 [US5] Implement Phase C post-battle cleanup for the **attacker-win** and **defender-win** cases fully in `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`: derive updated `composition` from final `Battle` HP map for each surviving company; remove zero-soldier companies; confirm T056 and T057 turn green
- [X] T064 [US5] Implement draw-case cleanup in Phase C of `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`: when `outcome == draw`, remove all companies on both sides regardless of remaining HP; confirm T058 turns green
- [X] T065 [US5] Implement castle-ownership-no-transfer on draw in Phase C of `TickMatch.tick()` in `lib/domain/use_cases/tick_match.dart`; confirm T059 turns green; also add the 0-soldier garrison guard to `CheckCollisions.check()` — companies with `totalSoldiers == 0` at a castle node are ignored as garrison defenders; confirm T061 turns green
- [X] T066 [US5] Confirm `battleId` clear and `destination` preservation in Phase C cleanup in `lib/domain/use_cases/tick_match.dart`; add a guard in `_advance()` so that when `destination == currentNode` the company stays stationary without emitting a new collision; confirm T060 and T062 turn green

**Checkpoint**: Full post-battle lifecycle is correct. All six cleanup scenarios pass. Survivors resume marching. No phantom companies or stale indicators remain. All T056–T062 are green.

---

## Phase 5: User Story 3 — Battle Indicator on the Map (Priority: P3)

**Goal**: While a battle is in progress, a visually distinct `BattleIndicator` widget is rendered on the map at the battle node's canvas coordinates. It remains until the battle resolves, persists across pan/zoom, and supports multiple simultaneous battles.

**Independent Test**: Trigger a battle at any node. Observe the map screen. A visually distinct pulsing crossed-swords marker must appear at the battle node and remain until the battle ends.

### Tests for User Story 3 (TDD — write before implementation)

- [X] T034 [P] Write **failing** widget test: `BattleIndicator` renders with minimum 44×44 pt tap target — create `test/widget/battle_indicator_test.dart`
- [X] T035 [P] Write **failing** widget test: `BattleIndicator.onTap` callback fires when indicator is tapped — in `test/widget/battle_indicator_test.dart`
- [X] T036 Write **failing** widget test: map screen renders a `BattleIndicator` for each entry in `MatchState.activeBattles` — extend `test/widget/map_screen_test.dart` (create file if it does not exist)
- [X] T037 Write **failing** widget test: map screen removes `BattleIndicator` when the corresponding `ActiveBattle` is gone from `MatchState.activeBattles` — extend `test/widget/map_screen_test.dart`

### Implementation for User Story 3

- [X] T038 [P] Create `BattleIndicator` widget — new file `lib/ui/widgets/battle_indicator.dart`; `StatefulWidget` with `battleId` (`String`) and `onTap` (`VoidCallback`) params; `AnimationController` with `repeat(reverse: true)` for pulse animation; `SingleTickerProviderStateMixin`; outer `SizedBox(44, 44)`; `RepaintBoundary` wrapping animated child; crossed-swords icon with pulsing red overlay; confirm T034 and T035 turn green
- [X] T039 Wire `BattleIndicator` into `MapScreen` in `lib/ui/screens/map_screen.dart`: watch `matchState.activeBattles`; in the map `Stack`, after company markers, add one `Positioned` `BattleIndicator` per active battle using `_nodeCanvasPos(nodeId)` for coordinates; `onTap` placeholder (wired in Phase 6); suppress normal company markers for companies with `battleId != null`; confirm T036 and T037 turn green

**Checkpoint**: Battle indicator is fully visible on the map during any active battle, correctly anchored to the battle node, and removed when the battle resolves. Golden screenshot can be taken here to lock in visual regression baseline.

---

## Phase 6: User Story 4 — Tap Battle Indicator to View Live Battle (Priority: P4)

**Goal**: Tapping a battle indicator opens `BattleScreen` for the specific battle (identified by `battleId`). The screen shows attacker/defender companies, current round, and soldier counts. "Next Round" advances one round immediately. Back navigation returns to the map with the indicator still visible if the battle is ongoing.

**Independent Test**: Trigger a battle. Tap the map indicator. `BattleScreen` opens showing the correct companies. Tap "Next Round" — soldier counts update. Navigate back — indicator is still present.

### Tests for User Story 4 (TDD — write before implementation)

- [X] T040 [P] Write **failing** widget test: `BattleScreen` shows the correct attacker and defender companies for a given `battleId` — extend `test/widget/battle_screen_test.dart`
- [X] T041 [P] Write **failing** widget test: tapping "Next Round" calls `MatchNotifier.advanceBattleRound` with the correct `battleId` — extend `test/widget/battle_screen_test.dart`
- [X] T042 [P] Write **failing** widget test: `BattleScreen` shows `_BattleSummary` when the `ActiveBattle` for its `battleId` is no longer in `MatchState.activeBattles` (battle resolved while screen was open) — extend `test/widget/battle_screen_test.dart`

### Implementation for User Story 4

- [X] T043 Add `required String battleId` constructor parameter to `BattleScreen` in `lib/ui/screens/battle_screen.dart`; make the screen watch `matchNotifierProvider` and derive its active battle with `state.activeBattles.firstWhereOrNull((b) => b.id == battleId)`
- [X] T044 Implement resolved-battle fallback in `BattleScreen` in `lib/ui/screens/battle_screen.dart`: when `activeBattle == null`, display `_BattleSummary` using the last-known `Battle` snapshot stored in local widget state; confirm T042 turns green
- [X] T045 Wire "Next Round" button in `BattleScreen` in `lib/ui/screens/battle_screen.dart`: call `ref.read(matchNotifierProvider.notifier).advanceBattleRound(battleId)`; this call must trigger full post-battle cleanup (zero-soldier removal, `battleId` clear, castle transfer) when the round resolves the battle — verify by confirming T023c's cleanup path is exercised; confirm T041 turns green; confirm T040 turns green
- [X] T046 Wire `BattleIndicator.onTap` in `MapScreen` in `lib/ui/screens/map_screen.dart`: on tap call `Navigator.push(context, MaterialPageRoute(builder: (_) => BattleScreen(battleId: ab.id)))` for the tapped battle

**Checkpoint**: Full battle loop is playable. Trigger → indicator → tap → view live battle → advance rounds → summary on resolve → back to map.

---

## Phase 7: Integration Test & End-to-End Validation

**Purpose**: Confirm the entire battle lifecycle (trigger → indicator → tap → advance → resolve → cleanup) works end-to-end in a device/emulator context.

- [ ] T047 Create integration test covering SC-001 through SC-005 (road-junction collision lifecycle) — new file `test/integration/battle_loop_test.dart`
- [ ] T048 Extend integration test with SC-006 through SC-009 (castle-assault lifecycle and empty-castle capture) — `test/integration/battle_loop_test.dart`

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, performance validation, and final analysis gate.

- [ ] T049 [P] Run `flutter analyze` — fix any new issues introduced during this feature; target: zero issues
- [ ] T050 [P] Run `flutter test` — confirm all tests pass (unit + widget + integration)
- [ ] T051 Profile game-loop tick with Flutter DevTools on an Android Snapdragon 665-class device: confirm single tick ≤ 16 ms with 2–5 active battles; the profiled tick MUST include the `MatchDao.saveMatch` persistence call (with `BattlesTable` row inserts active) — not just the in-memory logic — to catch SQLite-induced jank (fix U4); capture DevTools screenshot for PR evidence
- [ ] T052 Profile `BattleIndicator` animation: confirm 60 fps is maintained with up to 5 simultaneous indicators on the map; capture DevTools screenshot
- [ ] T053 [P] Verify `CompanyNotifier` blocks player move orders when `company.battleId != null` in `lib/state/company_notifier.dart`; add unit test if guard is missing
- [ ] T054 [P] Decide the fate of the unused global `battleNotifierProvider` path in `lib/state/battle_notifier.dart` (per R-005: retained but unused for new flow): if removing, first update all usages in `test/widget/battle_screen_test.dart` to use the new `matchNotifierProvider`-based override instead; if retaining, add a `// TODO(cleanup): battleNotifierProvider retained for backward compatibility — remove after BattleScreen migration is complete` comment; confirm no test breakage by running `flutter test test/widget/battle_screen_test.dart` after the change
- [ ] T055 Run quickstart.md step-by-step validation: execute each `flutter test` command in Section 4 and confirm all outputs match expectations

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └─► Phase 2 (Foundational) — BLOCKS everything
        ├─► Phase 3 (US1 — road junction) — MVP
        │     └─► Phase 4 (US2 — castle assault) — builds on US1 cleanup/trigger logic
        │           └─► Phase 4b (US5 — post-battle state) — completes cleanup rules
        │                 └─► Phase 5 (US3 — map indicator) — reads activeBattles from state
        │                       └─► Phase 6 (US4 — tap to battle screen) — wires indicator tap
        │                             └─► Phase 7 (Integration tests)
        │                                   └─► Phase 8 (Polish)
        └─► (Phase 5 T038 BattleIndicator widget can be developed in parallel with Phase 3/4/4b)
```

### User Story Dependencies

| Story | Depends On | Reason |
|-------|-----------|--------|
| US1 (road junction) | Phase 2 complete | Needs `ActiveBattle`, `battleId` on `CompanyOnMap`, schema migration |
| US2 (castle assault) | US1 complete | Reuses `ActiveBattle` creation, Phase C cleanup, and reinforcement logic |
| US5 (post-battle state) | US2 complete | Cleanup rules build directly on US1 Phase C and US2 castle transfer logic |
| US3 (map indicator) | US1 complete (needs `activeBattles` in `MatchState`) | Reads `state.activeBattles` populated by US1 |
| US4 (tap to screen) | US3 complete, `advanceBattleRound` from US1 | Wires tap on `BattleIndicator`; needs `BattleScreen` changes |

### Within Each User Story

1. Write **failing** tests first — confirm they fail before writing implementation
2. Implement minimum code to turn tests green
3. Refactor while keeping all tests green
4. Run `flutter analyze` after every task that touches a `.dart` file

### Parallel Opportunities

- **T005 + T006** (`ActiveBattle` tests + impl) run in parallel with **T003 + T004** (`battleId` tests + impl)
- **T007** (`BattlesTable`) and **T008** (`battleId` column) run in parallel
- **T011–T015** (all US1 failing tests) can be written in parallel before any implementation
- **T056–T062** (all US5 failing tests) can be written in parallel before any US5 implementation
- **T034 + T035** (`BattleIndicator` widget tests) run in parallel with US1/US2/US5 implementation
- **T038** (`BattleIndicator` widget) can be built in parallel once T034/T035 are written
- **T040, T041, T042** (`BattleScreen` widget tests) can be written in parallel
- **T049, T050, T053, T054** (Polish tasks) run in parallel

---

## Parallel Example: User Story 1

```
# Parallel: write all US1 failing tests simultaneously (different test methods, same file is fine)
Task T011: failing test — mid-edge pass-through clamp
Task T012: failing test — ActiveBattle created + companies frozen on roadCollision
Task T013: failing test — battle advances one round per tick
Task T014: failing test — post-battle cleanup
Task T015: failing test — same-owner companies do not trigger battle

# Then implement sequentially (each fix enables the next):
Task T016 → T017 → T018 → T019 → T020 → T021 → T022 → T023 → T024
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: confirm baseline is green
2. Complete Phase 2: foundational domain + DB changes (T003–T010)
3. Complete Phase 3: US1 road-junction collision (T011–T024)
4. **STOP and VALIDATE**: run `flutter test test/domain/`, verify all US1 tests pass
5. Demo: two opposing companies on a road — they halt and battle resolves

### Incremental Delivery

| Step | Completes | What You Can Demo |
|------|-----------|-------------------|
| Phase 1 + 2 | Foundation | — |
| Phase 3 (US1) | Road-junction battles | Companies halt and fight on roads |
| Phase 4 (US2) | Castle assault battles | Garrisoned castles must be fought for |
| Phase 4b (US5) | Full post-battle cleanup | Dead companies vanish; survivors resume march |
| Phase 5 (US3) | Map indicator | Player sees ⚔ on the map during battles |
| Phase 6 (US4) | Live battle detail | Player can tap to watch battle unfold |
| Phase 7 + 8 | Full polish | PR-ready, 60 fps confirmed |

---

## Notes

- **`[P]`** tasks target different files and have no dependency on incomplete tasks in the same phase — safe to run in parallel.
- **`[Story]`** labels (US1–US5) map directly to user stories in `spec.md` for full traceability.
- **TDD is non-negotiable** (Constitution Principle III): every domain task starts with a failing test. Never implement before the test exists and is confirmed failing.
- **Drift codegen** (T010) must be re-run any time a `Table` class or `@DriftDatabase` annotation changes. If `.g.dart` errors appear, run `dart run build_runner build --delete-conflicting-outputs`.
- **`MatchPhase.inBattle`** transition must be removed from `MatchNotifier` (T022) once `activeBattles.isNotEmpty` drives it — leaving both creates duplicate state updates (see quickstart.md Gotcha #3).
- Commit after each logical task group using the convention: `feat(battle): <description>` / `test(battle): <description>`.
