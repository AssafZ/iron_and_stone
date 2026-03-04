// T024: MatchDao.saveMatch / loadMatch — persist and restore activeBattles.
//
// These tests confirm:
//   1. activeBattles are written to BattlesTable during saveMatch.
//   2. loadMatch restores activeBattles with correct fields.
//   3. battleId on companies is persisted and restored (empty string → null).
//   4. Battle round state (roundNumber, HP maps, kind, outcome) survives round-trip.
//   5. loadMatch returns activeBattles: [] when no battles were saved.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/data/drift/match_dao.dart';
import 'package:iron_and_stone/domain/entities/active_battle.dart';
import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

MatchState _baseState({
  List<CompanyOnMap> companies = const [],
  List<ActiveBattle> activeBattles = const [],
}) {
  final map = GameMapFixture.build();
  final castles = map.nodes.whereType<CastleNode>().map((n) {
    return Castle(id: n.id, ownership: n.ownership, garrison: const {});
  }).toList();
  return MatchState(
    match: Match(
      map: map,
      humanPlayer: Ownership.player,
      phase: MatchPhase.playing,
    ),
    castles: castles,
    companies: companies,
    activeBattles: activeBattles,
  );
}

// ---------------------------------------------------------------------------
// T024 Tests
// ---------------------------------------------------------------------------

