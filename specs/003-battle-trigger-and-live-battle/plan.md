# Implementation Plan: Battle Trigger & Live Battle View

**Branch**: `003-battle-trigger-and-live-battle` | **Date**: 2026-03-04 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `specs/003-battle-trigger-and-live-battle/spec.md`

## Summary

Fix two bugs (companies passing through opponents, companies entering garrisoned castles without battle) and add the full battle loop: trigger detection → `ActiveBattle` state management → map battle indicator → tap-to-view live battle detail → post-battle cleanup (soldier count updates, company elimination, castle ownership transfer). All new game-rule logic lives in the domain layer; `TickMatch` is the orchestrator; `MatchState` gains an `activeBattles` list that is fully persisted via a new drift `BattlesTable`.

## Technical Context

**Language/Version**: Dart 3.x (sound null-safety)  
**Primary Dependencies**: Flutter 3.x, Riverpod (state), drift/drift_flutter (SQLite persistence)  
**Storage**: drift SQLite — new `battles_table` added; `companies_table` gains a `battleId` column  
**Testing**: `flutter_test` (unit + widget), `integration_test` (end-to-end flows)  
**Target Platform**: Android 8.0+ (API 26+), iOS 15+  
**Project Type**: Mobile game (single-player, local-only)  
**Performance Goals**: 60 fps on mid-range Android (Snapdragon 665) and iPhone XR; single game-loop tick ≤ 16 ms  
**Constraints**: No speculative abstractions (YAGNI); no new external packages; offline-only  
**Scale/Scope**: Single match, O(10) companies on map, O(5) simultaneous battles maximum in practice

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Domain Model First** | ✅ PASS | `ActiveBattle` entity, `battleId` field on `CompanyOnMap`, updated `TickMatch` orchestration, and `CheckCollisions` fix are all pure Dart in `lib/domain/`. No Flutter imports. |
| **II. Widget & Layer Separation** | ✅ PASS | Battle indicator widget and `BattleScreen` changes live in `lib/ui/`. `MatchNotifier` changes live in `lib/state/`. DAO changes live in `lib/data/`. No business logic in widgets. |
| **III. Test-First for Game Rules** | ✅ PASS | Every domain change (FR-003 fix, `ActiveBattle`, `TickMatch` battle orchestration, post-battle cleanup) requires a failing unit test before implementation. Widget tests for `BattleScreen` and `BattleIndicator`. |
| **IV. Performance & Frame Budget** | ✅ PASS | Battle indicator uses `AnimatedWidget` / `RepaintBoundary`; animation must not drop below 60 fps. `TickMatch` now does more work per tick (one `BattleEngine.resolveRound` call per active battle) — profiling required before merge. |
| **V. Simplicity & Incremental Complexity** | ✅ PASS | `battleId = "battle_<nodeId>"` avoids UUID generation. `ActiveBattle` is a thin wrapper over existing `Battle` + node association. `BattleScreen` is parameterised rather than replacing the global provider. No speculative abstractions. |

**Post-design re-check**: ✅ PASS — See Complexity Tracking below (one justified schema change).

## Project Structure

### Documentation (this feature)

```text
specs/003-battle-trigger-and-live-battle/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── quickstart.md        ← Phase 1 output
└── tasks.md             ← Phase 2 output (speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/
├── domain/
│   ├── entities/
│   │   ├── battle.dart                       EXISTING — no structural change
│   │   └── active_battle.dart                NEW — ActiveBattle entity
│   ├── use_cases/
│   │   ├── check_collisions.dart             MODIFY — add battleId field to CompanyOnMap; fix FR-003 mid-edge pass-through
│   │   └── tick_match.dart                   MODIFY — freeze in-battle companies; advance battle rounds; post-battle cleanup
│   └── rules/
│       └── battle_engine.dart                EXISTING — no change
│
├── state/
│   ├── match_notifier.dart                   MODIFY — add activeBattles to MatchState; wire TickMatch battle loop
│   └── battle_notifier.dart                  MODIFY — accept battleId param; read from MatchState.activeBattles
│
├── data/
│   └── drift/
│       ├── app_database.dart                 MODIFY — register BattlesTable; bump schemaVersion to 2
│       ├── match_dao.dart                    MODIFY — saveMatch/loadMatch include activeBattles
│       └── tables/
│           ├── battles_table.dart            NEW — drift table for ActiveBattle rows
│           └── companies_table.dart          MODIFY — add battleId column
│
└── ui/
    ├── screens/
    │   ├── map_screen.dart                   MODIFY — render BattleIndicator widgets; tap → BattleScreen(battleId)
    │   └── battle_screen.dart                MODIFY — accept battleId; read from MatchState.activeBattles
    └── widgets/
        └── battle_indicator.dart             NEW — animated crossed-swords map widget

test/
├── domain/
│   ├── entities/
│   │   └── active_battle_test.dart           NEW
│   └── use_cases/
│       ├── check_collisions_test.dart        EXTEND — FR-003 mid-edge cases; battleId field
│       └── tick_match_test.dart              EXTEND — battle freeze, round advance, post-battle cleanup
├── widget/
│   ├── battle_screen_test.dart               EXTEND — battleId param; multi-battle routing
│   └── battle_indicator_test.dart            NEW — renders at node coords; tap fires callback; removed on resolve
└── integration/
    └── battle_loop_test.dart                 NEW — full trigger → indicator → tap → resolve → cleanup flow
```

## Complexity Tracking

| Change | Why Needed | Simpler Alternative Rejected Because |
|--------|------------|-------------------------------------|
| New `battles_table` in drift schema (schemaVersion 2) | `ActiveBattle` must survive cold restarts (FR-026, SC-010); drift requires a table per persisted entity type | Storing battles as a JSON blob in the match row would couple schema evolution and make partial updates expensive; a dedicated table is consistent with how castles and companies are already persisted |
