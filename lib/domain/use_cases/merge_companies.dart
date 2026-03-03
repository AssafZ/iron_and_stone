import 'package:iron_and_stone/domain/rules/merge_split_rules.dart';
import 'package:iron_and_stone/domain/use_cases/check_collisions.dart';

/// Thrown when a merge action cannot be completed.
final class MergeCompaniesException implements Exception {
  final String message;
  const MergeCompaniesException(this.message);

  @override
  String toString() => 'MergeCompaniesException: $message';
}

/// The result of a successful [MergeCompanies.merge] operation.
final class MergeCompaniesResult {
  /// The primary merged [CompanyOnMap] (≤ 50 soldiers), placed on the shared node.
  final CompanyOnMap primary;

  /// An overflow [CompanyOnMap] when combined total > 50, also placed on the shared
  /// node. Null when combined total ≤ 50.
  final CompanyOnMap? overflow;

  const MergeCompaniesResult({required this.primary, this.overflow});
}

/// Use case: merge two friendly [CompanyOnMap] entities on the same map node.
///
/// Validates:
/// - Both Companies are on the same [MapNode].
/// - Both Companies have the same [Ownership].
/// - If combined total > 50, an [overflowId] must be provided.
///
/// Delegates domain math to [MergeSplitRules.merge].
///
/// Pure Dart — zero Flutter/state imports.
final class MergeCompanies {
  const MergeCompanies();

  /// Merge [companyA] and [companyB] into one or two [CompanyOnMap] entities.
  ///
  /// [newId] is the ID for the resulting primary Company.
  /// [overflowId] is the ID for the overflow Company (required when combined > 50).
  MergeCompaniesResult merge({
    required CompanyOnMap companyA,
    required CompanyOnMap companyB,
    required String newId,
    String? overflowId,
  }) {
    if (companyA.currentNode.id != companyB.currentNode.id) {
      throw const MergeCompaniesException(
        'Both Companies must be on the same map node to merge.',
      );
    }

    if (companyA.ownership != companyB.ownership) {
      throw const MergeCompaniesException(
        'Cannot merge Companies with different ownerships.',
      );
    }

    final domainResult = MergeSplitRules.merge(
      companyA.company,
      companyB.company,
    );

    if (domainResult.overflow != null && overflowId == null) {
      throw MergeCompaniesException(
        'Combined total exceeds 50 soldiers — an overflowId must be provided '
        '(combined: ${companyA.company.totalSoldiers.value + companyB.company.totalSoldiers.value}).',
      );
    }

    final primaryOnMap = CompanyOnMap(
      id: newId,
      company: domainResult.primary,
      ownership: companyA.ownership,
      currentNode: companyA.currentNode,
    );

    CompanyOnMap? overflowOnMap;
    if (domainResult.overflow != null) {
      overflowOnMap = CompanyOnMap(
        id: overflowId!,
        company: domainResult.overflow!,
        ownership: companyA.ownership,
        currentNode: companyA.currentNode,
      );
    }

    return MergeCompaniesResult(primary: primaryOnMap, overflow: overflowOnMap);
  }
}
