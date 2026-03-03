import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  group('MapNode', () {
    group('CastleNode', () {
      test('can be constructed with id and position', () {
        const node = CastleNode(
          id: 'castle_1',
          x: 100.0,
          y: 200.0,
          ownership: Ownership.player,
        );
        expect(node.id, equals('castle_1'));
        expect(node.x, equals(100.0));
        expect(node.y, equals(200.0));
        expect(node.ownership, equals(Ownership.player));
      });

      test('is a MapNode', () {
        const node = CastleNode(
          id: 'c1',
          x: 0.0,
          y: 0.0,
          ownership: Ownership.neutral,
        );
        expect(node, isA<MapNode>());
      });
    });

    group('RoadJunctionNode', () {
      test('can be constructed with id and position', () {
        const node = RoadJunctionNode(
          id: 'junction_1',
          x: 50.0,
          y: 75.0,
        );
        expect(node.id, equals('junction_1'));
        expect(node.x, equals(50.0));
        expect(node.y, equals(75.0));
      });

      test('is a MapNode', () {
        const node = RoadJunctionNode(id: 'j1', x: 0.0, y: 0.0);
        expect(node, isA<MapNode>());
      });
    });

    group('sealed class variants', () {
      test('CastleNode and RoadJunctionNode are distinct types', () {
        const castleNode = CastleNode(
          id: 'c1',
          x: 0.0,
          y: 0.0,
          ownership: Ownership.neutral,
        );
        const junctionNode = RoadJunctionNode(id: 'j1', x: 0.0, y: 0.0);
        expect(castleNode, isNot(isA<RoadJunctionNode>()));
        expect(junctionNode, isNot(isA<CastleNode>()));
      });

      test('equality by id', () {
        const node1 = CastleNode(
          id: 'c1',
          x: 0.0,
          y: 0.0,
          ownership: Ownership.player,
        );
        const node2 = CastleNode(
          id: 'c1',
          x: 0.0,
          y: 0.0,
          ownership: Ownership.player,
        );
        expect(node1, equals(node2));
      });
    });
  });
}
