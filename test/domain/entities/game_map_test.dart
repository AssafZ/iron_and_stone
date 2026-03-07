import 'package:flutter_test/flutter_test.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/game_map_fixture.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

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
        // Use only junction nodes so castle-on-road validation doesn't trigger.
        final disconnectedMap = GameMap(
          nodes: [nodeB, isolated],
          edges: [], // no edges — disconnected
        );
        final path = disconnectedMap.pathBetween(nodeB, isolated);
        expect(path, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // T010 — Castle-on-road validation (US3)
    // -----------------------------------------------------------------------

    group('castle-on-road validation (T010)', () {
      test('(a) map with all castles connected builds without error', () {
        // nodeA and nodeD are both connected; building gameMap in setUp must not throw.
        expect(
          () => GameMap(
            nodes: [nodeA, nodeB, nodeC, nodeD],
            edges: [edgeAB, edgeBA, edgeBC, edgeCB, edgeCD, edgeDC],
          ),
          returnsNormally,
        );
      });

      test('(b) map with castle having no edges throws ArgumentError naming the castle', () {
        const orphanCastle = CastleNode(
          id: 'orphan',
          x: 999.0,
          y: 999.0,
          ownership: Ownership.neutral,
        );
        expect(
          () => GameMap(
            nodes: [nodeA, nodeB, orphanCastle],
            edges: [edgeAB, edgeBA], // orphanCastle has no edges
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message.toString(),
              'message contains castle id',
              contains('orphan'),
            ),
          ),
        );
      });

      test('(c) GameMapFixture.build() succeeds (regression guard)', () {
        expect(GameMapFixture.build, returnsNormally);
      });
    });

    // -----------------------------------------------------------------------
    // T010 — roadDistance (US3, US6)
    // -----------------------------------------------------------------------

    group('roadDistance (T010)', () {
      test('(d) same-segment case: progress 0.2→0.7 on length-100 edge = 50.0', () {
        // A—100—B: from = RoadPosition at A→B progress 0.2, to = A→B progress 0.7
        final from = RoadPosition(
          currentNodeId: 'A',
          progress: 0.2,
          nextNodeId: 'B',
        );
        final to = RoadPosition(
          currentNodeId: 'A',
          progress: 0.7,
          nextNodeId: 'B',
        );
        expect(gameMap.roadDistance(from, to), closeTo(50.0, 0.001));
      });

      test('(e) cross-segment: A→B at 0.5 to C→D at 0.3 uses shortest BFS path', () {
        // from = midpoint of A—B (progress 0.5, so 50 units into length-100 edge)
        //        → still 50 units to reach B
        // then B—C (100 units)
        // then C—D at progress 0.3 = 30 units into length-100 edge
        // total = 50 + 100 + 30 = 180
        final from = RoadPosition(
          currentNodeId: 'A',
          progress: 0.5,
          nextNodeId: 'B',
        );
        final to = RoadPosition(
          currentNodeId: 'C',
          progress: 0.3,
          nextNodeId: 'D',
        );
        expect(gameMap.roadDistance(from, to), closeTo(180.0, 0.001));
      });
    });
  });
}