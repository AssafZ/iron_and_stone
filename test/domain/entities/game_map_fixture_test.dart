import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  late GameMap map;

  setUp(() {
    map = GameMapFixture.build();
  });

  group('GameMapFixture', () {
    group('node count', () {
      test('produces a GameMap with 4–8 nodes', () {
        expect(map.nodes.length, greaterThanOrEqualTo(4));
        expect(map.nodes.length, lessThanOrEqualTo(8));
      });
    });

    group('castle nodes', () {
      test('at least 2 nodes are CastleNodes', () {
        final castleNodes = map.nodes.whereType<CastleNode>().toList();
        expect(castleNodes.length, greaterThanOrEqualTo(2));
      });

      test('player castle has Ownership.player', () {
        final castleNodes = map.nodes.whereType<CastleNode>().toList();
        final playerCastles = castleNodes
            .where((n) => n.ownership == Ownership.player)
            .toList();
        expect(playerCastles, isNotEmpty);
      });

      test('AI castle has Ownership.ai', () {
        final castleNodes = map.nodes.whereType<CastleNode>().toList();
        final aiCastles = castleNodes
            .where((n) => n.ownership == Ownership.ai)
            .toList();
        expect(aiCastles, isNotEmpty);
      });

      test('player castle and AI castle have distinct Ownership values', () {
        final castleNodes = map.nodes.whereType<CastleNode>().toList();
        final playerCastle = castleNodes.firstWhere(
          (n) => n.ownership == Ownership.player,
        );
        final aiCastle = castleNodes.firstWhere(
          (n) => n.ownership == Ownership.ai,
        );
        expect(playerCastle.ownership, isNot(equals(aiCastle.ownership)));
      });
    });

    group('reachability', () {
      test('all nodes reachable from any castle node via road edges', () {
        final startNode = map.nodes.whereType<CastleNode>().first;
        for (final node in map.nodes) {
          final path = map.pathBetween(startNode, node);
          expect(
            path,
            isNotEmpty,
            reason: 'Node ${node.id} not reachable from ${startNode.id}',
          );
        }
      });
    });

    group('fixture properties', () {
      test('map has 6 nodes (2 castles + 4 road junctions)', () {
        expect(map.nodes.length, equals(6));
      });

      test('map has road edges with positive lengths', () {
        for (final edge in map.edges) {
          expect(
            edge.length,
            greaterThan(0),
            reason: 'Edge ${edge.from.id}→${edge.to.id} has non-positive length',
          );
        }
      });
    });
  });
}
