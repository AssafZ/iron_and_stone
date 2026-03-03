import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _playerCastle = CastleNode(
  id: 'player_castle',
  x: 0.0,
  y: 0.0,
  ownership: Ownership.player,
);

const _aiCastle = CastleNode(
  id: 'ai_castle',
  x: 300.0,
  y: 0.0,
  ownership: Ownership.ai,
);

const _junction = RoadJunctionNode(id: 'junction_mid', x: 150.0, y: 0.0);

GameMap _makeMap() {
  return GameMap(
    nodes: [_playerCastle, _junction, _aiCastle],
    edges: [
      RoadEdge(from: _playerCastle, to: _junction, length: 150.0),
      RoadEdge(from: _junction, to: _playerCastle, length: 150.0),
      RoadEdge(from: _junction, to: _aiCastle, length: 150.0),
      RoadEdge(from: _aiCastle, to: _junction, length: 150.0),
    ],
  );
}

CompanyOnMap _makeCompany({
  required String id,
  required Ownership ownership,
  required MapNode currentNode,
  MapNode? destination,
  double progress = 0.0,
}) {
  return CompanyOnMap(
    company: Company(composition: {UnitRole.warrior: 5}),
    id: id,
    ownership: ownership,
    currentNode: currentNode,
    destination: destination,
    progress: progress,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late GameMap map;
  late CheckCollisions useCase;

  setUp(() {
    map = _makeMap();
    useCase = const CheckCollisions();
  });

  group('CheckCollisions', () {
    group('empty map', () {
      test('empty companies list returns no triggers', () {
        final triggers = useCase.check(map: map, companies: []);
        expect(triggers, isEmpty);
      });
    });

    group('friendly Companies on same node', () {
      test('two friendly Companies on the same node return no trigger', () {
        final a = _makeCompany(
          id: 'p1',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final b = _makeCompany(
          id: 'p2',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final triggers = useCase.check(map: map, companies: [a, b]);
        expect(triggers, isEmpty);
      });
    });

    group('FR-014: opposing Companies on same road segment', () {
      test('player and AI Company on same node returns a road-collision trigger', () {
        final player = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _junction,
        );
        final ai = _makeCompany(
          id: 'ai_co',
          ownership: Ownership.ai,
          currentNode: _junction,
        );
        final triggers = useCase.check(map: map, companies: [player, ai]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.roadCollision),
          isTrue,
        );
      });
    });

    group('FR-015: Company arriving at enemy castle node', () {
      test('player Company at AI castle returns a castle-assault trigger', () {
        final playerAtAiCastle = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _aiCastle,
        );
        final triggers = useCase.check(map: map, companies: [playerAtAiCastle]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
          isTrue,
        );
      });

      test('AI Company at player castle returns a castle-assault trigger', () {
        final aiAtPlayerCastle = _makeCompany(
          id: 'ai_co',
          ownership: Ownership.ai,
          currentNode: _playerCastle,
        );
        final triggers = useCase.check(map: map, companies: [aiAtPlayerCastle]);
        expect(triggers, isNotEmpty);
        expect(
          triggers.any((t) => t.kind == BattleTriggerKind.castleAssault),
          isTrue,
        );
      });

      test('friendly Company at own castle returns no trigger', () {
        final playerAtOwnCastle = _makeCompany(
          id: 'player_co',
          ownership: Ownership.player,
          currentNode: _playerCastle,
        );
        final triggers = useCase.check(
          map: map,
          companies: [playerAtOwnCastle],
        );
        expect(triggers, isEmpty);
      });
    });
  });
}
