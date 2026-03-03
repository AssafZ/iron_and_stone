// T029 — Failing unit tests for DeployCompany use case
// Red-Green-Refactor: these tests must FAIL before implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/deploy_company.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _playerCastleNode = CastleNode(
  id: 'player_castle',
  x: 0.0,
  y: 0.0,
  ownership: Ownership.player,
);

const _junction1 = RoadJunctionNode(id: 'j1', x: 100.0, y: 0.0);

const _aiCastleNode = CastleNode(
  id: 'ai_castle',
  x: 300.0,
  y: 0.0,
  ownership: Ownership.ai,
);

GameMap _makeMap() => GameMap(
      nodes: [_playerCastleNode, _junction1, _aiCastleNode],
      edges: [
        RoadEdge(from: _playerCastleNode, to: _junction1, length: 100.0),
        RoadEdge(from: _junction1, to: _playerCastleNode, length: 100.0),
        RoadEdge(from: _junction1, to: _aiCastleNode, length: 200.0),
        RoadEdge(from: _aiCastleNode, to: _junction1, length: 200.0),
      ],
    );

Castle _makeCastle({Map<UnitRole, int>? garrison}) => Castle(
      id: _playerCastleNode.id,
      ownership: Ownership.player,
      garrison: garrison ??
          {
            UnitRole.warrior: 20,
            UnitRole.archer: 10,
          },
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DeployCompany', () {
    late GameMap map;
    late DeployCompany useCase;

    setUp(() {
      map = _makeMap();
      useCase = const DeployCompany();
    });

    group('happy path', () {
      test('removes deployed units from castle garrison', () {
        final castle = _makeCastle(garrison: {UnitRole.warrior: 20});
        final result = useCase.deploy(
          castle: castle,
          composition: {UnitRole.warrior: 10},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        expect(result.updatedCastle.garrison[UnitRole.warrior], equals(10));
      });

      test('places Company adjacent to castle on map (next road node)', () {
        final castle = _makeCastle(garrison: {UnitRole.warrior: 20});
        final result = useCase.deploy(
          castle: castle,
          composition: {UnitRole.warrior: 10},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        // The Company should start AT the castle node
        expect(result.company.currentNode.id, equals(_playerCastleNode.id));
        expect(result.company.ownership, equals(Ownership.player));
      });

      test('deploying exactly 50 soldiers is accepted', () {
        final castle = _makeCastle(garrison: {
          UnitRole.warrior: 25,
          UnitRole.archer: 25,
        });
        final result = useCase.deploy(
          castle: castle,
          composition: {UnitRole.warrior: 25, UnitRole.archer: 25},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        expect(result.company.company.totalSoldiers.value, equals(50));
      });

      test('deploying 0 of a role is ignored and does not throw', () {
        final castle = _makeCastle(garrison: {UnitRole.warrior: 20, UnitRole.archer: 10});
        final result = useCase.deploy(
          castle: castle,
          // 0 knights — garrison doesn't even have knights, but that's fine
          composition: {UnitRole.warrior: 5, UnitRole.knight: 0},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        expect(result.company.company.totalSoldiers.value, equals(5));
      });
    });

    group('rejection cases', () {
      test('throws when total composition exceeds 50 soldiers (FR-008)', () {
        final castle = _makeCastle(
          garrison: {UnitRole.warrior: 100, UnitRole.archer: 100},
        );
        expect(
          () => useCase.deploy(
            castle: castle,
            composition: {UnitRole.warrior: 30, UnitRole.archer: 25},
            castleNode: _playerCastleNode,
            map: map,
            companyId: 'co1',
          ),
          throwsA(isA<DeployCompanyException>()),
        );
      });

      test('throws when garrison lacks sufficient units for a role', () {
        final castle = _makeCastle(garrison: {UnitRole.warrior: 3});
        expect(
          () => useCase.deploy(
            castle: castle,
            composition: {UnitRole.warrior: 5},
            castleNode: _playerCastleNode,
            map: map,
            companyId: 'co1',
          ),
          throwsA(isA<DeployCompanyException>()),
        );
      });

      test('throws when deploying 0 total soldiers', () {
        final castle = _makeCastle();
        expect(
          () => useCase.deploy(
            castle: castle,
            composition: {UnitRole.warrior: 0},
            castleNode: _playerCastleNode,
            map: map,
            companyId: 'co1',
          ),
          throwsA(isA<DeployCompanyException>()),
        );
      });
    });

    group('garrison flat-pool decrement', () {
      test('garrison decremented by exact role amounts', () {
        final castle = _makeCastle(
          garrison: {
            UnitRole.warrior: 20,
            UnitRole.archer: 10,
          },
        );
        final result = useCase.deploy(
          castle: castle,
          composition: {UnitRole.warrior: 7, UnitRole.archer: 3},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        expect(result.updatedCastle.garrison[UnitRole.warrior], equals(13));
        expect(result.updatedCastle.garrison[UnitRole.archer], equals(7));
      });

      test('roles not in composition are unaffected in garrison', () {
        final castle = _makeCastle(
          garrison: {
            UnitRole.warrior: 10,
            UnitRole.knight: 5,
          },
        );
        final result = useCase.deploy(
          castle: castle,
          composition: {UnitRole.warrior: 5},
          castleNode: _playerCastleNode,
          map: map,
          companyId: 'co1',
        );
        // Knights untouched
        expect(result.updatedCastle.garrison[UnitRole.knight], equals(5));
      });
    });
  });
}
