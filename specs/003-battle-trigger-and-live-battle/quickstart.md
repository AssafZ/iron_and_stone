# Quickstart: Battle Trigger & Live Battle View

**Feature**: `003-battle-trigger-and-live-battle`  
**Date**: 2026-03-04

This guide gives an implementer everything needed to start coding immediately after reading it.

---

## 1. Prerequisites

```bash
# Confirm you are on the feature branch
git branch --show-current
# → 003-battle-trigger-and-live-battle

# Run all tests green before you start
flutter test
# → All tests passing

flutter analyze
# → No issues found
```

---

## 2. Implementation Order (Red-Green-Refactor)

Follow this exact order. Each step has a failing test you write first.

### Step 1 — Add `battleId` to `CompanyOnMap` (domain)

**File**: `lib/domain/use_cases/check_collisions.dart`

Add `String? battleId` field with sentinel `copyWith` support (mirror the `destination` sentinel pattern).

**Test first** (`test/domain/use_cases/check_collisions_test.dart`):
```dart
test('CompanyOnMap.copyWith clears battleId when null passed explicitly', () {
  final co = CompanyOnMap(id: 'x', ..., battleId: 'battle_n1');
  final cleared = co.copyWith(battleId: null);  // explicit null
  expect(cleared.battleId, isNull);
});
```

---

### Step 2 — Fix FR-003 mid-edge pass-through (domain)

**File**: `lib/domain/use_cases/tick_match.dart` — `_advance()` method

Guard: before the `newProgress >= 1.0` "arrived at next node" branch, check if any enemy company already has `currentNode.id == nextNode.id`. If yes, clamp to nextNode and stop.

**Test first** (`test/domain/use_cases/tick_match_test.dart`):
```dart
test('company stops at enemy-occupied node even if progress would carry it past', () {
  // Set up: player company 90% of the way to a node occupied by an AI company.
  // After tick: player is AT the node (progress 0.0), not past it.
  // CheckCollisions should then emit a roadCollision.
});
```

---

### Step 3 — Create `ActiveBattle` entity (domain)

**File**: `lib/domain/entities/active_battle.dart` *(new)*

```dart
final class ActiveBattle {
  final String id;          // "battle_<nodeId>"
  final String nodeId;
  final List<String> attackerCompanyIds;
  final List<String> defenderCompanyIds;
  final Ownership attackerOwnership;
  final Battle battle;

  // factory, copyWith, toString
}
```

**Test first** (`test/domain/entities/active_battle_test.dart`):
```dart
test('id equals battle_<nodeId>', () {
  final ab = ActiveBattle(nodeId: 'junction_3', ...);
  expect(ab.id, equals('battle_junction_3'));
});
```

---

### Step 4 — Update `TickMatch` to orchestrate battle loop (domain)

**File**: `lib/domain/use_cases/tick_match.dart`

1. Add `required List<ActiveBattle> activeBattles` to `tick()`.
2. After collision detection (step 5): process new triggers → create `ActiveBattle`s, tag company `battleId`s.
3. Advance each existing `ActiveBattle` by one round via `BattleEngine.resolveRound`.
4. Apply post-battle cleanup for resolved battles.
5. `TickResult` gains `List<ActiveBattle> activeBattles`.

**Test first** (extend `test/domain/use_cases/tick_match_test.dart`):
```dart
test('tick creates ActiveBattle and freezes companies when collision detected', ...);
test('tick advances existing battle by one round each tick', ...);
test('tick cleans up resolved battle and updates survivor compositions', ...);
test('tick transfers castle ownership on castleAssault attackersWin', ...);
test('tick removes zero-soldier companies after battle resolution', ...);
```

---

### Step 5 — Update `MatchState` and `MatchNotifier` (state)

**Files**: `lib/state/match_notifier.dart`

1. Add `List<ActiveBattle> activeBattles = const []` to `MatchState`.
2. Pass `current.activeBattles` to `TickMatch.tick(activeBattles: ...)`.
3. Store `result.activeBattles` back into state.
4. Add `void advanceBattleRound(String battleId)` action — calls `BattleEngine.resolveRound` on the matching `ActiveBattle` and applies cleanup if resolved.
5. Remove the old `MatchPhase.inBattle` transition (now driven by `activeBattles.isNotEmpty` instead).

---

### Step 6 — Drift schema migration (data)

**Files**:
- `lib/data/drift/tables/battles_table.dart` *(new)*
- `lib/data/drift/tables/companies_table.dart` — add `battleId` column
- `lib/data/drift/app_database.dart` — bump `schemaVersion` to `2`, add migration
- `lib/data/drift/match_dao.dart` — save/load `activeBattles`

