import 'package:iron_and_stone/domain/entities/castle.dart';
import 'package:iron_and_stone/domain/entities/company.dart';
import 'package:iron_and_stone/domain/entities/game_map.dart';
import 'package:iron_and_stone/domain/entities/map_node.dart';
import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

/// Thrown when a deploy action cannot be completed.
final class DeployCompanyException implements Exception {
  final String message;
  const DeployCompanyException(this.message);

  @override
  String toString() => 'DeployCompanyException: $message';
}

/// The result of a successful deploy action.
final class DeployCompanyResult {
  /// The castle with garrison decremented by the deployed composition.
  final Castle updatedCastle;

  /// The newly placed [CompanyOnMap] at the castle node.
  final CompanyOnMap company;

  const DeployCompanyResult({
    required this.updatedCastle,
    required this.company,
  });
}

/// Use case: deploy a Company from a castle garrison onto the map.
///
/// Validates:
/// - Total composition ≤ 50 soldiers (FR-008).
/// - At least 1 soldier in the composition.
/// - Garrison has sufficient units for each role.
///
/// On success, decrements the castle garrison and returns a [CompanyOnMap]
/// placed at the castle node (the player moves it from there).
///
/// Pure Dart — zero Flutter/state imports.
final class DeployCompany {
  const DeployCompany();

  /// Deploy a Company from [castle] using [composition].
  ///
  /// [companyId] is a unique identifier for the resulting [CompanyOnMap].
  DeployCompanyResult deploy({
    required Castle castle,
    required Map<UnitRole, int> composition,
    required CastleNode castleNode,
    required GameMap map,
    required String companyId,
  }) {
    // Strip zero-count entries.
    final filtered = Map<UnitRole, int>.fromEntries(
      composition.entries.where((e) => e.value > 0),
    );

    if (filtered.isEmpty) {
      throw const DeployCompanyException('Composition must include at least 1 soldier.');
    }

    // Validate total ≤ 50 (SoldierCount will also enforce this).
    final total = filtered.values.fold(0, (sum, v) => sum + v);
    if (total > 50) {
      throw DeployCompanyException(
        'Deployment would exceed the 50-soldier Company cap (total=$total).',
      );
    }

    // Validate garrison has enough of each role.
    for (final entry in filtered.entries) {
      final available = castle.garrison[entry.key] ?? 0;
      if (entry.value > available) {
        throw DeployCompanyException(
          'Insufficient ${entry.key.name} in garrison: '
          'requested ${entry.value}, available $available.',
        );
      }
    }

    // Decrement garrison.
    final updatedGarrison = Map<UnitRole, int>.from(castle.garrison);
    for (final entry in filtered.entries) {
      updatedGarrison[entry.key] = (updatedGarrison[entry.key] ?? 0) - entry.value;
    }

    final updatedCastle = castle.copyWith(garrison: updatedGarrison);

    // Build the Company.
    final company = Company(composition: filtered);

    // Place at castle node (ownership from castleNode).
    final companyOnMap = CompanyOnMap(
      company: company,
      id: companyId,
      ownership: castleNode.ownership,
      currentNode: castleNode,
      destination: null,
      progress: 0.0,
    );

    return DeployCompanyResult(
      updatedCastle: updatedCastle,
      company: companyOnMap,
    );
  }
}
