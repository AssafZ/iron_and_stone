import 'package:iron_and_stone/domain/entities/unit_role.dart';
import 'package:iron_and_stone/domain/rules/merge_split_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

/// Thrown when a split action cannot be completed.
final class SplitCompanyException implements Exception {
  final String message;
  const SplitCompanyException(this.message);

  @override
  String toString() => 'SplitCompanyException: $message';
}

/// The result of a successful [SplitCompany.split] operation.
final class SplitCompanyResult {
  /// The original Company with the split-off soldiers removed, on the same node.
  final CompanyOnMap kept;

  /// The newly formed Company containing the split-off soldiers, on the same node.
  final CompanyOnMap splitOff;

  const SplitCompanyResult({required this.kept, required this.splitOff});
}

/// Use case: split a [CompanyOnMap] into two Companies using a role-based
/// composition map.
///
/// Validates composition via [MergeSplitRules.split] and wraps results
/// back into [CompanyOnMap] entities placed on the same node.
///
/// Pure Dart — zero Flutter/state imports.
final class SplitCompany {
  const SplitCompany();

  /// Split [company] according to [splitComposition].
  ///
  /// [keptId] is the ID for the kept (remainder) Company.
  /// [splitId] is the ID for the new split-off Company.
  ///
  /// Throws [SplitCompanyException] for invalid compositions (delegates to
  /// [MergeSplitRules.split] which throws [ArgumentError]; wrapped here for
  /// a more descriptive exception type).
  SplitCompanyResult split({
    required CompanyOnMap company,
    required Map<UnitRole, int> splitComposition,
    required String keptId,
    required String splitId,
  }) {
    try {
      final domainResult = MergeSplitRules.split(
        company.company,
        splitComposition,
      );

      final kept = CompanyOnMap(
        id: keptId,
        company: domainResult.kept,
        ownership: company.ownership,
        currentNode: company.currentNode,
      );

      final splitOff = CompanyOnMap(
        id: splitId,
        company: domainResult.splitOff,
        ownership: company.ownership,
        currentNode: company.currentNode,
      );

      return SplitCompanyResult(kept: kept, splitOff: splitOff);
    } on ArgumentError catch (e) {
      throw SplitCompanyException(e.message?.toString() ?? e.toString());
    }
  }
}
