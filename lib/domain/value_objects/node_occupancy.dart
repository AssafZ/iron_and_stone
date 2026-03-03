import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

/// Returns `true` if [company] is considered stationary:
/// - destination is null, OR
/// - destination.id == currentNode.id
bool isStationary(CompanyOnMap company) =>
    company.destination == null ||
    company.destination!.id == company.currentNode.id;

/// Derives a [NodeOccupancy] for [nodeId] from [allCompanies] using the
/// cold-start / post-tick deterministic approach: stationary companies at the
/// node are sorted lexicographically by id.
///
/// This is used on app restart or after a game tick when transient arrival
/// order is unavailable.
NodeOccupancy deriveOccupancy(
  String nodeId,
  List<CompanyOnMap> allCompanies,
) {
  final stationary = allCompanies
      .where((c) => c.currentNode.id == nodeId && isStationary(c))
      .map((c) => c.id)
      .toList()
    ..sort();
  return NodeOccupancy(nodeId: nodeId, orderedIds: stationary);
}

/// Tracks which companies are currently **stationary** at a given map node,
/// and in which order they arrived.
///
/// The ordered list drives the slot-index computation used by the UI to
/// position markers without overlap.
///
/// This is a **pure-Dart, immutable value object** — no Flutter imports.
final class NodeOccupancy {
  /// ID of the [MapNode] this occupancy record belongs to.
  final String nodeId;

  /// Company IDs in arrival order (index 0 = first arrival = centre slot).
  ///
  /// Contains no duplicates. Contains only IDs of stationary companies.
  final List<String> orderedIds;

/// Creates a [NodeOccupancy].
  ///
  /// A defensive copy of [orderedIds] is taken — external mutations do not
  /// affect this value object.
  NodeOccupancy({
    required this.nodeId,
    required List<String> orderedIds,
  }) : orderedIds = List.unmodifiable(orderedIds);

  /// Returns a new [NodeOccupancy] with [id] appended at the end.
  ///
  /// No-op (returns unchanged copy) if [id] is already present.
  NodeOccupancy withArrival(String id) {
    if (orderedIds.contains(id)) return this;
    return NodeOccupancy(nodeId: nodeId, orderedIds: [...orderedIds, id]);
  }

  /// Returns a new [NodeOccupancy] with [id] removed.
  ///
  /// Remaining IDs are compacted (no gaps) — relative arrival order is
  /// preserved.
  ///
  /// No-op (returns unchanged copy) if [id] is not present.
  NodeOccupancy withDeparture(String id) {
    if (!orderedIds.contains(id)) return this;
    return NodeOccupancy(
      nodeId: nodeId,
      orderedIds: orderedIds.where((e) => e != id).toList(),
    );
  }

  /// Returns the 0-based slot index for [id], or `null` if not present.
  int? slotIndex(String id) {
    final idx = orderedIds.indexOf(id);
    return idx == -1 ? null : idx;
  }

  /// Returns `true` if [id] is currently in [orderedIds].
  bool contains(String id) => orderedIds.contains(id);

  @override
  String toString() => 'NodeOccupancy(nodeId=$nodeId, orderedIds=$orderedIds)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeOccupancy &&
          nodeId == other.nodeId &&
          _listEquals(orderedIds, other.orderedIds);

  @override
  int get hashCode => Object.hash(nodeId, Object.hashAll(orderedIds));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
