import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

void main() {
  // Map layout: A —100— B —100— C —100— D
  // A and D are castle nodes; B and C are junctions.
  const nodeA = CastleNode(id: 'A', x: 0.0, y: 0.0, ownership: Ownership.player);
  const nodeB = RoadJunctionNode(id: 'B', x: 100.0, y: 0.0);
  const nodeC = RoadJunctionNode(id: 'C', x: 200.0, y: 0.0);
  const nodeD = CastleNode(id: 'D', x: 300.0, y: 0.0, ownership: Ownership.ai);

  // Bidirectional edges (stored as two directed edges each)
  final edgeAB = RoadEdge(from: nodeA, to: nodeB, length: 100.0);
  final edgeBA = RoadEdge(from: nodeB, to: nodeA, length: 100.0);
  final edgeBC = RoadEdge(from: nodeB, to: nodeC, length: 100.0);
  final edgeCB = RoadEdge(from: nodeC, to: nodeB, length: 100.0);
  final edgeCD = RoadEdge(from: nodeC, to: nodeD, length: 100.0);
  final edgeDC = RoadEdge(from: nodeD, to: nodeC, length: 100.0);

  late GameMap gameMap;

  setUp(() {
    gameMap = GameMap(
      nodes: [nodeA, nodeB, nodeC, nodeD],
      edges: [edgeAB, edgeBA, edgeBC, edgeCB, edgeCD, edgeDC],
    );
  });

  group('GameMap', () {
    group('node and edge collection', () {
      test('contains all nodes', () {
        expect(gameMap.nodes.length, equals(4));
        expect(gameMap.nodes, containsAll([nodeA, nodeB, nodeC, nodeD]));
      });

      test('contains all edges', () {
        expect(gameMap.edges.length, equals(6));
      });
    });

    group('pathBetween', () {
      test('returns a valid road-only sequence from A to D', () {
        final path = gameMap.pathBetween(nodeA, nodeD);
        expect(path, isNotEmpty);
        expect(path.first, equals(nodeA));
        expect(path.last, equals(nodeD));
      });

      test('path contains only nodes connected by road edges', () {
        final path = gameMap.pathBetween(nodeA, nodeD);
        // Every consecutive pair in the path must have a road edge
        for (int i = 0; i < path.length - 1; i++) {
          final from = path[i];
          final to = path[i + 1];
          final hasEdge = gameMap.edges.any(
            (e) => e.from.id == from.id && e.to.id == to.id,
          );
          expect(hasEdge, isTrue, reason: 'No edge from ${from.id} to ${to.id}');
        }
      });

      test('path from A to A returns single-node list', () {
        final path = gameMap.pathBetween(nodeA, nodeA);
        expect(path, equals([nodeA]));
      });

      test('returns empty list for disconnected nodes', () {
        const isolated = RoadJunctionNode(id: 'X', x: 999.0, y: 999.0);
        final disconnectedMap = GameMap(
          nodes: [nodeA, isolated],
          edges: [], // no edges — disconnected
        );
        final path = disconnectedMap.pathBetween(nodeA, isolated);
        expect(path, isEmpty);
      });
    });
  });
}