After adding the table, regenerate drift code:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### Step 7 — `BattleScreen` multi-battle routing (presentation)

**File**: `lib/ui/screens/battle_screen.dart`

1. Add `const BattleScreen({super.key, required this.battleId})`.
2. Watch `matchNotifierProvider`; find active battle by `battleId`.
3. If `activeBattle == null` (resolved): show `_BattleSummary` using stored last-known state.
4. "Next Round" calls `ref.read(matchNotifierProvider.notifier).advanceBattleRound(battleId)`.

**Test first** (extend `test/widget/battle_screen_test.dart`):
```dart
test('BattleScreen shows correct battle for given battleId', ...);
test('Next Round button calls advanceBattleRound with correct battleId', ...);
test('shows _BattleSummary when activeBattle is null (resolved)', ...);
```

---

### Step 8 — `BattleIndicator` widget (presentation)

**File**: `lib/ui/widgets/battle_indicator.dart` *(new)*

```dart
class BattleIndicator extends StatefulWidget {
  final String battleId;
  final VoidCallback onTap;
  const BattleIndicator({super.key, required this.battleId, required this.onTap});
}
```

- `AnimationController` with `repeat(reverse: true)` for pulse (use `SingleTickerProviderStateMixin`).
- Outer `SizedBox(width: 44, height: 44)` for tap target.
- `RepaintBoundary` wrapping the animated child.

**Test first** (`test/widget/battle_indicator_test.dart`):
```dart
test('BattleIndicator renders at correct position', ...);
test('tap fires onTap callback', ...);
test('minimum 44x44 tap target', ...);
```

---

### Step 9 — Map screen integration (presentation)

**File**: `lib/ui/screens/map_screen.dart`

1. Watch `matchState.activeBattles`.
2. In the `Stack` children, after company markers: render a `BattleIndicator` per active battle, positioned at `_nodeCanvasPos(node)` for the battle's `nodeId`.
3. `onTap` callback: `Navigator.push(BattleScreen(battleId: ab.id))`.
4. Suppress normal company markers for companies with `battleId != null` (or render them underneath the indicator).

---

### Step 10 — Integration test (end-to-end)

**File**: `test/integration/battle_loop_test.dart` *(new)*

Covers SC-001 through SC-009: trigger → indicator → tap → advance rounds → outcome → cleanup.

---

## 3. Key Code Pointers

| What you need | Where it lives |
|---------------|---------------|
| `BattleEngine.resolveRound` | `lib/domain/rules/battle_engine.dart:32` |
| `ResolveBattle.addReinforcement` | `lib/domain/use_cases/resolve_battle.dart:110` |
| Node-to-canvas position | `MapScreen._nodeCanvasPos` in `lib/ui/screens/map_screen.dart` |
| Slot-offset pattern for markers | `_buildSlotMap` / `_offsetForCompany` in `map_screen.dart` |
| `destination` sentinel `copyWith` | `CompanyOnMap.copyWith` in `check_collisions.dart:80` |
| Drift migration pattern | `app_database.dart` — `MigrationStrategy.onUpgrade` |
| Castle ownership lookup | `MatchState.castles` + `Castle.ownership` in `match_notifier.dart` |

---

## 4. Run Tests

```bash
# Unit tests only (fast)
flutter test test/domain/

# Widget tests
flutter test test/widget/

# All tests
flutter test

# Analyze
flutter analyze
```

---

## 5. Gotchas

1. **Drift codegen must run** after any change to a `Table` class or `AppDatabase`. If you see `part 'app_database.g.dart'` errors, run `dart run build_runner build --delete-conflicting-outputs`.
2. **`Battle.attackers` / `defenders` invariant**: `Battle` throws if either list is empty at construction. When both sides are eliminated, `BattleEngine` inserts a zero-soldier placeholder `Company`. Post-battle cleanup must filter these out before writing to `CompanyOnMap.company.composition`.
3. **`MatchPhase.inBattle` is now set by `activeBattles.isNotEmpty`**: Remove the old trigger-based phase transition from `MatchNotifier.tick()` to avoid duplicate state updates.
4. **Reinforcement same tick as battle start**: A company arriving at a node where a trigger fires in the same tick must be added to the `Battle` at construction, not as a separate `addReinforcement` call. The trigger's `companyIds` list already includes all companies at the node after `_advanceCompanies` runs.
5. **Survivor destination = battle node**: After cleanup, a company whose `destination.id == currentNode.id` must not enter an infinite "arrived / not arrived" loop. `_advance()` already handles this (`destination == currentNode → stationary`).
