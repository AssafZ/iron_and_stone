import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
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

  /// Accumulated fractional growth per role, carried between ticks.
  ///
  /// Slower-growing roles (warriors, knights, catapults) accumulate a fraction
  /// each tick until it reaches 1.0, at which point a whole soldier is added
  /// and the remainder is kept for the next tick.
  final Map<UnitRole, double> growthRemainder;

  /// ID of the [ActiveBattle] this Company is currently locked into, or null
  /// when the Company is not in battle.
  final String? battleId;

  const CompanyOnMap({
    required this.company,
    required this.id,
    required this.ownership,
    required this.currentNode,
    this.destination,
    this.progress = 0.0,
    this.growthRemainder = const {},
    this.battleId,
  });

  /// Sentinel used to distinguish "caller passed null explicitly" from
  /// "caller did not pass the argument at all" for the nullable [destination].
  static const Object _destinationSentinel = Object();

  /// Sentinel used to distinguish "caller passed null explicitly" from
  /// "caller did not pass the argument at all" for the nullable [battleId].
  static const Object _battleIdSentinel = Object();

  CompanyOnMap copyWith({
    Company? company,
    String? id,
    Ownership? ownership,
    MapNode? currentNode,
    Object? destination = _destinationSentinel,
    double? progress,
    Map<UnitRole, double>? growthRemainder,
    Object? battleId = _battleIdSentinel,
  }) {
    return CompanyOnMap(
      company: company ?? this.company,
      id: id ?? this.id,
      ownership: ownership ?? this.ownership,
      currentNode: currentNode ?? this.currentNode,
      destination: identical(destination, _destinationSentinel)
          ? this.destination
          : destination as MapNode?,
      progress: progress ?? this.progress,
      growthRemainder: growthRemainder ?? this.growthRemainder,
      battleId: identical(battleId, _battleIdSentinel)
          ? this.battleId
          : battleId as String?,
    );
  }

  @override
  String toString() =>
      'CompanyOnMap(id=$id, owner=$ownership, node=${currentNode.id}, progress=$progress)';
}

/// Use case: detect battle triggers from the current map state.
///
/// Checks for:
/// - **FR-001**: Opposing Companies on the same road segment/node → [BattleTriggerKind.roadCollision]
/// - **FR-003**: A Company arriving at an enemy [CastleNode] that has stationary
///   garrison companies → [BattleTriggerKind.castleAssault]
/// - **FR-004**: An enemy castle with no living garrison is captured immediately
///   (no battle trigger emitted).
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

    // FR-003: Company arriving at an enemy castle node that has garrison defenders.
    // Only stationary companies (destination == null OR destination == currentNode)
    // with at least 1 soldier at the castle count as garrison.
    for (final co in companies) {
      final node = co.currentNode;
      if (node is! CastleNode) continue;
      if (!isEnemy(co.ownership, node.ownership)) continue;

      // Collect garrison defenders: companies at this castle node belonging to
      // the castle's owner that are stationary and have >= 1 soldier.
      final garrisonDefenders = companies.where((c) {
        if (c.id == co.id) return false;
        if (c.currentNode.id != node.id) return false;
        if (c.ownership != node.ownership) return false;
        final isStationary = c.destination == null || c.destination!.id == c.currentNode.id;
        if (!isStationary) return false;
        return c.company.totalSoldiers.value > 0;
      }).toList();

      if (garrisonDefenders.isEmpty) continue; // empty castle — no battle trigger

      // Emit ONE castleAssault trigger with the attacker + all garrison defenders.
      // Check we haven't already emitted one for this node (e.g. multiple attackers
      // arriving simultaneously — they will be grouped into one trigger below).
      final alreadyEmitted = triggers.any(
        (t) => t.kind == BattleTriggerKind.castleAssault && t.location.id == node.id,
      );
      if (!alreadyEmitted) {
        final allInvolvedIds = [
          // All attackers (enemies of the castle owner) at this node
          ...companies
              .where((c) =>
                  c.currentNode.id == node.id &&
                  isEnemy(c.ownership, node.ownership))
              .map((c) => c.id),
          // All garrison defenders
          ...garrisonDefenders.map((c) => c.id),
        ];
        triggers.add(
          BattleTrigger(
            kind: BattleTriggerKind.castleAssault,
            location: node,
            companyIds: allInvolvedIds.toSet().toList(),
          ),
        );
      }
    }

    // FR-001: Opposing Companies on the same node (non-castle-assault nodes).
    // Group companies by their current node id.
    final byNode = <String, List<CompanyOnMap>>{};
    for (final co in companies) {
      byNode.putIfAbsent(co.currentNode.id, () => []).add(co);
    }

    for (final nodeGroup in byNode.values) {
      if (nodeGroup.length < 2) continue;

      // Determine if any two companies on this node are enemies.
      bool hasAnyEnemy = false;
      for (int i = 0; i < nodeGroup.length && !hasAnyEnemy; i++) {
        for (int j = i + 1; j < nodeGroup.length && !hasAnyEnemy; j++) {
          if (isEnemy(nodeGroup[i].ownership, nodeGroup[j].ownership)) {
            hasAnyEnemy = true;
          }
        }
      }
      if (!hasAnyEnemy) continue;

      final node = nodeGroup.first.currentNode;
      // Skip if this is already covered by a castleAssault trigger at this node.
      final alreadyCastleAssault = triggers.any(
        (t) =>
            t.kind == BattleTriggerKind.castleAssault &&
            t.location.id == node.id,
      );
      if (!alreadyCastleAssault) {
        // Emit ONE trigger per node containing ALL companies present
        // (regardless of ownership mix — the battle loop sorts sides out).
        triggers.add(
          BattleTrigger(
            kind: BattleTriggerKind.roadCollision,
            location: node,
            companyIds: nodeGroup.map((c) => c.id).toList(),
          ),
        );
      }
    }

    return triggers;
  }

  static bool isEnemy(Ownership a, Ownership b) {
    if (a == Ownership.neutral || b == Ownership.neutral) return false;
    return a != b;
  }
}
