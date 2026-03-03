import 'dart:collection';

import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';

/// The game map graph: a collection of [MapNode]s connected by [RoadEdge]s.
///
/// Path finding uses BFS to find the shortest node-hop path between two nodes
/// via road edges only.
final class GameMap {
  final List<MapNode> nodes;
  final List<RoadEdge> edges;

  GameMap({required List<MapNode> nodes, required List<RoadEdge> edges})
      : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges);

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

  @override
  String toString() => 'GameMap(nodes=${nodes.length}, edges=${edges.length})';
}
