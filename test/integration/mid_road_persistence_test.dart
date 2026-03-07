// T040-b [Phase 9]: Mid-road persistence — full game-state round-trip.
//
// Confirms SC-005: a Company with a non-null midRoadDestination is saved and
// restored faithfully, and continues marching from the correct fractional
// position after being loaded from the database.

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
// Map / helpers
// ---------------------------------------------------------------------------

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

MatchState _makeState(List<CompanyOnMap> companies) {
  final map = _makeMap();
  return MatchState(
    match: Match(map: map, humanPlayer: Ownership.player, phase: MatchPhase.playing),
    castles: [
      Castle(id: 'pc', ownership: Ownership.player, garrison: {}),
      Castle(id: 'aic', ownership: Ownership.ai, garrison: {}),
    ],
    companies: companies,
    activeBattles: const [],
  );
}

// ---------------------------------------------------------------------------
// T040-b Tests
// ---------------------------------------------------------------------------

void main() {
  group('T040-b [Phase 9]: mid-road persistence round-trip', () {
    late AppDatabase db;
    late MatchDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = MatchDao(db);
    });

    tearDown(() async => db.close());

    // -----------------------------------------------------------------------
    // (1) Full round-trip: save → load → confirm position fields identical
    // -----------------------------------------------------------------------
    test(
      '(1) company with midRoadDestination at progress=0.4 survives full '
      'save/load round-trip with all position fields intact',
      () async {
        final midRoad = RoadPosition(
          currentNodeId: 'j1',
          nextNodeId: 'j2',
          progress: 0.8,
        );
        final co = CompanyOnMap(
          id: 'marcher',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.4,
          midRoadDestination: midRoad,
          company: Company(composition: {UnitRole.warrior: 10}),
        );

        await dao.saveMatch(matchId: 'm1', state: _makeState([co]));
        final loaded = (await dao.loadMatch('m1'))!;

        expect(loaded.companies, hasLength(1));
        final r = loaded.companies.first;

        expect(r.currentNode.id, 'j1');
        expect(r.progress, closeTo(0.4, 0.0001));
        expect(r.midRoadDestination, isNotNull);
        expect(r.midRoadDestination!.currentNodeId, 'j1');
        expect(r.midRoadDestination!.nextNodeId, 'j2');
        expect(r.midRoadDestination!.progress, closeTo(0.8, 0.0001));
      },
    );

    // -----------------------------------------------------------------------
    // (2) After loading, one tick advances from the fractional position
    // -----------------------------------------------------------------------
    test(
      '(2) loaded company at progress=0.4 with mid-road stop at 0.8 '
      'advances to between 0.4 and 0.8 after one tick (continues marching)',
      () async {
        // Warriors: 3 units/s × 10 s/tick = 30 units, edge=100 → Δprogress=0.30
        // Starting at 0.4, stop at 0.8 → after one tick: 0.4+0.30=0.70, still ≤0.8
        final midRoad = RoadPosition(
          currentNodeId: 'j1',
          nextNodeId: 'j2',
          progress: 0.8,
        );
        final co = CompanyOnMap(
          id: 'marcher2',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.4,
          midRoadDestination: midRoad,
          company: Company(composition: {UnitRole.warrior: 10}),
        );

        await dao.saveMatch(matchId: 'm2', state: _makeState([co]));
        final loaded = (await dao.loadMatch('m2'))!;

        final afterTick = const TickMatch().tick(
          match: loaded.match,
          castles: loaded.castles,
          companies: loaded.companies,
          activeBattles: const [],
        );

        expect(afterTick.companies, hasLength(1));
        final advanced = afterTick.companies.first;

        expect(
          advanced.progress,
          greaterThan(0.4),
          reason: 'Company must advance past 0.4 after one tick',
        );
        expect(
          advanced.progress,
          lessThanOrEqualTo(0.8),
          reason: 'Company must not overshoot the mid-road stop at 0.8',
        );
      },
    );

    // -----------------------------------------------------------------------
    // (3) Company reaches mid-road stop exactly — confirms stopping logic
    //     is preserved after persistence
    // -----------------------------------------------------------------------
    test(
      '(3) loaded company at progress=0.4 with mid-road stop at 0.7 '
      'stops at exactly 0.7 after one tick and clears midRoadDestination',
      () async {
        // Warriors: Δprogress = 0.30/tick; 0.4 + 0.30 = 0.70 exactly → reached.
        final midRoad = RoadPosition(
          currentNodeId: 'j1',
          nextNodeId: 'j2',
          progress: 0.7,
        );
        final co = CompanyOnMap(
          id: 'stopper',
          ownership: Ownership.player,
          currentNode: _j1,
          progress: 0.4,
          midRoadDestination: midRoad,
          company: Company(composition: {UnitRole.warrior: 10}),
        );

        await dao.saveMatch(matchId: 'm3', state: _makeState([co]));
        final loaded = (await dao.loadMatch('m3'))!;

        final afterTick = const TickMatch().tick(
          match: loaded.match,
          castles: loaded.castles,
          companies: loaded.companies,
          activeBattles: const [],
        );

        final stopped = afterTick.companies.first;
        expect(
          stopped.progress,
          closeTo(0.7, 0.001),
          reason: 'Company must stop at mid-road target 0.7',
        );
        expect(
          stopped.midRoadDestination,
          isNull,
          reason: 'midRoadDestination must be cleared after arriving',
        );
      },
    );
  });
}
