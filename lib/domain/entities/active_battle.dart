import 'package:iron_and_stone/domain/entities/battle.dart';
import 'package:iron_and_stone/domain/value_objects/ownership.dart';

/// An active battle in progress on the game map.
///
/// Associates a [Battle] (combat state) with the map node where it is
/// taking place, plus the company IDs on each side so the game loop can
/// freeze them and apply post-battle cleanup.
///
/// The [id] is derived deterministically from the [nodeId] so that persistence
/// round-trips never need UUID generation:
///   `id == "battle_<nodeId>"`
///
/// Pure Dart — zero Flutter imports.
final class ActiveBattle {
  /// Unique identifier: always `"battle_$nodeId"`.
  final String id;

  /// The map node ID where this battle is occurring.
  final String nodeId;

  /// IDs of [CompanyOnMap] entities on the attacking side.
  final List<String> attackerCompanyIds;

  /// IDs of [CompanyOnMap] entities on the defending side.
  final List<String> defenderCompanyIds;

  /// Which [Ownership] value the attackers belong to.
  final Ownership attackerOwnership;

  /// The live [Battle] carrying round state (HP maps, round log, outcome).
  final Battle battle;

  /// For mid-road battles: fractional progress along the canonical segment
  /// (from the lower-id node toward the higher-id node) where the battle is
  /// occurring. Null for node-level battles.
  final double? midRoadProgress;

  ActiveBattle({
    required this.nodeId,
    required List<String> attackerCompanyIds,
    required List<String> defenderCompanyIds,
    required this.attackerOwnership,
    required this.battle,
    this.midRoadProgress,
  })  : id = 'battle_$nodeId',
        attackerCompanyIds = List.unmodifiable(attackerCompanyIds),
        defenderCompanyIds = List.unmodifiable(defenderCompanyIds);

  /// Returns a new [ActiveBattle] with updated fields.
  ///
  /// [nodeId] and [id] are always derived together from the original [nodeId].
  ActiveBattle copyWith({
    String? nodeId,
    List<String>? attackerCompanyIds,
    List<String>? defenderCompanyIds,
    Ownership? attackerOwnership,
    Battle? battle,
    double? midRoadProgress,
  }) {
    return ActiveBattle(
      nodeId: nodeId ?? this.nodeId,
      attackerCompanyIds: attackerCompanyIds ?? this.attackerCompanyIds,
      defenderCompanyIds: defenderCompanyIds ?? this.defenderCompanyIds,
      attackerOwnership: attackerOwnership ?? this.attackerOwnership,
      battle: battle ?? this.battle,
      midRoadProgress: midRoadProgress ?? this.midRoadProgress,
    );
  }

  @override
  String toString() =>
      'ActiveBattle(id=$id, attackers=$attackerCompanyIds, '
      'defenders=$defenderCompanyIds, round=${battle.roundNumber}, '
      'outcome=${battle.outcome})';
}
