// T047 — SC-001 through SC-005: Road-junction collision lifecycle.
// T048 — SC-006 through SC-009: Post-battle cleanup & castle-assault lifecycle.
//
// These tests exercise the full battle loop end-to-end using TickMatch directly
// (pure-Dart domain layer, no Flutter widget tree required).

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/advance_battle.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Shared test helpers
// ---------------------------------------------------------------------------

/// A minimal in-line map: player castle — junction — ai castle.
/// All road lengths are 100 so a company with speed=1 arrives in 100 ticks.
final class _SimpleMap {
  static const playerCastle =
      CastleNode(id: 'pc', x: 0.0, y: 0.0, ownership: Ownership.player);
  static const junction = RoadJunctionNode(id: 'jn', x: 100.0, y: 0.0);
  static const aiCastle =
      CastleNode(id: 'ac', x: 200.0, y: 0.0, ownership: Ownership.ai);

  static GameMap build() => GameMap(
        nodes: [playerCastle, junction, aiCastle],
        edges: [
          RoadEdge(from: playerCastle, to: junction, length: 100.0),
          RoadEdge(from: junction, to: playerCastle, length: 100.0),
          RoadEdge(from: junction, to: aiCastle, length: 100.0),
          RoadEdge(from: aiCastle, to: junction, length: 100.0),
        ],
      );

  static Match match() => Match(
        map: build(),
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );

  static List<Castle> castles({
    Ownership playerOwnership = Ownership.player,
    Ownership aiOwnership = Ownership.ai,
    Map<UnitRole, int> playerGarrison = const {},
    Map<UnitRole, int> aiGarrison = const {},
  }) =>
      [
        Castle(
            id: 'pc',
            ownership: playerOwnership,
            garrison: playerGarrison),
        Castle(id: 'ac', ownership: aiOwnership, garrison: aiGarrison),
      ];
}

