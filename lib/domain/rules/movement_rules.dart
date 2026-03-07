import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/road_edge.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

/// Distance threshold (in map units) within which two friendly companies
/// trigger the proximity-merge prompt.
const double kProximityMergeThreshold = 30.0;

/// Result returned by [MovementRules.advancePosition].
final class MovementPositionResult {
  final MapNode currentNode;
  final double progress;

  /// `true` when the company has just arrived at its [midRoadDest] position.
  ///
  /// When this is `true`, [progress] is clamped to `midRoadDest.progress` and
  /// the caller is responsible for clearing the company's `midRoadDestination`.
  final bool reachedMidRoad;

  const MovementPositionResult({
    required this.currentNode,
    required this.progress,
    this.reachedMidRoad = false,
  });
}

/// Pure Dart movement rules — no Flutter dependencies.
///
/// Provides:
/// - [derivedSpeed]: minimum role speed for a [Company].
/// - [isValidPath]: road-only reachability check.
/// - [advancePosition]: position/progress update for one tick.
abstract final class MovementRules {
  /// Returns the movement speed for [company]: the minimum speed of all roles
  /// with at least 1 soldier present. Returns 0 for an empty company.
  static int derivedSpeed(Company company) {
    return company.movementSpeed;
  }

  /// Returns `true` if a road path exists between [from] and [to] on [map].
  ///
  /// A node is reachable from itself (returns `true`).
  /// Returns `false` if no path exists.
  static bool isValidPath(GameMap map, MapNode from, MapNode to) {
    final path = map.pathBetween(from, to);
    // pathBetween returns empty list for disconnected nodes.
    // For same-node it returns [from], which is non-empty.
    return path.isNotEmpty;
  }

  /// Advances a company's position by one tick.
  ///
  /// - [currentNode]: the node the company most recently passed through.
  /// - [destination]: the target node; `null` means stationary.
  /// - [progress]: fractional progress toward the next node [0.0, 1.0).
  /// - [company]: used to derive [derivedSpeed].
  /// - [map]: used to look up the next node and edge length.
  /// - [tickSeconds]: duration of one tick in seconds.
  /// - [midRoadDest]: optional mid-road stop point. When provided and the
  ///   company is on the matching segment, progress is clamped to
  ///   [midRoadDest.progress] upon arrival and [reachedMidRoad] is set.
  ///
  /// Returns a [MovementPositionResult] with the updated [MapNode] and
  /// fractional [progress].
  static MovementPositionResult advancePosition({
    required MapNode currentNode,
    required MapNode? destination,
    required double progress,
    required Company company,
    required GameMap map,
    required double tickSeconds,
    RoadPosition? midRoadDest,
  }) {
    if (destination == null || destination.id == currentNode.id) {
      return MovementPositionResult(
        currentNode: currentNode,
        progress: progress,
      );
    }

    final path = map.pathBetween(currentNode, destination);
    if (path.length < 2) {
      // No valid path — remain stationary.
      return MovementPositionResult(currentNode: currentNode, progress: progress);
    }

    final nextNode = path[1];
    final edge = _findEdge(map, currentNode, nextNode);
    if (edge == null) {
      return MovementPositionResult(currentNode: currentNode, progress: progress);
    }

    final speed = derivedSpeed(company).toDouble();
    final newProgress = progress + (speed * tickSeconds) / edge.length;

    // Mid-road stop: only applies when the company is on the exact segment
    // described by midRoadDest (same currentNode and nextNode pair).
    if (midRoadDest != null &&
        midRoadDest.currentNodeId == currentNode.id &&
        midRoadDest.nextNodeId == nextNode.id &&
        newProgress >= midRoadDest.progress) {
      return MovementPositionResult(
        currentNode: currentNode,
        progress: midRoadDest.progress,
        reachedMidRoad: true,
      );
    }

    if (newProgress >= 1.0) {
      // Arrived at the next node — reset progress (do not carry over excess
      // for simplicity; the next tick will continue from nextNode).
      return MovementPositionResult(currentNode: nextNode, progress: 0.0);
    }

    return MovementPositionResult(currentNode: currentNode, progress: newProgress);
  }

  static RoadEdge? _findEdge(GameMap map, MapNode from, MapNode to) {
    for (final edge in map.edges) {
      if (edge.from.id == from.id && edge.to.id == to.id) return edge;
    }
    return null;
  }
}
