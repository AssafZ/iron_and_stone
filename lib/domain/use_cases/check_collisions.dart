import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// The kind of battle trigger detected.
enum BattleTriggerKind {
  /// Two opposing Companies are on the same road segment/node (FR-014).
  roadCollision,

  /// A Company has arrived at an enemy castle node (FR-015).
  castleAssault,
}

/// Represents a battle that should be triggered as a result of a tick.
final class BattleTrigger {
  final BattleTriggerKind kind;

  /// The node at which the battle occurs.
  final MapNode location;

  /// IDs of the Companies involved.
  final List<String> companyIds;

  const BattleTrigger({
    required this.kind,
    required this.location,
    required this.companyIds,
  });

  @override
  String toString() =>
      'BattleTrigger(kind=$kind, location=${location.id}, companies=$companyIds)';
}

/// A [Company] positioned on the map with movement state.
final class CompanyOnMap {
  final Company company;

  /// Unique ID for this map entity.
  final String id;

  /// Ownership of this Company.
  final Ownership ownership;

  /// The node the Company is currently at or most recently passed through.
  final MapNode currentNode;

  /// The destination node this Company is marching toward (null = stationary).
  final MapNode? destination;

  /// Fractional progress toward the next node along the current road edge [0.0, 1.0).
  final double progress;

  const CompanyOnMap({
    required this.company,
    required this.id,
    required this.ownership,
    required this.currentNode,
    this.destination,
    this.progress = 0.0,
  });

  CompanyOnMap copyWith({
    Company? company,
    String? id,
    Ownership? ownership,
    MapNode? currentNode,
    MapNode? destination,
    double? progress,
  }) {
    return CompanyOnMap(
      company: company ?? this.company,
      id: id ?? this.id,
      ownership: ownership ?? this.ownership,
      currentNode: currentNode ?? this.currentNode,
      destination: destination,
      progress: progress ?? this.progress,
    );
  }

  @override
  String toString() =>
      'CompanyOnMap(id=$id, owner=$ownership, node=${currentNode.id}, progress=$progress)';
}

/// Use case: detect battle triggers from the current map state.
///
/// Checks for:
/// - **FR-014**: Opposing Companies on the same road segment/node → [BattleTriggerKind.roadCollision]
/// - **FR-015**: A Company arriving at an enemy [CastleNode] → [BattleTriggerKind.castleAssault]
///
/// Pure Dart — zero Flutter/state imports.
final class CheckCollisions {
  const CheckCollisions();

  /// Returns a list of [BattleTrigger]s detected among the given [companies].
  List<BattleTrigger> check({
    required GameMap map,
    required List<CompanyOnMap> companies,
  }) {
    final triggers = <BattleTrigger>[];

    // FR-015: Company at an enemy castle node
    for (final co in companies) {
      final node = co.currentNode;
      if (node is CastleNode && _isEnemy(co.ownership, node.ownership)) {
        triggers.add(
          BattleTrigger(
            kind: BattleTriggerKind.castleAssault,
            location: node,
            companyIds: [co.id],
          ),
        );
      }
    }

    // FR-014: Opposing Companies on the same node
    // Group companies by their current node id
    final byNode = <String, List<CompanyOnMap>>{};
    for (final co in companies) {
      byNode.putIfAbsent(co.currentNode.id, () => []).add(co);
    }

    for (final nodeGroup in byNode.values) {
      if (nodeGroup.length < 2) continue;

      // Find pairs of opposing Companies on this node
      final opposing = <CompanyOnMap>[];
      for (int i = 0; i < nodeGroup.length; i++) {
        for (int j = i + 1; j < nodeGroup.length; j++) {
          final a = nodeGroup[i];
          final b = nodeGroup[j];
          if (_isEnemy(a.ownership, b.ownership)) {
            opposing.add(a);
            opposing.add(b);
          }
        }
      }
      if (opposing.isEmpty) continue;

      // Deduplicate by id
      final seen = <String>{};
      final unique = opposing.where((c) => seen.add(c.id)).toList();

      final node = nodeGroup.first.currentNode;
      // Skip if this is already covered by a castleAssault trigger at this node
      final alreadyCastleAssault = triggers.any(
        (t) =>
            t.kind == BattleTriggerKind.castleAssault &&
            t.location.id == node.id,
      );
      if (!alreadyCastleAssault) {
        triggers.add(
          BattleTrigger(
            kind: BattleTriggerKind.roadCollision,
            location: node,
            companyIds: unique.map((c) => c.id).toList(),
          ),
        );
      }
    }

    return triggers;
  }

  static bool _isEnemy(Ownership a, Ownership b) {
    if (a == Ownership.neutral || b == Ownership.neutral) return false;
    return a != b;
  }
}