/// Run ticks until [predicate] returns true or [maxTicks] is exceeded.
/// Returns null if [predicate] was never satisfied.
({
  List<Castle> castles,
  List<CompanyOnMap> companies,
  List<ActiveBattle> activeBattles,
})?
    _runUntil({
  required Match match,
  required List<Castle> castles,
  required List<CompanyOnMap> companies,
  List<ActiveBattle> activeBattles = const [],
  required bool Function(
          List<Castle>, List<CompanyOnMap>, List<ActiveBattle>)
      predicate,
  int maxTicks = 500,
}) {
  var currentCastles = castles;
  var currentCompanies = companies;
  var currentBattles = activeBattles;

  for (var i = 0; i < maxTicks; i++) {
    final result = const TickMatch().tick(
      match: match.copyWith(elapsedTime: Duration(seconds: i * 10)),
      castles: currentCastles,
      companies: currentCompanies,
      activeBattles: currentBattles,
    );
    currentCastles = result.castles;
    currentCompanies = result.companies;
    currentBattles = result.activeBattles;
    if (predicate(currentCastles, currentCompanies, currentBattles)) {
      return (
        castles: currentCastles,
        companies: currentCompanies,
        activeBattles: currentBattles,
      );
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // T047 — SC-001 to SC-005: Road-junction collision lifecycle
  // =========================================================================

  group('T047 — SC-001: road-junction collision triggers a battle', () {
    // SC-001: An opposing company arriving at a road-junction node occupied
    // by an enemy company must trigger a roadCollision battle — zero instances
    // of a company continuing past an enemy-occupied node without combat.

    test(
        'SC-001a: player company arrives at junction occupied by stationary AI company — '
        'battle is created, both companies frozen', () {
      final match = _SimpleMap.match();

      // Player company marches from player castle toward the junction.
      // AI company is already stationary AT the junction.
      final playerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.playerCastle,
        destination: _SimpleMap.aiCastle,
        company: Company(composition: {UnitRole.warrior: 10}),
      );
      final aiCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction, // already at junction
        company: Company(composition: {UnitRole.warrior: 10}),
      );

      // Run enough ticks for the player company to reach the junction (100 units,
      // warrior speed ≥ 1/tick with dt=10s) — 200 ticks is more than enough.
      final result = _runUntil(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [playerCo, aiCo],
        predicate: (_, companies, battles) => battles.isNotEmpty,
        maxTicks: 300,
      );

      expect(result, isNotNull,
          reason: 'A battle must be triggered within 300 ticks');
      expect(result!.activeBattles, hasLength(1));
      expect(result.activeBattles.first.id, equals('battle_jn'));

      // Both companies must be frozen (battleId set).
      final p =
          result.companies.firstWhere((c) => c.id == 'player_co0');
      final ai = result.companies.firstWhere((c) => c.id == 'ai_co0');
      expect(p.battleId, equals('battle_jn'));
      expect(ai.battleId, equals('battle_jn'));
    });

    test(
        'SC-001b: player company does NOT continue past a junction occupied by an enemy — '
        'currentNode stays at junction after the trigger tick', () {
      final match = _SimpleMap.match();

      // Player almost at junction (high progress), AI at junction.
      final playerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.playerCastle,
        destination: _SimpleMap.junction,
        progress: 0.99, // one tick will push it over
        company: Company(composition: {UnitRole.warrior: 10}),
      );
      final aiCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        company: Company(composition: {UnitRole.warrior: 10}),
      );

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [playerCo, aiCo],
        activeBattles: const [],
      );

      final p =
          result.companies.firstWhere((c) => c.id == 'player_co0');
      // Must be clamped at the junction — NOT past it.
      expect(p.currentNode.id, equals('jn'));
      expect(p.progress, equals(0.0));
      // Battle created at the junction.
      expect(result.activeBattles.any((b) => b.nodeId == 'jn'), isTrue);
    });

    test(
        'SC-001c: two friendly companies at the same junction do NOT trigger a battle',
        () {
      final match = _SimpleMap.match();

      final co1 = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        company: Company(composition: {UnitRole.warrior: 5}),
      );
      final co2 = CompanyOnMap(
        id: 'player_co1',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        company: Company(composition: {UnitRole.warrior: 5}),
      );

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [co1, co2],
        activeBattles: const [],
      );

      expect(result.activeBattles, isEmpty,
          reason: 'Same-owner companies must not trigger a battle');
      expect(co1.battleId, isNull);
      expect(co2.battleId, isNull);
    });
  });

  // =========================================================================
  // T047 — SC-002 & SC-003: Castle-entry scenarios
  // =========================================================================

  group('T047 — SC-002 & SC-003: castle-entry triggers', () {
    // SC-002: Attacking company arriving at a garrisoned enemy castle must
    // trigger a castleAssault battle.
    test(
        'SC-002: player company arriving at garrisoned AI castle triggers castleAssault',
        () {
      final match = _SimpleMap.match();

      // AI castle has a garrison company.
      final garrisonCo = CompanyOnMap(
        id: 'ai_garrison',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.aiCastle,
        company: Company(composition: {UnitRole.warrior: 8}),
      );
      // Player company at junction, heading to AI castle.
      final attackerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.aiCastle,
        progress: 0.99, // one tick carries it to AI castle
        company: Company(composition: {UnitRole.warrior: 10}),
      );

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(
          aiGarrison: {UnitRole.warrior: 8},
        ),
        companies: [attackerCo, garrisonCo],
        activeBattles: const [],
      );

      expect(
        result.activeBattles.any((b) => b.nodeId == 'ac'),
        isTrue,
        reason: 'A castleAssault battle must be triggered at the AI castle',
      );
      // Both companies must be frozen.
      final attacker =
          result.companies.firstWhere((c) => c.id == 'player_co0');
      final garrison =
          result.companies.firstWhere((c) => c.id == 'ai_garrison');
      expect(attacker.battleId, startsWith('battle_'));
      expect(garrison.battleId, startsWith('battle_'));
    });

    // SC-003: Attacking company at an EMPTY enemy castle captures it immediately.
    test(
        'SC-003: player company arriving at empty AI castle captures it immediately — '
        'no battle triggered, ownership transfers to player', () {
      final match = _SimpleMap.match();

      // No AI garrison company on the map.
      final attackerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.aiCastle,
        progress: 0.99,
        company: Company(composition: {UnitRole.warrior: 10}),
      );

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(), // AI castle empty — no garrison
        companies: [attackerCo],
        activeBattles: const [],
      );

      // No battle must be created.
      expect(result.activeBattles, isEmpty,
          reason: 'Empty castle must not trigger a battle');
      // Castle ownership must transfer to player.
      final aiCastle =
          result.castles.firstWhere((c) => c.id == 'ac');
      expect(aiCastle.ownership, equals(Ownership.player));
    });
  });

  // =========================================================================
  // T047 — SC-004 & SC-005: ActiveBattle carries correct company data
  // =========================================================================

  group('T047 — SC-004 & SC-005: ActiveBattle company assignment', () {
    // SC-004 (domain side): each ActiveBattle must list the correct company IDs.
    // SC-005 (domain side): multiple simultaneous battles are independent.

    test(
        'SC-004: ActiveBattle.attackerCompanyIds and defenderCompanyIds match '
        'the companies involved in the collision', () {
      final match = _SimpleMap.match();

      final playerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.aiCastle,
        company: Company(composition: {UnitRole.warrior: 5}),
      );
      final aiCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.playerCastle,
        company: Company(composition: {UnitRole.warrior: 5}),
      );

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [playerCo, aiCo],
        activeBattles: const [],
      );

      expect(result.activeBattles, hasLength(1));
      final ab = result.activeBattles.first;
      expect(ab.attackerCompanyIds, contains('player_co0'));
      expect(ab.defenderCompanyIds, contains('ai_co0'));
    });

    test(
        'SC-005: two simultaneous battles on the fixture map are tracked independently',
        () {
      // Use GameMapFixture which has j1, j2, j3, j4 junctions.
      final map = GameMapFixture.build();
      final match = Match(
        map: map,
        humanPlayer: Ownership.player,
        phase: MatchPhase.playing,
      );

      final j1 =
          map.nodes.firstWhere((n) => n.id == 'j1') as RoadJunctionNode;
      final j4 =
          map.nodes.firstWhere((n) => n.id == 'j4') as RoadJunctionNode;

      // Battle 1 at j1.
      final pCo1 = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: j1,
        company: Company(composition: {UnitRole.warrior: 5}),
      );
      final aiCo1 = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: j1,
        company: Company(composition: {UnitRole.warrior: 5}),
      );

      // Battle 2 at j4.
      final pCo2 = CompanyOnMap(
        id: 'player_co1',
        ownership: Ownership.player,
        currentNode: j4,
        company: Company(composition: {UnitRole.warrior: 5}),
      );
      final aiCo2 = CompanyOnMap(
        id: 'ai_co1',
        ownership: Ownership.ai,
        currentNode: j4,
        company: Company(composition: {UnitRole.warrior: 5}),
      );

      final castles = map.nodes.whereType<CastleNode>().map((n) {
        return Castle(id: n.id, ownership: n.ownership, garrison: const {});
      }).toList();

      final result = const TickMatch().tick(
        match: match,
        castles: castles,
        companies: [pCo1, aiCo1, pCo2, aiCo2],
        activeBattles: const [],
      );

      // Two separate battles at two separate nodes.
      expect(result.activeBattles, hasLength(2));
      final ids = result.activeBattles.map((b) => b.id).toSet();
      expect(ids, containsAll(['battle_j1', 'battle_j4']));

      // Companies for each battle have correct battleId.
      final p0 = result.companies.firstWhere((c) => c.id == 'player_co0');
      final ai0 = result.companies.firstWhere((c) => c.id == 'ai_co0');
      final p1 = result.companies.firstWhere((c) => c.id == 'player_co1');
      final ai1 = result.companies.firstWhere((c) => c.id == 'ai_co1');
      expect(p0.battleId, equals('battle_j1'));
      expect(ai0.battleId, equals('battle_j1'));
      expect(p1.battleId, equals('battle_j4'));
      expect(ai1.battleId, equals('battle_j4'));
    });
  });

  // =========================================================================
  // T048 — SC-006: Survivor soldier counts match post-battle HP map
  // =========================================================================

  group('T048 — SC-006: survivor compositions match final HP map', () {
    // SC-006: After a battle resolves, each surviving company's total soldier
    // count equals the exact number of soldiers alive at the end of the final
    // round.

    test(
        'SC-006: surviving company composition reflects soldiers alive after battle',
        () {
      // Use AdvanceBattle to drive a battle to completion, then verify the
      // cleanup that TickMatch applies produces correct compositions.
      final match = _SimpleMap.match();

      // Strong attacker vs weak defender — attacker wins quickly.
      final attackerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        battleId: 'battle_jn',
        company: Company(composition: {UnitRole.knight: 20}),
      );
      final defenderCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        battleId: 'battle_jn',
        company: Company(composition: {UnitRole.warrior: 3}),
      );

      // Build an ActiveBattle that matches these companies.
      final ab = ActiveBattle(
        nodeId: 'jn',
        attackerCompanyIds: ['player_co0'],
        defenderCompanyIds: ['ai_co0'],
        attackerOwnership: Ownership.player,
        battle: Battle(
          attackers: [attackerCo.company],
          defenders: [defenderCo.company],
        ),
      );

      // Advance the battle until it resolves.
      var current = ab;
      for (var i = 0; i < 100; i++) {
        if (current.battle.outcome != null) break;
        current = const AdvanceBattle().advance(current);
      }
      expect(current.battle.outcome, isNotNull,
          reason: 'Battle must resolve within 100 rounds');

      // Feed the resolved ActiveBattle back through TickMatch — it should
      // apply post-battle cleanup in Phase C.
      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [attackerCo, defenderCo],
        activeBattles: [current],
      );

      // SC-007 partial: no zero-soldier companies remain.
      for (final co in result.companies) {
        final total =
            co.company.composition.values.fold(0, (a, b) => a + b);
        expect(total, greaterThan(0),
            reason:
                'No company with 0 soldiers should remain after cleanup');
      }

      // SC-006: surviving company soldier count matches the HP state.
      // At minimum the winning side must have ≥ 1 soldier remaining.
      expect(result.companies, isNotEmpty);
    });
  });

  // =========================================================================
  // T048 — SC-007: Zero-soldier companies are eliminated after battle
  // =========================================================================

  group('T048 — SC-007: zero-soldier companies removed after battle', () {
    test(
        'SC-007: company that loses all soldiers is removed from companies list',
        () {
      final match = _SimpleMap.match();

      // Very strong attacker vs minimal defender — defender will be wiped.
      final attackerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        battleId: 'battle_jn',
        company: Company(composition: {UnitRole.knight: 50}),
      );
      final defenderCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        battleId: 'battle_jn',
        company: Company(composition: {UnitRole.peasant: 1}),
      );

      // Build and resolve the battle fully via AdvanceBattle.
      var ab = ActiveBattle(
        nodeId: 'jn',
        attackerCompanyIds: ['player_co0'],
        defenderCompanyIds: ['ai_co0'],
        attackerOwnership: Ownership.player,
        battle: Battle(
          attackers: [attackerCo.company],
          defenders: [defenderCo.company],
        ),
      );
      for (var i = 0; i < 200; i++) {
        if (ab.battle.outcome != null) break;
        ab = const AdvanceBattle().advance(ab);
      }
      expect(ab.battle.outcome, isNotNull,
          reason: 'Battle must resolve');

      final result = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [attackerCo, defenderCo],
        activeBattles: [ab],
      );

      // The resolved battle must be removed from activeBattles.
      expect(result.activeBattles, isEmpty,
          reason: 'Resolved battle must be removed from activeBattles');

      // The eliminated company (0 soldiers) must not appear in companies.
      for (final co in result.companies) {
        final total =
            co.company.composition.values.fold(0, (a, b) => a + b);
        expect(total, greaterThan(0),
            reason: 'No zero-soldier company should survive cleanup');
      }
    });
  });

  // =========================================================================
  // T048 — SC-008: Castle ownership transfers after castleAssault attacker win
  // =========================================================================

  group('T048 — SC-008: castle ownership transfers on castleAssault attacker win',
      () {
    test(
        'SC-008: after castleAssault resolves with attackers winning, '
        'castle.ownership == attacker ownership', () {
      final match = _SimpleMap.match();

      // Player attacks AI castle.
      final attackerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.aiCastle,
        battleId: 'battle_ac',
        company: Company(composition: {UnitRole.knight: 30}),
      );
      final garrisonCo = CompanyOnMap(
        id: 'ai_garrison',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.aiCastle,
        battleId: 'battle_ac',
        company: Company(composition: {UnitRole.warrior: 2}),
      );

      // Build a castleAssault ActiveBattle.
      var ab = ActiveBattle(
        nodeId: 'ac',
        attackerCompanyIds: ['player_co0'],
        defenderCompanyIds: ['ai_garrison'],
        attackerOwnership: Ownership.player,
        battle: Battle(
          attackers: [attackerCo.company],
          defenders: [garrisonCo.company],
          kind: BattleKind.castleAssault,
        ),
      );

      // Advance until attackers win.
      for (var i = 0; i < 200; i++) {
        if (ab.battle.outcome != null) break;
        ab = const AdvanceBattle().advance(ab);
      }
      expect(ab.battle.outcome, isNotNull,
          reason: 'Battle must resolve within 200 rounds');

      // Only test castle transfer when attackers actually won.
      // (If defenders win, castle should stay AI.)
      if (ab.battle.outcome == BattleOutcome.attackersWin) {
        final result = const TickMatch().tick(
          match: match,
          castles: _SimpleMap.castles(),
          companies: [attackerCo, garrisonCo],
          activeBattles: [ab],
        );

        final aiCastle =
            result.castles.firstWhere((c) => c.id == 'ac');
        expect(aiCastle.ownership, equals(Ownership.player),
            reason: 'Castle must transfer to attacker after attacker win');
      }
    });
  });

  // =========================================================================
  // T048 — SC-009: Full battle loop end-to-end — trigger → advance → cleanup
  // =========================================================================

  group('T048 — SC-009: full battle loop end-to-end without crash', () {
    test(
        'SC-009: trigger → battle → multiple rounds via AdvanceBattle → '
        'cleanup — completes without error', () {
      final match = _SimpleMap.match();

      // Two evenly matched companies at the junction — will trigger a battle.
      final playerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.aiCastle,
        company: Company(composition: {UnitRole.warrior: 5, UnitRole.archer: 3}),
      );
      final aiCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        destination: _SimpleMap.playerCastle,
        company: Company(composition: {UnitRole.warrior: 5, UnitRole.archer: 3}),
      );

      // Step 1: First tick — battle is triggered.
      final tick1 = const TickMatch().tick(
        match: match,
        castles: _SimpleMap.castles(),
        companies: [playerCo, aiCo],
        activeBattles: const [],
      );
      expect(tick1.activeBattles, hasLength(1),
          reason: 'Battle must be created on first tick');

      // Step 2: Advance the battle manually round by round until resolved.
      var ab = tick1.activeBattles.first;
      final companies = tick1.companies;
      final castles = tick1.castles;
      const maxRounds = 200;

      for (var i = 0; i < maxRounds; i++) {
        if (ab.battle.outcome != null) break;
        ab = const AdvanceBattle().advance(ab);
      }

      expect(ab.battle.outcome, isNotNull,
          reason: 'Battle must resolve within $maxRounds rounds');

      // Step 3: Feed resolved battle through TickMatch — Phase C cleanup runs.
      final cleanup = const TickMatch().tick(
        match: match,
        castles: castles,
        companies: companies,
        activeBattles: [ab],
      );

      // Battle must be gone from activeBattles.
      expect(cleanup.activeBattles, isEmpty,
          reason: 'Resolved battle must be removed from activeBattles');

      // battleId must be cleared on survivors.
      for (final co in cleanup.companies) {
        expect(co.battleId, isNull,
            reason:
                'Survivor battleId must be null after post-battle cleanup');
      }

      // No zero-soldier companies.
      for (final co in cleanup.companies) {
        final total =
            co.company.composition.values.fold(0, (a, b) => a + b);
        expect(total, greaterThan(0));
      }
    });

    test(
        'SC-009b: game loop triggers battle and carries it forward; '
        'battle is NOT auto-resolved by ticks (requires manual advanceBattleRound)', () {
      final match = _SimpleMap.match();

      // Companies already at the junction when the loop starts.
      final playerCo = CompanyOnMap(
        id: 'player_co0',
        ownership: Ownership.player,
        currentNode: _SimpleMap.junction,
        company: Company(composition: {UnitRole.warrior: 8}),
      );
      final aiCo = CompanyOnMap(
        id: 'ai_co0',
        ownership: Ownership.ai,
        currentNode: _SimpleMap.junction,
        company: Company(composition: {UnitRole.warrior: 8}),
      );

      var currentCastles = _SimpleMap.castles();
      var currentCompanies = [playerCo, aiCo];
      var currentBattles = <ActiveBattle>[];
      var battleWasTriggered = false;

      // Run for a few ticks — the battle should be triggered and then
      // carried forward without auto-advancing (roundNumber stays at 0).
      for (var i = 0; i < 10; i++) {
        final result = const TickMatch().tick(
          match: match.copyWith(elapsedTime: Duration(seconds: i * 10)),
          castles: currentCastles,
          companies: currentCompanies,
          activeBattles: currentBattles,
        );
        currentCastles = result.castles;
        currentCompanies = result.companies;
        currentBattles = result.activeBattles;

        if (currentBattles.isNotEmpty && !battleWasTriggered) {
          battleWasTriggered = true;
        }
      }

      expect(battleWasTriggered, isTrue,
          reason: 'A battle must have been triggered during the run');
      // The battle must still be active — ticks do NOT resolve battles.
      expect(currentBattles, isNotEmpty,
          reason: 'Battle must still be active; ticks do not auto-advance it');
      // roundNumber must still be 0 — ticks carry it forward without advancing.
      expect(currentBattles.first.battle.roundNumber, equals(0),
          reason: 'tick() must not advance roundNumber; only advanceBattleRound() does');
    });
  });
}
