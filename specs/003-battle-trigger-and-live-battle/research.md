# Research: Battle Trigger & Live Battle View

**Feature**: `003-battle-trigger-and-live-battle`  
**Date**: 2026-03-04

---

## R-001 — Mid-edge pass-through fix (FR-003)

**Decision**: Clamp `progress` to `0.0` and set `currentNode = nextNode` when `newProgress >= 1.0` **and** `nextNode` is occupied by an enemy company. The company is stopped at the node; collision detection runs on the updated positions in step 5 of the same tick.

**Rationale**: `_advance()` in `TickMatch` already does the "arrived at next node" branch (`newProgress >= 1.0` → `copyWith(currentNode: nextNode, progress: 0.0)`). The fix is a single guard: before executing that branch, look up whether `nextNode` is enemy-occupied in the current `companies` list. If yes, set `currentNode = nextNode`, `progress = 0.0`, and **stop** (do not recurse for remaining progress). `CheckCollisions.check()` then finds the collision in the same tick.

**Alternatives considered**:
- Pre-check the full path before advancing: more complex, overkill — only the immediate next node matters per tick.
- Raising progress fractionally so the company "almost" arrives but never quite: breaks determinism and creates visual jitter.

---

## R-002 — `ActiveBattle` entity design

**Decision**: A plain Dart `final class ActiveBattle` with fields: `id` (`String`, value `"battle_<nodeId>"`), `nodeId` (`String`), `attackerCompanyIds` (`List<String>`), `defenderCompanyIds` (`List<String>`), `battle` (`Battle`), `attackerOwnership` (`Ownership`). No inheritance, no generics.

**Rationale**: The spec requires pairing a `Battle` (which tracks HP maps and round logs) with a map node and the IDs of participating `CompanyOnMap`s. A thin wrapper class satisfies all use cases (map indicator rendering, routing tap events, post-battle cleanup, persistence). The `id = "battle_<nodeId>"` key rule means no UUID generation is needed and the `id` is stable across reinforcements.

**`attackerOwnership` field**: Needed by `MatchNotifier` post-battle cleanup to determine castle ownership transfer (mirrors the `attackerOwnership` param currently passed to `ResolveBattle.resolve`).

**Alternatives considered**:
- Embedding `battle` directly in `MatchState` as a `Map<String, Battle>`: loses the attacker/defender company ID lists needed for cleanup; requires reconstructing context at post-battle time.
- Reusing `BattleResult` as the in-flight state: `BattleResult` is an end-state DTO, not suitable for mid-battle tracking.

---

## R-003 — `battleId` field on `CompanyOnMap`

**Decision**: Add `String? battleId` to `CompanyOnMap`. `copyWith` uses the same sentinel pattern already in place for `destination` so `null` can be passed explicitly.

**Rationale**: The movement engine needs a single, cheap check (`battleId != null`) to skip advancement. Company markers on the map need it to suppress the normal marker when a battle indicator is shown. The ID doubles as the routing key for tap events (`"battle_<nodeId>"`). No other field on `CompanyOnMap` changes.

**Alternatives considered**:
- A `Set<String> inBattleCompanyIds` on `MatchState`: requires two lookups instead of one; breaks the self-contained nature of `CompanyOnMap`.

---

## R-004 — `TickMatch` battle orchestration

**Decision**: Extend `TickMatch.tick()` with three new phases (executed after existing step 5 collision detection):

1. **Process new triggers**: For each `BattleTrigger` from `CheckCollisions`, if no `ActiveBattle` already exists at that node, create one and tag the involved companies with `battleId`. If one exists (reinforcement), call `ResolveBattle.addReinforcement` and tag the new company.
2. **Advance active battles**: For each `ActiveBattle` in the incoming `activeBattles` list (passed as a new param to `tick()`), call `BattleEngine.resolveRound(activeBattle.battle)` and update the `ActiveBattle` with the result.
3. **Post-battle cleanup**: For each `ActiveBattle` whose `battle.outcome` is non-null, apply cleanup: update surviving company compositions, remove zero-soldier companies, transfer castle ownership if applicable, clear `battleId` on survivors, remove `ActiveBattle` from the list.

**Signature change**: `TickResult` gains `List<ActiveBattle> activeBattles`; `TickMatch.tick()` gains a required `List<ActiveBattle> activeBattles` parameter.

**Rationale**: Keeping orchestration in `TickMatch` respects the single-tick orchestrator pattern already established. All existing phases (reinforce, advance, AI, collisions, victory) are unchanged; new phases are appended.

**Alternatives considered**:
- Handling battle advancement in `MatchNotifier` (state layer): violates Constitution Principle I (game rules in domain) and Principle II (no logic in state layer).
- A separate `AdvanceBattles` use case: would be trivially thin and adds unnecessary indirection (YAGNI).

---

