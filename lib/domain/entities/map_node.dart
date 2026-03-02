import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// A node on the game map — either a castle or a road junction.
sealed class MapNode {
  /// Unique identifier for this node.
  final String id;

  /// X-coordinate on the map canvas.
  final double x;

  /// Y-coordinate on the map canvas.
  final double y;

  const MapNode({required this.id, required this.x, required this.y});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(runtimeType, id, x, y);
}

/// A castle node — owns a garrison and has an [Ownership] value.
final class CastleNode extends MapNode {
  final Ownership ownership;

  const CastleNode({
    required super.id,
    required super.x,
    required super.y,
    required this.ownership,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastleNode && super == other && ownership == other.ownership;

  @override
  int get hashCode => Object.hash(super.hashCode, ownership);

  @override
  String toString() => 'CastleNode(id=$id, owner=$ownership, x=$x, y=$y)';
}

/// A road junction — a waypoint on a road, no garrison.
final class RoadJunctionNode extends MapNode {
  const RoadJunctionNode({
    required super.id,
    required super.x,
    required super.y,
  });

  @override
  String toString() => 'RoadJunctionNode(id=$id, x=$x, y=$y)';
}
