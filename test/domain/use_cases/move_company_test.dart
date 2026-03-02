// T030 — Failing unit tests for MoveCompany use case
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/use_cases/move_company.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _playerCastle = CastleNode(
  id: 'pc',
  x: 0.0,
  y: 0.0,
  ownership: Ownership.player,
);

const _junction1 = RoadJunctionNode(id: 'j1', x: 100.0, y: 0.0);
const _junction2 = RoadJunctionNode(id: 'j2', x: 200.0, y: 0.0);

const _aiCastle = CastleNode(
  id: 'ac',
  x: 300.0,
  y: 0.0,
  ownership: Ownership.ai,
);

GameMap _makeMap() => GameMap(
      nodes: [_playerCastle, _junction1, _junction2, _aiCastle],
      edges: [
        RoadEdge(from: _playerCastle, to: _junction1, length: 100.0),
        RoadEdge(from: _junction1, to: _playerCastle, length: 100.0),
        RoadEdge(from: _junction1, to: _junction2, length: 100.0),
        RoadEdge(from: _junction2, to: _junction1, length: 100.0),
        RoadEdge(from: _junction2, to: _aiCastle, length: 100.0),
        RoadEdge(from: _aiCastle, to: _junction2, length: 100.0),
      ],
    );

CompanyOnMap _makeCompany({
  MapNode? currentNode,
  MapNode? destination,
  double progress = 0.0,
  int warriors = 5,
}) {
  return CompanyOnMap(
    company: Company(composition: {UnitRole.warrior: warriors}),
    id: 'co1',
    ownership: Ownership.player,
    currentNode: currentNode ?? _playerCastle,
    destination: destination,
    progress: progress,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MoveCompany', () {
    late GameMap map;
    late MoveCompany useCase;

    setUp(() {
      map = _makeMap();
      useCase = const MoveCompany();
    });

    group('assign destination', () {
      test('sets destination and returns updated CompanyOnMap', () {
        final company = _makeCompany(currentNode: _playerCastle);
        final result = useCase.setDestination(
          company: company,
          destination: _aiCastle,
          map: map,
        );
        expect(result.destination?.id, equals(_aiCastle.id));
      });

      test('throws MoveCompanyException for off-road destination (no path)', () {
        const isolatedNode = RoadJunctionNode(id: 'iso', x: 999.0, y: 999.0);
        final company = _makeCompany(currentNode: _playerCastle);
        // 'iso' has no edges so pathBetween returns empty
        final mapWithIso = GameMap(
          nodes: [..._makeMap().nodes, isolatedNode],
          edges: _makeMap().edges,
        );
        expect(
          () => useCase.setDestination(
            company: company,
            destination: isolatedNode,
            map: mapWithIso,
          ),
          throwsA(isA<MoveCompanyException>()),
        );
      });

      test('setting destination to current node is accepted (no-op)', () {
        final company = _makeCompany(currentNode: _junction1);
        final result = useCase.setDestination(
          company: company,
          destination: _junction1,
          map: map,
        );
        expect(result.destination?.id, equals(_junction1.id));
      });
    });

    group('position advance per tick', () {
      test('progress increases toward next node on first tick', () {
        // Warrior speed = 6, edge = 100, tick = 10 s → progress += 0.6
        final company = _makeCompany(
          currentNode: _playerCastle,
          destination: _aiCastle,
          progress: 0.0,
        );
        final result = useCase.advance(
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_playerCastle.id));
        expect(result.progress, closeTo(0.6, 0.001));
      });

      test('company steps to next node when progress reaches 1.0', () {
        // At 0.6 progress, adding another 0.6 (= 1.2) → crosses to j1
        final company = _makeCompany(
          currentNode: _playerCastle,
          destination: _aiCastle,
          progress: 0.6,
        );
        final result = useCase.advance(
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction1.id));
      });

      test('stationary company (null destination) is unchanged', () {
        final company = _makeCompany(
          currentNode: _junction1,
          destination: null,
          progress: 0.0,
        );
        final result = useCase.advance(
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction1.id));
        expect(result.progress, equals(0.0));
      });

      test('company already at destination stays put', () {
        final company = _makeCompany(
          currentNode: _junction2,
          destination: _junction2,
          progress: 0.0,
        );
        final result = useCase.advance(
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction2.id));
        expect(result.progress, equals(0.0));
      });

      test('company arrives at destination after sufficient ticks', () {
        // playerCastle → j1 (100 units, warrior speed 6).
        // Each tick advances 60 units. After 2 ticks (120 units) it should be past j1.
        CompanyOnMap co = _makeCompany(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.0,
        );
        // First tick: progress = 0.6 (still at playerCastle)
        co = useCase.advance(company: co, map: map, tickSeconds: 10.0);
        // Second tick: progress = 1.2 → arrives at j1
        co = useCase.advance(company: co, map: map, tickSeconds: 10.0);
        expect(co.currentNode.id, equals(_junction1.id));
      });
    });

    // -------------------------------------------------------------------------
    // T058c — Reinforcement arrival signal (FR-021)
    // -------------------------------------------------------------------------
    group('reinforcement wave routing', () {
      test(
          'advance returns ReinforcementArrival when Company arrives at node with active battle',
          () {
        // Company is one tick away from junction1 (which has an active battle)
        // progress = 0.6, warrior speed 6, edge 100 → one more tick = arrives at j1
        final co = _makeCompany(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.6,
        );

        final activeBattleNodeIds = {_junction1.id}; // active battle at j1

        final result = useCase.advanceWithBattleCheck(
          company: co,
          map: map,
          tickSeconds: 10.0,
          activeBattleNodeIds: activeBattleNodeIds,
        );

        expect(result, isA<ReinforcementArrival>());
        final arrival = result as ReinforcementArrival;
        expect(arrival.company.id, equals(co.id));
        expect(arrival.battleNodeId, equals(_junction1.id));
      });

      test(
          'advance returns normal CompanyOnMap when destination node has no active battle',
          () {
        final co = _makeCompany(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.6,
        );

        final result = useCase.advanceWithBattleCheck(
          company: co,
          map: map,
          tickSeconds: 10.0,
          activeBattleNodeIds: const {}, // no active battles
        );

        expect(result, isA<CompanyOnMap>());
      });

      test(
          'advance with no battle check (empty activeBattleNodeIds) behaves like advance()',
          () {
        final co = _makeCompany(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.0,
        );

        final resultWithCheck = useCase.advanceWithBattleCheck(
          company: co,
          map: map,
          tickSeconds: 10.0,
          activeBattleNodeIds: const {},
        );

        final resultNormal = useCase.advance(
          company: co,
          map: map,
          tickSeconds: 10.0,
        );

        expect(resultWithCheck, isA<CompanyOnMap>());
        final coWithCheck = resultWithCheck as CompanyOnMap;
        expect(coWithCheck.currentNode.id, equals(resultNormal.currentNode.id));
        expect(coWithCheck.progress, closeTo(resultNormal.progress, 0.001));
      });
    });
  });
}
