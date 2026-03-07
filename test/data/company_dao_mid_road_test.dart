// T040 [P] [Phase 9]: MatchDao — persist and restore midRoadDestination on CompanyOnMap.
//
// These tests confirm:
//   1. A company with a non-null midRoadDestination survives a saveMatch/loadMatch
//      round-trip: (currentNodeId, progress, midRoadDestination.currentNodeId,
//      midRoadDestination.progress, midRoadDestination.nextNodeId) are identical.
//   2. A company with midRoadDestination == null loads back with null (no spurious
//      column data leaking in).
//   3. After loading, advancing one tick continues movement from the correct
//      fractional position (the company does NOT restart from progress = 0).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/data/drift/app_database.dart';
import 'package:iron_and_stone/data/drift/match_dao.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/match.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/tick_match.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';
import 'package:iron_and_stone/state/match_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

const _pc = CastleNode(id: 'pc', x: 0, y: 0, ownership: Ownership.player);
const _j1 = RoadJunctionNode(id: 'j1', x: 100, y: 0);
const _j2 = RoadJunctionNode(id: 'j2', x: 200, y: 0);
const _aic = CastleNode(id: 'aic', x: 300, y: 0, ownership: Ownership.ai);

GameMap _makeMap() => GameMap(nodes: [_pc, _j1, _j2, _aic], edges: [
      RoadEdge(from: _pc, to: _j1, length: 100.0),
      RoadEdge(from: _j1, to: _pc, length: 100.0),
      RoadEdge(from: _j1, to: _j2, length: 100.0),
      RoadEdge(from: _j2, to: _j1, length: 100.0),
      RoadEdge(from: _j2, to: _aic, length: 100.0),
      RoadEdge(from: _aic, to: _j2, length: 100.0),
    ]);

MatchState _stateWith({required List<CompanyOnMap> companies}) {
  final map = _makeMap();
  final castles = [
    Castle(id: 'pc', ownership: Ownership.player, garrison: {}),
    Castle(id: 'aic', ownership: Ownership.ai, garrison: {}),
  ];
  return MatchState(
    match: Match(map: map, humanPlayer: Ownership.player, phase: MatchPhase.playing),
    castles: castles,
    companies: companies,
    activeBattles: const [],
  );
}

// ---------------------------------------------------------------------------
// T040 Tests
// ---------------------------------------------------------------------------

void main() {
  group('T040 [Phase 9]: MatchDao — midRoadDestination persistence', () {
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
    // T040-1: midRoadDestination survives saveMatch / loadMatch round-trip
    // -----------------------------------------------------------------------
    test(
      'T040-1: company with midRoadDestination round-trips through '
      'saveMatch/loadMatch intact',
      () async {
        final midRoad = RoadPosition(
          currentNodeId: 'j1',
          nextNodeId: 'j2',
          progress: 0.4,
        );
        final co = CompanyOnMap(
          id: 'co_1',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.4,
          midRoadDestination: midRoad,
          company: Company(composition: {UnitRole.warrior: 5}),
        );

        await dao.saveMatch(matchId: 'match_t040', state: _stateWith(companies: [co]));

        final loaded = await dao.loadMatch('match_t040');
        expect(loaded, isNotNull);
        expect(loaded!.companies, hasLength(1));

        final restored = loaded.companies.first;
        expect(
          restored.currentNode.id,
          equals('j1'),
          reason: 'currentNode must be preserved',
        );
        expect(
          restored.progress,
          closeTo(0.4, 0.0001),
          reason: 'progress must be preserved',
        );
        expect(
          restored.midRoadDestination,
          isNotNull,
          reason: 'midRoadDestination must be non-null after round-trip',
        );
        expect(
          restored.midRoadDestination!.currentNodeId,
          equals('j1'),
          reason: 'midRoadDestination.currentNodeId must be preserved',
        );
        expect(
          restored.midRoadDestination!.nextNodeId,
          equals('j2'),
          reason: 'midRoadDestination.nextNodeId must be preserved',
        );
        expect(
          restored.midRoadDestination!.progress,
          closeTo(0.4, 0.0001),
          reason: 'midRoadDestination.progress must be preserved',
        );
      },
    );

    // -----------------------------------------------------------------------
    // T040-2: company without midRoadDestination loads back with null
    // -----------------------------------------------------------------------
    test(
      'T040-2: company with midRoadDestination == null loads back with null',
      () async {
        final co = CompanyOnMap(
          id: 'co_2',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.0,
          company: Company(composition: {UnitRole.warrior: 3}),
          // midRoadDestination left null
        );

        await dao.saveMatch(matchId: 'match_t040b', state: _stateWith(companies: [co]));

        final loaded = await dao.loadMatch('match_t040b');
        expect(loaded, isNotNull);
        expect(loaded!.companies.first.midRoadDestination, isNull,
            reason: 'midRoadDestination must remain null after round-trip');
      },
    );

    // -----------------------------------------------------------------------
    // T040-3: loaded company with midRoadDestination continues marching
    // -----------------------------------------------------------------------
    test(
      'T040-3: loaded company with midRoadDestination at progress=0.4 '
      'advances beyond 0.4 after one tick (does not reset to 0)',
      () async {
        final midRoad = RoadPosition(
          currentNodeId: 'j1',
          nextNodeId: 'j2',
          progress: 0.9, // stop near end of segment
        );
        final co = CompanyOnMap(
          id: 'co_3',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.4,
          midRoadDestination: midRoad,
          company: Company(composition: {UnitRole.warrior: 5}),
        );

        await dao.saveMatch(matchId: 'match_t040c', state: _stateWith(companies: [co]));
        final loaded = (await dao.loadMatch('match_t040c'))!;

        // Advance one tick — the company should continue from 0.4, not restart.
        final tickResult = const TickMatch().tick(
          match: loaded.match,
          castles: loaded.castles,
          companies: loaded.companies,
          activeBattles: const [],
        );

        final advanced = tickResult.companies.first;
        expect(
          advanced.progress,
          greaterThan(0.4),
          reason:
              'After one tick from restored state at progress=0.4, company '
              'must have advanced beyond 0.4 (not reset to 0)',
        );
      },
    );
  });
}
