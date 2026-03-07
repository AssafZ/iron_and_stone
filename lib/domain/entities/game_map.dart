import 'dart:collection';

import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

/// The game map graph: a collection of [MapNode]s connected by [RoadEdge]s.
///
/// Path finding uses BFS to find the shortest node-hop path between two nodes
/// via road edges only.
///
/// **Castle-on-road invariant**: every [CastleNode] in [nodes] must have at
/// least one [RoadEdge] in [edges] whose `from.id` or `to.id` matches the
/// castle's id. The constructor throws [ArgumentError] if this is violated.
final class GameMap {
  final List<MapNode> nodes;
  final List<RoadEdge> edges;

  GameMap({required List<MapNode> nodes, required List<RoadEdge> edges})
      : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges) {
    // Castle-on-road invariant: every CastleNode must have ≥ 1 edge.
    final edgeNodeIds = <String>{};
    for (final e in edges) {
      edgeNodeIds.add(e.from.id);
      edgeNodeIds.add(e.to.id);
    }
    for (final node in nodes) {
      if (node is CastleNode && !edgeNodeIds.contains(node.id)) {
        throw ArgumentError(
          'Castle "${node.id}" has no road edges. '
          'All castles must be connected to at least one road edge.',
        );
      }
    }
  }

  /// Returns the road-only path from [a] to [b] as an ordered list of nodes
  /// (inclusive of both endpoints).
  ///
  /// - Returns `[a]` if `a == b`.
  /// - Returns an empty list if no road path exists between [a] and [b].
  List<MapNode> pathBetween(MapNode a, MapNode b) {
    if (a.id == b.id) return [a];

    // Build adjacency map by node id.
    final adjacency = <String, List<MapNode>>{};
    for (final edge in edges) {
      adjacency.putIfAbsent(edge.from.id, () => []).add(edge.to);
    }

    // BFS
    final visited = <String>{};
    final queue = Queue<List<MapNode>>();
    queue.add([a]);
    visited.add(a.id);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final current = path.last;

      for (final neighbour in (adjacency[current.id] ?? <MapNode>[])) {
        if (visited.contains(neighbour.id)) continue;
        final newPath = <MapNode>[...path, neighbour];
        if (neighbour.id == b.id) return newPath;
        visited.add(neighbour.id);
        queue.add(newPath);
      }
    }

    return []; // disconnected
  }

  /// Computes the road distance (in map distance units) between two
  /// [RoadPosition]s.
  ///
  /// **Same-segment case** (`from.currentNodeId == to.currentNodeId &&
  /// from.nextNodeId == to.nextNodeId`):
  ///   `|to.progress - from.progress| * edge.length`
  ///
  /// **Cross-segment case**: distance from [from] to `from.nextNodeId`,
  /// then BFS shortest-path distance between the two next-nodes via named
  /// nodes, then distance from `to.currentNodeId` into [to].
  ///
  /// Returns `0.0` if both positions refer to the same point.
  double roadDistance(RoadPosition from, RoadPosition to) {
    // Same segment — simple fractional difference.
    if (from.currentNodeId == to.currentNodeId &&
        from.nextNodeId == to.nextNodeId) {
      final edge = _findEdgeById(from.currentNodeId, from.nextNodeId);
      if (edge == null) return 0.0;
      return (to.progress - from.progress).abs() * edge.length;
    }

    // Cross-segment calculation:
    // 1. Distance remaining on from's segment to reach from.nextNodeId.
    final fromEdge = _findEdgeById(from.currentNodeId, from.nextNodeId);
    final distFromToNextNode =
        fromEdge != null ? (1.0 - from.progress) * fromEdge.length : 0.0;

    // 2. Distance from to.currentNodeId to start of to's segment
    //    (i.e., how far into to.currentNodeId→to.nextNodeId we travel).
    final toEdge = _findEdgeById(to.currentNodeId, to.nextNodeId);
    final distIntoToSegment =
        toEdge != null ? to.progress * toEdge.length : 0.0;

    // 3. BFS distance between from.nextNodeId and to.currentNodeId through
    //    the named-node graph.
    final fromNextNode = _nodeById(from.nextNodeId);
    final toCurrentNode = _nodeById(to.currentNodeId);

    double midDistance = 0.0;
    if (fromNextNode != null && toCurrentNode != null) {
      if (fromNextNode.id == toCurrentNode.id) {
        midDistance = 0.0;
      } else {
        midDistance = _bfsDistance(fromNextNode, toCurrentNode);
      }
    }

    return distFromToNextNode + midDistance + distIntoToSegment;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  RoadEdge? _findEdgeById(String fromId, String toId) {
    for (final edge in edges) {
      if (edge.from.id == fromId && edge.to.id == toId) return edge;
    }
    return null;
  }

  MapNode? _nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// BFS over named nodes, summing edge lengths to find shortest road distance
  /// between [a] and [b].
  double _bfsDistance(MapNode a, MapNode b) {
    if (a.id == b.id) return 0.0;

    // Build adjacency with distances.
    final adjacency = <String, List<(MapNode, double)>>{};
    for (final edge in edges) {
      adjacency.putIfAbsent(edge.from.id, () => []).add((edge.to, edge.length));
    }

    // Dijkstra over weighted edges.
    final dist = <String, double>{a.id: 0.0};
    final queue = Queue<MapNode>();
    queue.add(a);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final currentDist = dist[current.id]!;

      for (final entry in (adjacency[current.id] ?? [])) {
        final neighbour = entry.$1;
        final edgeLen = entry.$2;
        final newDist = currentDist + edgeLen;
        if (!dist.containsKey(neighbour.id) || newDist < dist[neighbour.id]!) {
          dist[neighbour.id] = newDist;
          queue.add(neighbour);
        }
      }
    }

    return dist[b.id] ?? double.infinity;
  }

  @override
  String toString() => 'GameMap(nodes=${nodes.length}, edges=${edges.length})';
}
