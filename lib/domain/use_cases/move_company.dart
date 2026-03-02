import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/rules/movement_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

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
}
