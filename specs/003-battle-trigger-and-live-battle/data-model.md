# Data Model: Battle Trigger & Live Battle View

**Feature**: `003-battle-trigger-and-live-battle`  
**Date**: 2026-03-04

---

## Entity: `ActiveBattle` *(new — `lib/domain/entities/active_battle.dart`)*

Pairs an in-progress `Battle` with its map location and the IDs of the `CompanyOnMap` entries on each side.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | `"battle_<nodeId>"` — stable, unique per node |
| `nodeId` | `String` | ID of the contested `MapNode` |
| `attackerCompanyIds` | `List<String>` | IDs of `CompanyOnMap`s on the attacker side |
| `defenderCompanyIds` | `List<String>` | IDs of `CompanyOnMap`s on the defender side |
| `attackerOwnership` | `Ownership` | Owner of the attacking side — used for castle transfer |
| `battle` | `Battle` | Live `Battle` entity (HP maps, round log, outcome) |

**Invariants**:
- `attackerCompanyIds` and `defenderCompanyIds` are non-empty at construction.
- `id == "battle_${nodeId}"` — enforced in the factory / constructor.
- `battle.attackers` and `battle.defenders` lengths match the number of **unique** companies on each side (one `Company` per `CompanyOnMap` in the MVP; see R-008).

**State transitions**:
```
CREATED (outcome == null)
  → [BattleEngine.resolveRound per tick / manual "Next Round"]
  → RESOLVED (outcome != null)
  → [TickMatch post-battle cleanup removes from activeBattles]
  → REMOVED
```

**Serialisation** (`BattlesTable`): See DB schema below.

---

## Entity: `CompanyOnMap` *(modified — `lib/domain/use_cases/check_collisions.dart`)*

New field added:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `battleId` | `String?` | `null` | Non-null when the company is engaged in a battle. Value equals the `ActiveBattle.id` (`"battle_<nodeId>"`). Movement engine skips companies with `battleId != null`. |

**`copyWith` sentinel**: Same `Object _battleIdSentinel` pattern as `destination` — allows explicit `null` to be passed to clear `battleId` post-battle.

**Validation rules**:
- A company with `battleId != null` MUST NOT have its `progress` or `currentNode` advanced by `TickMatch._advance`.
- A company with `battleId != null` MUST NOT accept a player move order (enforced in `CompanyNotifier`).

---

## Entity: `MatchState` *(modified — `lib/state/match_notifier.dart`)*

New field added:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `activeBattles` | `List<ActiveBattle>` | `const []` | All in-progress battles. Populated by `TickMatch` when triggers are detected. Cleared per battle when that battle resolves. |

`copyWith` updated to accept `List<ActiveBattle>? activeBattles`.

---

## Entity: `TickResult` *(modified — `lib/domain/use_cases/tick_match.dart`)*

New field added:

| Field | Type | Notes |
|-------|------|-------|
| `activeBattles` | `List<ActiveBattle>` | Replaces the previous `battleTriggers`-only output for battle state. Contains all battles (new + continuing + just-resolved-and-cleaned-up-removed). |

`battleTriggers` is retained for backward-compatibility with existing tests; it continues to list raw triggers detected this tick.

---

## Entity: `TickMatch.tick()` *(new parameter)*

| Parameter | Type | Notes |
|-----------|------|-------|
| `activeBattles` | `List<ActiveBattle>` | Current active battles passed in from `MatchState`. Required. |

---

## DB Schema Changes

### Modified: `companies_table.dart`

New column:

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `battleId` | `TextColumn` | `''` (empty = null) | Maps to `CompanyOnMap.battleId`; empty string means `null` on load |

### New: `battles_table.dart`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `TEXT PRIMARY KEY` | `"battle_<nodeId>"` |
| `matchId` | `TEXT` | FK → `MatchesTable.id` |
| `nodeId` | `TEXT` | Contested map node ID |
| `attackerCompanyIds` | `TEXT` | JSON array e.g. `["player_co0","player_co1"]` |
| `defenderCompanyIds` | `TEXT` | JSON array e.g. `["ai_co0"]` |
| `attackerOwnership` | `TEXT` | `'player'` \| `'ai'` |
| `battleJson` | `TEXT` | Full JSON encoding of the `Battle` — see below |

**`battleJson` structure**:
```json
{
  "roundNumber": 3,
  "kind": "roadCollision",
  "outcome": null,
  "highGroundActive": false,
  "attackerHp": { "warrior_0": 8, "archer_1": 10 },
  "defenderHp": { "warrior_0": 5 },
  "attackers": [{ "warrior": 2, "archer": 1 }],
  "defenders": [{ "warrior": 1 }],
  "roundLog": ["Round 1: ...", "Round 2: ...", "Round 3: ..."]
}
```

### `app_database.dart` change

```dart
@DriftDatabase(tables: [MatchesTable, CastlesTable, CompaniesTable, BattlesTable])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(companiesTable, companiesTable.battleId);
        await m.createTable(battlesTable);
      }
    },
  );
}
```

---

## State Transitions — Full Battle Lifecycle

```
TICK N:
  CheckCollisions → BattleTrigger(nodeId: "junction_3", kind: roadCollision)
  TickMatch: no ActiveBattle at "junction_3" yet
    → CREATE ActiveBattle{id:"battle_junction_3", nodeId:"junction_3", ...}
    → TAG companies: co.battleId = "battle_junction_3"
    → BattleEngine.resolveRound(battle) → round 1 result
    → MatchState.activeBattles = [..., newActiveBattle]

TICK N+1 … N+k:
  TickMatch: ActiveBattle exists at "junction_3"
    → BattleEngine.resolveRound(activeBattle.battle) → round k+1 result
    → Update ActiveBattle in list

TICK N+k (outcome != null after resolveRound):
  TickMatch: post-battle cleanup
    → Update surviving CompanyOnMap.company.composition
    → Remove zero-soldier companies from companies list
    → Transfer castle ownership if castleAssault + attackersWin
    → Clear battleId on survivors
    → Remove ActiveBattle from activeBattles list

MAP RENDER (any tick N … N+k):
  MatchState.activeBattles.isNotEmpty → render BattleIndicator at nodeId canvas coords
  tap BattleIndicator → Navigator.push(BattleScreen(battleId: "battle_junction_3"))

BattleScreen:
  Watches matchNotifierProvider
  Finds activeBattle = state.activeBattles.firstWhere(id == battleId)
  If activeBattle == null (resolved while screen open) → show _BattleSummary
  "Next Round" → MatchNotifier.advanceBattleRound(battleId)
```
