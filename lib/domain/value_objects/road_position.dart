/// A fractional position on a road segment between two named [MapNode]s.
///
/// Represents a point between [currentNodeId] and [nextNodeId] as a
/// half-open progress value `[0.0, 1.0)`:
/// - `progress = 0.0` means the company is at [currentNodeId] but on the way
///   to [nextNodeId] (segment identity is explicit).
/// - `progress = 0.5` means the company is at the midpoint.
/// - `progress >= 1.0` is rejected — arrival at [nextNodeId] is expressed by
///   updating [currentNodeId] to the next node and resetting progress to 0.0.
///
/// Pure Dart — zero Flutter dependencies.
final class RoadPosition {
  /// ID of the node the company most recently departed from (segment start).
  final String currentNodeId;

  /// Fractional progress toward [nextNodeId] in the range `[0.0, 1.0)`.
  final double progress;

  /// ID of the node the company is heading toward (segment end).
  final String nextNodeId;

  RoadPosition({
    required this.currentNodeId,
    required this.progress,
    required this.nextNodeId,
  }) {
    if (progress < 0.0 || progress >= 1.0) {
      throw ArgumentError(
        'RoadPosition.progress must be in [0.0, 1.0); got $progress.',
      );
    }
    if (currentNodeId == nextNodeId) {
      throw ArgumentError(
        'RoadPosition.currentNodeId must differ from nextNodeId; '
        'both are "$currentNodeId".',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadPosition &&
          currentNodeId == other.currentNodeId &&
          progress == other.progress &&
          nextNodeId == other.nextNodeId;

  @override
  int get hashCode => Object.hash(currentNodeId, progress, nextNodeId);

  @override
  String toString() =>
      'RoadPosition($currentNodeId → $nextNodeId @ ${progress.toStringAsFixed(4)})';
}