## R-005 — Multi-battle `BattleScreen` routing

**Decision**: Add a `String battleId` constructor parameter to `BattleScreen`. The screen watches `matchNotifierProvider` and finds the `ActiveBattle` by `battleId` from `MatchState.activeBattles`. The "Next Round" button calls a new `MatchNotifier.advanceBattleRound(battleId)` action. The global `battleNotifierProvider` is retained but unused for the new flow; it may be removed in a future cleanup.

**Rationale**: The simplest change that makes `BattleScreen` work for multiple simultaneous battles without rewriting it. No new Riverpod provider family is needed — the `ActiveBattle` list already lives in `MatchState`. The `advanceBattleRound` action on `MatchNotifier` is a one-liner that calls `BattleEngine.resolveRound` and writes back the updated `ActiveBattle`.

**Alternatives considered**:
- `Provider.family<BattleState, String>(battleId)`: cleaner isolation but requires migrating all existing `BattleScreen` test overrides; disproportionate for MVP scope.
- Reading battle state from a separate `battleNotifierProvider` per battle: requires Riverpod provider-scoped overrides and significantly more boilerplate.

---

## R-006 — Drift schema migration (schemaVersion 1 → 2)

**Decision**: Add `BattlesTable` (new) and a `battleId` column to `CompaniesTable` (nullable text, default empty string). Bump `AppDatabase.schemaVersion` to `2`. Implement `MigrationStrategy` with `onUpgrade` that runs `ALTER TABLE companies ADD COLUMN battle_id TEXT NOT NULL DEFAULT ''`.

**Rationale**: Drift requires explicit migrations when adding columns or tables to an existing schema. The `ALTER TABLE` migration is the minimal SQLite change. A new `BattlesTable` stores one row per `ActiveBattle` with a JSON blob for the `Battle` payload (HP maps and round logs are already JSON-friendly maps/lists).

**`BattlesTable` schema**:
- `id` TEXT PRIMARY KEY — the `"battle_<nodeId>"` string
- `matchId` TEXT — FK to `MatchesTable`
- `nodeId` TEXT — the contested map node ID
- `attackerCompanyIds` TEXT — JSON array of company ID strings
- `defenderCompanyIds` TEXT — JSON array of company ID strings
- `attackerOwnership` TEXT — 'player' | 'ai'
- `battleJson` TEXT — full JSON encoding of the `Battle` (roundNumber, kind, outcome, attackerHp, defenderHp, roundLog, attackers composition, defenders composition)

**Alternatives considered**:
- Storing `activeBattles` as a JSON column on the match row: makes partial updates of one battle require re-serialising the entire list; harder to query for debugging; inconsistent with how castles/companies are stored.
- Using a `BattleRoundsTable` (one row per round): over-engineered for MVP; round log is already a `List<String>` in `Battle`.

---

## R-007 — Battle indicator widget

**Decision**: `BattleIndicator` is a `StatefulWidget` (needs `AnimationController`) that renders a `🗡️` crossed-swords icon with a pulsing red `BoxDecoration` overlay using an `AnimationController` with `repeat(reverse: true)`. Wrapped in `RepaintBoundary`. Tap target is 44 × 44 pt enforced via `SizedBox`. Positioned on the map canvas exactly like company markers (using `_nodeCanvasPos`).

**Rationale**: Matches the constitution 60 fps requirement — `AnimationController` uses the vsync ticker provided by `TickerProviderStateMixin`. `RepaintBoundary` ensures the pulsing animation only repaints its own subtree. 44 × 44 pt tap target per spec 002 / FR-014.

**Alternatives considered**:
- `AnimatedOpacity` / `TweenAnimationBuilder`: simpler but produces full-widget rebuilds rather than painter-level updates; worse for frame budget at many simultaneous battles.
- Lottie animation: new dependency, violates YAGNI.

---

## R-008 — Post-battle HP-to-composition conversion

**Decision**: After `Battle.outcome` is set, the surviving companies' compositions are derived from the **final `Battle.attackers` / `Battle.defenders` lists** as updated by `BattleEngine._companiesFromHp`. These lists already reflect the post-battle soldier counts (the engine writes them back on every round). `TickMatch` simply iterates `ActiveBattle.attackerCompanyIds` / `defenderCompanyIds`, finds the matching `CompanyOnMap` entries, and replaces their `company.composition` with the surviving `Company.composition` from the final `Battle`.

**Rationale**: `BattleEngine._companiesFromHp` (private) collapses all survivors into a single `Company` per side. For the MVP this is acceptable — multi-company-per-side compositions are summed. A future task can split survivors back to individual companies by tracking a company-index-to-company-id mapping in `ActiveBattle`.

**Alternatives considered**:
- Tracking per-original-company HP across battle rounds: requires a more complex HP map keying scheme; deferred to post-MVP.
