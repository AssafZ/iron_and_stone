// T028 — Failing unit tests for MovementRules
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

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

// Isolated node with no road connections.
const _isolatedNode = RoadJunctionNode(id: 'iso', x: 999.0, y: 999.0);

GameMap _makeMap() => GameMap(
      nodes: [_playerCastle, _junction1, _junction2, _aiCastle, _isolatedNode],
      edges: [
        RoadEdge(from: _playerCastle, to: _junction1, length: 100.0),
        RoadEdge(from: _junction1, to: _playerCastle, length: 100.0),
        RoadEdge(from: _junction1, to: _junction2, length: 100.0),
        RoadEdge(from: _junction2, to: _junction1, length: 100.0),
        RoadEdge(from: _junction2, to: _aiCastle, length: 100.0),
        RoadEdge(from: _aiCastle, to: _junction2, length: 100.0),
      ],
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MovementRules', () {
    group('derivedSpeed', () {
      test('single-role company returns that role speed', () {
        final company = Company(composition: {UnitRole.warrior: 10});
        expect(MovementRules.derivedSpeed(company), equals(UnitRole.warrior.speed));
      });

      test('Warriors + Catapults returns Catapult minimum speed', () {
        final company = Company(composition: {
          UnitRole.warrior: 5,
          UnitRole.catapult: 2,
        });
        // Warrior speed = 6, Catapult speed = 3 → minimum is 3
        expect(MovementRules.derivedSpeed(company), equals(3));
      });

      test('Knight (speed 10) + Catapult (speed 3) returns 3', () {
        final company = Company(composition: {
          UnitRole.knight: 3,
          UnitRole.catapult: 1,
        });
        expect(MovementRules.derivedSpeed(company), equals(3));
      });

      test('all five roles returns Catapult speed (3) as minimum', () {
        final company = Company(composition: {
          UnitRole.peasant: 2,   // speed 5
          UnitRole.warrior: 2,   // speed 6
          UnitRole.knight: 2,    // speed 10
          UnitRole.archer: 2,    // speed 6
          UnitRole.catapult: 1,  // speed 3
        });
        expect(MovementRules.derivedSpeed(company), equals(3));
      });

      test('empty company returns 0', () {
        final company = Company(composition: {});
        expect(MovementRules.derivedSpeed(company), equals(0));
      });

      test('zero-count role is not considered for minimum speed', () {
        // Catapult has 0 count — should not drag down speed.
        final company = Company(composition: {
          UnitRole.warrior: 5,
          UnitRole.catapult: 0,
        });
        expect(MovementRules.derivedSpeed(company), equals(UnitRole.warrior.speed));
      });
    });

    group('isValidPath', () {
      late GameMap map;

      setUp(() {
        map = _makeMap();
      });

      test('path exists between connected nodes returns true', () {
        expect(
          MovementRules.isValidPath(map, _playerCastle, _aiCastle),
          isTrue,
        );
      });

      test('same node returns true (no movement needed)', () {
        expect(
          MovementRules.isValidPath(map, _junction1, _junction1),
          isTrue,
        );
      });

      test('path to isolated node returns false (no road connection)', () {
        expect(
          MovementRules.isValidPath(map, _playerCastle, _isolatedNode),
          isFalse,
        );
      });

      test('path between adjacent nodes returns true', () {
        expect(
          MovementRules.isValidPath(map, _playerCastle, _junction1),
          isTrue,
        );
      });
    });

    group('advancePosition', () {
      late GameMap map;

      setUp(() {
        map = _makeMap();
      });

      test('company advances progress toward next node per tick', () {
        final company = Company(composition: {UnitRole.warrior: 5}); // speed 6
        // Edge length = 100. Speed = 6 units/s, tick = 10 s.
        // Expected progress = (6 * 10) / 100 = 0.6 after one tick.
        final result = MovementRules.advancePosition(
          currentNode: _playerCastle,
          destination: _aiCastle,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_playerCastle.id));
        expect(result.progress, closeTo(0.6, 0.001));
      });

      test('company arrives at next node when progress reaches 1.0', () {
        final company = Company(composition: {UnitRole.warrior: 5}); // speed 6
        // Already at progress 0.6; adding 0.6 more = 1.2 → arrives at next node.
        final result = MovementRules.advancePosition(
          currentNode: _playerCastle,
          destination: _aiCastle,
          progress: 0.6,
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction1.id));
        expect(result.progress, closeTo(0.0, 0.1)); // reset on arrival
      });

      test('stationary company (no destination) returns unchanged position', () {
        final company = Company(composition: {UnitRole.warrior: 5});
        final result = MovementRules.advancePosition(
          currentNode: _junction1,
          destination: null,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction1.id));
        expect(result.progress, equals(0.0));
      });

      test('company already at destination returns unchanged position', () {
        final company = Company(composition: {UnitRole.warrior: 5});
        final result = MovementRules.advancePosition(
          currentNode: _junction1,
          destination: _junction1,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 10.0,
        );
        expect(result.currentNode.id, equals(_junction1.id));
        expect(result.progress, equals(0.0));
      });
    });

    // -------------------------------------------------------------------------
    // T013 — advancePosition mid-road stop (US1)
    // -------------------------------------------------------------------------
    group('advancePosition mid-road stop', () {
      late GameMap map;

      setUp(() {
        map = _makeMap();
      });

      test(
          '(a) company reaches midRoadDest.progress within a tick → '
          'reachedMidRoad = true and progress clamped to dest',
          () {
        // Warrior speed 6, edge 100, tick 10 s → advances 0.6 per tick.
        // Start at progress 0.0 with midRoadDest at progress 0.4.
        // After one tick we would reach 0.6 which is > 0.4, so must clamp to 0.4.
        final company = Company(composition: {UnitRole.warrior: 5});
        final midRoadDest = RoadPosition(
          currentNodeId: _playerCastle.id,
          progress: 0.4,
          nextNodeId: _junction1.id,
        );
        final result = MovementRules.advancePosition(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 10.0,
          midRoadDest: midRoadDest,
        );
        expect(result.reachedMidRoad, isTrue);
        expect(result.progress, closeTo(0.4, 0.0001));
        expect(result.currentNode.id, equals(_playerCastle.id));
      });

      test(
          '(b) company does not yet reach midRoadDest.progress → '
          'reachedMidRoad = false and progress advances normally',
          () {
        // Warrior speed 6, edge 100, tick 1 s → advances 0.06 per tick.
        // MidRoadDest at 0.9 — company starts at 0.0, won't reach 0.9 in 1 s.
        final company = Company(composition: {UnitRole.warrior: 5});
        final midRoadDest = RoadPosition(
          currentNodeId: _playerCastle.id,
          progress: 0.9,
          nextNodeId: _junction1.id,
        );
        final result = MovementRules.advancePosition(
          currentNode: _playerCastle,
          destination: _junction1,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 1.0,
          midRoadDest: midRoadDest,
        );
        expect(result.reachedMidRoad, isFalse);
        expect(result.progress, closeTo(0.06, 0.0001));
        expect(result.currentNode.id, equals(_playerCastle.id));
      });

      test(
          '(c) company on wrong segment (different currentNode) advances '
          'toward midRoadDest.currentNodeId ignoring mid-road stop',
          () {
        // Company is on j1→j2 but midRoadDest targets pc→j1 segment.
        // The company must keep marching toward the dest.currentNodeId (pc)
        // and must NOT stop mid-road on this irrelevant segment.
        final company = Company(composition: {UnitRole.warrior: 5});
        final midRoadDest = RoadPosition(
          currentNodeId: _playerCastle.id,
          progress: 0.5,
          nextNodeId: _junction1.id,
        );
        // Company is at j1 heading toward j2, mid-road dest is on different segment.
        // We set destination = j2 so the path is j1 → j2.
        final result = MovementRules.advancePosition(
          currentNode: _junction1,
          destination: _junction2,
          progress: 0.0,
          company: company,
          map: map,
          tickSeconds: 1.0,
          midRoadDest: midRoadDest,
        );
        expect(result.reachedMidRoad, isFalse);
        // Company is on j1→j2, not pc→j1, so it should advance normally.
        expect(result.progress, greaterThan(0.0));
      });
    });
  });
}
