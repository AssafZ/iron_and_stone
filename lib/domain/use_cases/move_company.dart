import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

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

  /// Advance [company] position by one tick of [tickSeconds] seconds.
  ///
  /// Delegates to [MovementRules.advancePosition] and returns an updated
  /// [CompanyOnMap].
  CompanyOnMap advance({
    required CompanyOnMap company,
    required GameMap map,
    required double tickSeconds,
  }) {
    final result = MovementRules.advancePosition(
      currentNode: company.currentNode,
      destination: company.destination,
      progress: company.progress,
      company: company.company,
      map: map,
      tickSeconds: tickSeconds,
    );

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