void main() {
  group('T024: MatchDao — activeBattles persistence', () {
    late AppDatabase db;
    late MatchDao dao;

    setUp(() {
      db = _makeDb();
      dao = MatchDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    // -----------------------------------------------------------------------
    // T024-1: loadMatch returns empty activeBattles when none were saved
    // -----------------------------------------------------------------------
    test(
      'T024-1: loadMatch returns activeBattles: [] when no battles saved',
      () async {
        final state = _baseState();
        await dao.saveMatch(matchId: 'match_1', state: state);

        final restored = await dao.loadMatch('match_1');
        expect(restored, isNotNull);
        expect(
          restored!.activeBattles,
          isEmpty,
          reason: 'No battles → activeBattles must be empty list after load',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-2: one ActiveBattle survives a save/load round-trip
    // -----------------------------------------------------------------------
    test(
      'T024-2: one ActiveBattle is restored after saveMatch/loadMatch',
      () async {
        final map = GameMapFixture.build();
        final junctionNode = map.nodes.whereType<RoadJunctionNode>().first;

        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 5})],
          defenders: [Company(composition: {UnitRole.warrior: 5})],
          kind: BattleKind.roadCollision,
        );
        final activeBattle = ActiveBattle(
          nodeId: junctionNode.id,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );

        final state = _baseState(activeBattles: [activeBattle]);
        await dao.saveMatch(matchId: 'match_2', state: state);

        final restored = await dao.loadMatch('match_2');
        expect(restored, isNotNull);
        expect(
          restored!.activeBattles,
          hasLength(1),
          reason: 'One saved battle must be restored as one ActiveBattle',
        );

        final restoredBattle = restored.activeBattles.first;
        expect(restoredBattle.id, equals(activeBattle.id));
        expect(restoredBattle.nodeId, equals(junctionNode.id));
        expect(
          restoredBattle.attackerCompanyIds,
          equals(['p1']),
        );
        expect(
          restoredBattle.defenderCompanyIds,
          equals(['ai1']),
        );
        expect(
          restoredBattle.attackerOwnership,
          equals(Ownership.player),
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-3: Battle round state (roundNumber, kind) is preserved
    // -----------------------------------------------------------------------
    test(
      'T024-3: Battle roundNumber and kind survive round-trip',
      () async {
        final map = GameMapFixture.build();
        final junctionNode = map.nodes.whereType<RoadJunctionNode>().first;

        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 10})],
          defenders: [Company(composition: {UnitRole.archer: 8})],
          kind: BattleKind.castleAssault,
          roundNumber: 3,
        );
        final activeBattle = ActiveBattle(
          nodeId: junctionNode.id,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.ai,
          battle: battle,
        );

        final state = _baseState(activeBattles: [activeBattle]);
        await dao.saveMatch(matchId: 'match_3', state: state);

        final restored = await dao.loadMatch('match_3');
        final restoredBattle = restored!.activeBattles.first.battle;

        expect(
          restoredBattle.roundNumber,
          equals(3),
          reason: 'roundNumber must survive persistence round-trip',
        );
        expect(
          restoredBattle.kind,
          equals(BattleKind.castleAssault),
          reason: 'BattleKind must survive persistence round-trip',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-4: HP maps survive round-trip (non-null attackerHp / defenderHp)
    // -----------------------------------------------------------------------
    test(
      'T024-4: Battle HP maps survive round-trip',
      () async {
        final map = GameMapFixture.build();
        final junctionNode = map.nodes.whereType<RoadJunctionNode>().first;

        const attackerHp = {'warrior_0': 8, 'warrior_1': 10};
        const defenderHp = {'archer_0': 5};

        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 2})],
          defenders: [Company(composition: {UnitRole.archer: 1})],
          roundNumber: 2,
          attackerHp: attackerHp,
          defenderHp: defenderHp,
        );
        final activeBattle = ActiveBattle(
          nodeId: junctionNode.id,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );

        final state = _baseState(activeBattles: [activeBattle]);
        await dao.saveMatch(matchId: 'match_4', state: state);

        final restored = await dao.loadMatch('match_4');
        final restoredBattle = restored!.activeBattles.first.battle;

        expect(
          restoredBattle.attackerHp,
          equals(attackerHp),
          reason: 'attackerHp must survive persistence round-trip',
        );
        expect(
          restoredBattle.defenderHp,
          equals(defenderHp),
          reason: 'defenderHp must survive persistence round-trip',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-5: company battleId is persisted and restored (empty → null)
    // -----------------------------------------------------------------------
    test(
      'T024-5: company battleId is restored after round-trip '
      '(empty string in DB → null on load)',
      () async {
        final map = GameMapFixture.build();
        final junctionNode = map.nodes.whereType<RoadJunctionNode>().first;

        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 5})],
          defenders: [Company(composition: {UnitRole.warrior: 5})],
        );
        final activeBattle = ActiveBattle(
          nodeId: junctionNode.id,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );

        // Company in the battle (has battleId set).
        final playerCo = CompanyOnMap(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: junctionNode,
          company: Company(composition: {UnitRole.warrior: 5}),
          battleId: activeBattle.id,
        );
        // Company NOT in battle (no battleId).
        final aiCo = CompanyOnMap(
          id: 'ai1',
          ownership: Ownership.ai,
          currentNode: junctionNode,
          company: Company(composition: {UnitRole.warrior: 5}),
          battleId: activeBattle.id,
        );
        // Bystander — not in battle.
        final bystander = CompanyOnMap(
          id: 'by1',
          ownership: Ownership.player,
          currentNode: junctionNode,
          company: Company(composition: {UnitRole.archer: 2}),
          // battleId defaults to null
        );

        final state = _baseState(
          companies: [playerCo, aiCo, bystander],
          activeBattles: [activeBattle],
        );
        await dao.saveMatch(matchId: 'match_5', state: state);

        final restored = await dao.loadMatch('match_5');
        expect(restored, isNotNull);

        final restoredP1 =
            restored!.companies.firstWhere((c) => c.id == 'p1');
        final restoredAi1 =
            restored.companies.firstWhere((c) => c.id == 'ai1');
        final restoredBy1 =
            restored.companies.firstWhere((c) => c.id == 'by1');

        expect(
          restoredP1.battleId,
          equals(activeBattle.id),
          reason: 'battleId must be restored for a company in battle',
        );
        expect(
          restoredAi1.battleId,
          equals(activeBattle.id),
        );
        expect(
          restoredBy1.battleId,
          isNull,
          reason: 'empty string in DB must be loaded as null battleId',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-6: multiple ActiveBattles are all persisted and restored
    // -----------------------------------------------------------------------
    test(
      'T024-6: multiple ActiveBattles are all restored',
      () async {
        final map = GameMapFixture.build();
        final nodes = map.nodes.whereType<RoadJunctionNode>().toList();

        // Need at least two junction nodes; if only one, skip this test
        // gracefully by using the same node ID with a suffix.
        final nodeId1 = nodes.isNotEmpty ? nodes[0].id : 'j1';
        final nodeId2 = nodes.length > 1 ? nodes[1].id : '${nodeId1}_b';

        final battle1 = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 5})],
          defenders: [Company(composition: {UnitRole.warrior: 5})],
        );
        final battle2 = Battle(
          attackers: [Company(composition: {UnitRole.knight: 3})],
          defenders: [Company(composition: {UnitRole.archer: 4})],
          kind: BattleKind.castleAssault,
        );

        final ab1 = ActiveBattle(
          nodeId: nodeId1,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle1,
        );
        final ab2 = ActiveBattle(
          nodeId: nodeId2,
          attackerCompanyIds: ['p2'],
          defenderCompanyIds: ['ai2'],
          attackerOwnership: Ownership.ai,
          battle: battle2,
        );

        final state = _baseState(activeBattles: [ab1, ab2]);
        await dao.saveMatch(matchId: 'match_6', state: state);

        final restored = await dao.loadMatch('match_6');
        expect(restored, isNotNull);
        expect(
          restored!.activeBattles,
          hasLength(2),
          reason: 'Both ActiveBattles must be restored',
        );
        expect(
          restored.activeBattles.map((ab) => ab.id),
          containsAll([ab1.id, ab2.id]),
        );
      },
    );

    // -----------------------------------------------------------------------
    // T024-7: Battle roundLog survives round-trip
    // -----------------------------------------------------------------------
    test(
      'T024-7: Battle roundLog survives round-trip',
      () async {
        final map = GameMapFixture.build();
        final junctionNode = map.nodes.whereType<RoadJunctionNode>().first;

        final battle = Battle(
          attackers: [Company(composition: {UnitRole.warrior: 5})],
          defenders: [Company(composition: {UnitRole.warrior: 5})],
          roundNumber: 2,
          roundLog: ['Round 1: 2 damage to attackers', 'Round 2: 3 damage to defenders'],
        );
        final activeBattle = ActiveBattle(
          nodeId: junctionNode.id,
          attackerCompanyIds: ['p1'],
          defenderCompanyIds: ['ai1'],
          attackerOwnership: Ownership.player,
          battle: battle,
        );

        final state = _baseState(activeBattles: [activeBattle]);
        await dao.saveMatch(matchId: 'match_7', state: state);

        final restored = await dao.loadMatch('match_7');
        final restoredBattle = restored!.activeBattles.first.battle;

        expect(
          restoredBattle.roundLog,
          equals(battle.roundLog),
          reason: 'roundLog must survive persistence round-trip',
        );
      },
    );
  });
}
