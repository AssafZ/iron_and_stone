import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  const nodeA = CastleNode(id: 'a', x: 0.0, y: 0.0, ownership: Ownership.player);
  const nodeB = RoadJunctionNode(id: 'b', x: 100.0, y: 0.0);
  const nodeC = CastleNode(id: 'c', x: 200.0, y: 0.0, ownership: Ownership.ai);

  group('RoadEdge', () {
    group('construction', () {
      test('can connect two distinct nodes', () {
        final edge = RoadEdge(from: nodeA, to: nodeB, length: 100.0);
        expect(edge.from, equals(nodeA));
        expect(edge.to, equals(nodeB));
        expect(edge.length, equals(100.0));
      });

      test('throws for self-loop (from == to)', () {
        expect(
          () => RoadEdge(from: nodeA, to: nodeA, length: 0.0),
          throwsArgumentError,
        );
      });
    });

    group('directed edges', () {
      test('edge from A→B is different from B→A', () {
        final edgeAB = RoadEdge(from: nodeA, to: nodeB, length: 100.0);
        final edgeBA = RoadEdge(from: nodeB, to: nodeA, length: 100.0);
        expect(edgeAB, isNot(equals(edgeBA)));
      });
    });

    group('equality by node pair', () {
      test('two edges with same from/to/length are equal', () {
        final edge1 = RoadEdge(from: nodeA, to: nodeB, length: 50.0);
        final edge2 = RoadEdge(from: nodeA, to: nodeB, length: 50.0);
        expect(edge1, equals(edge2));
      });

      test('edges with different lengths but same nodes are not equal', () {
        final edge1 = RoadEdge(from: nodeA, to: nodeB, length: 50.0);
        final edge2 = RoadEdge(from: nodeA, to: nodeB, length: 75.0);
        expect(edge1, isNot(equals(edge2)));
      });

      test('edges connecting different node pairs are not equal', () {
        final edgeAB = RoadEdge(from: nodeA, to: nodeB, length: 100.0);
        final edgeBC = RoadEdge(from: nodeB, to: nodeC, length: 100.0);
        expect(edgeAB, isNot(equals(edgeBC)));
      });
    });

    group('connects exactly two nodes', () {
      test('from and to are always present and distinct', () {
        final edge = RoadEdge(from: nodeA, to: nodeC, length: 200.0);
        expect(edge.from, isNotNull);
        expect(edge.to, isNotNull);
        expect(edge.from.id, isNot(equals(edge.to.id)));
      });
    });
  });
}
