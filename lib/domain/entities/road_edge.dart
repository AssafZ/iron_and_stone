import 'package:iron_and_stone/domain/entities/map_node.dart';

/// A directed road edge connecting two distinct [MapNode]s.
///
/// To model an undirected road, add two [RoadEdge]s: A→B and B→A.
/// Self-loops (from == to) are rejected with [ArgumentError].
final class RoadEdge {
  final MapNode from;
  final MapNode to;

  /// Length of this road segment in map distance units.
  final double length;

  /// Stable string identifier derived as `"${from.id}__${to.id}"`.
  ///
  /// Computed in the constructor — not a required parameter.
  /// Used for persistence (drift column) and segment-keying in collision detection.
  final String id;

  RoadEdge({required this.from, required this.to, required this.length})
      : id = '${from.id}__${to.id}' {
    if (from.id == to.id) {
      throw ArgumentError(
        'A RoadEdge cannot be a self-loop: from.id == to.id == "${from.id}".',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadEdge &&
          from == other.from &&
          to == other.to &&
          length == other.length;

  @override
  int get hashCode => Object.hash(from, to, length);

  @override
  String toString() => 'RoadEdge(${from.id} → ${to.id}, length=$length)';
}
