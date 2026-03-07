import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';
import 'package:iron_and_stone/domain/value_objects/road_position.dart';

/// Returned by [MoveCompany.advanceWithBattleCheck] when a Company arrives at a
/// node that has an active battle — the company should be routed as a
/// reinforcement wave (FR-021) rather than continuing movement normally.
final class ReinforcementArrival {
  /// The company that just arrived at the battle node.
  final CompanyOnMap company;

  /// The node ID of the battle the company is joining as reinforcement.
  final String battleNodeId;

  const ReinforcementArrival({
    required this.company,
    required this.battleNodeId,
  });
}

/// Thrown when a move action cannot be completed.
final class MoveCompanyException implements Exception {
  final String message;
  const MoveCompanyException(this.message);

  @override
  String toString() => 'MoveCompanyException: $message';
}

/// Use case: assign a destination to a Company and advance its position per tick.
///
/// Pure Dart — zero Flutter/state imports.
final class MoveCompany {
  const MoveCompany();

  /// Assign [destination] to [company].
  ///
  /// Throws [MoveCompanyException] if no road path exists to [destination].
  CompanyOnMap setDestination({
    required CompanyOnMap company,
    required MapNode destination,
    required GameMap map,
  }) {
    // Same node: valid (no-op movement).
    if (destination.id == company.currentNode.id) {
      return company.copyWith(destination: destination);
    }

    if (!MovementRules.isValidPath(map, company.currentNode, destination)) {
      throw MoveCompanyException(
        'No road path from ${company.currentNode.id} to ${destination.id}.',
      );
    }

    return company.copyWith(destination: destination);
  }

  /// Assign a mid-road fractional stop position to [company].
  ///
  /// The company will march toward [dest.currentNodeId] and stop at the
  /// fractional progress [dest.progress] along the segment to [dest.nextNodeId].
  ///
  /// Throws [MoveCompanyException] if:
  /// - [company] is locked in a battle.
  /// - The segment described by [dest] does not exist in [map].
  CompanyOnMap setMidRoadDestination({
    required CompanyOnMap company,
    required RoadPosition dest,
    required GameMap map,
  }) {
    if (company.battleId != null) {
      throw MoveCompanyException(
        'Company ${company.id} is locked in battle ${company.battleId} '
        'and cannot receive a new mid-road destination.',
      );
    }

    // Validate that the segment exists in the map.
    final segmentExists = map.edges.any(
      (e) => e.from.id == dest.currentNodeId && e.to.id == dest.nextNodeId,
    );
    if (!segmentExists) {
      throw MoveCompanyException(
        'Segment "${dest.currentNodeId} → ${dest.nextNodeId}" does not exist '
        'in the map.',
      );
    }

    // Find the "next node" of the segment — we need it as the march destination
    // so the company walks toward the segment start.
    final nextNode = map.nodes
        .where((n) => n.id == dest.nextNodeId)
        .firstOrNull;
    if (nextNode == null) {
      throw MoveCompanyException(
        'Node "${dest.nextNodeId}" not found in the map.',
      );
    }

    // Use the segment's currentNodeId as the interim march destination.
    // The company needs to first navigate to dest.currentNodeId before
    // entering the segment; if it's already there the march starts immediately.
    final destNode = map.nodes
        .where((n) => n.id == dest.currentNodeId)
        .firstOrNull;
    if (destNode == null) {
      throw MoveCompanyException(
        'Node "${dest.currentNodeId}" not found in the map.',
      );
    }

    return company.copyWith(
      midRoadDestination: dest,
      destination: null,
    );
  }

  /// Advance [company] position by one tick of [tickSeconds] seconds.
  ///
  /// Delegates to [MovementRules.advancePosition] and returns an updated
  /// [CompanyOnMap]. When a [midRoadDestination] is set and the company
  /// reaches it, [midRoadDestination] is cleared and the company becomes
  /// stationary at that fractional position.
  CompanyOnMap advance({
    required CompanyOnMap company,
    required GameMap map,
    required double tickSeconds,
  }) {
    // Derive an effective march destination: use the explicit `destination`
    // field if set; otherwise derive from `midRoadDestination.nextNodeId`
    // so the company marches onto the target segment automatically.
    MapNode? effectiveDest = company.destination;
    if (effectiveDest == null && company.midRoadDestination != null) {
      effectiveDest = map.nodes
          .where((n) => n.id == company.midRoadDestination!.nextNodeId)
          .firstOrNull;
    }

    final result = MovementRules.advancePosition(
      currentNode: company.currentNode,
      destination: effectiveDest,
      progress: company.progress,
      company: company.company,
      map: map,
      tickSeconds: tickSeconds,
      midRoadDest: company.midRoadDestination,
    );

    if (result.reachedMidRoad) {
      // Company arrived at its mid-road stop — clear destination and intent.
      return company.copyWith(
        currentNode: result.currentNode,
        progress: result.progress,
        destination: null,
        midRoadDestination: null,
      );
    }

    return company.copyWith(
      currentNode: result.currentNode,
      destination: company.destination,
      progress: result.progress,
    );
  }

  /// Advance [company] and check if it arrives at a node with an active battle.
  ///
  /// Returns [ReinforcementArrival] if the company arrives at a node in
  /// [activeBattleNodeIds] (FR-021), otherwise returns the updated
  /// [CompanyOnMap].
  Object advanceWithBattleCheck({
    required CompanyOnMap company,
    required GameMap map,
    required double tickSeconds,
    required Set<String> activeBattleNodeIds,
  }) {
    final updated = advance(
      company: company,
      map: map,
      tickSeconds: tickSeconds,
    );

    if (activeBattleNodeIds.contains(updated.currentNode.id)) {
      return ReinforcementArrival(
        company: updated,
        battleNodeId: updated.currentNode.id,
      );
    }

    return updated;
  }
}
